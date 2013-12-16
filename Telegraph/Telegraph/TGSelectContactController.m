#import "TGSelectContactController.h"

#import "TGToolbarButton.h"

#import "TGUser.h"
#import "TGInterfaceManager.h"

#import "SGraphObjectNode.h"

#import "TGMessage+Telegraph.h"

#import "TGDatabase.h"
#import "TGTelegraph.h"

#import "TGTelegraphConversationProfileController.h"

#import "TGProgressWindow.h"

@interface TGSelectContactController ()

@property (nonatomic, strong) TGToolbarButton *createButton;

@property (nonatomic, strong) TGTelegraphConversationProfileController *chatInfoController;

@property (nonatomic) bool createEncrypted;

@property (nonatomic, strong) TGProgressWindow *progressWindow;

@property (nonatomic) TGUser *currentEncryptedUser;

@end

@implementation TGSelectContactController

- (id)initWithCreateGroup:(bool)createGroup createEncrypted:(bool)createEncrypted
{
    int contactsMode = TGContactsModeRegistered | TGContactsModeHideSelf;
    if (createEncrypted)
    {
        _createEncrypted = true;
    }
    else
    {
        if (createGroup)
            contactsMode |= TGContactsModeCompose;
        else
            contactsMode |= TGContactsModeCreateGroupOption;
    }
    
    self = [super initWithContactsMode:contactsMode];
    if (self)
    {
#if TARGET_IPHONE_SIMULATOR
        self.usersSelectedLimit = 10;
#else
        self.usersSelectedLimit = 99;
#endif
    }
    return self;
}

- (void)actionItemSelected
{
    TGSelectContactController *createGroupController = [[TGSelectContactController alloc] initWithCreateGroup:true createEncrypted:false];
    [self.navigationController pushViewController:createGroupController animated:true];
}

- (void)encryptionItemSelected
{
    TGSelectContactController *selectContactController = [[TGSelectContactController alloc] initWithCreateGroup:false createEncrypted:true];
    [self.navigationController pushViewController:selectContactController animated:true];
}

- (void)loadView
{
    [super loadView];
    
    self.backAction = @selector(performBackAction);
    
    if ((self.contactsMode & TGContactsModeCompose) == TGContactsModeCompose)
    {
        self.titleText = TGLocalized(@"Compose.NewGroup");
        
        _createButton = [[TGToolbarButton alloc] initWithType:TGToolbarButtonTypeDone];
        _createButton.minWidth = 56;
        _createButton.text = TGLocalized(@"Common.Next");
        [_createButton sizeToFit];
        [_createButton addTarget:self action:@selector(createButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:_createButton];
        _createButton.enabled = [self selectedContactsCount] != 0;
    }
    else if (_createEncrypted)
    {
        self.titleText = TGLocalized(@"Compose.NewEncryptedChat");
    }
    else
    {
        self.titleText = TGLocalized(@"Compose.NewMessage");
    }
}

- (void)performBackAction
{
    [self.navigationController popViewControllerAnimated:true];
}

- (void)createButtonPressed:(id)__unused sender
{
    NSArray *contacts = [self selectedContactsList];
    if (contacts.count == 0)
        return;
    /*else if (contacts.count == 1)
    {
        _shouldBeRemovedFromNavigationAfterHiding = true;
        
        int controllerIndex = [self.navigationController.viewControllers indexOfObject:self];
        if (controllerIndex != NSNotFound && controllerIndex > 0)
        {
            id previousController = [self.navigationController.viewControllers objectAtIndex:controllerIndex - 1];
            if ([previousController isKindOfClass:[TGSelectContactController class]])
                [(TGSelectContactController *)previousController setShouldBeRemovedFromNavigationAfterHiding:true];
        }
        
        TGUser *user = [contacts objectAtIndex:0];
        if (user.uid > 0)
            [[TGInterfaceManager instance] navigateToConversationWithId:user.uid conversation:nil];
    }*/
    else
    {
        if (_chatInfoController == nil)
        {
            _chatInfoController = [[TGTelegraphConversationProfileController alloc] initWithCreateChat];
            _chatInfoController.watcher = self.actionHandle;
        }
        
        NSMutableArray *participants = [[self selectedComposeUsers] mutableCopy];
        
        [_chatInfoController setCreateChatParticipants:participants];
        [self.navigationController pushViewController:_chatInfoController animated:true];
    }
}

- (void)contactSelected:(TGUser *)user
{
    _createButton.enabled = [self selectedContactsCount] != 0;
    [_createButton sizeToFit];
    
    [super contactSelected:user];
}

- (void)singleUserSelected:(TGUser *)user
{
    if (_createEncrypted)
    {
        if ([self.tableView indexPathForSelectedRow] != nil)
            [self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:true];
        
        _progressWindow = [[TGProgressWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        [_progressWindow show:true];
        
        _currentEncryptedUser = user;
        
        static int actionId = 0;
        [ActionStageInstance() requestActor:[[NSString alloc] initWithFormat:@"/tg/encrypted/createChat/(profile%d)", actionId++] options:@{@"uid": @(user.uid)} flags:0 watcher:self];
    }
    else
    {
        [super singleUserSelected:user];
    }
}

- (void)contactDeselected:(TGUser *)user
{
    _createButton.enabled = [self selectedContactsCount] != 0;
    [_createButton sizeToFit];
    
    [super contactDeselected:user];
}

#pragma mark -

- (void)actionStageActionRequested:(NSString *)action options:(NSDictionary *)options
{
    if ([action isEqualToString:@"chatCreated"])
    {
        _shouldBeRemovedFromNavigationAfterHiding = true;
    }
    
    if ([[self superclass] instancesRespondToSelector:@selector(actionStageActionRequested:options:)])
        [super actionStageActionRequested:action options:options];
}

- (void)actorCompleted:(int)status path:(NSString *)path result:(id)result
{
    if ([path hasPrefix:@"/tg/encrypted/createChat/"])
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            [_progressWindow dismiss:true];
            _progressWindow = nil;
            
            if (status == ASStatusSuccess)
            {
                TGConversation *conversation = result[@"conversation"];
                [[TGInterfaceManager instance] navigateToConversationWithId:conversation.conversationId conversation:nil];
            }
            else
            {
                [[[UIAlertView alloc] initWithTitle:nil message:status == -2 ? [[NSString alloc] initWithFormat:TGLocalized(@"Profile.CreateEncryptedChatOutdatedError"), _currentEncryptedUser.displayFirstName, _currentEncryptedUser.displayFirstName] : TGLocalized(@"Profile.CreateEncryptedChatError") delegate:nil cancelButtonTitle:TGLocalized(@"Common.OK") otherButtonTitles:nil] show];
            }
        });
    }
    
    if ([[self superclass] instancesRespondToSelector:@selector(actorCompleted:path:result:)])
        [super actorCompleted:status path:path result:result];
}

@end
