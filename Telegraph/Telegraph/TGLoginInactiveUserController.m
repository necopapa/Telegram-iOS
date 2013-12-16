#import "TGLoginInactiveUserController.h"

#import "TGToolbarButton.h"

#import "TGProgressWindow.h"

#import "TGTelegraph.h"

#import "TGAppDelegate.h"

#import "TGDatabase.h"

#import "SGraphObjectNode.h"

#import "TGImageUtils.h"
#import "TGRemoteImageView.h"

#import "TGSynchronizeContactsActor.h"

#import "TGTimelineUploadPhotoRequestBuilder.h"

#import "TGContactsController.h"

#import "TGActivityIndicatorView.h"

#import "TGLabel.h"

@interface TGLoginInactiveUserController ()

@property (nonatomic, strong) TGProgressWindow *progressWindow;

@property (nonatomic, strong) TGUser *user;

@property (nonatomic, strong) UIView *interfaceContainer;
@property (nonatomic, strong) UIView *accessDisabledContainer;

@property (nonatomic, strong) TGRemoteImageView *avatarView;

@property (nonatomic, strong) UILabel *welcomeLabel;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *exclamationLabel;

@property (nonatomic, strong) UILabel *noticeLabel;

@property (nonatomic, strong) UIButton *inviteButton;

@property (nonatomic, strong) UIImage *uploadingAvatarImage;

@property (nonatomic, strong) UIView *titleStatusContainer;
@property (nonatomic, strong) TGLabel *titleStatusLabel;
@property (nonatomic, strong) TGActivityIndicatorView *titleStatusIndicator;

@end

@implementation TGLoginInactiveUserController

@synthesize actionHandle = _actionHandle;

@synthesize progressWindow = _progressWindow;

@synthesize user = _user;

@synthesize interfaceContainer = _interfaceContainer;
@synthesize accessDisabledContainer = _accessDisabledContainer;

@synthesize avatarView = _avatarView;

@synthesize welcomeLabel = _welcomeLabel;
@synthesize nameLabel = _nameLabel;
@synthesize exclamationLabel = _exclamationLabel;

@synthesize noticeLabel = _noticeLabel;

@synthesize inviteButton = _inviteButton;

@synthesize uploadingAvatarImage = _uploadingAvatarImage;

@synthesize titleStatusContainer = _titleStatusContainer;
@synthesize titleStatusLabel = _titleStatusLabel;
@synthesize titleStatusIndicator = _titleStatusIndicator;

- (id)init
{
    self = [super initWithNibName:nil bundle:nil];
    if (self)
    {
        self.style = TGViewControllerStyleBlack;
        
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:true];
        
        [ActionStageInstance() watchForPath:@"/tg/activation" watcher:self];
        [ActionStageInstance() watchForPath:@"/tg/contactListSynchronizationState" watcher:self];
        [ActionStageInstance() watchForPath:@"/tg/removeAndExportActionsRunning" watcher:self];
    }
    return self;
}

- (void)dealloc
{
    [_actionHandle reset];
    [ActionStageInstance() removeWatcher:self];
}

