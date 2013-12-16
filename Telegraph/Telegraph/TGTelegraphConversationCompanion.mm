#import "TGTelegraphConversationCompanion.h"

#import "TGAppDelegate.h"

#import "TGSession.h"

#import "TGCache.h"
#import "TGRemoteImageView.h"

#import "TGImageDownloadActor.h"

#import "SGraphNode.h"
#import "SGraphListNode.h"
#import "SGraphObjectNode.h"

#import "TGConversationSendMessageActor.h"

#import "TGTelegraph.h"
#import "TGUserNode.h"

#import "TGImageInputMediaAttachment.h"
#import "TGLocationInputMediaAttachment.h"
#import "TGContactInputMediaAttachment.h"
#import "TGForwardedMessageInputMediaAttachment.h"

#import "TGInterfaceManager.h"
#import "TGInterfaceAssets.h"

#import "TGConversationItem.h"
#import "TGConversationDateItem.h"
#import "TGConversationUnreadItem.h"
#import "TGConversationMessageItem.h"

#import "TGConversationController.h"
#import "TGTelegraphImageViewControllerCompanion.h"

#import "TGDialogListCompanion.h"

#import "TGDatabase.h"

#import "TGTelegraphConversationMessageAssetsSource.h"

#import "TGTelegraphConversationProfileController.h"

#import "TGTelegraphGroupPhotoImageViewControllerCompanion.h"
#import "TGTelegraphProfileImageViewCompanion.h"

#import "TGImageUtils.h"
#import "TGDateUtils.h"

#import "TGForwardTargetController.h"

#import <set>

#import "TGSharedPtrWrapper.h"

#import "TGDownloadManager.h"

#import "TGVideoDownloadActor.h"

static int nextBroadcastMid = 700000000;

static const char *messageQueueSpecific = "com.telegraph.messagequeue";

static NSMutableSet *cancelledMediaIds()
{
    static NSMutableSet *set = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        set = [[NSMutableSet alloc] init];
    });
    return set;
}

static dispatch_queue_t messageQueue()
{
    static dispatch_queue_t queue = NULL;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        queue = dispatch_queue_create("com.telegraph.messagequeue", 0);
        if (dispatch_queue_set_specific != NULL)
            dispatch_queue_set_specific(queue, messageQueueSpecific, (void *)messageQueueSpecific, NULL);
    });
    
    return queue;
}

static void dispatchOnMessageQueue(dispatch_block_t block, bool synchronous)
{
    if (block == NULL)
        return;
    
    bool currentQueueIsMessageQueue = false;
    
    if (dispatch_queue_set_specific != NULL)
        currentQueueIsMessageQueue = dispatch_get_specific(messageQueueSpecific) == messageQueueSpecific;
    else
        currentQueueIsMessageQueue = dispatch_get_current_queue() == messageQueue();
    
    if (currentQueueIsMessageQueue)
        block();
    else
    {
        if (synchronous)
            dispatch_sync(messageQueue(), block);
        else
            dispatch_async(messageQueue(), block);
    }
}

@interface TGTelegraphConversationCompanion ()
{
    std::map<int, float> _messageUploadProgress;
    
    std::set<int> _proccessedDownloadedStatusMids;
}

@property (nonatomic) NSTimeInterval lastTypingActivityDate;
@property (nonatomic) bool didRemoveUnreadMarker;

@property (nonatomic) TGConversationControllerSynchronizationState synchronizationState;

@property (nonatomic, strong) NSArray *broadcastUids;
@property (nonatomic, strong) NSString *dispatchConversationTag;

@property (nonatomic, strong) TGConversation *conversation;
@property (nonatomic, strong) NSArray *typingUsers;
@property (nonatomic) bool requestedExtendedInfo;

@property (nonatomic) int openAtMessageId;

@property (nonatomic) bool sendingMessages;
@property (nonatomic) bool sendingMessagesClearText;

@property (nonatomic) int timeOffset;
@property (nonatomic) bool timeOffsetInitialized;

@property (nonatomic, strong) ASHandle *conversationProfileControllerHandle;
@property (nonatomic) bool loadedCreationDate;

@property (nonatomic) int userLink;
@property (nonatomic, strong) NSString *runningLinkAction;
@property (nonatomic) bool acceptingEncryptionRequest;

@property (nonatomic) int unreadCount;
@property (nonatomic, strong) TGTimer *unreadCountTimer;

@property (nonatomic) bool isContact;

@property (nonatomic, strong) NSMutableDictionary *mediaDownloadProgress;

@property (nonatomic) int minRemoteUnreadId;

@end

@implementation TGTelegraphConversationCompanion

static void addMessageActionUsers(TGMessage *message, TGConversationMessageItem *messageItem)
{
    TGActionMediaAttachment *messageAction = message.actionInfo;
    if (messageAction != nil)
    {
        switch (messageAction.actionType)
        {
            case TGMessageActionChatAddMember:
            case TGMessageActionChatDeleteMember:
            {
                NSNumber *nUid = [messageAction.actionData objectForKey:@"uid"];
                if (nUid != nil)
                {
                    TGUser *user = [TGDatabaseInstance() loadUser:[nUid intValue]];
                    if (user != nil)
                        messageItem.messageUsers = [NSDictionary dictionaryWithObject:user forKey:nUid];
                }
                
                break;
            }
            case TGMessageActionCreateChat:
            {
                NSMutableDictionary *usersDict = [[NSMutableDictionary alloc] init];
                for (NSNumber *nUid in [messageAction.actionData objectForKey:@"uids"])
                {
                    TGUser *user = [TGDatabaseInstance() loadUser:[nUid intValue]];
                    if (user != nil)
                        [usersDict setObject:user forKey:nUid];
                }
                messageItem.messageUsers = usersDict;
                
                break;
            }
            case TGMessageActionContactRequest:
            case TGMessageActionAcceptContactRequest:
            case TGMessageActionContactRegistered:
            case TGMessageActionEncryptedChatMessageLifetime:
            {
                if (messageItem.author == nil)
                    messageItem.author = [TGDatabaseInstance() loadUser:message.fromUid];
                break;
            }
            case TGMessageActionUserChangedPhoto:
            {
                if (messageItem.author == nil)
                    messageItem.author = [TGDatabaseInstance() loadUser:message.fromUid];
                break;
            }
            default:
                break;
        }
    }
    else
    {
        NSMutableDictionary *usersDict = nil;
        
        for (TGMediaAttachment *attachment in message.mediaAttachments)
        {
            if (attachment.type == TGContactMediaAttachmentType)
            {
                TGContactMediaAttachment *contactAttachment = (TGContactMediaAttachment *)attachment;
                if (contactAttachment.uid != 0)
                {
                    if (usersDict == nil)
                        usersDict = [[NSMutableDictionary alloc] init];
                    TGUser *user = [TGDatabaseInstance() loadUser:contactAttachment.uid];
                    if (user != nil)
                        [usersDict setObject:user forKey:[[NSNumber alloc] initWithInt:contactAttachment.uid]];
                }
            }
            else if (attachment.type == TGForwardedMessageMediaAttachmentType)
            {
                TGForwardedMessageMediaAttachment *forwardedMessageAttachment = (TGForwardedMessageMediaAttachment *)attachment;
                
                if (usersDict == nil)
                    usersDict = [[NSMutableDictionary alloc] init];
                TGUser *user = [TGDatabaseInstance() loadUser:forwardedMessageAttachment.forwardUid];
                if (user != nil)
                    [usersDict setObject:user forKey:[[NSNumber alloc] initWithInt:forwardedMessageAttachment.forwardUid]];
            }
        }
        
        if (usersDict != nil)
            messageItem.messageUsers = usersDict;
    }
}

- (void)commonInit
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        [TGConversationController setGlobalAssetsSource:[TGTelegraphConversationMessageAssetsSource instance]];
    });
}

- (id)initWithConversationId:(int64_t)conversationId atMessageId:(int)atMessageId isMultichat:(bool)isMultichat isEncrypted:(bool)isEncrypted conversation:(TGConversation *)conversation unreadCount:(int)unreadCount messagesToForward:(NSArray *)messagesToForward
{
    self = [super init];
    if (self != nil)
    {
        [self commonInit];
        
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:false];
        
        _conversationId = conversationId;
        _openAtMessageId = atMessageId;
        _dispatchConversationTag = [[NSString alloc] initWithFormat:@"%lld", _conversationId];
        
        self.isMultichat = isMultichat;
        self.isEncrypted = isEncrypted;
        
        _messagesToForward = messagesToForward;
        
        _unreadCount = unreadCount;
        
        if (self.isEncrypted)
        {
            conversation = [TGDatabaseInstance() loadConversationWithId:_conversationId];
            if (conversation.chatParticipants.chatParticipantUids.count != 0)
            {
                self.encryptedUserId = [conversation.chatParticipants.chatParticipantUids[0] intValue];
                self.encryptionIsIncoming = conversation.chatParticipants.chatAdminId != TGTelegraphInstance.clientUserId;
            }
            
            _encryptedConversationId = conversation.encryptedData.encryptedConversationId;
            _encryptedConversationAccessHash = conversation.encryptedData.accessHash;
        }
        
        if (conversationId != 0)
        {
            [ActionStageInstance() dispatchOnStageQueue:^
            {
                if (self.isEncrypted)
                    self.singleParticipant = [TGDatabaseInstance() loadUser:self.encryptedUserId];
                
                [ActionStageInstance() watchForPath:@"/tg/unreadCount" watcher:self];
                [ActionStageInstance() watchForPath:@"/system/significantTimeChange" watcher:self];
                [ActionStageInstance() watchForPath:[NSString stringWithFormat:@"/tg/conversation/(%lld)/messages", _conversationId] watcher:self];
                [ActionStageInstance() watchForPath:[NSString stringWithFormat:@"/tg/conversation/(%lld)/conversation", _conversationId] watcher:self];
                [ActionStageInstance() watchForPath:@"/tg/conversation/*/readmessages" watcher:self];
                [ActionStageInstance() watchForPath:[[NSString alloc] initWithFormat:@"/tg/conversation/(%lld)/readByDateMessages", _conversationId] watcher:self];
                [ActionStageInstance() watchForPath:@"/tg/conversation/*/failmessages" watcher:self];
                [ActionStageInstance() watchForPath:[[NSString alloc] initWithFormat:@"/tg/conversationReadApplied/(%lld)", _conversationId] watcher:self];
                [ActionStageInstance() watchForPath:[NSString stringWithFormat:@"/tg/conversation/(%lld)/messagesDeleted", _conversationId] watcher:self];
                [ActionStageInstance() watchForPath:[NSString stringWithFormat:@"/tg/conversation/(%lld)/messagesChanged", _conversationId] watcher:self];
                [ActionStageInstance() watchForPath:[NSString stringWithFormat:@"/tg/conversation/(%lld)/typing", _conversationId] watcher:self];
                
                if (conversationId <= INT_MIN)
                {
                    self.messageLifetime = [TGDatabaseInstance() messageLifetimeForPeerId:_conversationId];
                    
                    [ActionStageInstance() watchForPath:[[NSString alloc] initWithFormat:@"/tg/conversationMessageLifetime/(%lld)", _conversationId] watcher:self];
                }
                
                [ActionStageInstance() watchForPath:@"/tg/service/synchronizationstate" watcher:self];
                [ActionStageInstance() requestActor:@"/tg/service/synchronizationstate" options:nil watcher:self];
                
                [ActionStageInstance() watchForPath:@"/tg/blockedUsers" watcher:self];
                
                [ActionStageInstance() watchForPath:@"/as/media/imageThumbnailUpdated" watcher:self];
                
                NSArray *sendMessageActions = [ActionStageInstance() rejoinActionsWithGenericPathNow:@"/tg/conversations/@/sendMessage/@" prefix:[NSString stringWithFormat:@"/tg/conversations/(%lld)", _conversationId] watcher:self];
                
                if (!self.isMultichat || self.isEncrypted)
                {
                    [ActionStageInstance() watchForPath:@"/as/updateRelativeTimestamps" watcher:self];
                }
                
                std::tr1::shared_ptr<std::map<int, float> > messageUploadProgress(new std::map<int, float>());
                for (NSString *path in sendMessageActions)
                {
                    TGConversationSendMessageActor *actor = (TGConversationSendMessageActor *)[ActionStageInstance() executingActorWithPath:path];
                    if (actor != nil && actor.hasProgress)
                        (*messageUploadProgress)[actor.messageLocalMid] = actor.progress;
                }
                
                dispatchOnMessageQueue(^
                {
                    _messageUploadProgress = *messageUploadProgress;
                }, false);
                
                if (conversation != nil)
                    [self actorCompleted:ASStatusSuccess path:[NSString stringWithFormat:@"/tg/conversation/(%lld)/conversation", _conversationId] result:[[SGraphObjectNode alloc] initWithObject:conversation]];
                
                if (!self.isMultichat || self.isEncrypted)
                {
                    NSArray *contactActions = [ActionStageInstance() rejoinActionsWithGenericPathNow:@"/tg/contacts/requestActor/@/@" prefix:[NSString stringWithFormat:@"/tg/contacts/requestActor/(%lld)", [self singleUserId]] watcher:self];
                    
                    for (NSString *action in contactActions)
                    {
                        if ([action hasSuffix:@"(requestContact)"])
                        {
                            _runningLinkAction = @"requestContact";
                            break;
                        }
                        else if ([action hasSuffix:@"(acceptContact)"])
                        {
                            _runningLinkAction = @"acceptContact";
                            break;
                        }
                    }
                }
                
                [self prepareInitialState];
            }];
        }
    }
    return self;
}

- (id)initWithBroadcastUids:(NSArray *)broadcastUids unreadCount:(int)unreadCount
{
    self = [super init];
    if (self != nil)
    {
        [self commonInit];
        
        _broadcastUids = [broadcastUids sortedArrayUsingSelector:@selector(compare:)];
        
        _unreadCount = unreadCount;
        
        NSMutableString *conversationTag = [[NSMutableString alloc] initWithString:@"broadcast"];
        bool first = true;
        for (NSNumber *nUid in _broadcastUids)
        {
            if (first)
                first = false;
            else
                [conversationTag appendString:@","];
            [conversationTag appendFormat:@"%d", [nUid intValue]];
        }
        
        _dispatchConversationTag = conversationTag;
        
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:false];
        
        _conversationId = 0;
        self.isBroadcast = true;
        
        [ActionStageInstance() watchForPath:@"/tg/unreadCount" watcher:self];
        [ActionStageInstance() watchForPath:@"/tg/service/synchronizationstate" watcher:self];
        [ActionStageInstance() requestActor:@"/tg/service/synchronizationstate" options:nil watcher:self];
        
        [ActionStageInstance() dispatchOnStageQueue:^
        {
            [ActionStageInstance() watchForPath:@"/as/media/imageThumbnailUpdated" watcher:self];
            
            [self prepareInitialState];
        }];
    }
    return self;
}

- (void)updateUnreadCount
{
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        int unreadCount = [TGDatabaseInstance() cachedUnreadCount] - (self.isBroadcast ? 0 : [TGDatabaseInstance() unreadCountForConversation:self.conversationId]);
        
        if (_unreadCount != unreadCount)
        {
            _unreadCount = unreadCount;
            
            dispatch_async(dispatch_get_main_queue(), ^
            {
                [self.conversationController unreadCountChanged:unreadCount];
            });
        }
    }];
}

- (void)dealloc
{
    [_actionHandle reset];
    [ActionStageInstance() removeWatcher:self];
}

- (void)storeConversationState:(NSString *)messageText
{
    if (self.isBroadcast)
        return;
    
    TGMessage *state = (id)[NSNull null];
    if (messageText != nil && messageText.length != 0)
    {
        state = [[TGMessage alloc] init];
        state.text = messageText;
    }
    [ActionStageInstance() requestActor:[[NSString alloc] initWithFormat:@"/tg/conversation/(%lld)/setstate/(%d)", _conversationId, [messageText hash]] options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithLongLong:_conversationId], @"conversationId", state, @"state", nil] watcher:TGTelegraphInstance];
}

- (int)offsetFromGMT
{
    if (!_timeOffsetInitialized)
    {
        _timeOffsetInitialized = true;
        _timeOffset = [TGSession instance].timeOffsetFromUTC;
    }
    
    return _timeOffset;
}

/*#ifdef DEBUG
- (NSMutableArray *)conversationItems
{
    if (dispatch_get_specific(messageQueueSpecific) != messageQueueSpecific)
    {
        TGLog(@"*********** Error: Accessing conversationItems from outside of message queue");
    }
    
    return [super conversationItems];
}
#endif*/

- (void)removeUnreadMarker
{
    dispatchOnMessageQueue(^
    {
        if (_didRemoveUnreadMarker)
            return;
        
        NSArray *conversationItems = self.conversationItems;
        int itemCount = conversationItems.count;
        for (int i = itemCount - 1; i >= 0; i--)
        {
            TGConversationItem *item = [conversationItems objectAtIndex:i];
            if (item.type == TGConversationItemTypeUnread)
            {
                [self.conversationItems removeObjectAtIndex:i];
                dispatch_async(dispatch_get_main_queue(), ^
                {
                    [self.conversationController conversationMessagesChanged:nil insertedItems:nil removedAtIndices:[[NSArray alloc] initWithObjects:[[NSNumber alloc] initWithInt:i], nil] updatedAtIndices:nil updatedItems:nil delay:false scrollDownFlags:0];
                });
                break;
            }
        }
        
        _didRemoveUnreadMarker = true;
    }, false);
}

- (void)addUnreadMarkIfNeeded
{
    dispatchOnMessageQueue(^
    {
        NSMutableArray *conversationItems = self.conversationItems;
        int count = conversationItems.count;
        
        int insertIndex = -1;
        int unreadCount = 0;
        bool cancelSearch = false;
        
        for (int i = 0; i < count; i++)
        {
            TGConversationItem *item = [conversationItems objectAtIndex:i];
            switch (item.type)
            {
                case TGConversationItemTypeUnread:
                {
                    insertIndex = -1;
                    cancelSearch = true;
                    break;
                }
                case TGConversationItemTypeMessage:
                {
                    TGMessage *message = ((TGConversationMessageItem *)item).message;
                    if (!message.outgoing && message.unread)
                    {
                        insertIndex = i + 1;
                        unreadCount++;
                    }
                    else
                    {
                        cancelSearch = true;
                        break;
                    }
                    break;
                }
                default:
                    break;
            }
            
            if (cancelSearch)
                break;
        }
        
        if (insertIndex >= 0 && unreadCount >= 10)
        {
            if (insertIndex < (int)conversationItems.count)
            {
                TGConversationMessageItem *nextItem = [conversationItems objectAtIndex:insertIndex];
                if (nextItem.type == TGConversationItemTypeDate)
                    insertIndex++;
            }
            
            TGConversationUnreadItem *unreadItem = [[TGConversationUnreadItem alloc] initWithUnreadCount:unreadCount];
            [conversationItems insertObject:unreadItem atIndex:insertIndex];
            
            dispatch_async(dispatch_get_main_queue(), ^
            {
                [self.conversationController conversationMessagesChanged:[[NSArray alloc] initWithObjects:[[NSNumber alloc] initWithInt:insertIndex], nil] insertedItems:[[NSArray alloc] initWithObjects:unreadItem, nil] removedAtIndices:nil updatedAtIndices:nil updatedItems:nil delay:false scrollDownFlags:4];
            });
        }
    }, false);
}

