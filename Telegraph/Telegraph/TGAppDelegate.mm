#import "TGAppDelegate.h"

#import "TGTelegraph.h"
#import "TGSession.h"
#import "TGDatabase.h"
#import "TGMessage+Telegraph.h"

#import "TGInterfaceManager.h"
#import "TGInterfaceAssets.h"

#import "TGSchema.h"

#import "TGCache.h"
#import "TGRemoteImageView.h"
#import "TGImageUtils.h"

#import "TGApplicationWindow.h"

#import "TGViewController.h"

#import "TGTelegraphDialogListCompanion.h"

#import "TGNavigationBar.h"

#import "SGraphListNode.h"
#import "TGImageDownloadActor.h"

#import "TGHacks.h"

#import "TGTelegraphConversationMessageAssetsSource.h"
#import "TGReusableLabel.h"

#import "TGJpegTurbo.h"

#import "TGNotificationWindow.h"
#import "TGMessageNotificationView.h"

#import <QuartzCore/QuartzCore.h>
#import <AudioToolbox/AudioToolbox.h>
#import <ImageIO/ImageIO.h>

#import "TGLoginWelcomeController.h"
#import "TGLoginPhoneController.h"
#import "TGLoginCodeController.h"
#import "TGLoginProfileController.h"
#import "TGLoginInactiveUserController.h"

#import "TGConversationController.h"

#import "TGApplication.h"

#import "TGCameraWindow.h"

#import "TGContentViewController.h"

#import <pthread.h>

#import <AVFoundation/AVAudioPlayer.h>

#define TG_SYNCHRONIZED_DEFINE(lock) pthread_mutex_t TG_SYNCHRONIZED_##lock
#define TG_SYNCHRONIZED_INIT(lock) pthread_mutex_init(&TG_SYNCHRONIZED_##lock, NULL)
#define TG_SYNCHRONIZED_BEGIN(lock) pthread_mutex_lock(&TG_SYNCHRONIZED_##lock);
#define TG_SYNCHRONIZED_END(lock) pthread_mutex_unlock(&TG_SYNCHRONIZED_##lock);

CFAbsoluteTime applicationStartupTimestamp = 0;
CFAbsoluteTime mainLaunchTimestamp = 0;

NSArray *preloadedDialogList = nil;
NSArray *preloadedDialogListUids = nil;

dispatch_semaphore_t preloadedDialogListSemaphore = NULL;

static void printStartupCheckpoint(int index)
{
    CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();
    TGLog(@"<<< Checkpoint %d-%d: %d ms >>>", index - 1, index, (int)((currentTime - mainLaunchTimestamp) * 1000));
    mainLaunchTimestamp = currentTime;
}

TGAppDelegate *TGAppDelegateInstance = nil;
TGTelegraph *telegraph = nil;

@interface TGAppDelegate () <AVAudioPlayerDelegate>

@property (nonatomic) bool tokenAlreadyRequested;
@property (nonatomic, strong) id<TGDeviceTokenListener> deviceTokenListener;

@property (nonatomic) UIBackgroundTaskIdentifier backgroundTaskIdentifier;
@property (nonatomic, strong) NSTimer *backgroundTaskExpirationTimer;

@property (nonatomic, strong) NSMutableDictionary *loadedSoundSamples;

@property (nonatomic, strong) TGNotificationWindow *notificationWindow;
@property (nonatomic, strong) NSTimer *notificationWindowTimeoutTimer;

@property (nonatomic, strong) UIWebView *callingWebView;

@property (nonatomic, strong) AVAudioPlayer *currentAudioPlayer;

@end

@implementation TGAppDelegate

- (TGNavigationController *)loginNavigationController
{
    if (_loginNavigationController == nil)
    {
        TGLoginWelcomeController *welcomeController = [[TGLoginWelcomeController alloc] init];
        _loginNavigationController = [TGNavigationController navigationControllerWithRootController:welcomeController blackCorners:true];
        _loginNavigationController.restrictLandscape = true;
        TGNavigationBar *navigationBar = (TGNavigationBar *)_loginNavigationController.navigationBar;
        
        NSString *resourcePath = [[NSBundle mainBundle] resourcePath];
        
        navigationBar.defaultPortraitImage = [UIImage imageWithContentsOfFile:[resourcePath stringByAppendingPathComponent:[NSString stringWithFormat:@"LoginHeader%s.png", TGIsRetina() ? "@2x" : ""]]];
        navigationBar.defaultLandscapeImage = [TGViewController isWidescreen] ? [UIImage imageWithContentsOfFile:[resourcePath stringByAppendingPathComponent:[NSString stringWithFormat:@"LoginHeaderLandscape_Wide%s.png", TGIsRetina() ? "@2x" : ""]]] : [UIImage imageWithContentsOfFile:[resourcePath stringByAppendingPathComponent:[NSString stringWithFormat:@"LoginHeaderLandscape%s.png", TGIsRetina() ? "@2x" : ""]]];
        [navigationBar setShadowMode:true];
        [navigationBar updateBackground];
        
        _loginNavigationController.modalTransitionStyle = UIModalTransitionStyleFlipHorizontal;
        
        UIView *backgroundView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 480)];
        backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        
        UIColor *patternColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"DarkLinen.png"]];
        
        UIView *backgroundPatternView = [[UIView alloc] initWithFrame:backgroundView.bounds];
        backgroundPatternView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        backgroundPatternView.tag = ((int)0xF7E5C50E);
        backgroundPatternView.backgroundColor = patternColor;
        [backgroundView addSubview:backgroundPatternView];
        
        UIView *backgroundPatternTransitionView = [[UIView alloc] initWithFrame:backgroundView.bounds];
        backgroundPatternTransitionView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        backgroundPatternTransitionView.tag = ((int)0x7A461D42);
        backgroundPatternTransitionView.backgroundColor = patternColor;
        backgroundPatternTransitionView.hidden = true;
        [backgroundView addSubview:backgroundPatternTransitionView];
        
        UIImageView *shadowView = [[UIImageView alloc] initWithFrame:backgroundView.bounds];
        shadowView.tag = (int)0xB72CE77E;
        shadowView.image = [UIImage imageNamed:@"LoginShadow.png"];
        shadowView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [backgroundView addSubview:shadowView];
        
        _loginNavigationController.backgroundView = backgroundView;
    }
    
    return _loginNavigationController;
}