- (void)loadView
{
    [super loadView];
    
    self.view.opaque = false;
    
    self.titleText = TGLocalized(@"WelcomeScreen.Title");
    
    _interfaceContainer = [[UIView alloc] initWithFrame:self.view.bounds];
    _interfaceContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_interfaceContainer];
    
    TGToolbarButton *cancelButton = [[TGToolbarButton alloc] initWithCustomImages:[[UIImage imageNamed:@"HeaderButton_Login.png"] stretchableImageWithLeftCapWidth:11 topCapHeight:0] imageNormalHighlighted:[[UIImage imageNamed:@"HeaderButton_Login_Pressed.png"] stretchableImageWithLeftCapWidth:11 topCapHeight:0] imageLandscape:[[UIImage imageNamed:@"HeaderButton_Login_Landscape.png"] stretchableImageWithLeftCapWidth:11 topCapHeight:0] imageLandscapeHighlighted:[[UIImage imageNamed:@"HeaderButton_Login_Landscape_Pressed.png"] stretchableImageWithLeftCapWidth:11 topCapHeight:0] textColor:[UIColor whiteColor] shadowColor:UIColorRGBA(0x07080a, 0.35f)];
    cancelButton.text = TGLocalized(@"WelcomeScreen.Logout");
    cancelButton.minWidth = 59;
    [cancelButton sizeToFit];
    [cancelButton addTarget:self action:@selector(logoutButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:cancelButton];
    
    _avatarView = [[TGRemoteImageView alloc] initWithFrame:CGRectMake(0, 0, 187, 187)];
    _avatarView.fadeTransition = true;
    [_interfaceContainer addSubview:_avatarView];
    
    _welcomeLabel = [[UILabel alloc] init];
    _welcomeLabel.backgroundColor = [UIColor clearColor];
    _welcomeLabel.font = [UIFont systemFontOfSize:16];
    _welcomeLabel.textColor = [UIColor whiteColor];
    _welcomeLabel.shadowColor = UIColorRGB(0x28313d);
    _welcomeLabel.shadowOffset = CGSizeMake(0, 1);
    _welcomeLabel.text = TGLocalized(@"WelcomeScreen.Greeting");
    [_welcomeLabel sizeToFit];
    [_interfaceContainer addSubview:_welcomeLabel];
    
    _nameLabel = [[UILabel alloc] init];
    _nameLabel.backgroundColor = [UIColor clearColor];
    _nameLabel.font = [UIFont boldSystemFontOfSize:16];
    _nameLabel.textColor = [UIColor whiteColor];
    _nameLabel.shadowColor = UIColorRGB(0x28313d);
    _nameLabel.shadowOffset = CGSizeMake(0, 1);
    [_interfaceContainer addSubview:_nameLabel];
    
    _exclamationLabel = [[UILabel alloc] init];
    _exclamationLabel.backgroundColor = [UIColor clearColor];
    _exclamationLabel.font = [UIFont systemFontOfSize:16];
    _exclamationLabel.textColor = [UIColor whiteColor];
    _exclamationLabel.shadowColor = UIColorRGB(0x28313d);
    _exclamationLabel.shadowOffset = CGSizeMake(0, 1);
    _exclamationLabel.text = @"!";
    [_exclamationLabel sizeToFit];
    [_interfaceContainer addSubview:_exclamationLabel];
    
    _noticeLabel = [[UILabel alloc] init];
    _noticeLabel.font = [UIFont systemFontOfSize:14];
    _noticeLabel.textColor = UIColorRGB(0xc0c5cc);
    _noticeLabel.shadowColor = UIColorRGB(0x323c4a);
    _noticeLabel.shadowOffset = CGSizeMake(0, 1);
    _noticeLabel.text = TGLocalized(@"Login.InactiveHelp");
    _noticeLabel.backgroundColor = [UIColor clearColor];
    _noticeLabel.lineBreakMode = UILineBreakModeWordWrap;
    _noticeLabel.textAlignment = UITextAlignmentCenter;
    _noticeLabel.contentMode = UIViewContentModeCenter;
    _noticeLabel.numberOfLines = 0;
    CGSize size = [_noticeLabel sizeThatFits:CGSizeMake(270, 1024)];
    _noticeLabel.frame = CGRectMake(0, 0, size.width, size.height);
    [_interfaceContainer addSubview:_noticeLabel];
    
    UIImage *rawButtonImage = [UIImage imageNamed:[TGViewController isWidescreen] ? @"LoginGreenButton_Wide.png" : @"LoginGreenButton.png"];
    UIImage *rawButtonImageHighlighted = [UIImage imageNamed:[TGViewController isWidescreen] ? @"LoginGreenButton_Wide_Highlighted.png" : @"LoginGreenButton_Highlighted.png"];
    _inviteButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 279, rawButtonImage.size.height)];
    _inviteButton.exclusiveTouch = true;
    [_inviteButton setBackgroundImage:[rawButtonImage stretchableImageWithLeftCapWidth:(int)(rawButtonImage.size.width / 2) topCapHeight:0] forState:UIControlStateNormal];
    [_inviteButton setBackgroundImage:[rawButtonImageHighlighted stretchableImageWithLeftCapWidth:(int)(rawButtonImageHighlighted.size.width / 2) topCapHeight:0] forState:UIControlStateHighlighted];
    _inviteButton.titleLabel.font = [UIFont boldSystemFontOfSize:TGIsRetina() ? 16.5f : 16.0f];
    _inviteButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    [_inviteButton setTitle:TGLocalized(@"Login.InviteButton") forState:UIControlStateNormal];
    [_inviteButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [_inviteButton setTitleShadowColor:UIColorRGBA(0x1e6804, 0.4f) forState:UIControlStateNormal];
    [_inviteButton setTitleEdgeInsets:UIEdgeInsetsMake(0, 17, 0, 0)];
    [_inviteButton addTarget:self action:@selector(inviteButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    _inviteButton.titleLabel.shadowOffset = CGSizeMake(0, -1);
    [_interfaceContainer addSubview:_inviteButton];
    
    UIImageView *arrowView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"LoginGreenArrow.png"]];
    arrowView.frame = CGRectOffset(arrowView.frame, _inviteButton.frame.size.width - arrowView.frame.size.width - 13, 15);
    arrowView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [_inviteButton addSubview:arrowView];
    
    if (_user == nil)
        _user = [TGDatabaseInstance() loadUser:TGTelegraphInstance.clientUserId];
    
    if (![self _updateControllerInset:false])
        [self updateInterface];
}

