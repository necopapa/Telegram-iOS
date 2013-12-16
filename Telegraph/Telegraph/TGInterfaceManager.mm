#import "TGInterfaceManager.h"

#import "TGAppDelegate.h"

#import "TGConversationController.h"
#import "TGConversationMessageItem.h"
#import "TGTimelineController.h"

#import "TGTelegraph.h"
#import "TGMessage.h"

#import "TGDatabase.h"

#import "TGTelegraphConversationCompanion.h"

#import "TGMessageNotificationView.h"

#import "TGPhotoGridController.h"

#import "TGPeopleNearbyController.h"

#import "TGDownloadManager.h"
#import "TGDownloadCenterView.h"

#import "TGNavigationBar.h"

#import "TGLinearProgressView.h"

@interface TGInterfaceManager ()

@property (nonatomic, strong) UIWindow *preloadWindow;

@property (nonatomic, strong) TGDownloadCenterView *downloadCenterView;

@end

@implementation TGInterfaceManager

@synthesize actionHandle = _actionHandle;

@synthesize preloadWindow = _preloadWindow;

@synthesize downloadCenterView = _downloadCenterView;

+ (TGInterfaceManager *)instance
{
    static TGInterfaceManager *singleton = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        singleton = [[TGInterfaceManager alloc] init];
    });
    return singleton;
}

- (id)init
{
    self = [super init];
    if (self != nil)
    {
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:false];
    }
    return self;
}

- (void)dealloc
{
    [_actionHandle reset];
    [ActionStageInstance() removeWatcher:self];
}

- (void)preload
{
}

- (void)navigateToConversationWithId:(int64_t)conversationId conversation:(TGConversation *)conversation
{
    [self navigateToConversationWithId:conversationId conversation:conversation forwardMessages:nil animated:true];
}

- (void)navigateToConversationWithId:(int64_t)conversationId conversation:(TGConversation *)conversation animated:(bool)animated
{
    [self navigateToConversationWithId:conversationId conversation:conversation forwardMessages:nil animated:animated];
}

- (void)navigateToConversationWithId:(int64_t)conversationId conversation:(TGConversation *)conversation forwardMessages:(NSArray *)forwardMessages
{
    [self navigateToConversationWithId:conversationId conversation:conversation forwardMessages:forwardMessages animated:true];
}

- (void)navigateToConversationWithId:(int64_t)conversationId conversation:(TGConversation *)conversation forwardMessages:(NSArray *)forwardMessages animated:(bool)animated
{
    [self navigateToConversationWithId:conversationId conversation:conversation forwardMessages:forwardMessages atMessageId:0 clearStack:true openKeyboard:false animated:animated];
}

- (void)navigateToConversationWithId:(int64_t)conversationId conversation:(TGConversation *)conversation forwardMessages:(NSArray *)forwardMessages atMessageId:(int)atMessageId clearStack:(bool)clearStack openKeyboard:(bool)openKeyboard animated:(bool)animated
{
    [self dismissBannerForConversationId:conversationId];
    
    TGConversationController *conversationController = nil;
    for (UIViewController *viewController in TGAppDelegateInstance.mainNavigationController.viewControllers)
    {
        if ([viewController isKindOfClass:[TGConversationController class]])
        {
            TGConversationController *existingConversationController = (TGConversationController *)viewController;
            TGTelegraphConversationCompanion *existingConversationCompanion = (TGTelegraphConversationCompanion *)existingConversationController.conversationCompanion;
            if (existingConversationCompanion.conversationId == conversationId)
            {
                conversationController = existingConversationController;
                break;
            }
        }
    }
    
    int unreadCount = [TGDatabaseInstance() cachedUnreadCount] - [TGDatabaseInstance() unreadCountForConversation:conversationId];
    
    if (conversationController == nil)
    {
        bool isEncrypted = conversationId <= INT_MIN;
        
        TGTelegraphConversationCompanion *conversationCompanion = [[TGTelegraphConversationCompanion alloc] initWithConversationId:conversationId atMessageId:atMessageId isMultichat:(conversationId < 0) isEncrypted:isEncrypted conversation:conversation unreadCount:unreadCount messagesToForward:forwardMessages];
        
        conversationController = [[TGConversationController alloc] initWithConversationControllerCompanion:conversationCompanion unreadCount:unreadCount];
        conversationCompanion.conversationController = conversationController;
        
        conversationController.shouldRemoveAllPreviousControllers = TGAppDelegateInstance.exclusiveConversationControllers && clearStack;
        conversationController.openKeyboardAutomatically = openKeyboard;
        
        [TGAppDelegateInstance.mainNavigationController pushViewController:conversationController animated:animated];
    }
    else
    {
        ((TGTelegraphConversationCompanion *)conversationController.conversationCompanion).messagesToForward = forwardMessages;
        
        if (TGAppDelegateInstance.mainNavigationController.topViewController != conversationController)
        {
            [TGAppDelegateInstance.mainNavigationController popToViewController:conversationController animated:animated];
        }
        else
        {
            [conversationController viewWillDisappear:false];
            [conversationController viewDidDisappear:false];
            [conversationController viewWillAppear:false];
            [conversationController viewDidAppear:false];
        }
    }
}