+ (void)beginEarlyInitialization
{
    preloadedDialogListSemaphore = dispatch_semaphore_create(0);
    
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        [TGMessage registerMediaAttachmentParser:TGActionMediaAttachmentType parser:[[TGActionMediaAttachment alloc] init]];
        [TGMessage registerMediaAttachmentParser:TGImageMediaAttachmentType parser:[[TGImageMediaAttachment alloc] init]];
        [TGMessage registerMediaAttachmentParser:TGLocationMediaAttachmentType parser:[[TGLocationMediaAttachment alloc] init]];
        [TGMessage registerMediaAttachmentParser:TGLocalMessageMetaMediaAttachmentType parser:[[TGLocalMessageMetaMediaAttachment alloc] init]];
        [TGMessage registerMediaAttachmentParser:TGVideoMediaAttachmentType parser:[[TGVideoMediaAttachment alloc] init]];
        [TGMessage registerMediaAttachmentParser:TGContactMediaAttachmentType parser:[[TGContactMediaAttachment alloc] init]];
        [TGMessage registerMediaAttachmentParser:TGForwardedMessageMediaAttachmentType parser:[[TGForwardedMessageMediaAttachment alloc] init]];
        [TGMessage registerMediaAttachmentParser:TGUnsupportedMediaAttachmentType parser:[[TGUnsupportedMediaAttachment alloc] init]];
        
        TGLog(@"###### Early initialization ######");
        
        [TGDatabase setDatabaseName:@"tgdata"];
        [TGDatabase setLiveMessagesDispatchPath:@"/tg/conversations"];
        [TGDatabase setLiveUnreadCountDispatchPath:@"/tg/unreadCount"];
        
/*#if TARGET_IPHONE_SIMULATOR
        [TGDatabaseInstance() loadMessagesFromConversation:-90443398 maxMid:INT_MAX maxDate:INT_MAX maxLocalMid:INT_MAX atMessageId:0 limit:10000 extraUnread:false completion:^(NSArray *messages, __unused bool historyExistsBelow) {
            for (TGMessage *message in messages)
            {
                if (message.mid >= 37830)
                {
                    std::vector<TGDatabaseMessageFlagValue> flags;
                    TGDatabaseMessageFlagValue unreadFlag = {TGDatabaseMessageFlagUnread, true};
                    flags.push_back(unreadFlag);
                    
                    [TGDatabaseInstance() updateMessage:message.mid flags:flags dispatch:false];
                }
            }
        }];
#endif*/
        
        [[TGDatabase instance] markAllPendingMessagesAsFailed];
        [[TGDatabase instance] loadConversationListInitial:^(NSArray *dialogList, NSArray *userIds)
        {
            TGLog(@"###### Dialog list loaded ######");
            
            preloadedDialogList = dialogList;
            preloadedDialogListUids = userIds;
            
            dispatch_semaphore_signal(preloadedDialogListSemaphore);
        }];
    }];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)__unused launchOptions
{
    printStartupCheckpoint(-1);
    TGAppDelegateInstance = self;
    
    _window = [[TGApplicationWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    [(TGApplication *)application forceSetStatusBarStyle:UIStatusBarStyleBlackTranslucent animated:false];
    
    if (false)
    {
        dispatch_semaphore_wait(preloadedDialogListSemaphore, DISPATCH_TIME_FOREVER);
        
        std::vector<int> uids;
        for (NSNumber *nUid in preloadedDialogListUids)
        {
            uids.push_back([nUid intValue]);
        }
        [TGDatabaseInstance() loadUsers:uids];
        
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(320, 480), true, 2.0f);
        CGContextRef context = UIGraphicsGetCurrentContext();
        
        CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
        CGContextFillRect(context, CGRectMake(0, 0, 320, 480));
        
        CGContextSetFillColorWithColor(context, [UIColor blackColor].CGColor);
        
        UIFont *font = [UIFont systemFontOfSize:14];
        
        int offset = 0;
        for (TGConversation *conversation in preloadedDialogList)
        {
            if (conversation.isChat)
            {
                [conversation.chatTitle drawInRect:CGRectMake(0, offset, 320, 40) withFont:font];
            }
            else
            {
                TGUser *user = [TGDatabaseInstance() loadUser:(int)conversation.conversationId];
                [user.displayName drawInRect:CGRectMake(0, offset, 320, 40) withFont:font];
            }
            
            offset += 50;
            
            if (offset >= 480 - 20 - 44 - 39)
                break;
        }
        
        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    
        UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
        
        [self.window addSubview:imageView];
        [self.window makeKeyAndVisible];
        
        return true;
    }
    
    _loadedSoundSamples = [[NSMutableDictionary alloc] init];
    
    _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:false];
    
    [ASActor registerRequestBuilder:[TGImageDownloadActor class]];
    
    [TGInterfaceManager instance];
    
    telegraph = [[TGTelegraph alloc] init];
    
    printStartupCheckpoint(0);
    
    [TGHacks hackSetAnimationDuration];
    [TGHacks hackDrawPlaceholderInRect];
    
    printStartupCheckpoint(1);
    
    //[[TGDatabase instance] dropDatabase];
    
    printStartupCheckpoint(3);
    
    printStartupCheckpoint(4);
    
    TGTelegraphDialogListCompanion *dialogListCompanion = [[TGTelegraphDialogListCompanion alloc] init];
    _dialogListController = [[TGDialogListController alloc] initWithCompanion:dialogListCompanion];
    
    _contactsController = [[TGContactsController alloc] initWithContactsMode:TGContactsModeMainContacts | TGContactsModeRegistered | TGContactsModePhonebook | TGContactsModeHideSelf];
    
    //_addContactsController.tabBarItem.title = TGLocalized(@"AddContacts.TabTitle");
    //_addContactsController.tabBarItem.image = [UIImage imageNamed:@"Tabbar_Add.png"];
    
    _myAccountController = [[TGProfileController alloc] initWithUid:0 preferNativeContactId:0 encryptedConversationId:0];
    
    printStartupCheckpoint(5);
    
    _mainTabsController = [[TGMainTabsController alloc] init];
    [_mainTabsController setViewControllers:[NSArray arrayWithObjects:_contactsController, _dialogListController, _myAccountController, nil]];
    [_mainTabsController setSelectedIndex:1];
    
    printStartupCheckpoint(6);
    
    _mainNavigationController = [TGNavigationController navigationControllerWithRootController:_mainTabsController];
    
    printStartupCheckpoint(7);
    
    self.window.rootViewController = _mainNavigationController;
    
    self.window.backgroundColor = [UIColor blackColor];
    
    [self.window makeKeyAndVisible];
    
    TGCache *sharedCache = [[TGCache alloc] init];
    //sharedCache.imageMemoryLimit = 0;
    //sharedCache.imageMemoryEvictionInterval = 0;
    [TGRemoteImageView setSharedCache:sharedCache];
    
    printStartupCheckpoint(8);
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardDidShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardDidHide:) name:UIKeyboardWillHideNotification object:nil];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^
    //dispatch_async(dispatch_get_main_queue(), ^
    {
        [self loadSettings];
        
        dispatch_semaphore_wait(preloadedDialogListSemaphore, DISPATCH_TIME_FOREVER);
        
        SGraphListNode *node = [[SGraphListNode alloc] init];
        node.items = preloadedDialogList;
        
        std::vector<int> uids;
        for (NSNumber *nUid in preloadedDialogListUids)
        {
            uids.push_back([nUid intValue]);
        }
        [TGDatabaseInstance() loadUsers:uids];
        [(id<ASWatcher>)_dialogListController.dialogListCompanion actorCompleted:ASStatusSuccess path:@"/tg/dialoglist/(0)" result:node];
        TGLog(@"===== Dispatched dialog list");
        
        [ActionStageInstance() dispatchOnStageQueue:^
        {
            printStartupCheckpoint(9);
            
            [[TGSession instance] loadSession];
            
            if (TGTelegraphInstance.clientUserId != 0)
            {
                printStartupCheckpoint(11);
                
                [TGTelegraphInstance processAuthorizedWithUserId:TGTelegraphInstance.clientUserId clientIsActivated:TGTelegraphInstance.clientIsActivated];
                if (!TGTelegraphInstance.clientIsActivated)
                {
                    TGLog(@"===== User is not activated, presenting welcome screen");
                    [self presentLoginController:false showWelcomeScreen:true phoneNumber:nil phoneCode:nil phoneCodeHash:nil profileFirstName:nil profileLastName:nil];
                }
                
                printStartupCheckpoint(12);
                
            }
            else
            {
                NSDictionary *blockStateDict = [self loadLoginState];
                
                dispatch_async(dispatch_get_main_queue(), ^
                {
                    NSDictionary *stateDict = blockStateDict;
                    
                    int currentDate = ((int)CFAbsoluteTimeGetCurrent());
                    int stateDate = [stateDict[@"date"] intValue];
                    if (currentDate - stateDate > 60 * 60 * 23)
                    {
                        stateDict = nil;
                        [self resetLoginState];
                    }
                    
                    [self presentLoginController:false showWelcomeScreen:false phoneNumber:stateDict[@"phoneNumber"] phoneCode:stateDict[@"phoneCode"] phoneCodeHash:stateDict[@"phoneCodeHash"] profileFirstName:stateDict[@"firstName"] profileLastName:stateDict[@"lastName"]];
                });
                
                [[TGDatabase instance] dropDatabase];
            }
            
            [[TGSession instance] takeOff];
        }];
    });
    
    return true;
}

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)__unused application
{
    TGLog(@"******* Memory warning ******");
}

