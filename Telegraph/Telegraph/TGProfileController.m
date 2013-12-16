#import "TGProfileController.h"

#import <QuartzCore/QuartzCore.h>

#import "SGraphObjectNode.h"

#import "TGDatabase.h"

#import "TGDateUtils.h"
#import "TGStringUtils.h"

#import "TGTelegraph.h"
#import "TGInterfaceAssets.h"
#import "TGInterfaceManager.h"
#import "TGAppDelegate.h"

#import "TGTabControllerChild.h"

#import "TGActionTableView.h"
#import "TGRemoteImageView.h"

#import "TGTransitionableImageView.h"

#import "TGToolbarButton.h"

#import "TGLabel.h"
#import "TGView.h"

#import "TGImageUtils.h"

#import "TGHighlightableButton.h"

#import "TGMenuSection.h"
#import "TGContactMediaItem.h"

#import "TGButtonsMenuItem.h"
#import "TGButtonsMenuItemView.h"

#import "TGActionMenuItemCell.h"
#import "TGSwitchItemCell.h"
#import "TGPhoneItemCell.h"
#import "TGContactMediaItemCell.h"
#import "TGVariantMenuItemCell.h"
#import "TGButtonMenuItemCell.h"

#import "TGCommentMenuItem.h"
#import "TGCommentMenuItemView.h"

#import "TGWallpapersMenuItem.h"
#import "TGWallpapersMenuItemCell.h"
#import "TGWallpaperPreviewController.h"
#import "TGWallpaperStoreController.h"

#import "TGSettingsController.h"
#import "TGNotificationSettingsController.h"
#import "TGPrivacySettingsController.h"

#import "TGNavigationController.h"
#import "TGCustomNotificationController.h"
#import "TGPhoneLabelController.h"

#import "TGTelegraphConversationCompanion.h"

#import "TGActivityIndicatorView.h"

#import "TGUserNode.h"

#import "TGMediaListView.h"

#import "TGSession.h"

#import "TGBlockedUsersController.h"

#import "TGImageViewController.h"
#import "TGHacks.h"
#import "TGTelegraphProfileImageViewCompanion.h"

#import "TGDateLabel.h"

#import "TGLocationRequestActor.h"

#import "TGTimelineUploadPhotoRequestBuilder.h"
#import "TGChangeNameActor.h"

#import "TGForwardTargetController.h"

#import "TGWallpaperStoreController.h"

#import "TGSynchronizeContactsActor.h"

#import "TGProgressWindow.h"

#import "TGImagePickerController.h"
#import "TGImageSearchController.h"

#import "TGChatSettingsController.h"

#import "TGEncryptionKeyViewController.h"

#import "TGApplication.h"

#import "TGSecurity.h"

#import <libkern/OSAtomic.h>
#import <MessageUI/MessageUI.h>

#define TG_USE_CUSTOM_CAMERA false

#if TG_USE_CUSTOM_CAMERA
#import "TGCameraWindow.h"
#endif

#define TGImageSourceActionSheetTag ((int)0x34281CB0)

@interface TGSelectExistingContactController : TGContactsController

@property (nonatomic, strong) NSString *phoneNumber;
@property (nonatomic) int uid;

@end

@implementation TGSelectExistingContactController

@synthesize phoneNumber = _phoneNumber;
@synthesize uid = _uid;

- (id)initWithPhoneNumber:(NSString *)phoneNumber uid:(int)uid
{
    self = [super initWithContactsMode:TGContactsModeRegistered | TGContactsModePhonebook | TGContactsModeSelectModal];
    if (self != nil)
    {
        _phoneNumber = phoneNumber;
        _uid = uid;
    }
    return self;
}

- (void)loadView
{
    [super loadView];
    
    self.titleText = TGLocalized(@"Contacts.Title");
}

- (void)singleUserSelected:(TGUser *)user
{
    if (user.uid > 0)
    {
        TGPhonebookContact *phonebookContact = [TGDatabaseInstance() phonebookContactByPhoneId:user.contactId];
        if (phonebookContact != nil)
        {
            TGProfileController *profileController = [[TGProfileController alloc] initWithAddToExistingContact:user phonebookContact:phonebookContact phoneNumber:_phoneNumber addingUid:_uid watcherHandle:self.actionHandle];
            [self.navigationController pushViewController:profileController animated:true];
        }
    }
    else
    {
        TGPhonebookContact *phonebookContact = [TGDatabaseInstance() phonebookContactByNativeId:-user.uid];
        if (phonebookContact != nil)
        {
            TGProfileController *profileController = [[TGProfileController alloc] initWithAddToExistingPhonebookContact:phonebookContact phoneNumber:_phoneNumber addingUid:_uid watcherHandle:self.actionHandle];
            [self.navigationController pushViewController:profileController animated:true];
        }
    }
}

- (void)actionStageActionRequested:(NSString *)action options:(NSDictionary *)options
{
    if ([action isEqualToString:@"addToExistingContactCompleted"])
    {
        id<ASWatcher> watcher = self.watcherHandle.delegate;
        if (watcher != nil && [watcher respondsToSelector:@selector(actionStageActionRequested:options:)])
            [watcher actionStageActionRequested:@"dismissModalContacts" options:nil];
        
        return;
    }
    
    [super actionStageActionRequested:action options:options];
}

@end

#define TG_MEDIA_LIST_SHOW_IMAGES false

typedef enum {
    TGProfileControllerModeSelf = 0,
    TGProfileControllerModeTelegraphUser = 1,
    TGProfileControllerModePhonebookContact = 2,
    TGProfileControllerModeCreateNewContact = 3,
    TGProfileControllerModeAddToExistingContact = 4,
    TGProfileControllerModeAddToExistingPhonebookContact = 5,
    TGProfileControllerModeCreateNewPhonebookContact = 6
} TGProfileControllerMode;

#define TGPhonesSectionTag ((int)0x971D6AA8)

#define TGSetProfilePhotoTag ((int)0x93DF146D)

#define TGNotificationsTag ((int)0x9CB3E5F6)
#define TGSoundTag ((int)0x2FA3E1D5)
#define TGPhotoNotificationsTag ((int)0xAF23FB65)
#define TGMessageLifetimeTag ((int)0x7892301A)

#define TGAddPhotoActionSheetTag ((int)0x712E4F33)
#define TGLogoutConfirmationActionSheetTag ((int)0xB584D0A1)

#define TGMediaSectionTag ((int)0xDE66DF67)
#define TGMediaItemTag ((int)0x10818401)

#define TGKeyItemTag ((int)0x9E75A7C8)

#define TGAutosaveItemTag ((int)0x6AF356F4)

#define TGDeleteSectionTag ((int)0x1D615462)
#define TGLogoutSectionTag ((int)0x3E3C5D15)

#define TGActionsSectionTag ((int)0xF41A09CF)
#define TGActionButtonsTag ((int)0xFCAAB832)
#define TGActionCommentTag ((int)0x2B826FE8)

#define TGPhotoProgressActionSheetTag ((int)0xA60D4CD9)
#define TGDeleteContactActionSheetTag ((int)0xA54D21BA)
#define TGAddContactActionSheetTag ((int)0x24EF616F)

#define TGMessageLifetimeActionSheetTag ((int)0x15134FA8)

#define TGInvitePhonesActionSheetTag ((int)0xFBAFECF9)

static void updateGroupedCellBackground(TGGroupedCell *cell, bool firstInSection, bool lastInSection, bool animated)
{
    UIImage *newImage = nil;
    
    if (firstInSection && lastInSection)
    {
        newImage = [TGInterfaceAssets groupedCellSingle];
        ((UIImageView *)cell.selectedBackgroundView).image = [TGInterfaceAssets groupedCellSingleHighlighted];
        
        [cell setGroupedCellPosition:TGGroupedCellPositionFirst | TGGroupedCellPositionLast];
        [cell setExtendSelectedBackground:false];
    }
    else if (firstInSection)
    {
        [cell setGroupedCellPosition:TGGroupedCellPositionFirst];
        [cell setExtendSelectedBackground:true];
        
        newImage = [TGInterfaceAssets groupedCellTop];
        ((UIImageView *)cell.selectedBackgroundView).image = [TGInterfaceAssets groupedCellTopHighlighted];
    }
    else if (lastInSection)
    {
        [cell setGroupedCellPosition:TGGroupedCellPositionLast];
        [cell setExtendSelectedBackground:true];
        
        newImage = [TGInterfaceAssets groupedCellBottom];
        ((UIImageView *)cell.selectedBackgroundView).image = [TGInterfaceAssets groupedCellBottomHighlighted];
    }
    else
    {
        [cell setGroupedCellPosition:0];
        [cell setExtendSelectedBackground:true];
        
        newImage = [TGInterfaceAssets groupedCellMiddle];
        ((UIImageView *)cell.selectedBackgroundView).image = [TGInterfaceAssets groupedCellMiddleHighlighted];
    }
    
    if ([cell.backgroundView isKindOfClass:[TGTransitionableImageView class]])
    {
        if (animated)
            [(TGTransitionableImageView *)cell.backgroundView transitionToImage:newImage duration:0.3];
        else
            [(TGTransitionableImageView *)cell.backgroundView setImage:newImage];
    }
    else
    {
        ((UIImageView *)cell.backgroundView).image = newImage;
    }
    
    [cell setGroupedCellPosition:(firstInSection ? TGGroupedCellPositionFirst : 0) | (lastInSection ? TGGroupedCellPositionLast : 0)];
}

@interface TGProfileController () <TGTabControllerChild, UITableViewDelegate, UITableViewDataSource, UIGestureRecognizerDelegate, UIActionSheetDelegate, UITextFieldDelegate, TGActionTableViewDelegate, MFMessageComposeViewControllerDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate, TGImagePickerControllerDelegate, UIAlertViewDelegate>
{
    volatile int _compareVariable;
}

@property (nonatomic, strong) ASHandle *watcherHandle;

@property (nonatomic) bool ignoreAllUpdates;

@property (nonatomic) int uid;
@property (nonatomic) int preferNativeContactId;
@property (nonatomic, strong) TGUser *user;
@property (nonatomic, strong) TGPhonebookContact *phonebookContact;
@property (nonatomic) TGProfileControllerMode mode;
@property (nonatomic) int userLink;

@property (nonatomic) bool linkAction;

@property (nonatomic, strong) NSString *phoneNumberToAdd;
@property (nonatomic) int addingUid;

@property (nonatomic, strong) UIBarButtonItem *editBarButtonItem;

@property (nonatomic, strong) UIBarButtonItem *leftBarButtonItem;
@property (nonatomic, strong) UIBarButtonItem *rightBarButtonItem;

@property (nonatomic) bool appearAnimation;
@property (nonatomic) bool isRotating;

@property (nonatomic, strong) NSMutableArray *sectionList;

@property (nonatomic, strong) UIView *titleContainer;
@property (nonatomic, strong) TGRemoteImageView *avatarView;
@property (nonatomic, strong) UIButton *addPhotoButton;
@property (nonatomic, strong) UIImageView *avatarActivityOverlay;
@property (nonatomic, strong) TGActivityIndicatorView *avatarActivityIndicator;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) TGDateLabel *statusLabel;

@property (nonatomic, strong) UIView *editNameContainer;
@property (nonatomic, strong) UITextField *firstNameField;
@property (nonatomic, strong) UITextField *lastNameField;

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic) float currentTableWidth;

@property (nonatomic) bool mediaListLoading;
@property (nonatomic) int mediaListTotalCount;

@property (nonatomic, strong) TGMenuSection *phonesSection;
@property (nonatomic, strong) TGMenuSection *editingPhonesSection;

@property (nonatomic, strong) TGMenuSection *actionsSection;
@property (nonatomic, strong) TGButtonsMenuItem *actionButtons;
@property (nonatomic, strong) TGCommentMenuItem *actionsCommentItem;

@property (nonatomic, strong) TGMenuSection *notificationsSection;
@property (nonatomic, strong) TGSwitchItem *notificationsItem;
@property (nonatomic, strong) TGVariantMenuItem *soundItem;
@property (nonatomic, strong) TGSwitchItem *photoNotificationsItem;
@property (nonatomic, strong) TGVariantMenuItem *messageDeletionItem;

@property (nonatomic, strong) TGMenuSection *mediaSection;

@property (nonatomic, strong) TGMenuSection *deleteSection;
@property (nonatomic, strong) TGButtonMenuItem *deleteItem;
@property (nonatomic, strong) TGButtonMenuItem *createEncryptedChatItem;

@property (nonatomic, strong) TGMenuSection *logoutSection;

@property (nonatomic, strong) NSMutableDictionary *peerNotificationSettings;

@property (nonatomic) int32_t peerMessageLifetime;

@property (nonatomic, strong) NSCondition *dataTimeoutCondition;

@property (nonatomic, strong) UIActionSheet *currentActionSheet;
@property (nonatomic, strong) NSDictionary *currentActionSheetMapping;

@property (nonatomic, strong) UIAlertView *currentAlertView;

@property (nonatomic) int currentImagePickerTarget;

@property (nonatomic, strong) TGProgressWindow *progressWindow;

#if TG_USE_CUSTOM_CAMERA
@property (nonatomic, strong) TGCameraWindow *cameraWindow;
#endif

@property (nonatomic) bool showingEditingControls;

@property (nonatomic) bool changingName;
@property (nonatomic, strong) NSString *changingFirstName;
@property (nonatomic, strong) NSString *changingLastName;

@property (nonatomic) int synchronizationState;

@property (nonatomic) int64_t encryptedConversationId;
@property (nonatomic) int64_t encryptedPeerId;
@property (nonatomic) int64_t encryptedKeyId;
@property (nonatomic) bool encryptionCancelled;

@property (nonatomic, strong) UIView *lockView;

@property (nonatomic) bool ignoreControllerInsetUpdates;

@end

@implementation TGProfileController

@synthesize leftBarButtonItem = _leftBarButtonItem;
@synthesize rightBarButtonItem = _rightBarButtonItem;

- (id)initWithUid:(int)uid preferNativeContactId:(int)preferNativeContactId encryptedConversationId:(int64_t)encryptedConversationId
{
    self = [super initWithNibName:nil bundle:nil];
    if (self)
    {
        _encryptedConversationId = encryptedConversationId;
        if (_encryptedConversationId != 0)
        {
            _encryptedPeerId = [TGDatabaseInstance() peerIdForEncryptedConversationId:_encryptedConversationId];
            _peerMessageLifetime = [TGDatabaseInstance() messageLifetimeForPeerId:_encryptedPeerId];
        }
        
        [self _commonInit];
        
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:true];
        
        _uid = uid;
        _preferNativeContactId = preferNativeContactId;
        
        _sectionList = [[NSMutableArray alloc] init];
        
        _peerNotificationSettings = [[NSMutableDictionary alloc] init];
        
        _compareVariable = 0;
        _dataTimeoutCondition = [[NSCondition alloc] init];
        
        [self switchToUid:uid];
    }
    return self;
}

- (id)initWithPhonebookContact:(TGPhonebookContact *)phonebookContact
{
    self = [super init];
    if (self != nil)
    {
        [self _commonInit];
        
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:true];
        
        _sectionList = [[NSMutableArray alloc] init];
        
        _mode = TGProfileControllerModePhonebookContact;
        
        _phonebookContact = phonebookContact;
        _userLink = 0;
        
        [ActionStageInstance() dispatchOnStageQueue:^
        {
            [ActionStageInstance() watchForPath:@"/tg/contactlist" watcher:self];
            [ActionStageInstance() watchForPath:@"/tg/phonebook" watcher:self];
        }];
    }
    return self;
}

- (id)initWithCreateNewContact:(TGUser *)user watcherHandle:(ASHandle *)watcherHandle
{
    self = [super init];
    if (self != nil)
    {
        [self _commonInit];
        
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:true];
        
        _sectionList = [[NSMutableArray alloc] init];
        
        _uid = user.uid;
        _user = user;
        
        if (user == nil)
            _mode = TGProfileControllerModeCreateNewPhonebookContact;
        else
            _mode = TGProfileControllerModeCreateNewContact;
        
        _watcherHandle = watcherHandle;
        
        _phonebookContact = nil;
        _userLink = 0;
        
        [ActionStageInstance() dispatchOnStageQueue:^
        {
            if (_uid != 0)
            {
                [ActionStageInstance() watchForPath:@"/tg/userdatachanges" watcher:self];
                [ActionStageInstance() watchForPath:@"/tg/userpresencechanges" watcher:self];
                [ActionStageInstance() watchForPath:[NSString stringWithFormat:@"/tg/timeline/(%d)/items", _uid] watcher:self];
                [ActionStageInstance() watchForPath:[NSString stringWithFormat:@"/tg/peerSettings/(%d)", _uid] watcher:self];
                [ActionStageInstance() watchForPath:[[NSString alloc] initWithFormat:@"/tg/userLink/(%d)", _uid] watcher:self];
                [ActionStageInstance() watchForPath:@"/tg/contactlist" watcher:self];
                [ActionStageInstance() watchForPath:@"/tg/phonebook" watcher:self];
                
                [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/completeUsers/(%d,cached)", _uid] options:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:_uid] forKey:@"uid"] watcher:TGTelegraphInstance];
                [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/peerSettings/(%d,cached)", _uid] options:[NSDictionary dictionaryWithObject:[NSNumber numberWithLongLong:_uid] forKey:@"peerId"] watcher:self];
            }
        }];
    }
    return self;
}

- (id)initWithAddToExistingContact:(TGUser *)user phonebookContact:(TGPhonebookContact *)phonebookContact phoneNumber:(NSString *)phoneNumber addingUid:(int)addingUid watcherHandle:(ASHandle *)watcherHandle
{
    self = [super init];
    if (self != nil)
    {
        [self _commonInit];
        
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:true];
        
        _sectionList = [[NSMutableArray alloc] init];
        
        _uid = user.uid;
        _user = user;
        _phonebookContact = phonebookContact;
        
        _mode = TGProfileControllerModeAddToExistingContact;
        
        _watcherHandle = watcherHandle;
        
        _userLink = 0;
        
        _phoneNumberToAdd = phoneNumber;
        _addingUid = addingUid;
        
        [ActionStageInstance() dispatchOnStageQueue:^
        {
            if (_uid != 0)
            {
                [ActionStageInstance() watchForPath:@"/tg/userdatachanges" watcher:self];
                [ActionStageInstance() watchForPath:@"/tg/userpresencechanges" watcher:self];
                [ActionStageInstance() watchForPath:[NSString stringWithFormat:@"/tg/timeline/(%d)/items", _uid] watcher:self];
                [ActionStageInstance() watchForPath:[NSString stringWithFormat:@"/tg/peerSettings/(%d)", _uid] watcher:self];
                [ActionStageInstance() watchForPath:[[NSString alloc] initWithFormat:@"/tg/userLink/(%d)", _uid] watcher:self];
                
                [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/completeUsers/(%d,cached)", _uid] options:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:_uid] forKey:@"uid"] watcher:TGTelegraphInstance];
                [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/peerSettings/(%d,cached)", _uid] options:[NSDictionary dictionaryWithObject:[NSNumber numberWithLongLong:_uid] forKey:@"peerId"] watcher:self];
            }
            
            [ActionStageInstance() watchForPath:@"/tg/contactlist" watcher:self];
            [ActionStageInstance() watchForPath:@"/tg/phonebook" watcher:self];
        }];
    }
    return self;
}

- (id)initWithAddToExistingPhonebookContact:(TGPhonebookContact *)phonebookContact phoneNumber:(NSString *)phoneNumber addingUid:(int)addingUid watcherHandle:(ASHandle *)watcherHandle
{
    self = [super init];
    if (self != nil)
    {
        [self _commonInit];
        
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:true];
        
        _sectionList = [[NSMutableArray alloc] init];
        
        _phonebookContact = phonebookContact;
        
        _mode = TGProfileControllerModeAddToExistingPhonebookContact;
        
        _watcherHandle = watcherHandle;
        
        _userLink = 0;
        
        _phoneNumberToAdd = phoneNumber;
        _addingUid = addingUid;
        
        [ActionStageInstance() dispatchOnStageQueue:^
        {   
            [ActionStageInstance() watchForPath:@"/tg/contactlist" watcher:self];
            [ActionStageInstance() watchForPath:@"/tg/phonebook" watcher:self];
        }];
    }
    return self;
}

- (void)dealloc
{
    [self doUnloadView];
    
    _currentActionSheet.delegate = nil;
    _currentAlertView.delegate = nil;
    
    [_actionHandle reset];
    [ActionStageInstance() removeWatcher:self];
}

- (void)_commonInit
{
    self.wantsFullScreenLayout = true;
}

- (NSString *)controllerTitle
{
    return TGLocalized(@"Settings.Title");
}

- (void)setLeftBarButtonItem:(UIBarButtonItem *)leftBarButtonItem
{
    [self setLeftBarButtonItem:leftBarButtonItem animated:false];
}

- (void)setLeftBarButtonItem:(UIBarButtonItem *)leftBarButtonItem animated:(BOOL)animated
{
    if (self == TGAppDelegateInstance.myAccountController)
        _leftBarButtonItem = leftBarButtonItem;
    else
        [self.navigationItem setLeftBarButtonItem:leftBarButtonItem animated:animated];
}

- (void)setRightBarButtonItem:(UIBarButtonItem *)rightBarButtonItem
{
    [self setRightBarButtonItem:rightBarButtonItem animated:false];
}

- (void)setRightBarButtonItem:(UIBarButtonItem *)rightBarButtonItem animated:(BOOL)animated
{
    if (self == TGAppDelegateInstance.myAccountController)
        _rightBarButtonItem = rightBarButtonItem;
    else
        [self.navigationItem setRightBarButtonItem:rightBarButtonItem animated:animated];
}

- (UIBarButtonItem *)leftBarButtonItem
{
    if (self == TGAppDelegateInstance.myAccountController)
        return _leftBarButtonItem;
    else
        return self.navigationItem.leftBarButtonItem;
}

- (UIBarButtonItem *)editBarButtonItem
{
    if (_editBarButtonItem == nil)
    {
        TGToolbarButton *editButton = [[TGToolbarButton alloc] initWithType:TGToolbarButtonTypeGeneric];
        editButton.text = NSLocalizedString(@"Common.Edit", @"");
        editButton.minWidth = 51;
        bool hidden = (_mode == TGProfileControllerModeSelf || (_mode == TGProfileControllerModeTelegraphUser && (_userLink & TGUserLinkMyContact))) && _mode != TGProfileControllerModePhonebookContact ? false : true;
        
        editButton.hidden = hidden;
        [editButton sizeToFit];
        [editButton addTarget:self action:@selector(editingEditButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        
        _editBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:editButton];
    }
    
    return _editBarButtonItem;
}

- (UIBarButtonItem *)rightBarButtonItem
{
    if (self == TGAppDelegateInstance.myAccountController)
    {   
        if (_rightBarButtonItem == nil)
            _rightBarButtonItem = self.editBarButtonItem;
        
        return _rightBarButtonItem;
    }
    else
        return self.navigationItem.rightBarButtonItem;
}

- (UIBarButtonItem *)controllerLeftBarButtonItem
{
    return self.leftBarButtonItem;
}

- (UIBarButtonItem *)controllerRightBarButtonItem
{
    return self.rightBarButtonItem;
}

- (void)loadView
{
    [super loadView];
    
    self.titleText = (_mode == TGProfileControllerModeCreateNewContact || _mode == TGProfileControllerModeCreateNewPhonebookContact) ? TGLocalized(@"Profile.NewContactTitle") : (_encryptedConversationId != 0 ? [[NSString alloc] initWithFormat:@"   %@", TGLocalized(@"Profile.SecretTitle")] : TGLocalized(@"Profile.Title"));
    
    if (_encryptedConversationId != 0)
    {
        if ([self.titleLabel viewWithTag:12345] == nil)
        {
            _lockView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"ProfileLockIcon.png"]];
            _lockView.tag = 12345;
            CGRect frame = _lockView.frame;
            frame.origin = CGPointMake(0, UIInterfaceOrientationIsPortrait(self.interfaceOrientation) ? 6 : 4);
            _lockView.frame = frame;
            [self.titleLabel addSubview:_lockView];
        }
    }
    
    self.view.backgroundColor = [[TGInterfaceAssets instance] linesBackground];
    
    CGSize viewSize = self.view.bounds.size;
    
    _tableView = [[TGActionTableView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height) style:UITableViewStyleGrouped];
    _currentTableWidth = _tableView.frame.size.width;
    _tableView.allowsSelectionDuringEditing = true;
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.backgroundColor = [UIColor clearColor];
    _tableView.opaque = false;
    _tableView.backgroundView = nil;
    _tableView.sectionHeaderHeight = 0;
    _tableView.sectionFooterHeight = 0;
    [self.view addSubview:_tableView];
    
    _titleContainer = [[TGView alloc] initWithFrame:CGRectMake(0, 0, viewSize.width, 86)];
    ((TGView *)_titleContainer).hitTestMatchAll = true;
    _titleContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _titleContainer.backgroundColor = nil;
    _titleContainer.clipsToBounds = false;
    _titleContainer.opaque = false;
    
    _tableView.tableHeaderView = _titleContainer;

    [self setExplicitTableInset:UIEdgeInsetsMake(0, 0, 7, 0) scrollIndicatorInset:UIEdgeInsetsZero];
    
    _avatarView = [[TGRemoteImageView alloc] initWithFrame:CGRectMake(9, 14, 70, 70)];
    _avatarView.fadeTransition = true;
    _avatarView.userInteractionEnabled = true;
    _avatarView.exclusiveTouch = true;
    UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(avatarTapped:)];
    [_avatarView addGestureRecognizer:tapRecognizer];
    [_titleContainer addSubview:_avatarView];
    
    float retinaPixel = TGIsRetina() ? 0.5f : 0.0f;
    
    UIImage *rawImage = [UIImage imageNamed:@"AddPhotoMask.png"];
    _avatarActivityOverlay = [[UIImageView alloc] initWithImage:[rawImage stretchableImageWithLeftCapWidth:(int)(rawImage.size.width / 2) topCapHeight:(int)(rawImage.size.height / 2)]];
    _avatarActivityOverlay.userInteractionEnabled = true;
    [_avatarActivityOverlay addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(avatarActivityOverlayTapped:)]];
    _avatarActivityOverlay.frame = CGRectMake(9 + retinaPixel, 14, 69, 69);
    [_titleContainer addSubview:_avatarActivityOverlay];
    _avatarActivityOverlay.hidden = true;
    _avatarActivityOverlay.alpha = 0.0f;
    
    _avatarActivityIndicator = [[TGActivityIndicatorView alloc] initWithStyle:TGActivityIndicatorViewStyleSmallWhite];
    _avatarActivityIndicator.frame = CGRectOffset(_avatarActivityIndicator.frame, 36 + retinaPixel, 42);
    [_titleContainer addSubview:_avatarActivityIndicator];
    _avatarActivityIndicator.hidden = true;
    _avatarActivityIndicator.alpha = 0.0f;
    [_avatarActivityIndicator stopAnimating];
    
    CGRect addPhotoButtonFrame = _avatarView.frame;
    _addPhotoButton = [[TGHighlightableButton alloc] initWithFrame:addPhotoButtonFrame];
    _addPhotoButton.exclusiveTouch = true;
    
    UIImage *rawAddPhoto = [UIImage imageNamed:@"ProfilePhotoPlaceholder.png"];
    UIImage *rawAddPhotoHighlighted = [UIImage imageNamed:@"ProfilePhotoPlaceholder_Highlighted.png"];
    
    [_addPhotoButton setBackgroundImage:[rawAddPhoto stretchableImageWithLeftCapWidth:(int)(rawAddPhoto.size.width / 2) topCapHeight:0] forState:UIControlStateNormal];
    [_addPhotoButton setBackgroundImage:[rawAddPhotoHighlighted stretchableImageWithLeftCapWidth:(int)(rawAddPhotoHighlighted.size.width / 2) topCapHeight:0] forState:UIControlStateHighlighted];
    [_addPhotoButton addTarget:self action:@selector(addPhotoButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    [_titleContainer insertSubview:_addPhotoButton belowSubview:_avatarView];
    
    UILabel *addPhotoLabelFirst = [[UILabel alloc] init];
    addPhotoLabelFirst.text = TGLocalized(@"Profile.PhotoAdd");
    addPhotoLabelFirst.font = [UIFont boldSystemFontOfSize:14 + retinaPixel];
    addPhotoLabelFirst.backgroundColor = [UIColor clearColor];
    addPhotoLabelFirst.textColor = [UIColor whiteColor];
    addPhotoLabelFirst.shadowColor = UIColorRGBA(0x47586c, 0.5f);
    addPhotoLabelFirst.shadowOffset = CGSizeMake(0, -1);
    [addPhotoLabelFirst sizeToFit];
    
    UILabel *addPhotoLabelSecond = [[UILabel alloc] init];
    addPhotoLabelSecond.text = TGLocalized(@"Profile.PhotoPhoto");
    addPhotoLabelSecond.font = [UIFont boldSystemFontOfSize:14 + retinaPixel];
    addPhotoLabelSecond.backgroundColor = [UIColor clearColor];
    addPhotoLabelSecond.textColor = [UIColor whiteColor];
    addPhotoLabelSecond.shadowColor = UIColorRGBA(0x47586c, 0.5f);
    addPhotoLabelSecond.shadowOffset = CGSizeMake(0, -1);
    [addPhotoLabelSecond sizeToFit];
    
    addPhotoLabelFirst.frame = CGRectIntegral(CGRectMake((_addPhotoButton.frame.size.width - addPhotoLabelFirst.frame.size.width) / 2, 16 + retinaPixel, addPhotoLabelFirst.frame.size.width, addPhotoLabelFirst.frame.size.height));
    addPhotoLabelSecond.frame = CGRectIntegral(CGRectMake((_addPhotoButton.frame.size.width - addPhotoLabelSecond.frame.size.width) / 2, 33, addPhotoLabelSecond.frame.size.width, addPhotoLabelSecond.frame.size.height));
    
    [_addPhotoButton addSubview:addPhotoLabelFirst];
    [_addPhotoButton addSubview:addPhotoLabelSecond];
    
    _nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(94, _mode == TGProfileControllerModePhonebookContact ? 35 : 24, viewSize.width - 94 - 9, 24)];
    _nameLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _nameLabel.backgroundColor = [UIColor clearColor];
    _nameLabel.textColor = UIColorRGB(0x222932);
    _nameLabel.shadowColor = UIColorRGBA(0xedf0f5, 0.28f);
    _nameLabel.shadowOffset = CGSizeMake(0, 1);
    _nameLabel.font = [UIFont boldSystemFontOfSize:19];
    [_titleContainer addSubview:_nameLabel];
    
    _statusLabel = [[TGDateLabel alloc] initWithFrame:CGRectMake(94, 52, viewSize.width - 94 - 9, 24)];
    _statusLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _statusLabel.backgroundColor = [UIColor clearColor];
    _statusLabel.textColor = UIColorRGB(0x6d7d90);
    _statusLabel.shadowColor = UIColorRGBA(0xedf0f5, 0.28f);
    _statusLabel.shadowOffset = CGSizeMake(0, 1);
    _statusLabel.font = [UIFont systemFontOfSize:14];
    _statusLabel.dateFont = _statusLabel.font;
    _statusLabel.dateTextFont = _statusLabel.dateFont;
    _statusLabel.dateLabelFont = [UIFont systemFontOfSize:12];
    _statusLabel.amWidth = 20;
    _statusLabel.pmWidth = 20;
    _statusLabel.dstOffset = 2 + retinaPixel;
    [_titleContainer addSubview:_statusLabel];
    
    UISwipeGestureRecognizer *rightSwipeRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(tableViewSwiped:)];
    rightSwipeRecognizer.direction = UISwipeGestureRecognizerDirectionRight;
    [_tableView addGestureRecognizer:rightSwipeRecognizer];
    rightSwipeRecognizer.delegate = self;
    
    if (_mode == TGProfileControllerModeCreateNewContact || _mode == TGProfileControllerModeCreateNewPhonebookContact || _mode == TGProfileControllerModeAddToExistingContact || _mode == TGProfileControllerModeAddToExistingPhonebookContact)
    {
        _editingPhonesSection = [[TGMenuSection alloc] init];
        _editingPhonesSection.tag = TGPhonesSectionTag;
        NSMutableArray *newItems = [[NSMutableArray alloc] init];
        
        bool foundPhoneToAdd = false;
        
        if (_mode == TGProfileControllerModeAddToExistingContact || _mode == TGProfileControllerModeAddToExistingPhonebookContact)
        {
            NSString *cleanPhoneToAdd = [TGStringUtils cleanPhone:_phoneNumberToAdd];
            
            for (TGPhoneNumber *phoneNumber in _phonebookContact.phoneNumbers)
            {
                TGPhoneItem *phoneItem = [[TGPhoneItem alloc] init];
                phoneItem.label = phoneNumber.label;
                phoneItem.phone = phoneNumber.number;
                [newItems addObject:phoneItem];
                
                if ([[TGStringUtils cleanPhone:phoneNumber.number] isEqualToString:cleanPhoneToAdd])
                    foundPhoneToAdd = true;
            }
        }

        int addItemsCount = 2;
        
        if (foundPhoneToAdd)
            addItemsCount = 1;
        
        if (_mode == TGProfileControllerModeCreateNewPhonebookContact)
            addItemsCount = 1;
        
        NSString *phoneNumberToAdd = _mode == TGProfileControllerModeCreateNewContact ? _user.phoneNumber : _phoneNumberToAdd;
        
        for (int i = 0; i < addItemsCount; i++)
        {
            NSString *newLabel = TGLocalized(@"Profile.LabelMobile");
            for (NSString *label in [TGSynchronizeContactsManager phoneLabels])
            {
                bool used = false;
                for (TGPhoneItem *phoneItem in newItems)
                {
                    if ([phoneItem.label isEqualToString:label])
                    {
                        used = true;
                        break;
                    }
                }
                
                if (!used)
                {
                    newLabel = label;
                    break;
                }
            }
            
            TGPhoneItem *phoneItem = [[TGPhoneItem alloc] init];
            phoneItem.label = newLabel;
            phoneItem.phone = i == addItemsCount - 1 ? @"" : phoneNumberToAdd;
            [newItems addObject:phoneItem];
        }
        
        _editingPhonesSection.items = newItems;
        
        [_tableView setEditing:true animated:false];
    }
    [self updateTitle:false];
    [self updateTable];
    [self updateEditingState:false];
    
    if (_mode == TGProfileControllerModeCreateNewContact || _mode == TGProfileControllerModeCreateNewPhonebookContact || _mode == TGProfileControllerModeAddToExistingContact || _mode == TGProfileControllerModeAddToExistingPhonebookContact)
        [self updateNavigationButtons:true animated:false];
    else if (self != TGAppDelegateInstance.myAccountController)
        [self updateNavigationButtons:_showingEditingControls animated:false];
    
    if (![self _updateControllerInset:false])
        [self controllerInsetUpdated:UIEdgeInsetsZero];
}

