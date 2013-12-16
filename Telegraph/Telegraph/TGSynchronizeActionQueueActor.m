#import "TGSynchronizeActionQueueActor.h"

#import "TGDatabase.h"

#import "TGTelegraph.h"

#import "TGUpdateStateRequestBuilder.h"

#import "TGSession.h"

@interface TGSynchronizeActionQueueActor ()

@property (nonatomic) bool bypassQueue;

@property (nonatomic, strong) NSArray *currentMids;

@property (nonatomic) int64_t currentReadConversationId;
@property (nonatomic) int currentReadMaxMid;

@property (nonatomic) int64_t currentDeleteConversationId;
@property (nonatomic) bool currentClearConversation;

@end

@implementation TGSynchronizeActionQueueActor

+ (NSString *)genericPath
{
    return @"/tg/service/synchronizeactionqueue/@";
}

- (void)prepare:(NSDictionary *)__unused options
{
    NSNumber *nBypassQueue = [options objectForKey:@"bypassQueue"];
    if (nBypassQueue == nil || ![nBypassQueue boolValue])
        self.requestQueueName = @"messages";
}

- (void)execute:(NSDictionary *)__unused options
{
    [TGDatabaseInstance() checkIfLatestMessageIdIsNotApplied:^(int midForSinchronization)
    {
        if (midForSinchronization > 0)
        {
            [ActionStageInstance() requestActor:[[NSString alloc] initWithFormat:@"/tg/messages/reportDelivery/(messages)"] options:[[NSDictionary alloc] initWithObjectsAndKeys:[[NSNumber alloc] initWithInt:midForSinchronization], @"mid", nil] watcher:TGTelegraphInstance];
        }
    }];
    
    [TGDatabaseInstance() checkIfLatestQtsIsNotApplied:^(int qtsForSinchronization)
    {
        if (qtsForSinchronization > 0)
        {
            [ActionStageInstance() requestActor:[[NSString alloc] initWithFormat:@"/tg/messages/reportDelivery/(qts)"] options:[[NSDictionary alloc] initWithObjectsAndKeys:[[NSNumber alloc] initWithInt:qtsForSinchronization], @"qts", nil] watcher:TGTelegraphInstance];
        }
    }];
    
    [TGDatabaseInstance() loadQueuedActions:[NSArray arrayWithObjects:[NSNumber numberWithInt:TGDatabaseActionReadConversation], [NSNumber numberWithInt:TGDatabaseActionDeleteMessage], [NSNumber numberWithInt:TGDatabaseActionClearConversation], [NSNumber numberWithInt:TGDatabaseActionDeleteConversation], nil] completion:^(NSDictionary *actionSetsByType)
    {
        [ActionStageInstance() dispatchOnStageQueue:^
        {
            NSArray *readConversationActions = [actionSetsByType objectForKey:[NSNumber numberWithInt:TGDatabaseActionReadConversation]];
            NSArray *deleteMessageActions = [actionSetsByType objectForKey:[NSNumber numberWithInt:TGDatabaseActionDeleteMessage]];
            NSArray *deleteConversationActions = [actionSetsByType objectForKey:[NSNumber numberWithInt:TGDatabaseActionDeleteConversation]];
            NSArray *clearConversationActions = [actionSetsByType objectForKey:[NSNumber numberWithInt:TGDatabaseActionClearConversation]];
            
            if (readConversationActions.count != 0)
            {
                TGDatabaseAction action;
                [(NSValue *)[readConversationActions objectAtIndex:0] getValue:&action];
                _currentReadConversationId = action.subject;
                _currentReadMaxMid = action.arg0;
                
                if (_currentReadConversationId <= INT_MIN)
                {
                    int64_t encryptedConversationId = [TGDatabaseInstance() encryptedConversationIdForPeerId:_currentReadConversationId];
                    int64_t accessHash = [TGDatabaseInstance() encryptedConversationAccessHash:_currentReadConversationId];
                    
                    if (encryptedConversationId != 0 && accessHash != 0)
                        self.cancelToken = [TGTelegraphInstance doReadEncrytedHistory:encryptedConversationId accessHash:accessHash maxDate:_currentReadMaxMid actor:self];
                    else
                        [self readMessagesSuccess:nil];
                }
                else
                    self.cancelToken = [TGTelegraphInstance doConversationReadHistory:action.subject maxMid:action.arg0 offset:0 actor:self];
            }
            else if (deleteMessageActions.count != 0)
            {
                NSMutableArray *messageIds = [[NSMutableArray alloc] initWithCapacity:deleteMessageActions.count];
                for (NSValue *value in deleteMessageActions)
                {
                    TGDatabaseAction action;
                    [value getValue:&action];
                    
                    [messageIds addObject:[[NSNumber alloc] initWithInt:(int)action.subject]];
                }
                
                _currentMids = messageIds;
                
                self.cancelToken = [TGTelegraphInstance doDeleteMessages:messageIds actor:self];
            }
            else if (deleteConversationActions.count != 0)
            {
                for (NSValue *value in deleteConversationActions)
                {
                    TGDatabaseAction action;
                    [value getValue:&action];
                }
                
                TGDatabaseAction action;
                [(NSValue *)[deleteConversationActions objectAtIndex:0] getValue:&action];
                _currentDeleteConversationId = action.subject;
                
                _currentClearConversation = false;
                
                if (_currentDeleteConversationId < 0)
                {
                    if (action.subject < 0)
                        [TGUpdateStateRequestBuilder addIgnoreConversationId:_currentDeleteConversationId];
                    
                    if (_currentDeleteConversationId <= INT_MIN)
                    {
                        int64_t encryptedConversationId = [TGDatabaseInstance() encryptedConversationIdForPeerId:_currentDeleteConversationId];
                        
                        [ActionStageInstance() dispatchResource:@"/tg/service/cancelAcceptEncryptedChat" resource:@(encryptedConversationId)];
                        
                        if (encryptedConversationId != 0)
                            self.cancelToken = [TGTelegraphInstance doRejectEncryptedChat:encryptedConversationId actor:self];
                        else
                            [self rejectEncryptedChatSuccess];
                    }
                    else
                        self.cancelToken = [TGTelegraphInstance doDeleteConversationMember:_currentDeleteConversationId uid:TGTelegraphInstance.clientUserId actor:self];
                }
                else
                {
                    if (_currentDeleteConversationId <= INT_MIN)
                        [self deleteHistorySuccess:nil];
                    else
                        self.cancelToken = [TGTelegraphInstance doDeleteConversation:_currentDeleteConversationId offset:0 actor:self];
                }
            }
            else if (clearConversationActions.count != 0)
            {
                TGDatabaseAction action;
                [(NSValue *)[clearConversationActions objectAtIndex:0] getValue:&action];
                _currentDeleteConversationId = action.subject;
                
                _currentClearConversation = true;
                
                if (_currentDeleteConversationId <= INT_MIN)
                    [self deleteHistorySuccess:nil];
                else
                    self.cancelToken = [TGTelegraphInstance doDeleteConversation:_currentDeleteConversationId offset:0 actor:self];
            }
            else
            {
                [ActionStageInstance() actionCompleted:self.path result:nil];
            }
        }];
    }];
}