- (void)doUnloadView
{
    
}

- (void)viewDidUnload
{
    [self doUnloadView];
    
    [super viewDidUnload];
}

- (void)viewWillAppear:(BOOL)animated
{
    [self rejoinActions];
    
    [self updateAccessStatus];
    
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    if (self.navigationController.viewControllers.count > 2)
    {
        NSArray *newViewControllers = [[NSArray alloc] initWithObjects:[self.navigationController.viewControllers objectAtIndex:0], [self.navigationController.viewControllers lastObject], nil];
        [self.navigationController setViewControllers:newViewControllers animated:false];
    }
    
    [super viewDidAppear:animated];
}

- (void)rejoinActions
{
    if (_uploadingAvatarImage == nil)
    {
        [ActionStageInstance() dispatchOnStageQueue:^
        {
            NSArray *uploadActions = [ActionStageInstance() rejoinActionsWithGenericPathNow:@"/tg/timeline/@/uploadPhoto/@" prefix:[[NSString alloc] initWithFormat:@"/tg/timeline/(%d)", TGTelegraphInstance.clientUserId] watcher:self];
            
            if (uploadActions.count != 0)
            {
                UIImage *uploadingAvatar = nil;
                if (uploadActions.count != 0)
                {
                    uploadingAvatar = ((TGTimelineUploadPhotoRequestBuilder *)[ActionStageInstance() executingActorWithPath:uploadActions.lastObject]).currentLoginBigPhoto;
                }
                
                dispatch_async(dispatch_get_main_queue(), ^
                {
                    _uploadingAvatarImage = uploadingAvatar;
                    [_avatarView loadImage:_uploadingAvatarImage];
                });
            }
        }];
    }
}