- (void)doUnloadView
{
    _tableView.delegate = nil;
    _tableView.dataSource = nil;
    _tableView = nil;
}

- (void)viewDidUnload
{
    [self doUnloadView];
    
    [super viewDidUnload];
}

- (void)performCloseProfile
{
    _ignoreAllUpdates = true;
    
    [self.navigationController popViewControllerAnimated:true];
}

- (void)setShowAvatarActivity:(bool)show animated:(bool)animated
{
    if (show)
    {
        _avatarActivityIndicator.hidden = false;
        [_avatarActivityIndicator startAnimating];
        
        _avatarActivityOverlay.hidden = false;
        if (animated)
        {
            [UIView animateWithDuration:0.3 animations:^
            {
                _avatarActivityOverlay.alpha = 1.0f;
                _avatarActivityIndicator.alpha = 1.0f;
            }];
        }
        else
        {
            _avatarActivityOverlay.alpha = 1.0f;
            _avatarActivityIndicator.alpha = 1.0f;
        }
    }
    else
    {
        if (animated)
        {
            [UIView animateWithDuration:0.3 animations:^
            {
                _avatarActivityOverlay.alpha = 0.0f;
                _avatarActivityIndicator.alpha = 0.0f;
            } completion:^(BOOL finished)
            {
                if (finished)
                {
                    [_avatarActivityIndicator stopAnimating];
                    _avatarActivityIndicator.hidden = true;
                    
                    _avatarActivityOverlay.hidden = true;
                }
            }];
        }
        else
        {
            _avatarActivityOverlay.alpha = 0.0f;
            _avatarActivityIndicator.alpha = 0.0f;
            [_avatarActivityIndicator stopAnimating];
            _avatarActivityIndicator.hidden = true;
            
            _avatarActivityOverlay.hidden = true;
        }
    }
    
    int section = 0;
    int item = 0;
    TGButtonMenuItem *photoItem = (TGButtonMenuItem *)[self findMenuItem:TGSetProfilePhotoTag sectionIndex:&section itemIndex:&item];
    if (photoItem != nil)
    {
        if (photoItem.enabled != !show)
        {
            photoItem.enabled = !show;
            TGButtonMenuItemCell *buttonCell = (TGButtonMenuItemCell *)[_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:item inSection:section]];
            if ([buttonCell isKindOfClass:[TGButtonMenuItemCell class]])
                [buttonCell setEnabled:photoItem.enabled];
        }
    }
}

- (int)uid
{
    return _uid;
}

- (void)switchToUid:(int)uid
{
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        [ActionStageInstance() removeWatcher:self];
        
        if (uid != _uid)
            _preferNativeContactId = 0;
        _uid = uid;
        _user = nil;
        _phonebookContact = nil;
        _userLink = 0;
        
        if (uid != 0)
        {
            [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/users/(%d)", uid] options:nil watcher:self];
        
            [ActionStageInstance() watchForPath:@"/tg/userdatachanges" watcher:self];
            [ActionStageInstance() watchForPath:@"/tg/userpresencechanges" watcher:self];
            [ActionStageInstance() watchForPath:[NSString stringWithFormat:@"/tg/timeline/(%d)/items", uid] watcher:self];
            [ActionStageInstance() watchForPath:[NSString stringWithFormat:@"/tg/peerSettings/(%d)", uid] watcher:self];
            [ActionStageInstance() watchForPath:[[NSString alloc] initWithFormat:@"/tg/userLink/(%d)", uid] watcher:self];
            [ActionStageInstance() watchForPath:@"/tg/contactlist" watcher:self];
            [ActionStageInstance() watchForPath:@"/tg/phonebook" watcher:self];
            
            if (uid == TGTelegraphInstance.clientUserId)
            {
                [ActionStageInstance() requestActor:@"/tg/service/synchronizationstate" options:nil watcher:self];
                [ActionStageInstance() watchForPath:@"/tg/service/synchronizationstate" watcher:self];
            }
            
            if (_encryptedConversationId != 0)
            {
                [ActionStageInstance() watchForPath:[[NSString alloc] initWithFormat:@"/tg/conversation/(%lld)/conversation", _encryptedPeerId] watcher:self];
                [ActionStageInstance() watchForPath:[[NSString alloc] initWithFormat:@"/tg/encrypted/messageLifetime/(%lld)", _encryptedPeerId] watcher:self];
            }
        }
        
        if (uid == 0)
        {
            dispatch_async(dispatch_get_main_queue(), ^
            {
                if (_uid == TGTelegraphInstance.clientUserId)
                    self.mode = TGProfileControllerModeSelf;
                else
                    self.mode = TGProfileControllerModeTelegraphUser;
                
                [self updateTitle:false];
                [self updateTable];
            });
        }
        
        dispatch_async(dispatch_get_main_queue(), ^
        {
            if (self.isViewLoaded && _tableView.isEditing)
            {
                [_tableView setEditing:false animated:false];
                [self updateEditingState:false];
                [self updateNavigationButtons:false animated:false];
            }
        });
    }];
}

- (void)updateActions
{
    [self updateActions:true];
}

- (void)updateActions:(bool)updateTable
{
    bool showComment = false;
    bool hasPhones = false;
    
    NSMutableArray *buttons = [[NSMutableArray alloc] init];
    if (_mode == TGProfileControllerModePhonebookContact)
    {
        if (_phonebookContact.phoneNumbers.count != 0)
        {
            [buttons addObject:[[NSDictionary alloc] initWithObjectsAndKeys:TGLocalized(@"Profile.InviteButton"), @"title", [[NSNumber alloc] initWithBool:(_userLink & TGUserLinkMyRequested)], @"disabled", @"invite", @"action", [[NSNumber alloc] initWithBool:true], @"green", nil]];
        }
    }
    else
    {
        if (_user.phoneNumber.length != 0)
            hasPhones = true;
        
        [buttons addObject:[[NSDictionary alloc] initWithObjectsAndKeys:TGLocalized(@"Profile.SendMessageButton"), @"title", [[NSNumber alloc] initWithBool:false], @"disabled", @"sendMessage", @"action", nil]];
        
        if (_phonebookContact == nil)
        {
            [buttons addObject:[[NSDictionary alloc] initWithObjectsAndKeys:TGLocalized(@"Profile.AddContactButton"), @"title", [[NSNumber alloc] initWithBool:_user.phoneNumber.length == 0], @"disabled", @"addContact", @"action", nil]];
        }
        else
        {
            [buttons addObject:[[NSDictionary alloc] initWithObjectsAndKeys:TGLocalized(@"Profile.ShareContactButton"), @"title", [[NSNumber alloc] initWithBool:false], @"disabled", @"shareContact", @"action", nil]];
        }
    }
    
    _actionButtons.buttons = buttons;
    
    bool haveButtonsSection = false;
    
    int sectionIndex = 0;
    int itemIndex = 0;
    if ([self findMenuItem:TGActionButtonsTag sectionIndex:&sectionIndex itemIndex:&itemIndex])
    {
        haveButtonsSection = true;
        TGButtonsMenuItemView *buttonsView = (TGButtonsMenuItemView *)[_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:itemIndex inSection:sectionIndex]];
        if ([buttonsView isKindOfClass:[TGButtonsMenuItemView class]])
        {
            [buttonsView setButtons:_actionButtons.buttons];
        }
    }
    
    if (!haveButtonsSection)
        return;
    
    bool validComment = true;
    NSString *newComment = (_userLink & TGUserLinkMyRequested) ? @"You have sent a contact request" : @"To exchange phone numbers you can send a contact request";
    showComment = !hasPhones && (_userLink & TGUserLinkMyRequested);
    if (![_actionsCommentItem.comment isEqualToString:newComment])
    {
        _actionsCommentItem.comment = newComment;
        validComment = false;
    }
    
    bool haveComment = [self findMenuItem:TGActionCommentTag sectionIndex:&sectionIndex itemIndex:&itemIndex] != nil;
    if (showComment && !haveComment)
    {
        [_actionsSection.items addObject:_actionsCommentItem];
        
        if (updateTable)
        {
            [_tableView beginUpdates];
            [_tableView insertRowsAtIndexPaths:[[NSArray alloc] initWithObjects:[NSIndexPath indexPathForRow:1 inSection:sectionIndex], nil] withRowAnimation:UITableViewRowAnimationFade];
            [_tableView endUpdates];
        }
    }
    else if (!showComment && haveComment)
    {
        [_actionsSection.items removeObjectAtIndex:1];
        
        if (updateTable)
        {
            [_tableView beginUpdates];
            [_tableView deleteRowsAtIndexPaths:[[NSArray alloc] initWithObjects:[NSIndexPath indexPathForRow:itemIndex inSection:sectionIndex], nil] withRowAnimation:UITableViewRowAnimationFade];
            [_tableView endUpdates];
        }
    }
    else if (showComment && haveComment && !validComment)
    {
        if (updateTable)
        {
            [_tableView beginUpdates];
            [_tableView reloadRowsAtIndexPaths:[[NSArray alloc] initWithObjects:[NSIndexPath indexPathForRow:itemIndex inSection:sectionIndex], nil] withRowAnimation:UITableViewRowAnimationFade];
            [_tableView endUpdates];
        }
    }
}

- (NSString *)userFirstName
{
    if (_overrideFirstName != nil || _overrideLastName != nil)
        return _overrideFirstName;
    
    return _user.firstName;
}

- (NSString *)userLastName
{
    if (_overrideFirstName != nil || _overrideLastName != nil)
        return _overrideLastName;
    
    return _user.lastName;
}

- (NSString *)userDisplayName
{
    if (_overrideFirstName != nil || _overrideLastName != nil)
    {
        NSString *firstName = [self userFirstName];
        NSString *lastName = [self userLastName];
        
        if (firstName != nil && firstName.length != 0 && lastName != nil && lastName.length != 0)
            return [[NSString alloc] initWithFormat:@"%@ %@", firstName, lastName];
        else if (firstName != nil && firstName.length != 0)
            return firstName;
        else if (lastName != nil && lastName.length != 0)
            return lastName;
    }
    
    return _user.displayName;
}

