#import "TGForwardTargetController.h"

#import "TGDialogListController.h"
#import "TGTelegraphDialogListCompanion.h"
#import "TGContactsController.h"

#import "TGInterfaceManager.h"
#import "TGInterfaceAssets.h"

#import "TGButtonGroupView.h"
#import "TGToolbarButton.h"

#import "TGDatabase.h"

@interface TGForwardContactsController : TGContactsController

@property (nonatomic, strong) ASHandle *watcher;

@end

@implementation TGForwardContactsController

@synthesize watcher = _watcher;

- (void)singleUserSelected:(TGUser *)user
{
    [_watcher requestAction:@"userSelected" options:[NSDictionary dictionaryWithObjectsAndKeys:user, @"user", nil]];
}

@end

#pragma mark -

@interface TGForwardTargetController () <UIAlertViewDelegate, TGButtonGroupViewDelegate>

@property (nonatomic) bool blockMode;

@property (nonatomic, strong) UIView *toolbarContainerView;
@property (nonatomic, strong) TGButtonGroupView *buttonGroupView;

@property (nonatomic, strong) TGDialogListController *dialogListController;
@property (nonatomic, strong) TGTelegraphDialogListCompanion *dialogListCompanion;
@property (nonatomic, strong) TGForwardContactsController *contactsController;

@property (nonatomic, strong) TGViewController *currentViewController;

@property (nonatomic, strong) id selectedTarget;

@property (nonatomic, strong) NSArray *messages;

@property (nonatomic, strong) UIAlertView *currentAlert;

@end

@implementation TGForwardTargetController

- (id)initWithMessages:(NSArray *)messages
{
    self = [super initWithNibName:nil bundle:nil];
    if (self)
    {
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:true];
        
        _confirmationPrefix = TGLocalized(@"Conversation.ForwardToPrefix");
        
        _dialogListCompanion = [[TGTelegraphDialogListCompanion alloc] init];
        _dialogListCompanion.forwardMode = true;
        _dialogListCompanion.conversatioSelectedWatcher = _actionHandle;
        _dialogListController = [[TGDialogListController alloc] initWithCompanion:_dialogListCompanion];
        _dialogListController.customParentViewController = self;
        [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/dialoglist/(%d)", INT_MAX] options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:25], @"limit", [NSNumber numberWithInt:INT_MAX], @"date", nil] watcher:_dialogListCompanion];
        
        _contactsController = [[TGForwardContactsController alloc] initWithContactsMode:TGContactsModeRegistered | TGContactsModeClearSelectionImmediately];
        _contactsController.watcher = _actionHandle;
        _contactsController.customParentViewController = self;
        
        _messages = messages;
    }
    return self;
}

- (id)initWithSelectBlockTarget
{
    self = [super initWithNibName:nil bundle:nil];
    if (self)
    {
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:true];
        
        _dialogListCompanion = [[TGTelegraphDialogListCompanion alloc] init];
        _dialogListCompanion.forwardMode = true;
        _dialogListCompanion.conversatioSelectedWatcher = _actionHandle;
        _dialogListController = [[TGDialogListController alloc] initWithCompanion:_dialogListCompanion];
        _dialogListController.customParentViewController = self;
        [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/dialoglist/(%d)", INT_MAX] options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:25], @"limit", [NSNumber numberWithInt:INT_MAX], @"date", nil] watcher:_dialogListCompanion];
        
        _contactsController = [[TGForwardContactsController alloc] initWithContactsMode:TGContactsModeRegistered | TGContactsModeClearSelectionImmediately];
        _contactsController.watcher = _actionHandle;
        _contactsController.customParentViewController = self;
        
        _confirmationPrefix = TGLocalized(@"BlockedUsers.BlockPrefix");
        _controllerTitle = TGLocalized(@"BlockedUsers.BlockTitle");
        _blockMode = true;
    }
    return self;
}

- (void)dealloc
{
    [self doUnloadView];
    
    _currentAlert.delegate = nil;
    
    _dialogListController.customParentViewController = nil;
    _contactsController.customParentViewController = nil;
    
    [_actionHandle reset];
    [ActionStageInstance() removeWatcher:self];
}

- (UIBarStyle)requiredNavigationBarStyle
{
    if (_currentViewController != nil && [_currentViewController conformsToProtocol:@protocol(TGViewControllerNavigationBarAppearance) ] && [_currentViewController respondsToSelector:@selector(requiredNavigationBarStyle)])
        return [(id<TGViewControllerNavigationBarAppearance>)_currentViewController requiredNavigationBarStyle];
    return UIBarStyleDefault;
}