- (void)clearUnreadIfNeeded:(bool)force
{
    if (self.isBroadcast)
        return;
    
    dispatchOnMessageQueue(^
    {
        if (self.conversationItems.count == 0 || _conversationId == 0)
            return;
        
        bool hasOutgoing = false;
        
        NSMutableArray *conversationItems = self.conversationItems;
        int count = conversationItems.count;
        for (int i = 0; i < count; i++)
        {
            TGConversationItem *item = [conversationItems objectAtIndex:i];
            if (item.type == TGConversationItemTypeMessage)
            {
                TGConversationMessageItem *messageItem = (TGConversationMessageItem *)item;
                TGMessage *message = messageItem.message;
                bool outgoing = message.outgoing;
                if (!outgoing && message.unread)
                {
                    int mid = message.mid;
                    if (_minRemoteUnreadId == 0 || mid < _minRemoteUnreadId)
                        _minRemoteUnreadId = mid;
                    
                    if (message.unread)
                    {
                        messageItem = [messageItem copy];
                        messageItem.message.unread = false;
                        
                        [conversationItems replaceObjectAtIndex:i withObject:messageItem];
                    }
                }
                
                if (i == 0 && outgoing)
                    hasOutgoing = true;
            }
        }
        
        if (!_doNotRead || hasOutgoing)
        {
            int minRemoteUnreadId = _minRemoteUnreadId;
            
            dispatch_async(dispatch_get_main_queue(), ^
            {
                if (force || [self.conversationController shouldReadHistory])
                {
                    [ActionStageInstance() dispatchOnStageQueue:^
                    {
                        static int actionId = 1;
                        
                        [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/conversations/(%lld)/readHistory/(%d)", _conversationId, actionId++] options:[[NSDictionary alloc] initWithObjectsAndKeys:@(minRemoteUnreadId), @"minRemoteId", nil] watcher:self];
                    }];
                }
            });
        }
    }, false);
}

- (void)unloadOldItemsIfNeeded
{
    if (self.isBroadcast)
        return;
    
    dispatchOnMessageQueue(^
    {
        if (self.conversationItems.count > 180)
        {
            [self.conversationItems removeObjectsInRange:NSMakeRange(150, self.conversationItems.count - 150)];
            TGConversationItem *lastItem = [self.conversationItems lastObject];
            if (lastItem.type == TGConversationItemTypeMessage)
            {
                TGMessage *message = ((TGConversationMessageItem *)[self.conversationItems lastObject]).message;
                TGConversationDateItem *dateItem = [[TGConversationDateItem alloc] initWithDate:message.date];
                [self.conversationItems addObject:dateItem];
            }
            
            NSArray *items = [NSArray arrayWithArray:self.conversationItems];
            
            dispatch_async(dispatch_get_main_queue(), ^
            {
                self.canLoadMoreHistory = true;
                [self.conversationController conversationHistoryLoadingCompleted];
                [self.conversationController conversationHistoryFullyReloaded:items];
            });
        }
    }, false);
}

#undef TG_TIMESTAMP_DEFINE
#undef TG_TIMESTAMP_MEASURE

#define TG_TIMESTAMP_DEFINE(s)
#define TG_TIMESTAMP_MEASURE(s)

- (void)prepareInitialState
{
    if (!self.isBroadcast)
        self.isLoading = true;
    
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        TG_TIMESTAMP_DEFINE(updateState)
        
        [ActionStageInstance() watchForPath:@"downloadManagerStateChanged" watcher:self];
        [[TGDownloadManager instance] requestState:_actionHandle];
        
        TG_TIMESTAMP_MEASURE(updateState)
        
        if (!self.isBroadcast)
        {
            [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/conversation/(%lld)/state", _conversationId] options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithLongLong:_conversationId], @"conversationId", nil] watcher:self];
            
            if (self.isMultichat)
            {
                [ActionStageInstance() watchForPath:@"/tg/userdatachanges" watcher:self];
                [ActionStageInstance() watchForPath:@"/tg/userpresencechanges" watcher:self];
                [ActionStageInstance() watchForPath:@"/tg/contactlist" watcher:self];
                
                if (self.isEncrypted)
                {
                    if (self.singleParticipant == nil)
                    {
                        TGUser *user = [[TGDatabase instance] loadUser:(int)[self singleUserId]];
                        if (user != nil)
                            [self actorCompleted:ASStatusSuccess path:[NSString stringWithFormat:@"/tg/users/(%lld)", [self singleUserId]] result:[[TGUserNode alloc] initWithUser:user]];
                        else
                        {
                            [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/users/(%lld)", [self singleUserId]] options:nil watcher:self];
                        }
                    }
                    
                    [ActionStageInstance() watchForPath:[NSString stringWithFormat:@"/tg/peerSettings/(%lld)", [self singleUserId]] watcher:self];
                    [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/peerSettings/(%lld,cachedOnly)", [self singleUserId]] options:[NSDictionary dictionaryWithObject:[NSNumber numberWithLongLong:[self singleUserId]] forKey:@"peerId"] watcher:self];
                }
                else
                {
                    [ActionStageInstance() watchForPath:[NSString stringWithFormat:@"/tg/peerSettings/(%lld)", _conversationId] watcher:self];
                    [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/peerSettings/(%lld,cachedOnly)", _conversationId] options:[NSDictionary dictionaryWithObject:[NSNumber numberWithLongLong:_conversationId] forKey:@"peerId"] watcher:self];
                }
                
                if (_conversation == nil)
                {
                    [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/conversation/(%lld)/conversation", _conversationId] options:nil watcher:self];
                }
            }
            else
            {
                if (self.singleParticipant == nil)
                {
                    TGUser *user = [[TGDatabase instance] loadUser:(int)_conversationId];
                    if (user != nil)
                        [self actorCompleted:ASStatusSuccess path:[NSString stringWithFormat:@"/tg/users/(%lld)", _conversationId] result:[[TGUserNode alloc] initWithUser:user]];
                    else
                    {
                        [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/users/(%lld)", _conversationId] options:nil watcher:self];
                    }
                }
                
                [ActionStageInstance() watchForPath:@"/tg/userdatachanges" watcher:self];
                [ActionStageInstance() watchForPath:@"/tg/userpresencechanges" watcher:self];
                [ActionStageInstance() watchForPath:@"/tg/contactlist" watcher:self];
                [ActionStageInstance() watchForPath:[[NSString alloc] initWithFormat:@"/tg/userLink/(%lld)", [self singleUserId]] watcher:self];
                
                [ActionStageInstance() watchForPath:[NSString stringWithFormat:@"/tg/peerSettings/(%lld)", [self singleUserId]] watcher:self];
                [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/peerSettings/(%lld,cachedOnly)", [self singleUserId]] options:[NSDictionary dictionaryWithObject:[NSNumber numberWithLongLong:[self singleUserId]] forKey:@"peerId"] watcher:self];
            }
        
            dispatchOnMessageQueue(^
            {
                if (self.conversationItems.count == 0)
                {
                    [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/conversations/(%lld)/history/(up0)", _conversationId] options:
                     @{
                        @"limit" : @([TGViewController isWidescreen] ? 50 : 12),
                        @"loadUnread": @((bool)(self.messagesToForward.count == 0)),
                        @"loadAtMessageId": @(_openAtMessageId),
                        @"isEncrypted": @(self.isEncrypted)
                     } watcher:self];
                }
            }, false);
            
            TG_TIMESTAMP_MEASURE(updateState)
        }
        else
        {
            [self updateTitle];
            [self updateSubtitle];
        }
        
        NSString *title = self.conversationTitle;
        NSString *subtitle = self.conversationSubtitle;
        NSString *typingSubtitle = self.conversationTypingSubtitle;
        bool isContact = _isContact;
        
        dispatchOnMessageQueue(^
        {
            std::tr1::shared_ptr<std::map<int, float> > pMessageUploadProgress = [self messageUploadProgressCopy];
            
            if ([ActionStageInstance() requestActorStateNow:@"/tg/service/updatestate"])
            {
                dispatch_async(dispatch_get_main_queue(), ^
                {
                    [self.conversationController conversationTitleChanged:title subtitle:subtitle typingSubtitle:typingSubtitle isContact:isContact];
                    [self.conversationController conversationMessageUploadProgressChanged:pMessageUploadProgress];
                });
            }
            else
            {
                dispatch_async(dispatch_get_main_queue(), ^
                {
                    [self.conversationController conversationMessageUploadProgressChanged:pMessageUploadProgress];
                });
            }
        }, false);
    }];
}

- (void)sendMessageIfAny
{
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        if (_messagesToForward != nil && _messagesToForward.count != 0)
        {
            NSMutableArray *messages = [[NSMutableArray alloc] init];
            for (TGMessage *message in _messagesToForward)
            {
                NSMutableDictionary *messageDesc = [[NSMutableDictionary alloc] init];
                if (message.text != nil)
                    [messageDesc setObject:message.text forKey:@"text"];
                if (message.mediaAttachments != nil)
                    [messageDesc setObject:message.mediaAttachments forKey:@"existingAttachments"];
                [messages addObject:messageDesc];
            }
            
            [self sendMessages:messages clearText:false];
            
            _messagesToForward = nil;
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^
            {
                [self.conversationController timeToLoadMoreHistory];
            });
        }
    }];
}

- (void)loadMoreHistory
{
    if (self.isBroadcast)
        return;
    
    self.isLoading = true;
    
    dispatchOnMessageQueue(^
    {
        int remoteMessagesProcessed = 0;
        int minMid = INT_MAX;
        int minLocalMid = INT_MAX;
        int index = 0;
        int minDate = INT_MAX;
        
        NSMutableArray *conversationItems = self.conversationItems;
        
        for (int i = conversationItems.count - 1; i >= 0 && remoteMessagesProcessed < 200; i--)
        {
            TGConversationItem *item = [conversationItems objectAtIndex:i];
            if (item.type == TGConversationItemTypeMessage)
            {
                TGMessage *message = ((TGConversationMessageItem *)item).message;
                if (message.mid < TGMessageLocalMidBaseline)
                {
                    remoteMessagesProcessed++;
                    if (message.mid < minMid)
                        minMid = message.mid;
                    index++;
                }
                else
                {
                    if (message.mid < minLocalMid)
                        minLocalMid = message.mid;
                }
                
                if ((int)message.date < minDate)
                    minDate = (int)message.date;
            }
        }
        
        if (minMid == INT_MAX)
            minMid = 0;
        if (minLocalMid == INT_MAX)
            minLocalMid = 0;
        if (minDate == INT_MAX)
            minDate = 0;
        
        [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/conversations/(%lld)/history/(up%d)", _conversationId, minMid] options:@{
            @"maxMid": @(minMid),
            @"maxLocalMid": @(minLocalMid),
            @"offset": @(index),
            @"maxDate": @(minDate),
            @"isEncrypted": @(self.isEncrypted)
         } watcher:self];
    }, false);
}

- (void)loadMoreHistoryDownwards
{
    if (self.isBroadcast)
        return;
    
    self.isLoadingDownwards = true;
    
    dispatchOnMessageQueue(^
    {
        int remoteMessagesProcessed = 0;
        int maxMid = INT_MIN;
        int maxLocalMid = INT_MIN;
        int maxDate = INT_MIN;
        
        NSMutableArray *conversationItems = self.conversationItems;
        int count = conversationItems.count;
        
        for (int i = 0; i < count && remoteMessagesProcessed < 40; i++)
        {
            TGConversationItem *item = [conversationItems objectAtIndex:i];
            if (item.type == TGConversationItemTypeMessage)
            {
                TGMessage *message = ((TGConversationMessageItem *)item).message;
                if (message.mid < TGMessageLocalMidBaseline)
                {
                    remoteMessagesProcessed++;
                    if (message.mid > maxMid)
                        maxMid = message.mid;
                }
                else
                {
                    if (message.mid > maxLocalMid)
                        maxLocalMid = message.mid;
                }
                
                if ((int)message.date > maxDate)
                    maxDate = (int)message.date;
            }
        }
        
        if (maxMid == INT_MIN)
            maxMid = 0;
        if (maxLocalMid == INT_MIN)
            maxLocalMid = 0;
        if (maxDate == INT_MIN)
            maxDate = 0;
        
        [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/conversations/(%lld)/history/(down%d)", _conversationId, maxMid] options:@{
            @"maxMid": @(maxMid),
            @"maxLocalMid": @(maxLocalMid),
            @"maxDate": @(maxDate),
            @"downwards": @(true),
            @"isEncrypted": @(self.isEncrypted)
         } watcher:self];
    }, false);
}

- (void)reloadHistoryShortcut
{
    dispatchOnMessageQueue(^
    {
        [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/conversations/(%lld)/history/(up0)", _conversationId] options:
         @{
            @"limit" : @([TGViewController isWidescreen] ? 50 : 12),
            @"loadUnread": @(false),
            @"clearExisting": @(true),
            @"isEncrypted": @(self.isEncrypted)
         } watcher:self];
    }, false);
}

- (bool)isAssetUrlOnServer:(NSString *)assetUrl
{
    return [TGImageDownloadActor serverMediaDataForAssetUrl:assetUrl] != nil;
}

- (TGImageInputMediaAttachment *)createImageAttachmentFromImage:(UIImage *)image assetUrl:(NSString *)assetUrl
{
    if (image == nil)
        return nil;
    
    TGLog(@"assetUrl: %@", assetUrl);
    
    TGImageInputMediaAttachment *imageAttachment = [[TGImageInputMediaAttachment alloc] init];
    
    NSDictionary *serverData = self.isEncrypted ? nil : [TGImageDownloadActor serverMediaDataForAssetUrl:assetUrl];
    if (serverData != nil)
    {
        if ([serverData objectForKey:@"imageId"] != nil && [serverData objectForKey:@"imageAttachment"] != nil)
        {
            imageAttachment.serverImageAttachment = [serverData objectForKey:@"imageAttachment"];
            imageAttachment.serverImageId = imageAttachment.serverImageAttachment.imageId;
            imageAttachment.serverAccessHash = imageAttachment.serverImageAttachment.accessHash;
        }
    }
    else
    {
        CGSize originalSize = image.size;
        originalSize.width *= image.scale;
        originalSize.height *= image.scale;
        
        imageAttachment.imageSize = TGFitSize(originalSize, CGSizeMake(800, 800));
        imageAttachment.thumbnailSize = TGFitSize(originalSize, CGSizeMake(90, 90));
        
        UIImage *fullImage = TGScaleImageToPixelSize(image, imageAttachment.imageSize);
        imageAttachment.imageData = UIImageJPEGRepresentation(fullImage, 0.87f);
        
        UIImage *previewImage = TGScaleImageToPixelSize(fullImage, TGFitSize(originalSize, [TGConversationController preferredInlineThumbnailSize]));
        imageAttachment.thumbnailData = UIImageJPEGRepresentation(previewImage, 0.9f);
        previewImage = nil;
        fullImage = nil;
        
        imageAttachment.assetUrl = assetUrl.length == 0 ? nil : assetUrl;
    }
    
    return imageAttachment;
}

- (TGVideoInputMediaAttachment *)createVideoAttachmentFromVideo:(NSString *)fileName thumbnailImage:(UIImage *)thumbnailImage duration:(int)duration dimensions:(CGSize)dimensions assetUrl:(NSString *)assetUrl
{
    NSDictionary *serverData = self.isEncrypted ? nil : [TGImageDownloadActor serverMediaDataForAssetUrl:assetUrl];
    if (serverData != nil)
    {
        if ([serverData objectForKey:@"videoAttachment"])
        {
            TGVideoInputMediaAttachment *videoAttachment = [[TGVideoInputMediaAttachment alloc] init];
            videoAttachment.serverVideoAttachment = [serverData objectForKey:@"videoAttachment"];
            
            return videoAttachment;
        }
    }

    if (fileName == nil || thumbnailImage == nil)
        return nil;

    TGVideoInputMediaAttachment *videoAttachment = [[TGVideoInputMediaAttachment alloc] init];

    videoAttachment.thumbnailSize = thumbnailImage.size;
    videoAttachment.thumbnailData = UIImageJPEGRepresentation(thumbnailImage, 0.87f);

    videoAttachment.tmpFilePath = fileName;

    videoAttachment.duration = duration;
    videoAttachment.dimensions = dimensions;

    videoAttachment.assetUrl = assetUrl.length == 0 ? nil : assetUrl;

    return videoAttachment;
}

- (TGMessage *)prepareMessageForSending:(NSString *)text attachments:(NSArray *)attachments prevoiusMessage:(TGMessage *)previousMessage mediaToSend:(NSMutableArray *)mediaToSend newMessageDate:(int)newMessageDate guid:(NSString *)guid
{
    TGLocalMessageMetaMediaAttachment *mediaMeta = [[TGLocalMessageMetaMediaAttachment alloc] init];
    bool mediaMetaRequired = false;
    
    TGMessage *newMessage = [[TGMessage alloc] init];
    newMessage.cid = self.conversationId;
    newMessage.local = true;
    newMessage.outgoing = true;
    newMessage.unread = true;
    newMessage.deliveryState = TGMessageDeliveryStatePending;
    newMessage.date = newMessageDate;
    newMessage.fromUid = TGTelegraphInstance.clientUserId;
    newMessage.toUid = _conversationId;
    newMessage.text =  text == nil ? @"" : text;
    
    if (self.isEncrypted)
    {
        int64_t randomId = 0;
        arc4random_buf(&randomId, 8);
        newMessage.randomId = randomId;
    }
    
    static NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true) objectAtIndex:0];

    NSString *tmpImagesPath = [documentsDirectory stringByAppendingPathComponent:@"upload"];
    NSString *videosPath = [documentsDirectory stringByAppendingPathComponent:@"video"];
    NSFileManager *fileManager = [ActionStageInstance() globalFileManager];
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        NSError *error = nil;
        [fileManager createDirectoryAtPath:tmpImagesPath withIntermediateDirectories:true attributes:nil error:&error];
        [fileManager createDirectoryAtPath:videosPath withIntermediateDirectories:true attributes:nil error:&error];
    });
    
    NSMutableArray *messageAttachments = [[NSMutableArray alloc] init];
    if (newMessage.mediaAttachments != nil)
        [messageAttachments addObjectsFromArray:newMessage.mediaAttachments];
    
    if (previousMessage != nil)
    {
        if (previousMessage.mid != 0 || previousMessage.localMid != 0)
        {
            newMessage.mid = previousMessage.mid;
            newMessage.localMid = previousMessage.localMid;
        }
        
        if (previousMessage.mediaAttachments != nil)
            [messageAttachments addObjectsFromArray:previousMessage.mediaAttachments];
    }
    
    if (attachments != nil && attachments.count != 0)
    {
        int attachmentIndex = -1;
        for (TGInputMediaAttachment *attachment in attachments)
        {
            attachmentIndex++;
            
            if ([attachment isKindOfClass:[TGImageInputMediaAttachment class]])
            {
                TGImageInputMediaAttachment *imageAttachment = (TGImageInputMediaAttachment *)attachment;
                
                if (imageAttachment.image != nil)
                {
                    CGSize originalSize = imageAttachment.image.size;
                    originalSize.width *= imageAttachment.image.scale;
                    originalSize.height *= imageAttachment.image.scale;
                    
                    CGSize fullSize = TGFitSize(originalSize, CGSizeMake(800, 800));
                    CGSize previewSize = TGFitSize(originalSize, CGSizeMake(90, 90));
                    CGSize previewRealSize = TGFitSize(originalSize, [TGConversationController preferredInlineThumbnailSize]);

                    UIImage *previewImage = TGScaleImageToPixelSize(imageAttachment.image, previewRealSize);
                    NSData *previewImageData = UIImageJPEGRepresentation(previewImage, 0.9f);
                    previewImage = nil;
                    
                    UIImage *fullImage = TGScaleImageToPixelSize(imageAttachment.image, fullSize);
                    NSData *fullImageData = UIImageJPEGRepresentation(fullImage, 0.87f);
                    fullImage = nil;
                    
                    NSString *previewFilePath = [tmpImagesPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%dp.bin", guid, attachmentIndex]];
                    [previewImageData writeToFile:previewFilePath atomically:false];
                    NSString *previewUrl = [NSString stringWithFormat:@"upload/%@-%dp.bin", guid, attachmentIndex];
                    
                    NSString *fullFilePath = [tmpImagesPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%df.bin", guid, attachmentIndex]];
                    [fullImageData writeToFile:fullFilePath atomically:false];
                    NSString *fullUrl = [NSString stringWithFormat:@"upload/%@-%df.bin", guid, attachmentIndex];
                    
                    TGImageMediaAttachment *nativeAttachment = [[TGImageMediaAttachment alloc] init];
                    nativeAttachment.imageId = 0;
                    nativeAttachment.date = (int)(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970 + [self offsetFromGMT]);
                    nativeAttachment.hasLocation = false;
                    TGImageInfo *imageInfo = [[TGImageInfo alloc] init];
                    [imageInfo addImageWithSize:previewSize url:previewUrl];
                    [imageInfo addImageWithSize:fullSize url:fullUrl];
                    nativeAttachment.imageInfo = imageInfo;
                    
                    [messageAttachments addObject:nativeAttachment];
                    
                    TGImageInputMediaAttachment *preparedAttachment = [[TGImageInputMediaAttachment alloc] init];
                    preparedAttachment.imageData = fullImageData;
                    [mediaToSend addObject:preparedAttachment];
                    
                    mediaMetaRequired = true;
                    [mediaMeta.imageInfoList addObject:imageInfo];
                    
                    [mediaMeta.imageUrlToDataFile setObject:previewFilePath forKey:previewUrl];
                    [mediaMeta.imageUrlToDataFile setObject:fullFilePath forKey:fullUrl];
                }
                else if (imageAttachment.serverImageAttachment != nil && imageAttachment.serverImageId != 0 && imageAttachment.serverAccessHash != 0)
                {
                    [messageAttachments addObject:imageAttachment.serverImageAttachment];
                    
                    TGImageInputMediaAttachment *preparedAttachment = [[TGImageInputMediaAttachment alloc] init];
                    preparedAttachment.assetUrl = imageAttachment.assetUrl;
                    preparedAttachment.serverImageId = imageAttachment.serverImageId;
                    preparedAttachment.serverAccessHash = imageAttachment.serverAccessHash;
                    [mediaToSend addObject:preparedAttachment];
                }
                else if (imageAttachment.imageData != nil && imageAttachment.thumbnailData != nil)
                {   
                    NSString *previewFilePath = [tmpImagesPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%dp.bin", guid, attachmentIndex]];
                    [imageAttachment.thumbnailData writeToFile:previewFilePath atomically:false];
                    NSString *previewUrl = [NSString stringWithFormat:@"upload/%@-%dp.bin", guid, attachmentIndex];
                    
                    NSString *fullFilePath = [tmpImagesPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%df.bin", guid, attachmentIndex]];
                    [imageAttachment.imageData writeToFile:fullFilePath atomically:false];
                    NSString *fullUrl = [NSString stringWithFormat:@"upload/%@-%df.bin", guid, attachmentIndex];
                    
                    TGImageMediaAttachment *nativeAttachment = [[TGImageMediaAttachment alloc] init];
                    nativeAttachment.imageId = imageAttachment.serverImageId;
                    nativeAttachment.date = (int)(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970 + [self offsetFromGMT]);
                    nativeAttachment.hasLocation = false;
                    TGImageInfo *imageInfo = [[TGImageInfo alloc] init];
                    [imageInfo addImageWithSize:imageAttachment.thumbnailSize url:previewUrl];
                    [imageInfo addImageWithSize:imageAttachment.imageSize url:fullUrl];
                    nativeAttachment.imageInfo = imageInfo;
                    
                    [messageAttachments addObject:nativeAttachment];
                    
                    TGImageInputMediaAttachment *preparedAttachment = [[TGImageInputMediaAttachment alloc] init];
                    preparedAttachment.imageData = imageAttachment.imageData;
                    preparedAttachment.assetUrl = imageAttachment.assetUrl;
                    preparedAttachment.serverImageId = imageAttachment.serverImageId;
                    preparedAttachment.serverAccessHash = imageAttachment.serverAccessHash;
                    [mediaToSend addObject:preparedAttachment];
                    
                    mediaMetaRequired = true;
                    [mediaMeta.imageInfoList addObject:imageInfo];
                    
                    [mediaMeta.imageUrlToDataFile setObject:previewFilePath forKey:previewUrl];
                    [mediaMeta.imageUrlToDataFile setObject:fullFilePath forKey:fullUrl];
                }
            }
            else if ([attachment isKindOfClass:[TGVideoInputMediaAttachment class]])
            {
                TGVideoInputMediaAttachment *videoAttachment = (TGVideoInputMediaAttachment *)attachment;
                
                if (videoAttachment.serverVideoAttachment != nil)
                {
                    [messageAttachments addObject:videoAttachment.serverVideoAttachment];
                    
                    TGVideoInputMediaAttachment *videoInputAttachment = [[TGVideoInputMediaAttachment alloc] init];
                    videoInputAttachment.serverVideoId = videoAttachment.serverVideoAttachment.videoId;
                    videoInputAttachment.serverAccessHash = videoAttachment.serverVideoAttachment.accessHash;
                    
                    [mediaToSend addObject:videoInputAttachment];
                }
                else
                {
                    TGVideoMediaAttachment *nativeAttachment = [[TGVideoMediaAttachment alloc] init];
                    
                    int64_t localVideoId = 0;
                    arc4random_buf(&localVideoId, 8);
                    
                    NSString *uploadVideoFile = [videosPath stringByAppendingPathComponent:[[NSString alloc] initWithFormat:@"local%llx.mov", localVideoId]];
                    [[ActionStageInstance() globalFileManager] moveItemAtPath:videoAttachment.tmpFilePath toPath:uploadVideoFile error:nil];
                    
                    nativeAttachment.localVideoId = localVideoId;
                    videoAttachment.localVideoId = localVideoId;
                    
                    nativeAttachment.duration = videoAttachment.duration;
                    nativeAttachment.dimensions = videoAttachment.dimensions;
                    
                    TGVideoInfo *videoInfo = [[TGVideoInfo alloc] init];
                    [videoInfo addVideoWithQuality:1 url:[[NSString alloc] initWithFormat:@"local-video:local%llx.mov", localVideoId] size:videoAttachment.size];
                    
                    nativeAttachment.videoInfo = videoInfo;
                    
                    [[TGRemoteImageView sharedCache] cacheImage:nil withData:videoAttachment.previewData url:[[NSString alloc] initWithFormat:@"video-thumbnail-local%llx.jpg", localVideoId] availability:TGCacheDisk];
                    
                    NSString *previewFilePath = [tmpImagesPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%dp.bin", guid, attachmentIndex]];
                    [videoAttachment.thumbnailData writeToFile:previewFilePath atomically:false];
                    NSString *previewUrl = [NSString stringWithFormat:@"upload/%@-%dp.bin", guid, attachmentIndex];
                    
                    TGImageInfo *thumbnailInfo = [[TGImageInfo alloc] init];
                    [thumbnailInfo addImageWithSize:videoAttachment.thumbnailSize url:previewUrl];
                    nativeAttachment.thumbnailInfo = thumbnailInfo;
                    
                    [messageAttachments addObject:nativeAttachment];
                    
                    [mediaToSend addObject:videoAttachment];
                    
                    mediaMetaRequired = true;
                    [mediaMeta.imageInfoList addObject:thumbnailInfo];
                    
                    [mediaMeta.imageUrlToDataFile setObject:previewFilePath forKey:previewUrl];
                }
            }
            else if ([attachment isKindOfClass:[TGLocationInputMediaAttachment class]])
            {
                TGLocationInputMediaAttachment *locationAttachment = (TGLocationInputMediaAttachment *)attachment;
                
                TGLocationMediaAttachment *nativeAttachment = [[TGLocationMediaAttachment alloc] init];
                nativeAttachment.latitude = locationAttachment.latitude;
                nativeAttachment.longitude = locationAttachment.longitude;
                [messageAttachments addObject:nativeAttachment];
                
                [mediaToSend addObject:locationAttachment];
            }
            else if ([attachment isKindOfClass:[TGContactInputMediaAttachment class]])
            {
                TGContactInputMediaAttachment *contactAttachment = (TGContactInputMediaAttachment *)attachment;
                
                TGContactMediaAttachment *nativeAttachment = [[TGContactMediaAttachment alloc] init];
                nativeAttachment.uid = contactAttachment.uid;
                nativeAttachment.firstName = contactAttachment.firstName;
                nativeAttachment.lastName = contactAttachment.lastName;
                nativeAttachment.phoneNumber = contactAttachment.phoneNumber;
                [messageAttachments addObject:nativeAttachment];
                
                [mediaToSend addObject:contactAttachment];
            }
        }
    }
    else if (previousMessage != nil && previousMessage.mediaAttachments != nil && previousMessage.mediaAttachments.count != 0)
    {
        for (TGMediaAttachment *attachment in previousMessage.mediaAttachments)
        {
            if (attachment.type == (int)TGLocalMessageMetaMediaAttachmentType)
            {
                mediaMeta = (TGLocalMessageMetaMediaAttachment *)attachment;
                break;
            }
        }
        
        for (TGMediaAttachment *attachment in previousMessage.mediaAttachments)
        {
            if (attachment.type == TGImageMediaAttachmentType)
            {
                TGImageMediaAttachment *imageAttachment = (TGImageMediaAttachment *)attachment;
                if (imageAttachment.imageId != 0)
                {
                    TGImageInputMediaAttachment *preparedAttachment = [[TGImageInputMediaAttachment alloc] init];
                    preparedAttachment.serverImageId = imageAttachment.imageId;
                    preparedAttachment.serverAccessHash = imageAttachment.accessHash;
                    [mediaToSend addObject:preparedAttachment];
                }
                else
                {
                    NSString *localUrl = [imageAttachment.imageInfo closestImageUrlWithSize:CGSizeMake(800, 800) resultingSize:NULL];
                    if (localUrl != nil)
                    {
                        NSString *filePath = [mediaMeta.imageUrlToDataFile objectForKey:localUrl];
                        if (filePath != nil)
                        {
                            NSData *fileData = [NSData dataWithContentsOfFile:filePath options:0 error:NULL];
                            if (fileData != nil)
                            {
                                TGImageInputMediaAttachment *preparedAttachment = [[TGImageInputMediaAttachment alloc] init];
                                preparedAttachment.imageData = fileData;
                                [mediaToSend addObject:preparedAttachment];
                            }
                        }
                    }
                }
            }
            else if (attachment.type == TGVideoMediaAttachmentType)
            {
                TGVideoMediaAttachment *videoAttachment = (TGVideoMediaAttachment *)attachment;
                
                if (videoAttachment.videoId != 0)
                {
                    TGVideoInputMediaAttachment *inputAttachment = [[TGVideoInputMediaAttachment alloc] init];
                    
                    inputAttachment.serverVideoId = videoAttachment.videoId;
                    inputAttachment.serverAccessHash = videoAttachment.accessHash;
                    
                    inputAttachment.duration = videoAttachment.duration;
                    
                    [mediaToSend addObject:inputAttachment];
                }
                else if (videoAttachment.localVideoId != 0)
                {
                    TGVideoInputMediaAttachment *inputAttachment = [[TGVideoInputMediaAttachment alloc] init];
                    
                    inputAttachment.localVideoId = videoAttachment.localVideoId;
                    
                    CGSize thumbnailSize = CGSizeZero;
                    NSString *thumbnailUrl = [videoAttachment.thumbnailInfo closestImageUrlWithSize:CGSizeMake(90, 90) resultingSize:&thumbnailSize];
                    inputAttachment.thumbnailData = [[NSData alloc] initWithContentsOfFile:[documentsDirectory stringByAppendingPathComponent:thumbnailUrl]];
                    inputAttachment.thumbnailSize = thumbnailSize;
                    
                    inputAttachment.duration = videoAttachment.duration;
                    inputAttachment.dimensions = videoAttachment.dimensions;
                    
                    [mediaToSend addObject:inputAttachment];
                }
            }
            else if (attachment.type == TGLocationMediaAttachmentType)
            {
                TGLocationMediaAttachment *locationAttachment = (TGLocationMediaAttachment *)attachment;
                TGLocationInputMediaAttachment *preparedAttachment = [[TGLocationInputMediaAttachment alloc] init];
                preparedAttachment.latitude = locationAttachment.latitude;
                preparedAttachment.longitude = locationAttachment.longitude;
                [mediaToSend addObject:preparedAttachment];
            }
            else if (attachment.type == TGContactMediaAttachmentType)
            {
                TGContactMediaAttachment *contactAttachment = (TGContactMediaAttachment *)attachment;
                
                TGContactInputMediaAttachment *preparedAttachment = [[TGContactInputMediaAttachment alloc] init];
                preparedAttachment.uid = contactAttachment.uid;
                preparedAttachment.firstName = contactAttachment.firstName;
                preparedAttachment.lastName = contactAttachment.lastName;
                preparedAttachment.phoneNumber = contactAttachment.phoneNumber;
                [mediaToSend addObject:preparedAttachment];
            }
            else if (attachment.type == TGForwardedMessageMediaAttachmentType)
            {
                TGForwardedMessageMediaAttachment *forwardedMessageAttachment = (TGForwardedMessageMediaAttachment *)attachment;
                
                TGForwardedMessageInputMediaAttachment *preparedAttachment = [[TGForwardedMessageInputMediaAttachment alloc] init];
                preparedAttachment.forwardMid = forwardedMessageAttachment.forwardMid;
                [mediaToSend addObject:preparedAttachment];
            }
        }
    }
    
    if (mediaMetaRequired && mediaMeta.localMediaId == 0)
    {
        int mediaId = arc4random();
        mediaMeta.localMediaId = mediaId;
    }
    
    if (mediaMetaRequired && ![messageAttachments containsObject:mediaMeta])
        [messageAttachments addObject:mediaMeta];
    
    newMessage.mediaAttachments = messageAttachments;
    
    return newMessage;
}

- (void)sendMessage:(NSString *)text attachments:(NSArray *)attachments clearText:(bool)clearText
{
    if (clearText)
        _lastTypingActivityDate = 0;
    
    NSMutableArray *messageArray = [[NSMutableArray alloc] initWithCapacity:1];
    
    if (attachments != nil)
    {
        NSMutableDictionary *messageDesc = [[NSMutableDictionary alloc] init];
        [messageDesc setObject:attachments forKey:@"attachments"];
        [messageArray addObject:messageDesc];
    }
    
    if (text.length != 0)
    {
        const int maxTextSize = 1024 * 4;
        
        if (text.length <= maxTextSize)
        {
            NSMutableDictionary *messageDesc = [[NSMutableDictionary alloc] init];
            if (text != nil)
                [messageDesc setObject:text forKey:@"text"];
            [messageArray addObject:messageDesc];
        }
        else
        {
            for (int i = 0; i < (int)text.length; i += maxTextSize)
            {
                NSMutableDictionary *messageDesc = [[NSMutableDictionary alloc] init];
                
                NSString *currentText = [text substringWithRange:NSMakeRange(i, MIN(maxTextSize, text.length - i))];
                
                if (currentText != nil)
                    [messageDesc setObject:currentText forKey:@"text"];
                
                [messageArray addObject:messageDesc];
            }
        }
    }

    [self sendMessages:messageArray clearText:clearText];
}

- (void)sendMediaMessages:(NSArray *)attachments clearText:(bool)clearText
{
    if (clearText)
        _lastTypingActivityDate = 0;
    
    NSMutableArray *messagesToSend = [[NSMutableArray alloc] init];
    
    for (NSArray *attachmentsDesc in attachments)
    {
        NSMutableDictionary *messageDesc = [[NSMutableDictionary alloc] init];
        if (attachments != nil)
            [messageDesc setObject:attachmentsDesc forKey:@"attachments"];
        
        [messagesToSend addObject:messageDesc];
    }
    [self sendMessages:messagesToSend clearText:clearText];
}

- (void)sendMessages:(NSArray *)inputMessages clearText:(bool)clearText
{
    if (clearText)
    {
        TGLog(@"[sendMessages:0x%x, %d]", (int)inputMessages, inputMessages.count);
        [self.conversationController disableSendButton:true];
    }
    
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        static unsigned int randomSeed = 0;
        if (randomSeed == 0)
            randomSeed = (unsigned int)CFAbsoluteTimeGetCurrent();
        int randomValue = rand_r(&randomSeed);
        
        NSMutableArray *newMessages = [[NSMutableArray alloc] init];
        NSMutableArray *newMessageActions = [[NSMutableArray alloc] init];
        
        for (NSDictionary *messageDesc in inputMessages)
        {
            int newMessageDate = (int)([[NSDate date] timeIntervalSince1970] + [self offsetFromGMT] - [[NSTimeZone localTimeZone] secondsFromGMT]);
            
            NSString *text = [messageDesc objectForKey:@"text"];
            NSArray *attachments = [messageDesc objectForKey:@"attachments"];
            NSArray *existingAttachments = [messageDesc objectForKey:@"existingAttachments"];
            
            NSString *guid = [NSString stringWithFormat:@"%x%x%x%x", (int)(CFAbsoluteTimeGetCurrent()), randomValue, (int)text, (int)attachments];
            
            NSMutableArray *mediaToSend = [[NSMutableArray alloc] init];
            TGMessage *previousMessage = [[TGMessage alloc] init];
            previousMessage.text = text;
            previousMessage.mediaAttachments = existingAttachments;
            TGMessage *newMessage = [self prepareMessageForSending:text attachments:attachments prevoiusMessage:previousMessage mediaToSend:mediaToSend newMessageDate:newMessageDate guid:guid];
            
            [newMessages addObject:newMessage];
            
            NSString *messageText = text;
            if (messageText == nil)
                messageText = @"";
            
            NSMutableDictionary *options = [[NSMutableDictionary alloc] init];
            if (self.isBroadcast)
                [options setObject:_broadcastUids forKey:@"broadcastUids"];
            else
                [options setObject:[NSNumber numberWithLongLong:_conversationId] forKey:@"conversationId"];
            [options setObject:guid forKey:@"guid"];
            [options setObject:messageText forKey:@"messageText"];
            if (mediaToSend.count != 0)
                [options setObject:mediaToSend forKey:@"media"];
            for (TGMediaAttachment *attachment in newMessage.mediaAttachments)
            {
                if ([attachment isKindOfClass:[TGLocalMessageMetaMediaAttachment class]])
                {
                    [options setObject:attachment forKey:@"messageMeta"];
                }
            }
            
            [newMessageActions addObject:[NSDictionary dictionaryWithObjectsAndKeys:newMessage, @"message", options, @"options", nil]];
        }
        
        if (!self.isBroadcast)
            [[TGDatabase instance] addMessagesToConversation:newMessages conversationId:_conversationId updateConversation:nil dispatch:true countUnread:false];
        else
        {
            for (TGMessage *message in newMessages)
            {
                if (message.local)
                {
                    message.mid = nextBroadcastMid;
                    message.localMid = nextBroadcastMid;
                    
                    nextBroadcastMid++;
                }
            }
        }
        
        dispatchOnMessageQueue(^
        {
            _sendingMessages = true;
            _sendingMessagesClearText = clearText;
            [self actionStageResourceDispatched:[NSString stringWithFormat:@"/tg/conversation/(%@)/messages", _dispatchConversationTag] resource:[[SGraphObjectNode alloc] initWithObject:newMessages] arguments:nil];
            _sendingMessagesClearText = false;
            _sendingMessages = false;
        }, false);
        
        for (NSDictionary *messageAction in newMessageActions)
        {
            TGMessage *newMessage = [messageAction objectForKey:@"message"];
            NSMutableDictionary *options = [messageAction objectForKey:@"options"];
            [options setObject:[NSNumber numberWithInt:newMessage.mid] forKey:@"localMid"];
            options[@"isEncrypted"] = @(self.isEncrypted);
            options[@"date"] = @(newMessage.date);
            options[@"encryptedConversationId"] = @(_conversation.encryptedData.encryptedConversationId);
            options[@"accessHash"] = @(_conversation.encryptedData.accessHash);
            
            [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/conversations/(%@)/sendMessage/(%d)", _dispatchConversationTag, newMessage.mid] options:options watcher:self];
            [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/conversations/(%@)/sendMessage/(%d)", _dispatchConversationTag, newMessage.mid] options:options watcher:TGTelegraphInstance];
        }
        
        if (clearText)
            [self.conversationController disableSendButton:false];
    }];
}

- (void)retryAllMessages
{
    dispatchOnMessageQueue(^
    {
        NSMutableArray *mids = [[NSMutableArray alloc] init];
        
        for (TGConversationItem *item in self.conversationItems)
        {
            if (item.type == TGConversationItemTypeMessage)
            {
                TGConversationMessageItem *messageItem = (TGConversationMessageItem *)item;
                if (messageItem.message.deliveryState == TGMessageDeliveryStateFailed && messageItem.message.mid >= TGMessageLocalMidBaseline)
                    [mids addObject:[[NSNumber alloc] initWithInt:messageItem.message.mid]];
            }
        }
        
        if (mids.count != 0)
            [self retryMessages:mids];
    }, false);
}

- (void)retryMessages:(NSArray *)mids
{
    dispatchOnMessageQueue(^
    {
        std::set<int> midsToRetry;
        for (NSNumber *nMid in mids)
            midsToRetry.insert([nMid intValue]);
        
        NSMutableArray *addedMessages = [[NSMutableArray alloc] init];
        
        NSMutableArray *deletedIndices = [[NSMutableArray alloc] init];
        NSMutableArray *deletedMids = [[NSMutableArray alloc] init];
        
        NSMutableArray *conversationItems = self.conversationItems;
        
        int index = -1;
        int itemsCount = conversationItems.count;
        for (int i = 0; i < itemsCount; i++)
        {
            index++;
            
            TGConversationItem *item = [conversationItems objectAtIndex:i];
            if (item.type == TGConversationItemTypeMessage)
            {
                TGMessage *message = ((TGConversationMessageItem *)item).message;
                if (midsToRetry.find(message.mid) != midsToRetry.end())
                {
                    TGMessage *currentMessage = [message copy];
                    [addedMessages addObject:currentMessage];
                    
                    [deletedIndices addObject:[NSNumber numberWithInt:index]];
                    [deletedMids addObject:[NSNumber numberWithInt:message.mid]];
                    [conversationItems removeObjectAtIndex:i];
                    
                    i--;
                    itemsCount--;
                    
                    if (i + 1 < itemsCount)
                    {
                        TGConversationItem *nextItem = [conversationItems objectAtIndex:(i + 1)];
                        TGConversationItem *prevItem = nil;
                        if (i >= 0)
                            prevItem = [conversationItems objectAtIndex:i];
                        
                        if (nextItem.type == TGConversationItemTypeDate && (prevItem == nil || prevItem.type != TGConversationItemTypeMessage))
                        {
                            [deletedIndices addObject:[NSNumber numberWithInt:(index + 1)]];
                            [conversationItems removeObjectAtIndex:(i + 1)];
                            
                            itemsCount--;
                        }
                    }
                }
            }
        }
        
        NSMutableArray *insertedIndices = [[NSMutableArray alloc] init];
        NSMutableArray *insertedItems = [[NSMutableArray alloc] init];
        
        int newMessageDate = (int)([[NSDate date] timeIntervalSince1970] + [self offsetFromGMT] - [NSTimeZone localTimeZone].secondsFromGMT);
        bool addDateItem = false;
        if (conversationItems.count == 0)
            addDateItem = true;
        else
        {
            TGConversationItem *lastItem = [conversationItems objectAtIndex:0];
            if (lastItem.type == TGConversationItemTypeMessage)
            {
                TGMessage *lastItemMessage = ((TGConversationMessageItem *)lastItem).message;
                int messageDayDate = (int)(lastItemMessage.date + [self offsetFromGMT]);
                if ((newMessageDate + [self offsetFromGMT]) / (24 * 60 * 60) != messageDayDate / (24 * 60 * 60))
                {
                    addDateItem = true;
                }
            }
        }
        
        TGConversationController *controller = self.conversationController;
        int dateInsertIndex = addedMessages.count;
        int nextInsertIndex = addedMessages.count - 1;
        
        for (TGMessage *currentMessage in addedMessages.reverseObjectEnumerator)
        {
            static unsigned int randomSeed = 0;
            if (randomSeed == 0)
                randomSeed = (unsigned int)CFAbsoluteTimeGetCurrent();
            int randomValue = rand_r(&randomSeed);
            NSString *guid = [NSString stringWithFormat:@"%x%x", (int)(CFAbsoluteTimeGetCurrent()) ^ randomValue, (int)currentMessage];
            
            NSMutableArray *mediaToSend = [[NSMutableArray alloc] init];
            TGMessage *newMessage = [self prepareMessageForSending:currentMessage.text attachments:nil prevoiusMessage:currentMessage mediaToSend:mediaToSend newMessageDate:newMessageDate guid:guid];
            
            if (!self.isBroadcast)
                [[TGDatabase instance] renewLocalMessagesInConversation:[NSArray arrayWithObject:newMessage] conversationId:_conversationId];
            else
            {
                if (newMessage.local)
                {
                    newMessage.mid = nextBroadcastMid;
                    newMessage.localMid = nextBroadcastMid;
                    
                    nextBroadcastMid++;
                }
            }
            
            TGConversationMessageItem *newMessageItem = [[TGConversationMessageItem alloc] initWithMessage:newMessage];
            if (self.isMultichat && !self.isEncrypted)
                newMessageItem.author = [[TGDatabase instance] loadUser:newMessage.fromUid];
            addMessageActionUsers(newMessage, newMessageItem);
            [controller precalculateItemMetrics:newMessageItem];
            [conversationItems insertObject:newMessageItem atIndex:0];
            
            [insertedItems insertObject:newMessageItem atIndex:0];
            [insertedIndices insertObject:[NSNumber numberWithInt:nextInsertIndex] atIndex:0];
            
            nextInsertIndex--;
            
            NSString *messageText = newMessage.text;
            if (messageText == nil)
                messageText = @"";
            
            NSMutableDictionary *options = [[NSMutableDictionary alloc] init];
            if (self.isBroadcast)
                [options setObject:_broadcastUids forKey:@"broadcastUids"];
            else
                [options setObject:[NSNumber numberWithLongLong:_conversationId] forKey:@"conversationId"];
            
            [options setObject:[NSNumber numberWithInt:newMessage.mid] forKey:@"localMid"];
            [options setObject:guid forKey:@"guid"];
            [options setObject:messageText forKey:@"messageText"];
            if (mediaToSend.count != 0)
                [options setObject:mediaToSend forKey:@"media"];
            for (TGMediaAttachment *attachment in newMessage.mediaAttachments)
            {
                if ([attachment isKindOfClass:[TGLocalMessageMetaMediaAttachment class]])
                {
                    [options setObject:attachment forKey:@"messageMeta"];
                }
            }
            [options setObject:[NSNumber numberWithBool:true] forKey:@"isRetry"];
            [options setObject:[NSNumber numberWithBool:self.isEncrypted] forKey:@"isEncrypted"];
            options[@"date"] = @(newMessage.date);
            options[@"encryptedConversationId"] = @(_conversation.encryptedData.encryptedConversationId);
            options[@"accessHash"] = @(_conversation.encryptedData.accessHash);
            
            [ActionStageInstance() dispatchOnStageQueue:^
            {
                [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/conversations/(%@)/sendMessage/(%d)", _dispatchConversationTag, newMessage.mid] options:options watcher:self];
                [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/conversations/(%@)/sendMessage/(%d)", _dispatchConversationTag, newMessage.mid] options:options watcher:TGTelegraphInstance];
            }];
        }
        
        if (addDateItem)
        {
            TGConversationDateItem *dateItem = [[TGConversationDateItem alloc] initWithDate:(newMessageDate)];
            [controller precalculateItemMetrics:dateItem];
            [conversationItems insertObject:dateItem atIndex:dateInsertIndex];
            [insertedItems addObject:dateItem];
            [insertedIndices addObject:[NSNumber numberWithInt:dateInsertIndex]];
        }
        
        [self updateMediaStatuses:insertedItems];
        
        dispatch_async(dispatch_get_main_queue(), ^
        {
            [self.conversationController scrollDownOnNextUpdate:false];
            [self.conversationController conversationMessagesChanged:insertedIndices insertedItems:insertedItems removedAtIndices:deletedIndices updatedAtIndices:nil updatedItems:nil delay:false scrollDownFlags:0];
        });
    }, false);
}

- (void)retryMessage:(int)mid
{
    [self retryMessages:[[NSArray alloc] initWithObjects:[[NSNumber alloc] initWithInt:mid], nil]];
}

- (void)cancelMessageProgress:(int)mid
{
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        [self deleteMessages:[[NSArray alloc] initWithObjects:[[NSNumber alloc] initWithInt:mid], nil]];
        
        NSString *path = [NSString stringWithFormat:@"/tg/conversations/(%@)/sendMessage/(%d)", _dispatchConversationTag, mid];
        [ActionStageInstance() removeAllWatchersFromPath:path];
        dispatchOnMessageQueue(^
        {
            _messageUploadProgress.erase(mid);
        }, false);
        [self actorCompleted:ASStatusFailed path:path result:nil];
    }];
}

- (void)cancelMediaProgress:(id)mediaId
{
    if (mediaId == nil)
        return;
    
    dispatchOnMessageQueue(^
    {
        [cancelledMediaIds() addObject:mediaId];
    }, false);
    
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        [[TGDownloadManager instance] cancelItem:mediaId];
        
        [_mediaDownloadProgress removeObjectForKey:mediaId];
        if (_mediaDownloadProgress.count == 0)
            _mediaDownloadProgress = nil;
        
        NSMutableDictionary *mediaDownloadProgress = _mediaDownloadProgress == nil ? nil : [[NSMutableDictionary alloc] initWithDictionary:_mediaDownloadProgress];
        
        dispatch_async(dispatch_get_main_queue(), ^
        {
            [self.conversationController conversationMediaDownloadProgressChanged:mediaDownloadProgress];
        });
    }];
}

- (void)forwardMessages:(NSArray *)array
{
    dispatchOnMessageQueue(^
    {
        std::set<int> midsToForward;
        NSMutableArray *messagesToForward = [[NSMutableArray alloc] init];
        
        for (NSNumber *nMid in array)
        {
            midsToForward.insert([nMid intValue]);
        }
        
        for (TGConversationItem *item in self.conversationItems)
        {
            if (item.type == TGConversationItemTypeMessage)
            {
                TGMessage *message = ((TGConversationMessageItem *)item).message;
                if (midsToForward.find(message.mid) != midsToForward.end())
                {
                    if (message.mid < TGMessageLocalMidBaseline)
                    {
                        message = [message copy];
                        
                        if (message.forwardUid == 0)
                        {
                            message.forwardUid = (int)message.fromUid;
                            
                            TGForwardedMessageMediaAttachment *forwardedMessageAttachment = [[TGForwardedMessageMediaAttachment alloc] init];
                            forwardedMessageAttachment.forwardUid = (int)message.fromUid;
                            forwardedMessageAttachment.forwardDate = message.date;
                            forwardedMessageAttachment.forwardMid = message.mid;
                            NSMutableArray *mediaAttachments = [[NSMutableArray alloc] init];
                            [mediaAttachments addObject:forwardedMessageAttachment];
                            if (message.mediaAttachments.count != 0)
                                [mediaAttachments addObjectsFromArray:message.mediaAttachments];
                            message.mediaAttachments = mediaAttachments;
                        }
                        else
                        {
                            int count = message.mediaAttachments.count;
                            for (int i = 0; i < count; i++)
                            {
                                TGMediaAttachment *attachment = [message.mediaAttachments objectAtIndex:i];
                                if (attachment.type == TGForwardedMessageMediaAttachmentType)
                                {
                                    TGForwardedMessageMediaAttachment *forwardedMessageAttachment = [(TGForwardedMessageMediaAttachment *)attachment copy];
                                    forwardedMessageAttachment.forwardMid = message.mid;
                                    
                                    NSMutableArray *mediaAttachments = [[NSMutableArray alloc] init];
                                    [mediaAttachments addObjectsFromArray:message.mediaAttachments];
                                    [mediaAttachments replaceObjectAtIndex:i withObject:forwardedMessageAttachment];
                                    message.mediaAttachments = mediaAttachments;
                                    break;
                                }
                            }
                        }
                    }
                    
                    [messagesToForward addObject:message];
                    midsToForward.erase(message.mid);
                }
            }
            
            if (midsToForward.empty())
                break;
        }
        
        if (messagesToForward.count != 0)
        {
            [messagesToForward sortUsingComparator:^NSComparisonResult(TGMessage *message1, TGMessage *message2)
            {
                return message1.date < message2.date ? NSOrderedAscending : NSOrderedDescending;
            }];
            
            dispatch_async(dispatch_get_main_queue(), ^
            {
                TGForwardTargetController *forwardController = [[TGForwardTargetController alloc] initWithMessages:messagesToForward];
                forwardController.watcherHandle = _actionHandle;
                TGNavigationController *navigationController = [TGNavigationController navigationControllerWithRootController:forwardController blackCorners:false];
                
                if (iosMajorVersion() <= 5)
                {
                    [TGViewController disableAutorotationFor:0.45];
                    [forwardController view];
                    [forwardController viewWillAppear:false];
                    
                    CGSize screenSize = [TGViewController screenSizeForInterfaceOrientation:self.conversationController.interfaceOrientation];
                    navigationController.view.frame = CGRectMake(0, screenSize.height, screenSize.width, screenSize.height);
                    [self.conversationController.navigationController.view addSubview:navigationController.view];
                    
                    [UIView animateWithDuration:0.45 animations:^
                    {
                        navigationController.view.frame = CGRectMake(0, 0, screenSize.width, screenSize.height);
                    } completion:^(BOOL finished)
                    {
                        [navigationController.view removeFromSuperview];
                        
                        if (finished)
                        {
                            [self.conversationController.navigationController presentViewController:navigationController animated:false completion:nil];
                        }
                    }];
                }
                else
                {
                    [self.conversationController.navigationController presentViewController:navigationController animated:true completion:nil];
                }
            });
        }
    }, false);
}

- (void)deleteMessages:(NSArray *)mids
{
    dispatchOnMessageQueue(^
    {
        [self deleteMessagesFromList:mids];
        
        if (mids.count != 0)
        {
            std::set<int> midsSet;
            for (NSNumber *nMid in mids)
                midsSet.insert([nMid intValue]);
            
            NSMutableArray *removePaths = [[NSMutableArray alloc] init];
            
            for (TGConversationItem *item in self.conversationItems)
            {
                if (item.type == TGConversationItemTypeMessage)
                {
                    TGMessage *message = ((TGConversationMessageItem *)item).message;
                    
                    if (midsSet.find(message.mid) != midsSet.end() || (message.local && midsSet.find(message.localMid) != midsSet.end()))
                    {
                        if (message.deliveryState == TGMessageDeliveryStatePending)
                        {
                            [removePaths addObject:[NSString stringWithFormat:@"/tg/conversations/(%@)/sendMessage/(%d)", _dispatchConversationTag, message.mid]];
                        }
                    }
                }
            }
            
            for (NSString *path in removePaths)
            {
                [ActionStageInstance() removeAllWatchersFromPath:path];
            }
            
            if (!self.isBroadcast)
            {
                static int actionId = 1;
                [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/conversation/(%@)/deleteMessages/(conv%d)", _dispatchConversationTag, actionId++] options:[NSDictionary dictionaryWithObject:mids forKey:@"mids"] watcher:TGTelegraphInstance];
            }
        }
    }, false);
}

- (void)deleteMessagesFromList:(NSArray *)mids
{
    dispatchOnMessageQueue(^
    {
        NSMutableArray *deletedIndices = [[NSMutableArray alloc] init];
        
        int itemsCount = self.conversationItems.count;
        int index = -1;

        int unreadMarkerIndex = -1;
        if (!_didRemoveUnreadMarker)
        {
            for (int i = 0; i < itemsCount; i++)
            {
                TGConversationItem *item = [self.conversationItems objectAtIndex:i];
                if (item.type == TGConversationItemTypeUnread)
                {
                    unreadMarkerIndex = i;
                    break;
                }
            }
        }
        
        for (int i = 0; i < itemsCount; i++)
        {
            index++;
            
            TGConversationItem *item = [self.conversationItems objectAtIndex:i];
            if (item.type == TGConversationItemTypeMessage)
            {
                TGMessage *message = ((TGConversationMessageItem *)item).message;
                
                NSNumber *nMid = [NSNumber numberWithInt:message.mid];
                NSNumber *nLocalMid = [NSNumber numberWithInt:message.localMid];
                bool containsMid = [mids containsObject:nMid];
                if (containsMid || [mids containsObject:nLocalMid])
                {
                    [deletedIndices addObject:[NSNumber numberWithInt:index]];
                    [self.conversationItems removeObjectAtIndex:i];
                    
                    i--;
                    itemsCount--;
                    
                    if (i + 1 < itemsCount)
                    {
                        TGConversationItem *nextItem = [self.conversationItems objectAtIndex:i + 1];
                        TGConversationItem *prevItem = nil;
                        if (i >= 0)
                            prevItem = [self.conversationItems objectAtIndex:i];
                        
                        if (nextItem.type == TGConversationItemTypeDate && (prevItem == nil || prevItem.type != TGConversationItemTypeMessage))
                        {
                            [deletedIndices addObject:[NSNumber numberWithInt:(index + 1)]];
                            [self.conversationItems removeObjectAtIndex:(i + 1)];
                            
                            index++;
                            itemsCount--;
                        }
                    }
                }
            }
        }
        
        if (deletedIndices.count != 0)
        {
            if (unreadMarkerIndex >= 0)
            {
                TGConversationItem *item = [self.conversationItems objectAtIndex:0];
                if (item.type == TGConversationItemTypeUnread)
                {
                    [self.conversationItems removeObjectAtIndex:0];
                    [deletedIndices addObject:[[NSNumber alloc] initWithInt:unreadMarkerIndex]];
                    
                    _didRemoveUnreadMarker = true;
                }
            }
            
            dispatch_async(dispatch_get_main_queue(), ^
            {
                [self.conversationController conversationMessagesChanged:nil insertedItems:nil removedAtIndices:deletedIndices updatedAtIndices:nil updatedItems:nil delay:false scrollDownFlags:0];
            });
        }
    }, false);
}

- (void)clearAllMessages
{
    dispatchOnMessageQueue(^
    {
        if (!self.isBroadcast)
        {
            [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/conversation/(%@)/clearHistory", _dispatchConversationTag] options:[NSDictionary dictionaryWithObject:[NSNumber numberWithLongLong:self.conversationId] forKey:@"conversationId"] watcher:self];
        }
    
#warning check
        [self.conversationItems removeAllObjects];
        
        dispatch_async(dispatch_get_main_queue(), ^
        {
            [self.conversationController conversationMessagesCleared];
        });
    }, false);
}

static dispatch_queue_t messagesServiceQueue()
{
    static dispatch_queue_t queue = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        queue = dispatch_queue_create("ph.telegra.messageServiceQueue", NULL);
    });
    return queue;
}

- (void)updateMediaStatuses:(NSArray *)items
{
    dispatch_async(messagesServiceQueue(), ^
    {
        static NSFileManager *fileManager = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^
        {
            fileManager = [[NSFileManager alloc] init];
        });
        
        NSSet *cancelledMediaIdsSet = cancelledMediaIds();
        
        NSMutableDictionary *addedStatuses = [[NSMutableDictionary alloc] init];
        
        NSMutableArray *messagesToDownload = [[NSMutableArray alloc] init];
        
        bool autoDownload = _conversationId < 0 || self.isEncrypted ? TGAppDelegateInstance.autoDownloadPhotosInGroups : TGAppDelegateInstance.autoDownloadPhotosInPrivateChats;
        
        //CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
        
        for (TGConversationItem *item in items)
        {
            int itemType = item.type;
            if (itemType == TGConversationItemTypeMessage)
            {
                TGMessage *message = ((TGConversationMessageItem *)item).message;
                if (_proccessedDownloadedStatusMids.find(message.mid) != _proccessedDownloadedStatusMids.end())
                    continue;
                
                TGCache *cache = [TGRemoteImageView sharedCache];
                int imageHeight = (int)([TGViewController screenSize:UIDeviceOrientationPortrait].height * 2);
                
                if (message.mediaAttachments.count != 0)
                {
                    for (TGMediaAttachment *attachment in message.mediaAttachments)
                    {
                        id mediaId = nil;
                        int type = attachment.type;
                        
                        if (type == TGVideoMediaAttachmentType)
                        {
                            TGVideoMediaAttachment *videoAttachment = (TGVideoMediaAttachment *)attachment;
                            mediaId = [[TGMediaId alloc] initWithType:1 itemId:videoAttachment.videoId];
                            
                            NSString *url = [videoAttachment.videoInfo urlWithQuality:0 actualQuality:NULL actualSize:NULL];
                            bool videoDownloaded = [TGVideoDownloadActor isVideoDownloaded:fileManager url:url];
                            [addedStatuses setObject:[[NSNumber alloc] initWithBool:videoDownloaded] forKey:mediaId];
                            
                            break;
                        }
                        else if (type == TGImageMediaAttachmentType)
                        {
                            TGImageMediaAttachment *imageAttachment = (TGImageMediaAttachment *)attachment;
                            mediaId = [[TGMediaId alloc] initWithType:2 itemId:imageAttachment.imageId];
                            
                            NSString *url = [[imageAttachment imageInfo] closestImageUrlWithHeight:imageHeight resultingSize:NULL];
                            
                            NSString *path = [cache pathForCachedData:url];
                            if (path != nil)
                            {
                                bool imageDownloaded = [url hasPrefix:@"upload/"] ? true : [fileManager fileExistsAtPath:path];
                                [addedStatuses setObject:[[NSNumber alloc] initWithBool:imageDownloaded] forKey:mediaId];
                                
                                if (!imageDownloaded && ![cancelledMediaIdsSet containsObject:mediaId])
                                {
                                    [messagesToDownload addObject:message];
                                }
                            }
                            
                            break;
                        }
                    }
                }
            }
            else if (itemType == TGConversationItemTypeUnread)
            {
                NSArray *reversedArray = [[messagesToDownload reverseObjectEnumerator] allObjects];
                [messagesToDownload removeAllObjects];
                [messagesToDownload addObjectsFromArray:reversedArray];
            }
        }
        
        //TGLog(@"===== Processed %d media items in %f ms", items.count, (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0);
        
        if (messagesToDownload.count != 0 && autoDownload)
        {
            [ActionStageInstance() dispatchOnStageQueue:^
            {
                for (TGMessage *message in messagesToDownload)
                {
                    [self downloadMedia:message changePriority:false];
                }
            }];
        }
        
        if (addedStatuses.count != 0)
        {
            dispatch_async(dispatch_get_main_queue(), ^
            {
                [self.conversationController addProcessedMediaDownloadedStatuses:addedStatuses];
            });
        }
    });
}

- (void)downloadMedia:(TGMessage *)message changePriority:(bool)changePriority
{
    int64_t conversationId = _conversationId;
    
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        for (TGMediaAttachment *attachment in message.mediaAttachments)
        {
            if (attachment.type == TGVideoMediaAttachmentType)
            {
                TGVideoMediaAttachment *videoAttachment = (TGVideoMediaAttachment *)attachment;
                id mediaId = [[TGMediaId alloc] initWithType:1 itemId:videoAttachment.videoId];
                
                NSString *url = [videoAttachment.videoInfo urlWithQuality:0 actualQuality:NULL actualSize:NULL];
                
                if (url != nil)
                {
                    [[TGDownloadManager instance] requestItem:[NSString stringWithFormat:@"/as/media/video/(%@)", url] options:[[NSDictionary alloc] initWithObjectsAndKeys:videoAttachment, @"videoAttachment", nil] changePriority:changePriority messageId:message.mid itemId:mediaId groupId:conversationId itemClass:TGDownloadItemClassVideo];
                }
                
                break;
            }
            else if (attachment.type == TGImageMediaAttachmentType)
            {
                int imageHeight = (int)([TGViewController screenSize:UIDeviceOrientationPortrait].height * 2);
                
                TGImageMediaAttachment *imageAttachment = (TGImageMediaAttachment *)attachment;
                id mediaId = [[TGMediaId alloc] initWithType:2 itemId:imageAttachment.imageId];
                
                NSString *url = [[imageAttachment imageInfo] closestImageUrlWithHeight:imageHeight resultingSize:NULL];
                
                if (url != nil)
                {
                    int contentHints = TGRemoteImageContentHintLargeFile;
                    if ([self shouldAutosavePhotos] && !message.outgoing)
                        contentHints |= TGRemoteImageContentHintSaveToGallery;
                    
                    NSMutableDictionary *options = [[NSMutableDictionary alloc] initWithObjectsAndKeys:[NSNumber numberWithInt:0], @"cancelTimeout", [TGRemoteImageView sharedCache], @"cache", [NSNumber numberWithBool:false], @"useCache", [NSNumber numberWithBool:false], @"allowThumbnailCache", [[NSNumber alloc] initWithInt:contentHints], @"contentHints", nil];
                    [options setObject:[[NSDictionary alloc] initWithObjectsAndKeys:
                        [[NSNumber alloc] initWithInt:message.mid], @"messageId",
                        [[NSNumber alloc] initWithLongLong:message.cid], @"conversationId",
                        [[NSNumber alloc] initWithBool:message.unread], @"forceSave",
                        mediaId, @"mediaId", imageAttachment.imageInfo, @"imageInfo",
                        [[NSNumber alloc] initWithBool:!message.outgoing], @"storeAsAsset",
                    nil] forKey:@"userProperties"];
                    
                    [[TGDownloadManager instance] requestItem:[NSString stringWithFormat:@"/img/(download:{filter:%@}%@)", @"maybeScale", url] options:options changePriority:changePriority messageId:message.mid itemId:mediaId groupId:conversationId itemClass:TGDownloadItemClassImage];
                }
                
                break;
            }
        }
    }];
}