- (void)updateEditingState:(bool)animated
{    
    if (_tableView.isEditing)
    {
        if (_editNameContainer == nil)
        {
            _editNameContainer = [[UIView alloc] initWithFrame:CGRectMake(90, 14, _titleContainer.frame.size.width - 90 - 9, 88)];
            _editNameContainer.hidden = true;
            _editNameContainer.alpha = 0.0f;
            _editNameContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            
            UIImageView *firstNameBackgroundView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, _editNameContainer.frame.size.width, 44)];
            firstNameBackgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            firstNameBackgroundView.image = [TGInterfaceAssets groupedCellTop];
            firstNameBackgroundView.userInteractionEnabled = true;
            [firstNameBackgroundView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(focusOnFirstNameField:)]];
            [_editNameContainer addSubview:firstNameBackgroundView];
            
            UIImageView *lastNameBackgroundView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 44, _editNameContainer.frame.size.width, 44)];
            lastNameBackgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            lastNameBackgroundView.image = [TGInterfaceAssets groupedCellBottom];
            lastNameBackgroundView.userInteractionEnabled = true;
            [lastNameBackgroundView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(focusOnLastNameField:)]];
            [_editNameContainer addSubview:lastNameBackgroundView];
            
            _firstNameField = [[UITextField alloc] initWithFrame:CGRectMake(15, 12, _editNameContainer.frame.size.width - 20, 22)];
            _firstNameField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            _firstNameField.contentMode = UIViewContentModeLeft;
            _firstNameField.font = [UIFont boldSystemFontOfSize:16];
            _firstNameField.backgroundColor = [UIColor clearColor];
            _firstNameField.keyboardType = UIKeyboardTypeDefault;
            _firstNameField.returnKeyType = UIReturnKeyNext;
            _firstNameField.textColor = [UIColor blackColor];
            _firstNameField.clearButtonMode = UITextFieldViewModeWhileEditing;
            _firstNameField.delegate = self;
            _firstNameField.placeholder = TGLocalized(@"Profile.FirstNamePlaceholder");
            [_editNameContainer addSubview:_firstNameField];
            
            _lastNameField = [[UITextField alloc] initWithFrame:CGRectMake(15, 44 + 11, _editNameContainer.frame.size.width - 20, 22)];
            _lastNameField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            _lastNameField.contentMode = UIViewContentModeLeft;
            _lastNameField.font = [UIFont boldSystemFontOfSize:16];
            _lastNameField.backgroundColor = [UIColor clearColor];
            _lastNameField.keyboardType = UIKeyboardTypeDefault;
            _lastNameField.returnKeyType = UIReturnKeyDefault;
            _lastNameField.textColor = [UIColor blackColor];
            _lastNameField.clearButtonMode = UITextFieldViewModeWhileEditing;
            _lastNameField.delegate = self;
            _lastNameField.placeholder = TGLocalized(@"Profile.LastNamePlaceholder");
            [_editNameContainer addSubview:_lastNameField];
            
            if (_mode == TGProfileControllerModeSelf)
            {
                _firstNameField.text = _user.realFirstName;
                _lastNameField.text = _user.realLastName;
            }
            else if (_mode == TGProfileControllerModePhonebookContact || _mode == TGProfileControllerModeAddToExistingPhonebookContact)
            {
                _firstNameField.text = _phonebookContact.firstName;
                _lastNameField.text = _phonebookContact.lastName;
            }
            else if (_mode == TGProfileControllerModeCreateNewPhonebookContact)
            {
                
            }
            else
            {
                if (_user.hasAnyName)
                {
                    _firstNameField.text = [self userFirstName];
                    _lastNameField.text = [self userLastName];
                }
                else
                {
                    _firstNameField.text = @"";
                    _lastNameField.text = @"";
                }
            }
            
            [_titleContainer addSubview:_editNameContainer];
        }
        
        _editNameContainer.hidden = false;
        
        if (animated)
        {
            [UIView animateWithDuration:0.3 animations:^
            {
                _nameLabel.alpha = 0.0f;
                _statusLabel.alpha = 0.0f;
                _editNameContainer.alpha = 1.0f;
            } completion:^(BOOL finished)
            {
                if (finished)
                {
                    _nameLabel.hidden = true;
                    _statusLabel.hidden = true;
                }
            }];
        }
        else
        {
            _nameLabel.alpha = 0.0f;
            _statusLabel.alpha = 0.0f;
            _editNameContainer.alpha = 1.0f;
            
            _nameLabel.hidden = true;
            _statusLabel.hidden = true;
        }
    }
    else
    {
        _nameLabel.hidden = false;
        _statusLabel.hidden = false;
        
        if (animated)
        {
            [UIView animateWithDuration:0.3 animations:^
            {
                _nameLabel.alpha = 1.0f;
                _statusLabel.alpha = 1.0f;
                _editNameContainer.alpha = 0.0f;
            } completion:^(BOOL finished)
            {
                if (finished)
                {
                    _editNameContainer.hidden = true;
                }
            }];
        }
        else
        {
            _nameLabel.alpha = 1.0f;
            _statusLabel.alpha = 1.0f;
            
            if (_editNameContainer != nil)
            {
                _editNameContainer.alpha = 0.0f;
                _editNameContainer.hidden = true;
            }
        }
    }
    
    if (_mode == TGProfileControllerModeTelegraphUser || _mode == TGProfileControllerModeCreateNewContact || _mode == TGProfileControllerModeCreateNewPhonebookContact || _mode == TGProfileControllerModeAddToExistingContact || _mode == TGProfileControllerModeAddToExistingPhonebookContact)
    {
        if (_tableView.isEditing)
        {
            [_tableView beginUpdates];
            
            NSMutableIndexSet *deleteSectionIndices = [[NSMutableIndexSet alloc] init];
            
            int sectionIndex = 0;
            if ([self findMenuItem:TGMediaItemTag sectionIndex:&sectionIndex itemIndex:NULL] != nil)
                [deleteSectionIndices addIndex:sectionIndex];
            if ([self findSection:TGActionsSectionTag sectionIndex:&sectionIndex] != nil)
                [deleteSectionIndices addIndex:sectionIndex];
            
            int itemIndex = 0;
            if ([self findMenuItem:TGActionButtonsTag sectionIndex:&sectionIndex itemIndex:&itemIndex])
            {
                UITableViewCell *cell = [_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:itemIndex inSection:sectionIndex]];
                [UIView animateWithDuration:0.2 animations:^
                {
                    cell.alpha = 0.0f;
                }];
            }
            
            if (_deleteSection != nil)
            {
                int section = 0;
                if ([self findSection:_deleteSection.tag sectionIndex:&section])
                {
                    [_tableView reloadSections:[NSIndexSet indexSetWithIndex:section] withRowAnimation:UITableViewRowAnimationFade];
                }
            }
            
            [_sectionList removeObjectsAtIndexes:deleteSectionIndices];
            [_tableView deleteSections:deleteSectionIndices withRowAnimation:UITableViewRowAnimationFade];
            
            int notificationsSectionIndex = 0;
            if ([self findSection:TGPhonesSectionTag sectionIndex:NULL])
                notificationsSectionIndex = 1;
            
            if (_mode != TGProfileControllerModeAddToExistingPhonebookContact && _mode != TGProfileControllerModeCreateNewPhonebookContact && [self findMenuItem:_notificationsItem.tag sectionIndex:NULL itemIndex:NULL] == nil)
            {
                [_sectionList insertObject:_notificationsSection atIndex:notificationsSectionIndex];
                [_tableView insertSections:[NSIndexSet indexSetWithIndex:notificationsSectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            }
            
           /* if (_mode != TGProfileControllerModeCreateNewContact && _mode != TGProfileControllerModeCreateNewPhonebookContact && _mode != TGProfileControllerModeAddToExistingContact && _mode != TGProfileControllerModeAddToExistingPhonebookContact && [self findMenuItem:_deleteSection.tag sectionIndex:NULL itemIndex:NULL] == nil)
            {
                [_sectionList insertObject:_deleteSection atIndex:notificationsSectionIndex + 1];
                [_tableView insertSections:[NSIndexSet indexSetWithIndex:notificationsSectionIndex + 1] withRowAnimation:UITableViewRowAnimationFade];
            }*/
            
            NSIndexPath *indexPathToResetEditing = nil;
            TGMenuSection *phonesSection = [self findSection:TGPhonesSectionTag sectionIndex:&sectionIndex];
            if (phonesSection != nil)
            {
                if (phonesSection.items.count != 0 && ((TGPhoneItem *)[phonesSection.items lastObject]).phone.length != 0)
                {
                    NSString *newLabel = TGLocalized(@"Profile.LabelMobile");
                    for (NSString *label in [TGSynchronizeContactsManager phoneLabels])
                    {
                        bool used = false;
                        for (TGPhoneItem *phoneItem in phonesSection.items)
                        {
                            if ([phoneItem.label isEqualToString:label])
                            {
                                used = true;
                                break;
                            }
                        }
                        
                        if (!used)
                        {
                            newLabel = label;
                            break;
                        }
                    }
                    
                    TGPhoneItem *emptyPhone = [[TGPhoneItem alloc] init];
                    emptyPhone.label = newLabel;
                    emptyPhone.phone = @"";
                    [phonesSection.items addObject:emptyPhone];
                    
                    if (phonesSection.items.count >= 2)
                    {
                        UITableViewCell *previousCell = [_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:phonesSection.items.count - 2 inSection:sectionIndex]];
                        updateGroupedCellBackground((TGGroupedCell *)previousCell, phonesSection.items.count == 2, false, true);
                    }
                    
                    indexPathToResetEditing = [NSIndexPath indexPathForRow:phonesSection.items.count - 1 inSection:sectionIndex];
                    [_tableView insertRowsAtIndexPaths:[[NSArray alloc] initWithObjects:indexPathToResetEditing, nil] withRowAnimation:UITableViewRowAnimationFade];
                }
            }
            
            [_tableView endUpdates];
            
            if (indexPathToResetEditing != nil)
            {
                UITableViewCell *cell = [_tableView cellForRowAtIndexPath:indexPathToResetEditing];
                if (cell != nil)
                {
                    [cell setEditing:false animated:false];
                    [cell setEditing:true animated:true];
                }
            }
        }
        else
        {
            [_tableView beginUpdates];
            
            NSMutableIndexSet *deleteSectionIndices = [[NSMutableIndexSet alloc] init];
            
            if (_deleteSection != nil)
            {
                int section = 0;
                if ([self findSection:_deleteSection.tag sectionIndex:&section])
                {
                    [_tableView reloadSections:[NSIndexSet indexSetWithIndex:section] withRowAnimation:UITableViewRowAnimationFade];
                }
            }
            
            int sectionIndex = 0;
            if ([self findMenuItem:_notificationsItem.tag sectionIndex:&sectionIndex itemIndex:NULL] != nil)
                [deleteSectionIndices addIndex:sectionIndex];
            
            [_sectionList removeObjectsAtIndexes:deleteSectionIndices];
            [_tableView deleteSections:deleteSectionIndices withRowAnimation:UITableViewRowAnimationFade];
            
            if (_actionsSection != nil && [self findSection:TGActionsSectionTag sectionIndex:NULL] == nil && _encryptedConversationId == 0)
            {
                [_sectionList insertObject:_actionsSection atIndex:_sectionList.count - 1];
                [_tableView insertSections:[NSIndexSet indexSetWithIndex:_sectionList.count - 2] withRowAnimation:UITableViewRowAnimationFade];
            }
            
            if (_mediaSection != nil && [self findMenuItem:TGMediaItemTag sectionIndex:NULL itemIndex:NULL] == nil)
            {
                [_sectionList insertObject:_mediaSection atIndex:_sectionList.count - 1];
                [_tableView insertSections:[NSIndexSet indexSetWithIndex:_sectionList.count - 2] withRowAnimation:UITableViewRowAnimationFade];
            }
            
            TGMenuSection *phonesSection = [self findSection:TGPhonesSectionTag sectionIndex:&sectionIndex];
            if (phonesSection != nil)
            {
                NSMutableArray *removeIndices = [[NSMutableArray alloc] init];
                int index = -1;
                for (TGPhoneItem *item in phonesSection.items)
                {
                    index++;
                    
                    if (item.phone.length == 0)
                        [removeIndices addObject:[NSIndexPath indexPathForRow:index inSection:sectionIndex]];
                }
                
                if (removeIndices.count != 0)
                {
                    for (int i = removeIndices.count - 1; i >= 0; i--)
                        [phonesSection.items removeObjectAtIndex:((NSIndexPath *)[removeIndices objectAtIndex:i]).row];
                    [_tableView deleteRowsAtIndexPaths:removeIndices withRowAnimation:UITableViewRowAnimationFade];
                    
                    if (phonesSection.items.count >= 1)
                    {
                        UITableViewCell *previousCell = [_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:phonesSection.items.count - 1 inSection:sectionIndex]];
                        updateGroupedCellBackground((TGGroupedCell *)previousCell, phonesSection.items.count == 1, true, true);
                    }
                }
            }
            
            [_tableView endUpdates];
        }
    }
    else
    {
        if (_mode == TGProfileControllerModeSelf)
        {
            @try
            {
                [_tableView beginUpdates];
                
                if (_tableView.isEditing)
                {
                    if ([self findSection:TGLogoutSectionTag sectionIndex:NULL] == nil)
                    {
                        [_sectionList addObject:_logoutSection];
                        [_tableView insertSections:[NSIndexSet indexSetWithIndex:_sectionList.count - 1] withRowAnimation:UITableViewRowAnimationFade];
                    }
                }
                else
                {
                    int sectionIndex = 0;
                    if ([self findSection:TGLogoutSectionTag sectionIndex:&sectionIndex] != nil)
                    {
                        [_sectionList removeObjectAtIndex:sectionIndex];
                        [_tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
                    }
                }
                
                [_tableView endUpdates];
            }
            @catch (NSException *e)
            {
                TGLog(@"%@", e);
            }
        }
    }
    
    [_tableView.tableHeaderView.layer removeAllAnimations];
    [_tableView.tableHeaderView.layer.presentationLayer removeAllAnimations];
    CGRect frame = _tableView.tableHeaderView.frame;
    frame.origin.x = 0;
    frame.size.width = _tableView.frame.size.width;
    _tableView.tableHeaderView.frame = frame;
    
    if (animated && _mode == TGProfileControllerModeTelegraphUser)
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            NSMutableArray *buttonsInCells = [[NSMutableArray alloc] init];
            for (id cell in _tableView.visibleCells)
            {
                if ([cell isKindOfClass:[TGButtonMenuItemCell class]])
                {
                    UITableViewCell *currentButtonCell = cell;
                    
                    currentButtonCell.clipsToBounds = false;
                    
                    [currentButtonCell.layer removeAnimationForKey:@"position"];
                    [currentButtonCell.layer.presentationLayer removeAnimationForKey:@"position"];
                    
                    [(TGButtonMenuItemCell *)currentButtonCell updateFrame];
                    
                    [buttonsInCells addObject:cell];
                }
            }
            
            for (UIView *view in _tableView.subviews)
            {
                if ([view isKindOfClass:[TGButtonMenuItemCell class]] && ![buttonsInCells containsObject:view])
                {
                    [view.layer removeAnimationForKey:@"position"];
                    [view.layer.presentationLayer removeAnimationForKey:@"position"];
                    
                    [(TGButtonMenuItemCell *)view updateFrame];
                }
            }
        });
    }
}

- (void)setMode:(TGProfileControllerMode)mode
{
    _mode = mode;
}

- (void)setUserLink:(int)userLink
{
    [self setUserLink:userLink animated:false];
}

- (void)setUserLink:(int)userLink animated:(bool)animated
{
    _userLink = userLink;
    
    bool enableEditing = false;
    
    if (_mode == TGProfileControllerModeCreateNewContact || _mode == TGProfileControllerModeCreateNewPhonebookContact || _mode == TGProfileControllerModeAddToExistingContact || _mode == TGProfileControllerModeAddToExistingPhonebookContact)
    {
        enableEditing = true;
    }
    else if (_mode == TGProfileControllerModeTelegraphUser)
    {
        if (_userLink & TGUserLinkMyContact)
        {
            enableEditing = true;
        }
    }
    else if (_mode == TGProfileControllerModeSelf)
    {
        enableEditing = true;
    }
    
    if (!enableEditing && _tableView.isEditing)
    {
        [_tableView setEditing:false animated:animated];
        [self updateEditingState:animated];
        [self updateNavigationButtons:false animated:animated];
    }
    
    if (self.editBarButtonItem.customView.hidden != !enableEditing)
    {
        self.editBarButtonItem.customView.hidden = !enableEditing;
    }
    
    [self updateActions];
}

- (void)updateTitle:(bool)animated
{
    if (!self.isViewLoaded)
    {
        if (_mode == TGProfileControllerModeSelf && _user.photoUrlSmall.length != 0)
        {
            TGDispatchAfter(0.3, dispatch_get_main_queue(), ^
            {
                [TGRemoteImageView preloadImage:_user.photoUrlSmall filter:@"profileAvatar" cache:nil allowThumbnailCache:false watcher:self];
            });
        }
        
        return;
    }
    
    if (_user == nil && _mode != TGProfileControllerModePhonebookContact && _mode != TGProfileControllerModeCreateNewPhonebookContact && _mode != TGProfileControllerModeAddToExistingPhonebookContact)
    {
        _tableView.hidden = true;
    }
    else
    {
        _tableView.hidden = false;
        
        if (_mode == TGProfileControllerModeSelf)
        {
            if (_synchronizationState == 1)
                _statusLabel.text = TGLocalized(@"State.connecting");
            else if (_synchronizationState == 2)
                _statusLabel.text = TGLocalized(@"State.updating");
            else
                _statusLabel.text = TGLocalized(@"Presence.online");
        }
        else if (_mode == TGProfileControllerModePhonebookContact || _mode == TGProfileControllerModeAddToExistingPhonebookContact || _mode == TGProfileControllerModeCreateNewPhonebookContact)
        {
            _statusLabel.text = nil;
        }
        else
        {
            if (_user.presence.online)
                _statusLabel.text = TGLocalized(@"Presence.online");
            else
            {
                int lastSeen = _user.presence.lastSeen;
                if (lastSeen < 0)
                    _statusLabel.text = TGLocalized(@"Presence.invisible");
                else if (lastSeen != 0)
                    _statusLabel.text = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"Time.last_seen", nil), [TGDateUtils stringForLastSeen:lastSeen]];
                else
                    _statusLabel.text = TGLocalized(@"Presence.offline");
            }
        }
        
        [_statusLabel measureTextSize];
        
        NSString *currentFirstName = nil;
        NSString *currentLastName = nil;
        if (_mode == TGProfileControllerModeSelf)
        {
            currentFirstName = _user.realFirstName;
            currentLastName = _user.realLastName;
        }
        else
        {
            if (_phonebookContact != nil)
            {
                currentFirstName = _phonebookContact.firstName;
                currentLastName = _phonebookContact.lastName;
            }
            else
            {
                currentFirstName = [self userFirstName];
                currentLastName = [self userLastName];
            }
        }
        
        if (_changingName)
        {
            if (_editNameContainer != nil)
            {
                _firstNameField.text = _changingFirstName;
                _lastNameField.text = _changingLastName;
                
                _firstNameField.enabled = false;
                _firstNameField.alpha = 0.5f;
                _lastNameField.enabled = false;
                _lastNameField.alpha = 0.5f;
            }
            
            _nameLabel.text = [[NSString alloc] initWithFormat:@"%@ %@", _changingFirstName, _changingLastName];
        }
        else
        {
            if (_editNameContainer != nil)
            {
                if (!_firstNameField.isFirstResponder && !_lastNameField.isFirstResponder)
                {
                    _firstNameField.text = currentFirstName;
                    _lastNameField.text = currentLastName;
                }
            }
            
            if (_mode == TGProfileControllerModePhonebookContact || _mode == TGProfileControllerModeAddToExistingPhonebookContact || _mode == TGProfileControllerModeCreateNewPhonebookContact)
            {
                _nameLabel.text = [[NSString alloc] initWithFormat:@"%@%s%@", _phonebookContact.firstName, _phonebookContact.firstName.length == 0 ? "" : " ", _phonebookContact.lastName];
            }
            else
                _nameLabel.text = _mode == TGProfileControllerModeSelf ? _user.displayRealName : [self userDisplayName];
        }
        
        [self updateButtons:self.interfaceOrientation];
        
        if (_avatarActivityOverlay.alpha < FLT_EPSILON && ((_avatarView.currentUrl != nil) != (_user.photoUrlSmall != nil) || ![_user.photoUrlSmall isEqualToString:_avatarView.currentUrl]))
        {
            if (_user.photoUrlSmall != nil)
            {
                _avatarView.fadeTransitionDuration = animated ? 0.3 : 0.14;
                if (animated)
                {
                    UIImage *currentImage = [_avatarView currentImage];
                    [_avatarView loadImage:_user.photoUrlSmall filter:@"profileAvatar" placeholder:(currentImage != nil ? currentImage :[TGInterfaceAssets profileAvatarPlaceholderEmpty]) forceFade:true];
                }
                else
                    [_avatarView loadImage:_user.photoUrlSmall filter:@"profileAvatar" placeholder:[TGInterfaceAssets profileAvatarPlaceholderEmpty] forceFade:false];
                
                if (animated)
                {
                    [UIView animateWithDuration:0.3 animations:^
                    {
                        _avatarView.alpha = 1.0f;
                        _addPhotoButton.alpha = 0.0f;
                    } completion:^(BOOL finished)
                    {
                        if (finished)
                        {
                            _addPhotoButton.hidden = true;
                        }
                    }];
                }
                else
                {
                    _avatarView.alpha = 1.0f;
                    _addPhotoButton.alpha = 0.0f;
                    _addPhotoButton.hidden = true;
                }
            }
            else
            {
                if (_mode == TGProfileControllerModeSelf)
                {
                    if (animated)
                    {
                        _addPhotoButton.hidden = false;
                        [UIView animateWithDuration:0.3 animations:^
                        {
                            _avatarView.alpha = 0.0f;
                            _addPhotoButton.alpha = 1.0f;
                        } completion:^(BOOL finished)
                        {
                            if (finished)
                            {
                                [_avatarView loadImage:nil];
                            }
                        }];
                    }
                    else
                    {
                        [_avatarView loadImage:nil];
                        
                        _avatarView.alpha = 0.0f;
                        _addPhotoButton.hidden = false;
                        _addPhotoButton.alpha = 1.0f;
                    }
                }
                else
                {
                    [_avatarView loadImage:[TGInterfaceAssets profileAvatarPlaceholder:_uid]];
                    _addPhotoButton.hidden = true;
                    _addPhotoButton.alpha = 0.0f;
                }
            }
        }
    }
}

- (void)updateTable
{
    [_sectionList removeAllObjects];
    
    if (_user != nil || ((_mode == TGProfileControllerModePhonebookContact || _mode == TGProfileControllerModeAddToExistingPhonebookContact) &&_phonebookContact != nil) || _mode == TGProfileControllerModeCreateNewPhonebookContact)
    {
        if (_mode == TGProfileControllerModeSelf)
        {
            TGMenuSection *photoSection = [[TGMenuSection alloc] init];
            [_sectionList addObject:photoSection];
            
            TGButtonMenuItem *photoItem = [[TGButtonMenuItem alloc] initWithTitle:TGLocalized(@"Settings.SetProfilePhoto") subtype:TGButtonMenuItemSubtypeGrayButton];
            photoItem.tag = TGSetProfilePhotoTag;
            photoItem.action = @selector(changePhotoButtonPressed);
            [photoSection.items addObject:photoItem];
            
            TGMenuSection *generalSection = [[TGMenuSection alloc] init];
            [_sectionList addObject:generalSection];
            
            TGActionMenuItem *notificationsItem = [[TGActionMenuItem alloc] initWithTitle:TGLocalized(@"Settings.NotificationsAndSounds")];
            notificationsItem.action = @selector(notificationsButtonPressed);
            [generalSection.items addObject:notificationsItem];
            
            /*TGActionMenuItem *privacyItem = [[TGActionMenuItem alloc] initWithTitle:@"Privacy Settings"];
            privacyItem.action = @selector(privacyButtonPressed);
            [generalSection.items addObject:privacyItem];*/
            
            TGActionMenuItem *blockedUsersItem = [[TGActionMenuItem alloc] initWithTitle:TGLocalized(@"Settings.BlockedUsers")];
            blockedUsersItem.action = @selector(blockedUsersButtonPressed);
            [generalSection.items addObject:blockedUsersItem];
            
            TGActionMenuItem *chatSettingsItem = [[TGActionMenuItem alloc] initWithTitle:TGLocalized(@"Settings.ChatSettings")];
            chatSettingsItem.action = @selector(chatSettingsButtonPressed);
            [generalSection.items addObject:chatSettingsItem];
            
            /*TGActionMenuItem *chatBackgroundItem = [[TGActionMenuItem alloc] initWithTitle:TGLocalized(@"Settings.ChatBackground")];
            chatBackgroundItem.action = @selector(chatBackgroundButtonPressed);
            [generalSection.items addObject:chatBackgroundItem];*/
            
            /*TGMenuSection *shareSection = [[TGMenuSection alloc] init];
            [shareSection.items addObject:shareItem];
            [_sectionList addObject:shareSection];
            
            TGActionMenuItem *shareItem = [[TGActionMenuItem alloc] initWithTitle:@"Share with friends"];
            shareItem.action = @selector(shareButtonPressed);*/
            
            TGMenuSection *wallpapersSection = [[TGMenuSection alloc] init];
            TGWallpapersMenuItem *wallpapersItem = [[TGWallpapersMenuItem alloc] init];
            [wallpapersSection.items addObject:wallpapersItem];
            [_sectionList addObject:wallpapersSection];
            
            TGMenuSection *autosaveSection = [[TGMenuSection alloc] init];
            [_sectionList addObject:autosaveSection];
            
            TGActionMenuItem *supportItem = [[TGActionMenuItem alloc] initWithTitle:TGLocalized(@"Settings.Support")];
            supportItem.action = @selector(supportButtonPressed);
            [autosaveSection.items addObject:supportItem];
            
            TGSwitchItem *autosaveItem = [[TGSwitchItem alloc] initWithTitle:TGLocalized(@"Settings.SaveIncomingPhotos")];
            autosaveItem.tag = TGAutosaveItemTag;
            autosaveItem.isOn = TGAppDelegateInstance.autosavePhotos;
            [autosaveSection.items addObject:autosaveItem];
            TGCommentMenuItem *autosaveCommentItem = [[TGCommentMenuItem alloc] initWithComment:TGLocalized(@"Settings.SaveIncomingPhotosHelp")];
            [autosaveSection.items addObject:autosaveCommentItem];
            
            _logoutSection = [[TGMenuSection alloc] init];
            _logoutSection.tag = TGLogoutSectionTag;
            if (_tableView.isEditing)
                [_sectionList addObject:_logoutSection];
            
            TGButtonMenuItem *logoutItem = [[TGButtonMenuItem alloc] initWithTitle:TGLocalized(@"Settings.Logout") subtype:TGButtonMenuItemSubtypeRedButton];
            logoutItem.action = @selector(logoutButtonPressed);
            [_logoutSection.items addObject:logoutItem];
        }
        else
        {   
            _phonesSection = [[TGMenuSection alloc] init];
            _phonesSection.tag = TGPhonesSectionTag;
            
            if (_mode == TGProfileControllerModePhonebookContact || _mode == TGProfileControllerModeAddToExistingPhonebookContact)
            {
                for (TGPhoneNumber *phoneNumber in _phonebookContact.phoneNumbers)
                {
                    TGPhoneItem *phoneItem = [[TGPhoneItem alloc] init];
                    phoneItem.label = phoneNumber.label;
                    phoneItem.phone = phoneNumber.number;
                    [_phonesSection.items addObject:phoneItem];
                }
            }
            else if (_mode == TGProfileControllerModeCreateNewPhonebookContact)
            {
            }
            else
            {
                if (_user.phoneNumber != nil && _user.phoneNumber.length != 0)
                {
                    int userPhoneMatchHash = phoneMatchHash(_user.phoneNumber);
                    if (_phonebookContact != nil && _phonebookContact.phoneNumbers.count != 0)
                    {
                        bool highlightMainPhone = _phonebookContact.phoneNumbers.count != 1;
                        for (TGPhoneNumber *phoneNumber in _phonebookContact.phoneNumbers)
                        {
                            TGPhoneItem *phoneItem = [[TGPhoneItem alloc] init];
                            phoneItem.label = phoneNumber.label;
                            phoneItem.phone = phoneNumber.number;
                            phoneItem.isMainPhone = phoneNumber.phoneId == userPhoneMatchHash;
                            phoneItem.highlightMainPhone = highlightMainPhone;
                            [_phonesSection.items addObject:phoneItem];
                        }
                    }
                    else
                    {
                        TGPhoneItem *phoneItem = [[TGPhoneItem alloc] init];
                        phoneItem.label = TGLocalized(@"Profile.LabelMobile");
                        phoneItem.phone = _user.phoneNumber;
                        phoneItem.isMainPhone = true;
                        phoneItem.highlightMainPhone = false;
                        [_phonesSection.items addObject:phoneItem];
                    }
                }
                else
                {
                    TGPhoneItem *phoneItem = [[TGPhoneItem alloc] init];
                    phoneItem.label = TGLocalized(@"Profile.LabelMobile");
                    phoneItem.phone = @"empty";
                    phoneItem.isMainPhone = true;
                    phoneItem.highlightMainPhone = false;
                    phoneItem.disabled = true;
                    [_phonesSection.items addObject:phoneItem];
                }
            }
            
            if (_tableView.editing)
                [_sectionList addObject:_editingPhonesSection];
            else
                [_sectionList addObject:_phonesSection];
            
            if (_actionsSection == nil)
            {
                _actionsSection = [[TGMenuSection alloc] init];
                _actionsSection.tag = TGActionsSectionTag;
                
                _actionButtons = [[TGButtonsMenuItem alloc] init];
                _actionButtons.tag = TGActionButtonsTag;
                [_actionsSection.items addObject:_actionButtons];
                
                _actionsCommentItem = [[TGCommentMenuItem alloc] initWithComment:@""];
                _actionsCommentItem.tag = TGActionCommentTag;
            }
            
            if (!_tableView.isEditing && _encryptedConversationId == 0)
                [_sectionList addObject:_actionsSection];
            
            if (_notificationsSection == nil)
            {
                int muteUntil = [[_peerNotificationSettings objectForKey:@"muteUntil"] intValue];
                int soundId = [[_peerNotificationSettings objectForKey:@"soundId"] intValue];
                
                NSNumber *photoNotificationsEnabled = [_peerNotificationSettings objectForKey:@"photoNotificationsEnabled"];
                
                _notificationsSection = [[TGMenuSection alloc] init];
                
                _notificationsItem = [[TGSwitchItem alloc] init];
                _notificationsItem.title = TGLocalized(@"Profile.Notifications");
                _notificationsItem.tag = TGNotificationsTag;
                _notificationsItem.isOn = muteUntil == 0;
                [_notificationsSection.items addObject:_notificationsItem];
                
                _soundItem = [[TGVariantMenuItem alloc] init];
                _soundItem.tag = TGSoundTag;
                _soundItem.title = TGLocalized(@"Profile.Sound");
                NSArray *soundsArray = [TGAppDelegateInstance alertSoundTitles];
                if (soundId >= 0 && soundId < (int)soundsArray.count)
                    _soundItem.variant = [soundsArray objectAtIndex:soundId];
                else
                    _soundItem.variant = [[NSString alloc] initWithFormat:@"Sound %d", soundId];
                _soundItem.action = @selector(customSoundPressed);
                
                _photoNotificationsItem = [[TGSwitchItem alloc] init];
                _photoNotificationsItem.title = TGLocalized(@"Profile.NewPhotos");
                _photoNotificationsItem.tag = TGPhotoNotificationsTag;
                _photoNotificationsItem.isOn = photoNotificationsEnabled == nil || [photoNotificationsEnabled boolValue];
                [_notificationsSection.items addObject:_photoNotificationsItem];
                
                [_notificationsSection.items addObject:_soundItem];
            }
            
            if (_tableView.isEditing && _uid > 0)
                [_sectionList addObject:_notificationsSection];
            
            if (_mediaSection == nil)
            {
                _mediaSection = [[TGMenuSection alloc] init];
                _mediaSection.tag = TGMediaSectionTag;
                
                TGContactMediaItem *mediaItem = [[TGContactMediaItem alloc] init];
                mediaItem.tag = TGMediaItemTag;
                [_mediaSection.items addObject:mediaItem];
                
                if (_encryptedConversationId != 0)
                {                    
                    int64_t keyId = 0;
                    NSData *keyData = [TGDatabaseInstance() encryptionKeyForConversationId:[TGDatabaseInstance() peerIdForEncryptedConversationId:_encryptedConversationId] keyFingerprint:&keyId];
                    _encryptionCancelled = [TGDatabaseInstance() loadConversationWithId:[TGDatabaseInstance() peerIdForEncryptedConversationId:_encryptedConversationId]].encryptedData.handshakeState == 3;
                    if (keyData != nil)
                    {
                        _encryptedKeyId = keyId;
                        NSData *hashData = computeSHA1(keyData);
                        if (hashData != nil)
                        {
                            _messageDeletionItem = [[TGVariantMenuItem alloc] init];
                            _messageDeletionItem.tag = TGMessageLifetimeTag;
                            _messageDeletionItem.title = TGLocalized(@"Profile.MessageLifetime");
                            _messageDeletionItem.action = @selector(messageLifetimePressed);
                            
                            int messageLifetime = _peerMessageLifetime;
                            if (messageLifetime == 0)
                                _messageDeletionItem.variant = TGLocalized(@"Profile.MessageLifetimeForever");
                            else if (messageLifetime <= 2)
                                _messageDeletionItem.variant = TGLocalized(@"Profile.MessageLifetime2s");
                            else if (messageLifetime <= 5)
                                _messageDeletionItem.variant = TGLocalized(@"Profile.MessageLifetime5s");
                            else if (messageLifetime <= 1 * 60)
                                _messageDeletionItem.variant = TGLocalized(@"Profile.MessageLifetime1m");
                            else if (messageLifetime <= 60 * 60)
                                _messageDeletionItem.variant = TGLocalized(@"Profile.MessageLifetime1h");
                            else if (messageLifetime <= 24 * 60 * 60)
                                _messageDeletionItem.variant = TGLocalized(@"Profile.MessageLifetime1d");
                            else if (messageLifetime <= 7 * 24 * 60 * 60)
                                _messageDeletionItem.variant = TGLocalized(@"Profile.MessageLifetime1w");
                            
                            [_mediaSection.items addObject:_messageDeletionItem];
                            
                            TGVariantMenuItem *keyItem = [[TGVariantMenuItem alloc] init];
                            keyItem.tag = TGKeyItemTag;
                            keyItem.title = TGLocalized(@"Profile.EncryptionKey");
                            keyItem.action = @selector(encryptionKeyPressed);
                            [_mediaSection.items addObject:keyItem];
                            
                            keyItem.variantImage = TGIdenticonImage(hashData, CGSizeMake(24, 24));
                        }
                    }
                    
                }
            }
            
            if (!_tableView.isEditing && _mode != TGProfileControllerModePhonebookContact && _mode != TGProfileControllerModeAddToExistingPhonebookContact && _mode != TGProfileControllerModeCreateNewPhonebookContact)
                [_sectionList addObject:_mediaSection];
            
            if (_deleteSection == nil)
            {
                _deleteSection = [[TGMenuSection alloc] init];
                _deleteSection.tag = TGDeleteSectionTag;
                
                _deleteItem = [[TGButtonMenuItem alloc] initWithTitle:TGLocalized(@"Profile.DeleteContact") subtype:TGButtonMenuItemSubtypeRedButton];
                _deleteItem.action = @selector(deleteButtonPressed);
                [_deleteSection.items addObject:_deleteItem];
                
                _createEncryptedChatItem = [[TGButtonMenuItem alloc] initWithTitle:[[NSString alloc] initWithFormat:@"    %@", TGLocalized(@"Profile.StartEncryptedChat")] subtype:TGButtonMenuItemSubtypeGreenButton];
                _createEncryptedChatItem.titleIcon = [UIImage imageNamed:@"GreenButtonLockIcon.png"];
                _createEncryptedChatItem.action = @selector(createEncryptedChatPressed);
                //[_deleteSection.items addObject:_createEncryptedChatItem];
            }
            
            if ((_mode != TGProfileControllerModeCreateNewContact && _mode != TGProfileControllerModeCreateNewPhonebookContact && _mode != TGProfileControllerModeAddToExistingContact && _mode != TGProfileControllerModeAddToExistingPhonebookContact && _mode != TGProfileControllerModePhonebookContact))
                [_sectionList addObject:_deleteSection];
        }
        
        [self updateActions:false];
    }
         
    if (!self.isViewLoaded)
        return;

    [_tableView reloadData];
}