- (bool)navigationBarShouldBeHidden
{
    if (_currentViewController != nil && [_currentViewController conformsToProtocol:@protocol(TGViewControllerNavigationBarAppearance) ] && [_currentViewController respondsToSelector:@selector(navigationBarShouldBeHidden)])
        return [(id<TGViewControllerNavigationBarAppearance>)_currentViewController navigationBarShouldBeHidden];
    return false;
}

- (bool)shouldBeRemovedFromNavigationAfterHiding
{
    return true;
}

- (void)loadView
{
    [super loadView];
    
    self.titleText = _controllerTitle != nil ? _controllerTitle : TGLocalized(@"Conversation.ForwardTitle");
    
    TGToolbarButton *doneButton = [[TGToolbarButton alloc] initWithType:TGToolbarButtonTypeGeneric];
    doneButton.text = NSLocalizedString(@"Common.Cancel", @"");
    doneButton.minWidth = 59;
    [doneButton sizeToFit];
    [doneButton addTarget:self action:@selector(doneButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    
    UIBarButtonItem *doneButtonItem = [[UIBarButtonItem alloc] initWithCustomView:doneButton];
    self.navigationItem.leftBarButtonItem = doneButtonItem;
    
    _toolbarContainerView = [[UIView alloc] initWithFrame:CGRectMake(0, self.view.frame.size.height - 44, self.view.frame.size.width, 44)];
    _toolbarContainerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    _toolbarContainerView.backgroundColor = [[TGInterfaceAssets instance] footerBackground];
    
    _buttonGroupView = [[TGButtonGroupView alloc] init];
    _buttonGroupView.delegate = self;
    [_buttonGroupView addButton:TGLocalized(@"Conversation.ForwardChats")];
    [_buttonGroupView addButton:TGLocalized(@"Conversation.ForwardContacts")];
    [_buttonGroupView sizeToFit];
    
    _buttonGroupView.frame = CGRectIntegral(CGRectOffset(_buttonGroupView.frame, (_toolbarContainerView.frame.size.width - _buttonGroupView.frame.size.width) / 2, (_toolbarContainerView.frame.size.height - _buttonGroupView.frame.size.height) / 2));
    _buttonGroupView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [_toolbarContainerView addSubview:_buttonGroupView];
    
    [self setCurrentViewController:_dialogListController];
    
    [self.view addSubview:_toolbarContainerView];
}

- (void)doUnloadView
{
    [self setCurrentViewController:nil];
    
    if (_dialogListController.isViewLoaded)
        _dialogListController.view = nil;
    if (_contactsController.isViewLoaded)
        _contactsController.view = nil;
}

- (void)setCurrentViewController:(TGViewController *)currentViewController
{
    if (_currentViewController != nil)
    {
        [_currentViewController willMoveToParentViewController:nil];
        [_currentViewController.view removeFromSuperview];
        [_currentViewController removeFromParentViewController];
        [_currentViewController didMoveToParentViewController:nil];
    }
    
    _currentViewController = currentViewController;
    
    if (_currentViewController != nil)
    {
        _currentViewController.parentInsets = UIEdgeInsetsMake(0, 0, _toolbarContainerView.frame.size.height, 0);
        
        [_currentViewController willMoveToParentViewController:self];
        [_currentViewController.view setFrame:self.view.bounds];
        [self.view insertSubview:_currentViewController.view atIndex:0];
        [self addChildViewController:_currentViewController];
        [_currentViewController didMoveToParentViewController:self];
    }
}

/*- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    
    _toolbarContainerView.frame = CGRectMake(0, self.view.frame.size.height - 44, self.view.frame.size.width, 44);
    if (_currentViewController != nil)
    {
        [_currentViewController.view setFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height - _toolbarContainerView.frame.size.height)];
    }
}*/

#pragma mark -

- (void)doneButtonPressed
{
    [self dismissSelf];
}

- (void)dismissSelf
{
    [self.presentingViewController dismissViewControllerAnimated:true completion:nil];
}

- (void)buttonGroupViewButtonPressed:(TGButtonGroupView *)__unused buttonGroupView index:(int)index
{
    if (index == 0)
    {
        if (_currentViewController != _dialogListController)
            [self setCurrentViewController:_dialogListController];
    }
    else if (index == 1)
    {
        if (_currentViewController != _contactsController)
            [self setCurrentViewController:_contactsController];
    }
}

#pragma mark -

- (void)actionStageActionRequested:(NSString *)action options:(NSDictionary *)options
{
    if ([action isEqualToString:@"userSelected"])
    {
        TGUser *user = [options objectForKey:@"user"];
        if (user != nil)
        {
            if (_blockMode)
            {
                [_watcherHandle requestAction:@"blockUser" options:user];
            }
            else
            {
                _selectedTarget = user;
                
                _currentAlert.delegate = nil;
                _currentAlert = [[UIAlertView alloc] initWithTitle:nil message:[NSString stringWithFormat:@"%@%@?", _confirmationPrefix, user.displayName] delegate:self cancelButtonTitle:NSLocalizedString(@"Common.No", nil) otherButtonTitles:NSLocalizedString(@"Common.Yes", nil), nil];
                [_currentAlert show];
            }
        }
    }
    else if ([action isEqualToString:@"conversationSelected"])
    {
        TGConversation *conversation = [options objectForKey:@"conversation"];
        if (conversation != nil)
        {
            _selectedTarget = conversation;
            
            if (conversation.isChat && conversation.conversationId > INT_MIN)
            {
                _selectedTarget = conversation;
                
                _currentAlert.delegate = nil;
                _currentAlert = [[UIAlertView alloc] initWithTitle:nil message:[NSString stringWithFormat:@"%@\"%@\"?", _blockMode ? TGLocalized(@"BlockedUsers.LeavePrefix") : _confirmationPrefix, conversation.chatTitle] delegate:self cancelButtonTitle:NSLocalizedString(@"Common.No", nil) otherButtonTitles:NSLocalizedString(@"Common.Yes", nil), nil];
                [_currentAlert show];
            }
            else
            {
                int uid = 0;
                
                if (conversation.isChat)
                {
                    if (conversation.chatParticipants.chatParticipantUids.count != 0)
                        uid = [conversation.chatParticipants.chatParticipantUids[0] intValue];
                }
                else
                    uid = (int)conversation.conversationId;
                
                TGUser *user = [TGDatabaseInstance() loadUser:uid];
                if (user != nil)
                {
                    if (_blockMode)
                    {
                        [_watcherHandle requestAction:@"blockUser" options:user];
                    }
                    else
                    {
                        _selectedTarget = conversation.isChat ? conversation : user;
                        
                        _currentAlert.delegate = nil;
                        _currentAlert = [[UIAlertView alloc] initWithTitle:nil message:[NSString stringWithFormat:@"%@%@?", _confirmationPrefix, user.displayName] delegate:self cancelButtonTitle:NSLocalizedString(@"Common.No", nil) otherButtonTitles:NSLocalizedString(@"Common.Yes", nil), nil];
                        [_currentAlert show];
                    }
                }
            }
        }
    }
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex != alertView.cancelButtonIndex && _selectedTarget != nil)
    {
        if (_blockMode)
        {
            if ([_selectedTarget isKindOfClass:[TGUser class]])
                [_watcherHandle requestAction:@"blockUser" options:_selectedTarget];
            else if ([_selectedTarget isKindOfClass:[TGConversation class]])
                [_watcherHandle requestAction:@"leaveConversation" options:_selectedTarget];
        }
        else
        {
            id<ASWatcher> watcher = _watcherHandle.delegate;
            if (watcher != nil && [watcher respondsToSelector:@selector(actionStageActionRequested:options:)])
                [watcher actionStageActionRequested:@"willForwardMessages" options:[[NSDictionary alloc] initWithObjectsAndKeys:self, @"controller", _selectedTarget, @"target", nil]];
            
            if ([_selectedTarget isKindOfClass:[TGUser class]])
            {
                TGUser *user = (TGUser *)_selectedTarget;
                [[TGInterfaceManager instance] navigateToConversationWithId:user.uid conversation:nil forwardMessages:_messages animated:false];
            }
            else if ([_selectedTarget isKindOfClass:[TGConversation class]])
            {
                TGConversation *conversation = (TGConversation *)_selectedTarget;
                [[TGInterfaceManager instance] navigateToConversationWithId:conversation.conversationId conversation:nil forwardMessages:_messages animated:false];
            }
        }
    }
    
    _currentAlert.delegate = nil;
    _currentAlert = nil;
}

@end