- (void)sendContactRequest
{
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        NSString *action = [NSString stringWithFormat:@"/tg/contacts/requestActor/(%lld)/(requestContact)", [self singleUserId]];
        NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:[[NSNumber alloc] initWithInt:(int)[self singleUserId]], @"uid", @"requestContact", @"action", nil];
        [ActionStageInstance() requestActor:action options:options watcher:self];
        [ActionStageInstance() requestActor:action options:options watcher:TGTelegraphInstance];
    }];
}

- (void)acceptContactRequest
{
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        NSString *action = [NSString stringWithFormat:@"/tg/contacts/requestActor/(%lld)/(requestContact)", [self singleUserId]];
        NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:[[NSNumber alloc] initWithInt:(int)[self singleUserId]], @"uid", @"requestContact", @"action", nil];
        [ActionStageInstance() requestActor:action options:options watcher:self];
        [ActionStageInstance() requestActor:action options:options watcher:TGTelegraphInstance];
    }];
}

- (void)blockUser
{
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        static int actionId = 0;
        
        [ActionStageInstance() requestActor:[[NSString alloc] initWithFormat:@"/tg/changePeerBlockedStatus/(cb%d)", actionId++] options:[[NSDictionary alloc] initWithObjectsAndKeys:[[NSNumber alloc] initWithLongLong:[self singleUserId]], @"peerId", [[NSNumber alloc] initWithBool:true], @"block", nil] watcher:TGTelegraphInstance];
    }];
}