- (void)clearFirstResponder:(UIView *)v
{
    if (v == nil)
        return;
    
    for (UIView *view in v.subviews)
    {
        if ([view isFirstResponder])
        {
            [view resignFirstResponder];
            return;
        }
        [self clearFirstResponder:view];
    }
}

- (void)scrollToTopRequested
{
    [_tableView setContentOffset:CGPointMake(0, -_tableView.contentInset.top) animated:true];
}

- (void)updateButtons:(UIInterfaceOrientation)__unused orientation
{
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return toInterfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
}

- (BOOL)shouldAutorotate
{
    return true;
}

- (void)controllerInsetUpdated:(UIEdgeInsets)previousInset
{
    if (_ignoreControllerInsetUpdates)
        return;
    
    [super controllerInsetUpdated:previousInset];
    
    for (id cell in _tableView.visibleCells)
    {
        if ([cell isKindOfClass:[TGButtonMenuItemCell class]])
        {
            [cell updateFrame];
        }
    }
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    
    if (_lockView != nil)
    {
        CGRect frame = _lockView.frame;
        frame.origin = CGPointMake(0, UIInterfaceOrientationIsPortrait(self.interfaceOrientation) ? 6 : 4);
        _lockView.frame = frame;
    }
    
    [self updateButtons:toInterfaceOrientation];
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
    
    _isRotating = true;
    _currentTableWidth = [TGViewController screenSizeForInterfaceOrientation:toInterfaceOrientation].width;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    _isRotating = false;
    
    [super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
}

- (void)viewWillAppear:(BOOL)animated
{
    if (_user == nil && _uid != TGTelegraphInstance.clientUserId && _compareVariable == 0 && _mode != TGProfileControllerModePhonebookContact && _mode != TGProfileControllerModeAddToExistingPhonebookContact)
    {
        [_dataTimeoutCondition lock];
        [_dataTimeoutCondition waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.3]];
        [_dataTimeoutCondition unlock];
    }
    
    _currentTableWidth = [TGViewController screenSizeForInterfaceOrientation:self.interfaceOrientation].width;
    
    _appearAnimation = true;
    
    if (_tableView.indexPathForSelectedRow != nil)
        [_tableView deselectRowAtIndexPath:_tableView.indexPathForSelectedRow animated:animated];
    
    [self updateButtons:self.interfaceOrientation];
    
    if (_user != nil && _uid == TGTelegraphInstance.clientUserId)
    {
        [self rejoinActions];
    }
    
    if (_lockView != nil)
    {
        CGRect frame = _lockView.frame;
        frame.origin = CGPointMake(0, UIInterfaceOrientationIsPortrait(self.interfaceOrientation) ? 6 : 4);
        _lockView.frame = frame;
    }
    
    [super viewWillAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    _ignoreControllerInsetUpdates = true;
    
    [super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
    _ignoreControllerInsetUpdates = false;
    
    [super viewDidDisappear:animated];
}

- (void)rejoinActions
{
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        NSArray *deleteActions = [ActionStageInstance() rejoinActionsWithGenericPathNow:@"/tg/timeline/@/deleteAvatar/@" prefix:[[NSString alloc] initWithFormat:@"/tg/timeline/(%d)", _uid] watcher:self];
        NSArray *uploadActions = [ActionStageInstance() rejoinActionsWithGenericPathNow:@"/tg/timeline/@/uploadPhoto/@" prefix:[[NSString alloc] initWithFormat:@"/tg/timeline/(%d)", _uid] watcher:self];
        
        if (deleteActions.count != 0 || uploadActions.count != 0)
        {
            UIImage *uploadingAvatar = nil;
            if (uploadActions.count != 0)
            {
                uploadingAvatar = ((TGTimelineUploadPhotoRequestBuilder *)[ActionStageInstance() executingActorWithPath:uploadActions.lastObject]).currentPhoto;
            }
            
            dispatch_async(dispatch_get_main_queue(), ^
            {
                if (_avatarActivityOverlay.hidden)
                {
                    [self setShowAvatarActivity:true animated:false];
                    
                    if (uploadingAvatar != nil)
                    {
                        [_avatarView loadImage:uploadingAvatar];
                        _avatarView.alpha = 1.0f;
                        _avatarView.hidden = false;
                        
                        _addPhotoButton.hidden = true;
                        _addPhotoButton.alpha = 0.0f;
                    }
                }
            });
        }
        
        NSArray *actions = [ActionStageInstance() rejoinActionsWithGenericPathNow:@"/tg/changeUserName/@" prefix:@"/tg/changeUserName" watcher:self];
        if (actions.count != 0)
        {
            TGChangeNameActor *actor = (TGChangeNameActor *)[ActionStageInstance() executingActorWithPath:[actions lastObject]];
            NSString *firstName = actor.currentFirstName;
            NSString *lastName = actor.currentLastName;
            
            dispatch_async(dispatch_get_main_queue(), ^
            {
                _changingName = true;
                _changingFirstName = firstName;
                _changingLastName = lastName;
                
                if (_firstNameField != nil)
                {
                    _firstNameField.text = firstName;
                    _lastNameField.text = lastName;
                    
                    _firstNameField.enabled = false;
                    _firstNameField.alpha = 0.5f;
                    _lastNameField.enabled = false;
                    _lastNameField.alpha = 0.5f;
                }

                _nameLabel.text = [[NSString alloc] initWithFormat:@"%@ %@", _changingFirstName, _changingLastName];
            });
        }
        
        NSArray *requestActors = [ActionStageInstance() rejoinActionsWithGenericPathNow:@"/tg/contacts/requestActor/@/@" prefix:[NSString stringWithFormat:@"/tg/contacts/requestActor/(%d)/(requestContact)", _uid] watcher:self];
        if (requestActors.count != 0)
        {
            dispatch_async(dispatch_get_main_queue(), ^
            {
                _linkAction = true;
                
                if (self.isViewLoaded)
                    [self updateActions];
            });
        }
    }];
}

- (void)viewDidAppear:(BOOL)animated
{
    _appearAnimation = false;
    
    [super viewDidAppear:animated];
}

#pragma mark -

- (NSInteger)numberOfSectionsInTableView:(UITableView *)__unused tableView
{
    return _sectionList.count;
}

- (NSInteger)tableView:(UITableView *)__unused tableView numberOfRowsInSection:(NSInteger)section
{
    if (section < (int)_sectionList.count)
    {
        TGMenuSection *menuSection = [_sectionList objectAtIndex:section];
        return menuSection.items.count;
    }
    
    return 0;
}

- (CGFloat)tableView:(UITableView *)__unused tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section < (int)_sectionList.count)
    {
        TGMenuSection *section = [_sectionList objectAtIndex:indexPath.section];
        if (indexPath.row < (int)section.items.count)
        {
            TGMenuItem *item = [section.items objectAtIndex:indexPath.row];
         
            switch (item.type)
            {
                case TGActionMenuItemType:
                case TGPhoneItemType:
                case TGSwitchItemType:
                case TGVariantMenuItemType:
                    return 44;
                case TGButtonMenuItemType:
                {
                    if (_encryptedConversationId != 0 && !tableView.editing)
                        return 1;
                    return 45;
                }
                case TGButtonsMenuItemType:
                    return 43;
                case TGContactMediaItemType:
                {
                    return 44;
                }
                case TGWallpapersMenuItemType:
                {
                    return 182;
                }
                case TGCommentMenuItemType:
                    return [(TGCommentMenuItem *)item heightForWidth:_currentTableWidth];
                default:
                    break;
            }
        }
    }
    
    return 0;
}

- (CGFloat)tableView:(UITableView*)__unused tableView heightForHeaderInSection:(NSInteger)__unused section
{
    if (_tableView == tableView)
    {
        TGMenuSection *menuSection = [_sectionList objectAtIndex:section];
        if (section == 0)
        {
            if (menuSection.tag == TGPhonesSectionTag && menuSection.items.count == 0)
                return 2;
                
            return _tableView.isEditing ? (18 + 12) : 12;
        }
        else
        {
            switch (menuSection.tag)
            {
                case TGPhonesSectionTag:
                    return menuSection.items.count == 0 ? 0 : 12;
                case TGMediaSectionTag:
                    return _encryptedConversationId != 0 ? 10 : 28;
                case TGActionsSectionTag:
                    return 10;
                default:
                    break;
            }
        }
    }
    
    return 12;
}