- (void)keyboardDidShow:(NSNotification *)__unused notification
{
    _keyboardVisible = true;
    
    CGRect keyboardFrame = [[[notification userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    _keyboardHeight = MIN(keyboardFrame.size.width, keyboardFrame.size.height);
}

- (void)keyboardDidHide:(NSNotification *)__unused notification
{
    _keyboardVisible = false;
    
    _keyboardHeight = 0;
}

- (void)applicationWillResignActive:(UIApplication *)__unused application
{
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        int unreadCount = [TGDatabaseInstance() databaseState].unreadCount;
        dispatch_async(dispatch_get_main_queue(), ^
        {
            [[UIApplication sharedApplication] setApplicationIconBadgeNumber:unreadCount];
        });
    }];
}

- (void)applicationSignificantTimeChange:(UIApplication *)__unused application
{
    TGLog(@"***** Significant time change");
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        [ActionStageInstance() dispatchResource:@"/system/significantTimeChange" resource:nil];
    }];
    
    [TGDatabaseInstance() processAndScheduleSelfDestruct];
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
#if defined(DEBUG) || defined(INTERNAL_RELEASE)
    TGLogSynchronize();
#endif
    
    if (_backgroundTaskExpirationTimer != nil && [_backgroundTaskExpirationTimer isValid])
    {
        [_backgroundTaskExpirationTimer invalidate];
        _backgroundTaskExpirationTimer = nil;
    }
    
    _backgroundTaskIdentifier = [application beginBackgroundTaskWithExpirationHandler:^
    {
        if (_backgroundTaskExpirationTimer != nil)
        {
            if ([_backgroundTaskExpirationTimer isValid])
                [_backgroundTaskExpirationTimer invalidate];
            _backgroundTaskExpirationTimer = nil;
        }
        
        UIBackgroundTaskIdentifier identifier = _backgroundTaskIdentifier;
        _backgroundTaskIdentifier = UIBackgroundTaskInvalid;
        [application endBackgroundTask:identifier];
    }];
    
    _enteredBackgroundTime = CFAbsoluteTimeGetCurrent();
    
    NSTimeInterval maxBackgroundTime = [application backgroundTimeRemaining] - 0.5 * 60.0;
    if (_disableBackgroundMode)
        maxBackgroundTime = 1;
    
    TGLog(@"Background time remaining: %d m %d s", (int)(maxBackgroundTime / 60.0), (int)(maxBackgroundTime - (int)((maxBackgroundTime / 60.0) * 60.0f)));
    
    _backgroundTaskExpirationTimer = [NSTimer timerWithTimeInterval:MAX(maxBackgroundTime, 1.0) target:self selector:@selector(backgroundExpirationTimerEvent:) userInfo:nil repeats:false];
    [[NSRunLoop mainRunLoop] addTimer:_backgroundTaskExpirationTimer forMode:NSRunLoopCommonModes];
    
    [ActionStageInstance() requestActor:@"/tg/service/updatepresence/(timeout)" options:nil watcher:TGTelegraphInstance];
}