- (UIView *)accessDisabledContainer
{
    if (_accessDisabledContainer == nil)
    {
        float topOffset = 20 + 44;
        
        topOffset = MIN(topOffset, 20 + 50);
        
        float titleY = topOffset + ([TGViewController isWidescreen] ? 205 : 190);
        
        _accessDisabledContainer = [[UIView alloc] initWithFrame:self.view.bounds];
        _accessDisabledContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.view addSubview:_accessDisabledContainer];
        
        UIImageView *placeholderImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"ContactsDeniedPlaceholder.png"]];
        placeholderImageView.frame = CGRectOffset(placeholderImageView.frame, floorf((_accessDisabledContainer.frame.size.width - placeholderImageView.frame.size.width) / 2), titleY - placeholderImageView.frame.size.height - 29);
        [_accessDisabledContainer addSubview:placeholderImageView];
        
        UILabel *titleLabel = [[UILabel alloc] init];
        titleLabel.backgroundColor = [UIColor clearColor];
        titleLabel.font = [UIFont boldSystemFontOfSize:17];
        titleLabel.textColor = [UIColor whiteColor];
        titleLabel.shadowColor = UIColorRGB(0x28313d);
        titleLabel.shadowOffset = CGSizeMake(0, 1);
        [_accessDisabledContainer addSubview:titleLabel];
    
        titleLabel.text = TGLocalized(@"WelcomeScreen.ContactsAccessDisabled");
        [titleLabel sizeToFit];
        titleLabel.frame = CGRectOffset(titleLabel.frame, floorf((_accessDisabledContainer.frame.size.width - titleLabel.frame.size.width) / 2), titleY);
        
        UILabel *noticeLabel = [[UILabel alloc] init];
        noticeLabel.font = [UIFont systemFontOfSize:14];
        noticeLabel.textColor = UIColorRGB(0xc0c5cc);
        noticeLabel.shadowColor = UIColorRGB(0x323c4a);
        noticeLabel.shadowOffset = CGSizeMake(0, 1);
        noticeLabel.text = TGLocalized(@"Login.InactiveHelp");
        noticeLabel.backgroundColor = [UIColor clearColor];
        noticeLabel.lineBreakMode = UILineBreakModeWordWrap;
        noticeLabel.textAlignment = UITextAlignmentCenter;
        noticeLabel.contentMode = UIViewContentModeCenter;
        noticeLabel.numberOfLines = 0;
        
        NSString *model = @"iPhone";
        NSString *rawModel = [[[UIDevice currentDevice] model] lowercaseString];
        if ([rawModel rangeOfString:@"ipod"].location != NSNotFound)
            model = @"iPod";
        else if ([rawModel rangeOfString:@"ipad"].location != NSNotFound)
            model = @"iPad";
        
        NSString *baseText = [[NSString alloc] initWithFormat:TGLocalized(@"WelcomeScreen.ContactsAccessHelp"), model];
        
        if ([UILabel instancesRespondToSelector:@selector(setAttributedText:)])
        {
            UIColor *foregroundColor = UIColorRGB(0xc0c5cc);
            
            NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:[UIFont systemFontOfSize:14], NSFontAttributeName, foregroundColor, NSForegroundColorAttributeName, nil];
            NSDictionary *subAttrs = [NSDictionary dictionaryWithObjectsAndKeys:[UIFont boldSystemFontOfSize:14], NSFontAttributeName, nil];
            const NSRange range = [baseText rangeOfString:TGLocalized(@"WelcomeScreen.ContactsAccessSettings")];
            
            NSMutableAttributedString *attributedText = [[NSMutableAttributedString alloc] initWithString:baseText attributes:attrs];
            [attributedText setAttributes:subAttrs range:range];
            
            [noticeLabel setAttributedText:attributedText];
        }
        else
        {
            noticeLabel.text = baseText;
        }
        CGSize size = [noticeLabel sizeThatFits:CGSizeMake(270, 1024)];
        noticeLabel.frame = CGRectMake(floorf((_accessDisabledContainer.frame.size.width - size.width) / 2), titleY + 34, size.width, size.height);
        [_accessDisabledContainer addSubview:noticeLabel];
    }
    
    return _accessDisabledContainer;
}