-(CGFloat)tableView:(UITableView*)__unused tableView heightForFooterInSection:(NSInteger)__unused section
{
    TGMenuSection *menuSection = [_sectionList objectAtIndex:section];
    switch (menuSection.tag)
    {
        case TGPhonesSectionTag:
            return 0;
        default:
            break;
    }
    return 1 + (TGIsRetina() ? 0.5f : 1.0f);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    TGMenuItem *item = nil;
    bool firstInSection = false;
    bool lastInSection = false;
    bool clearBackground = false;
    
    if (indexPath.section < (int)_sectionList.count)
    {
        TGMenuSection *section = [_sectionList objectAtIndex:indexPath.section];
        if (indexPath.row < (int)section.items.count)
        {
            item = [section.items objectAtIndex:indexPath.row];
            
            if (indexPath.row == 0)
                firstInSection = true;
            else
            {
                int previousType = ((TGMenuItem *)[section.items objectAtIndex:indexPath.row - 1]).type;
                if (previousType == TGCommentMenuItemType)
                    firstInSection = true;
            }
            
            if (indexPath.row + 1 == (int)section.items.count)
            {
                lastInSection = true;
            }
            else
            {
                int nextType = ((TGMenuItem *)[section.items objectAtIndex:indexPath.row + 1]).type;
                if (nextType == TGCommentMenuItemType)
                    lastInSection = true;
            }
        }
    }
    
    if (item != nil)
    {
        UITableViewCell *cell = nil;
        
        if (item.type == TGActionMenuItemType)
        {
            static NSString *actionItemCellIdentifier = @"AI";
            TGActionMenuItemCell *actionItemCell = (TGActionMenuItemCell *)[tableView dequeueReusableCellWithIdentifier:actionItemCellIdentifier];
            if (actionItemCell == nil)
            {
                actionItemCell = [[TGActionMenuItemCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:actionItemCellIdentifier];
                
                UIImageView *backgroundView = [[UIImageView alloc] init];
                actionItemCell.backgroundView = backgroundView;
                UIImageView *selectedBackgroundView = [[UIImageView alloc] init];
                actionItemCell.selectedBackgroundView = selectedBackgroundView;
            }
            
            TGActionMenuItem *actionItem = (TGActionMenuItem *)item;
            
            actionItemCell.title = actionItem.title;
            
            cell = actionItemCell;
        }
        else if (item.type == TGButtonMenuItemType)
        {
            static NSString *buttonItemCellIdentifier = @"BI";
            TGButtonMenuItemCell *buttonItemCell = (TGButtonMenuItemCell *)[tableView dequeueReusableCellWithIdentifier:buttonItemCellIdentifier];
            if (buttonItemCell == nil)
            {
                buttonItemCell = [[TGButtonMenuItemCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:buttonItemCellIdentifier];
                
                buttonItemCell.selectionStyle = UITableViewCellSelectionStyleNone;
                
                UIImageView *backgroundView = [[UIImageView alloc] init];
                buttonItemCell.backgroundView = backgroundView;
                UIImageView *selectedBackgroundView = [[UIImageView alloc] init];
                buttonItemCell.selectedBackgroundView = selectedBackgroundView;
                
                buttonItemCell.watcherHandle = _actionHandle;
            }
            
            TGButtonMenuItem *buttonItem = (TGButtonMenuItem *)item;
            
            [buttonItemCell setContentHidden:false];
            
            if (_mode != TGProfileControllerModeSelf)
            {
                if (tableView.editing)
                    buttonItem = _deleteItem;
                else
                {
                    buttonItem = _createEncryptedChatItem;
                    if (_encryptedConversationId != 0)
                        [buttonItemCell setContentHidden:true];
                }
            }
            
            buttonItemCell.itemId = buttonItem;
            buttonItemCell.title = buttonItem.title;
            [buttonItemCell setTitleIcon:buttonItem.titleIcon];
            [buttonItemCell setSubtype:buttonItem.subtype];
            [buttonItemCell setEnabled:buttonItem.enabled];
            
            cell = buttonItemCell;
            
            clearBackground = true;
        }
        else if (item.type == TGButtonsMenuItemType)
        {
            static NSString *buttonsItemCellIdentifier = @"BBI";
            TGButtonsMenuItemView *buttonsItemCell = (TGButtonsMenuItemView *)[tableView dequeueReusableCellWithIdentifier:buttonsItemCellIdentifier];
            if (buttonsItemCell == nil)
            {
                buttonsItemCell = [[TGButtonsMenuItemView alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:buttonsItemCellIdentifier];
                
                buttonsItemCell.selectionStyle = UITableViewCellSelectionStyleNone;
                
                UIImageView *backgroundView = [[UIImageView alloc] init];
                buttonsItemCell.backgroundView = backgroundView;
                UIImageView *selectedBackgroundView = [[UIImageView alloc] init];
                buttonsItemCell.selectedBackgroundView = selectedBackgroundView;
                
                buttonsItemCell.watcherHandle = _actionHandle;
            }
            
            TGButtonsMenuItem *buttonsItem = (TGButtonsMenuItem *)item;
            [buttonsItemCell setButtons:buttonsItem.buttons];
            
            cell = buttonsItemCell;
            
            clearBackground = true;
        }
        else if (item.type == TGSwitchItemType)
        {
            static NSString *switchItemCellIdentifier = @"SI";
            TGSwitchItemCell *switchItemCell = (TGSwitchItemCell *)[tableView dequeueReusableCellWithIdentifier:switchItemCellIdentifier];
            if (switchItemCell == nil)
            {
                switchItemCell = [[TGSwitchItemCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:switchItemCellIdentifier];
                
                UIImageView *backgroundView = [[UIImageView alloc] init];
                switchItemCell.backgroundView = backgroundView;
                UIImageView *selectedBackgroundView = [[UIImageView alloc] init];
                switchItemCell.selectedBackgroundView = selectedBackgroundView;
                
                switchItemCell.selectionStyle = UITableViewCellSelectionStyleNone;
                
                switchItemCell.watcherHandle = _actionHandle;
            }
            
            TGSwitchItem *switchItem = (TGSwitchItem *)item;
            
            switchItemCell.title = switchItem.title;
            switchItemCell.isOn = switchItem.isOn;
            
            switchItemCell.itemId = switchItem;
            
            cell = switchItemCell;
        }
        else if (item.type == TGVariantMenuItemType)
        {
            static NSString *variantItemCellIdentifier = @"VI";
            TGVariantMenuItemCell *variantItemCell = (TGVariantMenuItemCell *)[tableView dequeueReusableCellWithIdentifier:variantItemCellIdentifier];
            if (variantItemCell == nil)
            {
                variantItemCell = [[TGVariantMenuItemCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:variantItemCellIdentifier];
                
                UIImageView *backgroundView = [[UIImageView alloc] init];
                variantItemCell.backgroundView = backgroundView;
                UIImageView *selectedBackgroundView = [[UIImageView alloc] init];
                variantItemCell.selectedBackgroundView = selectedBackgroundView;
            }
            
            TGVariantMenuItem *variantItem = (TGVariantMenuItem *)item;
            
            variantItemCell.title = variantItem.title;
            variantItemCell.variant = variantItem.variant;
            [variantItemCell setVariantImage:variantItem.variantImage];
            
            cell = variantItemCell;
        }
        else if (item.type == TGPhoneItemType)
        {
            static NSString *phoneItemCellIdentifier = @"PI";
            TGPhoneItemCell *phoneItemCell = (TGPhoneItemCell *)[tableView dequeueReusableCellWithIdentifier:phoneItemCellIdentifier];
            if (phoneItemCell == nil)
            {
                phoneItemCell = [[TGPhoneItemCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:phoneItemCellIdentifier];
                
                phoneItemCell.backgroundView = [[TGTransitionableImageView alloc] init];
                UIImageView *selectedBackgroundView = [[UIImageView alloc] init];
                phoneItemCell.selectedBackgroundView = selectedBackgroundView;
                
                phoneItemCell.watcherHandle = _actionHandle;
            }
            
            TGPhoneItem *phoneItem = (TGPhoneItem *)item;
            
            phoneItemCell.label = phoneItem.label;
            phoneItemCell.phone = [phoneItem formattedPhone];
            [phoneItemCell setIsMainPhone:phoneItem.highlightMainPhone && phoneItem.isMainPhone];
            [phoneItemCell setDisabled:phoneItem.disabled];
            
            [phoneItemCell resetView];
            
            cell = phoneItemCell;
        }
        else if (item.type == TGContactMediaItemType)
        {
            static NSString *contactMediaItemCellIdentifier = @"MI";
            TGContactMediaItemCell *mediaItemCell = (TGContactMediaItemCell *)[tableView dequeueReusableCellWithIdentifier:contactMediaItemCellIdentifier];
            if (mediaItemCell == nil)
            {
                TGMediaListView *mediaListView = nil;
                mediaItemCell = [[TGContactMediaItemCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:contactMediaItemCellIdentifier mediaListView:mediaListView];
                
                UIImageView *backgroundView = [[UIImageView alloc] init];
                mediaItemCell.backgroundView = backgroundView;
                UIImageView *selectedBackgroundView = [[UIImageView alloc] init];
                mediaItemCell.selectedBackgroundView = selectedBackgroundView;
                
                [mediaItemCell setTitle:TGLocalized(@"Profile.SharedMedia")];
            }
            
            [mediaItemCell setCount:_mediaListTotalCount];
            [mediaItemCell setIsLoading:_mediaListLoading];
            
            cell = mediaItemCell;
        }
        else if (item.type == TGWallpapersMenuItemType)
        {
            static NSString *wallpapersCellIdentifier = @"WWC";
            TGWallpapersMenuItemCell *wallpapersCell = (TGWallpapersMenuItemCell *)[tableView dequeueReusableCellWithIdentifier:wallpapersCellIdentifier];
            if (wallpapersCell == nil)
            {
                wallpapersCell = [[TGWallpapersMenuItemCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:wallpapersCellIdentifier];
                wallpapersCell.watcherHandle = _actionHandle;
            }
            
            return wallpapersCell;
        }
        else if (item.type == TGCommentMenuItemType)
        {
            static NSString *commentItemCellIdentifier = @"CI";
            TGCommentMenuItemView *commentItemCell = (TGCommentMenuItemView *)[tableView dequeueReusableCellWithIdentifier:commentItemCellIdentifier];
            if (commentItemCell == nil)
            {
                commentItemCell = [[TGCommentMenuItemView alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:commentItemCellIdentifier];
                
                commentItemCell.selectionStyle = UITableViewCellSelectionStyleNone;
                commentItemCell.backgroundView = [[UIView alloc] init];
                commentItemCell.selectedBackgroundView = [[UIView alloc] init];
            }
            
            clearBackground = true;
            
            TGCommentMenuItem *commentItem = (TGCommentMenuItem *)item;
            commentItemCell.label = commentItem.comment;
            
            cell = commentItemCell;
        }
        
        if (cell != nil)
        {
            if (!clearBackground)
            {
                updateGroupedCellBackground((TGGroupedCell *)cell, firstInSection, lastInSection, false);
            }
            
            return cell;
        }
    }
    
    static NSString *emptyCellIdentifier = @"EC";
    UITableViewCell *emptyCell = [tableView dequeueReusableCellWithIdentifier:emptyCellIdentifier];
    if (emptyCell == nil)
        emptyCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:emptyCellIdentifier];
    return emptyCell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)__unused indexPath
{
    if (tableView == _tableView)
    {
        if ([cell isKindOfClass:[TGButtonMenuItemCell class]])
        {
            [(TGButtonMenuItemCell *)cell updateFrame];
        }
    }
}

- (void)dismissEditingControls
{
}

- (NSIndexPath *)indexPathForCell:(UITableViewCell *)cell
{
    for (NSIndexPath *indexPath in [_tableView indexPathsForVisibleRows])
    {
        UITableViewCell *tableCell = [_tableView cellForRowAtIndexPath:indexPath];
        
        if (tableCell == cell)
            return indexPath;
    }
    
    return nil;
}

- (void)animateRowDeletion:(NSIndexPath *)indexPath
{
    TGMenuSection *section = [_sectionList objectAtIndex:indexPath.section];
    
    if (indexPath.row == (int)section.items.count - 1)
    {
        UITableViewCell *cell = [_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:indexPath.row - 1 inSection:indexPath.section]];
        if (cell != nil && [cell isKindOfClass:[TGGroupedCell class]])
            updateGroupedCellBackground((TGGroupedCell *)cell, indexPath.row - 1 == 0, true, true);
    }
    
    if (indexPath.row == 0)
    {
        UITableViewCell *cell = [_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:indexPath.row + 1 inSection:indexPath.section]];
        if (cell != nil && [cell isKindOfClass:[TGGroupedCell class]])
            updateGroupedCellBackground((TGGroupedCell *)cell, true, indexPath.row + 1 == (int)section.items.count - 1, true);
    }
    
    [_tableView deleteRowsAtIndexPaths:[[NSArray alloc] initWithObjects:indexPath, nil] withRowAnimation:iosMajorVersion() >= 5 ? UITableViewRowAnimationAutomatic : UITableViewRowAnimationFade];
}

- (void)commitAction:(UITableViewCell *)cell
{
    NSIndexPath *indexPath = [self indexPathForCell:cell];
    if (indexPath == nil)
        return;
    
    TGMenuItem *item = nil;
    TGMenuSection *section = nil;
    if (indexPath.section < (int)_sectionList.count)
    {
        section = [_sectionList objectAtIndex:indexPath.section];
        if (indexPath.row < (int)section.items.count)
            item = [section.items objectAtIndex:indexPath.row];
    }
    
    if (item != nil && item.type == TGPhoneItemType)
    {
        TGPhoneItem *phoneItem = (TGPhoneItem *)item;
        if (phoneItem.phone.length != 0)
        {
            [_tableView beginUpdates];
            
            UITableViewCell *cell = [_tableView cellForRowAtIndexPath:indexPath];
            if (cell != nil && [cell isKindOfClass:[TGPhoneItemCell class]])
            {
                [((TGPhoneItemCell *)cell) fadeOutEditingControls];
            }
            
            [self animateRowDeletion:indexPath];
            [section.items removeObjectAtIndex:indexPath.row];
            
            [_tableView endUpdates];
        }
    }

    for (UITableViewCell *cell in [_tableView visibleCells])
    {
        if ([cell conformsToProtocol:@protocol(TGActionTableViewCell)])
            [(id<TGActionTableViewCell>)cell dismissEditingControls:true];
    }
    
    [self updateDoneButtonState];
}

- (BOOL)tableView:(UITableView *)__unused tableView canEditRowAtIndexPath:(NSIndexPath *)__unused indexPath
{
    return true;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)__unused tableView editingStyleForRowAtIndexPath:(NSIndexPath *)__unused indexPath
{
    return UITableViewCellEditingStyleNone;
}

- (BOOL)tableView:(UITableView *)__unused tableView shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (_mode == TGProfileControllerModeSelf)
        return false;
    
    TGMenuItem *item = nil;
    
    if (indexPath.section < (int)_sectionList.count)
    {
        TGMenuSection *section = [_sectionList objectAtIndex:indexPath.section];
        if (indexPath.row < (int)section.items.count)
        {
            item = [section.items objectAtIndex:indexPath.row];
        }
    }
    
    if (item != nil)
    {
        switch (item.type)
        {
            case TGButtonMenuItemType:
            case TGButtonsMenuItemType:
                return false;
            default:
                break;
        }
        return true;
    }
    
    return false;
}

- (void)tableView:(UITableView *)__unused tableView performAction:(SEL)action forRowAtIndexPath:(NSIndexPath *)indexPath withSender:(id)__unused sender
{
    TGMenuItem *item = nil;
    
    if (indexPath.section < (int)_sectionList.count)
    {
        TGMenuSection *section = [_sectionList objectAtIndex:indexPath.section];
        if (indexPath.row < (int)section.items.count)
        {
            item = [section.items objectAtIndex:indexPath.row];
        }
    }
    
    if (item != nil)
    {
        if (item.type == TGPhoneItemType)
        {
            TGPhoneItem *phoneItem = (TGPhoneItem *)item;
            if (action == @selector(copy:))
            {
                UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
                if (pasteboard != nil && phoneItem.phone != nil)
                {
                    NSString *copyString = [TGStringUtils formatPhoneUrl:phoneItem.phone];
                    [pasteboard setString:copyString];
                }
            }
        }
    }
}

- (BOOL)tableView:(UITableView *)__unused tableView canPerformAction:(SEL)action forRowAtIndexPath:(NSIndexPath *)indexPath withSender:(id)__unused sender
{
    if (_tableView.editing)
        return false;
    
    TGMenuItem *item = nil;
    
    if (indexPath.section < (int)_sectionList.count)
    {
        TGMenuSection *section = [_sectionList objectAtIndex:indexPath.section];
        if (indexPath.row < (int)section.items.count)
        {
            item = [section.items objectAtIndex:indexPath.row];
        }
    }
    
    if (item != nil)
    {
        if (item.type == TGPhoneItemType)
        {
            if (action == @selector(copy:))
                return true;
        }
    }
    
    return false;
}

- (BOOL)tableView:(UITableView *)__unused tableView shouldShowMenuForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (_tableView.editing)
        return false;
    
    TGMenuItem *item = nil;
    
    if (indexPath.section < (int)_sectionList.count)
    {
        TGMenuSection *section = [_sectionList objectAtIndex:indexPath.section];
        if (indexPath.row < (int)section.items.count)
        {
            item = [section.items objectAtIndex:indexPath.row];
        }
    }
    
    if (item != nil)
    {
        if (item.type == TGPhoneItemType)
            return true;
    }
    
    return false;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    TGMenuItem *item = nil;
    
    if (indexPath.section < (int)_sectionList.count)
    {
        TGMenuSection *section = [_sectionList objectAtIndex:indexPath.section];
        if (indexPath.row < (int)section.items.count)
        {
            item = [section.items objectAtIndex:indexPath.row];
        }
    }
    
    if (item != nil)
    {
        if (item.type == TGActionMenuItemType)
        {
            TGActionMenuItem *actionItem = ((TGActionMenuItem *)item);
            if (actionItem.action && [self respondsToSelector:actionItem.action])
            {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                [self performSelector:actionItem.action];
#pragma clang diagnostic pop
            }
        }
        else if (item.type == TGVariantMenuItemType)
        {
            TGVariantMenuItem *variantItem = ((TGVariantMenuItem *)item);
            if (variantItem.action && [self respondsToSelector:variantItem.action])
            {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                [self performSelector:variantItem.action];
#pragma clang diagnostic pop
            }
        }
        else if (item.type == TGSwitchItemType)
        {
            /*TGSwitchItem *switchItem = (TGSwitchItem *)item;
            switchItem.isOn = !switchItem.isOn;
            [(TGSwitchItemCell *)[tableView cellForRowAtIndexPath:indexPath] setIsOn:switchItem.isOn animated:true];
            [(TGSwitchItemCell *)[tableView cellForRowAtIndexPath:indexPath] fireChangeEvent];*/
        }
        else if (item.type == TGPhoneItemType)
        {   
            if (_tableView.editing)
            {
                TGPhoneLabelController *labelController = [[TGPhoneLabelController alloc] initWithSelectedLabel:((TGPhoneItem *)item).label];
                labelController.watcherHandle = _actionHandle;
                TGNavigationController *navigationController = [TGNavigationController navigationControllerWithRootController:labelController blackCorners:false];
                
                [self presentViewController:navigationController animated:true completion:nil];
            }
            else
            {
                [tableView deselectRowAtIndexPath:indexPath animated:true];
                
                TGPhoneItem *phoneItem = ((TGPhoneItem *)item);
                if (phoneItem.phone != nil && phoneItem.phone.length != 0)
                {
                    NSString *telephoneScheme = @"tel:";
                    if (![[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"tel://"]])
                        telephoneScheme = @"facetime:";
                    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@%@", telephoneScheme, [TGStringUtils formatPhoneUrl: phoneItem.phone]]]];
                }
            }
        }
        else if (item.type == TGContactMediaItemType)
        {
            [[TGInterfaceManager instance] navigateToMediaListOfConversation:_encryptedConversationId != 0 ? _encryptedPeerId : _uid];
        }
        else if (item.type == TGWallpapersMenuItemType)
        {
            [self chatBackgroundButtonPressed];
        }
    }
}

#pragma mark -

- (void)avatarTapped:(UITapGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateRecognized)
    {
        if (_avatarActivityOverlay.alpha < 1.0 - FLT_EPSILON)
            [self addPhotoButtonPressed];
        else
            [self avatarActivityOverlayTapped:recognizer];
    }
}

- (void)avatarActivityOverlayTapped:(UITapGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateRecognized)
    {
        if (_avatarActivityOverlay.alpha < 1.0 - FLT_EPSILON)
            return;
        
        if (_uid > 0 && _mode == TGProfileControllerModeSelf)
        {
            _currentActionSheet.delegate = nil;
            
            NSMutableDictionary *actionSheetMapping = [[NSMutableDictionary alloc] init];
            
            _currentActionSheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
            _currentActionSheet.tag = TGPhotoProgressActionSheetTag;
            _currentActionSheet.destructiveButtonIndex = [_currentActionSheet addButtonWithTitle:TGLocalized(@"Profile.StopImageUpload")];
            [actionSheetMapping setObject:@"stop" forKey:[[NSNumber alloc] initWithInt:_currentActionSheet.destructiveButtonIndex]];
            _currentActionSheet.cancelButtonIndex = [_currentActionSheet addButtonWithTitle:NSLocalizedString(@"Common.Cancel", nil)];
            if ([self.parentViewController isKindOfClass:[UITabBarController class]])
                [_currentActionSheet showInView:self.parentViewController.view];
            else
                [_currentActionSheet showInView:self.view];
            
            _currentActionSheetMapping = actionSheetMapping;
        }
    }
}

- (void)addPhotoButtonPressed
{
    if (_avatarActivityOverlay.alpha > FLT_EPSILON)
        return;
    
    if (_uid > 0)
    {
        if (_mode == TGProfileControllerModeSelf)
        {
            if (_avatarView.currentUrl.length == 0)
            {
                [self showCamera];
            }
            else
            {
                [self actionStageActionRequested:@"openAllPhotos" options:nil];
            }
        }
        else if (!_tableView.editing)
        {
            [self actionStageActionRequested:@"openAllPhotos" options:nil];
        }
    }
}

- (void)logoutButtonPressed
{
    _currentActionSheet.delegate = nil;
    
    _currentActionSheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:TGLocalized(@"Common.Cancel") destructiveButtonTitle:TGLocalized(@"Settings.Logout") otherButtonTitles: nil];
    _currentActionSheet.tag = TGLogoutConfirmationActionSheetTag;
    if ([self.parentViewController isKindOfClass:[UITabBarController class]])
        [_currentActionSheet showInView:self.parentViewController.view];
    else
        [_currentActionSheet showInView:self.view];
}

- (void)customSoundPressed
{
    if ([_tableView indexPathForSelectedRow] != nil)
        [_tableView deselectRowAtIndexPath:[_tableView indexPathForSelectedRow] animated:true];
    
    TGCustomNotificationController *soundController = [[TGCustomNotificationController alloc] initWithMode:TGCustomNotificationControllerModeUser];
    soundController.watcherHandle = _actionHandle;
    soundController.selectedIndex = [[_peerNotificationSettings objectForKey:@"soundId"] intValue];
    TGNavigationController *navigationController = [TGNavigationController navigationControllerWithRootController:soundController blackCorners:false];
    
    [self presentViewController:navigationController animated:true completion:nil];
}

- (void)changePhotoButtonPressed
{
    [self showCamera];
}

- (void)showCamera
{
#if TG_USE_CUSTOM_CAMERA
    _cameraWindow = [[TGCameraWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    _cameraWindow.watcherHandle = _actionHandle;
    [_cameraWindow show];
#else
    if (_currentActionSheet != nil)
        _currentActionSheet.delegate = nil;
    
    _currentActionSheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
    _currentActionSheet.tag = TGImageSourceActionSheetTag;
    [_currentActionSheet addButtonWithTitle:TGLocalized(@"Common.TakePhoto")];
    [_currentActionSheet addButtonWithTitle:TGLocalized(@"Common.ChoosePhoto")];
    [_currentActionSheet addButtonWithTitle:TGLocalized(@"Conversation.SearchWebImages")];
    _currentActionSheet.cancelButtonIndex = [_currentActionSheet addButtonWithTitle:NSLocalizedString(@"Common.Cancel", nil)];
    [_currentActionSheet showInView:self.parentViewController.view];
#endif
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    _currentActionSheet.delegate = nil;
    _currentActionSheet = nil;
    
    if (actionSheet.tag == TGAddPhotoActionSheetTag)
    {
        NSString *action = [_currentActionSheetMapping objectForKey:[[NSNumber alloc] initWithInt:buttonIndex]];
        if ([action isEqualToString:@"allPhotos"])
        {
            [self actionStageActionRequested:@"openAllPhotos" options:nil];
            
            //[[TGInterfaceManager instance] navigateToTimelineOfUser:_uid];
        }
        else if ([action isEqualToString:@"updatePhoto"])
        {
            [self showCamera];
            
            //[ActionStageInstance() requestActor:@"/tg/location/current/(100)" options:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:100] forKey:@"precisionMeters"] watcher:self];
        }
        else if ([action isEqualToString:@"deletePhoto"])
        {
            [self actionStageActionRequested:@"deleteAvatar" options:nil];
        }
    }
    else if (actionSheet.tag == TGLogoutConfirmationActionSheetTag)
    {
        if (buttonIndex == actionSheet.destructiveButtonIndex)
        {
            [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/auth/logout/(%d)", TGTelegraphInstance.clientUserId] options:nil watcher:self];
            
            _progressWindow = [[TGProgressWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
            [_progressWindow show:true];
        }
    }
    else if (actionSheet.tag == TGPhotoProgressActionSheetTag)
    {
        if (buttonIndex == actionSheet.destructiveButtonIndex)
        {
            [self setShowAvatarActivity:false animated:false];
            [self updateTitle:false];
            
            int uid = _uid;
            [ActionStageInstance() dispatchOnStageQueue:^
            {
                NSArray *deleteActions = [ActionStageInstance() rejoinActionsWithGenericPathNow:@"/tg/timeline/@/deleteAvatar/@" prefix:[[NSString alloc] initWithFormat:@"/tg/timeline/(%d)", uid] watcher:self];
                NSArray *uploadActions = [ActionStageInstance() rejoinActionsWithGenericPathNow:@"/tg/timeline/@/uploadPhoto/@" prefix:[[NSString alloc] initWithFormat:@"/tg/timeline/(%d)", uid] watcher:self];

                for (NSString *action in deleteActions)
                {
                    [ActionStageInstance() removeAllWatchersFromPath:action];
                }
                
                for (NSString *action in uploadActions)
                {
                    [ActionStageInstance() removeAllWatchersFromPath:action];
                }
            }];
        }
    }
    else if (actionSheet.tag == TGDeleteContactActionSheetTag)
    {
        if (buttonIndex == actionSheet.destructiveButtonIndex)
        {
            [self deleteContact];
        }
    }
    else if (actionSheet.tag == TGAddContactActionSheetTag)
    {
        if (buttonIndex != actionSheet.cancelButtonIndex)
        {
            NSString *action = [_currentActionSheetMapping objectForKey:[[NSNumber alloc] initWithInt:buttonIndex]];
            if ([action isEqualToString:@"createNewContact"])
            {
                TGProfileController *createContactController = [[TGProfileController alloc] initWithCreateNewContact:_user watcherHandle:_actionHandle];
                
                TGNavigationController *navigationController = [TGNavigationController navigationControllerWithRootController:createContactController blackCorners:false];
                
                [self presentViewController:navigationController animated:true completion:nil];
            }
            else if ([action isEqualToString:@"addToExistingContact"])
            {
                TGSelectExistingContactController *contactsController = [[TGSelectExistingContactController alloc] initWithPhoneNumber:_user.phoneNumber uid:_user.uid];
                contactsController.watcherHandle = _actionHandle;
                
                TGNavigationController *navigationController = [TGNavigationController navigationControllerWithRootController:contactsController blackCorners:false];
                
                [self presentViewController:navigationController animated:true completion:nil];
            }
        }
    }
    else if (actionSheet.tag == TGInvitePhonesActionSheetTag)
    {
        if (buttonIndex != actionSheet.cancelButtonIndex)
        {
            NSString *phoneNumber = [_currentActionSheetMapping objectForKey:[[NSNumber alloc] initWithInt:buttonIndex]];
            [self inviteByPhone:phoneNumber];
        }
    }
    else if (actionSheet.tag == TGImageSourceActionSheetTag)
    {
        if (buttonIndex == 0 || buttonIndex == 1 || buttonIndex == 2)
        {
            if (buttonIndex == 0 && ![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera])
                return;
            
            [self.view endEditing:true];
            
            _currentImagePickerTarget = 0;
            
            if (buttonIndex == 0)
            {
                UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
                imagePicker.sourceType = UIImagePickerControllerSourceTypeCamera;
                imagePicker.allowsEditing = true;
                imagePicker.delegate = self;
                
                [(TGApplication *)[UIApplication sharedApplication] setProcessStatusBarHiddenRequests:true];
                
                [self presentViewController:imagePicker animated:true completion:nil];
            }
            else
            {
                NSMutableArray *viewControllers = [[NSMutableArray alloc] init];
                
                TGImageSearchController *searchController = [[TGImageSearchController alloc] initWithAvatarSelection:true];
                searchController.autoActivateSearch = buttonIndex == 2;
                searchController.delegate = self;
                [viewControllers addObject:searchController];
                
                if (buttonIndex == 1)
                {
                    TGImagePickerController *imagePicker = [[TGImagePickerController alloc] initWithGroupUrl:nil groupTitle:nil avatarSelection:true];
                    imagePicker.delegate = self;
                    [viewControllers addObject:imagePicker];
                }
                
                UIViewController *topViewController = [viewControllers lastObject];
                
                [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackTranslucent animated:true];
                
                TGNavigationController *navigationController = [TGNavigationController navigationControllerWithControllers:viewControllers];
                navigationController.restrictLandscape = true;
                
                [topViewController view];
                
                [TGViewController disableUserInteractionFor:0.2];
                TGDispatchAfter([TGViewController isWidescreen] ? 0 : 0.2, dispatch_get_main_queue(), ^
                {
                    if (iosMajorVersion() <= 5)
                    {
                        [TGViewController disableAutorotationFor:0.45];
                        [topViewController view];
                        [topViewController viewWillAppear:false];
                        
                        CGSize screenSize = [TGViewController screenSizeForInterfaceOrientation:self.interfaceOrientation];
                        navigationController.view.frame = CGRectMake(0, screenSize.height, screenSize.width, screenSize.height);
                        [self.navigationController.view addSubview:navigationController.view];
                        
                        [UIView animateWithDuration:0.45 animations:^
                        {
                            navigationController.view.frame = CGRectMake(0, 0, screenSize.width, screenSize.height);
                        } completion:^(BOOL finished)
                        {
                            [navigationController.view removeFromSuperview];
                            if (finished)
                            {
                                [topViewController viewWillDisappear:false];
                                [topViewController viewDidDisappear:false];
                                [self presentViewController:navigationController animated:false completion:nil];
                            }
                        }];
                    }
                    else
                    {
                        [self presentViewController:navigationController animated:true completion:nil];
                    }
                });
            }
        }
    }
    else if (actionSheet.tag == TGMessageLifetimeActionSheetTag)
    {
        if (buttonIndex != actionSheet.cancelButtonIndex)
        {
            int lifetimeVariants[] = {
                0,
                2,
                5,
                1 * 60,
                60 * 60,
                24 * 60 * 60,
                7 * 24 * 60 * 60
            };
            
            int messageLifetime = (buttonIndex >= 0 && buttonIndex < (int)(sizeof(lifetimeVariants) / sizeof(lifetimeVariants[0]))) ? lifetimeVariants[buttonIndex] : 0;
            _peerMessageLifetime = messageLifetime;
            
            [TGDatabaseInstance() setMessageLifetimeForPeerId:_encryptedPeerId encryptedConversationId:_encryptedConversationId messageLifetime:messageLifetime writeToActionQueue:true];
            [ActionStageInstance() requestActor:@"/tg/service/synchronizeserviceactions/(settings)" options:nil watcher:TGTelegraphInstance];
            
            [self updateNotificationSettingsItems:false];
        }
    }
}

- (void)imagePickerController:(TGImagePickerController *)__unused imagePicker didFinishPickingWithAssets:(NSArray *)assets
{
    if (assets.count != 0)
    {
        for (id object in assets)
        {
            if ([object isKindOfClass:[UIImage class]])
            {
                if (_currentImagePickerTarget == 0)
                {
                    [self _updateProfileImage:object];
                }
            }
        }
        
        [self dismissViewControllerAnimated:true completion:nil];
        
        [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackOpaque animated:true];
    }
    else
    {
        [self dismissViewControllerAnimated:true completion:nil];
        
        [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackOpaque animated:true];
    }
}

- (void)_updateProfileImage:(UIImage *)image
{
    NSData *imageData = UIImageJPEGRepresentation(image, 0.5f);
    if (imageData == nil)
        return;
    
    TGImageProcessor filter = [TGRemoteImageView imageProcessorForName:@"profileAvatar"];
    UIImage *toImage = filter(image);
    
    _avatarView.hidden = false;
    _avatarView.alpha = 1.0f;
    _addPhotoButton.hidden = true;
    _addPhotoButton.alpha = 0.0f;
    [_avatarView loadImage:toImage];
    _avatarView.currentFilter = @"profileAvatar";
    [self setShowAvatarActivity:true animated:true];
    
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        bool hasLocation = false;
        double locationLatitude = 0.0;
        double locationLongitude = 0.0;
        [TGLocationRequestActor currentLocation:&hasLocation latitude:&locationLatitude longitude:&locationLongitude];
        [ActionStageInstance() removeWatcher:self fromPath:@"/tg/location/current/(100)"];
        
        NSMutableDictionary *options = [[NSMutableDictionary alloc] init];
        
        uint8_t fileId[32];
        arc4random_buf(&fileId, 32);
        
        NSMutableString *filePath = [[NSMutableString alloc] init];
        for (int i = 0; i < 32; i++)
        {
            [filePath appendFormat:@"%02x", fileId[i]];
        }
        
        NSString *tmpImagesPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true) objectAtIndex:0] stringByAppendingPathComponent:@"upload"];
        static NSFileManager *fileManager = nil;
        if (fileManager == nil)
            fileManager = [[NSFileManager alloc] init];
        NSError *error = nil;
        [fileManager createDirectoryAtPath:tmpImagesPath withIntermediateDirectories:true attributes:nil error:&error];
        NSString *absoluteFilePath = [tmpImagesPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.bin", filePath]];
        [imageData writeToFile:absoluteFilePath atomically:false];
        
        [options setObject:filePath forKey:@"originalFileUrl"];
        
        if (hasLocation)
        {
            [options setObject:[NSNumber numberWithDouble:locationLatitude] forKey:@"latitude"];
            [options setObject:[NSNumber numberWithDouble:locationLongitude] forKey:@"longitude"];
        }
        
        [options setObject:toImage forKey:@"currentPhoto"];
        
        NSString *action = [[NSString alloc] initWithFormat:@"/tg/timeline/(%d)/uploadPhoto/(%@)", _uid, filePath];
        [ActionStageInstance() requestActor:action options:options watcher:self];
        [ActionStageInstance() requestActor:action options:options watcher:TGTelegraphInstance];
    }];
}

- (void)imagePickerController:(UIImagePickerController *)__unused picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    [self dismissViewControllerAnimated:true completion:nil];
    
    [(TGApplication *)[UIApplication sharedApplication] setProcessStatusBarHiddenRequests:false];
    
    if (_currentImagePickerTarget == 0)
    {
        CGRect cropRect = [[info objectForKey:UIImagePickerControllerCropRect] CGRectValue];
        if (ABS(cropRect.size.width - cropRect.size.height) > FLT_EPSILON)
        {
            if (cropRect.size.width < cropRect.size.height)
            {
                cropRect.origin.x -= (cropRect.size.height - cropRect.size.width) / 2;
                cropRect.size.width = cropRect.size.height;
            }
            else
            {
                cropRect.origin.y -= (cropRect.size.width - cropRect.size.height) / 2;
                cropRect.size.height = cropRect.size.width;
            }
        }
        
        UIImage *image = TGFixOrientationAndCrop([info objectForKey:UIImagePickerControllerOriginalImage], cropRect, CGSizeMake(600, 600));

        [self _updateProfileImage:image];
    }
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)__unused picker
{
    [self dismissViewControllerAnimated:true completion:nil];
    
    [(TGApplication *)[UIApplication sharedApplication] setProcessStatusBarHiddenRequests:false];
}

- (void)tableViewSwiped:(UISwipeGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateRecognized)
    {
        if (recognizer.direction == UISwipeGestureRecognizerDirectionRight)
        {
            if ([self.navigationController.viewControllers objectAtIndex:0] != self)
                [self performCloseProfile];
        }
    }
}