- (void)unblockUser
{
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        static int actionId = 0;
        
        [ActionStageInstance() requestActor:[[NSString alloc] initWithFormat:@"/tg/changePeerBlockedStatus/(cu%d)", actionId++] options:[[NSDictionary alloc] initWithObjectsAndKeys:[[NSNumber alloc] initWithLongLong:[self singleUserId]], @"peerId", [[NSNumber alloc] initWithBool:false], @"block", nil] watcher:TGTelegraphInstance];
    }];
}

- (void)muteConversation:(bool)mute
{
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        static int actionId = 0;
        [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/changePeerSettings/(%lld)/(conversationController%d)", _conversation.conversationId, actionId++] options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithLongLong:_conversation.conversationId], @"peerId", [NSNumber numberWithInt:!mute ? 0 : INT_MAX], @"muteUntil", nil] watcher:TGTelegraphInstance];
    }];
}

- (void)leaveGroup
{
    UINavigationController *navigationController = self.conversationController.navigationController;
    int index = [navigationController.viewControllers indexOfObject:self.conversationController];
    if (index != NSNotFound && index > 0)
    {
        [TGAppDelegateInstance.dialogListController.dialogListCompanion deleteItem:[[TGConversation alloc] initWithConversationId:_conversationId unreadCount:0 serviceUnreadCount:0] animated:false];
        [navigationController popToViewController:[navigationController.viewControllers objectAtIndex:index - 1] animated:true];
    }
}

- (void)acceptEncryptionRequest
{
    /*[ActionStageInstance() dispatchOnStageQueue:^
    {
        _acceptingEncryptionRequest = true;
        static int actionId = 0;
        [ActionStageInstance() requestActor:[[NSString alloc] initWithFormat:@"/tg/encrypted/acceptEncryptedChat/(%d)", actionId++] options:@{@"encryptedConversationId": @(_conversation.encryptedData.encryptedConversationId), @"accessHash": @(_conversation.encryptedData.accessHash)} flags:0 watcher:self];
    }];*/
}

- (void)ignoreContactRequest
{
    
}

- (id<TGImageViewControllerCompanion>)createImageViewControllerCompanion:(int)firstItemId reverseOrder:(bool)reverseOrder
{
    TGTelegraphImageViewControllerCompanion *companion = [[TGTelegraphImageViewControllerCompanion alloc] initWithPeerId:_conversationId firstItemId:firstItemId isEncrypted:self.isEncrypted];
    companion.reverseOrder = reverseOrder;
    return companion;
}

- (id<TGImageViewControllerCompanion>)createGroupPhotoImageViewControllerCompanion:(id<TGMediaItem>)mediaItem
{
    TGTelegraphGroupPhotoImageViewControllerCompanion *companion = [[TGTelegraphGroupPhotoImageViewControllerCompanion alloc] initWithMediaItem:mediaItem];
    return companion;
}

- (id<TGImageViewControllerCompanion>)createUserPhotoImageViewControllerCompanion:(id<TGMediaItem>)mediaItem
{
    TGTelegraphProfileImageViewCompanion *companion = [[TGTelegraphProfileImageViewCompanion alloc] initWithUid:(int)self.conversationId photoItem:mediaItem loadList:false];
    return companion;
}

- (id<TGMediaItem>)createMediaItemFromMessage:(TGMessage *)message author:(TGUser *)author imageInfo:(TGImageInfo *)imageInfo
{
    return [[TGMessageMediaItem alloc] initWithMessage:message author:author imageInfo:imageInfo];
}

- (id<TGMediaItem>)createMediaItemFromMessage:(TGMessage *)message author:(TGUser *)author videoAttachment:(TGVideoMediaAttachment *)videoAttachment
{
    return [[TGMessageMediaItem alloc] initWithMessage:message author:author videoAttachment:videoAttachment];
}

- (id<TGMediaItem>)createMediaItemFromAvatarMessage:(TGMessage *)message
{
    TGImageMediaAttachment *imageAttachment = message.actionInfo.actionData[@"photo"];
    
    TGProfileImageItem *imageItem = [[TGProfileImageItem alloc] initWithProfilePhoto:imageAttachment];
    [imageItem setExplicitItemId:[[NSNumber alloc] initWithInt:message.mid]];
    return imageItem;
}