- (void)navigateToConversationWithBroadcastUids:(NSArray *)broadcastUids forwardMessages:(NSArray *)forwardMessages
{
    int unreadCount = [TGDatabaseInstance() cachedUnreadCount];
    
    TGTelegraphConversationCompanion *conversationCompanion = [[TGTelegraphConversationCompanion alloc] initWithBroadcastUids:broadcastUids unreadCount:unreadCount];
    ((TGTelegraphConversationCompanion *)conversationCompanion).messagesToForward = forwardMessages;
    
    TGConversationController *conversationController = [[TGConversationController alloc] initWithConversationControllerCompanion:conversationCompanion unreadCount:unreadCount];
    conversationCompanion.conversationController = conversationController;
    
    [TGAppDelegateInstance.mainNavigationController pushViewController:conversationController animated:true];
}

- (void)navigateToProfileOfUser:(int)uid
{
    [self navigateToProfileOfUser:uid preferNativeContactId:0];
}

- (void)navigateToProfileOfUser:(int)uid encryptedConversationId:(int64_t)encryptedConversationId
{
    [self navigateToProfileOfUser:uid preferNativeContactId:0 encryptedConversationId:encryptedConversationId];
}

- (void)navigateToProfileOfUser:(int)uid preferNativeContactId:(int)preferNativeContactId
{
    [self navigateToProfileOfUser:uid preferNativeContactId:preferNativeContactId encryptedConversationId:0];
}

- (void)navigateToProfileOfUser:(int)uid preferNativeContactId:(int)preferNativeContactId encryptedConversationId:(int64_t)encryptedConversationId
{
    TGProfileController *contactController = [[TGProfileController alloc] initWithUid:uid preferNativeContactId:preferNativeContactId encryptedConversationId:encryptedConversationId];
    [TGAppDelegateInstance.mainNavigationController pushViewController:contactController animated:true];
}

- (void)navigateToContact:(int)uid firstName:(NSString *)firstName lastName:(NSString *)lastName phoneNumber:(NSString *)__unused phoneNumber
{
    TGProfileController *contactController = nil;
    if (uid != 0)
    {
        contactController = [[TGProfileController alloc] initWithUid:uid preferNativeContactId:0 encryptedConversationId:0];
        if (![TGDatabaseInstance() uidIsRemoteContact:uid])
        {
            contactController.overrideFirstName = firstName;
            contactController.overrideLastName = lastName;
        }
    }
    if (contactController != nil)
        [TGAppDelegateInstance.mainNavigationController pushViewController:contactController animated:true];
}

- (void)navigateToTimelineOfUser:(int)__unused uid
{
    /*TGTimelineController *timelineController = [[TGTimelineController alloc] initWithUid:uid];
    [TGAppDelegateInstance.mainNavigationController pushViewController:timelineController animated:true];*/
}

- (void)navigateToMediaListOfConversation:(int64_t)conversationId
{
    if (conversationId == 0)
        return;
    
    TGPhotoGridController *photoController = [[TGPhotoGridController alloc] initWithConversationId:conversationId isEncrypted:conversationId <= INT_MIN];
    [TGAppDelegateInstance.mainNavigationController pushViewController:photoController animated:true];
}