- (void)notificationsButtonPressed
{
    TGNotificationSettingsController *notificationSettingsController = [[TGNotificationSettingsController alloc] init];
    [self.navigationController pushViewController:notificationSettingsController animated:true];
}

- (void)chatSettingsButtonPressed
{
    [self.navigationController pushViewController:[[TGChatSettingsController alloc] init] animated:true];
}

- (void)supportButtonPressed
{
    int uid = [TGTelegraphInstance createServiceUserIfNeeded];
    [[TGInterfaceManager instance] navigateToConversationWithId:uid conversation:nil forwardMessages:nil atMessageId:0 clearStack:true openKeyboard:true animated:true];
}

- (void)privacyButtonPressed
{
    TGPrivacySettingsController *privacySettingsController = [[TGPrivacySettingsController alloc] init];
    [self.navigationController pushViewController:privacySettingsController animated:true];
}

- (void)blockedUsersButtonPressed
{
    TGBlockedUsersController *blockedUsersController = [[TGBlockedUsersController alloc] init];
    [self.navigationController pushViewController:blockedUsersController animated:true];
}

- (void)chatBackgroundButtonPressed
{
    TGWallpaperStoreController *wallpaperStoreController = [[TGWallpaperStoreController alloc] init];
    [self.navigationController pushViewController:wallpaperStoreController animated:true];
}

- (void)focusOnFirstNameField:(UITapGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateRecognized && !_firstNameField.isFirstResponder)
    {
        [_firstNameField becomeFirstResponder];
    }
}

- (void)focusOnLastNameField:(UITapGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateRecognized && !_lastNameField.isFirstResponder)
    {
        [_lastNameField becomeFirstResponder];
    }
}

- (BOOL)textFieldShouldClear:(UITextField *)textField
{
    textField.text = @"";
    
    [self updateDoneButtonState];
    
    return false;
}



- (BOOL)textField:(UITextField *)__unused textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)rawString
{
    if (range.location + MAX(0, (int)rawString.length - (int)range.length) > 256)
        return false;
    
    dispatch_async(dispatch_get_main_queue(), ^
    {
        [self updateDoneButtonState];
    });
    
    return true;
    
    /*NSString *string = rawString;//[[rawString componentsSeparatedByCharactersInSet:[[NSCharacterSet alphanumericCharacterSet] invertedSet]] componentsJoinedByString:@""];
    
    NSString *newText = [textField.text stringByReplacingCharactersInRange:range withString:string];
    
    if ((int)newText.length > 256)
        newText = [newText substringToIndex:256];
    
    textField.text = newText;
    
    int stringLength = string.length;
    int caretPosition = range.location + stringLength;
    
    if (caretPosition > (int)newText.length)
        caretPosition = newText.length;
    
    caretPosition = [newText lengthByComposedCharacterSequencesInRange:NSMakeRange(0, caretPosition)];
    
    UITextPosition *startPosition = [textField positionFromPosition:textField.beginningOfDocument offset:caretPosition];
    UITextPosition *endPosition = [textField positionFromPosition:textField.beginningOfDocument offset:caretPosition];
    if (startPosition != nil && endPosition != nil)
    {
        UITextRange *selection = [textField textRangeFromPosition:startPosition toPosition:endPosition];
        if (selection != nil)
            textField.selectedTextRange = selection;
    }
    
    [self updateDoneButtonState];*/
    
    return false;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (textField == _firstNameField)
    {
        [_lastNameField becomeFirstResponder];
        
        return false;
    }
    else if (textField == _lastNameField)
    {
        //[self editingDoneButtonPressed];
        
        [self clearFirstResponder:self.view];
        dispatch_async(dispatch_get_main_queue(), ^
        {
            for (UITableViewCell *cell in _tableView.visibleCells)
            {
                if ([cell isKindOfClass:[TGButtonMenuItemCell class]])
                    [cell setFrame:cell.frame];
            }
        });
        
        return false;
    }
    
    return true;
}

- (void)textFieldDidBeginEditing:(UITextField *)__unused textField
{
    if (!_showingEditingControls)
        [self updateNavigationButtons:true animated:true];
}

#pragma mark -

- (TGMenuSection *)findSection:(int)tag sectionIndex:(int *)sectionIndex
{
    int iSection = -1;
    for (TGMenuSection *section in _sectionList)
    {
        iSection++;
        
        if (section.tag == tag)
        {
            if (sectionIndex)
                *sectionIndex = iSection;
            return section;
        }
    }
    
    return nil;
}

- (TGMenuItem *)findMenuItem:(int)tag sectionIndex:(int *)sectionIndex itemIndex:(int *)itemIndex
{
    int iSection = -1;
    for (TGMenuSection *section in _sectionList)
    {
        iSection++;
        
        int iItem = -1;
        for (TGMenuItem *item in section.items)
        {
            iItem++;
            
            if (item.tag == tag)
            {
                if (sectionIndex)
                    *sectionIndex = iSection;
                if (itemIndex)
                    *itemIndex = iItem;
                return item;
            }
        }
    }
    
    return nil;
}

- (void)actionStageResourceDispatched:(NSString *)path resource:(id)resource arguments:(id)__unused arguments
{
    if ([path isEqualToString:@"/tg/userdatachanges"])
    {
        if (_ignoreAllUpdates || _uid == 0)
            return;
        
        NSArray *users = ((SGraphObjectNode *)resource).object;
        TGUser *selectedUser = nil;
        for (TGUser *user in users)
        {
            if (user.uid == _uid)
            {
                selectedUser = user;
                break;
            }
        }
        
        if (selectedUser != nil)
        {
            TGPhonebookContact *phonebookContact = nil;
            if (selectedUser.contactId != 0)
            {
                if (_preferNativeContactId != 0)
                {
                    TGPhonebookContact *candidateContact = [TGDatabaseInstance() phonebookContactByNativeId:_preferNativeContactId];
                    if ([candidateContact containsPhoneId:selectedUser.contactId])
                        phonebookContact = candidateContact;
                }
                if (phonebookContact == nil)
                    phonebookContact = [TGDatabaseInstance() phonebookContactByPhoneId:selectedUser.contactId];
            }
            
            dispatch_async(dispatch_get_main_queue(), ^
            {
                bool updateTable = false;
                int difference = [selectedUser differenceFromUser:_user];
                if (difference & TGUserFieldPhoneNumber)
                    updateTable = true;
                
                self.user = selectedUser;
                _phonebookContact = phonebookContact;
                [self updateTitle:true];
                if (updateTable)
                    [self updateTable];
            });
        }
    }
    else if ([path isEqualToString:@"/tg/userpresencechanges"])
    {
        if (_ignoreAllUpdates)
            return;
        
        NSArray *users = ((SGraphObjectNode *)resource).object;
        TGUser *selectedUser = nil;
        for (TGUser *user in users)
        {
            if (user.uid == _uid)
            {
                selectedUser = user;
                break;
            }
        }
        
        if (selectedUser != nil)
        {
            dispatch_async(dispatch_get_main_queue(), ^
            {
                self.user = selectedUser;
                [self updateTitle:true];
            });
        }
    }
    else if ([path hasPrefix:@"/tg/contactlist"] || [path hasPrefix:@"/tg/phonebook"])
    {
        if (_ignoreAllUpdates)
            return;
        
        TGPhonebookContact *phonebookContact = nil;
        
        if (_mode == TGProfileControllerModePhonebookContact || _mode == TGProfileControllerModeAddToExistingPhonebookContact)
        {
            phonebookContact = [TGDatabaseInstance() phonebookContactByNativeId:_phonebookContact.nativeId];
        }
        else
        {
            TGUser *myUser = [TGDatabaseInstance() loadUser:_uid];
            if (myUser.contactId != 0)
            {
                if (_preferNativeContactId != 0)
                {
                    TGPhonebookContact *candidateContact = [TGDatabaseInstance() phonebookContactByNativeId:_preferNativeContactId];
                    if ([candidateContact containsPhoneId:myUser.contactId])
                        phonebookContact = candidateContact;
                }
                if (phonebookContact == nil)
                    phonebookContact = [TGDatabaseInstance() phonebookContactByPhoneId:myUser.contactId];
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^
        {
            if ((_mode == TGProfileControllerModePhonebookContact || _mode == TGProfileControllerModeAddToExistingPhonebookContact) && phonebookContact == nil)
            {
                [self.navigationController popViewControllerAnimated:false];
                
                return;
            }
                
            if ((phonebookContact != nil) != (_phonebookContact != nil) || (_phonebookContact != nil && ![_phonebookContact isEqualToPhonebookContact:phonebookContact]))
            {
                bool hadNoContact = _phonebookContact == nil;
                _phonebookContact = phonebookContact;
                [self updateActions];
                
                NSMutableArray *currentPhones = [[NSMutableArray alloc] init];
                for (TGPhoneItem *phoneItem in _phonesSection.items)
                {
                    NSString *phoneNumber = [TGStringUtils cleanPhone:phoneItem.phone];
                    if (phoneNumber != 0)
                        [currentPhones addObject:[[TGPhoneNumber alloc] initWithLabel:phoneItem.label number:phoneNumber]];
                }
                
                if (hadNoContact || ![phonebookContact hasEqualPhonesFuzzy:currentPhones])
                    [self updateTable];
                
                if (_mode == TGProfileControllerModePhonebookContact || _mode == TGProfileControllerModeAddToExistingPhonebookContact)
                    [self updateTitle:false];
            }
        });
    }
    else if ([path hasPrefix:@"/tg/userLink/"])
    {
        if (_ignoreAllUpdates)
            return;
        
        [self actorCompleted:ASStatusSuccess path:path result:resource];
    }
    else if ([path hasPrefix:[NSString stringWithFormat:@"/tg/peerSettings/(%d", _uid]])
    {
        if (_ignoreAllUpdates)
            return;
        
        [self actorCompleted:ASStatusSuccess path:path result:resource];
    }
    else if ([path isEqualToString:@"/tg/service/synchronizationstate"])
    {
        if (_ignoreAllUpdates)
            return;
        
        [self actorCompleted:ASStatusSuccess path:path result:resource];
    }
    else if (_encryptedConversationId != 0 && [path isEqualToString:[[NSString alloc] initWithFormat:@"/tg/conversation/(%lld)/conversation", _encryptedPeerId]])
    {
        int64_t keyId = 0;
        NSData *keyData = [TGDatabaseInstance() encryptionKeyForConversationId:[TGDatabaseInstance() peerIdForEncryptedConversationId:_encryptedConversationId] keyFingerprint:&keyId];
        if (keyData != nil)
        {
            dispatch_async(dispatch_get_main_queue(), ^
            {
                int section = 0;
                int index = 0;
                TGVariantMenuItem *keyItem = (TGVariantMenuItem *)[self findMenuItem:TGKeyItemTag sectionIndex:&section itemIndex:&index];
                
                bool encryptionCancelled = [TGDatabaseInstance() loadConversationWithId:[TGDatabaseInstance() peerIdForEncryptedConversationId:_encryptedConversationId]].encryptedData.handshakeState == 3;
                
                bool reloadData = false;
                
                if (_encryptedKeyId != keyId || _encryptionCancelled != encryptionCancelled)
                {
                    _encryptedKeyId = keyId;
                    _encryptionCancelled = encryptionCancelled;
                    
                    if (keyData != nil)
                    {
                        NSData *hashData = computeSHA1(keyData);
                        if (hashData != nil)
                        {
                            if (keyItem == nil)
                            {
                                _messageDeletionItem = [[TGVariantMenuItem alloc] init];
                                _messageDeletionItem.tag = TGMessageLifetimeTag;
                                _messageDeletionItem.title = TGLocalized(@"Profile.MessageLifetime");
                                _messageDeletionItem.action = @selector(messageLifetimePressed);
                                
                                int messageLifetime = _peerMessageLifetime;
                                if (messageLifetime == 0)
                                    _messageDeletionItem.variant = TGLocalized(@"Profile.MessageLifetimeForever");
                                else if (messageLifetime <= 2)
                                    _messageDeletionItem.variant = TGLocalized(@"Profile.MessageLifetime2s");
                                else if (messageLifetime <= 5)
                                    _messageDeletionItem.variant = TGLocalized(@"Profile.MessageLifetime5s");
                                else if (messageLifetime <= 1 * 60)
                                    _messageDeletionItem.variant = TGLocalized(@"Profile.MessageLifetime1m");
                                else if (messageLifetime <= 60 * 60)
                                    _messageDeletionItem.variant = TGLocalized(@"Profile.MessageLifetime1h");
                                else if (messageLifetime <= 24 * 60 * 60)
                                    _messageDeletionItem.variant = TGLocalized(@"Profile.MessageLifetime1d");
                                else if (messageLifetime <= 7 * 24 * 60 * 60)
                                    _messageDeletionItem.variant = TGLocalized(@"Profile.MessageLifetime1w");
                                
                                [_mediaSection.items addObject:_messageDeletionItem];
                                
                                keyItem = [[TGVariantMenuItem alloc] init];
                                keyItem.tag = TGKeyItemTag;
                                keyItem.title = TGLocalized(@"Profile.EncryptionKey");
                                keyItem.action = @selector(encryptionKeyPressed);
                                [_mediaSection.items addObject:keyItem];
                                
                                reloadData = true;
                            }
                            
                            keyItem.variantImage = TGIdenticonImage(hashData, CGSizeMake(24, 24));
                        }
                    }
                    else
                        keyItem.variantImage = nil;
                    
                    TGVariantMenuItemCell *variantCell = (TGVariantMenuItemCell *)[_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:section]];
                    if ([variantCell isKindOfClass:[TGVariantMenuItemCell class]])
                    {
                        [variantCell setVariant:keyItem.variant];
                        [variantCell setVariantImage:keyItem.variantImage];
                    }
                    
                    if (reloadData)
                        [_tableView reloadData];
                }
            });
        }
    }
    else if ([path hasPrefix:@"/tg/encrypted/messageLifetime/"])
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            _peerMessageLifetime = [resource intValue];
            
            [self updateNotificationSettingsItems:false];
        });
    }
}

- (void)actorCompleted:(int)resultCode path:(NSString *)path result:(id)__unused result
{
    if ([path isEqualToString:[NSString stringWithFormat:@"/tg/users/(%d)", _uid]])
    {
        OSAtomicIncrement32(&_compareVariable);
        [_dataTimeoutCondition lock];
        [_dataTimeoutCondition signal];
        [_dataTimeoutCondition unlock];
        
        TGUser *user = nil;
        if (resultCode == ASStatusSuccess)
            user = ((TGUserNode *)result).user;
        
        int userLink = [TGDatabaseInstance() loadUserLink:_uid outdated:NULL];
        if (userLink == 0 && [TGDatabaseInstance() uidIsRemoteContact:_uid])
            userLink = TGUserLinkKnown | TGUserLinkMyContact;
        
        TGPhonebookContact *phonebookContact = nil;
        if (user.contactId != 0)
        {
            if (_preferNativeContactId != 0)
            {
                TGPhonebookContact *candidateContact = [TGDatabaseInstance() phonebookContactByNativeId:_preferNativeContactId];
                if ([candidateContact containsPhoneId:user.contactId])
                    phonebookContact = candidateContact;
            }
            if (phonebookContact == nil)
                phonebookContact = [TGDatabaseInstance() phonebookContactByPhoneId:user.contactId];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^
        {
            _user = user;
            _phonebookContact = phonebookContact;
            
            _userLink = userLink;
            if (_uid == TGTelegraphInstance.clientUserId)
                self.mode = TGProfileControllerModeSelf;
            else
                self.mode = TGProfileControllerModeTelegraphUser;
            
            if (resultCode == ASStatusSuccess && _mode != TGProfileControllerModeSelf)
            {
                _mediaListLoading = true;
                [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/conversations/(%lld)/mediahistory/(0)", _encryptedConversationId != 0 ? _encryptedPeerId : (int64_t)_uid] options:[[NSDictionary alloc] initWithObjectsAndKeys:[NSNumber numberWithInt:5], @"limit", @(_encryptedConversationId != 0), @"isEncrypted", nil] watcher:self];
            }
            
            [self updateTitle:false];
            [self updateTable];
            
            self.userLink = userLink;
            
            if (_mode != TGProfileControllerModeSelf)
            {
                [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/completeUsers/(%d,cached)", _uid] options:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:_uid] forKey:@"uid"] watcher:TGTelegraphInstance];
                [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/peerSettings/(%d,cached)", _uid] options:[NSDictionary dictionaryWithObject:[NSNumber numberWithLongLong:_uid] forKey:@"peerId"] watcher:self];
            }
        });
        
        [self rejoinActions];
    }
    else if ([path isEqualToString:[[NSString alloc] initWithFormat:@"/tg/userLink/(%d)", _uid]])
    {
        int userLink = [((SGraphObjectNode *)result).object intValue];
        dispatch_async(dispatch_get_main_queue(), ^
        {
            if (_userLink != userLink)
            {
                [self setUserLink:userLink animated:true];
            }
        });
    }
    else if ([path hasPrefix:[NSString stringWithFormat:@"/tg/conversations/(%lld)/mediahistory/", _encryptedConversationId != 0 ? _encryptedPeerId : (int64_t)_uid]])
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            _mediaListLoading = false;
            
            if (resultCode == ASStatusSuccess)
            {
                NSDictionary *dict = ((SGraphObjectNode *)result).object;
                
                _mediaListTotalCount = [[dict objectForKey:@"count"] intValue];
            }
            
            int sectionIndex = -1;
            for (TGMenuSection *section in _sectionList)
            {
                sectionIndex++;
                
                int itemIndex = -1;
                for (TGMenuItem *item in section.items)
                {
                    itemIndex++;
                    
                    if (item.type == TGContactMediaItemType)
                    {
                        TGContactMediaItemCell *cell = (TGContactMediaItemCell *)[_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:itemIndex inSection:sectionIndex]];
                        if (cell != nil && [cell isKindOfClass:[TGContactMediaItemCell class]])
                        {
                            [cell setIsLoading:false];
                            [cell setCount:_mediaListTotalCount];
                        }
                        
                        break;
                    }
                }
            }
        });
    }
    else if ([path hasPrefix:[NSString stringWithFormat:@"/tg/peerSettings/(%d", _uid]])
    {
        NSDictionary *notificationSettings = ((SGraphObjectNode *)result).object;
        
        dispatch_async(dispatch_get_main_queue(), ^
        {
            if (_peerNotificationSettings == nil)
                _peerNotificationSettings = [notificationSettings mutableCopy];
            else
                [_peerNotificationSettings addEntriesFromDictionary:notificationSettings];
            
            [self updateNotificationSettingsItems:false];
        });
    }
    else if ([path isEqualToString:@"/tg/service/synchronizationstate"])
    {
        int state = [((SGraphObjectNode *)result).object intValue];
        
        dispatch_async(dispatch_get_main_queue(), ^
        {
            if (_mode == TGProfileControllerModeSelf)
            {
                if (state & 2)
                    _synchronizationState = 1;
                else if (state & 1)
                    _synchronizationState = 2;
                else
                    _synchronizationState = 0;
                
                if (self.isViewLoaded)
                    [self updateTitle:false];
            }
        });
    }
    else if ([path hasPrefix:[[NSString alloc] initWithFormat:@"/tg/timeline/(%d)/deleteAvatar", _uid]])
    {
        TGUser *myUser = [TGDatabaseInstance() loadUser:_uid];
        
        dispatch_async(dispatch_get_main_queue(), ^
        {
            _user = myUser;
            
            if (resultCode == ASStatusSuccess)
            {
            }
            else
            {
                UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:nil message:TGLocalized(@"Profile.ImageDeleteError") delegate:nil cancelButtonTitle:NSLocalizedString(@"Common.OK", nil) otherButtonTitles:nil];
                [alertView show];
            }
            
            [self setShowAvatarActivity:false animated:true];
            
            [self updateTitle:resultCode != ASStatusSuccess];
            
            if (_currentActionSheet.tag == TGPhotoProgressActionSheetTag)
            {
                [_currentActionSheet dismissWithClickedButtonIndex:_currentActionSheet.cancelButtonIndex animated:true];
                _currentActionSheet.delegate = nil;
                _currentActionSheet = nil;
            }
        });
    }
    else if ([path hasPrefix:[[NSString alloc] initWithFormat:@"/tg/timeline/(%d)/uploadPhoto", _uid]])
    {
        TGUser *myUser = [TGDatabaseInstance() loadUser:_uid];
        
        dispatch_async(dispatch_get_main_queue(), ^
        {
            _user = myUser;
            
            if (resultCode == ASStatusSuccess)
            {
                _avatarView.currentUrl = myUser.photoUrlSmall;
                _addPhotoButton.hidden = true;
                _addPhotoButton.alpha = 0.0f;
            }
            else
            {
                UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:nil message:TGLocalized(@"Profile.ImageUploadError") delegate:nil cancelButtonTitle:NSLocalizedString(@"Common.OK", nil) otherButtonTitles:nil];
                [alertView show];
            }
            
            [self setShowAvatarActivity:false animated:resultCode == ASStatusSuccess];
            
            [self updateTitle:resultCode == ASStatusSuccess];
            
            if (_currentActionSheet.tag == TGPhotoProgressActionSheetTag)
            {
                [_currentActionSheet dismissWithClickedButtonIndex:_currentActionSheet.cancelButtonIndex animated:true];
                _currentActionSheet.delegate = nil;
                _currentActionSheet = nil;
            }
        });
    }
    else if ([path hasPrefix:@"/tg/auth/logout/"])
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            [_progressWindow dismiss:true];
            _progressWindow = nil;
            
            if (resultCode != ASStatusSuccess)
            {
                [[[UIAlertView alloc] initWithTitle:nil message:TGLocalized(@"Settings.LogoutError") delegate:nil cancelButtonTitle:TGLocalized(@"Common.OK") otherButtonTitles:nil] show];
            }
        });
    }
    else if ([path hasPrefix:@"/tg/changeUserName/"])
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            if (resultCode != ASStatusSuccess)
            {
                _firstNameField.text = _user.realFirstName;
                _lastNameField.text = _user.realLastName;
                
                _nameLabel.text = _mode == TGProfileControllerModeSelf ? _user.displayRealName : [self userDisplayName];
            }
            
            _changingName = false;
            _changingFirstName = nil;
            _changingLastName = nil;
            _firstNameField.enabled = true;
            _lastNameField.enabled = true;
            
            [UIView animateWithDuration:0.2f animations:^
            {
                _firstNameField.alpha = 1.0f;
                _lastNameField.alpha = 1.0f;
            }];
        });
    }
    else if ([path hasSuffix:@"breakLinkLocal)"])
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            _ignoreAllUpdates = true;
            
            [self.navigationController popViewControllerAnimated:true];
        });
    }
    else if ([path hasSuffix:@"addContactLocal)"])
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            _ignoreAllUpdates = true;
            
            id<ASWatcher> watcher = _watcherHandle.delegate;
            if (watcher != nil && [watcher respondsToSelector:@selector(actionStageActionRequested:options:)])
                [watcher actionStageActionRequested:@"createContactCompleted" options:[[NSDictionary alloc] initWithObjectsAndKeys:[[NSNumber alloc] initWithBool:resultCode == ASStatusSuccess], @"success", nil]];
        });
    }
    else if ([path hasSuffix:@"changePhonesLocal)"])
    {
        if (_mode == TGProfileControllerModeAddToExistingContact || _mode == TGProfileControllerModeAddToExistingPhonebookContact)
        {
            dispatch_async(dispatch_get_main_queue(), ^
            {
                _ignoreAllUpdates = true;
                
                id<ASWatcher> watcher = _watcherHandle.delegate;
                if (watcher != nil && [watcher respondsToSelector:@selector(actionStageActionRequested:options:)])
                    [watcher actionStageActionRequested:@"addToExistingContactCompleted" options:nil];
            });
        }
        else if ([path hasPrefix:@"/tg/synchronizeContacts/(removedMainPhone"])
        {
            dispatch_async(dispatch_get_main_queue(), ^
            {
                _ignoreAllUpdates = true;
                
                [self.navigationController popViewControllerAnimated:true];
            });
        }
    }
    else if ([path hasSuffix:@"requestContact)"])
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            _linkAction = false;
            
            [_progressWindow dismiss:true];
            _progressWindow = nil;
        });
    }
    else if ([path hasPrefix:@"/tg/encrypted/createChat/"])
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            [_progressWindow dismiss:true];
            _progressWindow = nil;
            
            if (resultCode == ASStatusSuccess)
            {
                TGConversation *conversation = result[@"conversation"];
                [[TGInterfaceManager instance] navigateToConversationWithId:conversation.conversationId conversation:nil];
            }
            else
            {
                [[[UIAlertView alloc] initWithTitle:nil message:resultCode == -2 ? [[NSString alloc] initWithFormat:TGLocalized(@"Profile.CreateEncryptedChatOutdatedError"), _user.displayFirstName, _user.displayFirstName] : TGLocalized(@"Profile.CreateEncryptedChatError") delegate:nil cancelButtonTitle:TGLocalized(@"Common.OK") otherButtonTitles:nil] show];
            }
        });
    }
}