- (void)backgroundExpirationTimerEvent:(NSTimer *)__unused timer
{
    [[TGSession instance] suspendNetwork];
    
    _backgroundTaskExpirationTimer = nil;
    
    UIBackgroundTaskIdentifier identifier = _backgroundTaskIdentifier;
    _backgroundTaskIdentifier = UIBackgroundTaskInvalid;
    if (identifier == UIBackgroundTaskInvalid)
        TGLog(@"***** Strange. *****");
    
    double delayInSeconds = 5;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^
    {
        [[UIApplication sharedApplication] endBackgroundTask:identifier];
    });
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    if (_backgroundTaskIdentifier != UIBackgroundTaskInvalid)
    {
        UIBackgroundTaskIdentifier identifier = _backgroundTaskIdentifier;
        _backgroundTaskIdentifier = UIBackgroundTaskInvalid;
        [application endBackgroundTask:identifier];
    }
    if (_backgroundTaskExpirationTimer != nil)
    {
        if ([_backgroundTaskExpirationTimer isValid])
            [_backgroundTaskExpirationTimer invalidate];
        _backgroundTaskExpirationTimer = nil;
    }
    else
    {
        [[TGSession instance] resumeNetwork];
    }
    
    if (_callingWebView != nil)
    {
        [_callingWebView stopLoading];
        _callingWebView = nil;
    }
    
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        if ([ActionStageInstance() executingActorWithPath:@"/tg/service/updatepresence/(timeout)"] != nil)
            [ActionStageInstance() removeWatcher:TGTelegraphInstance fromPath:@"/tg/service/updatepresence/(timeout)"];
        else
            [TGTelegraphInstance updatePresenceNow];
    }];
}

- (void)applicationDidBecomeActive:(UIApplication *)__unused application
{
    //[ActionStageInstance() requestActor:@"/tg/locationServicesState/(dispatch)" options:[[NSDictionary alloc] initWithObjectsAndKeys:[[NSNumber alloc] initWithBool:true], @"dispatch", nil] watcher:TGTelegraphInstance];
}

- (void)applicationWillTerminate:(UIApplication *)__unused application
{
    TGLogSynchronize();
}

#pragma - Controller management

- (void)performPhoneCall:(NSURL *)url
{
    _callingWebView = [[UIWebView alloc] init];
    [_callingWebView loadRequest:[NSURLRequest requestWithURL:url]];
}

- (void)presentLoginController:(bool)clearControllerStates showWelcomeScreen:(bool)showWelcomeScreen phoneNumber:(NSString *)phoneNumber phoneCode:(NSString *)phoneCode phoneCodeHash:(NSString *)phoneCodeHash profileFirstName:(NSString *)profileFirstName profileLastName:(NSString *)profileLastName
{
    if (![[NSThread currentThread] isMainThread])
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            [self presentLoginController:clearControllerStates showWelcomeScreen:showWelcomeScreen phoneNumber:phoneNumber phoneCode:phoneCode phoneCodeHash:phoneCodeHash profileFirstName:profileFirstName profileLastName:profileLastName];
        });
        
        return;
    }
    else
    {
        TGNavigationController *loginNavigationController = [self loginNavigationController];
        NSMutableArray *viewControllers = [[loginNavigationController viewControllers] mutableCopy];
        
        if (showWelcomeScreen)
        {
            TGLoginInactiveUserController *inactiveUserController = [[TGLoginInactiveUserController alloc] init];
            [viewControllers addObject:inactiveUserController];
        }
        else
        {
            if (phoneNumber.length != 0)
            {
                TGLoginPhoneController *phoneController = [[TGLoginPhoneController alloc] init];
                [(TGLoginPhoneController *)phoneController setPhoneNumber:phoneNumber];
                [viewControllers addObject:phoneController];
                
                NSMutableString *cleanPhone = [[NSMutableString alloc] init];
                for (int i = 0; i < (int)phoneNumber.length; i++)
                {
                    unichar c = [phoneNumber characterAtIndex:i];
                    if (c >= '0' && c <= '9')
                        [cleanPhone appendString:[[NSString alloc] initWithCharacters:&c length:1]];
                }
                
                if (phoneCode.length != 0 && phoneCodeHash.length != 0)
                {
                    TGLoginProfileController *profileController = [[TGLoginProfileController alloc] initWithShowKeyboard:true phoneNumber:cleanPhone phoneCodeHash:phoneCodeHash phoneCode:phoneCode];
                    [viewControllers addObject:profileController];
                }
                else if (phoneCodeHash.length != 0)
                {
                    TGLoginCodeController *codeController = [[TGLoginCodeController alloc] initWithShowKeyboard:true phoneNumber:cleanPhone phoneCodeHash:phoneCodeHash];
                    [viewControllers addObject:codeController];
                }
            }
        }
        
        [loginNavigationController setViewControllers:viewControllers animated:false];
        
        if (_mainNavigationController.presentedViewController != nil)
        {
            if (_mainNavigationController.presentedViewController == loginNavigationController)
                return;
            
            [_mainNavigationController dismissModalViewControllerAnimated:true];
            double delayInSeconds = 0.5;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
            dispatch_after(popTime, dispatch_get_main_queue(), ^
            {
                [_mainNavigationController presentViewController:loginNavigationController animated:[[UIApplication sharedApplication] applicationState] == UIApplicationStateActive completion:nil];
            });
        }
        else
            [_mainNavigationController presentViewController:loginNavigationController animated:[[UIApplication sharedApplication] applicationState] == UIApplicationStateActive completion:nil];
        
        if (clearControllerStates)
        {
            double delayInSeconds = 0.5;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
            dispatch_after(popTime, dispatch_get_main_queue(), ^
            {
                [_mainTabsController setSelectedIndex:1];
                
                [_dialogListController.dialogListCompanion clearData];
                [_contactsController clearData];
                //[_addContactsController clearData];
                
                //NSArray *controllers = [_mainNavigationController.viewControllers copy];
                
                [_mainNavigationController popToViewController:[_mainNavigationController.viewControllers objectAtIndex:0] animated:false];
                
                /*for (int i = 1; i < (int)controllers.count; i++)
                {
                    UIViewController *controller = [controllers objectAtIndex:i];
                    if ([controller conformsToProtocol:@protocol(TGDestructableViewController)])
                        [(id<TGDestructableViewController>)controller cleanupBeforeDestruction];
                }*/
            });
        }
    }
}