- (void)displayBannerIfNeeded:(TGMessage *)message conversationId:(int64_t)conversationId
{
    if (!TGAppDelegateInstance.bannerEnabled)
        return;
    
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        TGUser *user = [TGDatabaseInstance() loadUser:(int)message.fromUid];
        TGConversation *conversation = nil;
        if (conversationId < 0)
            conversation = [TGDatabaseInstance() loadConversationWithId:conversationId];
        
        if (user != nil && (conversationId > 0 || conversation != nil))
        {
            dispatch_async(dispatch_get_main_queue(), ^
            {
                if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateActive)
                    return;
                
                bool hasModalController = false;
                
                if ([TGAppDelegateInstance.mainNavigationController respondsToSelector:@selector(presentedViewController)])
                    hasModalController = TGAppDelegateInstance.mainNavigationController.presentedViewController != nil;
                else
                    hasModalController = TGAppDelegateInstance.mainNavigationController.modalViewController != nil;
                
                if (!hasModalController)
                {
                    if ([TGAppDelegateInstance.mainNavigationController.topViewController respondsToSelector:@selector(presentedViewController)])
                        hasModalController = TGAppDelegateInstance.mainNavigationController.topViewController.presentedViewController != nil;
                    else
                        hasModalController = TGAppDelegateInstance.mainNavigationController.topViewController.modalViewController != nil;
                }
                
                if (hasModalController)
                    return;
                
                TGConversationController *conversationController = nil;
                for (UIViewController *viewController in TGAppDelegateInstance.mainNavigationController.viewControllers)
                {
                    if ([viewController isKindOfClass:[TGConversationController class]])
                    {
                        TGConversationController *existingConversationController = (TGConversationController *)viewController;
                        TGTelegraphConversationCompanion *existingConversationCompanion = (TGTelegraphConversationCompanion *)existingConversationController.conversationCompanion;
                        if (existingConversationCompanion.conversationId == conversationId)
                        {
                            conversationController = existingConversationController;
                            break;
                        }
                    }
                }
                if (conversationController == nil || conversationController != TGAppDelegateInstance.mainNavigationController.topViewController)
                {
                    int timeout = 5;
#ifdef DEBUG
                    //timeout = 50;
#endif
                    
                    NSMutableDictionary *users = nil;
                    
                    if (message.mediaAttachments.count != 0)
                    {
                        users = [[NSMutableDictionary alloc] initWithCapacity:1];
                        
                        if (user != nil)
                            [users setObject:user forKey:@"author"];
                        
                        for (TGMediaAttachment *attachment in message.mediaAttachments)
                        {
                            if (attachment.type == TGActionMediaAttachmentType)
                            {
                                TGActionMediaAttachment *actionAttachment = (TGActionMediaAttachment *)attachment;
                                switch (actionAttachment.actionType)
                                {
                                    case TGMessageActionChatAddMember:
                                    case TGMessageActionChatDeleteMember:
                                    {
                                        NSNumber *nUid = [actionAttachment.actionData objectForKey:@"uid"];
                                        if (nUid != nil)
                                        {
                                            TGUser *subjectUser = [TGDatabaseInstance() loadUser:[nUid intValue]];
                                            if (subjectUser != nil)
                                                [users setObject:subjectUser forKey:[[NSNumber alloc] initWithInt:subjectUser.uid]];
                                        }
                                        
                                        break;
                                    }
                                    default:
                                        break;
                                }
                            }
                        }
                    }
                    
                    [TGAppDelegateInstance displayNotification:@"message" timeout:timeout constructor:^UIView *(UIView *existingView)
                    {
                        TGMessageNotificationView *messageView = (TGMessageNotificationView *)existingView;
                        if (messageView == nil)
                            messageView = [[TGMessageNotificationView alloc] initWithFrame:CGRectMake(0, 0, 320, 45)];
                        
                        messageView.messageText = message.text;
                        messageView.authorUid = (int)message.fromUid;
                        messageView.conversationId = message.cid;
                        messageView.users = users;
                        messageView.messageAttachments = message.mediaAttachments;
                        messageView.avatarUrl = user.photoUrlSmall;
                        messageView.titleText = conversationId < 0 && conversationId > INT_MIN ? [[NSString alloc] initWithFormat:@"%@@%@", user.displayName, conversation.chatTitle] : user.displayName;
                        messageView.isLocationNotification = false;
                        [messageView resetView];
                        
                        return messageView;
                    } watcher:_actionHandle watcherAction:@"navigateToConversation" watcherOptions:[[NSDictionary alloc] initWithObjectsAndKeys:[NSNumber numberWithLongLong:conversationId], @"conversationId", nil]];
                }
            });
        }
    }];
}

- (void)dismissBannerForConversationId:(int64_t)conversationId
{
    UIView *currentNotificationView = [TGAppDelegateInstance currentNotificationView];
    if (currentNotificationView != nil && [currentNotificationView isKindOfClass:[TGMessageNotificationView class]])
    {
        if (((TGMessageNotificationView *)currentNotificationView).conversationId == conversationId)
            [TGAppDelegateInstance dismissNotification];
    }
}