- (void)updateNotificationSettingsItems:(bool)__unused animated
{
    int muteUntil = [[_peerNotificationSettings objectForKey:@"muteUntil"] intValue];
    int soundId = [[_peerNotificationSettings objectForKey:@"soundId"] intValue];
    
    NSNumber *nPhotoNotificationsEnabled = [_peerNotificationSettings objectForKey:@"photoNotificationsEnabled"];
    
    _notificationsItem.isOn = muteUntil == 0;
    
    NSArray *soundsArray = [TGAppDelegateInstance alertSoundTitles];
    if (soundId >= 0 && soundId < (int)soundsArray.count)
        _soundItem.variant = [soundsArray objectAtIndex:soundId];
    else
        _soundItem.variant = [[NSString alloc] initWithFormat:@"Sound %d", soundId];
    
    _photoNotificationsItem.isOn = nPhotoNotificationsEnabled == nil || [nPhotoNotificationsEnabled boolValue];
    
    int messageLifetime = _peerMessageLifetime;
    if (messageLifetime == 0)
        _messageDeletionItem.variant = TGLocalized(@"Profile.MessageLifetimeForever");
    else if (messageLifetime <= 2)
        _messageDeletionItem.variant = TGLocalized(@"Profile.MessageLifetime2s");
    else if (messageLifetime <= 5)
        _messageDeletionItem.variant = TGLocalized(@"Profile.MessageLifetime5s");
    else if (messageLifetime <= 1 * 60)
        _messageDeletionItem.variant = TGLocalized(@"Profile.MessageLifetime1m");
    else if (messageLifetime <= 60 * 60)
        _messageDeletionItem.variant = TGLocalized(@"Profile.MessageLifetime1h");
    else if (messageLifetime <= 24 * 60 * 60)
        _messageDeletionItem.variant = TGLocalized(@"Profile.MessageLifetime1d");
    else if (messageLifetime <= 7 * 24 * 60 * 60)
        _messageDeletionItem.variant = TGLocalized(@"Profile.MessageLifetime1w");
    
    int sectionIndex = 0;
    int itemIndex = 0;
    if ([self findMenuItem:_notificationsItem.tag sectionIndex:&sectionIndex itemIndex:&itemIndex] != nil)
    {
        TGSwitchItemCell *switchCell = (TGSwitchItemCell *)[_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:itemIndex inSection:sectionIndex]];
        if ([switchCell isKindOfClass:[TGSwitchItemCell class]])
            [switchCell setIsOn:_notificationsItem.isOn];
    }
    
    if ([self findMenuItem:_soundItem.tag sectionIndex:&sectionIndex itemIndex:&itemIndex] != nil)
    {
        TGVariantMenuItemCell *variantCell = (TGVariantMenuItemCell *)[_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:itemIndex inSection:sectionIndex]];
        if ([variantCell isKindOfClass:[TGVariantMenuItemCell class]])
            [variantCell setVariant:_soundItem.variant];
    }
    
    if ([self findMenuItem:TGPhotoNotificationsTag sectionIndex:&sectionIndex itemIndex:&itemIndex] != nil)
    {
        TGSwitchItemCell *switchCell = (TGSwitchItemCell *)[_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:itemIndex inSection:sectionIndex]];
        if ([switchCell isKindOfClass:[TGSwitchItemCell class]])
            [switchCell setIsOn:_photoNotificationsItem.isOn];
    }
    
    if ([self findMenuItem:TGMessageLifetimeTag sectionIndex:&sectionIndex itemIndex:&itemIndex] != nil)
    {
        TGVariantMenuItemCell *variantCell = (TGVariantMenuItemCell *)[_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:itemIndex inSection:sectionIndex]];
        if ([variantCell isKindOfClass:[TGVariantMenuItemCell class]])
            [variantCell setVariant:_messageDeletionItem.variant];
    }
}

- (void)actionStageActionRequested:(NSString *)__unused action options:(NSDictionary *)options
{
    if ([action isEqualToString:@"toggleSwitchItem"])
    {
        TGSwitchItem *switchItem = [options objectForKey:@"itemId"];
        if (switchItem == nil)
            return;
        
        NSNumber *nValue = [options objectForKey:@"value"];
        
        switchItem.isOn = [nValue boolValue];
        
        if (switchItem.tag == TGNotificationsTag)
        {
            NSNumber *nMuteUntil = [NSNumber numberWithInt:switchItem.isOn ? 0 : INT_MAX];
            [_peerNotificationSettings setObject:nMuteUntil forKey:@"muteUntil"];
            
            static int actionId = 0;
            
            [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/changePeerSettings/(%d)/(pd%d)", _uid, actionId++] options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithLongLong:_uid], @"peerId", nMuteUntil, @"muteUntil", nil] watcher:TGTelegraphInstance];
        }
        else if (switchItem.tag == TGAutosaveItemTag)
        {
            TGAppDelegateInstance.autosavePhotos = switchItem.isOn;
            [TGAppDelegateInstance saveSettings];
        }
        else if (switchItem.tag == TGPhotoNotificationsTag)
        {
            NSNumber *nPhotoNotificationsEnabled = [NSNumber numberWithBool:switchItem.isOn];
            [_peerNotificationSettings setObject:nPhotoNotificationsEnabled forKey:@"photoNotificationsEnabled"];
            
            static int actionId = 0;
            
            [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/changePeerSettings/(%d)/(1pd%d)", _uid, actionId++] options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithLongLong:_uid], @"peerId", nPhotoNotificationsEnabled, @"photoNotificationsEnabled", nil] watcher:TGTelegraphInstance];
        }
    }
    else if ([action isEqualToString:@"buttonItemPressed"])
    {
        TGButtonMenuItem *buttonItem = [options objectForKey:@"itemId"];
        if (buttonItem == nil)
            return;
        
        if ([self respondsToSelector:buttonItem.action])
        {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [self performSelector:buttonItem.action];
#pragma clang diagnostic pop
        }
    }
    else if ([action isEqualToString:@"customSoundSelected"])
    {
        [self dismissViewControllerAnimated:true completion:nil];
        
        NSNumber *nIndex = [options objectForKey:@"index"];
        if (nIndex != nil)
        {
            int currentSoundId = [[_peerNotificationSettings objectForKey:@"soundId"] intValue];
            if (currentSoundId == [nIndex intValue])
                return;
            
            [_peerNotificationSettings setObject:[NSNumber numberWithInt:[nIndex intValue]] forKey:@"soundId"];
            [self updateNotificationSettingsItems:true];
            
            static int actionId = 0;
            
            [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/changePeerSettings/(%d)/(pe%d)", _uid, actionId++] options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithLongLong:_uid], @"peerId", [NSNumber numberWithInt:[nIndex intValue]], @"soundId", nil] watcher:TGTelegraphInstance];
        }
    }
    else if ([action isEqualToString:@"phoneLabelSelected"])
    {   
        NSString *label = [options objectForKey:@"label"];
        NSIndexPath *indexPath = [_tableView indexPathForSelectedRow];
        if (indexPath != nil)
        {
            if (label != nil)
            {
                TGMenuItem *item = [((TGMenuSection *)[_sectionList objectAtIndex:indexPath.section]).items objectAtIndex:indexPath.row];
                if (item.type == TGPhoneItemType)
                {
                    TGPhoneItem *phoneItem = (TGPhoneItem *)item;
                    phoneItem.label = label;
                    
                    TGPhoneItemCell *cell = (TGPhoneItemCell *)[_tableView cellForRowAtIndexPath:indexPath];
                    if ([cell isKindOfClass:[TGPhoneItemCell class]])
                        [cell setLabel:label];
                }
            }
            
            [_tableView deselectRowAtIndexPath:indexPath animated:true];
        }
        
        [self dismissViewControllerAnimated:true completion:nil];
    }
    else if ([action isEqualToString:@"openImage"])
    {
    }
    else if ([action isEqualToString:@"hideImage"])
    {
        if ([[options objectForKey:@"hide"] boolValue])
        {
            TGImageInfo *imageInfo = options[@"imageInfo"];
            if (imageInfo != nil)
            {
                if (_avatarView.currentUrl != nil && [imageInfo containsSizeWithUrl:_avatarView.currentUrl])
                    _avatarView.hidden = true;
                else
                    _avatarView.hidden = false;
            }
        }
    }
    else if ([action isEqualToString:@"openAllPhotos"])
    {
        if (_user != nil && _user.photoUrlBig != nil && _avatarView.currentImage != nil)
        {
            UIImage *placeholder = [[TGRemoteImageView sharedCache] cachedImage:_user.photoUrlSmall availability:TGCacheBoth];
            
            if (placeholder == nil)
                placeholder = [_avatarView currentImage];
            
            TGImageInfo *imageInfo = [[TGImageInfo alloc] init];
            [imageInfo addImageWithSize:CGSizeMake(160, 160) url:_user.photoUrlSmall];
            [imageInfo addImageWithSize:CGSizeMake(640, 640) url:_user.photoUrlBig];
            
            TGImageMediaAttachment *imageAttachment = [[TGImageMediaAttachment alloc] init];
            imageAttachment.imageInfo = imageInfo;
            
            TGProfileImageItem *imageItem = [[TGProfileImageItem alloc] initWithProfilePhoto:imageAttachment];
            TGImageViewController *imageViewController = [[TGImageViewController alloc] initWithImageItem:imageItem placeholder:placeholder];
            
            imageViewController.hideDates = true;
            imageViewController.reverseOrder = true;
            
            TGTelegraphProfileImageViewCompanion *companion = [[TGTelegraphProfileImageViewCompanion alloc] initWithUid:_uid photoItem:imageItem loadList:true];
            companion.watcherHandle = _actionHandle;
            imageViewController.imageViewCompanion = companion;
            companion.imageViewController = imageViewController;
            
            CGRect windowSpaceFrame = [_avatarView convertRect:_avatarView.bounds toView:_avatarView.window];
            
            TGRemoteImageView *avatarView = _avatarView;
            [imageViewController animateAppear:self.view anchorForImage:_tableView fromRect:windowSpaceFrame fromImage:_avatarView.currentImage start:^
            {
                avatarView.hidden = true;
            }];
            imageViewController.watcherHandle = _actionHandle;
            
            [TGAppDelegateInstance presentContentController:imageViewController];
        }
    }
    else if ([action isEqualToString:@"closeImage"])
    {
        TGImageViewController *imageViewController = [options objectForKey:@"sender"];
        
        CGRect targetRect = [_avatarView convertRect:_avatarView.bounds toView:self.view.window];
        UIImage *targetImage = [_avatarView currentImage];
        
        TGImageInfo *imageInfo = options[@"imageInfo"];
        
        if (targetImage == nil || [options[@"forceSwipe"] boolValue] || (imageInfo != nil && ![imageInfo containsSizeWithUrl:[_avatarView currentUrl]]))
            targetRect = CGRectZero;
        
        if ([options[@"forceSwipe"] boolValue])
            _avatarView.hidden = false;
        
        [imageViewController animateDisappear:self.view anchorForImage:_tableView toRect:targetRect toImage:targetImage swipeVelocity:0.0f completion:^
        {
            _avatarView.hidden = false;
            
            [TGAppDelegateInstance dismissContentController];
        }];
        
        [((TGNavigationController *)self.navigationController) updateControllerLayout:false];
    }
    else if ([action isEqualToString:@"deleteAvatar"])
    {
        [self setShowAvatarActivity:true animated:true];
        
        [ActionStageInstance() dispatchOnStageQueue:^
        {
            static int actionId = 0;
            
            NSDictionary *options = [[NSDictionary alloc] initWithObjectsAndKeys:[[NSNumber alloc] initWithInt:_uid], @"uid", nil];
            NSString *action = [[NSString alloc] initWithFormat:@"/tg/timeline/(%d)/deleteAvatar/(%d)", _uid, actionId++];
            [ActionStageInstance() requestActor:action options:options watcher:self];
            [ActionStageInstance() requestActor:action options:options watcher:TGTelegraphInstance];
        }];
    }
    else if ([action isEqualToString:@"dismissCamera"])
    {
#if TG_USE_CUSTOM_CAMERA
        if (_cameraWindow != nil)
        {
            [_cameraWindow dismiss];
            _cameraWindow = nil;
        }
#endif
    }
    else if ([action isEqualToString:@"cameraCompleted"])
    {
#if TG_USE_CUSTOM_CAMERA
        if (_cameraWindow != nil)
        {
            NSData *imageData = [options objectForKey:@"imageData"];
            UIImage *image = [options objectForKey:@"image"];
            
            if (imageData == nil)
                return;
            
            TGImageProcessor filter = [TGRemoteImageView imageProcessorForName:@"profileAvatar"];
            UIImage *toImage = filter(image);
            
            [_cameraWindow dismissToRect:[_avatarView convertRect:_avatarView.bounds toView:self.view.window] fromImage:image toImage:toImage toView:self.view aboveView:_tableView interfaceOrientation:self.interfaceOrientation];
            _cameraWindow = nil;
            
            _avatarViewEdit.alpha = 0.0f;
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((0.29 * TGAnimationSpeedFactor()) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^
            {
                _avatarView.hidden = false;
                _avatarView.alpha = 1.0f;
                _addPhotoButton.hidden = true;
                _addPhotoButton.alpha = 0.0f;
                [_avatarView loadImage:toImage];
                _avatarView.currentFilter = @"profileAvatar";
                [self setShowAvatarActivity:true animated:true];
                
                [ActionStageInstance() dispatchOnStageQueue:^
                {
                    bool hasLocation = false;
                    double locationLatitude = 0.0;
                    double locationLongitude = 0.0;
                    [TGLocationRequestActor currentLocation:&hasLocation latitude:&locationLatitude longitude:&locationLongitude];
                    [ActionStageInstance() removeWatcher:self fromPath:@"/tg/location/current/(100)"];
                    
                    NSMutableDictionary *options = [[NSMutableDictionary alloc] init];
                    
                    uint8_t fileId[32];
                    arc4random_buf(&fileId, 32);
                    
                    NSMutableString *filePath = [[NSMutableString alloc] init];
                    for (int i = 0; i < 32; i++)
                    {
                        [filePath appendFormat:@"%02x", fileId[i]];
                    }
                    
                    NSString *tmpImagesPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true) objectAtIndex:0] stringByAppendingPathComponent:@"upload"];
                    static NSFileManager *fileManager = nil;
                    if (fileManager == nil)
                        fileManager = [[NSFileManager alloc] init];
                    NSError *error = nil;
                    [fileManager createDirectoryAtPath:tmpImagesPath withIntermediateDirectories:true attributes:nil error:&error];
                    NSString *absoluteFilePath = [tmpImagesPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.bin", filePath]];
                    [imageData writeToFile:absoluteFilePath atomically:false];
                    
                    [options setObject:filePath forKey:@"originalFileUrl"];
                    
                    if (hasLocation)
                    {
                        [options setObject:[NSNumber numberWithDouble:locationLatitude] forKey:@"latitude"];
                        [options setObject:[NSNumber numberWithDouble:locationLongitude] forKey:@"longitude"];
                    }
                    
                    [options setObject:toImage forKey:@"currentPhoto"];
                    
                    NSString *action = [[NSString alloc] initWithFormat:@"/tg/timeline/(%d)/uploadPhoto/(%@)", _uid, filePath];
                    [ActionStageInstance() requestActor:action options:options watcher:self];
                    [ActionStageInstance() requestActor:action options:options watcher:TGTelegraphInstance];
                }];
            });
        }
#endif
    }
    else if ([action isEqualToString:@"dismissModalContacts"])
    {
        [self dismissViewControllerAnimated:true completion:nil];
    }
    else if ([action isEqualToString:@"buttonsMenuItemAction"])
    {
        NSString *buttonAction = [options objectForKey:@"action"];
        if ([buttonAction isEqualToString:@"sendMessage"])
        {
            bool clearStack = true;
            /*for (UIViewController *viewController in self.navigationController.viewControllers)
            {
                if ([viewController isKindOfClass:[TGAddContactsController class]])
                {
                    clearStack = false;
                    break;
                }
            }*/
            
            [[TGInterfaceManager instance] navigateToConversationWithId:_uid conversation:nil forwardMessages:nil atMessageId:0 clearStack:clearStack openKeyboard:true animated:true];
        }
        else if ([buttonAction isEqualToString:@"sendRequest"])
        {
            [self sendContactRequest];
        }
        else if ([buttonAction isEqualToString:@"addContact"])
        {
            if (_user.phoneNumber.length == 0)
            {
            }
            else
            {
                _currentActionSheet.delegate = nil;
                
                NSMutableDictionary *actionSheetMapping = [[NSMutableDictionary alloc] init];
                
                _currentActionSheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
                _currentActionSheet.tag = TGAddContactActionSheetTag;
                
                [actionSheetMapping setObject:@"createNewContact" forKey:[[NSNumber alloc] initWithInt:[_currentActionSheet addButtonWithTitle:TGLocalized(@"Profile.CreateNewContact")]]];
                [actionSheetMapping setObject:@"addToExistingContact" forKey:[[NSNumber alloc] initWithInt:[_currentActionSheet addButtonWithTitle:TGLocalized(@"Profile.AddToExisting")]]];
                
                _currentActionSheet.cancelButtonIndex = [_currentActionSheet addButtonWithTitle:NSLocalizedString(@"Common.Cancel", nil)];
                if ([self.parentViewController isKindOfClass:[UITabBarController class]])
                    [_currentActionSheet showInView:self.parentViewController.view];
                else
                    [_currentActionSheet showInView:self.view];
                
                _currentActionSheetMapping = actionSheetMapping;
            }
        }
        else if ([buttonAction isEqualToString:@"shareContact"])
        {
            if (_user.phoneNumber.length != 0)
            {
                TGMessage *message = [[TGMessage alloc] init];
                
                TGContactMediaAttachment *contactAttachment = [[TGContactMediaAttachment alloc] init];
                contactAttachment.uid = _user.uid;
                contactAttachment.firstName = [self userFirstName];
                contactAttachment.lastName = [self userLastName];
                contactAttachment.phoneNumber = _user.phoneNumber;
                
                message.mediaAttachments = [[NSArray alloc] initWithObjects:contactAttachment, nil];
                
                TGForwardTargetController *forwardController = [[TGForwardTargetController alloc] initWithMessages:[[NSArray alloc] initWithObjects:message, nil]];
                forwardController.watcherHandle = _actionHandle;
                forwardController.controllerTitle = TGLocalized(@"Profile.ShareContactButton");
                forwardController.confirmationPrefix = TGLocalized(@"Profile.ShareContactPrefix");

                TGNavigationController *navigationController = [TGNavigationController navigationControllerWithRootController:forwardController blackCorners:false];
                
                if (iosMajorVersion() <= 5)
                {
                    [TGViewController disableAutorotationFor:0.45];
                    [forwardController view];
                    [forwardController viewWillAppear:false];
                    
                    CGSize screenSize = [TGViewController screenSizeForInterfaceOrientation:self.interfaceOrientation];
                    navigationController.view.frame = CGRectMake(0, screenSize.height, screenSize.width, screenSize.height);
                    [self.navigationController.view addSubview:navigationController.view];
                    
                    [UIView animateWithDuration:0.45 animations:^
                    {
                        navigationController.view.frame = CGRectMake(0, 0, screenSize.width, screenSize.height);
                    } completion:^(BOOL finished)
                    {
                        [navigationController.view removeFromSuperview];
                        
                        if (finished)
                        {
                            [self.navigationController presentViewController:navigationController animated:false completion:nil];
                        }
                    }];
                }
                else
                {
                    [self.navigationController presentViewController:navigationController animated:true completion:nil];
                }
            }
        }
        else if ([buttonAction isEqualToString:@"invite"])
        {
            if (_phonebookContact.phoneNumbers.count == 1)
            {
                [self inviteByPhone:((TGPhoneNumber *)[_phonebookContact.phoneNumbers objectAtIndex:0]).number];
            }
            else if (_phonebookContact.phoneNumbers.count > 1)
            {
                _currentActionSheet.delegate = nil;
                
                NSMutableDictionary *actionSheetMapping = [[NSMutableDictionary alloc] init];
                
                _currentActionSheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
                _currentActionSheet.tag = TGInvitePhonesActionSheetTag;
                
                for (TGPhoneNumber *phoneNumber in _phonebookContact.phoneNumbers)
                {
                    NSString *itemText = nil;
                    if (phoneNumber.label.length > 0)
                        itemText = [[NSString alloc] initWithFormat:@"%@: %@", phoneNumber.label, [TGStringUtils formatPhone:phoneNumber.number forceInternational:false]];
                    else
                        itemText = [TGStringUtils formatPhone:phoneNumber.number forceInternational:false];
                    [actionSheetMapping setObject:[NSString stringWithString:phoneNumber.number] forKey:[[NSNumber alloc] initWithInt:[_currentActionSheet addButtonWithTitle:itemText]]];
                }
                
                _currentActionSheet.cancelButtonIndex = [_currentActionSheet addButtonWithTitle:NSLocalizedString(@"Common.Cancel", nil)];
                if ([self.parentViewController isKindOfClass:[UITabBarController class]])
                    [_currentActionSheet showInView:self.parentViewController.view];
                else
                    [_currentActionSheet showInView:self.view];
                
                _currentActionSheetMapping = actionSheetMapping;
            }
        }
    }
    else if ([action isEqualToString:@"phoneItemReceivedFocus"])
    {
        UITableViewCell *cell = [options objectForKey:@"cell"];
        NSIndexPath *indexPath = [self indexPathForCell:cell];
        if (indexPath == nil)
            return;
        
        TGMenuSection *section = [_sectionList objectAtIndex:indexPath.section];
        
        NSMutableArray *deleteIndices = [[NSMutableArray alloc] init];
        int index = -1;
        for (TGPhoneItem *phoneItem in section.items)
        {
            index++;
            if (index != indexPath.row && phoneItem.phone.length == 0 && index != (int)section.items.count - 1)
            {
                [deleteIndices addObject:[NSIndexPath indexPathForRow:index inSection:indexPath.section]];
            }
        }
        
        if (deleteIndices.count != 0)
        {
            [_tableView beginUpdates];
            for (NSIndexPath *indexPath in [deleteIndices reverseObjectEnumerator])
            {
                [self animateRowDeletion:indexPath];
                [section.items removeObjectAtIndex:indexPath.row];
            }
            [_tableView endUpdates];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^
        {
            [(TGPhoneItemCell *)cell requestFocus];
        });
    }
    else if ([action isEqualToString:@"phoneItemChanged"])
    {
        UITableViewCell *cell = [options objectForKey:@"cell"];
        NSIndexPath *indexPath = [self indexPathForCell:cell];
        if (indexPath == nil)
            return;
        
        TGPhoneItemCell *phoneItemCell = (TGPhoneItemCell *)cell;
        
        TGMenuSection *section = [_sectionList objectAtIndex:indexPath.section];
        TGPhoneItem *item = [section.items objectAtIndex:indexPath.row];
        item.formattedPhone = phoneItemCell.phone;
        
        if (((TGPhoneItem *)[section.items lastObject]).phone.length != 0)
        {
            [_tableView beginUpdates];
            
            NSString *newLabel = @"mobile";
            for (NSString *label in [TGSynchronizeContactsManager phoneLabels])
            {
                bool used = false;
                for (TGPhoneItem *phoneItem in section.items)
                {
                    if ([phoneItem.label isEqualToString:label])
                    {
                        used = true;
                        break;
                    }
                }
                
                if (!used)
                {
                    newLabel = label;
                    break;
                }
            }
            
            TGPhoneItem *emptyPhone = [[TGPhoneItem alloc] init];
            emptyPhone.label = newLabel;
            emptyPhone.phone = @"";
            [section.items addObject:emptyPhone];
            
            if (section.items.count >= 2)
            {
                UITableViewCell *previousCell = [_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:section.items.count - 2 inSection:indexPath.section]];
                updateGroupedCellBackground((TGGroupedCell *)previousCell, section.items.count == 2, false, true);
            }
            
            NSIndexPath *indexPathToResetEditing = [NSIndexPath indexPathForRow:section.items.count - 1 inSection:indexPath.section];
            [_tableView insertRowsAtIndexPaths:[[NSArray alloc] initWithObjects:indexPathToResetEditing, nil] withRowAnimation:UITableViewRowAnimationFade];
            
            [_tableView endUpdates];
        }
        
        [self updateDoneButtonState];
    }
    else if ([action isEqualToString:@"createContactCompleted"])
    {
        [self dismissViewControllerAnimated:true completion:nil];
    }
    else if ([action isEqualToString:@"openWallpaper"])
    {
        if (options != nil)
        {
            TGWallpaperPreviewController *wallpaperPreviewController = [[TGWallpaperPreviewController alloc] initWithWallpaperInfo:options];
            wallpaperPreviewController.watcherHandle = _actionHandle;
        
            [self presentViewController:wallpaperPreviewController animated:true completion:nil];
        }
    }
    else if ([action isEqualToString:@"wallpaperSelected"])
    {
        [self dismissViewControllerAnimated:true completion:nil];
        
        if (options != nil)
        {
            NSString *currentUrl = [TGWallpaperStoreController selectWallpaper:options];
            [ActionStageInstance() dispatchResource:@"/tg/assets/currentWallpaperUrl" resource:currentUrl];
        }
    }
    else if ([action isEqualToString:@"willForwardMessages"])
    {
        [self dismissViewControllerAnimated:true completion:nil];
    }
}