- (void)presentMainController
{
    if (![[NSThread currentThread] isMainThread])
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            [self presentMainController];
        });
        
        return;
    }
    
    self.loginNavigationController = nil;
    
    UIViewController *presentedViewController = nil;
    
    if ([_mainNavigationController respondsToSelector:@selector(presentedViewController)])
        presentedViewController = _mainNavigationController.presentedViewController;
    else
        presentedViewController = _mainNavigationController.modalViewController;
    
    if ([presentedViewController respondsToSelector:@selector(isBeingDismissed)])
    {
        if ([presentedViewController isBeingDismissed] || [presentedViewController isBeingPresented])
        {
            [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
            TGDispatchAfter(0.1, dispatch_get_main_queue(), ^
            {
                [[UIApplication sharedApplication] endIgnoringInteractionEvents];
                
                [self presentMainController];
            });
        }
        else
        {
            [_mainNavigationController dismissViewControllerAnimated:[[UIApplication sharedApplication] applicationState] == UIApplicationStateActive  completion:nil];
        }
    }
    else
    {
        [_mainNavigationController dismissViewControllerAnimated:[[UIApplication sharedApplication] applicationState] == UIApplicationStateActive completion:nil];
    }
}

- (void)presentContentController:(UIViewController *)controller
{
    _contentWindow = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    _contentWindow.windowLevel = UIWindowLevelStatusBar - 0.1f;
    
    _contentWindow.rootViewController = controller;
    
    dispatch_async(dispatch_get_main_queue(), ^
    {
        [self dismissNotification];
        
        [_contentWindow makeKeyAndVisible];
    });
}

- (void)dismissContentController
{
    if ([_contentWindow.rootViewController conformsToProtocol:@protocol(TGContentViewController)])
    {
        [(id<TGContentViewController>)_contentWindow.rootViewController contentControllerWillBeDismissed];
    }
    
    [_contentWindow.rootViewController viewWillDisappear:false];
    [_contentWindow.rootViewController viewDidDisappear:false];
    _contentWindow.rootViewController = nil;
    if (_contentWindow.isKeyWindow)
        [_contentWindow resignKeyWindow];
    [_window makeKeyWindow];
    _contentWindow = nil;
    
    if ([self.mainNavigationController.topViewController conformsToProtocol:@protocol(TGDestructableViewController)] && [self.mainNavigationController.topViewController respondsToSelector:@selector(contentControllerWillBeDismissed)])
        [(id<TGDestructableViewController>)self.mainNavigationController.topViewController contentControllerWillBeDismissed];
    
    dispatch_async(dispatch_get_main_queue(), ^
    {
        if (!_window.isKeyWindow)
            [_window makeKeyWindow];
    });
}

- (void)openURLNative:(NSURL *)url
{
    [(TGApplication *)[UIApplication sharedApplication] openURL:url forceNative:true];
}

#pragma mark -

- (NSDictionary *)loadLoginState
{
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    
    NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true) objectAtIndex:0];
    NSData *stateData = [[NSData alloc] initWithContentsOfFile:[documentsDirectory stringByAppendingPathComponent:@"state.data"]];
    
    if (stateData.length != 0)
    {
        NSInputStream *is = [[NSInputStream alloc] initWithData:stateData];
        [is open];
        
        uint8_t version = 0;
        [is read:(uint8_t *)&version maxLength:1];
        
        {
            int date = [is readInt32];
            if (date != 0)
                dict[@"date"] = @(date);
        }
        
        {
            NSString *phoneNumber = [is readString];
            if (phoneNumber.length != 0)
                dict[@"phoneNumber"] = phoneNumber;
        }
        
        {
            NSString *phoneCode = [is readString];
            if (phoneCode.length != 0)
                dict[@"phoneCode"] = phoneCode;
        }
        
        {
            NSString *phoneCodeHash = [is readString];
            if (phoneCodeHash.length != 0)
                dict[@"phoneCodeHash"] = phoneCodeHash;
        }
        
        {
            NSString *firstName = [is readString];
            if (firstName.length != 0)
                dict[@"firstName"] = firstName;
        }
        
        {
            NSString *lastName = [is readString];
            if (lastName.length != 0)
                dict[@"lastName"] = lastName;
        }
        
        {
            NSData *photo = [is readBytes];
            if (photo.length != 0)
                dict[@"photo"] = photo;
        }
        
        [is close];
    }
    
    return dict;
}

- (void)resetLoginState
{
    NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true) objectAtIndex:0];
    [[NSFileManager defaultManager] removeItemAtPath:[documentsDirectory stringByAppendingPathComponent:@"state.data"] error:nil];
}

- (void)saveLoginStateWithDate:(int)date phoneNumber:(NSString *)phoneNumber phoneCode:(NSString *)phoneCode phoneCodeHash:(NSString *)phoneCodeHash firstName:(NSString *)firstName lastName:(NSString *)lastName photo:(NSData *)photo
{
    NSOutputStream *os = [[NSOutputStream alloc] initToMemory];
    [os open];
    
    uint8_t version = 0;
    [os write:&version maxLength:1];
    
    [os writeInt32:date];
    
    [os writeString:phoneNumber];
    [os writeString:phoneCode];
    [os writeString:phoneCodeHash];
    [os writeString:firstName];
    [os writeString:lastName];
    [os writeBytes:photo];
    
    [os close];
    
    NSData *data = [os currentBytes];
    NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true) objectAtIndex:0];
    [data writeToFile:[documentsDirectory stringByAppendingPathComponent:@"state.data"] atomically:true];
}