- (bool)updateTitle
{
#if TARGET_IPHONE_SIMULATOR
    if (![ActionStageInstance() isCurrentQueueStageQueue])
        TGLog(@"****** Calling updateTitle from wrong queue");
#endif
    
    NSString *newTitle = @" ";
    bool changed = false;
    
    if (self.isEncrypted)
    {
        if (self.singleParticipant != nil)
        {
            TGUser *user = self.singleParticipant;
            
            bool newIsContact = [TGDatabaseInstance() uidIsRemoteContact:user.uid];
            if (newIsContact != _isContact)
            {
                changed = true;
                _isContact = newIsContact;
            }
            
            if (user.phoneNumber.length != 0 && !_isContact && user.uid != 333000)
                newTitle = [user formattedPhoneNumber];
            else
                newTitle = user.displayName;
        }
    }
    else if (self.isBroadcast)
    {
        newTitle = TGLocalized(@"Conversation.BroadcastTitle");
    }
    else if (self.isMultichat)
    {
        if (_conversation.chatTitle != nil)
            newTitle = _conversation.chatTitle;
    }
    else
    {
        if (self.singleParticipant != nil)
        {
            TGUser *user = self.singleParticipant;
            
            bool newIsContact = [TGDatabaseInstance() uidIsRemoteContact:user.uid];
            if (newIsContact != _isContact)
            {
                changed = true;
                _isContact = newIsContact;
            }
            
            if (user.phoneNumber.length != 0 && !_isContact && user.uid != 333000)
                newTitle = [user formattedPhoneNumber];
            else
                newTitle = user.displayName;
        }
    }
    
    if (![newTitle isEqualToString:self.conversationTitle] || changed)
    {
        self.conversationTitle = newTitle;
        return true;
    }
    
    return false;
}

- (bool)updateSubtitle
{
#if TARGET_IPHONE_SIMULATOR
    if (![ActionStageInstance() isCurrentQueueStageQueue])
        TGLog(@"****** Calling updateSubtitle from wrong queue");
#endif
    
    NSString *newSubtitle = @" ";
    NSString *newTypingSubtitle = @" ";

    if (self.isEncrypted)
    {
        if (_conversation.encryptedData.handshakeState == 3)
            newSubtitle = TGLocalized(@"Conversation.EncryptionCanceled");
        else
        {
            if (_typingUsers.count != 0)
            {
                newTypingSubtitle = TGLocalized(@"Conversation.StatusTyping");
            }
            
            if (self.singleParticipant != nil)
            {
                TGUser *user = self.singleParticipant;
                
                int lastSeen = user.presence.lastSeen;
                
                if (user.presence.online)
                    newSubtitle = TGLocalized(@"Presence.online");
                else if (lastSeen < 0)
                    newSubtitle = TGLocalized(@"Presence.invisible");
                else if (lastSeen != 0)
                    newSubtitle = [[NSString alloc] initWithFormat:@"%@ %@", NSLocalizedString(@"Time.last_seen", nil), [TGDateUtils stringForRelativeLastSeen:lastSeen]];
                else
                    newSubtitle = TGLocalized(@"Presence.offline");
            }
            else
                newSubtitle = @" ";
        }
    }
    else if (self.isBroadcast)
    {
        newSubtitle = [[NSString alloc] initWithFormat:@"%d %s", _broadcastUids.count, _broadcastUids.count == 1 ? "person" : "people"];
    }
    else if (self.isMultichat)
    {
        if (_typingUsers.count != 0)
        {
            NSMutableString *typingString = [[NSMutableString alloc] init];
            
            for (NSNumber *nUid in _typingUsers)
            {
                TGUser *user = [TGDatabaseInstance() loadUser:[nUid intValue]];
                if (user != nil)
                {
                    NSString *firstName = user.firstName;
                    NSString *lastName = user.lastName;
                    NSString *displayName = firstName;
                    if (displayName == nil || displayName.length == 0)
                        displayName = lastName;
                    if (displayName != nil)
                    {
                        if (typingString.length != 0)
                            [typingString appendString:@", "];
                        [typingString appendString:displayName];
                    }
                }
            }
            
            newTypingSubtitle = typingString.length == 0 ? @" " : typingString;
        }

        if (_conversation.kickedFromChat)
            newSubtitle = TGLocalizedStatic(@"Conversation.StatusKickedFromGroup");
        else if (_conversation.leftChat)
            newSubtitle = TGLocalizedStatic(@"Conversation.StatusLeftGroup");
        else
        {
            if (_conversation.chatParticipantCount == 0)
                newSubtitle = @" ";
            else
            {
                int onlineCount = [TGDatabaseInstance() loadUsersOnlineCount:_conversation.chatParticipants.chatParticipantUids alwaysOnlineUid:TGTelegraphInstance.clientUserId];
                if (onlineCount == 0)
                    newSubtitle = [NSString stringWithFormat:@"%d %@", _conversation.chatParticipantCount, _conversation.chatParticipantCount == 1 ? TGLocalizedStatic(@"Conversation.StatusMember") : TGLocalizedStatic(@"Conversation.StatusMembers")];
                else
                    newSubtitle = [NSString stringWithFormat:@"%d %@, %d %@", _conversation.chatParticipantCount, _conversation.chatParticipantCount == 1 ? TGLocalizedStatic(@"Conversation.StatusMember") : TGLocalizedStatic(@"Conversation.StatusMembers"), onlineCount, TGLocalizedStatic(@"Presence.online")];
            }
        }
    }
    else
    {
        if (_typingUsers.count != 0)
        {
            newTypingSubtitle = TGLocalized(@"Conversation.StatusTyping");
        }
        
        if (self.singleParticipant != nil)
        {
            TGUser *user = self.singleParticipant;
            
            int lastSeen = user.presence.lastSeen;
            
            if (user.presence.online)
                newSubtitle = TGLocalized(@"Presence.online");
            else if (lastSeen < 0)
                newSubtitle = TGLocalized(@"Presence.invisible");
            else if (lastSeen != 0)
                newSubtitle = [[NSString alloc] initWithFormat:@"%@ %@", NSLocalizedString(@"Time.last_seen", nil), [TGDateUtils stringForRelativeLastSeen:lastSeen]];
            else
                newSubtitle = TGLocalized(@"Presence.offline");
        }
        else
            newSubtitle = @" ";
    }
    
    bool subtitleChanged = false;
    
    if (![newSubtitle isEqualToString:self.conversationSubtitle])
    {
        self.conversationSubtitle = newSubtitle;
        subtitleChanged = true;
    }
    
    if (![newTypingSubtitle isEqualToString:self.conversationTypingSubtitle])
    {
        self.conversationTypingSubtitle = newTypingSubtitle;
        subtitleChanged = true;
    }
    
    return subtitleChanged;
}

#pragma mark - Data logic

- (void)_messageDelivered:(int)localMid addedMessages:(NSArray *)addedMessages success:(bool)success shouldDispatchUploadProgress:(bool)shouldDispatchUploadProgress pMessageUploadProgress:(std::tr1::shared_ptr<std::map<int, float> >)pMessageUploadProgress pDispatchedUploadProgress:(bool *)pDispatchedUploadProgress
{      
    NSMutableArray *conversationItems = self.conversationItems;
    
    bool playedSound = false;
    
    int itemsCount = self.conversationItems.count;
    for (int i = 0; i < itemsCount; i++)
    {
        TGConversationItem *item = [conversationItems objectAtIndex:i];
        if (item.type == TGConversationItemTypeMessage)
        {
            TGMessage *message = ((TGConversationMessageItem *)item).message;
            if (message.mid == localMid)
            {
                if (success && message.deliveryState == TGMessageDeliveryStatePending)
                {
                    playedSound = true;
                    if (TGAppDelegateInstance.outgoingSoundEnabled && TGAppDelegateInstance.soundEnabled)
                        [TGAppDelegateInstance playSound:@"sent.caf" vibrate:false];
                }
                
                TGMessage *newMessage = [message copy];
                
                if (!success)
                    newMessage.deliveryState = TGMessageDeliveryStateFailed;
                else
                {
                    if (addedMessages != nil)
                    {
                        if (!self.isBroadcast && addedMessages.count == 0)
                        {
                            newMessage.deliveryState = TGMessageDeliveryStateFailed;
                        }
                        else
                        {
                            TGMessage *addedMessage = [addedMessages objectAtIndex:0];
                            
                            newMessage.deliveryState = TGMessageDeliveryStateDelivered;
                            newMessage.local = false;
                            newMessage.localMid = localMid;
                            newMessage.mid = addedMessage.mid;
                            newMessage.mediaAttachments = addedMessage.mediaAttachments;
                            newMessage.realDate = addedMessage.date;
                            
                            if (self.conversationId == TGTelegraphInstance.clientUserId)
                                newMessage.unread = false;
                        }
                    }
                    else
                        newMessage.deliveryState = TGMessageDeliveryStateDelivered;
                }
                
                TGConversationMessageItem *newMessageItem = [[TGConversationMessageItem alloc] initWithMessage:newMessage];
                if (self.isMultichat && !self.isEncrypted)
                    newMessageItem.author = [[TGDatabase instance] loadUser:newMessage.fromUid];
                addMessageActionUsers(newMessage, newMessageItem);
                [conversationItems replaceObjectAtIndex:i withObject:newMessageItem];
                
                NSArray *updatedIndices = [[NSArray alloc] initWithObjects:[NSNumber numberWithInt:i], nil];
                NSArray *updatedItems = [[NSArray alloc] initWithObjects:newMessageItem, nil];
                
                if (pDispatchedUploadProgress != NULL)
                    *pDispatchedUploadProgress = true;
                
                dispatch_async(dispatch_get_main_queue(), ^
                {
                    [self.conversationController conversationMessagesChanged:nil insertedItems:nil removedAtIndices:nil updatedAtIndices:updatedIndices updatedItems:updatedItems delay:false scrollDownFlags:0];
                    if (shouldDispatchUploadProgress)
                        [self.conversationController conversationMessageUploadProgressChanged:pMessageUploadProgress];
                });
                
                break;
            }
        }
    }
    
    if (!playedSound && self.canLoadMoreHistoryDownwards)
    {
        if (success)
        {
            if (TGAppDelegateInstance.outgoingSoundEnabled && TGAppDelegateInstance.soundEnabled)
                [TGAppDelegateInstance playSound:@"sent.caf" vibrate:false];
        }
    }
}

- (void)actorMessageReceived:(NSString *)path messageType:(NSString *)messageType message:(id)message
{
    if ([path hasPrefix:[NSString stringWithFormat:@"/tg/conversations/(%@)/sendMessage/(", _dispatchConversationTag]])
    {
        if ([messageType isEqualToString:@"messageDelivered"])
        {
            int localMid = [message intValue];
            
            dispatchOnMessageQueue(^
            {
                [self _messageDelivered:localMid addedMessages:nil success:true shouldDispatchUploadProgress:false pMessageUploadProgress:std::tr1::shared_ptr<std::map<int, float> >() pDispatchedUploadProgress:NULL];
            }, false);
        }
    }
}