- (void)updateNavigationButtons:(bool)editing animated:(bool)animated
{
    if (editing)
    {
        if (_mode == TGProfileControllerModeAddToExistingContact || _mode == TGProfileControllerModeAddToExistingPhonebookContact)
        {
            if ([self leftBarButtonItem].customView.tag != ((int)0x263D9E33))
                [self setBackAction:@selector(performCloseProfile) animated:animated];
        }
        else
        {
            TGToolbarButton *cancelButton = [[TGToolbarButton alloc] initWithType:TGToolbarButtonTypeGeneric];
            cancelButton.text = NSLocalizedString(@"Common.Cancel", @"");
            cancelButton.minWidth = 59;
            [cancelButton sizeToFit];
            [cancelButton addTarget:self action:@selector(editingCancelButtonPressed) forControlEvents:UIControlEventTouchUpInside];
            
            UIBarButtonItem *cancelButtonItem = [[UIBarButtonItem alloc] initWithCustomView:cancelButton];
            [self setLeftBarButtonItem:cancelButtonItem animated:animated];
        }
        
        TGToolbarButton *doneButton = [[TGToolbarButton alloc] initWithType:TGToolbarButtonTypeDone];
        doneButton.tag = ((int)0x28DB5B6A);
        doneButton.text = NSLocalizedString(@"Common.Done", @"");
        doneButton.minWidth = 51;
        [doneButton sizeToFit];
        [doneButton addTarget:self action:@selector(editingDoneButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        UIBarButtonItem *doneButtonItem = [[UIBarButtonItem alloc] initWithCustomView:doneButton];
        [self setRightBarButtonItem:doneButtonItem animated:animated];
        
        [self updateDoneButtonState];
        
        _showingEditingControls = true;
    }
    else
    {
        if (self == TGAppDelegateInstance.myAccountController)
            [self setLeftBarButtonItem:nil animated:false];
        else if ([self leftBarButtonItem].customView.tag != ((int)0x263D9E33))
            [self setBackAction:@selector(performCloseProfile) animated:animated];
        
        [self setRightBarButtonItem:self.editBarButtonItem animated:animated];
        
        _showingEditingControls = false;
    }
    
    if (self == TGAppDelegateInstance.myAccountController)
    {
        [TGAppDelegateInstance.mainTabsController updateLeftBarButtonForCurrentController:animated];
        [TGAppDelegateInstance.mainTabsController updateRightBarButtonForCurrentController:animated];
    }
}

- (void)updateDoneButtonState
{
    TGToolbarButton *doneButton = nil;
    if (self.rightBarButtonItem.customView.tag == ((int)0x28DB5B6A))
        doneButton = (TGToolbarButton *)self.rightBarButtonItem.customView;
    
    if (_mode == TGProfileControllerModeSelf)
        doneButton.enabled = _firstNameField.text.length != 0 && _lastNameField.text.length != 0;
    else
    {
        bool haveNumber = false;
        for (TGPhoneItem *phoneItem in _editingPhonesSection.items)
        {
            if (phoneItem.phone.length != 0)
                haveNumber = true;
        }
        doneButton.enabled = haveNumber && (_firstNameField.text.length != 0 || _lastNameField.text.length != 0);
    }

}

- (void)editingEditButtonPressed
{
    if (_mode != TGProfileControllerModeSelf)
    {
        _editingPhonesSection = [[TGMenuSection alloc] init];
        _editingPhonesSection.tag = _phonesSection.tag;
        _editingPhonesSection.items = [self deepCopyPhoneItems:_phonesSection.items];
        
        int sectionIndex = 0;
        if ([self findSection:_phonesSection.tag sectionIndex:&sectionIndex])
            [_sectionList replaceObjectAtIndex:sectionIndex withObject:_editingPhonesSection];
    }
    
    [_tableView setEditing:true animated:true];
    [self updateEditingState:true];
    [self updateNavigationButtons:true animated:true];
}

- (void)editingDoneButtonPressed
{
    if (_mode == TGProfileControllerModeCreateNewContact)
    {
        [TGViewController disableUserInteractionFor:0.5];
        
        int matchHash = phoneMatchHash(_user.phoneNumber);
        bool hasCurrentNumber = false;
        
        TGPhonebookContact *phonebookContact = [[TGPhonebookContact alloc] init];
        phonebookContact.firstName = _firstNameField.text;
        phonebookContact.lastName = _lastNameField.text;
        
        NSMutableArray *phoneNumbers = [[NSMutableArray alloc] init];
        for (TGPhoneItem *phoneItem in _editingPhonesSection.items)
        {
            if (phoneItem.phone.length != 0)
            {
                [phoneNumbers addObject:[[TGPhoneNumber alloc] initWithLabel:phoneItem.label number:phoneItem.phone]];
                if (!hasCurrentNumber && phoneMatchHash(phoneItem.phone) == matchHash)
                    hasCurrentNumber = true;
            }
        }
        phonebookContact.phoneNumbers = phoneNumbers;
        
        static int actionId = 0;
        [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/synchronizeContacts/(%d,%d,addContactLocal)", _uid, actionId++] options:[NSDictionary dictionaryWithObjectsAndKeys:phonebookContact, @"contact", [[NSNumber alloc] initWithInt:hasCurrentNumber ? _uid : 0], @"uid", nil] watcher:self];
        
        return;
    }
    else if (_mode == TGProfileControllerModeCreateNewPhonebookContact)
    {
        [TGViewController disableUserInteractionFor:0.5];
        
        int matchHash = phoneMatchHash(_user.phoneNumber);
        bool hasCurrentNumber = false;
        
        TGPhonebookContact *phonebookContact = [[TGPhonebookContact alloc] init];
        phonebookContact.firstName = _firstNameField.text;
        phonebookContact.lastName = _lastNameField.text;
        
        NSMutableArray *phoneNumbers = [[NSMutableArray alloc] init];
        for (TGPhoneItem *phoneItem in _editingPhonesSection.items)
        {
            if (phoneItem.phone.length != 0)
            {
                [phoneNumbers addObject:[[TGPhoneNumber alloc] initWithLabel:phoneItem.label number:phoneItem.phone]];
                if (!hasCurrentNumber && phoneMatchHash(phoneItem.phone) == matchHash)
                    hasCurrentNumber = true;
            }
        }
        phonebookContact.phoneNumbers = phoneNumbers;
        
        static int actionId = 0;
        [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/synchronizeContacts/(%d,%d,addContactLocal)", _uid, actionId++] options:[NSDictionary dictionaryWithObjectsAndKeys:phonebookContact, @"contact", nil] watcher:self];
        
        return;
    }
    else if (_mode == TGProfileControllerModeAddToExistingContact || _mode == TGProfileControllerModeAddToExistingPhonebookContact)
    {
        NSMutableArray *newPhoneNumbers = [[NSMutableArray alloc] init];
        for (TGPhoneItem *phoneItem in _editingPhonesSection.items)
        {
            NSString *phoneNumber = phoneItem.phone;
            if (phoneNumber.length != 0)
                [newPhoneNumbers addObject:[[TGPhoneNumber alloc] initWithLabel:phoneItem.label number:phoneNumber]];
        }
        
        [self changePhoneNumbers:newPhoneNumbers removedMainPhone:false];
        
        return;
    }
    else if (_mode != TGProfileControllerModeSelf)
    {
        int sectionIndex = 0;
        if ([self findSection:_phonesSection.tag sectionIndex:&sectionIndex])
            [_sectionList replaceObjectAtIndex:sectionIndex withObject:_phonesSection];
        
        if ([self havePhoneChanges])
        {
            NSString *cleanMainPhone = nil;
            if (_user.phoneNumber.length != 0)
                cleanMainPhone = [TGStringUtils cleanPhone:_user.phoneNumber];
            
            bool removedMainPhone = cleanMainPhone == nil ? false : true;
            
            NSMutableArray *newPhoneNumbers = [[NSMutableArray alloc] init];
            for (TGPhoneItem *phoneItem in _editingPhonesSection.items)
            {
                NSString *phoneNumber = phoneItem.phone;
                if (phoneNumber.length != 0)
                {
                    if (cleanMainPhone != nil && [[TGStringUtils cleanPhone:phoneNumber] isEqualToString:cleanMainPhone])
                        removedMainPhone = false;
                    [newPhoneNumbers addObject:[[TGPhoneNumber alloc] initWithLabel:phoneItem.label number:phoneNumber]];
                }
            }
            
            [self changePhoneNumbers:newPhoneNumbers removedMainPhone:removedMainPhone];
            
            if (removedMainPhone)
            {
                self.view.userInteractionEnabled = false;
                return;
            }
        }
        
        _phonesSection.items = [self deepCopyPhoneItems:_editingPhonesSection.items];
        _editingPhonesSection = nil;
    }
    
    [self clearFirstResponder:self.view];
    
    [_tableView setEditing:false animated:true];
    [self updateEditingState:true];
    
    if (_showingEditingControls)
    {
        if ([self.rightBarButtonItem.customView isKindOfClass:[TGToolbarButton class]])
        {
            TGToolbarButton *doneButton = (TGToolbarButton *)self.rightBarButtonItem.customView;
            doneButton.selected = true;
            doneButton.highlighted = true;
        }
        [self updateNavigationButtons:false animated:true];
    }
    
    NSString *currentFirstName = nil;
    NSString *currentLastName = nil;
    
    if (_mode == TGProfileControllerModeSelf)
    {
        currentFirstName = _user.realFirstName;
        currentLastName = _user.realLastName;
    }
    else
    {
        if (_user.hasAnyName)
        {
            currentFirstName = [self userFirstName];
            currentLastName = [self userLastName];
        }
        else
        {
            currentFirstName = @"";
            currentLastName = @"";
        }
    }
    
    if (_firstNameField != nil && _lastNameField != nil && (![_firstNameField.text isEqualToString:currentFirstName] || ![_lastNameField.text isEqualToString:currentLastName]))
    {
        if (_mode == TGProfileControllerModeSelf)
        {
            _firstNameField.enabled = false;
            _lastNameField.enabled = false;
            
            [UIView animateWithDuration:0.2f animations:^
            {
                _firstNameField.alpha = 0.5f;
                _lastNameField.alpha = 0.5f;
            }];
            
            _changingName = true;
            _changingFirstName = _firstNameField.text;
            _changingLastName = _lastNameField.text;
            
            _nameLabel.text = [[NSString alloc] initWithFormat:@"%@ %@", _changingFirstName, _changingLastName];
            
            static int actionId = 0;
            NSString *action = [[NSString alloc] initWithFormat:@"/tg/changeUserName/(%d)", actionId++];
            NSDictionary *options = [[NSDictionary alloc] initWithObjectsAndKeys:[NSString stringWithString:_firstNameField.text], @"firstName", [NSString stringWithString:_lastNameField.text], @"lastName", nil];
            
            [ActionStageInstance() dispatchOnStageQueue:^
            {
                [ActionStageInstance() requestActor:action options:options watcher:self];
                [ActionStageInstance() requestActor:action options:options watcher:TGTelegraphInstance];
            }];
        }
        else if (_mode == TGProfileControllerModeCreateNewContact || _mode == TGProfileControllerModeCreateNewPhonebookContact || _mode == TGProfileControllerModeAddToExistingContact || _mode == TGProfileControllerModeAddToExistingPhonebookContact)
        {
            
        }
        else
        {
            [self changeContactName:_firstNameField.text lastName:_lastNameField.text];
        }
    }
}

- (bool)havePhoneChanges
{
    NSMutableArray *currentPhones = [[NSMutableArray alloc] init];
    for (TGPhoneItem *phoneItem in _phonesSection.items)
    {
        if (phoneItem.phone.length != 0)
            [currentPhones addObject:phoneItem];
    }
    
    NSMutableArray *newPhones = [[NSMutableArray alloc] init];
    for (TGPhoneItem *phoneItem in _editingPhonesSection.items)
    {
        if (phoneItem.phone.length != 0)
            [newPhones addObject:phoneItem];
    }
    
    if (currentPhones.count != newPhones.count)
        return true;

    for (int i = 0; i < (int)currentPhones.count; i++)
    {
        TGPhoneItem *phoneItem1 = [currentPhones objectAtIndex:i];
        TGPhoneItem *phoneItem2 = [newPhones objectAtIndex:i];
        
        if (![phoneItem1.label isEqualToString:phoneItem2.label])
            return true;
        
        if (![phoneItem1.formattedPhone isEqualToString:phoneItem2.formattedPhone])
            return true;
    }

    return false;
}

- (void)editingCancelButtonPressed
{
    if (_mode == TGProfileControllerModeCreateNewContact || _mode == TGProfileControllerModeCreateNewPhonebookContact)
    {
        id<ASWatcher> watcher = _watcherHandle.delegate;
        if (watcher != nil && [watcher respondsToSelector:@selector(actionStageActionRequested:options:)])
            [watcher actionStageActionRequested:@"createContactCompleted" options:nil];
        
        return;
    }
    else if (_mode != TGProfileControllerModeSelf)
    {
        int sectionIndex = 0;
        if ([self findSection:_phonesSection.tag sectionIndex:&sectionIndex])
            [_sectionList replaceObjectAtIndex:sectionIndex withObject:_phonesSection];
        
        if ([self havePhoneChanges])
        {
            [UIView setAnimationsEnabled:false];
            [_tableView reloadSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationNone];
            [UIView setAnimationsEnabled:true];
        }
        else
            _phonesSection.items = [self deepCopyPhoneItems:_editingPhonesSection.items];
        
        _editingPhonesSection = nil;
    }
    
    [self clearFirstResponder:self.view];
    
    [_tableView setEditing:false animated:true];
    [self updateEditingState:true];
    
    if (_showingEditingControls)
    {
        if ([self.leftBarButtonItem.customView isKindOfClass:[TGToolbarButton class]])
        {
            TGToolbarButton *cancelButton = (TGToolbarButton *)self.leftBarButtonItem.customView;
            cancelButton.selected = true;
            cancelButton.highlighted = true;
        }
        
        [self updateNavigationButtons:false animated:true];
    }
    
    if (_mode == TGProfileControllerModeSelf)
    {
        _firstNameField.text = _user.realFirstName;
        _lastNameField.text = _user.realLastName;
    }
    else if (_mode == TGProfileControllerModeTelegraphUser)
    {
        if (_phonebookContact != nil)
        {
            _firstNameField.text = _phonebookContact.firstName;
            _lastNameField.text = _phonebookContact.lastName;
        }
        else
        {
            _firstNameField.text = [self userFirstName];
            _lastNameField.text = [self userLastName];
        }
    }
}

- (void)deleteButtonPressed
{
    if (!_tableView.editing)
        return;
    
    _currentActionSheet.delegate = nil;
    
    _currentActionSheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
    _currentActionSheet.tag = TGDeleteContactActionSheetTag;
    _currentActionSheet.destructiveButtonIndex = [_currentActionSheet addButtonWithTitle:TGLocalized(@"Profile.DeleteContact")];
    _currentActionSheet.cancelButtonIndex = [_currentActionSheet addButtonWithTitle:NSLocalizedString(@"Common.Cancel", nil)];
    if ([self.parentViewController isKindOfClass:[UITabBarController class]])
        [_currentActionSheet showInView:self.parentViewController.view];
    else
        [_currentActionSheet showInView:self.view];
}

- (void)deleteContact
{
    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
    
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        if ([TGSynchronizeContactsManager instance].phonebookAccessStatus != TGPhonebookAccessStatusEnabled)
        {
            dispatch_async(dispatch_get_main_queue(), ^
            {
                [[UIApplication sharedApplication] endIgnoringInteractionEvents];
                
                [[[UIAlertView alloc] initWithTitle:nil message:TGLocalized(@"Profile.PhonebookAccessDisabled") delegate:nil cancelButtonTitle:TGLocalized(@"Common.OK") otherButtonTitles:nil] show];
            });
        }
        else
        {
            _ignoreAllUpdates = true;
            
            static int actionId = 0;
            [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/synchronizeContacts/(break%d,%d,breakLinkLocal)", _uid, actionId++] options:[NSDictionary dictionaryWithObjectsAndKeys:[[NSNumber alloc] initWithInt:_uid], @"uid", [[NSNumber alloc] initWithInt:_phonebookContact.nativeId], @"nativeId", nil] watcher:self];
            
            TGDispatchAfter(0.5, dispatch_get_main_queue(), ^
            {
                [[UIApplication sharedApplication] endIgnoringInteractionEvents];
            });
        }
    }];
}

- (void)changeContactName:(NSString *)firstName lastName:(NSString *)lastName
{
    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
    
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        if ([TGSynchronizeContactsManager instance].phonebookAccessStatus != TGPhonebookAccessStatusEnabled)
        {
            dispatch_async(dispatch_get_main_queue(), ^
            {
                [[UIApplication sharedApplication] endIgnoringInteractionEvents];
                
                [[[UIAlertView alloc] initWithTitle:nil message:TGLocalized(@"Profile.PhonebookAccessDisabled") delegate:nil cancelButtonTitle:TGLocalized(@"OK") otherButtonTitles:nil] show];
            });
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^
            {
                [[UIApplication sharedApplication] endIgnoringInteractionEvents];
                
                _nameLabel.text = [[NSString alloc] initWithFormat:@"%@ %@", firstName, lastName];
            });
            
            //TGDispatchAfter(0.3, [ActionStageInstance() globalStageDispatchQueue], ^
            //{
                static int actionId = 0;
                [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/synchronizeContacts/(%d,%d,changeNameLocal)", _uid, actionId++] options:[NSDictionary dictionaryWithObjectsAndKeys:[[NSNumber alloc] initWithInt:_uid], @"uid", firstName, @"firstName", lastName, @"lastName", [[NSNumber alloc] initWithInt:_phonebookContact.nativeId], @"nativeId", nil] watcher:self];
            //});
        }
    }];
}

- (void)changePhoneNumbers:(NSArray *)phoneNumbers removedMainPhone:(bool)removedMainPhone
{
    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
    
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        if ([TGSynchronizeContactsManager instance].phonebookAccessStatus != TGPhonebookAccessStatusEnabled)
        {
            dispatch_async(dispatch_get_main_queue(), ^
            {
                [[UIApplication sharedApplication] endIgnoringInteractionEvents];
                
                [[[UIAlertView alloc] initWithTitle:nil message:TGLocalized(@"Profile.PhonebookAccessDisabled") delegate:nil cancelButtonTitle:TGLocalized(@"Common.OK") otherButtonTitles:nil] show];
            });
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^
            {
                [[UIApplication sharedApplication] endIgnoringInteractionEvents];
            });
            
            static int actionId = 0;
            
            NSMutableDictionary *options = [[NSMutableDictionary alloc] init];
            [options setObject:[[NSNumber alloc] initWithInt:_uid] forKey:@"uid"];
            [options setObject:[[NSNumber alloc] initWithInt:_phonebookContact.nativeId] forKey:@"nativeId"];
            if (phoneNumbers != nil)
                [options setObject:phoneNumbers forKey:@"phones"];
            
            if (_mode == TGProfileControllerModeAddToExistingContact || _mode == TGProfileControllerModeAddToExistingPhonebookContact)
            {
                bool found = false;
                NSString *phoneNumberToAdd = [TGStringUtils cleanPhone:_phoneNumberToAdd];
                for (TGPhoneNumber *phoneNumber in phoneNumbers)
                {
                    if ([[TGStringUtils cleanPhone:phoneNumber.number] isEqualToString:phoneNumberToAdd])
                    {
                        found = true;
                        break;
                    }
                }
                if (found)
                    [options setObject:[[NSNumber alloc] initWithInt:_addingUid] forKey:@"addingUid"];
            }
            
            if (removedMainPhone)
                [options setObject:[[NSNumber alloc] initWithBool:true] forKey:@"removedMainPhone"];
            
            [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/synchronizeContacts/(%s,%d,changePhonesLocal)", removedMainPhone ? "removedMainPhone" : "", actionId++] options:options watcher:self];
        }
    }];
}

- (NSMutableArray *)deepCopyPhoneItems:(NSArray *)array
{
    NSMutableArray *newArray = [[NSMutableArray alloc] initWithCapacity:array.count];
    for (TGPhoneItem *phoneItem in array)
    {
        [newArray addObject:[phoneItem copy]];
    }
    
    return newArray;
}

- (void)inviteByPhone:(NSString *)phoneNumber
{
    if ([MFMessageComposeViewController canSendText])
    {
        MFMessageComposeViewController *messageComposer = [[MFMessageComposeViewController alloc] init];
        
        if (messageComposer != nil)
        {
            messageComposer.recipients = [[NSArray alloc] initWithObjects:phoneNumber, nil];
            messageComposer.messageComposeDelegate = self;
            
            messageComposer.body = TGLocalized(@"Contacts.InvitationText");
            
            [self presentViewController:messageComposer animated:true completion:nil];
            
            [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackOpaque];
        }
    }
}

- (void)messageComposeViewController:(MFMessageComposeViewController *)__unused controller didFinishWithResult:(MessageComposeResult)__unused result
{
    [self dismissViewControllerAnimated:true completion:nil];
    
    if (result == MessageComposeResultSent)
    {
        @try
        {
            static int inviteAction = 0;
            [ActionStageInstance() requestActor:[[NSString alloc] initWithFormat:@"/tg/auth/sendinvites/(%d)", inviteAction] options:[[NSDictionary alloc] initWithObjectsAndKeys:controller.body, @"text", controller.recipients, @"phones", nil] watcher:TGTelegraphInstance];
        }
        @catch (NSException *exception)
        {
        }
    }
}

- (void)sendContactRequest
{
    if (_uid != 0)
    {
        _progressWindow = [[TGProgressWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
        [_progressWindow show:true];
        
        int uid = _uid;
        _linkAction = true;
        [self updateActions:false];
        
        [ActionStageInstance() dispatchOnStageQueue:^
        {
            if (_uid != 0)
            {
                NSString *action = [NSString stringWithFormat:@"/tg/contacts/requestActor/(%d)/(requestContact)", uid];
                NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:[[NSNumber alloc] initWithInt:uid], @"uid", @"requestContact", @"action", nil];
                [ActionStageInstance() requestActor:action options:options watcher:self];
                [ActionStageInstance() requestActor:action options:options watcher:TGTelegraphInstance];
            }
        }];
    }
}

- (void)createEncryptedChatPressed
{
    if ([_tableView indexPathForSelectedRow] != nil)
        [_tableView deselectRowAtIndexPath:[_tableView indexPathForSelectedRow] animated:true];
    
    int64_t peerId = [TGDatabaseInstance() activeEncryptedPeerIdForUserId:_uid];
    
    if (peerId == 0)
    {
        _progressWindow = [[TGProgressWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        [_progressWindow show:true];
        
        static int actionId = 0;
        [ActionStageInstance() requestActor:[[NSString alloc] initWithFormat:@"/tg/encrypted/createChat/(profile%d)", actionId++] options:@{@"uid": @(_uid)} flags:0 watcher:self];
    }
    else
    {
        [[TGInterfaceManager instance] navigateToConversationWithId:peerId conversation:nil];
    }
}

- (void)encryptionKeyPressed
{
    [self.navigationController pushViewController:[[TGEncryptionKeyViewController alloc] initWithEncryptedConversationId:_encryptedConversationId userId:_uid] animated:true];
}

- (void)messageLifetimePressed
{
    if ([_tableView indexPathForSelectedRow] != nil)
        [_tableView deselectRowAtIndexPath:[_tableView indexPathForSelectedRow] animated:true];
    
    _currentActionSheet.delegate = nil;
    
    _currentActionSheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
    _currentActionSheet.tag = TGMessageLifetimeActionSheetTag;
    
    [_currentActionSheet addButtonWithTitle:TGLocalized(@"Profile.MessageLifetimeForever")];
    [_currentActionSheet addButtonWithTitle:TGLocalized(@"Profile.MessageLifetime2s")];
    [_currentActionSheet addButtonWithTitle:TGLocalized(@"Profile.MessageLifetime5s")];
    [_currentActionSheet addButtonWithTitle:TGLocalized(@"Profile.MessageLifetime1m")];
    [_currentActionSheet addButtonWithTitle:TGLocalized(@"Profile.MessageLifetime1h")];
    [_currentActionSheet addButtonWithTitle:TGLocalized(@"Profile.MessageLifetime1d")];
    [_currentActionSheet addButtonWithTitle:TGLocalized(@"Profile.MessageLifetime1w")];
    
    _currentActionSheet.cancelButtonIndex = [_currentActionSheet addButtonWithTitle:TGLocalized(@"Common.Cancel")];
    
    [_currentActionSheet showInView:self.view];
}

@end