- (void)updateAccessStatus
{
    TGPhonebookAccessStatus accessStatus = [TGSynchronizeContactsManager instance].phonebookAccessStatus;
    
    dispatch_async(dispatch_get_main_queue(), ^
    {
        if (accessStatus == TGPhonebookAccessStatusDisabled)
        {
            _interfaceContainer.hidden = true;
            self.accessDisabledContainer.hidden = false;
        }
        else
        {
            _interfaceContainer.hidden = false;
            _accessDisabledContainer.hidden = true;
        }
    });
}
- (UIView *)titleStatusContainer
{
    if (_titleStatusContainer == nil)
    {
        _titleStatusContainer = [[UIView alloc] initWithFrame:CGRectMake(floorf((self.titleLabel.frame.size.width - 40) / 2), -14, 40, 30)];
        _titleStatusContainer.clipsToBounds = false;
        
        _titleStatusLabel = [[TGLabel alloc] initWithFrame:CGRectZero];
        _titleStatusLabel.clipsToBounds = false;
        _titleStatusLabel.backgroundColor = [UIColor clearColor];
        _titleStatusLabel.textColor = [UIColor whiteColor];
        _titleStatusLabel.shadowColor = UIColorRGB(0x2f3948);
        _titleStatusLabel.shadowOffset = CGSizeMake(0, -1);
        _titleStatusLabel.font = [UIFont boldSystemFontOfSize:18];
        _titleStatusLabel.verticalAlignment = TGLabelVericalAlignmentTop;
        [_titleStatusContainer addSubview:_titleStatusLabel];
        
        _titleStatusIndicator = [[TGActivityIndicatorView alloc] initWithStyle:TGActivityIndicatorViewStyleSmallWhite];
        [_titleStatusContainer addSubview:_titleStatusIndicator];
        
        _titleStatusContainer.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        [self.titleLabel addSubview:_titleStatusContainer];
        
        _titleStatusLabel.text = TGLocalized(@"WelcomeScreen.UpdatingTitle");
        [_titleStatusLabel sizeToFit];
        _titleStatusLabel.frame = CGRectIntegral(CGRectMake((_titleStatusLabel.superview.frame.size.width - _titleStatusLabel.frame.size.width + _titleStatusIndicator.frame.size.width + 5) / 2, (_titleStatusLabel.superview.frame.size.height - _titleStatusLabel.frame.size.height) / 2 - 1, _titleStatusLabel.frame.size.width, _titleStatusLabel.frame.size.height));
        _titleStatusIndicator.frame = CGRectMake(_titleStatusLabel.frame.origin.x - _titleStatusIndicator.frame.size.width - 5, _titleStatusLabel.frame.origin.y + 4, _titleStatusIndicator.frame.size.width, _titleStatusIndicator.frame.size.height);
    }
    
    return _titleStatusContainer;
}

- (void)updateSynchronizationStatus
{
    bool updating = [TGSynchronizeContactsManager instance].contactsSynchronizationStatus;
    bool exporting = [TGSynchronizeContactsManager instance].removeAndExportActionsRunning;
    
    dispatch_async(dispatch_get_main_queue(), ^
    {
        if (updating || exporting)
        {
            self.titleText = nil;
            
            self.titleStatusContainer.hidden = false;
            [_titleStatusIndicator startAnimating];
        }
        else
        {
            self.titleText = TGLocalized(@"WelcomeScreen.Title");
            
            self.titleStatusContainer.hidden = true;
            [_titleStatusIndicator stopAnimating];
        }
    });
}

- (void)controllerInsetUpdated:(UIEdgeInsets)previousInset
{
    [super controllerInsetUpdated:previousInset];
    
    [self updateInterface];
}