- (void)loadSettings
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    TGTelegraphInstance.clientUserId = [[userDefaults objectForKey:@"telegraphUserId"] intValue];
    TGTelegraphInstance.clientIsActivated = [[userDefaults objectForKey:@"telegraphUserActivated"] boolValue];
    
    TGLog(@"Activated = %d", TGTelegraphInstance.clientIsActivated ? 1 : 0);
    
    id value = nil;
    if ((value = [userDefaults objectForKey:@"soundEnabled"]) != nil)
        _soundEnabled = [value boolValue];
    else
        _soundEnabled = true;
    
    if ((value = [userDefaults objectForKey:@"outgoingSoundEnabled"]) != nil)
        _outgoingSoundEnabled = [value boolValue];
    else
        _outgoingSoundEnabled = true;
    
    if ((value = [userDefaults objectForKey:@"vibrationEnabled"]) != nil)
        _vibrationEnabled = [value boolValue];
    else
        _vibrationEnabled = false;
    
    if ((value = [userDefaults objectForKey:@"bannerEnabled"]) != nil)
        _bannerEnabled = [value boolValue];
    else
        _bannerEnabled = true;
    
    if ((value = [userDefaults objectForKey:@"locationTranslationEnabled"]) != nil)
        _locationTranslationEnabled = [value boolValue];
    else
        _locationTranslationEnabled = false;
    
    if ((value = [userDefaults objectForKey:@"exclusiveConversationControllers"]) != nil)
        _exclusiveConversationControllers = [value boolValue];
    else
        _exclusiveConversationControllers = true;
    
    if ((value = [userDefaults objectForKey:@"autosavePhotos"]) != nil)
        _autosavePhotos = [value boolValue];
    else
        _autosavePhotos = false;

    if ((value = [userDefaults objectForKey:@"customChatBackground"]) != nil)
        _customChatBackground = [value boolValue];
    else
    {
        _customChatBackground = false;
        
        NSString *imageUrl = @"wallpaper-original-pattern-default";
        NSString *thumbnailUrl = @"local://wallpaper-thumb-pattern-default";
        NSString *filePath = [[NSBundle mainBundle] pathForResource:imageUrl ofType:@"jpg"];
        int tintColor = 0x0c3259;
        
        if (filePath != nil)
        {
            NSFileManager *fileManager = [[NSFileManager alloc] init];
            NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true) objectAtIndex:0];
            NSString *wallpapersPath = [documentsDirectory stringByAppendingPathComponent:@"wallpapers"];
            [fileManager createDirectoryAtPath:wallpapersPath withIntermediateDirectories:true attributes:nil error:nil];
            
            [fileManager copyItemAtPath:filePath toPath:[wallpapersPath stringByAppendingPathComponent:@"_custom.jpg"] error:nil];
            [[thumbnailUrl dataUsingEncoding:NSUTF8StringEncoding] writeToFile:[wallpapersPath stringByAppendingPathComponent:@"_custom-meta"] atomically:false];
            
            [(tintColor == -1 ? [NSData data] : [[NSData alloc] initWithBytes:&tintColor length:4]) writeToFile:[wallpapersPath stringByAppendingPathComponent:@"_custom_mono.dat"] atomically:false];
            
            _customChatBackground = true;
        }
    }

    if ((value = [userDefaults objectForKey:@"useDifferentBackend"]) != nil)
        _useDifferentBackend = [value boolValue];
    else
        _useDifferentBackend = true;
    
    if ((value = [userDefaults objectForKey:@"baseFontSize"]) != nil)
        TGBaseFontSize = MAX(16, MIN(60, [value intValue]));
    else
        TGBaseFontSize = 16;
    
    if ((value = [userDefaults objectForKey:@"autoDownloadPhotosInGroups"]) != nil)
        _autoDownloadPhotosInGroups = [value boolValue];
    else
        _autoDownloadPhotosInGroups = true;
    
    if ((value = [userDefaults objectForKey:@"autoDownloadPhotosInPrivateChats"]) != nil)
        _autoDownloadPhotosInPrivateChats = [value boolValue];
    else
        _autoDownloadPhotosInPrivateChats = true;
    
    _locationTranslationEnabled = false;
}

- (void)saveSettings
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    [userDefaults setObject:[[NSNumber alloc] initWithInt:TGTelegraphInstance.clientUserId] forKey:@"telegraphUserId"];
    [userDefaults setObject:[[NSNumber alloc] initWithBool:TGTelegraphInstance.clientIsActivated] forKey:@"telegraphUserActivated"];
    
    [userDefaults setObject:[NSNumber numberWithBool:_soundEnabled] forKey:@"soundEnabled"];
    [userDefaults setObject:[NSNumber numberWithBool:_outgoingSoundEnabled] forKey:@"outgoingSoundEnabled"];
    [userDefaults setObject:[NSNumber numberWithBool:_vibrationEnabled] forKey:@"vibrationEnabled"];
    [userDefaults setObject:[NSNumber numberWithBool:_bannerEnabled] forKey:@"bannerEnabled"];
    [userDefaults setObject:[NSNumber numberWithBool:_locationTranslationEnabled] forKey:@"locationTranslationEnabled"];
    [userDefaults setObject:[NSNumber numberWithBool:_exclusiveConversationControllers] forKey:@"exclusiveConversationControllers"];
    
    [userDefaults setObject:[NSNumber numberWithBool:_autosavePhotos] forKey:@"autosavePhotos"];
    [userDefaults setObject:[NSNumber numberWithBool:_customChatBackground] forKey:@"customChatBackground"];

    [userDefaults setObject:[NSNumber numberWithBool:_useDifferentBackend] forKey:@"useDifferentBackend"];

    [userDefaults setObject:[NSNumber numberWithInt:TGBaseFontSize] forKey:@"baseFontSize"];
    
    [userDefaults setObject:[NSNumber numberWithBool:_autoDownloadPhotosInGroups] forKey:@"autoDownloadPhotosInGroups"];
    [userDefaults setObject:[NSNumber numberWithBool:_autoDownloadPhotosInPrivateChats] forKey:@"autoDownloadPhotosInPrivateChats"];
    
    [userDefaults synchronize];
}

#pragma mark -