- (void)displayNearbyBannerIdNeeded:(int)peopleCount
{
    if (!TGAppDelegateInstance.locationTranslationEnabled || peopleCount <= 0)
        return;
    
    dispatch_async(dispatch_get_main_queue(), ^
    {
        if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateActive)
            return;
        
        for (UIViewController *viewController in TGAppDelegateInstance.mainNavigationController.viewControllers)
        {
            if ([viewController isKindOfClass:[TGPeopleNearbyController class]])
            {
                return;
            }
        }
        
        [TGAppDelegateInstance displayNotification:@"message" timeout:5 constructor:^UIView *(UIView *existingView)
        {
            TGMessageNotificationView *messageView = (TGMessageNotificationView *)existingView;
            if (messageView == nil)
            {
                messageView = [[TGMessageNotificationView alloc] initWithFrame:CGRectMake(0, 0, 320, 45)];
            }
            
            messageView.authorUid = 0;
            messageView.messageText = nil;
            messageView.avatarUrl = nil;
            messageView.titleText = peopleCount == 1 ? @"1 person nearby" : [[NSString alloc] initWithFormat:@"%d people are nearby", peopleCount];
            messageView.isLocationNotification = true;
            [messageView resetView];
            
            return messageView;
        } watcher:_actionHandle watcherAction:@"navigateToPeopleNearby" watcherOptions:nil];
    });
}

- (void)actionStageActionRequested:(NSString *)action options:(NSDictionary *)options
{
    if ([action isEqualToString:@"navigateToConversation"])
    {
        if (TGAppDelegateInstance.contentWindow != nil)
            return;
        
        int64_t conversationId = [[options objectForKey:@"conversationId"] longLongValue];
        if (conversationId == 0)
            return;
        
        if (conversationId < 0)
        {
            if ([TGDatabaseInstance() loadConversationWithId:conversationId] == nil)
                return;
        }
        
        UIViewController *presentedViewController = nil;
        if ([UIViewController instancesRespondToSelector:@selector(presentedViewController)])
            presentedViewController = [TGAppDelegateInstance.mainNavigationController presentedViewController];
        else
            presentedViewController = [TGAppDelegateInstance.mainNavigationController modalViewController];
        
        if (presentedViewController != nil)
        {
            [TGAppDelegateInstance.mainNavigationController dismissViewControllerAnimated:true completion:nil];
        }
        
        [self navigateToConversationWithId:conversationId conversation:nil animated:presentedViewController == nil];
    }
    else if ([action isEqualToString:@"navigateToPeopleNearby"])
    {
        if (TGAppDelegateInstance.contentWindow != nil)
            return;
        
        for (UIViewController *viewController in TGAppDelegateInstance.mainNavigationController.viewControllers)
        {
            if ([viewController isKindOfClass:[TGPeopleNearbyController class]])
            {
                return;
            }
        }
        
        UIViewController *presentedViewController = nil;
        if ([UIViewController instancesRespondToSelector:@selector(presentedViewController)])
            presentedViewController = [TGAppDelegateInstance.mainNavigationController presentedViewController];
        else
            presentedViewController = [TGAppDelegateInstance.mainNavigationController modalViewController];
        
        if (presentedViewController != nil)
        {
            [TGAppDelegateInstance.mainNavigationController dismissViewControllerAnimated:true completion:nil];
        }
        
        TGPeopleNearbyController *peopleNearbyController = [[TGPeopleNearbyController alloc] init];
        [TGAppDelegateInstance.mainNavigationController pushViewController:peopleNearbyController animated:presentedViewController == nil];
    }
}

- (void)actionStageResourceDispatched:(NSString *)path resource:(id)resource arguments:(id)__unused arguments
{
    if ([path isEqualToString:@"downloadManagerStateChanged"])
    {
        NSDictionary *items = [[NSDictionary alloc] initWithDictionary:resource];
        
        dispatch_async(dispatch_get_main_queue(), ^
        {
            if (items.count != 0 || _downloadCenterView != nil)
            {
                [self downloadCenterView];
                
                bool wasHidden = _downloadCenterView.hidden;
                _downloadCenterView.hidden = items.count == 0;
                
                __block float progress = 0.0f;
                
                if (items.count != 0)
                {
                    [items enumerateKeysAndObjectsUsingBlock:^(__unused NSString *path, TGDownloadItem *item, __unused BOOL *stop)
                    {
                        progress += item.progress;
                    }];
                    
                    progress /= (float)(items.count);
                }
                
                [_downloadCenterView setItems:items.count];
                [_downloadCenterView setProgress:progress animated:!wasHidden];
            }
        });
    }
}

- (UIView *)downloadCenterView
{
    if (_downloadCenterView == nil)
    {
        _downloadCenterView = [[TGDownloadCenterView alloc] init];
        _downloadCenterView.frame = CGRectOffset(_downloadCenterView.frame, TGAppDelegateInstance.mainNavigationController.view.frame.size.width - _downloadCenterView.frame.size.width, TGAppDelegateInstance.mainNavigationController.navigationBar.frame.size.height);
        [(TGNavigationBar *)TGAppDelegateInstance.mainNavigationController.navigationBar addSubview:_downloadCenterView];
        [(TGNavigationBar *)TGAppDelegateInstance.mainNavigationController.navigationBar setProgressView:_downloadCenterView];
    }
    
    return _downloadCenterView;
}

@end