- (void)actorCompleted:(int)resultCode path:(NSString *)path result:(id)result
{
    if ([path isEqualToString:@"/tg/service/synchronizationstate"])
    {
        int state = [((SGraphObjectNode *)result).object intValue];
        
        TGConversationControllerSynchronizationState newState = TGConversationControllerSynchronizationStateNone;
        if (state & 2)
        {
            if (state & 4)
                newState = TGConversationControllerSynchronizationStateWaitingForNetwork;
            else
                newState = TGConversationControllerSynchronizationStateConnecting;
        }
        else if (state & 1)
            newState = TGConversationControllerSynchronizationStateUpdating;
        
        if (newState != _synchronizationState)
        {
            _synchronizationState = newState;
            dispatch_async(dispatch_get_main_queue(), ^
            {
                [self.conversationController synchronizationStatusChanged:newState];
            });
        }
    }
    else if ((!self.isMultichat || self.isEncrypted) && [path isEqualToString:[NSString stringWithFormat:@"/tg/users/(%lld)", [self singleUserId]]])
    {
        if (resultCode == ASStatusSuccess)
        {
            //TG_TIMESTAMP_DEFINE(actorCompletedUser)
            
            TGUser *user = ((TGUserNode *)result).user;
            
            self.singleParticipant = user;
            
            [self updateTitle];
            [self updateSubtitle];
            NSString *title = self.conversationTitle;
            NSString *subtitle = self.conversationSubtitle;
            NSString *typingSubtitle = self.conversationTypingSubtitle;
            bool isContact = _isContact;
            
            NSDictionary *options = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:user.uid] forKey:@"uid"];
            [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/completeUsers/(%d)", user.uid] options:options watcher:self];
            [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/completeUsers/(%d)", user.uid] options:options watcher:TGTelegraphInstance];
            
            dispatch_async(dispatch_get_main_queue(), ^
            {
                [self.conversationController conversationTitleChanged:title subtitle:subtitle typingSubtitle:typingSubtitle isContact:isContact];
                [self.conversationController conversationSignleParticipantChanged:user];
            });
            
            [ActionStageInstance() requestActor:[[NSString alloc] initWithFormat:@"/tg/blockedUsers/(%lld,cached)", [self singleUserId]] options:[[NSDictionary alloc] initWithObjectsAndKeys:[[NSNumber alloc] initWithInt:(int)[self singleUserId]], @"uid", nil] watcher:self];
            
            [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/conversation/(%lld)/typing", _conversationId] options:nil watcher:self];
        }
    }
    else if ((!self.isMultichat || self.isEncrypted) && [path hasPrefix:[[NSString alloc] initWithFormat:@"/tg/completeUsers/(%lld", [self singleUserId]]])
    {
        NSDictionary *userResult = ((SGraphObjectNode *)result).object;
        
        [self actorCompleted:ASStatusSuccess path:[[NSString alloc] initWithFormat:@"/tg/userLink/(%lld)", [self singleUserId]] result:[[SGraphObjectNode alloc] initWithObject:[userResult objectForKey:@"userLink"]]];
    }
    else if ((!self.isMultichat || self.isEncrypted) && [path isEqualToString:[[NSString alloc] initWithFormat:@"/tg/userLink/(%lld)", [self singleUserId]]])
    {
        if (self.singleParticipant != nil)
        {
            int userLink = [((SGraphObjectNode *)result).object intValue];
            
            if (_conversationId == TGTelegraphInstance.clientUserId)
                userLink = TGUserLinkMyContact | TGUserLinkKnown | TGUserLinkForeignMutual;
            
            _userLink = userLink;
            
            int linkAction = -1;
            
            if ([_runningLinkAction isEqualToString:@"requestContact"])
            {
                linkAction = 0;
            }
            else if ([_runningLinkAction isEqualToString:@"acceptContact"])
            {
                linkAction = 1;
            }
            
            dispatch_async(dispatch_get_main_queue(), ^
            {
                [self.conversationController conversationLinkChanged:userLink];
                if (linkAction != -1)
                    [self.conversationController linkActionInProgress:linkAction inProgress:true];
            });
        }
    }
    else if ([path hasPrefix:@"/tg/peerSettings"])
    {
        bool isMuted = [[((SGraphObjectNode *)result).object objectForKey:@"muteUntil"] intValue] != 0;
        
        dispatch_async(dispatch_get_main_queue(), ^
        {
            [self.conversationController setConversationMuted:isMuted];
        });
    }
    else if (self.isMultichat && [path isEqualToString:[NSString stringWithFormat:@"/tg/conversation/(%lld)/conversation", _conversationId]])
    {
        TGConversation *oldConversation = _conversation;
        
        if (resultCode == ASStatusSuccess)
        {
            _conversation = ((SGraphObjectNode *)result).object;
            if (!_requestedExtendedInfo)
            {
                _requestedExtendedInfo = true;
                
                if (!self.isEncrypted)
                {
                    [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/conversationExtended/(%lld)", _conversationId] options:[NSDictionary dictionaryWithObject:[NSNumber numberWithLongLong:_conversationId] forKey:@"conversationId"] watcher:TGTelegraphInstance];
                }
                else
                {
                    [ActionStageInstance() requestActor:[[NSString alloc] initWithFormat:@"/tg/blockedUsers/(%lld,cached)", [self singleUserId]] options:[[NSDictionary alloc] initWithObjectsAndKeys:[[NSNumber alloc] initWithInt:(int)[self singleUserId]], @"uid", nil] watcher:self];
                }
            }
        }
        
        [self updateTitle];
        [self updateSubtitle];
        
        NSString *title = self.conversationTitle;
        NSString *subtitle = self.conversationSubtitle;
        NSString *typingSubtitle = self.conversationTypingSubtitle;
        bool isContact = _isContact;
        
        TGConversation *conversation = _conversation;
        
        bool modelChanged = ![oldConversation isEqualToConversationIgnoringMessage:conversation];
        
        TGUser *singleParticipant = self.singleParticipant;
        
        if (conversation.encryptedData.handshakeState == 2)
        {
            [self acceptEncryptionRequest];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^
        {
            [self.conversationController conversationTitleChanged:title subtitle:subtitle typingSubtitle:typingSubtitle isContact:isContact];
            [self.conversationController conversationAvatarChanged:conversation.chatPhotoSmall];
            
            id<ASWatcher> watcher = _conversationProfileControllerHandle.delegate;
            if (modelChanged && watcher != nil && conversation != nil && [watcher respondsToSelector:@selector(actionStageActionRequested:options:)])
            {
                [watcher actionStageActionRequested:@"chatInfoChanged" options:[NSDictionary dictionaryWithObject:conversation forKey:@"chatInfo"]];
            }
            
            if (self.isEncrypted)
            {
                [self.conversationController conversationSignleParticipantChanged:singleParticipant];
                [self.conversationController setEncryptionStatus:conversation.encryptedData.handshakeState];
            }
        });
        
        [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/conversation/(%lld)/typing", _conversationId] options:nil watcher:self];
    }
    else if ([path hasPrefix:@"/tg/blockedUsers"])
    {
        id blockedResult = ((SGraphObjectNode *)result).object;
        
        if ([blockedResult isKindOfClass:[NSNumber class]])
        {
            dispatch_async(dispatch_get_main_queue(), ^
            {
                [self.conversationController setUserBlocked:[blockedResult boolValue]];
            });
        }
        else if ([blockedResult isKindOfClass:[NSArray class]])
        {
            int currentUid = (int)[self singleUserId];
            bool blocked = false;
            for (TGUser *user in blockedResult)
            {
                if (user.uid == currentUid)
                {
                    blocked = true;
                    break;
                }
            }
            
            dispatch_async(dispatch_get_main_queue(), ^
            {
                [self.conversationController setUserBlocked:blocked];
            });
        }
    }
    else if ([path isEqualToString:[NSString stringWithFormat:@"/tg/conversation/(%lld)/typing", _conversationId]])
    {
        NSArray *typingUsers = ((SGraphObjectNode *)result).object;
        _typingUsers = typingUsers;
        
        if ([self updateSubtitle])
        {
            NSString *title = self.conversationTitle;
            NSString *subtitle = self.conversationSubtitle;
            NSString *typingSubtitle = self.conversationTypingSubtitle;
            bool isContact = _isContact;

            dispatch_async(dispatch_get_main_queue(), ^
            {
                [self.conversationController conversationTitleChanged:title subtitle:subtitle typingSubtitle:typingSubtitle isContact:isContact];
            });
        }
    }
    else if ([path isEqualToString:[NSString stringWithFormat:@"/tg/conversation/(%lld)/state", _conversationId]])
    {
        if (resultCode == ASStatusSuccess)
        {
            TGMessage *state = ((SGraphObjectNode *)result).object;
            if (state != nil && state.text.length != 0)
            {
                dispatch_async(dispatch_get_main_queue(), ^
                {
                    [self.conversationController setMessageText:state.text];
                });
            }
        }
    }
    else if ([path hasPrefix:[NSString stringWithFormat:@"/tg/conversations/(%lld)/history", _conversationId]])
    {
        dispatchOnMessageQueue(^
        {
            bool isDownwardsRequest = [[result objectForKey:@"downwards"] boolValue];
            
            if (resultCode == 0)
            {
                bool wasEmpty = self.conversationItems.count == 0;
                __unused NSTimeInterval startTime = CFAbsoluteTimeGetCurrent();
                
                int offsetFromGMT = [self offsetFromGMT];
                
                bool clearExisting = [[result objectForKey:@"clearExisting"] boolValue];
                
                NSArray *historyMessages = [result objectForKey:@"messages"];
                bool resultLoadedUnread = [[result objectForKey:@"loadUnread"] boolValue];
                
                bool suggestToLoadMoreHistory = false;

                if (isDownwardsRequest)
                {
                    self.canLoadMoreHistoryDownwards = historyMessages.count != 0;
                }
                else
                {
                    if ([path hasSuffix:@"/history/(up0)"])
                        self.canLoadMoreHistoryDownwards = [[result objectForKey:@"historyExistsBelow"] boolValue];
                    
                    self.canLoadMoreHistory = historyMessages.count != 0;
                    suggestToLoadMoreHistory = true;
                }
                
                CFAbsoluteTime dbStartTime = CFAbsoluteTimeGetCurrent();
                
                NSArray *receivedItems = [historyMessages sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2)
                {
                    return ((TGMessage *)obj1).date < ((TGMessage *)obj2).date ? NSOrderedDescending : (((TGMessage *)obj1).date > ((TGMessage *)obj2).date ? NSOrderedAscending : (((TGMessage *)obj1).mid < ((TGMessage *)obj2).mid ? NSOrderedDescending : NSOrderedAscending));
                }];
                
                NSMutableDictionary *cachedUsers = [[NSMutableDictionary alloc] init];
                bool isMultichat = self.isMultichat && !self.isEncrypted;
                
                NSMutableArray *itemsToPrecalculate = [[NSMutableArray alloc] init];
                
                if (receivedItems.count != 0)
                {
                    if (clearExisting)
                        [self.conversationItems removeAllObjects];
                        
                    NSMutableArray *items = nil;
                    
                    int dateDifferenceFromGMT = [self offsetFromGMT];
                    
                    bool scrollToUnread = false;
                    bool keepScrollOffset = false;
                    
                    if (self.conversationItems.count == 0)
                    {
                        //suggestToLoadMoreHistory = false;
                        items = [[NSMutableArray alloc] initWithCapacity:receivedItems.count];
                        
                        int lastDayDate = 0;
                        int receivedCount = receivedItems.count;
                        for (int i = 0; i < receivedCount; i++)
                        {
                            TGMessage *message = [receivedItems objectAtIndex:i];
                            
                            int currentDayDate = (int)((int)(message.date) + dateDifferenceFromGMT);
                            if (lastDayDate != 0)
                            {
                                if (currentDayDate / (24 * 60 * 60) != lastDayDate / (24 * 60 * 60))
                                {
                                    TGConversationDateItem *dateItem = [[TGConversationDateItem alloc] initWithDate:(lastDayDate - dateDifferenceFromGMT)];
                                    [itemsToPrecalculate addObject:dateItem];
                                    [items addObject:dateItem];
                                }
                            }
                            lastDayDate = currentDayDate;
                            
                            TGConversationMessageItem *messageItem = [[TGConversationMessageItem alloc] initWithMessage:message];
                            if (isMultichat)
                            {
                                NSNumber *nUid = [[NSNumber alloc] initWithInt:(int)message.fromUid];
                                TGUser *author = [cachedUsers objectForKey:nUid];
                                if (author == nil)
                                {
                                    author = [[TGDatabase instance] loadUser:(int)message.fromUid];
                                    if (author != nil)
                                        [cachedUsers setObject:author forKey:nUid];
                                }
                                messageItem.author = author;
                            }
                            addMessageActionUsers(message, messageItem);
                            [itemsToPrecalculate addObject:messageItem];
                            [items addObject:messageItem];
                        }
                        
                        if (lastDayDate != 0)
                        {
                            TGConversationDateItem *dateItem = [[TGConversationDateItem alloc] initWithDate:(lastDayDate - dateDifferenceFromGMT)];
                            [itemsToPrecalculate addObject:dateItem];
                            [items addObject:dateItem];
                        }
                        
                        if ([path hasSuffix:@"/(up0)"] && resultLoadedUnread)
                        {
                            int itemCount = items.count;
                            for (int i = itemCount - 1; i >= 0; i--)
                            {
                                TGConversationItem *item = [items objectAtIndex:i];
                                
                                if (item.type == TGConversationItemTypeMessage)
                                {
                                    TGConversationMessageItem *messageItem = (TGConversationMessageItem *)item;
                                    TGMessage *message = messageItem.message;
                                    if (!message.outgoing && message.unread)
                                    {
                                        int insertIndex = i + 1;
                                        for (int j = i + 1; j < itemCount; j++)
                                        {
                                            TGConversationItem *anotherItem = [items objectAtIndex:j];
                                            if (anotherItem.type == TGConversationItemTypeMessage)
                                            {
                                                insertIndex = j;
                                                break;
                                            }
                                        }
                                        
                                        int unreadCount = 0;
                                        for (int j = i; j >= 0; j--)
                                        {
                                            TGConversationItem *anotherItem = [items objectAtIndex:j];
                                            if (anotherItem.type == TGConversationItemTypeMessage)
                                            {
                                                TGMessage *message = ((TGConversationMessageItem *)anotherItem).message;
                                                if (message.unread && !message.outgoing)
                                                    unreadCount++;
                                            }
                                        }
                                        
                                        if (unreadCount >= (self.conversationId < 0 && !self.isEncrypted ? 3 : 10))
                                        {
                                            TGConversationUnreadItem *unreadItem = [[TGConversationUnreadItem alloc] initWithUnreadCount:unreadCount];
                                            [items insertObject:unreadItem atIndex:insertIndex];
                                            scrollToUnread = true;
                                        }
                                        
                                        break;
                                    }
                                }
                            }
                        }
                        
                        [self.conversationItems addObjectsFromArray:items];
                    }
                    else
                    {
                        NSMutableArray *conversationItems = self.conversationItems;
                        
                        if (isDownwardsRequest)
                        {
                            keepScrollOffset = true;
                            
                            int maxInsertIndex = 0;
                            
                            for (TGMessage *message in receivedItems)
                            {
                                int date = (int)message.date;
                                
                                int itemsCount = conversationItems.count;
                                for (int i = 0; i < itemsCount; i++)
                                {
                                    TGConversationItem *item = [conversationItems objectAtIndex:i];
                                    if (item.type == TGConversationItemTypeMessage)
                                    {
                                        TGMessage *localMessage = ((TGConversationMessageItem *)item).message;
                                        if (((int)(localMessage.date)) <= date)
                                        {
                                            TGConversationMessageItem *messageItem = [[TGConversationMessageItem alloc] initWithMessage:message];
                                            if (isMultichat)
                                            {
                                                NSNumber *nUid = [[NSNumber alloc] initWithInt:(int)message.fromUid];
                                                TGUser *author = [cachedUsers objectForKey:nUid];
                                                if (author == nil)
                                                {
                                                    author = [[TGDatabase instance] loadUser:(int)message.fromUid];
                                                    if (author != nil)
                                                        [cachedUsers setObject:author forKey:nUid];
                                                }
                                                messageItem.author = author;
                                            }
                                            addMessageActionUsers(message, messageItem);
                                            [itemsToPrecalculate addObject:messageItem];
                                            [conversationItems insertObject:messageItem atIndex:i];
                                            
                                            maxInsertIndex++;
                                            
                                            break;
                                        }
                                    }
                                }
                            }
                            
                            std::set<int> midSet;
                            int itemsCount = conversationItems.count;
                            for (int i = 0; i < itemsCount; i++)
                            {
                                TGConversationItem *item = [conversationItems objectAtIndex:i];
                                if (item.type == TGConversationItemTypeMessage)
                                {
                                    int mid = ((TGConversationMessageItem *)item).message.mid;
                                    
                                    std::set<int>::iterator it = midSet.find(mid);
                                    if (it != midSet.end())
                                    {
                                        [conversationItems removeObjectAtIndex:i];
                                        i--;
                                        itemsCount--;
                                    }
                                    else
                                        midSet.insert(mid);
                                }
                            }
                            
                            itemsCount = conversationItems.count;
                    
                            int lastDayDate = 0;
                    
                            for (int i = 0; i < itemsCount; i++)
                            {
                                TGConversationItem *item = [conversationItems objectAtIndex:i];
                                if (item.type == TGConversationItemTypeMessage)
                                {
                                    TGMessage *message = ((TGConversationMessageItem *)item).message;
                                    int currentDayDate = (int)((int)(message.date) + offsetFromGMT);
                                    if (lastDayDate != 0)
                                    {
                                        if (currentDayDate / (24 * 60 * 60) != lastDayDate / (24 * 60 * 60))
                                        {
                                            TGConversationDateItem *dateItem = [[TGConversationDateItem alloc] initWithDate:(lastDayDate - offsetFromGMT)];
                                            [itemsToPrecalculate addObject:dateItem];
                                            [self.conversationItems insertObject:dateItem atIndex:i];
                                            itemsCount++;
                                            i++;
                                        }
                                    }
                                    
                                    lastDayDate = currentDayDate;
                                }
                                else if (item.type == TGConversationItemTypeDate)
                                {
                                    break;
                                }
                            }
                        }
                        else
                        {
                            if (conversationItems.count != 0 && ((TGConversationItem *)[conversationItems lastObject]).type == TGConversationItemTypeDate)
                                [conversationItems removeLastObject];
                            
                            int minInsertIndex = INT_MAX;
                            
                            for (TGMessage *message in receivedItems)
                            {
                                int date = (int)message.date;
                                
                                for (int i = conversationItems.count - 1; i >= 0; i--)
                                {
                                    TGConversationItem *item = [conversationItems objectAtIndex:i];
                                    if (item.type == TGConversationItemTypeMessage)
                                    {
                                        TGMessage *localMessage = ((TGConversationMessageItem *)item).message;
                                        if (((int)(localMessage.date)) >= date)
                                        {
                                            TGConversationMessageItem *messageItem = [[TGConversationMessageItem alloc] initWithMessage:message];
                                            if (isMultichat)
                                            {
                                                NSNumber *nUid = [[NSNumber alloc] initWithInt:(int)message.fromUid];
                                                TGUser *author = [cachedUsers objectForKey:nUid];
                                                if (author == nil)
                                                {
                                                    author = [[TGDatabase instance] loadUser:(int)message.fromUid];
                                                    if (author != nil)
                                                        [cachedUsers setObject:author forKey:nUid];
                                                }
                                                messageItem.author = author;
                                            }
                                            addMessageActionUsers(message, messageItem);
                                            [itemsToPrecalculate addObject:messageItem];
                                            [conversationItems insertObject:messageItem atIndex:i + 1];
                                            
                                            if (i < minInsertIndex)
                                                minInsertIndex = i;
                                            
                                            break;
                                        }
                                    }
                                }
                            }
                            
                            if (wasEmpty)
                                TGLog(@"===== Insert time: %f ms", (CFAbsoluteTimeGetCurrent() - dbStartTime) * 1000.0);
                            
                            if (minInsertIndex > 0)
                                minInsertIndex--;
                            
                            int conversationItemsCount = conversationItems.count;
                            for (int i = minInsertIndex; i < conversationItemsCount; i++)
                            {
                                TGConversationItem *item = [conversationItems objectAtIndex:i];
                                if (item.type == TGConversationItemTypeDate)
                                {
                                    [self.conversationItems removeObjectAtIndex:i];
                                    i--;
                                    conversationItemsCount--;
                                }
                            }
                            
                            std::set<int> midSet;
                            int itemsCount = conversationItems.count;
                            for (int i = 0; i < itemsCount; i++)
                            {
                                TGConversationItem *item = [conversationItems objectAtIndex:i];
                                if (item.type == TGConversationItemTypeMessage)
                                {
                                    int mid = ((TGConversationMessageItem *)item).message.mid;
                                    
                                    std::set<int>::iterator it = midSet.find(mid);
                                    if (it != midSet.end())
                                    {
                                        [conversationItems removeObjectAtIndex:i];
                                        i--;
                                        itemsCount--;
                                    }
                                    else
                                        midSet.insert(mid);
                                }
                            }
                            
                            int lastDayDate = 0;
                            conversationItemsCount = conversationItems.count;
                            for (int i = MAX(minInsertIndex - 1, 0); i < conversationItemsCount; i++)
                            {
                                TGConversationItem *item = [conversationItems objectAtIndex:i];
                                if (item.type == TGConversationItemTypeMessage)
                                {
                                    TGMessage *message = ((TGConversationMessageItem *)item).message;
                                    int currentDayDate = (int)((int)(message.date) + offsetFromGMT);
                                    if (lastDayDate != 0)
                                    {
                                        if (currentDayDate / (24 * 60 * 60) != lastDayDate / (24 * 60 * 60))
                                        {
                                            TGConversationDateItem *dateItem = [[TGConversationDateItem alloc] initWithDate:(lastDayDate - offsetFromGMT)];
                                            [itemsToPrecalculate addObject:dateItem];
                                            [self.conversationItems insertObject:dateItem atIndex:i];
                                            conversationItemsCount++;
                                        }
                                    }
                                    lastDayDate = currentDayDate;
                                }
                            }
                            
                            if (lastDayDate != 0)
                            {
                                TGConversationDateItem *dateItem = [[TGConversationDateItem alloc] initWithDate:(lastDayDate - [self offsetFromGMT])];
                                [itemsToPrecalculate addObject:dateItem];
                                [conversationItems addObject:dateItem];
                            }
                        }
                        
                        /*dbStartTime = CFAbsoluteTimeGetCurrent();
                        
                        if (wasEmpty)
                            TGLog(@"===== Reduce time: %f ms", (CFAbsoluteTimeGetCurrent() - dbStartTime) * 1000.0);*/
                                                
                        items = [[NSMutableArray alloc] initWithArray:conversationItems];
                    }
                    
                    if (wasEmpty)
                        TGLog(@"Processing time: %f ms", (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0);
                    
                    startTime = CFAbsoluteTimeGetCurrent();
                    
#warning precalculate only for screen height
                    
                    NSMutableArray *delayedItems = nil;
                    
                    if (scrollToUnread)
                    {
                        delayedItems = [[NSMutableArray alloc] init];
                        int itemCount = items.count;
                        
                        for (int i = itemCount - 1; i >= 0; i--)
                        {
                            TGConversationItem *item = [items objectAtIndex:i];
                            if (item.type == TGConversationItemTypeUnread)
                            {
                                NSRange deleteRange = NSMakeRange(0, 0);
                                for (int j = 0; j < i - 18; j++)
                                {
                                    [delayedItems addObject:[items objectAtIndex:j]];
                                    deleteRange.length++;
                                }
                                
                                if (deleteRange.length > 0)
                                    [items removeObjectsInRange:deleteRange];
                                break;
                            }
                        }
                        
                        [itemsToPrecalculate removeAllObjects];
                        [itemsToPrecalculate addObjectsFromArray:items];
                    }
                    
                    TGConversationController *conversationController = self.conversationController;
                    for (TGConversationItem *item in itemsToPrecalculate)
                    {
                        [conversationController precalculateItemMetrics:item];
                    }
                    TGLog(@"Precalculated %d items", itemsToPrecalculate.count);
                    [itemsToPrecalculate removeAllObjects];
                    
                    if (wasEmpty)
                        TGLog(@"Precalculating time: %f ms", (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0);
            
                    int scrollToMid = 0;
                    if (!scrollToUnread && _openAtMessageId != 0 && [path hasSuffix:@"history/(up0)"] && !clearExisting)
                    {
                        scrollToMid = _openAtMessageId;
                    }
                    
                    bool freezeConversation = scrollToUnread && delayedItems.count != 0;
                    
                    if (scrollToUnread && delayedItems.count > 100)
                    {
                        delayedItems = nil;
                        self.canLoadMoreHistoryDownwards = true;
                        suggestToLoadMoreHistory = true;
                        freezeConversation = false;
                        [self.conversationItems removeAllObjects];
                        [self.conversationItems addObjectsFromArray:items];
                    }
                    
                    [self updateMediaStatuses:items];
            
                    NSTimeInterval updateStartTime = CFAbsoluteTimeGetCurrent();
                    dispatch_async(dispatch_get_main_queue(), ^
                    {
                        if (isDownwardsRequest)
                            self.isLoadingDownwards = false;
                        else
                            self.isLoading = false;
                        
                        if (freezeConversation)
                            [self.conversationController freezeConversation:true];
                        
                        int scrollFlags = 0;
                        if (scrollToUnread)
                            scrollFlags |= TGConversationControllerUpdateFlagsScrollToUnread;
                        if (keepScrollOffset)
                            scrollFlags |= TGConversationControllerUpdateFlagsScrollKeep;
                        if (clearExisting)
                            scrollFlags |= TGConversationControllerUpdateFlagsScrollDown;
                        
                        [self.conversationController conversationHistoryFullyReloaded:items scrollToMid:scrollToMid scrollFlags:scrollFlags];
                        if (suggestToLoadMoreHistory)
                            [self.conversationController timeToLoadMoreHistory];
                        if (wasEmpty)
                            TGLog(@"Update time: %f ms", (CFAbsoluteTimeGetCurrent() - updateStartTime) * 1000.0);
                    });
                    
                    if (scrollToUnread && delayedItems.count != 0)
                    {
                        [itemsToPrecalculate addObjectsFromArray:delayedItems];
                        NSArray *interfaceItems = [[NSArray alloc] initWithArray:self.conversationItems];
                        [self updateMediaStatuses:interfaceItems];
                        for (TGConversationItem *item in itemsToPrecalculate)
                        {
                            [conversationController precalculateItemMetrics:item];
                        }
                        TGLog(@"Precalculated %d items", itemsToPrecalculate.count);
                        [itemsToPrecalculate removeAllObjects];
                        
                        dispatch_async(dispatch_get_main_queue(), ^
                        {
                            self.isLoading = false;
                            [self.conversationController freezeConversation:false];
                            
                            int scrollFlags = TGConversationControllerUpdateFlagsScrollToUnread;
                            [self.conversationController conversationHistoryFullyReloaded:interfaceItems scrollToMid:0 scrollFlags:scrollFlags];
                            if (suggestToLoadMoreHistory)
                                [self.conversationController timeToLoadMoreHistory];
                            if (wasEmpty)
                                TGLog(@"Update time: %f ms", (CFAbsoluteTimeGetCurrent() - updateStartTime) * 1000.0);
                        });
                    }
                }
            }
            
#warning load authors also
            
            [self clearUnreadIfNeeded:false];
            
            dispatch_async(dispatch_get_main_queue(), ^
            {
                if (isDownwardsRequest)
                {
                    self.isLoadingDownwards = false;
                    [self.conversationController conversationDownwardsHistoryLoadingCompleted];
                }
                else
                {
                    self.isLoading = false;
                    [self.conversationController conversationHistoryLoadingCompleted];
                }
            });
        }, false);
    }
    else if ([path hasPrefix:[NSString stringWithFormat:@"/tg/conversations/(%@)/sendMessage/(", _dispatchConversationTag]])
    {
        int startIndex = [path rangeOfString:@"/sendMessage/("].location + 14;
        int localMid = [[path substringWithRange:NSMakeRange(startIndex, path.length - startIndex - 1)] intValue];
        
        dispatchOnMessageQueue(^
        {   
            std::tr1::shared_ptr<std::map<int, float> > pMessageUploadProgress;
            
            bool shouldDispatchUploadProgress = _messageUploadProgress.find(localMid) != _messageUploadProgress.end();
            bool dispatchedUploadProgress = false;
            if (shouldDispatchUploadProgress)
            {
                _messageUploadProgress.erase(localMid);
                pMessageUploadProgress = [self messageUploadProgressCopy];
            }
            
            [self _messageDelivered:localMid addedMessages:((SGraphListNode *)result).items success:resultCode == ASStatusSuccess shouldDispatchUploadProgress:shouldDispatchUploadProgress pMessageUploadProgress:pMessageUploadProgress pDispatchedUploadProgress:&dispatchedUploadProgress];
            
            if (shouldDispatchUploadProgress && !dispatchedUploadProgress)
            {
                dispatch_async(dispatch_get_main_queue(), ^
                {
                    [self.conversationController conversationMessageUploadProgressChanged:pMessageUploadProgress];
                });
            }
        }, false);
    }
    else if ([path hasPrefix:[NSString stringWithFormat:@"/tg/contacts/requestActor/(%lld)", [self singleUserId]]])
    {
        if ([path hasSuffix:@"(requestContact)"])
        {
            _runningLinkAction = nil;
            
            dispatch_async(dispatch_get_main_queue(), ^
            {
                [self.conversationController linkActionInProgress:0 inProgress:false];
            });
        }
        else if ([path hasSuffix:@"(acceptContact)"])
        {
            _runningLinkAction = nil;
            
            dispatch_async(dispatch_get_main_queue(), ^
            {
                [self.conversationController linkActionInProgress:1 inProgress:false];
            });
        }
    }
    else if ([path hasPrefix:@"/tg/encrypted/acceptEncryptedChat/"])
    {
    }
}

- (void)actorReportedProgress:(NSString *)path progress:(float)progress
{
    if ([path hasPrefix:[NSString stringWithFormat:@"/tg/conversations/(%@)/sendMessage/(", _dispatchConversationTag]])
    {
        int startIndex = [path rangeOfString:@"/sendMessage/("].location + 14;
        int localMid = [[path substringWithRange:NSMakeRange(startIndex, path.length - startIndex - 1)] intValue];
        
        dispatchOnMessageQueue(^
        {
            _messageUploadProgress[localMid] = progress;
            
            std::tr1::shared_ptr<std::map<int, float> > pMessageUploadProgress = [self messageUploadProgressCopy];
            dispatch_async(dispatch_get_main_queue(), ^
            {
                [self.conversationController conversationMessageUploadProgressChanged:pMessageUploadProgress];
            });
        }, false);
    }
}

- (void)insertIntoIndexArray:(NSMutableArray *)insertedIndices insertedItems:(NSMutableArray *)insertedItems index:(int)index item:(TGConversationItem *)item
{
    bool inserted = false;
    for (int i = 0; i < (int)insertedIndices.count; i++)
    {
        NSNumber *currentIndex = [insertedIndices objectAtIndex:i];
        if ([currentIndex intValue] >= index)
        {
            for (int j = i; j < (int)insertedIndices.count; j++)
            {
                NSNumber *indexToReplace = [insertedIndices objectAtIndex:j];
                [insertedIndices replaceObjectAtIndex:j withObject:[NSNumber numberWithInt:([indexToReplace intValue] + 1)]];
            }
            
            [insertedIndices insertObject:[NSNumber numberWithInt:index] atIndex:i];
            [insertedItems insertObject:item atIndex:i];
            inserted = true;
            
            break;
        }
    }
    
    if (!inserted)
    {
        [insertedIndices addObject:[NSNumber numberWithInt:index]];
        [insertedItems addObject:item];
    }
}

- (void)actionStageResourceDispatched:(NSString *)path resource:(id)resource arguments:(id)__unused arguments
{
    if ([path isEqualToString:@"/tg/service/synchronizationstate"])
    {
        [self actorCompleted:ASStatusSuccess path:path result:resource];
    }
    else if ([path isEqualToString:[NSString stringWithFormat:@"/tg/conversation/(%@)/typing", _dispatchConversationTag]])
    {
        [self actorCompleted:ASStatusSuccess path:path result:resource];
    }
    else if ([path hasPrefix:@"/tg/userLink/"])
    {
        [self actorCompleted:ASStatusSuccess path:path result:resource];
    }
    else if ([path hasPrefix:@"/tg/peerSettings"])
    {
        [self actorCompleted:ASStatusSuccess path:path result:resource];
    }
    else if ([path isEqualToString:@"/as/updateRelativeTimestamps"])
    {
        if ([self updateSubtitle])
        {
            NSString *title = self.conversationTitle;
            NSString *subtitle = self.conversationSubtitle;
            NSString *typingSubtitle = self.conversationTypingSubtitle;
            bool isContact = _isContact;
            
            dispatch_async(dispatch_get_main_queue(), ^
            {
                [self.conversationController conversationTitleChanged:title subtitle:subtitle typingSubtitle:typingSubtitle isContact:isContact];
            });
        }
    }
    else if ([path isEqualToString:@"/tg/userdatachanges"])
    {
        NSArray *users = ((SGraphObjectNode *)resource).object;
        
        if (!self.isMultichat || self.isEncrypted)
        {
            int targetUserId = (int)[self singleUserId];
            
            TGUser *selectedUser = nil;
            for (TGUser *user in users)
            {
                if (user.uid == targetUserId)
                {
                    selectedUser = user;
                    break;
                }
            }
            
            if (selectedUser != nil)
            {
                self.singleParticipant = selectedUser;
                
                bool titleUpdated = [self updateTitle];
                bool subtitleUpdated = [self updateSubtitle];
                
                NSString *title = self.conversationTitle;
                NSString *subtitle = self.conversationSubtitle;
                NSString *typingSubtitle = self.conversationTypingSubtitle;
                bool isContact = _isContact;
                
                dispatch_async(dispatch_get_main_queue(), ^
                {
                    [self.conversationController conversationParticipantDataChanged:selectedUser];
                    
                    if (titleUpdated || subtitleUpdated)
                        [self.conversationController conversationTitleChanged:title subtitle:subtitle typingSubtitle:typingSubtitle isContact:isContact];
                    
                    if (!self.isMultichat || self.isEncrypted)
                        [self.conversationController conversationSignleParticipantChanged:selectedUser];
                });
            }
        }
        else
        {
            NSMutableArray *filteredUsers = [[NSMutableArray alloc] init];
            std::tr1::shared_ptr<std::map<int, int> > changedUsers(new std::map<int, int>());
            std::set<int> userExistsSet;
            int userIndex = -1;
            for (NSNumber *nUid in _conversation.chatParticipants.chatParticipantUids)
            {
                userIndex++;
                userExistsSet.insert([nUid intValue]);
            }
            
            for (TGUser *user in users)
            {
                std::set<int>::iterator it = userExistsSet.find(user.uid);
                if (it != userExistsSet.end())
                {
                    [filteredUsers addObject:user];
                    changedUsers->insert(std::pair<int, int>(user.uid, [filteredUsers count] - 1));
                    break;
                }
            }
            
            if (filteredUsers.count != 0)
            {
                dispatchOnMessageQueue(^
                {
                    NSMutableArray *replacedIndices = [[NSMutableArray alloc] init];
                    NSMutableArray *replacedItems = [[NSMutableArray alloc] init];
                    
                    NSArray *conversationItems = self.conversationItems;
                    int itemsCount = conversationItems.count;
                    for (int i = 0; i < itemsCount; i++)
                    {
                        TGConversationItem *item = [conversationItems objectAtIndex:i];
                        
                        if (item.type == TGConversationItemTypeMessage)
                        {
                            TGConversationMessageItem *messageItem = (TGConversationMessageItem *)item;
                            std::map<int, int>::iterator userIt = changedUsers->find(messageItem.author.uid);
                            if (userIt != changedUsers->end())
                            {
                                TGConversationMessageItem *newItem = [[TGConversationMessageItem alloc] initWithMessage:messageItem.message];
                                newItem.author = [filteredUsers objectAtIndex:userIt->second];
                                
                                [replacedIndices addObject:[NSNumber numberWithInt:i]];
                                [replacedItems addObject:newItem];
                            }
                        }
                    }
                    
                    dispatch_async(dispatch_get_main_queue(), ^
                    {
                        [self.conversationController changeModelItems:replacedIndices items:replacedItems];
                    });
                }, false);
                    
                bool titleUpdated = [self updateTitle];
                bool subtitleUpdated = [self updateSubtitle];
                
                NSString *title = self.conversationTitle;
                NSString *subtitle = self.conversationSubtitle;
                NSString *typingSubtitle = self.conversationTypingSubtitle;
                bool isContact = _isContact;
                
                dispatch_async(dispatch_get_main_queue(), ^
                {
                    for (TGUser *user in filteredUsers)
                        [self.conversationController conversationParticipantDataChanged:user];
                    
                    if (titleUpdated || subtitleUpdated)
                        [self.conversationController conversationTitleChanged:title subtitle:subtitle typingSubtitle:typingSubtitle isContact:isContact];
                });
            }
        }
    }
    else if ([path isEqualToString:@"/tg/userpresencechanges"])
    {
        NSArray *users = ((SGraphObjectNode *)resource).object;
        
        if (!self.isMultichat || self.isEncrypted)
        {
            int targetUserId = (int)[self singleUserId];
            
            for (TGUser *user in users)
            {
                if (user.uid == targetUserId)
                {
                    self.singleParticipant = user;
                    
                    bool titleUpdated = [self updateTitle];
                    bool subtitleUpdated = [self updateSubtitle];
                    
                    NSString *title = self.conversationTitle;
                    NSString *subtitle = self.conversationSubtitle;
                    NSString *typingSubtitle = self.conversationTypingSubtitle;
                    bool isContact = _isContact;
                    
                    dispatch_async(dispatch_get_main_queue(), ^
                    {
                        if (titleUpdated || subtitleUpdated)
                            [self.conversationController conversationTitleChanged:title subtitle:subtitle typingSubtitle:typingSubtitle isContact:isContact];
                    });
                    
                    break;
                }
            }
        }
        else
        {
            bool subtitleUpdated = [self updateSubtitle];
            
            if (subtitleUpdated)
            {
                NSString *title = self.conversationTitle;
                NSString *subtitle = self.conversationSubtitle;
                NSString *typingSubtitle = self.conversationTypingSubtitle;
                bool isContact = _isContact;
                
                dispatch_async(dispatch_get_main_queue(), ^
                {
                    [self.conversationController conversationTitleChanged:title subtitle:subtitle typingSubtitle:typingSubtitle isContact:isContact];
                });
            }
        }
    }
    else if ([path isEqualToString:@"/tg/contactlist"])
    {
      if (!self.isMultichat || self.isEncrypted)
      {
          bool titleUpdated = [self updateTitle];
          bool subtitleUpdated = [self updateSubtitle];
          
          NSString *title = self.conversationTitle;
          NSString *subtitle = self.conversationSubtitle;
          NSString *typingSubtitle = self.conversationTypingSubtitle;
          bool isContact = _isContact;
          
          dispatch_async(dispatch_get_main_queue(), ^
          {
              if (titleUpdated || subtitleUpdated)
                  [self.conversationController conversationTitleChanged:title subtitle:subtitle typingSubtitle:typingSubtitle isContact:isContact];
          });
      }
    }
    else if ([path hasPrefix:@"/tg/conversationMessageLifetime/"])
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            [self.conversationController messageLifetimeChanged:[resource intValue]];
        });
    }
    else if ([path hasPrefix:@"/tg/conversationReadApplied/"])
    {
        dispatchOnMessageQueue(^
        {
            if ([resource intValue] == _minRemoteUnreadId)
                _minRemoteUnreadId = 0;
        }, false);
    }
    else if ([path isEqualToString:[NSString stringWithFormat:@"/tg/conversation/(%@)/messages", _dispatchConversationTag]])
    {
        if (self.canLoadMoreHistoryDownwards)
        {
            TGLog(@"Skipping new messages, have unloaded messages below");
            
            bool sendingMessages = _sendingMessages;
            bool clearText = _sendingMessagesClearText;
            
            bool showNewMessages = false;
            
            NSArray *messages = ((SGraphObjectNode *)resource).object;
            for (TGMessage *message in messages)
            {
                if (!message.outgoing && message.unread)
                {
                    showNewMessages = true;
                    break;
                }
            }
            
            dispatch_async(dispatch_get_main_queue(), ^
            {
                TGConversationController *conversationController = self.conversationController;
                
                if (sendingMessages)
                {
                    if (clearText)
                        [conversationController clearInputText];
                }
                
                if ([conversationController shouldReadHistory])
                    [self clearUnreadIfNeeded:false];
                
                if (showNewMessages)
                    [conversationController displayNewMessagesTooltip];
            });
            
            if (sendingMessages)
                [self reloadHistoryShortcut];
            
            return;
        }
        
        dispatchOnMessageQueue(^
        {
            NSMutableArray *messages = [((SGraphObjectNode *)resource).object mutableCopy];
            
            bool haveIncoming = _conversationId == TGTelegraphInstance.clientUserId;
            
            std::set<int> existingMids;
            
            NSMutableArray *conversationItems = self.conversationItems;
            
            for (TGConversationItem *item in conversationItems)
            {
                if (item.type == TGConversationItemTypeMessage)
                {
                    existingMids.insert(((TGConversationMessageItem *)item).message.mid);
                }
            }
            
            for (int i = 0; i < (int)messages.count; i++)
            {
                TGMessage *message = [messages objectAtIndex:i];
                if (existingMids.find(message.mid) != existingMids.end())
                {
                    [messages removeObjectAtIndex:i];
                    i--;
                }
                else
                {
                    existingMids.insert(message.mid);
                }
            }
            
            if (messages.count == 0)
            {
                if (haveIncoming)
                    [self clearUnreadIfNeeded:false];
                return;
            }
            
            [messages sortUsingComparator:^NSComparisonResult(TGMessage *message1, TGMessage *message2)
            {
                int date1 = (int)message1.date;
                int date2 = (int)message2.date;
                
                if (date1 < date2)
                    return NSOrderedAscending;
                else if (date1 > date2)
                    return NSOrderedDescending;
                else
                {
                    int mid1 = message1.mid;
                    int mid2 = message2.mid;
                    if (mid1 < mid2)
                        return NSOrderedAscending;
                    else if (mid1 > mid2)
                        return NSOrderedDescending;
                    
                    return NSOrderedSame;
                }
            }];
            
            NSArray *removedIndices = nil;
            
            if (_sendingMessages && !_didRemoveUnreadMarker)
            {
                _didRemoveUnreadMarker = true;
                
                int index = -1;
                for (TGConversationMessageItem *item in conversationItems)
                {
                    index++;
                    
                    if (item.type == TGConversationItemTypeUnread)
                    {
                        removedIndices = [[NSArray alloc] initWithObjects:[[NSNumber alloc] initWithInt:index], nil];
                        [conversationItems removeObjectAtIndex:index];
                        break;
                    }
                }
            }
            
            TGConversationController *controller = self.conversationController;
            
            NSMutableArray *insertedIndices = [[NSMutableArray alloc] init];
            NSMutableArray *insertedItems = [[NSMutableArray alloc] init];
            
            NSMutableDictionary *cachedUsers = [[NSMutableDictionary alloc] init];
            bool isMultichat = self.isMultichat && !self.isEncrypted;
            
            for (TGMessage *message in messages)
            {
                int messageDate = (int)(message.date + [self offsetFromGMT]);
                int messageMid = message.mid;
                
                bool inserted = false;
                for (int i = 0; i < (int)conversationItems.count; i++)
                {
                    TGConversationItem *item = [conversationItems objectAtIndex:i];
                    int currentDate = 0;
                    if (item.type == TGConversationItemTypeMessage)
                    {
                        TGMessage *messageItemMessage = ((TGConversationMessageItem *)item).message;
                        currentDate = (int)(messageItemMessage.date + [self offsetFromGMT]);
                    
                        if (messageDate >= currentDate || messageMid > messageItemMessage.mid)
                        {
                            TGConversationMessageItem *newMessageItem = [[TGConversationMessageItem alloc] initWithMessage:message];
                            if (isMultichat)
                            {
                                NSNumber *nUid = [[NSNumber alloc] initWithInt:(int)message.fromUid];
                                TGUser *author = [cachedUsers objectForKey:nUid];
                                if (author == nil)
                                {
                                    author = [[TGDatabase instance] loadUser:(int)message.fromUid];
                                    if (author != nil)
                                        [cachedUsers setObject:author forKey:nUid];
                                }
                                newMessageItem.author = author;
                            }
                            addMessageActionUsers(message, newMessageItem);
                            [controller precalculateItemMetrics:newMessageItem];
                            
                            int insertIndex = i;
                            bool tryInsertDate = true;
                            
                            if (i - 1 >= 0)
                            {
                                TGConversationItem *prevItem = [conversationItems objectAtIndex:(i - 1)];
                                if (prevItem.type == TGConversationItemTypeDate)
                                {
                                    if ((((TGConversationDateItem *)prevItem).date + [self offsetFromGMT]) / (24 * 60 * 60) == (messageDate) / (24 * 60 * 60))
                                    {
                                        insertIndex = i - 1;
                                        tryInsertDate = false;
                                    }
                                }
                            }

                            [conversationItems insertObject:newMessageItem atIndex:insertIndex];
                            [self insertIntoIndexArray:insertedIndices insertedItems:insertedItems index:insertIndex item:newMessageItem];
                            
                            if (tryInsertDate && (currentDate / (24 * 60 * 60) != messageDate / (24 * 60 * 60)))
                            {
                                TGConversationDateItem *dateItem = [[TGConversationDateItem alloc] initWithDate:(messageDate - [self offsetFromGMT])];
                                [controller precalculateItemMetrics:dateItem];

                                [conversationItems insertObject:dateItem atIndex:(i + 1)];
                                [self insertIntoIndexArray:insertedIndices insertedItems:insertedItems index:(i + 1) item:dateItem];
                            }
                            
                            inserted = true;
                            break;
                        }
                    }
                }
                
                if (!inserted)
                {
                    TGConversationMessageItem *newMessageItem = [[TGConversationMessageItem alloc] initWithMessage:message];
                    if (isMultichat)
                    {
                        NSNumber *nUid = [[NSNumber alloc] initWithInt:(int)message.fromUid];
                        TGUser *author = [cachedUsers objectForKey:nUid];
                        if (author == nil)
                        {
                            author = [[TGDatabase instance] loadUser:(int)message.fromUid];
                            if (author != nil)
                                [cachedUsers setObject:author forKey:nUid];
                        }
                        newMessageItem.author = author;
                    }
                    addMessageActionUsers(message, newMessageItem);
                    [controller precalculateItemMetrics:newMessageItem];
                    
                    [self insertIntoIndexArray:insertedIndices insertedItems:insertedItems index:conversationItems.count item:newMessageItem];
                    [conversationItems insertObject:newMessageItem atIndex:conversationItems.count];
                    
                    if (true)
                    {
                        TGConversationDateItem *dateItem = [[TGConversationDateItem alloc] initWithDate:(messageDate - [self offsetFromGMT])];
                        [controller precalculateItemMetrics:dateItem];

                        [self insertIntoIndexArray:insertedIndices insertedItems:insertedItems index:(conversationItems.count) item:dateItem];
                        [conversationItems insertObject:dateItem atIndex:(conversationItems.count)];
                    }
                }
            }
            
            bool scrollToUnread = false;
            bool actuallyScrollToUnread = false;
            
            if (true)
            {
                int lookupLimit = conversationItems.count;
                
                int insertIndex = -1;
                int unreadCount = 0;
                bool cancelSearch = false;
                bool lookForUnread = true;
                
                int replaceIndex = -1;
                TGConversationUnreadItem *replaceItem = nil;
                
                for (int i = 0; i < lookupLimit; i++)
                {
                    TGConversationItem *item = [conversationItems objectAtIndex:i];
                    switch (item.type)
                    {
                        case TGConversationItemTypeUnread:
                        {
                            replaceItem = [[TGConversationUnreadItem alloc] initWithUnreadCount:((TGConversationUnreadItem *)item).unreadCount];
                            replaceIndex = i;
                            
                            cancelSearch = true;
                            
                            break;
                        }
                        case TGConversationItemTypeMessage:
                        {
                            if (lookForUnread)
                            {
                                TGMessage *message = ((TGConversationMessageItem *)item).message;
                                if (!message.outgoing && message.unread)
                                {
                                    insertIndex = i + 1;
                                    unreadCount++;
                                }
                                else
                                {
                                    lookForUnread = false;
                                }
                            }
                            
                            break;
                        }
                        default:
                            break;
                    }
                    
                    if (cancelSearch)
                        break;
                }
                
                const int unreadLimit = 10;
                if (insertIndex >= 0 && unreadCount >= unreadLimit)
                {
                    if (replaceIndex >= 0)
                    {
                        //replaceItem.unreadCount = replaceItem.unreadCount + unreadCount;
                        [conversationItems replaceObjectAtIndex:replaceIndex withObject:replaceItem];
                        
                        actuallyScrollToUnread = false;
                        
                        //[conversationItems removeObjectAtIndex:replaceIndex];
                    }
                    else if (insertIndex < (int)conversationItems.count)
                    {
                        TGConversationMessageItem *nextItem = [conversationItems objectAtIndex:insertIndex];
                        if (nextItem.type == TGConversationItemTypeDate)
                            insertIndex++;
                        
                        TGConversationUnreadItem *unreadItem = [[TGConversationUnreadItem alloc] initWithUnreadCount:unreadCount];
                        
                        [self insertIntoIndexArray:insertedIndices insertedItems:insertedIndices index:insertIndex item:unreadItem];
                        [conversationItems insertObject:unreadItem atIndex:insertIndex];
                        
                        actuallyScrollToUnread = true;
                    }
                    
                    scrollToUnread = true;
                }
            }
            
            bool sendingMessages = _sendingMessages;
            bool clearText = _sendingMessagesClearText;
            
            [self updateMediaStatuses:insertedItems];
            
            NSArray *fullArray = scrollToUnread ? [[NSArray alloc] initWithArray:conversationItems] : nil;

            dispatch_async(dispatch_get_main_queue(), ^
            {
                if (scrollToUnread)
                {
                    int scrollFlags = 0;
                    if (actuallyScrollToUnread)
                        scrollFlags |= TGConversationControllerUpdateFlagsScrollToUnread;
                    else
                        scrollFlags |= TGConversationControllerUpdateFlagsScrollKeep;
                    [controller conversationHistoryFullyReloaded:fullArray scrollToMid:0 scrollFlags:scrollFlags];
                }
                else
                    [controller conversationMessagesChanged:insertedIndices insertedItems:insertedItems removedAtIndices:removedIndices updatedAtIndices:nil updatedItems:nil delay:sendingMessages scrollDownFlags:(sendingMessages ? (clearText ? 3 : 1) : 0)];
                
                if ([controller shouldReadHistory])
                    [self clearUnreadIfNeeded:false];
            });
        }, false);
    }
    else if ([path isEqualToString:[[NSString alloc] initWithFormat:@"/tg/conversation/(%@)/messagesChanged", _dispatchConversationTag]])
    {
        NSArray *midMessagePairs = ((SGraphObjectNode *)resource).object;
        if (midMessagePairs.count % 2 != 0)
            return;
        
        dispatch_async(dispatch_get_main_queue(), ^
        {
            [self.conversationController messageIdsChanged:midMessagePairs];
        });
    }
    else if ([path isEqualToString:@"/tg/unreadCount"])
    {
        int newUnreadCount = [((SGraphObjectNode *)resource).object intValue];

        if (_unreadCountTimer != nil)
        {
            [_unreadCountTimer invalidate];
            _unreadCountTimer = nil;
        }
        
        if (_unreadCount != newUnreadCount)
        {
            ASHandle *actionHandle = _actionHandle;
            _unreadCountTimer = [[TGTimer alloc] initWithTimeout:0.1 repeat:false completion:^
            {
                id<ASWatcher> watcher = actionHandle.delegate;
                if (watcher != nil)
                {
                    [watcher actionStageActionRequested:@"applyUnreadCount" options:[[NSDictionary alloc] initWithObjectsAndKeys:[[NSNumber alloc] initWithInt:newUnreadCount], @"unreadCount", nil]];
                }
            } queue:[ActionStageInstance() globalStageDispatchQueue]];
            [_unreadCountTimer start];
        }
    }
    else if ([path isEqualToString:@"/system/significantTimeChange"])
    {
        int dateDifferenceFromGMT = (int)([TGSession instance].timeOffsetFromUTC);
        
        //if (ABS(self.timeOffset - dateDifferenceFromGMT) < 1)
        //    return;
        
        _timeOffsetInitialized = true;
        _timeOffset = dateDifferenceFromGMT;
        
        bool subtitleUpdated = [self updateSubtitle];
        NSString *title = self.conversationTitle;
        NSString *subtitle = self.conversationSubtitle;
        NSString *typingSubtitle = self.conversationTypingSubtitle;
        bool isContact = _isContact;
        
        dispatchOnMessageQueue(^
        {
            NSMutableArray *conversationItems = self.conversationItems;
            int count = conversationItems.count;
            for (int i = 0; i < count; i++)
            {
                TGConversationItem *item = [conversationItems objectAtIndex:i];
                if (item.type != TGConversationItemTypeMessage)
                {
                    [conversationItems removeObjectAtIndex:i];
                    count--;
                    i--;
                }
            }
            
            int lastDayDate = 0;
            for (int i = 0; i < count; i++)
            {
                TGConversationMessageItem *messageItem = [conversationItems objectAtIndex:i];
                
                int currentDayDate = (int)((int)(messageItem.message.date) + dateDifferenceFromGMT);
                if (lastDayDate != 0)
                {
                    if (currentDayDate / (24 * 60 * 60) != lastDayDate / (24 * 60 * 60))
                    {
                        TGConversationDateItem *dateItem = [[TGConversationDateItem alloc] initWithDate:(lastDayDate - dateDifferenceFromGMT)];
                        [conversationItems insertObject:dateItem atIndex:i];
                        count++;
                    }
                }
                lastDayDate = currentDayDate;
            }
            
            if (lastDayDate != 0)
            {
                TGConversationDateItem *dateItem = [[TGConversationDateItem alloc] initWithDate:(lastDayDate - dateDifferenceFromGMT)];
                [conversationItems addObject:dateItem];
            }
            
            NSArray *items = [[NSArray alloc] initWithArray:conversationItems];
            
            dispatch_async(dispatch_get_main_queue(), ^
            {
                [self.conversationController conversationHistoryFullyReloaded:items];
                
                if (subtitleUpdated)
                    [self.conversationController conversationTitleChanged:title subtitle:subtitle typingSubtitle:typingSubtitle isContact:isContact];
            });
        }, false);
    }
    else if ([path isEqualToString:[NSString stringWithFormat:@"/tg/conversation/*/readmessages"]])
    {
        dispatchOnMessageQueue(^
        {
            TGSharedPtrWrapper *ptrWrapper = ((SGraphObjectNode *)resource).object;
            if (ptrWrapper == nil)
                return;
            
            std::tr1::shared_ptr<std::set<int> > mids = std::tr1::static_pointer_cast<std::set<int> >([ptrWrapper ptr]);
            
            NSMutableArray *updatedIndices = [[NSMutableArray alloc] init];
            NSMutableArray *updatedItems = [[NSMutableArray alloc] init];
            
            NSMutableArray *conversationItems = self.conversationItems;
            int itemsCount = conversationItems.count;
            for (int i = 0; i < itemsCount; i++)
            {
                TGConversationItem *item = [conversationItems objectAtIndex:i];
                if (item.type == TGConversationItemTypeMessage)
                {
                    TGConversationMessageItem *messageItem = (TGConversationMessageItem *)item;
                    if (mids->find(messageItem.message.mid) != mids->end())
                    {
                        TGConversationMessageItem *newItem = [messageItem copy];
                        newItem.message.unread = false;
                        [conversationItems replaceObjectAtIndex:i withObject:newItem];
                        
                        [updatedIndices addObject:[[NSNumber alloc] initWithInt:i]];
                        [updatedItems addObject:newItem];
                    }
                }
            }
            
            if (updatedItems.count != 0)
            {
                dispatch_async(dispatch_get_main_queue(), ^
                {
                    [self.conversationController conversationMessagesChanged:nil insertedItems:nil removedAtIndices:nil updatedAtIndices:updatedIndices updatedItems:updatedItems delay:false scrollDownFlags:0];
                });
            }
        }, false);
    }
    else if ([path isEqualToString:[[NSString alloc] initWithFormat:@"/tg/conversation/(%lld)/readByDateMessages", _conversationId]])
    {
        dispatchOnMessageQueue(^
        {
            int maxDate = [resource[@"maxDate"] intValue];
            if (maxDate != 0)
            {
                NSMutableArray *updatedIndices = [[NSMutableArray alloc] init];
                NSMutableArray *updatedItems = [[NSMutableArray alloc] init];
                
                NSMutableArray *conversationItems = self.conversationItems;
                int itemsCount = conversationItems.count;
                for (int i = 0; i < itemsCount; i++)
                {
                    TGConversationItem *item = [conversationItems objectAtIndex:i];
                    if (item.type == TGConversationItemTypeMessage)
                    {
                        TGConversationMessageItem *messageItem = (TGConversationMessageItem *)item;
                        if (messageItem.message.outgoing && ((int32_t)messageItem.message.date <= maxDate || ((int32_t)messageItem.message.realDate != 0 && (int32_t)messageItem.message.realDate <= maxDate)))
                        {
                            TGConversationMessageItem *newItem = [messageItem copy];
                            newItem.message.unread = false;
                            [conversationItems replaceObjectAtIndex:i withObject:newItem];
                            
                            [updatedIndices addObject:[[NSNumber alloc] initWithInt:i]];
                            [updatedItems addObject:newItem];
                        }
                    }
                }
                
                if (updatedItems.count != 0)
                {
                    dispatch_async(dispatch_get_main_queue(), ^
                    {
                        [self.conversationController conversationMessagesChanged:nil insertedItems:nil removedAtIndices:nil updatedAtIndices:updatedIndices updatedItems:updatedItems delay:false scrollDownFlags:0];
                    });
                }
            }
        }, false);
    }
    else if ([path isEqualToString:[NSString stringWithFormat:@"/tg/conversation/*/failmessages"]])
    {
        dispatchOnMessageQueue(^
        {
            NSArray *midsArray = resource[@"mids"];
            std::set<int> mids;
            for (NSNumber *nMid in midsArray)
                mids.insert([nMid intValue]);
            
            NSMutableArray *updatedIndices = [[NSMutableArray alloc] init];
            NSMutableArray *updatedItems = [[NSMutableArray alloc] init];
            
            NSMutableArray *conversationItems = self.conversationItems;
            int itemsCount = conversationItems.count;
            for (int i = 0; i < itemsCount; i++)
            {
                TGConversationItem *item = [conversationItems objectAtIndex:i];
                if (item.type == TGConversationItemTypeMessage)
                {
                    TGConversationMessageItem *messageItem = (TGConversationMessageItem *)item;
                    if (mids.find(messageItem.message.mid) != mids.end())
                    {
                        TGConversationMessageItem *newItem = [messageItem copy];
                        newItem.message.deliveryState = TGMessageDeliveryStateFailed;
                        [conversationItems replaceObjectAtIndex:i withObject:newItem];
                        
                        [updatedIndices addObject:[[NSNumber alloc] initWithInt:i]];
                        [updatedItems addObject:newItem];
                    }
                }
            }
            
            if (updatedItems.count != 0)
            {
                dispatch_async(dispatch_get_main_queue(), ^
                {
                    [self.conversationController conversationMessagesChanged:nil insertedItems:nil removedAtIndices:nil updatedAtIndices:updatedIndices updatedItems:updatedItems delay:false scrollDownFlags:0];
                });
            }
        }, false);
    }
    else if ([path isEqualToString:[NSString stringWithFormat:@"/tg/conversation/(%@)/messagesDeleted", _dispatchConversationTag]])
    {
        [self deleteMessagesFromList:((SGraphObjectNode *)resource).object];
    }
    else if ([path isEqualToString:[NSString stringWithFormat:@"/tg/conversation/(%@)/conversation", _dispatchConversationTag]])
    {
        [self actorCompleted:ASStatusSuccess path:path result:resource];
    }
    else if ([path isEqualToString:@"downloadManagerStateChanged"])
    {
        NSDictionary *mediaList = resource;
        if (mediaList == nil || mediaList.count == 0)
            _mediaDownloadProgress = nil;
        else
        {
            NSMutableDictionary *downloadList = [[NSMutableDictionary alloc] init];
            
            [mediaList enumerateKeysAndObjectsUsingBlock:^(__unused NSString *path, TGDownloadItem *item, __unused BOOL *stop)
            {
                if (item.itemId != nil)
                    [downloadList setObject:[[NSNumber alloc] initWithFloat:item.progress] forKey:item.itemId];
            }];
            
            _mediaDownloadProgress = downloadList;
        }

        NSMutableDictionary *mediaDownloadProgress = _mediaDownloadProgress == nil ? nil : [[NSMutableDictionary alloc] initWithDictionary:_mediaDownloadProgress];
        
        NSMutableDictionary *mediaDownloadStatuses = nil;
        
        if (arguments != nil)
        {
            for (id mediaId in [arguments objectForKey:@"completedItemIds"])
            {
                if (mediaDownloadStatuses == nil)
                    mediaDownloadStatuses = [[NSMutableDictionary alloc] init];
                
                [mediaDownloadStatuses setObject:[[NSNumber alloc] initWithBool:true] forKey:mediaId];
            }
            
            for (id mediaId in [arguments objectForKey:@"failedItemIds"])
            {
                if (mediaDownloadStatuses == nil)
                    mediaDownloadStatuses = [[NSMutableDictionary alloc] init];
                
                [mediaDownloadStatuses setObject:[[NSNumber alloc] initWithBool:false] forKey:mediaId];
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^
        {
            if (mediaDownloadStatuses != nil)
                [self.conversationController addProcessedMediaDownloadedStatuses:mediaDownloadStatuses];
            [self.conversationController conversationMediaDownloadProgressChanged:mediaDownloadProgress];
        });
    }
    else if ([path isEqualToString:@"/as/media/imageThumbnailUpdated"])
    {
        NSString *thumbnailUrl = resource;
        
        dispatchOnMessageQueue(^
        {
            bool foundUrl = false;
            
            for (TGConversationItem *item in self.conversationItems)
            {
                if (item.type == TGConversationItemTypeMessage)
                {
                    for (TGMediaAttachment *attachment in ((TGConversationMessageItem *)item).message.mediaAttachments)
                    {
                        if (attachment.type == TGImageMediaAttachmentType)
                        {
                            TGImageMediaAttachment *imageAttachment = (TGImageMediaAttachment *)attachment;
                            NSString *attachmentUrl = [imageAttachment.imageInfo closestImageUrlWithSize:CGSizeMake(90, 90) resultingSize:NULL];
                            if (attachmentUrl != nil && [attachmentUrl isEqualToString:thumbnailUrl])
                                foundUrl = true;
                            break;
                        }
                        else if (attachment.type == TGVideoMediaAttachmentType)
                        {
                            TGVideoMediaAttachment *videoAttachment = (TGVideoMediaAttachment *)attachment;
                            NSString *attachmentUrl = [videoAttachment.thumbnailInfo closestImageUrlWithSize:CGSizeMake(90, 90) resultingSize:NULL];
                            if (attachmentUrl != nil && [attachmentUrl isEqualToString:thumbnailUrl])
                                foundUrl = true;
                        }
                    }
                }
                
                if (foundUrl)
                    break;
            }
            
            if (foundUrl)
            {
                dispatch_async(dispatch_get_main_queue(), ^
                {
                    [self.conversationController reloadImageThumbnailsWithUrl:thumbnailUrl];
                });
            }
        }, false);
    }
}

- (void)actionStageActionRequested:(NSString *)action options:(NSDictionary *)__unused options
{
    if ([action isEqualToString:@"deleteConversation"])
    {
        [self leaveGroup];
    }
    else if ([action isEqualToString:@"applyUnreadCount"])
    {
        [_unreadCountTimer invalidate];
        _unreadCountTimer = nil;
        
        int newUnreadCount = [[options objectForKey:@"unreadCount"] intValue];
        _unreadCount = newUnreadCount;
        
        dispatch_async(dispatch_get_main_queue(), ^
        {
            [self.conversationController unreadCountChanged:newUnreadCount];
        });
    }
    else if ([action isEqualToString:@"willForwardMessages"])
    {
        [self.conversationController dismissViewControllerAnimated:true completion:nil];
    }
}

#pragma mark - Actions

- (void)userAvatarPressed
{
    if (self.isEncrypted)
    {
        if (self.encryptedUserId != 0)
            [[TGInterfaceManager instance] navigateToProfileOfUser:self.encryptedUserId encryptedConversationId:_encryptedConversationId];
    }
    else if (self.isMultichat)
        [self showConversationProfile:false activateTitleChange:false];
    else
        [[TGInterfaceManager instance] navigateToProfileOfUser:(int)_conversationId];
}

- (void)conversationMemberSelected:(int)uid
{
    [[TGInterfaceManager instance] navigateToProfileOfUser:(int)uid];
}

- (void)messageTypingActivity
{
    if (self.isBroadcast)
        return;
    
    CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();
    if (currentTime - _lastTypingActivityDate >= 4.0)
    {
        _lastTypingActivityDate = currentTime;
        [ActionStageInstance() dispatchOnStageQueue:^
        {
            if (self.isMultichat || [TGDatabaseInstance() loadUsersOnlineCount:[[NSArray alloc] initWithObjects:[[NSNumber alloc] initWithInt:(int)_conversationId], nil] alwaysOnlineUid:0] > 0 || ![TGDatabaseInstance() uidIsRemoteContact:(int)_conversationId])
            {
                [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/conversation/(%lld)/activity/(typing)", _conversationId] options:@{@"encryptedConversationId": @(_encryptedConversationId), @"accessHash": @(_encryptedConversationAccessHash)} watcher:self];
            }
        }];
    }
}

- (void)changeConversationTitle:(NSString *)title
{
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        static int actionId = 0;
        
        NSMutableDictionary *options = [[NSMutableDictionary alloc] init];
        [options setObject:[NSNumber numberWithLongLong:_conversation.conversationId] forKey:@"conversationId"];
        [options setObject:[NSString stringWithString:title] forKey:@"title"];
        
        NSString *path = [[NSString alloc] initWithFormat:@"/tg/conversation/(%lld)/changeTitle/(%da)", _conversation.conversationId, actionId++];
        [ActionStageInstance() requestActor:path options:options watcher:self];
        [ActionStageInstance() requestActor:path options:options watcher:TGTelegraphInstance];
    }];
}

- (void)showConversationProfile:(bool)activateCamera activateTitleChange:(bool)activateTitleChange
{
    TGTelegraphConversationProfileController *conversationProfileController = [[TGTelegraphConversationProfileController alloc] initWithConversation:_conversation];
    conversationProfileController.watcher = _actionHandle;
    _conversationProfileControllerHandle = conversationProfileController.actionHandle;
    conversationProfileController.activateCamera = activateCamera;
    conversationProfileController.activateTitleChange = activateTitleChange;
    [TGAppDelegateInstance.mainNavigationController pushViewController:conversationProfileController animated:true];
}

- (void)openContact:(TGContactMediaAttachment *)contactAttachment
{
    [[TGInterfaceManager instance] navigateToContact:contactAttachment.uid firstName:contactAttachment.firstName lastName:contactAttachment.lastName phoneNumber:contactAttachment.phoneNumber];
}

#pragma mark - Interface Assets

- (UIColor *)conversationBackground
{
    return [[TGInterfaceAssets instance] blueLinenBackground];
}

static UIImage *customBackgroundImage = nil;
static int customBackgroundImageTint = -1;

static bool _doNotRead = false;

+ (void)resetBackgroundImage
{
    customBackgroundImage = nil;
    customBackgroundImageTint = -1;
    
    [TGConversationController clearSharedCache];
}

+ (void)setDoNotRead:(bool)doNotRead
{
    _doNotRead = doNotRead;
}

+ (bool)doNotRead
{
    return _doNotRead;
}

- (UIImage *)conversationBackgroundImage
{
    if (customBackgroundImage == nil && TGAppDelegateInstance.customChatBackground)
    {
        NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true) objectAtIndex:0];
        NSString *wallpapersPath = [documentsDirectory stringByAppendingPathComponent:@"wallpapers"];
        
        customBackgroundImage = [[UIImage alloc] initWithContentsOfFile:[wallpapersPath stringByAppendingPathComponent:@"_custom.jpg"]];
        NSData *tintData = [[NSData alloc] initWithContentsOfFile:[wallpapersPath stringByAppendingPathComponent:@"_custom_mono.dat"]];
        if (tintData.length < 4)
            customBackgroundImageTint = -1;
        else
            [tintData getBytes:&customBackgroundImageTint length:4];
    }
    
    [[TGTelegraphConversationMessageAssetsSource instance] setMonochromeColor:customBackgroundImageTint];
    
    return customBackgroundImage;
}