- (NSArray *)alertSoundTitles
{
    static NSArray *soundArray = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        NSMutableArray *array = [[NSMutableArray alloc] init];
        [array addObject:@"No Sound"];
        [array addObject:@"Default"];
        [array addObject:@"Tri-tone"];
        [array addObject:@"Tremolo"];
        [array addObject:@"Alert"];
        [array addObject:@"Bell"];
        [array addObject:@"Calypso"];
        [array addObject:@"Chime"];
        [array addObject:@"Glass"];
        [array addObject:@"Telegraph"];
        soundArray = array;
    });
    
    return soundArray;
}

- (void)playSound:(NSString *)name vibrate:(bool)vibrate
{
    dispatch_async(dispatch_get_main_queue(), ^
    {
        if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateActive || name == nil)
            return;
        
        static NSMutableDictionary *soundPlayed = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^
        {
            soundPlayed = [[NSMutableDictionary alloc] init];
        });
        
        double lastTimeSoundPlayed = [[soundPlayed objectForKey:name] doubleValue];
        
        CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();
        if (currentTime - lastTimeSoundPlayed < 0.25)
            return;
    
        [soundPlayed setObject:[[NSNumber alloc] initWithDouble:currentTime] forKey:name];
        
        if (name != nil)
        {
            NSNumber *soundId = [_loadedSoundSamples objectForKey:name];
            if (soundId == nil)
            {
                NSString *path = [NSString stringWithFormat:@"%@/%@", [[NSBundle mainBundle] resourcePath], name];
                NSURL *filePath = [NSURL fileURLWithPath:path isDirectory:NO];
                SystemSoundID sound;
                AudioServicesCreateSystemSoundID((__bridge CFURLRef)filePath, &sound);
                soundId = [NSNumber numberWithUnsignedLong:sound];
                [_loadedSoundSamples setObject:soundId forKey:name];
            }
            AudioServicesPlaySystemSound([soundId unsignedLongValue]);
        }
        
        if (vibrate && TGAppDelegateInstance.vibrationEnabled)
        {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
        }
    });
}

- (void)playNotificationSound:(NSString *)name
{
    dispatch_async(dispatch_get_main_queue(), ^
    {
        _currentAudioPlayer.delegate = nil;
        _currentAudioPlayer = nil;
        
        NSError *error = nil;
        AVAudioPlayer *audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:[[NSBundle mainBundle] URLForResource:name withExtension: @"m4a"] error:&error];
        if (error == nil)
        {
            _currentAudioPlayer = audioPlayer;
            audioPlayer.delegate = self;
            [audioPlayer play];
        }
    });
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)__unused flag
{
    if (player == _currentAudioPlayer)
    {
        _currentAudioPlayer.delegate = nil;
        _currentAudioPlayer = nil;
    }
}

- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)__unused player error:(NSError *)__unused error
{
    if (player == _currentAudioPlayer)
    {
        _currentAudioPlayer.delegate = nil;
        _currentAudioPlayer = nil;
    }
}

- (void)displayNotification:(NSString *)identifier timeout:(NSTimeInterval)timeout constructor:(UIView *(^)(UIView *existingView))constructor watcher:(ASHandle *)watcher watcherAction:(NSString *)watcherAction watcherOptions:(NSDictionary *)watcherOptions
{
    dispatch_async(dispatch_get_main_queue(), ^
    {
        if (_contentWindow != nil)
            return;
        
        static NSMutableDictionary *viewsByIdentifier = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^
        {
            viewsByIdentifier = [[NSMutableDictionary alloc] init];
        });
        
        UIView *existingView = [viewsByIdentifier objectForKey:identifier];
        UIView *view = constructor(existingView);
        if (view != nil)
        {
            if (_notificationWindow == nil)
            {
                _notificationWindow = [[TGNotificationWindow alloc] initWithFrame:CGRectZero];
                _notificationWindow.windowHeight = 45;
                [_notificationWindow adjustToInterfaceOrientation:[[UIApplication sharedApplication] statusBarOrientation]];
                _notificationWindow.windowLevel = UIWindowLevelStatusBar + 0.1f;
                //_notificationWindow.backgroundColor = [UIColor greenColor];
            }
            
            [_notificationWindow setContentView:view];
            _notificationWindow.watcher = watcher;
            _notificationWindow.watcherAction = watcherAction;
            _notificationWindow.watcherOptions = watcherOptions;
            [_notificationWindow animateIn];
            
            if (_notificationWindowTimeoutTimer != nil)
            {
                [_notificationWindowTimeoutTimer invalidate];
                _notificationWindowTimeoutTimer = nil;
            }
            
            _notificationWindowTimeoutTimer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:timeout] interval:timeout target:self selector:@selector(notificationWindowTimeoutTimerEvent) userInfo:nil repeats:false];
            [[NSRunLoop mainRunLoop] addTimer:_notificationWindowTimeoutTimer forMode:NSRunLoopCommonModes];
        }
    });
}

- (void)notificationWindowTimeoutTimerEvent
{
    _notificationWindowTimeoutTimer = nil;
    
    [_notificationWindow animateOut];
}

- (void)dismissNotification
{
    if (_notificationWindowTimeoutTimer != nil)
    {
        [_notificationWindowTimeoutTimer invalidate];
        _notificationWindowTimeoutTimer = nil;
    }
    
    [_notificationWindow animateOut];
}

- (UIView *)currentNotificationView
{
    return _notificationWindow.isDismissed ? nil : _notificationWindow.contentView;
}

#pragma mark -

- (void)requestDeviceToken:(id<TGDeviceTokenListener>)listener
{
    if (_tokenAlreadyRequested)
    {
        [_deviceTokenListener deviceTokenRequestCompleted:nil];
        return;
    }
    
    _deviceTokenListener = listener;
    [[UIApplication sharedApplication] registerForRemoteNotificationTypes:(UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound | UIRemoteNotificationTypeAlert)];
}

- (void)application:(UIApplication*)__unused application didRegisterForRemoteNotificationsWithDeviceToken:(NSData*)deviceToken
{
    _tokenAlreadyRequested = true;
    
    NSString *token = [[deviceToken description] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"<>"]];
    token = [token stringByReplacingOccurrencesOfString:@" " withString:@""];
    TGLog(@"Device token: %@", token);
    
    [_deviceTokenListener deviceTokenRequestCompleted:token];
    _deviceTokenListener = nil;
}