- (void)readMessagesSuccess:(TLmessages_AffectedHistory *)affectedHistory
{
    if (affectedHistory != nil)
        [[TGSession instance] updatePts:affectedHistory.pts date:0 seq:affectedHistory.seq];
    
    if (affectedHistory.offset > 0)
    {
        self.cancelToken = [TGTelegraphInstance doConversationReadHistory:_currentReadConversationId maxMid:_currentReadMaxMid offset:affectedHistory.offset actor:self];
    }
    else
    {
        TGDatabaseAction action = { .type = TGDatabaseActionReadConversation, .subject = _currentReadConversationId, .arg0 = _currentReadMaxMid, .arg1 = 0 };
        [TGDatabaseInstance() confirmQueuedActions:[NSArray arrayWithObject:[[NSValue alloc] initWithBytes:&action objCType:@encode(TGDatabaseAction)]] requireFullMatch:false];
        
        [self execute:nil];
    }
}

- (void)readMessagesFailed
{
    [self execute:nil];
}

- (void)deleteMessagesSuccess:(NSArray *)__unused deletedMids
{
    NSMutableArray *actions = [[NSMutableArray alloc] initWithCapacity:_currentMids.count];
    for (NSNumber *nMid in _currentMids)
    {
        TGDatabaseAction action = { .type = TGDatabaseActionDeleteMessage, .subject = [nMid intValue], .arg0 = 0, .arg1 = 0 };
        [actions addObject:[[NSValue alloc] initWithBytes:&action objCType:@encode(TGDatabaseAction)]];
    }
    [TGDatabaseInstance() confirmQueuedActions:actions requireFullMatch:false];
    
    [self execute:nil];
}

- (void)deleteMessagesFailed
{
    [self deleteHistorySuccess:nil];
}

- (void)deleteHistorySuccess:(TLmessages_AffectedHistory *)affectedHistory
{
    if (affectedHistory != nil)
        [[TGSession instance] updatePts:affectedHistory.pts date:0 seq:affectedHistory.seq];
    
    if (affectedHistory.offset > 0)
    {
        self.cancelToken = [TGTelegraphInstance doDeleteConversation:_currentDeleteConversationId offset:affectedHistory.offset actor:self];
    }
    else
    {
        TGDatabaseAction action = { .type = _currentClearConversation ? TGDatabaseActionClearConversation : TGDatabaseActionDeleteConversation, .subject = _currentDeleteConversationId, .arg0 = 0, .arg1 = 0 };
        [TGDatabaseInstance() confirmQueuedActions:[NSArray arrayWithObject:[[NSValue alloc] initWithBytes:&action objCType:@encode(TGDatabaseAction)]] requireFullMatch:false];
        
        [self execute:nil];
    }
}

- (void)deleteHistoryFailed
{
    [self deleteHistorySuccess:nil];
}

- (void)deleteMemberSuccess:(TLmessages_StatedMessage *)statedMessage
{
    [[TGSession instance] updatePts:statedMessage.pts date:0 seq:statedMessage.seq];
    
    [TGUpdateStateRequestBuilder removeIgnoreConversationId:_currentDeleteConversationId];
    
    self.cancelToken = [TGTelegraphInstance doDeleteConversation:_currentDeleteConversationId offset:0 actor:self];
}

- (void)deleteMemberFailed
{
    [TGUpdateStateRequestBuilder removeIgnoreConversationId:_currentDeleteConversationId];
    
    self.cancelToken = [TGTelegraphInstance doDeleteConversation:_currentDeleteConversationId offset:0 actor:self];
}

- (void)rejectEncryptedChatSuccess
{
    [TGUpdateStateRequestBuilder removeIgnoreConversationId:_currentDeleteConversationId];
    
    [self deleteHistorySuccess:nil];
}

- (void)rejectEncryptedChatFailed
{
    [TGUpdateStateRequestBuilder removeIgnoreConversationId:_currentDeleteConversationId];
    
    [self deleteHistorySuccess:nil];
}

- (void)readEncryptedSuccess
{
    [self readMessagesSuccess:nil];
}

- (void)readEncryptedFailed
{
    [self readMessagesSuccess:nil];
}

@end