- (UIImage *)conversationBackgroundOverlay
{
    static UIImage *image = nil;
    if (image == nil)
    {
        UIImage *rawImage = [UIImage imageNamed:@"ConversationBackgroundShadow.png"];
        image = [rawImage stretchableImageWithLeftCapWidth:(int)(rawImage.size.width / 2) topCapHeight:(int)(rawImage.size.height / 2)];
    }
    return image;
}

- (UIImage *)inputContainerShadowImage
{
    if (((TGTelegraphConversationMessageAssetsSource *)[self messageAssetsSource]).monochromeColor != -1)
    {
        static UIImage *image = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^
        {
            image = [[UIImage imageNamed:@"ChatInputContainer_Shadow_Mono.png"] stretchableImageWithLeftCapWidth:0 topCapHeight:0];
        });
        return image;
    }
    else
    {
        static UIImage *image = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^
        {
            image = [[UIImage imageNamed:@"ChatInputContainer_Shadow.png"] stretchableImageWithLeftCapWidth:0 topCapHeight:0];
        });
        return image;
    }
}

- (UIImage *)inputFieldBackground
{
    static UIImage *image = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        image = [[UIImage imageNamed:@"ConversationInputPanel.png"] stretchableImageWithLeftCapWidth:55 topCapHeight:21];
    });
    return image;
}