- (void)application:(UIApplication*)__unused application didFailToRegisterForRemoteNotificationsWithError:(NSError*)error
{
    _tokenAlreadyRequested = true;
    
	TGLog(@"Failed register for remote notifications: %@", error);
    [_deviceTokenListener deviceTokenRequestCompleted:nil];
    _deviceTokenListener = nil;
}

- (void)application:(UIApplication *)__unused application didReceiveLocalNotification:(UILocalNotification *)notification
{
    if (application.applicationState == UIApplicationStateActive)
        return;
    
    int64_t conversationId = [[notification.userInfo objectForKey:@"cid"] longLongValue];
    
    if (conversationId != 0 && _mainNavigationController.topViewController != _mainTabsController)
    {
        bool foundActive = false;
        
        for (UIViewController *controller in _mainNavigationController.viewControllers)
        {
            if ([controller isKindOfClass:[TGConversationController class]])
            {
                TGConversationController *conversationController = (TGConversationController *)controller;
                if (conversationController.conversationCompanion.conversationId == conversationId)
                {
                    foundActive = true;
                    break;
                }
            }
        }
        
        if (!foundActive)
        {
            [TGConversationController resetLastConversationIdForBackAction];
            [_mainNavigationController popToRootViewControllerAnimated:false];
            if (_mainTabsController.selectedIndex != 1)
                [_mainTabsController setSelectedIndex:1];
        }
        
        [self dismissContentController];
    }
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
{
    if (application.applicationState == UIApplicationStateActive)
        return;
    
    [self processRemoteNotification:userInfo];
}

- (void)processRemoteNotification:(NSDictionary *)userInfo
{
    [self processRemoteNotification:userInfo removeView:nil];
}

- (void)processRemoteNotification:(NSDictionary *)userInfo removeView:(UIView *)removeView
{
    if (TGTelegraphInstance.clientUserId == 0)
    {
        [removeView removeFromSuperview];
        return;
    }
    
    id nFromId = [userInfo objectForKey:@"from_id"];
    id nChatId = [userInfo objectForKey:@"chat_id"];
    id nContactId = [userInfo objectForKey:@"contact_id"];
    
    int conversationId = 0;
    
    if (nFromId != nil && [TGSchema canCreateIntFromObject:nFromId])
    {
        conversationId = [TGSchema intFromObject:nFromId];
        
        //[[TGInterfaceManager instance] navigateToConversationWithId:[TGSchema intFromObject:nFromId] conversation:nil animated:false];
        //[removeView removeFromSuperview];
    }
    else if (nChatId != nil && [TGSchema canCreateIntFromObject:nChatId])
    {
        conversationId = -[TGSchema intFromObject:nChatId];
        
        /*[ActionStageInstance() dispatchOnStageQueue:^
        {
            TGConversation *conversation = [TGDatabaseInstance() loadConversationWithId:-[TGSchema intFromObject:nChatId]];
            dispatch_async(dispatch_get_main_queue(), ^
            {
                if (conversation != nil)
                    [[TGInterfaceManager instance] navigateToConversationWithId:-[TGSchema intFromObject:nChatId] conversation:nil animated:false];
                [removeView removeFromSuperview];
            });
        }];*/
    }
    else if (nContactId != nil && [TGSchema canCreateIntFromObject:nContactId])
    {
        conversationId = [TGSchema intFromObject:nContactId];
    }
    else
    {
        [removeView removeFromSuperview];
    }
    
    if (conversationId != 0 && _mainNavigationController.topViewController != _mainTabsController)
    {
        bool foundActive = false;
        
        for (UIViewController *controller in _mainNavigationController.viewControllers)
        {
            if ([controller isKindOfClass:[TGConversationController class]])
            {
                TGConversationController *conversationController = (TGConversationController *)controller;
                if (conversationController.conversationCompanion.conversationId == conversationId)
                {
                    foundActive = true;
                    break;
                }
            }
        }
        
        if (!foundActive)
        {
            [TGConversationController resetLastConversationIdForBackAction];
            [_mainNavigationController popToRootViewControllerAnimated:false];
            if (_mainTabsController.selectedIndex != 1)
                [_mainTabsController setSelectedIndex:1];
        }
    }
}

- (BOOL)application:(UIApplication *)__unused application handleOpenURL:(NSURL *)url
{
    NSError *error = nil;
    
    NSString *match = nil;
    
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\/\\/c\\/(\\d*)" options:NSRegularExpressionCaseInsensitive error:&error];
    NSTextCheckingResult *textCheckingResult = [regex firstMatchInString:url.resourceSpecifier options:0 range:NSMakeRange(0, url.resourceSpecifier.length)];
    if (textCheckingResult != nil)
    {
        NSRange matchRange = [textCheckingResult rangeAtIndex:1];
        match = [url.resourceSpecifier substringWithRange:matchRange];
    }
    else
    {
        regex = [NSRegularExpression regularExpressionWithPattern:@"\\/\\/(\\d*)" options:NSRegularExpressionCaseInsensitive error:&error];
        textCheckingResult = [regex firstMatchInString:url.resourceSpecifier options:0 range:NSMakeRange(0, url.resourceSpecifier.length)];
        
        if (textCheckingResult != nil)
        {
            NSRange matchRange = [textCheckingResult rangeAtIndex:1];
            match = [url.resourceSpecifier substringWithRange:matchRange];
        }
    }
    
    if (match == nil)
        return true;
    
    if (_loginNavigationController != nil && _loginNavigationController.viewControllers.count != 0 && [[_loginNavigationController.viewControllers lastObject] isKindOfClass:[TGLoginCodeController class]])
    {
        [(TGLoginCodeController *)[_loginNavigationController.viewControllers lastObject] applyCode:match];
    }
    
    return true;
}

- (NSUInteger)application:(UIApplication *)__unused application supportedInterfaceOrientationsForWindow:(UIWindow *)__unused window
{
#if TG_USE_CUSTOM_CAMERA
    if ([window isKindOfClass:[TGCameraWindow class]])
    {
        return UIInterfaceOrientationMaskPortrait;
    }
#endif
    
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

@end