- (void)updateInterface
{
    float topOffset = self.controllerInset.top;
    
    topOffset = MIN(topOffset, 20 + 50);
    
    if (_user.realFirstName.length != 0)
        _nameLabel.text = _user.realFirstName;
    else
        _nameLabel.text = _user.realLastName;
    [_nameLabel sizeToFit];
    
    if (_uploadingAvatarImage == nil)
    {
        if ((_user.photoUrlBig != nil) != (_avatarView.currentUrl != nil) || (_user.photoUrlBig != nil && ![_user.photoUrlBig isEqualToString:_avatarView.currentUrl]))
        {
            if (_user.photoUrlBig == nil)
                [_avatarView loadImage:[UIImage imageNamed:@"LoginBigPhotoPlaceholder.png"]];
            else
                [_avatarView loadImage:_user.photoUrlBig filter:@"inactiveAvatar" placeholder:[UIImage imageNamed:@"LoginBigPhotoPlaceholder.png"]];
        }
        else if (_avatarView.currentUrl == nil && _avatarView.currentImage == nil)
            [_avatarView loadImage:[UIImage imageNamed:@"LoginBigPhotoPlaceholder.png"]];
    }
    
    if (_nameLabel.frame.size.width + _welcomeLabel.frame.size.width + _exclamationLabel.frame.size.width > 315)
    {
        CGRect frame = _nameLabel.frame;
        frame.size.width = 315 - _welcomeLabel.frame.size.width - _exclamationLabel.frame.size.width;
        _nameLabel.frame = frame;
    }
    
    float welcomeY = topOffset + ([TGViewController isWidescreen] ? 255 : 235);
    CGRect welcomeFrame = _welcomeLabel.frame;
    welcomeFrame.origin = CGPointMake(floorf((320 - _nameLabel.frame.size.width - _welcomeLabel.frame.size.width - _exclamationLabel.frame.size.width) / 2), welcomeY);
    _welcomeLabel.frame = welcomeFrame;
    
    CGRect nameFrame = _nameLabel.frame;
    nameFrame.origin = CGPointMake(welcomeFrame.origin.x + welcomeFrame.size.width, welcomeFrame.origin.y);
    _nameLabel.frame = nameFrame;
    
    CGRect exclamationFrame = _exclamationLabel.frame;
    exclamationFrame.origin = CGPointMake(nameFrame.origin.x + nameFrame.size.width, nameFrame.origin.y);
    _exclamationLabel.frame = exclamationFrame;
    
    _noticeLabel.frame = CGRectMake(floorf((320 - _noticeLabel.frame.size.width) / 2), welcomeFrame.origin.y + welcomeFrame.size.height + 4, _noticeLabel.frame.size.width, _noticeLabel.frame.size.height);
    
    _inviteButton.frame = CGRectMake(floorf((320 - _inviteButton.frame.size.width) / 2), _noticeLabel.frame.origin.y + _noticeLabel.frame.size.height + 23, _inviteButton.frame.size.width, _inviteButton.frame.size.height);
    
    _avatarView.frame = CGRectMake(floorf((320 - _avatarView.frame.size.width) / 2), welcomeFrame.origin.y - 10 - _avatarView.frame.size.height, _avatarView.frame.size.width, _avatarView.frame.size.height);
}

#pragma mark -

- (void)logoutButtonPressed
{
    _progressWindow = [[TGProgressWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    [_progressWindow show:true];
    
    [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/auth/logout/(%d)", TGTelegraphInstance.clientUserId] options:nil watcher:self];
}

- (void)inviteButtonPressed
{
    TGContactsController *contactsController = [[TGContactsController alloc] initWithContactsMode:TGContactsModeInvite | TGContactsModeModalInvite | TGContactsModeModalInviteWithBack];
    contactsController.loginStyle = true;
    contactsController.watcherHandle = _actionHandle;
    [self.navigationController pushViewController:contactsController animated:true];
}

#pragma mark -

- (void)actionStageResourceDispatched:(NSString *)path resource:(id)resource arguments:(id)__unused arguments
{
    if ([path isEqualToString:@"/tg/activation"])
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            if ([((SGraphObjectNode *)resource).object boolValue])
                [TGAppDelegateInstance presentMainController];
        });
    }
    else if ([path isEqualToString:@"/tg/contactListSynchronizationState"])
    {
        if (![((SGraphObjectNode *)resource).object boolValue])
        {
            bool activated = [TGDatabaseInstance() haveRemoteContactUids];
            
            dispatch_async(dispatch_get_main_queue(), ^
            {
                if (activated)
                    [TGAppDelegateInstance presentMainController];
            });
        }
        else
        {
            
        }
        
        [self updateSynchronizationStatus];
        [self updateAccessStatus];
    }
    else if ([path isEqualToString:@"/tg/removeAndExportActionsRunning"])
    {
        [self updateSynchronizationStatus];
    }
}

- (void)actorCompleted:(int)resultCode path:(NSString *)path result:(id)__unused result
{
    if ([path hasPrefix:@"/tg/auth/logout/"])
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            [_progressWindow dismiss:true];
            _progressWindow = nil;
            
            if (resultCode != ASStatusSuccess)
            {
                [[[UIAlertView alloc] initWithTitle:nil message:@"An error occured" delegate:nil cancelButtonTitle:TGLocalized(@"Common.OK") otherButtonTitles:nil] show];
            }
            
            [self.navigationController popToRootViewControllerAnimated:true];
        });
    }
}

@end