- (UIImage *)inputContainerRawBackground
{
    static UIImage *image = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        image = [UIImage imageNamed:@"ConversationInputPanel_Background.png"];
    });
    return image;
}

- (UIImage *)attachButtonImage
{
    static UIImage *image = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        image = [UIImage imageNamed:@"AttachBtn.png"];
    });
    return image;
}

- (UIImage *)attachButtonImageHighlighted
{
    static UIImage *image = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        image = [UIImage imageNamed:@"AttachBtn_Pressed.png"];
    });
    return image;
}

- (UIImage *)attachButtonArrowImageUp
{
    static UIImage *image = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        image = [UIImage imageNamed:@"AttachArrowUp.png"];
    });
    return image;
}

- (UIImage *)attachButtonArrowImageDown
{
    static UIImage *image = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        image = [UIImage imageNamed:@"AttachArrowDown.png"];
    });
    return image;
}

- (UIImage *)sendButtonImage
{
    static UIImage *image = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        UIImage *rawImage = [UIImage imageNamed:@"SendButton.png"];
        image = [rawImage stretchableImageWithLeftCapWidth:(int)(rawImage.size.width / 2) topCapHeight:0];
    });
    return image;
}

- (UIImage *)sendButtonImageHighlighted
{
    static UIImage *image = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        UIImage *rawImage = [UIImage imageNamed:@"SendButton_Pressed.png"];
        image = [rawImage stretchableImageWithLeftCapWidth:(int)(rawImage.size.width / 2) topCapHeight:0];
    });
    return image;
}

- (CGSize)titleAvatarSize:(UIDeviceOrientation)orientation
{
    if (UIDeviceOrientationIsPortrait(orientation))
        return CGSizeMake(35, 35);
    else
        return CGSizeMake(25, 25);
}

- (UIImage *)titleAvatarPlaceholder
{
    if (self.isEncrypted)
        return [[TGInterfaceAssets instance] smallAvatarPlaceholder:self.encryptedUserId];
    else if (self.isMultichat)
        return [[TGInterfaceAssets instance] smallGroupAvatarPlaceholder:_conversationId];
    else
        return [[TGInterfaceAssets instance] smallAvatarPlaceholder:(int)_conversationId];
    
    return nil;
}

- (UIImage *)titleAvatarPlaceholderGeneric
{
    static UIImage *image = nil;
    if (image == nil)
        image = [UIImage imageNamed:@"TitleAvatarPlaceholderGeneric.png"];
    return image;
}

- (UIImage *)titleAvatarOverlay:(UIInterfaceOrientation)orientation
{
    return UIInterfaceOrientationIsLandscape(orientation) ? [TGInterfaceAssets conversationTitleAvatarOverlayLandscape] : [TGInterfaceAssets conversationTitleAvatarOverlay];
}

- (UIImage *)unreadCountBadgeImage
{
    static UIImage *image = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        image = [[UIImage imageNamed:@"ConversationUnreadBadge.png"] stretchableImageWithLeftCapWidth:12 topCapHeight:0];
    });
    return image;
}

- (UIImage *)chatArrowDownImage
{
    static UIImage *image = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        image = [UIImage imageNamed:@"ChatArrowDown.png"];
    });
    return image;
}

- (UIImage *)chatArrowUpImage
{
    static UIImage *image = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        image = [UIImage imageNamed:@"ChatArrowUp.png"];
    });
    return image;
}

- (UIColor *)attachmentPanelBackground
{
    return [[TGInterfaceAssets instance] darkLinenBackground];
}

- (UIImage *)attachmentPanelShadow
{
    static UIImage *image = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        image = [UIImage imageNamed:@"LinenShadow.png"];
    });
    return image;
}

- (UIImage *)attachmentPanelDivider
{
    static UIImage *image = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        UIImage *rawImage = [UIImage imageNamed:@"ShadowDivider.png"];
        image = [rawImage stretchableImageWithLeftCapWidth:(int)(rawImage.size.width / 2) topCapHeight:0];
    });
    return image;
}

- (UIImage *)attachmentCameraImage
{
    static UIImage *image = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        image = [UIImage imageNamed:@"Camera.png"];
    });
    return image;
}

- (UIImage *)attachmentCameraImageHighlighted
{
    static UIImage *image = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        image = [UIImage imageNamed:@"Camera_Pressed.png"];
    });
    return image;
}

- (UIImage *)attachmentGalleryImage
{
    static UIImage *image = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        image = [UIImage imageNamed:@"Gallery.png"];
    });
    return image;
}

- (UIImage *)attachmentGalleryImageHighlighted
{
    static UIImage *image = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        image = [UIImage imageNamed:@"Gallery_Pressed.png"];
    });
    return image;
}

- (UIImage *)attachmentLocationImage
{
    static UIImage *image = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        image = [UIImage imageNamed:@"Location.png"];
    });
    return image;
}

- (UIImage *)attachmentLocationImageHighlighted
{
    static UIImage *image = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        image = [UIImage imageNamed:@"Location_Pressed.png"];
    });
    return image;
}

- (UIImage *)attachmentAudioImage
{
    static UIImage *image = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        image = [UIImage imageNamed:@"Audio.png"];
    });
    return image;
}

- (UIImage *)attachmentAudioImageHighlighted
{
    static UIImage *image = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        image = [UIImage imageNamed:@"Audio_Pressed.png"];
    });
    return image;
}

- (UIColor *)membersPanelBackground
{
    static UIColor *color = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        color = [[TGInterfaceAssets instance] darkLinenBackground];
    });
    return color;
}

- (UIImage *)membersPanelBackgroundImage
{
    static UIImage *image = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        image = [UIImage imageNamed:@"MembersPanelBackground.png"];
    });
    return image;
}

- (UIImage *)actionBarBackgroundImage
{
    static UIImage *image = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        image = [UIImage imageNamed:@"ConversationActionBar.png"];
    });
    return image;
}

- (UIImage *)editingDeleteButtonBackground
{
    static UIImage *image = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        UIImage *rawImage = [UIImage imageNamed:@"ActionDelete_Button.png"];
        image = [rawImage stretchableImageWithLeftCapWidth:(int)(rawImage.size.width / 2) topCapHeight:0];
    });
    return image;
}

- (UIImage *)editingDeleteButtonBackgroundHighlighted
{
    static UIImage *image = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        UIImage *rawImage = [UIImage imageNamed:@"ActionDelete_Button_Pressed.png"];
        image = [rawImage stretchableImageWithLeftCapWidth:(int)(rawImage.size.width / 2) topCapHeight:0];
    });
    return image;
}

- (UIImage *)editingDeleteButtonIcon
{
    static UIImage *image = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        image = [UIImage imageNamed:@"ActionDeleteIcon.png"];
    });
    return image;
}

- (UIImage *)editingForwardButtonBackground
{
    static UIImage *image = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        UIImage *rawImage = [UIImage imageNamed:@"ActionForward_Button.png"];
        image = [rawImage stretchableImageWithLeftCapWidth:(int)(rawImage.size.width / 2) topCapHeight:0];
    });
    return image;
}

- (UIImage *)editingForwardButtonBackgroundHighlighted
{
    static UIImage *image = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        UIImage *rawImage = [UIImage imageNamed:@"ActionForward_Button_Pressed.png"];
        image = [rawImage stretchableImageWithLeftCapWidth:(int)(rawImage.size.width / 2) topCapHeight:0];
    });
    return image;
}

- (UIImage *)editingForwardButtonIcon
{
    static UIImage *image = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        image = [UIImage imageNamed:@"ActionForwardIcon.png"];
    });
    return image;
}

- (UIImage *)inlineButton
{
    static UIImage *image = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        UIImage *rawImage = [UIImage imageNamed:@"ConversationInlineButton.png"];
        image = [rawImage stretchableImageWithLeftCapWidth:(int)(rawImage.size.width / 2) topCapHeight:0];
    });
    return image;
}

- (UIImage *)inlineButtonHighlighted
{
    static UIImage *image = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        UIImage *rawImage = [UIImage imageNamed:@"ConversationInlineButton_Highlighted.png"];
        image = [rawImage stretchableImageWithLeftCapWidth:(int)(rawImage.size.width / 2) topCapHeight:0];
    });
    return image;
}

- (UIImage *)headerActionArrowUp
{
    static UIImage *image = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        image = [UIImage imageNamed:@"HeaderActionArrowUp.png"];
    });
    return image;
}

- (UIImage *)headerActionArrowDown
{
    static UIImage *image = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        image = [UIImage imageNamed:@"HeaderActionArrowDown.png"];
    });
    return image;
}

- (id<TGAppManager>)applicationManager
{
    return TGAppDelegateInstance;
}

- (id<TGConversationMessageAssetsSource>)messageAssetsSource
{
    static TGTelegraphConversationMessageAssetsSource *singleton = nil;
    if (singleton == nil)
        singleton = [TGTelegraphConversationMessageAssetsSource instance];
    return singleton;
}

- (bool)shouldAutosavePhotos
{
    return _conversationId > INT_MIN && TGAppDelegateInstance.autosavePhotos;
}

- (int)ignoreSaveToGalleryUid
{
    return TGTelegraphInstance.clientUserId;
}

- (std::tr1::shared_ptr<std::map<int, float> >)messageUploadProgressCopy
{
    if (_messageUploadProgress.empty())
        return std::tr1::shared_ptr<std::map<int, float> >();
    
    std::tr1::shared_ptr<std::map<int, float> > pMap(new std::map<int, float>(_messageUploadProgress));
    return pMap;
}

- (void)setConversationController:(TGConversationController *)conversationController
{
    [super setConversationController:conversationController];
    
    [ActionStageInstance() dispatchOnStageQueue:^
    {   
        dispatch_async(dispatch_get_main_queue(), ^
        {
            [self.conversationController conversationTitleChanged:self.safeConversationTitle subtitle:self.safeConversationSubtitle typingSubtitle:self.conversationTypingSubtitle isContact:_isContact];
        });
    }];
}

- (int64_t)singleUserId
{
    return self.isEncrypted ? (int64_t)self.encryptedUserId : _conversationId;
}

@end
