#import "TGTelegraphConversationProfileController.h"

#import "SGraphObjectNode.h"

#import "TGConversationChangePhotoActor.h"
#import "TGConversationChangeTitleRequestActor.h"

#import "TGInterfaceAssets.h"
#import "TGInterfaceManager.h"

#import "TGApplication.h"

#import "TGTableView.h"
#import "TGRemoteImageView.h"
#import "TGToolbarButton.h"

#import "TGImageViewController.h"
#import "TGTelegraphProfileImageViewCompanion.h"

#import "TGTelegraph.h"

#import "TGDatabase.h"

#import "TGDateUtils.h"
#import "TGImageUtils.h"

#import "TGSwitchView.h"

#import "TGHighlightableButton.h"

#import "TGContactsController.h"

#import "TGMenuSection.h"
#import "TGContactMediaItem.h"
#import "TGUserMenuItem.h"

#import "TGActionMenuItemCell.h"
#import "TGSwitchItemCell.h"
#import "TGPhoneItemCell.h"
#import "TGContactMediaItemCell.h"
#import "TGButtonMenuItemCell.h"
#import "TGVariantMenuItemCell.h"

#import "TGButtonsMenuItem.h"
#import "TGButtonsMenuItemView.h"

#import "TGActivityIndicatorView.h"

#import "TGUserMenuItemCell.h"

#import "TGActionTableView.h"

#import "TGCustomNotificationController.h"

#import "TGAppDelegate.h"

#import "TGHacks.h"

#import "TGImageViewController.h"
#import "TGImagePickerController.h"
#import "TGImageSearchController.h"

#import "TGSession.h"

#import "TGProgressWindow.h"

#import <QuartzCore/QuartzCore.h>

#include <set>

#define TG_MEDIA_LIST_SHOW_IMAGES false

#define TG_USE_CUSTOM_CAMERA false

#define TGButtonsSectionTag ((int)0x26A2D355)

#define TGMembersSectionTag ((int)0x4E153930)
#define TGMediaSectionTag ((int)0x2174970e)

#define TGUserActionSheetTag ((int)0x53E8D5BD)
#define TGLeaveConversationActionSheetTag ((int)0x27BEF70E)
#define TGAvatarActionSheetTag ((int)0xF3AEE8CC)
#define TGDeletePhotoConfirmationActionSheetTag ((int)0x7BCC2A36)
#define TGImageSourceActionSheetTag ((int)0x34281CB0)

#define TGNotificationsTag ((int)0xDEC3ED0B)
#define TGSoundTag ((int)0x9CB3E5F6)
#define TGMediaListTag ((int)0x993241e)

#define TGGroupTypeTag ((int)0x596B9C0A)

#define TGAddMemberConfirmationAlertTag ((int)0x325fa79)

#if TG_USE_CUSTOM_CAMERA
#import "TGCameraWindow.h"
#endif

@interface TGSelectSingleContactController : TGContactsController

@property (nonatomic, strong) ASHandle *watcher;

@end

@implementation TGSelectSingleContactController

@synthesize watcher = _watcher;

- (void)loadView
{
    [super loadView];
    
    self.titleText = NSLocalizedString(@"ConversationProfile.AddMemberTitle", nil);
    self.backAction = @selector(performClose);
}

- (void)performClose
{
    [self.navigationController popViewControllerAnimated:true];
}

- (void)singleUserSelected:(TGUser *)user
{
    [_watcher requestAction:@"contactSelected" options:[[NSDictionary alloc] initWithObjectsAndKeys:[NSNumber numberWithInt:user.uid], @"uid", nil]];
}

@end

#pragma mark -

@interface TGTelegraphConversationProfileController () <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate, UIActionSheetDelegate, UIGestureRecognizerDelegate, TGActionTableViewDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate, TGImagePickerControllerDelegate, UIAlertViewDelegate>
{
    std::set<int> _usersWithActionInProgress;
}

@property (nonatomic, strong) TGConversation *conversation;

@property (nonatomic, strong) NSMutableArray *sectionList;

@property (nonatomic, strong) UIView *leftChatContainer;
@property (nonatomic, strong) UILabel *kickedFromChatLabel;
@property (nonatomic, strong) UIActivityIndicatorView *returnToChatButtonIndicator;

@property (nonatomic) bool appearAnimation;

@property (nonatomic, strong) TGActionTableView *tableView;

@property (nonatomic, strong) UIView *headerView;
@property (nonatomic, strong) UIView *headerViewContents;
@property (nonatomic, strong) UIButton *addPhotoButton;
@property (nonatomic, strong) TGRemoteImageView *avatarView;
@property (nonatomic, strong) UIView *avatarViewEdit;
@property (nonatomic, strong) UIImageView *avatarActivityOverlay;
@property (nonatomic, strong) TGActivityIndicatorView *avatarActivityIndicator;

@property (nonatomic, strong) UILabel *conversationTitleLabel;
@property (nonatomic, strong) UILabel *conversationSubtitleLabel;
@property (nonatomic, strong) UIImageView *conversationTitleFieldBackground;
@property (nonatomic, strong) UITextField *conversationTitleField;

@property (nonatomic, strong) TGMenuSection *buttonsSection;

@property (nonatomic, strong) TGMenuSection *mediaSection;

@property (nonatomic) bool mediaListLoading;
@property (nonatomic) int mediaListTotalCount;

#if TG_MEDIA_LIST_SHOW_IMAGES
@property (nonatomic, strong) NSMutableArray *mediaList;
@property (nonatomic, strong) TGMediaListView *mediaListView;
#endif

@property (nonatomic, strong) TGSwitchItem *notificationsMenuItem;
@property (nonatomic, strong) TGVariantMenuItem *customSoundMenuItem;
@property (nonatomic, strong) TGContactMediaItem *mediaItem;

@property (nonatomic, strong) TGSelectSingleContactController *contactsController;

@property (nonatomic) int actionSheetUid;

#if TG_USE_CUSTOM_CAMERA
@property (nonatomic, strong) TGCameraWindow *cameraWindow;
#endif

@property (nonatomic, strong) UIImage *currentUploadingImage;
@property (nonatomic) bool updatingAvatar;

@property (nonatomic, strong) NSString *currentUpdatingTitle;
@property (nonatomic) bool updatingTitle;

@property (nonatomic, strong) NSMutableDictionary *peerNotificationSettings;

@property (nonatomic) NSTimeInterval lastListUpdateDate;

@property (nonatomic, strong) UIActionSheet *currentActionSheet;
@property (nonatomic, strong) UIAlertView *currentAlertView;

@property (nonatomic, strong) TGProgressWindow *progressWindow;

@property (nonatomic) bool createChatBroadcast;

@property (nonatomic, strong) NSData *createChatPhotoData;
@property (nonatomic, strong) UIImage *createChatPhotoThumbnail;

@property (nonatomic) bool allUsersAreNotEditable;

@property (nonatomic) bool isEncrypted;

@end

@implementation TGTelegraphConversationProfileController

- (id)initWithConversation:(TGConversation *)conversation
{
    self = [super initWithNibName:nil bundle:nil];
    if (self)
    {
        _isEncrypted = conversation.isEncrypted;
        
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:true];
        
        _sectionList = [[NSMutableArray alloc] init];
        
        _peerNotificationSettings = [[NSMutableDictionary alloc] init];
        
        _mediaSection = [[TGMenuSection alloc] init];
        _mediaSection.tag = TGMediaSectionTag;
        [_sectionList addObject:_mediaSection];
        
        _notificationsMenuItem = [[TGSwitchItem alloc] init];
        _notificationsMenuItem.title = TGLocalized(@"ConversationProfile.Notifications");
        _notificationsMenuItem.tag = TGNotificationsTag;
        _notificationsMenuItem.isOn = true;
        [_mediaSection.items addObject:_notificationsMenuItem];
        
        _mediaItem = [[TGContactMediaItem alloc] init];
        _mediaItem.tag = TGMediaListTag;
        [_mediaSection.items addObject:_mediaItem];
        
        _customSoundMenuItem = [[TGVariantMenuItem alloc] init];
        _customSoundMenuItem.title = TGLocalized(@"ConversationProfile.Sound");
        _customSoundMenuItem.tag = TGSoundTag;
        _customSoundMenuItem.action = @selector(customSoundPressed);
        _customSoundMenuItem.variant = TGLocalized(@"ConversationProfile.DefaultSound");
        
#if TG_MEDIA_LIST_SHOW_IMAGES
        _mediaList = [[NSMutableArray alloc] init];
#endif
        
        _buttonsSection = [[TGMenuSection alloc] init];
        _buttonsSection.tag = TGButtonsSectionTag;
        [_sectionList addObject:_buttonsSection];
        
        TGButtonsMenuItem *buttonsItem = [[TGButtonsMenuItem alloc] init];
        buttonsItem.buttons = @[
            @{@"title": TGLocalized(@"ConversationProfile.AddMemberButton"),
              @"disabled": @(false),
              @"action": @"addMember"},
            @{@"title": TGLocalized(@"ConversationProfile.LeaveGroupButton"),
              @"disabled": @(false),
              @"action": @"leaveGroup"},
        ];
        [_buttonsSection.items addObject:buttonsItem];
        
        TGMenuSection *membersSection = [[TGMenuSection alloc] init];
        membersSection.tag = TGMembersSectionTag;
        [_sectionList addObject:membersSection];
        
        [self chatInfoChanged:conversation];
        
        [ActionStageInstance() dispatchOnStageQueue:^
        {
            [ActionStageInstance() watchForPath:@"/tg/userdatachanges" watcher:self];
            [ActionStageInstance() watchForPath:@"/tg/userpresencechanges" watcher:self];
            [ActionStageInstance() watchForPath:@"/as/updateRelativeTimestamps" watcher:self];
            
            NSArray *addActions = [ActionStageInstance() rejoinActionsWithGenericPathNow:@"/tg/conversation/@/addMember/@" prefix:[NSString stringWithFormat:@"/tg/conversation/(%lld)", conversation.conversationId] watcher:self];
            NSArray *deleteActions = [ActionStageInstance() rejoinActionsWithGenericPathNow:@"/tg/conversation/@/deleteMember/@" prefix:[NSString stringWithFormat:@"/tg/conversation/(%lld)", conversation.conversationId] watcher:self];
            
            dispatch_async(dispatch_get_main_queue(), ^
            {
                for (NSString *action in addActions)
                {
                    NSRange range = [action rangeOfString:@"/addMember/("];
                    int uid = [[action substringFromIndex:(range.location + range.length)] intValue];
                    _usersWithActionInProgress.insert(uid);
                }
                
                for (NSString *action in deleteActions)
                {
                    NSRange range = [action rangeOfString:@"/deleteMember/("];
                    int uid = [[action substringFromIndex:(range.location + range.length)] intValue];
                    _usersWithActionInProgress.insert(uid);
                }
                
                for (UITableViewCell *cell in _tableView.visibleCells)
                {
                    if ([cell isKindOfClass:[TGUserMenuItemCell class]])
                    {
                        TGUserMenuItemCell *userCell = (TGUserMenuItemCell *)cell;
                        if (_usersWithActionInProgress.find(userCell.uid) != _usersWithActionInProgress.end() && !userCell.isDisabled)
                        {
                            [userCell setIsDisabled:true];
                        }
                    }
                }
            });
            
            NSArray *changeAvatarActions = [ActionStageInstance() rejoinActionsWithGenericPathNow:@"/tg/conversation/@/updateAvatar/@" prefix:[NSString stringWithFormat:@"/tg/conversation/(%lld)", conversation.conversationId] watcher:self];
            if (changeAvatarActions.count != 0)
            {
                TGConversationChangePhotoActor *changePhotoActor = (TGConversationChangePhotoActor *)[ActionStageInstance() executingActorWithPath:[changeAvatarActions lastObject]];
                if (changePhotoActor != nil)
                {
                    UIImage *currentImage = changePhotoActor.currentImage;
                    dispatch_async(dispatch_get_main_queue(), ^
                    {
                        _currentUploadingImage = currentImage;
                        _updatingAvatar = true;
                        
                        if (self.isViewLoaded)
                        {
                            if (currentImage != nil)
                            {
                                [_avatarView loadImage:currentImage];
                                _addPhotoButton.hidden = true;
                                _avatarViewEdit.hidden = false;
                            }
                            
                            [self setShowAvatarActivity:true animated:false];
                        }
                    });
                }
            }
            
            NSArray *changeTitleActions = [ActionStageInstance() rejoinActionsWithGenericPathNow:@"/tg/conversation/@/changeTitle/@" prefix:[NSString stringWithFormat:@"/tg/conversation/(%lld)", conversation.conversationId] watcher:self];
            if (changeTitleActions.count != 0)
            {
                TGConversationChangeTitleRequestActor *changeTitleActor = (TGConversationChangeTitleRequestActor *)[ActionStageInstance() executingActorWithPath:[changeTitleActions lastObject]];
                if (changeTitleActor != nil)
                {
                    NSString *currentTitle = changeTitleActor.currentTitle;
                    dispatch_async(dispatch_get_main_queue(), ^
                    {
                        _currentUpdatingTitle = currentTitle;
                        _updatingTitle = true;
                        
                        if (self.isViewLoaded)
                        {
                            _conversationTitleField.text = currentTitle;
                            _conversationTitleField.userInteractionEnabled = false;
                            _conversationTitleField.textColor = UIColorRGB(0x888888);
                            
                            _conversationTitleLabel.text = currentTitle;
                            _conversationTitleLabel.textColor = UIColorRGB(0x66727f);
                        }
                    });
                }
            }
        }];
    }
    return self;
}

- (id)initWithCreateChat
{
    self = [super init];
    if (self != nil)
    {
        _createChat = true;
        
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:true];
        
        _sectionList = [[NSMutableArray alloc] init];
        
        TGMenuSection *membersSection = [[TGMenuSection alloc] init];
        membersSection.tag = TGMembersSectionTag;
        [_sectionList addObject:membersSection];
        
        TGMenuSection *typeSection = [[TGMenuSection alloc] init];
        [_sectionList addObject:typeSection];
    }
    return self;
}

- (void)dealloc
{
    [_actionHandle reset];
    [ActionStageInstance() removeWatcher:self];
    
    [self doUnloadView];
    
    _currentActionSheet.delegate = nil;
    _currentAlertView.delegate = nil;
}

- (bool)shouldBeRemovedFromNavigationAfterHiding
{
    return _createChat;
}

- (void)loadView
{
    [super loadView];
    
    float retinaPixel = TGIsRetina() ? 0.5f : 0.0f;
    
    self.titleText = _createChat ? TGLocalized(@"Compose.NewGroup") : TGLocalized(@"ConversationProfile.Title");
    
    _tableView = [[TGActionTableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.opaque = true;
    _tableView.backgroundColor = nil;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.backgroundView = nil;
    _tableView.allowsSelectionDuringEditing = true;
    [self.view addSubview:_tableView];
    
    _headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, _createChat ? 59 : 89)];
    _headerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _headerView.backgroundColor = nil;
    _headerView.opaque = false;
    _tableView.tableHeaderView = _headerView;
    _tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 1, 7)];
    
    _headerViewContents = [[UIView alloc] initWithFrame:_headerView.bounds];
    _headerViewContents.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [_headerView addSubview:_headerViewContents];
    
    _avatarView = [[TGRemoteImageView alloc] initWithFrame:CGRectMake(9, 14, 70, 70)];
    _avatarView.fadeTransition = true;
    [_headerViewContents addSubview:_avatarView];
    
    if (_avatarViewEdit == nil)
    {
        UIImage *rawEditImage = [UIImage imageNamed:@"SettingsProfileAvatarEditBackground.png"];
        _avatarViewEdit = [[UIImageView alloc] initWithImage:[rawEditImage stretchableImageWithLeftCapWidth:(int)(rawEditImage.size.width / 2) topCapHeight:0]];
        _avatarViewEdit.frame = CGRectMake(1, _avatarView.frame.size.height - _avatarViewEdit.frame.size.height - 1, _avatarView.frame.size.width - 2, _avatarViewEdit.frame.size.height);
        _avatarViewEdit.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
        [_avatarView addSubview:_avatarViewEdit];
        
        UILabel *editLabel = [[UILabel alloc] init];
        editLabel.text = TGLocalized(@"Common.edit");
        editLabel.backgroundColor = [UIColor clearColor];
        editLabel.textColor = [UIColor whiteColor];
        editLabel.font = [UIFont boldSystemFontOfSize:13];
        [editLabel sizeToFit];
        editLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        editLabel.frame = CGRectOffset(editLabel.frame, floorf((_avatarViewEdit.frame.size.width - editLabel.frame.size.width) / 2), 0);
        [_avatarViewEdit addSubview:editLabel];
    }
    
    _avatarViewEdit.alpha = 0.0f;
    
    [_avatarView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(avatarTapped:)]];
    
    CGRect addPhotoButtonFrame = _avatarView.frame;
    _addPhotoButton = [[TGHighlightableButton alloc] initWithFrame:addPhotoButtonFrame];
    _addPhotoButton.exclusiveTouch = true;
    
    UIImage *rawAddPhoto = [UIImage imageNamed:@"ProfilePhotoPlaceholder.png"];
    UIImage *rawAddPhotoHighlighted = [UIImage imageNamed:@"ProfilePhotoPlaceholder_Highlighted.png"];
    
    [_addPhotoButton setBackgroundImage:[rawAddPhoto stretchableImageWithLeftCapWidth:(int)(rawAddPhoto.size.width / 2) topCapHeight:0] forState:UIControlStateNormal];
    [_addPhotoButton setBackgroundImage:[rawAddPhotoHighlighted stretchableImageWithLeftCapWidth:(int)(rawAddPhotoHighlighted.size.width / 2) topCapHeight:0] forState:UIControlStateHighlighted];
    [_addPhotoButton addTarget:self action:@selector(addPhotoButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    [_headerViewContents insertSubview:_addPhotoButton belowSubview:_avatarView];
    
    UILabel *addPhotoLabelFirst = [[UILabel alloc] init];
    addPhotoLabelFirst.text = TGLocalized(@"ConversationProfile.PhotoAdd");
    addPhotoLabelFirst.font = [UIFont boldSystemFontOfSize:14 + retinaPixel];
    addPhotoLabelFirst.backgroundColor = [UIColor clearColor];
    addPhotoLabelFirst.textColor = [UIColor whiteColor];
    addPhotoLabelFirst.shadowColor = UIColorRGBA(0x47586c, 0.5f);
    addPhotoLabelFirst.shadowOffset = CGSizeMake(0, -1);
    [addPhotoLabelFirst sizeToFit];
    
    UILabel *addPhotoLabelSecond = [[UILabel alloc] init];
    addPhotoLabelSecond.text = TGLocalized(@"ConversationProfile.PhotoPhoto");
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
    
    UIImage *rawImage = [UIImage imageNamed:@"AddPhotoMask.png"];
    _avatarActivityOverlay = [[UIImageView alloc] initWithImage:[rawImage stretchableImageWithLeftCapWidth:(int)(rawImage.size.width / 2) topCapHeight:(int)(rawImage.size.height / 2)]];
    _avatarActivityOverlay.userInteractionEnabled = false;
    _avatarActivityOverlay.frame = CGRectMake(_avatarView.frame.origin.x + retinaPixel, _avatarView.frame.origin.y, 69, 69);
    [_headerViewContents addSubview:_avatarActivityOverlay];
    _avatarActivityOverlay.hidden = true;
    _avatarActivityOverlay.alpha = 0.0f;
    
    _avatarActivityIndicator = [[TGActivityIndicatorView alloc] initWithStyle:TGActivityIndicatorViewStyleSmallWhite];
    _avatarActivityIndicator.frame = CGRectOffset(_avatarActivityIndicator.frame, _avatarView.frame.origin.x + 27 + retinaPixel, _avatarView.frame.origin.y + 28);
    [_headerViewContents addSubview:_avatarActivityIndicator];
    _avatarActivityIndicator.hidden = true;
    _avatarActivityIndicator.alpha = 0.0f;
    [_avatarActivityIndicator stopAnimating];
    
    if (_createChat)
    {
        _avatarView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        _addPhotoButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        _avatarActivityOverlay.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        _avatarActivityIndicator.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;;
    }
    
    _conversationTitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(92, 24, self.view.frame.size.width - 92 - 9, 24)];
    _conversationTitleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _conversationTitleLabel.backgroundColor = [UIColor clearColor];
    _conversationTitleLabel.textColor = UIColorRGB(0x222932);
    _conversationTitleLabel.shadowColor = UIColorRGBA(0xedf0f5, 0.28f);
    _conversationTitleLabel.shadowOffset = CGSizeMake(0, 1);
    _conversationTitleLabel.font = [UIFont boldSystemFontOfSize:19];
    [_headerViewContents addSubview:_conversationTitleLabel];
    
    _conversationSubtitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(93, 49 + retinaPixel, self.view.frame.size.width - 92 - 9, 24)];
    _conversationSubtitleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _conversationSubtitleLabel.backgroundColor = [UIColor clearColor];
    _conversationSubtitleLabel.textColor = UIColorRGB(0x6d7d90);
    _conversationSubtitleLabel.shadowColor = UIColorRGBA(0xedf0f5, 0.28f);
    _conversationSubtitleLabel.shadowOffset = CGSizeMake(0, 1);
    _conversationSubtitleLabel.font = [UIFont systemFontOfSize:14];
    [_headerViewContents addSubview:_conversationSubtitleLabel];
    
    _conversationTitleFieldBackground = [[UIImageView alloc] initWithImage:[TGInterfaceAssets groupedCellSingle]];
    _conversationTitleFieldBackground.frame = _createChat ? CGRectMake(9, 14, self.view.frame.size.width - 9 * 2, 44) : CGRectMake(89, 14, self.view.frame.size.width - 89 - 9, 44);
    _conversationTitleFieldBackground.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _conversationTitleFieldBackground.userInteractionEnabled = true;
    [_conversationTitleFieldBackground addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(focusOnTitleField:)]];
    _conversationTitleFieldBackground.hidden = true;
    _conversationTitleFieldBackground.alpha = 0.0f;
    [_headerViewContents addSubview:_conversationTitleFieldBackground];
    
    _conversationTitleField = [[UITextField alloc] initWithFrame:CGRectOffset(CGRectInset(_conversationTitleFieldBackground.frame, 12, 10), 0, 1)];
    _conversationTitleField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _conversationTitleField.font = [UIFont boldSystemFontOfSize:16];
    _conversationTitleField.delegate = self;
    _conversationTitleField.returnKeyType = UIReturnKeyDone;
    _conversationTitleField.hidden = true;
    _conversationTitleField.alpha = 0.0f;
    _conversationTitleField.placeholder = TGLocalized(@"ConversationProfile.GroupName");
    [TGHacks setTextFieldPlaceholderColor:_conversationTitleField color:UIColorRGB(0x8d98a6)];
    [_headerViewContents addSubview:_conversationTitleField];
    
    if (_createChat)
    {
        [_avatarView removeFromSuperview];
        [_addPhotoButton removeFromSuperview];
        [_avatarActivityIndicator removeFromSuperview];
        [_avatarActivityOverlay removeFromSuperview];
    }
    
    self.view.backgroundColor = [[TGInterfaceAssets instance] linesBackground];
    
#if TG_MEDIA_LIST_SHOW_IMAGES
    _mediaListView = [[TGMediaListView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
    _mediaListView.watcherHandle = _actionHandle;
#endif
    
    if (!_createChat)
        [self updateTitle];
    else
        _avatarView.userInteractionEnabled = false;
    
    if (_updatingAvatar)
    {
        if (_currentUploadingImage != nil)
        {
            [_avatarView loadImage:_currentUploadingImage];
            _addPhotoButton.hidden = true;
            _avatarViewEdit.hidden = true;
        }
        
        _avatarActivityIndicator.hidden = false;
        [_avatarActivityIndicator startAnimating];
        
        _avatarActivityOverlay.hidden = false;
        _avatarActivityOverlay.alpha = 1.0f;
    }
    
    if (_updatingTitle)
    {
        _conversationTitleField.text = _currentUpdatingTitle;
        _conversationTitleField.userInteractionEnabled = false;
        _conversationTitleField.textColor = UIColorRGB(0x888888);
        
        _conversationTitleLabel.text = _currentUpdatingTitle;
        _conversationTitleLabel.textColor = UIColorRGB(0x66727f);
    }
    
    UISwipeGestureRecognizer *rightSwipeRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(tableViewSwiped:)];
    rightSwipeRecognizer.direction = UISwipeGestureRecognizerDirectionRight;
    [_tableView addGestureRecognizer:rightSwipeRecognizer];
    rightSwipeRecognizer.delegate = self;
    
    [self updateEditingState:false explicitState:_createChat];
}

- (void)doUnloadView
{
    _tableView.delegate = nil;
    _tableView.dataSource = nil;
    _tableView = nil;
    _conversationTitleField.delegate = nil;
}

- (void)viewDidUnload
{
    [super viewDidUnload];
}

- (void)performClose
{
    [self.navigationController popViewControllerAnimated:true];
}

- (void)tableViewSwiped:(UISwipeGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateRecognized)
    {
        if (recognizer.direction == UISwipeGestureRecognizerDirectionRight)
            [self performClose];
    }
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
        
        _avatarViewEdit.hidden = true;
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
        
        _avatarViewEdit.hidden = _avatarView.currentUrl != nil;
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    _appearAnimation = true;
    
    if ([_tableView indexPathForSelectedRow] != nil)
    {
        [_tableView deselectRowAtIndexPath:[_tableView indexPathForSelectedRow] animated:animated];
    }
    
    if (_activateTitleChange)
    {
        _activateTitleChange = false;
        [_conversationTitleField becomeFirstResponder];
    }
    
    [self updateInterface:self.interfaceOrientation];
    
    if (_createChat)
    {
        [_conversationTitleField becomeFirstResponder];
    }
    
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    _appearAnimation = false;
    
    if (_activateCamera)
    {
        _activatedCamera = true;
        [self showCamera];
    }
    
    [super viewDidAppear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return toInterfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
}

- (BOOL)shouldAutorotate
{
    return true;
}

- (void)updateInterface:(UIInterfaceOrientation)__unused orientation
{
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [self updateInterface:toInterfaceOrientation];
    
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
}

#pragma mark -

- (void)setCreateChatParticipants:(NSArray *)participants
{
    for (TGMenuSection *section in _sectionList)
    {
        if (section.tag == TGMembersSectionTag)
        {
            [section.items removeAllObjects];
            for (TGUser *user in participants)
            {
                TGUserMenuItem *userItem = [[TGUserMenuItem alloc] init];
                userItem.user = user;
                [section.items addObject:userItem];
            }
            
            break;
        }
    }
    
    if (self.isViewLoaded)
        [_tableView reloadData];
}

- (void)updateUserSortingAutomatic
{
    NSUInteger sectionIndex = [self sectionIndexForTag:TGMembersSectionTag];
    if (sectionIndex != NSNotFound)
    {
        TGMenuSection *membersSection = [_sectionList objectAtIndex:sectionIndex];
        
        NSArray *array = [self updateUsersSortingInArray:membersSection.items];
        
        bool isChanged = false;
        
        for (int i = 0; i < (int)array.count; i++)
        {
            if (((TGUserMenuItem *)membersSection.items[i]).user.uid != ((TGUserMenuItem *)array[i]).user.uid)
            {
                isChanged = true;
                break;
            }
        }
        
        if (isChanged)
        {
            membersSection.items = [array mutableCopy];
            
            [_tableView reloadData];
        }
    }
}

- (NSArray *)updateUsersSortingInArray:(NSArray *)currentArray
{
    NSDictionary *invitedDates = _conversation.chatParticipants.chatInvitedDates;
    
    NSArray *array = [currentArray sortedArrayUsingComparator:^NSComparisonResult(TGUserMenuItem *item1, TGUserMenuItem *item2)
    {
        TGUser *user1 = item1.user;
        TGUser *user2 = item2.user;
        
        if (user1.presence.online != user2.presence.online)
            return user1.presence.online ? NSOrderedAscending : NSOrderedDescending;
        
        if ((user1.presence.lastSeen < 0) != (user2.presence.lastSeen < 0))
            return user1.presence.lastSeen >= 0 ? NSOrderedAscending : NSOrderedDescending;
        
        if (user1.presence.online)
        {
            NSNumber *nDate1 = invitedDates[[[NSNumber alloc] initWithInt:user1.uid]];
            NSNumber *nDate2 = invitedDates[[[NSNumber alloc] initWithInt:user2.uid]];
            
            if (nDate1 != nil && nDate2 != nil)
                return [nDate1 intValue] < [nDate2 intValue] ? NSOrderedAscending : NSOrderedDescending;
            else
                return user1.uid < user2.uid ? NSOrderedAscending : NSOrderedDescending;
        }
        
        if (user1.presence.lastSeen < 0)
        {
            NSNumber *nDate1 = invitedDates[[[NSNumber alloc] initWithInt:user1.uid]];
            NSNumber *nDate2 = invitedDates[[[NSNumber alloc] initWithInt:user2.uid]];
            
            if (nDate1 != nil && nDate2 != nil)
                return [nDate1 intValue] < [nDate2 intValue] ? NSOrderedAscending : NSOrderedDescending;
            else
                return user1.uid < user2.uid ? NSOrderedAscending : NSOrderedDescending;
        }
        
        return user1.presence.lastSeen > user2.presence.lastSeen ? NSOrderedAscending : NSOrderedDescending;
    }];
        
    return array;
}

- (void)updateEditableStates
{
    bool newAllUsersAreNotEditable = true;
    
    for (TGMenuSection *section in _sectionList)
    {
        if (section.tag == TGMembersSectionTag)
        {
            for (TGUserMenuItem *userItem in section.items)
            {
                TGUser *user = userItem.user;
                
                bool isWithAction = _usersWithActionInProgress.find(user.uid) != _usersWithActionInProgress.end();
                
                bool editable = false;
                
                if (isWithAction)
                    editable = true;
                else
                {
                    if (user.uid == TGTelegraphInstance.clientUserId)
                        editable = false;
                    else if (_conversation.chatParticipants.chatAdminId == TGTelegraphInstance.clientUserId)
                        editable = true;
                    else
                    {
                        NSNumber *nInviterUid = [_conversation.chatParticipants.chatInvitedBy objectForKey:[NSNumber numberWithInt:user.uid]];
                        if (nInviterUid != nil && [nInviterUid intValue] == TGTelegraphInstance.clientUserId)
                            editable = true;
                        else
                            editable = false;
                    }
                }
                
                if (editable)
                {
                    newAllUsersAreNotEditable = false;
                    break;
                }
            }
            
            break;
        }
    }
    
    if (newAllUsersAreNotEditable != _allUsersAreNotEditable)
    {
        _allUsersAreNotEditable = newAllUsersAreNotEditable;
        
        for (UITableViewCell *cell in _tableView.visibleCells)
        {
            if ([cell isKindOfClass:[TGUserMenuItemCell class]])
            {
                TGUserMenuItemCell *userCell = (TGUserMenuItemCell *)cell;
                userCell.alwaysNonEditable = _allUsersAreNotEditable;
                [userCell updateEditable:true];
            }
        }
    }
}

- (void)chatInfoChanged:(TGConversation *)conversation
{
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        TGMenuSection *membersSection = nil;
        
        membersSection = [[TGMenuSection alloc] init];
        membersSection.tag = TGMembersSectionTag;
        int creatorUid = conversation.chatParticipants.chatAdminId;
        
        NSArray *participantUids = [conversation.chatParticipants.chatParticipantUids sortedArrayUsingComparator:^NSComparisonResult(NSNumber *nUid1, NSNumber *nUid2)
        {
            if ([nUid1 intValue] == creatorUid)
                return NSOrderedAscending;
            else if ([nUid2 intValue] == creatorUid)
                return NSOrderedDescending;
            
            NSNumber *nDate1 = [conversation.chatParticipants.chatInvitedDates objectForKey:nUid1];
            NSNumber *nDate2 = [conversation.chatParticipants.chatInvitedDates objectForKey:nUid2];
            
            return [nDate1 compare:nDate2];
        }];
        
        NSMutableArray *newUsers = [[NSMutableArray alloc] init];
        for (NSNumber *nUid in participantUids)
        {
            TGUser *user = [TGDatabaseInstance() loadUser:[nUid intValue]];
            if (user != nil)
            {
                TGUserMenuItem *userItem = [[TGUserMenuItem alloc] init];
                userItem.user = user;
                [membersSection.items addObject:userItem];
                [newUsers addObject:user];
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^
        {
            NSDictionary *lastInvitedBy = _conversation.chatParticipants.chatInvitedBy;
            
            bool versionUpdated = false;
            
            if (_conversation == nil)
            {
                versionUpdated = true;
                _mediaListLoading = true;
                
                for (UITableViewCell *cell in _tableView.visibleCells)
                {
                    if ([cell isKindOfClass:[TGContactMediaItemCell class]])
                    {
                        [(TGContactMediaItemCell *)cell setIsLoading:_mediaListLoading];
                        break;
                    }
                }
                
                [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/conversations/(%lld)/mediahistory/(0)", conversation.conversationId] options:[[NSDictionary alloc] initWithObjectsAndKeys:[NSNumber numberWithInt:5], @"limit", @(_isEncrypted), @"isEncrypted", nil] watcher:self];
                [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/peerSettings/(%lld,cached)", conversation.conversationId] options:[NSDictionary dictionaryWithObject:[NSNumber numberWithLongLong:conversation.conversationId] forKey:@"peerId"] watcher:self];
            }
            else
            {
                versionUpdated = _conversation.chatParticipants == nil || conversation.chatParticipants.version > _conversation.chatParticipants.version;
            }
            
            _conversation = conversation;
            
            if (_contactsController != nil)
                _contactsController.disabledUsers = [_conversation.chatParticipants.chatParticipantUids copy];
            
            std::set<int> newUids;
            std::set<int> currentUids;
            
            int sectionIndex = -1;
            for (TGMenuSection *section in _sectionList)
            {
                sectionIndex++;
                if (section.tag == TGMembersSectionTag)
                {
                    for (TGMenuItem *item in section.items)
                    {
                        if (item.type == TGUserMenuItemType)
                            currentUids.insert(((TGUserMenuItem *)item).user.uid);
                    }
                    
                    break;
                }
            }
            
            for (TGUser *user in newUsers)
            {
                newUids.insert(user.uid);
            }
            
            bool listUpdated = currentUids != newUids;
            
            if (listUpdated && versionUpdated)
            {
                dispatch_block_t block = ^
                {
                    _lastListUpdateDate = CFAbsoluteTimeGetCurrent();
                    
                    for (int i = 0; i < (int)_sectionList.count; i++)
                    {
                        TGMenuSection *section = [_sectionList objectAtIndex:i];
                        if (section.tag == TGMembersSectionTag)
                        {
                            membersSection.items = [[self updateUsersSortingInArray:membersSection.items] mutableCopy];
                            
                            [_sectionList replaceObjectAtIndex:i withObject:membersSection];
                            
                            bool animationsWereEnabled = [UIView areAnimationsEnabled];
                            [UIView setAnimationsEnabled:false];
                            [_tableView reloadSections:[NSIndexSet indexSetWithIndex:i] withRowAnimation:UITableViewRowAnimationNone];
                            [UIView setAnimationsEnabled:animationsWereEnabled];
                            break;
                        }
                    }
                    
                    [self updateEditableStates];
                };
                
                if (CFAbsoluteTimeGetCurrent() - _lastListUpdateDate > 0.301)
                    block();
                else
                {
                    CFAbsoluteTime sleepTime = MAX(0, MIN(0.301, 0.301 - (CFAbsoluteTimeGetCurrent() - _lastListUpdateDate)));
                    
                    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(sleepTime * NSEC_PER_SEC));
                    dispatch_after(popTime, dispatch_get_main_queue(), block);
                }
            }
            
            if (!listUpdated && versionUpdated)
            {
                std::set<int> changedInvitations;
                
                NSDictionary *currentInvitedBy = _conversation.chatParticipants.chatInvitedBy;
                for (NSNumber *nUid in _conversation.chatParticipants.chatParticipantUids)
                {
                    NSNumber *nInvitedBy1 = [lastInvitedBy objectForKey:nUid];
                    NSNumber *nInvitedBy2 = [currentInvitedBy objectForKey:nUid];
                    if ((nInvitedBy1 != nil) != (nInvitedBy2 != nil) || (nInvitedBy1 != nil && ![nInvitedBy1 isEqualToNumber:nInvitedBy2]))
                    {
                        changedInvitations.insert([nUid intValue]);
                    }
                }
                
                if (!changedInvitations.empty())
                {
                    for (UITableViewCell *cell in _tableView.visibleCells)
                    {
                        if ([cell isKindOfClass:[TGUserMenuItemCell class]])
                        {
                            TGUserMenuItemCell *userCell = (TGUserMenuItemCell *)cell;
                            if (changedInvitations.find(userCell.uid) != changedInvitations.end())
                            {
                                if (userCell.uid == TGTelegraphInstance.clientUserId)
                                    userCell.editable = false;
                                else if (_conversation.chatParticipants.chatAdminId == TGTelegraphInstance.clientUserId)
                                    userCell.editable = true;
                                else
                                {
                                    NSNumber *nInviterUid = [_conversation.chatParticipants.chatInvitedBy objectForKey:[NSNumber numberWithInt:userCell.uid]];
                                    if (nInviterUid != nil && [nInviterUid intValue] == TGTelegraphInstance.clientUserId)
                                        userCell.editable = true;
                                    else
                                        userCell.editable = false;
                                }
                                
                                [userCell updateEditable];
                            }
                        }
                    }
                }
            }
            
            [self updateTitle];
            [self updateEditableStates];
        });
    }];
}

- (void)updateTitle
{
    if (!_conversationTitleField.isFirstResponder)
    {
        _conversationTitleField.text = _conversation.chatTitle;
        _conversationTitleLabel.text = _conversation.chatTitle;
    }
    
    if (_conversation.chatPhotoSmall != nil && _conversation.chatPhotoSmall.length != 0)
    {
        if (_avatarView.currentUrl == nil || ![_avatarView.currentUrl isEqualToString:_conversation.chatPhotoSmall])
            [_avatarView loadImage:_conversation.chatPhotoSmall filter:@"profileAvatar" placeholder:[TGInterfaceAssets profileGroupAvatarPlaceholder]];
        _addPhotoButton.hidden = true;
        _avatarViewEdit.hidden = false;
        _avatarView.userInteractionEnabled = true;
    }
    else
    {
        [_avatarView loadImage:nil];
        _addPhotoButton.hidden = false;
        _avatarViewEdit.hidden = true;
        _avatarView.userInteractionEnabled = false;
    }

    int participantCount = _conversation.chatParticipantCount;
    _conversationSubtitleLabel.text = [[NSString alloc] initWithFormat:@"%d %s", participantCount, participantCount == 1 ? "member" : "members"];
    
    if (_conversation.leftChat || _conversation.kickedFromChat)
    {
        self.navigationItem.rightBarButtonItem.customView.alpha = 0.0f;
        
        if (_leftChatContainer == nil)
        {
            _leftChatContainer = [[UIView alloc] initWithFrame:self.view.bounds];
            _leftChatContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            _leftChatContainer.backgroundColor = [[TGInterfaceAssets instance] linesBackground];
            
            _kickedFromChatLabel = [[UILabel alloc] initWithFrame:CGRectZero];
            _kickedFromChatLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
            _kickedFromChatLabel.text = NSLocalizedString(@"ConversationProfile.KickedFromChat", nil);
            _kickedFromChatLabel.backgroundColor = [UIColor clearColor];
            _kickedFromChatLabel.font = [UIFont boldSystemFontOfSize:15];
            _kickedFromChatLabel.textColor = UIColorRGB(0x697487);
            _kickedFromChatLabel.shadowColor = UIColorRGBA(0xffffff, 0.7f);
            _kickedFromChatLabel.shadowOffset = CGSizeMake(0, 1);
            [_leftChatContainer addSubview:_kickedFromChatLabel];
            
            [self.view addSubview:_leftChatContainer];
        }
        
        _leftChatContainer.hidden = false;
        _leftChatContainer.alpha = 1.0f;
        
        if (_conversation.kickedFromChat)
        {
            _kickedFromChatLabel.text = NSLocalizedString(@"ConversationProfile.KickedFromChat", nil);
        }
        else
        {
            _kickedFromChatLabel.text = NSLocalizedString(@"ConversationProfile.LeftChat", nil);
            if (_usersWithActionInProgress.find(TGTelegraphInstance.clientUserId) == _usersWithActionInProgress.end())
            {
                _returnToChatButtonIndicator.hidden = true;
                [_returnToChatButtonIndicator stopAnimating];
            }
            else
            {
                _returnToChatButtonIndicator.hidden = false;
                [_returnToChatButtonIndicator startAnimating];
            }
        }
        
        [_kickedFromChatLabel sizeToFit];
        _kickedFromChatLabel.frame = CGRectIntegral(CGRectMake((_leftChatContainer.frame.size.width - _kickedFromChatLabel.frame.size.width) / 2, (_leftChatContainer.frame.size.height - _kickedFromChatLabel.frame.size.height) / 2, _kickedFromChatLabel.frame.size.width, _kickedFromChatLabel.frame.size.height));
    }
    else
    {
        self.navigationItem.rightBarButtonItem.customView.alpha = 1.0f;
        
        if (_leftChatContainer != nil && !_leftChatContainer.hidden)
        {
            [UIView animateWithDuration:0.3 animations:^
            {
                _leftChatContainer.alpha = 0.0f;
            } completion:^(BOOL finished)
            {
                if (finished)
                    _leftChatContainer.hidden = true;
            }];
        }
    }
}

#pragma mark - Table

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
            
            if (item.type == TGActionMenuItemType || item.type == TGPhoneItemType || item.type == TGSwitchItemType || item.type == TGVariantMenuItemType)
                return 44;
            else if (item.type == TGButtonMenuItemType)
                return 45;
            else if (item.type == TGButtonsMenuItemType)
                return 43;
            else if (item.type == TGContactMediaItemType)
            {
#if TG_MEDIA_LIST_SHOW_IMAGES
                return _mediaList.count != 0 ? 145 : 44;
#else
                return 44;
#endif
            }
            else if (item.type == TGUserMenuItemType)
                return 49;
        }
    }
    
    return 0;
}

-(CGFloat)tableView:(UITableView*)__unused tableView heightForHeaderInSection:(NSInteger)__unused section
{
    return 8;
}

-(CGFloat)tableView:(UITableView*)__unused tableView heightForFooterInSection:(NSInteger)__unused section
{
    return 1;
}

static void updateGroupedCellBackground(TGGroupedCell *cell, bool firstInSection, bool lastInSection, bool animated)
{
    UIImage *newImage = nil;
    
    if (firstInSection && lastInSection)
    {
        [cell setGroupedCellPosition:TGGroupedCellPositionFirst | TGGroupedCellPositionLast];
        [cell setExtendSelectedBackground:false];
        
        newImage = [TGInterfaceAssets groupedCellSingle];
        ((UIImageView *)cell.selectedBackgroundView).image = [TGInterfaceAssets groupedCellSingleHighlighted];
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
    
    if (animated)
    {
        [UIView transitionWithView:cell.backgroundView duration:0.3 options:UIViewAnimationOptionTransitionCrossDissolve animations:^
        {
            ((UIImageView *)cell.backgroundView).image = newImage;
        } completion:nil];
    }
    else
    {
        ((UIImageView *)cell.backgroundView).image = newImage;
    }
    
    [cell setGroupedCellPosition:(firstInSection ? TGGroupedCellPositionFirst : 0) | (lastInSection ? TGGroupedCellPositionLast : 0)];
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
            if (indexPath.row + 1 == (int)section.items.count)
                lastInSection = true;
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
        if (item.type == TGButtonMenuItemType)
        {
            static NSString *buttonItemCellIdentifier = @"BI";
            TGButtonMenuItemCell *buttonItemCell = (TGButtonMenuItemCell *)[tableView dequeueReusableCellWithIdentifier:buttonItemCellIdentifier];
            if (buttonItemCell == nil)
            {
                buttonItemCell = [[TGButtonMenuItemCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:buttonItemCellIdentifier];
                
                UIImageView *backgroundView = [[UIImageView alloc] init];
                buttonItemCell.backgroundView = backgroundView;
                UIImageView *selectedBackgroundView = [[UIImageView alloc] init];
                buttonItemCell.selectedBackgroundView = selectedBackgroundView;
                
                buttonItemCell.watcherHandle = _actionHandle;
            }
            
            TGButtonMenuItem *buttonItem = (TGButtonMenuItem *)item;
            
            buttonItemCell.itemId = buttonItem;
            buttonItemCell.title = buttonItem.title;
            [buttonItemCell setSubtype:buttonItem.subtype];
            
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
            
            switchItemCell.itemId = switchItem;
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
            
            cell = variantItemCell;
        }
        else if (item.type == TGPhoneItemType)
        {
            static NSString *phoneItemCellIdentifier = @"PI";
            TGPhoneItemCell *phoneItemCell = (TGPhoneItemCell *)[tableView dequeueReusableCellWithIdentifier:phoneItemCellIdentifier];
            if (phoneItemCell == nil)
            {
                phoneItemCell = [[TGPhoneItemCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:phoneItemCellIdentifier];
                
                UIImageView *backgroundView = [[UIImageView alloc] init];
                phoneItemCell.backgroundView = backgroundView;
                UIImageView *selectedBackgroundView = [[UIImageView alloc] init];
                phoneItemCell.selectedBackgroundView = selectedBackgroundView;
            }
            
            TGPhoneItem *phoneItem = (TGPhoneItem *)item;
            
            phoneItemCell.label = phoneItem.label;
            phoneItemCell.phone = [phoneItem formattedPhone];
            
            cell = phoneItemCell;
        }
        else if (item.type == TGContactMediaItemType)
        {
            static NSString *contactMediaItemCellIdentifier = @"MI";
            TGContactMediaItemCell *mediaItemCell = (TGContactMediaItemCell *)[tableView dequeueReusableCellWithIdentifier:contactMediaItemCellIdentifier];
            if (mediaItemCell == nil)
            {
                TGMediaListView *mediaListView = nil;
#if TG_MEDIA_LIST_SHOW_IMAGES
                mediaListView = _mediaListView;
#endif
                mediaItemCell = [[TGContactMediaItemCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:contactMediaItemCellIdentifier mediaListView:mediaListView];
                
                UIImageView *backgroundView = [[UIImageView alloc] init];
                mediaItemCell.backgroundView = backgroundView;
                UIImageView *selectedBackgroundView = [[UIImageView alloc] init];
                mediaItemCell.selectedBackgroundView = selectedBackgroundView;
                
                [mediaItemCell setTitle:TGLocalized(@"ConversationProfile.MediaList")];
            }
            
#if TG_MEDIA_LIST_SHOW_IMAGES
            [mediaItemCell setIsExpanded:_mediaList.count != 0 animated:false];
#else
            [mediaItemCell setIsExpanded:false animated:false];
#endif
            [mediaItemCell setCount:_mediaListTotalCount];
            [mediaItemCell setIsLoading:_mediaListLoading];
            
            cell = mediaItemCell;
        }
        else if (item.type == TGUserMenuItemType)
        {
            static NSString *userCellIdentifier = @"UI";
            TGUserMenuItemCell *userCell = (TGUserMenuItemCell *)[tableView dequeueReusableCellWithIdentifier:userCellIdentifier];
            if (userCell == nil)
            {
                userCell = [[TGUserMenuItemCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:userCellIdentifier];
                
                UIImageView *backgroundView = [[UIImageView alloc] init];
                userCell.backgroundView = backgroundView;
                UIImageView *selectedBackgroundView = [[UIImageView alloc] init];
                userCell.selectedBackgroundView = selectedBackgroundView;
            }
            
            userCell.selectionStyle = (_createChat || tableView.isEditing) ? UITableViewCellSelectionStyleNone : UITableViewCellSelectionStyleBlue;
            
            TGUserMenuItem *userItem = (TGUserMenuItem *)item;
            
            TGUser *user = userItem.user;
            userCell.user = user;
            userCell.uid = user.uid;
            
            bool isWithAction = _usersWithActionInProgress.find(user.uid) != _usersWithActionInProgress.end();
            
            if (isWithAction)
                userCell.editable = true;
            else
            {
                if (user.uid == TGTelegraphInstance.clientUserId)
                    userCell.editable = false;
                else if (_conversation.chatParticipants.chatAdminId == TGTelegraphInstance.clientUserId)
                    userCell.editable = true;
                else
                {
                    NSNumber *nInviterUid = [_conversation.chatParticipants.chatInvitedBy objectForKey:[NSNumber numberWithInt:user.uid]];
                    if (nInviterUid != nil && [nInviterUid intValue] == TGTelegraphInstance.clientUserId)
                        userCell.editable = true;
                    else
                        userCell.editable = false;
                }
            }
            
            userCell.alwaysNonEditable = _allUsersAreNotEditable;
            
            userCell.title = userItem.user.displayName;
            
            bool subtitleActive = false;
            userCell.subtitle = subtitleTextForUser(user, subtitleActive);
            userCell.subtitleActive = subtitleActive;
                        
            userCell.avatarUrl = userItem.user.photoUrlSmall;
            
            [userCell setIsDisabled:isWithAction animated:false];
            
            [userCell resetView:false];
            
            cell = userCell;
        }
        
        if (cell != nil)
        {
            if (!clearBackground)
            {
                updateGroupedCellBackground((TGGroupedCell *)cell, firstInSection, lastInSection, false);
            }
            else
            {
                ((UIImageView *)cell.backgroundView).image = nil;
                ((UIImageView *)cell.selectedBackgroundView).image = nil;
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

static inline NSString *subtitleTextForUser(TGUser *user, bool &subtitleActive)
{
    bool localSubtitleActive = false;
    NSString *subtitle = @"";
    
    if (user.presence.online || user.uid == TGTelegraphInstance.clientUserId)
    {
        localSubtitleActive = true;
        subtitle = TGLocalized(@"Presence.online");
    }
    else
    {
        int lastSeen = user.presence.lastSeen;
        if (lastSeen < 0)
            subtitle = TGLocalized(@"Presence.invisible");
        else if (lastSeen != 0)
            subtitle = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"Time.last_seen", nil), [TGDateUtils stringForRelativeLastSeen:lastSeen]];
        else
            subtitle = TGLocalized(@"Presence.offline");
    }
    
    subtitleActive = localSubtitleActive;
    
    return subtitle;
}

- (void)updateRelativeTimestamps
{
    for (id cell in _tableView.visibleCells)
    {
        if ([cell isKindOfClass:[TGUserMenuItemCell class]])
        {
            TGUserMenuItemCell *userCell = cell;
            
            bool subtitleActive = false;
            NSString *subtitle = subtitleTextForUser(userCell.user, subtitleActive);
            
            if (subtitleActive != userCell.subtitleActive || ![userCell.subtitle isEqualToString:subtitle])
            {
                userCell.subtitleActive = subtitleActive;
                userCell.subtitle = subtitle;
                
                [userCell resetView:true];
            }
        }
    }
}

#pragma mark - Actions

- (BOOL)tableView:(UITableView *)__unused tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return indexPath.section == 2;
}

- (BOOL)tableView:(UITableView *)__unused tableView shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)__unused indexPath
{
    return false;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)__unused tableView editingStyleForRowAtIndexPath:(NSIndexPath *)__unused indexPath
{
    return UITableViewCellEditingStyleNone;
}

- (void)dismissEditingControls
{
}

- (void)commitAction:(UITableViewCell *)cell
{
    for (NSIndexPath *indexPath in [_tableView indexPathsForVisibleRows])
    {
        UITableViewCell *tableCell = [_tableView cellForRowAtIndexPath:indexPath];
        
        if (tableCell == cell)
        {
            TGMenuItem *item = nil;
            if (indexPath.section < (int)_sectionList.count)
            {
                TGMenuSection *section = [_sectionList objectAtIndex:indexPath.section];
                if (indexPath.row < (int)section.items.count)
                    item = [section.items objectAtIndex:indexPath.row];
            }
            TGUser *user = nil;
            if (item.type == TGUserMenuItemType)
                user = ((TGUserMenuItem *)item).user;
            
            if (user != nil)
            {
                _usersWithActionInProgress.insert(user.uid);
                
                for (UITableViewCell *cell in _tableView.visibleCells)
                {
                    if ([cell isKindOfClass:[TGUserMenuItemCell class]])
                    {
                        TGUserMenuItemCell *userCell = (TGUserMenuItemCell *)cell;
                        if (userCell.uid == user.uid)
                        {
                            [userCell setIsDisabled:false animated:false];
                            [userCell setIsDisabled:true animated:true];
                            break;
                        }
                    }
                }
                
                NSDictionary *options = [[NSDictionary alloc] initWithObjectsAndKeys:[NSNumber numberWithLongLong:_conversation.conversationId], @"conversationId", [NSNumber numberWithInt:user.uid], @"uid", nil];
                [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/conversation/(%lld)/deleteMember/(%d)", _conversation.conversationId, user.uid] options:options watcher:self];
                //[ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/conversation/(%lld)/deleteMember/(%d)", _conversation.conversationId, user.uid] options:options watcher:TGTelegraphInstance];
            }
            
            break;
        }
    }
    
    for (UITableViewCell *cell in [_tableView visibleCells])
    {
        if ([cell conformsToProtocol:@protocol(TGActionTableViewCell)])
            [(id<TGActionTableViewCell>)cell dismissEditingControls:true];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    TGMenuItem *item = nil;
    if (indexPath.section < (int)_sectionList.count)
    {
        TGMenuSection *section = [_sectionList objectAtIndex:indexPath.section];
        if (indexPath.row < (int)section.items.count)
            item = [section.items objectAtIndex:indexPath.row];
    }
    
    if (item == nil)
        return;
    
    if (item.type == TGUserMenuItemType)
    {
        if (!_tableView.isEditing && !_createChat)
        {
            TGUser *user = ((TGUserMenuItem *)item).user;
            NSString *userName = user.firstName != nil ? user.firstName : user.lastName;
            if (userName == nil)
                userName = user.phoneNumber;
            
            if (user.uid != TGTelegraphInstance.clientUserId)
            {
                [[TGInterfaceManager instance] navigateToProfileOfUser:user.uid];
            }
        }
        
        [tableView deselectRowAtIndexPath:indexPath animated:!_tableView.isEditing];
    }
    else if (item.type == TGActionMenuItemType)
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
    else if (item.type == TGContactMediaItemType)
    {
        [[TGInterfaceManager instance] navigateToMediaListOfConversation:_conversation.conversationId];
    }
}

- (void)addParticipantButtonPressed
{
    _contactsController = [[TGSelectSingleContactController alloc] initWithContactsMode:TGContactsModeRegistered | TGContactsModeHideSelf];
    
    _contactsController.disabledUsers = [_conversation.chatParticipants.chatParticipantUids copy];
    _contactsController.watcher = _actionHandle;
    [self.navigationController pushViewController:_contactsController animated:true];
}

- (void)leaveConversationButtonPressed
{
    _currentActionSheet.delegate = nil;
    
    _currentActionSheet = [[UIActionSheet alloc] initWithTitle:TGLocalized(@"ConversationProfile.LeaveConfirmation") delegate:self cancelButtonTitle:TGLocalized(@"Common.Cancel") destructiveButtonTitle:TGLocalized(@"ConversationProfile.LeaveDeleteAndExit") otherButtonTitles:nil];
    _currentActionSheet.tag = TGLeaveConversationActionSheetTag;
    [_currentActionSheet showInView:self.view];
}

- (void)customSoundPressed
{
    if ([_tableView indexPathForSelectedRow] != nil)
        [_tableView deselectRowAtIndexPath:[_tableView indexPathForSelectedRow] animated:true];
    
    TGCustomNotificationController *soundController = [[TGCustomNotificationController alloc] initWithMode:TGCustomNotificationControllerModeGroup];
    soundController.watcherHandle = _actionHandle;
    soundController.selectedIndex = [[_peerNotificationSettings objectForKey:@"soundId"] intValue];
    TGNavigationController *navigationController = [TGNavigationController navigationControllerWithRootController:soundController blackCorners:false];
    
    [self presentViewController:navigationController animated:true completion:nil];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    _currentActionSheet.delegate = nil;
    _currentActionSheet = nil;
    
    if (actionSheet.tag == TGLeaveConversationActionSheetTag)
    {
        if (buttonIndex == actionSheet.destructiveButtonIndex)
        {
            id<ASWatcher> watcher = _watcher.delegate;
            if (watcher != nil && [watcher respondsToSelector:@selector(actionStageActionRequested:options:)])
                [watcher actionStageActionRequested:@"deleteConversation" options:nil];
        }
    }
    else if (actionSheet.tag == TGUserActionSheetTag)
    {
        if (_actionSheetUid <= 0)
            return;
        
        NSIndexPath *userIndexPath = nil;
        int sectionIndex = -1;
        for (TGMenuSection *section in _sectionList)
        {
            sectionIndex++;
            
            if (section.tag == TGMembersSectionTag)
            {
                int itemIndex = -1;
                for (TGMenuItem *item in section.items)
                {
                    itemIndex++;
                    
                    if (item.type == TGUserMenuItemType)
                    {
                        TGUserMenuItem *userItem = (TGUserMenuItem *)item;
                        if (userItem.user.uid == _actionSheetUid)
                        {
                            userIndexPath = [NSIndexPath indexPathForRow:itemIndex inSection:sectionIndex];
                            
                            break;
                        }
                    }
                }
                break;
            }
        }
        
        if (buttonIndex == 0)
        {
            [[TGInterfaceManager instance] navigateToProfileOfUser:_actionSheetUid];
        }
        else if (buttonIndex == 1 && buttonIndex != actionSheet.cancelButtonIndex)
        {
            [[TGInterfaceManager instance] navigateToConversationWithId:_actionSheetUid conversation:nil];
        }
        else if (buttonIndex == actionSheet.destructiveButtonIndex)
        {
            if (userIndexPath != nil)
                [self commitAction:[_tableView cellForRowAtIndexPath:userIndexPath]];
        }
        
        _actionSheetUid = 0;
    }
    else if (actionSheet.tag == TGAvatarActionSheetTag)
    {
        if (buttonIndex == actionSheet.destructiveButtonIndex)
        {
            if (_createChat)
            {
                _createChatPhotoData = nil;
                _createChatPhotoThumbnail = nil;
                [_avatarView loadImage:nil];
                _avatarViewEdit.hidden = true;
                _addPhotoButton.hidden = false;
                _avatarView.userInteractionEnabled = false;
            }
            else
            {
                _currentActionSheet.delegate = nil;
                
                _currentActionSheet = [[UIActionSheet alloc] initWithTitle:TGLocalized(@"ConversationProfile.DeleteGroupPhotoConfirmation") delegate:self cancelButtonTitle:TGLocalized(@"Common.Cancel") destructiveButtonTitle:TGLocalized(@"Common.Delete") otherButtonTitles:nil];
                _currentActionSheet.tag = TGDeletePhotoConfirmationActionSheetTag;
                [_currentActionSheet showInView:self.view];
            }
        }
        else if (buttonIndex == 0)
        {
            if (_conversation != nil && _conversation.chatPhotoBig != nil && _avatarView.currentImage != nil)
            {
                UIImage *placeholder = [[TGRemoteImageView sharedCache] cachedImage:_conversation.chatPhotoSmall availability:TGCacheBoth];
                
                if (placeholder == nil)
                    placeholder = [_avatarView currentImage];
                
                TGImageInfo *imageInfo = [[TGImageInfo alloc] init];
                [imageInfo addImageWithSize:CGSizeMake(640, 640) url:_conversation.chatPhotoBig];
                
                TGImageMediaAttachment *imageAttachment = [[TGImageMediaAttachment alloc] init];
                imageAttachment.imageInfo = imageInfo;
                
                TGProfileImageItem *imageItem = [[TGProfileImageItem alloc] initWithProfilePhoto:imageAttachment];
                TGImageViewController *imageViewController = [[TGImageViewController alloc] initWithImageItem:imageItem placeholder:placeholder];
                imageViewController.hideDates = true;
                
                TGTelegraphProfileImageViewCompanion *companion = [[TGTelegraphProfileImageViewCompanion alloc] initWithUid:0 photoItem:imageItem loadList:false];
                companion.watcherHandle = _actionHandle;
                imageViewController.imageViewCompanion = companion;
                companion.imageViewController = imageViewController;
                
                CGRect windowSpaceFrame = [_avatarView convertRect:_avatarView.bounds toView:_avatarView.window];
                
                UIView *avatarView = _avatarView;
                [imageViewController animateAppear:self.view anchorForImage:_tableView fromRect:windowSpaceFrame fromImage:_avatarView.currentImage start:^
                {
                    avatarView.alpha = 0.0f;
                }];
                imageViewController.watcherHandle = _actionHandle;
                
                [TGAppDelegateInstance presentContentController:imageViewController];
            }
        }
        else if (buttonIndex != actionSheet.cancelButtonIndex)
        {
            [self showCamera];
        }
    }
    else if (actionSheet.tag == TGDeletePhotoConfirmationActionSheetTag)
    {
        if (buttonIndex == actionSheet.destructiveButtonIndex)
        {
            if (_createChat)
            {
                _createChatPhotoData = nil;
                _createChatPhotoThumbnail = nil;
                [_avatarView loadImage:nil];
                _addPhotoButton.hidden = false;
                _avatarViewEdit.hidden = true;
                _avatarView.userInteractionEnabled = false;
            }
            else
            {
                _updatingAvatar = true;
                [self setShowAvatarActivity:true animated:true];
                
                NSMutableDictionary *uploadOptions = [[NSMutableDictionary alloc] init];
                [uploadOptions setObject:[NSNumber numberWithLongLong:_conversation.conversationId] forKey:@"conversationId"];
                
                [ActionStageInstance() dispatchOnStageQueue:^
                {
                    static int actionId = 0;
                    [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/conversation/(%lld)/updateAvatar/(d%d)", _conversation.conversationId, actionId] options:uploadOptions watcher:self];
                    [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/conversation/(%lld)/updateAvatar/(d%d)", _conversation.conversationId, actionId++] options:uploadOptions watcher:TGTelegraphInstance];
                }];
            }
        }
    }
    else if (actionSheet.tag == TGImageSourceActionSheetTag)
    {
        if (buttonIndex == 0)// || buttonIndex == 1)
        {
            if (buttonIndex == 0 && ![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera])
                return;
            
            [self.view endEditing:true];
            
            [(TGApplication *)[UIApplication sharedApplication] setProcessStatusBarHiddenRequests:true];
            
            UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
            imagePicker.sourceType = buttonIndex == 0 ? UIImagePickerControllerSourceTypeCamera : UIImagePickerControllerSourceTypePhotoLibrary;
            imagePicker.allowsEditing = true;
            imagePicker.delegate = self;
            
            [self presentViewController:imagePicker animated:true completion:nil];
        }
        else if (buttonIndex == 1 || buttonIndex == 2)
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

- (void)imagePickerController:(TGImagePickerController *)__unused imagePicker didFinishPickingWithAssets:(NSArray *)assets
{
    if (assets.count != 0)
    {
        for (id object in assets)
        {
            if ([object isKindOfClass:[UIImage class]])
            {
                [self _updateProfileImage:object];
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
    
    [UIView animateWithDuration:0.3 animations:^
    {
        [TGHacks setApplicationStatusBarAlpha:1.0f];
    }];
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
    [_currentActionSheet showInView:self.view];
#endif
}

- (void)imagePickerController:(UIImagePickerController *)__unused picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    [self dismissViewControllerAnimated:true completion:nil];
    
    [(TGApplication *)[UIApplication sharedApplication] setProcessStatusBarHiddenRequests:false];
    
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

- (void)_updateProfileImage:(UIImage *)image
{
    NSData *imageData = UIImageJPEGRepresentation(image, 0.6f);
    if (imageData == nil)
        return;
    
    TGImageProcessor filter = [TGRemoteImageView imageProcessorForName:@"profileAvatar"];
    UIImage *avatarImage = filter(image);
    
    [_avatarView loadImage:avatarImage];
    _addPhotoButton.hidden = true;
    _avatarViewEdit.hidden = false;
    
    if (_createChat)
    {
        _createChatPhotoData = imageData;
        _createChatPhotoThumbnail = avatarImage;
        _avatarView.userInteractionEnabled = true;
    }
    else
    {
        _updatingAvatar = true;
        [self setShowAvatarActivity:true animated:true];
        
        NSMutableDictionary *uploadOptions = [[NSMutableDictionary alloc] init];
        [uploadOptions setObject:imageData forKey:@"imageData"];
        [uploadOptions setObject:[NSNumber numberWithLongLong:_conversation.conversationId] forKey:@"conversationId"];
        [uploadOptions setObject:avatarImage forKey:@"currentImage"];
        
        [ActionStageInstance() dispatchOnStageQueue:^
        {
            static int actionId = 0;
            [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/conversation/(%lld)/updateAvatar/(a%d)", _conversation.conversationId, actionId] options:uploadOptions watcher:self];
            [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/conversation/(%lld)/updateAvatar/(a%d)", _conversation.conversationId, actionId++] options:uploadOptions watcher:TGTelegraphInstance];
        }];
    }
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)__unused picker
{
    [self dismissViewControllerAnimated:true completion:nil];
    
    [(TGApplication *)[UIApplication sharedApplication] setProcessStatusBarHiddenRequests:false];
}

- (void)returnToChatButtonPressed
{
    _usersWithActionInProgress.insert(TGTelegraphInstance.clientUserId);
    [self updateTitle];
    
    [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/conversation/(%lld)/addMember/(%d)", _conversation.conversationId, TGTelegraphInstance.clientUserId] options:[[NSDictionary alloc] initWithObjectsAndKeys:[NSNumber numberWithLongLong:_conversation.conversationId], @"conversationId", [NSNumber numberWithInt:TGTelegraphInstance.clientUserId], @"uid", nil] watcher:self];
}

- (void)titleLabelLongPressed:(UILongPressGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateBegan)
    {   
        [_conversationTitleField becomeFirstResponder];
    }
}

- (void)addPhotoButtonPressed
{
    if (!_avatarActivityIndicator.hidden || _avatarActivityIndicator.alpha > FLT_EPSILON)
        return;
    
    if ((_createChat && _createChatPhotoData != nil) || (_conversation.chatPhotoSmall != nil && _conversation.chatPhotoSmall.length != 0))
    {
        _currentActionSheet.delegate = nil;
        
        _currentActionSheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
        
        [_currentActionSheet addButtonWithTitle:TGLocalized(@"ConversationProfile.OpenPhoto")];
        [_currentActionSheet addButtonWithTitle:TGLocalized(@"ConversationProfile.UpdatePhoto")];
        [_currentActionSheet addButtonWithTitle:TGLocalized(@"ConversationProfile.DeletePhoto")];
        [_currentActionSheet addButtonWithTitle:NSLocalizedString(@"Common.Cancel", nil)];
        _currentActionSheet.destructiveButtonIndex = 2;
        _currentActionSheet.cancelButtonIndex = 3;
        
        _currentActionSheet.tag = TGAvatarActionSheetTag;
        [_currentActionSheet showInView:self.view];
    }
    else
    {
        [self showCamera];
    }
}

- (void)avatarTapped:(UITapGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateRecognized)
    {
        [self addPhotoButtonPressed];
    }
}

#pragma mark -

- (void)focusOnTitleField:(UITapGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateRecognized && !_conversationTitleField.isFirstResponder)
    {
        [_conversationTitleField becomeFirstResponder];
    }
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    if (range.location == NSNotFound)
        return false;
    
    if (range.location + MAX(0, (int)string.length - (int)range.length) > 256)
        return false;
    
    dispatch_async(dispatch_get_main_queue(), ^
    {
        if ([self.navigationItem.rightBarButtonItem.customView isKindOfClass:[TGToolbarButton class]])
        {
            NSString *withoutWhitespace = [textField.text stringByReplacingOccurrencesOfString:@" " withString:@"" options:NSLiteralSearch range:NSMakeRange(0, textField.text.length)];
            ((TGToolbarButton *)self.navigationItem.rightBarButtonItem.customView).enabled = withoutWhitespace.length != 0;
        }
    });
    
    return true;
    
    /*NSString *newText = [textField.text stringByReplacingCharactersInRange:range withString:string];
    if (newText == nil)
        return false;
    
    if ((int)newText.length > 100)
    {
        if (string.length > 1)
            newText = [newText substringToIndex:100];
        else
            return false;
    }
    
    textField.text = newText;
    
    int caretPosition = range.location + string.length;
    
    if (caretPosition > (int)textField.text.length)
        caretPosition = textField.text.length;
    
    UITextPosition *startPosition = [textField positionFromPosition:textField.beginningOfDocument offset:caretPosition];
    UITextPosition *endPosition = [textField positionFromPosition:textField.beginningOfDocument offset:caretPosition];
    if (startPosition != nil && endPosition != nil)
    {
        UITextRange *selection = [textField textRangeFromPosition:startPosition toPosition:endPosition];
        if (selection != nil)
            textField.selectedTextRange = selection;
    }
    
    if ([self.navigationItem.rightBarButtonItem.customView isKindOfClass:[TGToolbarButton class]])
    {
        NSString *withoutWhitespace = [newText stringByReplacingOccurrencesOfString:@" " withString:@"" options:NSLiteralSearch range:NSMakeRange(0, newText.length)];
        ((TGToolbarButton *)self.navigationItem.rightBarButtonItem.customView).enabled = withoutWhitespace.length != 0;
    }
    
    return false;*/
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)__unused scrollView
{
    [self.view endEditing:true];
}

- (void)updateEditingState:(bool)animated explicitState:(bool)explicitState
{
    if (explicitState)
    {
        if (!_createChat)
        {
            TGToolbarButton *cancelButton = [[TGToolbarButton alloc] initWithType:TGToolbarButtonTypeGeneric];
            cancelButton.text = NSLocalizedString(@"Common.Cancel", @"");
            cancelButton.minWidth = 59;
            [cancelButton sizeToFit];
            [cancelButton addTarget:self action:@selector(cancelButtonPressed) forControlEvents:UIControlEventTouchUpInside];
            
            UIBarButtonItem *cancelButtonItem = [[UIBarButtonItem alloc] initWithCustomView:cancelButton];
            [self.navigationItem setLeftBarButtonItem:cancelButtonItem animated:animated];
        
            TGToolbarButton *doneButton = [[TGToolbarButton alloc] initWithType:TGToolbarButtonTypeDone];
            doneButton.text = NSLocalizedString(@"Common.Done", @"");
            doneButton.minWidth = 51;
            [doneButton sizeToFit];
            [doneButton addTarget:self action:@selector(doneButtonPressed) forControlEvents:UIControlEventTouchUpInside];
            
            UIBarButtonItem *doneButtonItem = [[UIBarButtonItem alloc] initWithCustomView:doneButton];
            [self.navigationItem setRightBarButtonItem:doneButtonItem animated:animated];
            
            doneButton.enabled = _conversationTitleField.text.length != 0;
        }
        else
        {
            [self setBackAction:@selector(performClose) animated:animated];
            
            TGToolbarButton *createButton = [[TGToolbarButton alloc] initWithType:TGToolbarButtonTypeDone];
            createButton.text = TGLocalized(@"Compose.Create");
            createButton.minWidth = 60;
            [createButton sizeToFit];
            [createButton addTarget:self action:@selector(createButtonPressed) forControlEvents:UIControlEventTouchUpInside];
            
            UIBarButtonItem *createButtonItem = [[UIBarButtonItem alloc] initWithCustomView:createButton];
            [self.navigationItem setRightBarButtonItem:createButtonItem animated:animated];
            
            NSString *withoutWhitespace = [_conversationTitleField.text stringByReplacingOccurrencesOfString:@" " withString:@"" options:NSLiteralSearch range:NSMakeRange(0, _conversationTitleField.text.length)];
            createButton.enabled = withoutWhitespace.length != 0;
        }
        
        _conversationTitleField.hidden = false;
        _conversationTitleFieldBackground.hidden = false;
        
        if (animated)
        {
            [UIView animateWithDuration:0.3 animations:^
            {
                _conversationTitleField.alpha = 1.0f;
                _conversationTitleFieldBackground.alpha = 1.0f;
                _conversationTitleLabel.alpha = 0.0f;
                _conversationSubtitleLabel.alpha = 0.0f;
            } completion:^(BOOL finished)
            {
                if (finished)
                {
                    _conversationTitleLabel.hidden = true;
                    _conversationSubtitleLabel.hidden = true;
                }
            }];
        }
        else
        {
            _conversationTitleField.alpha = 1.0f;
            _conversationTitleFieldBackground.alpha = 1.0f;
            _conversationTitleLabel.alpha = 0.0f;
            _conversationSubtitleLabel.alpha = 0.0f;
            
            _conversationTitleLabel.hidden = true;
        }
        
        int sectionIndex = -1;
        int itemIndex = -1;
        if ([self findMenuItem:TGMediaListTag sectionIndex:&sectionIndex itemIndex:&itemIndex])
        {
            UIImageView *temporaryImageView = nil;
            
            UITableViewCell *cell = [_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:itemIndex inSection:sectionIndex]];
            if (cell != nil)
            {
                UIGraphicsBeginImageContextWithOptions(cell.bounds.size, false, 0.0f);
                [cell.layer renderInContext:UIGraphicsGetCurrentContext()];
                UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
                UIGraphicsEndImageContext();
                temporaryImageView = [[UIImageView alloc] initWithImage:image];
            }
            
            [_tableView beginUpdates];
            
            [((TGMenuSection *)[_sectionList objectAtIndex:sectionIndex]).items replaceObjectAtIndex:itemIndex withObject:_customSoundMenuItem];
            
            [_tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:itemIndex inSection:sectionIndex]] withRowAnimation:UITableViewRowAnimationNone];
            
            [_tableView endUpdates];
            
            cell = [_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:itemIndex inSection:sectionIndex]];
            if (cell != nil)
            {
                temporaryImageView.frame = cell.frame;
                [cell.superview addSubview:temporaryImageView];
                
                [UIView animateWithDuration:0.3 animations:^
                {
                    temporaryImageView.alpha = 0.0f;
                } completion:^(__unused BOOL finished)
                {
                    [temporaryImageView removeFromSuperview];
                }];
            }
        }
        
        /*int sectionIndex = 0;
        int itemIndex = 0;
        if ([self findMenuItem:_customSoundMenuItem.tag sectionIndex:NULL itemIndex:NULL] == nil && [self findMenuItem:_notificationsMenuItem.tag sectionIndex:&sectionIndex itemIndex:&itemIndex] != nil)
        {
            UITableViewCell *oldCell = nil;
            if (animated)
                oldCell = [_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:itemIndex inSection:sectionIndex]];
            
            [((TGMenuSection *)[_sectionList objectAtIndex:sectionIndex]).items replaceObjectAtIndex:itemIndex withObject:_customSoundMenuItem];
            [_tableView beginUpdates];
            [_tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:itemIndex inSection:sectionIndex]] withRowAnimation:UITableViewRowAnimationNone];
            
            int photosSectionIndex = 0;
            if ([self findMenuItem:TGMediaListTag sectionIndex:&photosSectionIndex itemIndex:NULL])
            {
                [_sectionList removeObjectAtIndex:photosSectionIndex];
                [_tableView deleteSections:[NSIndexSet indexSetWithIndex:photosSectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            }
            
            [_tableView endUpdates];
            
            UITableViewCell *newCell = [_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:itemIndex inSection:sectionIndex]];
            
            if (animated && oldCell != nil && newCell != nil)
            {
                UIView *oldContentView = nil;
                int oldContentViewIndex = 0;
                for (int i = 0; i < (int)oldCell.subviews.count; i++)
                {
                    if ([oldCell.subviews objectAtIndex:i] == oldCell.contentView)
                    {
                        oldContentView = [oldCell.subviews objectAtIndex:i];
                        oldContentViewIndex = i;
                        break;
                    }
                }
                
                if (oldContentView != nil)
                {
                    for (UIView *subview in oldContentView.subviews)
                    {
                        if ([subview isKindOfClass:[TGSwitchView class]])
                        {
                            subview.layer.rasterizationScale = [[UIScreen mainScreen] scale];
                            subview.layer.shouldRasterize = true;
                        }
                    }
                    
                    for (UIView *subview in newCell.contentView.subviews)
                    {
                        if ([subview isKindOfClass:[TGSwitchView class]])
                        {
                            subview.layer.rasterizationScale = [[UIScreen mainScreen] scale];
                            subview.layer.shouldRasterize = true;
                        }
                    }
                    
                    [oldContentView removeFromSuperview];
                    [newCell insertSubview:oldContentView aboveSubview:newCell.contentView];
                    newCell.contentView.alpha = 0.0f;
                    
                    [UIView animateWithDuration:0.3 animations:^
                    {
                        newCell.contentView.alpha = 1.0f;
                    } completion:nil];
                    
                    [UIView animateWithDuration:0.3 animations:^
                    {
                        oldContentView.alpha = 0.0f;
                    } completion:^(__unused BOOL finished)
                    {
                        for (UIView *subview in oldContentView.subviews)
                        {
                            if ([subview isKindOfClass:[TGSwitchView class]])
                                subview.layer.shouldRasterize = false;
                        }
                        
                        for (UIView *subview in newCell.contentView.subviews)
                        {
                            if ([subview isKindOfClass:[TGSwitchView class]])
                                subview.layer.shouldRasterize = false;
                        }
                        
                        oldContentView.alpha = 1.0f;
                        [oldContentView removeFromSuperview];
                        [oldCell insertSubview:oldContentView atIndex:oldContentViewIndex];
                    }];
                }
            }
        }*/
    }
    else
    {
        [self setBackAction:@selector(performClose) animated:true];
        
        TGToolbarButton *editButton = [[TGToolbarButton alloc] initWithType:TGToolbarButtonTypeGeneric];
        editButton.text = NSLocalizedString(@"Common.Edit", @"");
        editButton.minWidth = 51;
        [editButton sizeToFit];
        [editButton addTarget:self action:@selector(editButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        
        UIBarButtonItem *editButtonItem = [[UIBarButtonItem alloc] initWithCustomView:editButton];
        [self.navigationItem setRightBarButtonItem:editButtonItem animated:animated];
        
        _conversationTitleLabel.hidden = false;
        _conversationSubtitleLabel.hidden = false;
        
        if (animated)
        {
            
            [UIView animateWithDuration:0.3 animations:^
            {
                _conversationTitleField.alpha = 0.0f;
                _conversationTitleFieldBackground.alpha = 0.0f;
                _conversationTitleLabel.alpha = 1.0f;
                _conversationSubtitleLabel.alpha = 1.0f;
            } completion:^(BOOL finished)
            {
                if (finished)
                {
                    _conversationTitleField.hidden = true;
                    _conversationTitleFieldBackground.hidden = true;
                }
            }];
        }
        else
        {
            _conversationTitleField.alpha = 0.0f;
            _conversationTitleFieldBackground.alpha = 0.0f;
            _conversationTitleLabel.alpha = 1.0f;
            _conversationSubtitleLabel.alpha = 1.0f;
            
            _conversationTitleField.hidden = true;
            _conversationTitleFieldBackground.hidden = true;
        }
        
        int sectionIndex = -1;
        int itemIndex = -1;
        if ([self findMenuItem:TGSoundTag sectionIndex:&sectionIndex itemIndex:&itemIndex])
        {
            UIImageView *temporaryImageView = nil;
            
            UITableViewCell *cell = [_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:itemIndex inSection:sectionIndex]];
            if (cell != nil)
            {
                UIGraphicsBeginImageContextWithOptions(cell.bounds.size, false, 0.0f);
                [cell.layer renderInContext:UIGraphicsGetCurrentContext()];
                UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
                UIGraphicsEndImageContext();
                temporaryImageView = [[UIImageView alloc] initWithImage:image];
            }

            
            [_tableView beginUpdates];
            
            [((TGMenuSection *)[_sectionList objectAtIndex:sectionIndex]).items replaceObjectAtIndex:itemIndex withObject:_mediaItem];
            
            [_tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:itemIndex inSection:sectionIndex]] withRowAnimation:UITableViewRowAnimationNone];
            
            [_tableView endUpdates];
            
            cell = [_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:itemIndex inSection:sectionIndex]];
            if (cell != nil)
            {
                temporaryImageView.frame = cell.frame;
                [cell.superview addSubview:temporaryImageView];
                
                [UIView animateWithDuration:0.3 animations:^
                 {
                     temporaryImageView.alpha = 0.0f;
                 } completion:^(__unused BOOL finished)
                 {
                     [temporaryImageView removeFromSuperview];
                 }];
            }
        }
        
        /*int sectionIndex = 0;
        int itemIndex = 0;
        if ([self findMenuItem:_customSoundMenuItem.tag sectionIndex:&sectionIndex itemIndex:&itemIndex] != nil && [self findMenuItem:_notificationsMenuItem.tag sectionIndex:NULL itemIndex:NULL] == nil)
        {
            UITableViewCell *oldCell = nil;
            if (animated)
                oldCell = [_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:itemIndex inSection:sectionIndex]];
            
            [((TGMenuSection *)[_sectionList objectAtIndex:sectionIndex]).items replaceObjectAtIndex:itemIndex withObject:_notificationsMenuItem];
            [_tableView beginUpdates];
            [_tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:itemIndex inSection:sectionIndex]] withRowAnimation:UITableViewRowAnimationNone];
            
            if ([self findMenuItem:TGMediaListTag sectionIndex:NULL itemIndex:NULL] == nil)
            {
                TGMenuSection *mediaSection = [[TGMenuSection alloc] init];
                mediaSection.tag = TGMediaSectionTag;
                [_sectionList addObject:mediaSection];
                
                TGContactMediaItem *mediaItem = [[TGContactMediaItem alloc] init];
                mediaItem.tag = TGMediaListTag;
                [mediaSection.items addObject:mediaItem];
                
                [_tableView insertSections:[NSIndexSet indexSetWithIndex:_sectionList.count - 1] withRowAnimation:UITableViewRowAnimationFade];
            }
            
            [_tableView endUpdates];
            
            UITableViewCell *newCell = [_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:itemIndex inSection:sectionIndex]];
            
            if (animated && oldCell != nil && newCell != nil)
            {
                UIView *oldContentView = nil;
                int oldContentViewIndex = 0;
                for (int i = 0; i < (int)oldCell.subviews.count; i++)
                {
                    if ([oldCell.subviews objectAtIndex:i] == oldCell.contentView)
                    {
                        oldContentView = [oldCell.subviews objectAtIndex:i];
                        oldContentViewIndex = i;
                        break;
                    }
                }
                
                if (oldContentView != nil)
                {
                    for (UIView *subview in oldContentView.subviews)
                    {
                        if ([subview isKindOfClass:[TGSwitchView class]])
                        {
                            subview.layer.rasterizationScale = [[UIScreen mainScreen] scale];
                            subview.layer.shouldRasterize = true;
                        }
                    }
                    
                    for (UIView *subview in newCell.contentView.subviews)
                    {
                        if ([subview isKindOfClass:[TGSwitchView class]])
                        {
                            subview.layer.rasterizationScale = [[UIScreen mainScreen] scale];
                            subview.layer.shouldRasterize = true;
                        }
                    }
                    
                    [oldContentView removeFromSuperview];
                    [newCell insertSubview:oldContentView belowSubview:newCell.contentView];
                    newCell.contentView.alpha = 0.0f;
                    
                    [UIView animateWithDuration:0.3 animations:^
                    {
                        newCell.contentView.alpha = 1.0f;
                    } completion:nil];
                    
                    [UIView animateWithDuration:0.3 animations:^
                    {
                        oldContentView.alpha = 0.0f;
                    } completion:^(__unused BOOL finished)
                    {
                        for (UIView *subview in oldContentView.subviews)
                        {
                            if ([subview isKindOfClass:[TGSwitchView class]])
                            {
                                subview.layer.rasterizationScale = [[UIScreen mainScreen] scale];
                                subview.layer.shouldRasterize = false;
                            }
                        }
                        
                        for (UIView *subview in newCell.contentView.subviews)
                        {
                            if ([subview isKindOfClass:[TGSwitchView class]])
                            {
                                subview.layer.rasterizationScale = [[UIScreen mainScreen] scale];
                                subview.layer.shouldRasterize = false;
                            }
                        }
                        
                        oldContentView.alpha = 1.0f;
                        [oldContentView removeFromSuperview];
                        [oldCell insertSubview:oldContentView atIndex:oldContentViewIndex];
                    }];
                }
            }
        }*/
    }
    
    if (animated)
    {
        [UIView animateWithDuration:0.3 animations:^
        {
            _avatarViewEdit.alpha = explicitState ? 1.0f : 0.0f;
        }];
    }
    else
    {
        _avatarViewEdit.alpha = explicitState ? 1.0f : 0.0f;
    }
    
    for (UITableViewCell *cell in _tableView.visibleCells)
    {
        if ([cell isKindOfClass:[TGUserMenuItemCell class]])
        {
            cell.selectionStyle = explicitState ? UITableViewCellSelectionStyleNone : UITableViewCellSelectionStyleBlue;
        }
    }
}


- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    
    NSString *withoutWhitespace = [textField.text stringByReplacingOccurrencesOfString:@" " withString:@"" options:NSLiteralSearch range:NSMakeRange(0, textField.text.length)];
    
    if (!_createChat && withoutWhitespace.length != 0)
    {
        [self updateEditingState:true explicitState:false];
        [_tableView setEditing:false animated:true];
        
        if (![textField.text isEqualToString:_conversation.chatTitle])
        {
            static int actionId = 0;
            
            NSMutableDictionary *options = [[NSMutableDictionary alloc] init];
            [options setObject:[NSNumber numberWithLongLong:_conversation.conversationId] forKey:@"conversationId"];
            [options setObject:[NSString stringWithString:textField.text] forKey:@"title"];
            
            _updatingTitle = true;
            _conversationTitleField.userInteractionEnabled = false;
            _conversationTitleField.textColor = UIColorRGB(0x999999);
            
            _conversationTitleLabel.text = _conversationTitleField.text;
            _conversationTitleLabel.textColor = UIColorRGB(0x66727f);
            
            NSString *path = [[NSString alloc] initWithFormat:@"/tg/conversation/(%lld)/changeTitle/(%da)", _conversation.conversationId, actionId++];
            [ActionStageInstance() requestActor:path options:options watcher:self];
            [ActionStageInstance() requestActor:path options:options watcher:TGTelegraphInstance];
        }
    }
    
    return false;
}

- (void)editButtonPressed
{
    [(TGToolbarButton *)self.navigationItem.rightBarButtonItem.customView setSelected:true];
    
    [_tableView setEditing:true animated:true];
    [self updateEditingState:true explicitState:true];
}

- (void)cancelButtonPressed
{
    [(TGToolbarButton *)self.navigationItem.leftBarButtonItem.customView setSelected:true];
    
    [_conversationTitleField resignFirstResponder];
    
    [self updateEditingState:true explicitState:false];
    [_tableView setEditing:false animated:true];
    
    _conversationTitleField.text = _conversation.chatTitle;
    _conversationTitleLabel.text = _conversation.chatTitle;
}

- (void)doneButtonPressed
{
    [(TGToolbarButton *)self.navigationItem.rightBarButtonItem.customView setSelected:true];
    
    [self textFieldShouldReturn:_conversationTitleField];
}

- (void)createButtonPressed
{
    NSMutableArray *uids = [[NSMutableArray alloc] init];
    
    for (TGMenuSection *section in _sectionList)
    {
        if (section.tag == TGMembersSectionTag)
        {
            for (TGUserMenuItem *userItem in section.items)
            {
                if (userItem.user.uid != TGTelegraphInstance.clientUserId)
                    [uids addObject:[[NSNumber alloc] initWithInt:userItem.user.uid]];
            }
            
            break;
        }
    }
    
    if (_createChatBroadcast)
    {
        [[TGInterfaceManager instance] navigateToConversationWithBroadcastUids:uids forwardMessages:nil];
    }
    else
    {
        _progressWindow = [[TGProgressWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
        [_progressWindow show:true];
        
        static int actionId = 0;
        [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/conversation/createChat/(%d)", actionId++] options:[NSDictionary dictionaryWithObjectsAndKeys:uids, @"uids", [NSString stringWithString:_conversationTitleField.text], @"title", nil] watcher:self];
    }
}

#pragma mark -

- (void)actionStageResourceDispatched:(NSString *)path resource:(id)resource arguments:(id)__unused arguments
{
    if ([path isEqualToString:@"/tg/userdatachanges"] || [path isEqualToString:@"/tg/userpresencechanges"])
    {
        NSArray *users = ((SGraphObjectNode *)resource).object;
        
        dispatch_async(dispatch_get_main_queue(), ^
        {
            std::tr1::shared_ptr<std::map<int, int> > changedUidToIndex(new std::map<int, int>());
            int index = -1;
            for (TGUser *user in users)
            {
                index++;
                changedUidToIndex->insert(std::pair<int, int>(user.uid, index));
            }
    
            TGMenuSection *membersSection = nil;
            for (TGMenuSection *section in _sectionList)
            {
                if (section.tag == TGMembersSectionTag)
                {
                    membersSection = section;
                    break;
                }
            }
            
            bool haveChanges = false;
            
            for (TGMenuItem *item in membersSection.items)
            {
                if (item.type == TGUserMenuItemType)
                {
                    TGUserMenuItem *userItem = (TGUserMenuItem *)item;
                    std::map<int, int>::iterator it = changedUidToIndex->find(userItem.user.uid);
                    if (it != changedUidToIndex->end())
                    {
                        haveChanges = true;
                        userItem.user = [users objectAtIndex:it->second];
                    }
                }
            }
            
            if (!haveChanges)
                return;
                       
            for (UITableViewCell *cell in _tableView.visibleCells)
            {
                if ([cell isKindOfClass:[TGUserMenuItemCell class]])
                {
                    TGUserMenuItemCell *userCell = (TGUserMenuItemCell *)cell;
                    std::map<int, int>::iterator it = changedUidToIndex->find(userCell.uid);
                    if (it != changedUidToIndex->end())
                    {
                        TGUser *user = [users objectAtIndex:it->second];
                        
                        userCell.uid = user.uid;
                        userCell.user = user;
                        userCell.title = user.displayName;
                        
                        bool subtitleActive = false;
                        userCell.subtitle = subtitleTextForUser(user, subtitleActive);
                        userCell.subtitleActive = subtitleActive;
                                                
                        userCell.avatarUrl = user.photoUrlSmall;
                        
                        [userCell setIsDisabled:_usersWithActionInProgress.find(user.uid) != _usersWithActionInProgress.end() animated:false];
                        
                        [userCell resetView:true];
                    }
                }
            }
            
            [self updateUserSortingAutomatic];
        });
    }
    else if ([path isEqualToString:@"/as/updateRelativeTimestamps"])
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            [self updateRelativeTimestamps];
        });
    }
    else if ([path hasPrefix:[NSString stringWithFormat:@"/tg/peerSettings/(%lld", _conversation.conversationId]])
    {
        [self actorCompleted:ASStatusSuccess path:path result:resource];
    }
}

- (void)actionStageActionRequested:(NSString *)action options:(NSDictionary *)options
{
    if ([action isEqualToString:@"chatInfoChanged"])
    {
        [self chatInfoChanged:[options objectForKey:@"chatInfo"]];
    }
    else if ([action isEqualToString:@"contactSelected"])
    {
        [_contactsController deselectRow];
        
        int uid = [[options objectForKey:@"uid"] intValue];
        if (uid <= 0)
        {
            if (_contactsController != nil && self.navigationController.topViewController == _contactsController)
            {
                [self.navigationController popViewControllerAnimated:true];
                _contactsController = nil;
            }
        }
        else
        {
            for (NSNumber *nUid in _conversation.chatParticipants.chatParticipantUids)
            {
                if ([nUid intValue] == uid)
                {
                    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:nil message:NSLocalizedString(@"ConversationProfile.UserAlreadyInChat", nil) delegate:nil cancelButtonTitle:NSLocalizedString(@"Common.OK", nil) otherButtonTitles:nil];
                    [alertView show];
                    
                    return;
                }
            }
            
            TGUser *user = [TGDatabaseInstance() loadUser:uid];
            if (user != nil)
            {
                _actionSheetUid = uid;
                
                _currentAlertView = [[UIAlertView alloc] initWithTitle:nil message:[[NSString alloc] initWithFormat:TGLocalized(@"ConversationProfile.AddMemberToChatConfirmation"), user.displayName] delegate:self cancelButtonTitle:TGLocalized(@"Common.Cancel") otherButtonTitles:TGLocalized(@"Common.OK"), nil];
                _currentAlertView.tag = TGAddMemberConfirmationAlertTag;
                [_currentAlertView show];
            }
            else
            {
                if (_contactsController != nil && self.navigationController.topViewController == _contactsController)
                {
                    [self.navigationController popViewControllerAnimated:true];
                    _contactsController = nil;
                }
            }
        }
    }
    else if ([action isEqualToString:@"toggleSwitchItem"])
    {
        TGSwitchItem *switchItem = [options objectForKey:@"itemId"];
        if (switchItem == nil)
            return;
        
        NSNumber *nValue = [options objectForKey:@"value"];
        
        switchItem.isOn = [nValue boolValue];
        
        if (switchItem.tag == TGNotificationsTag)
        {
            [_peerNotificationSettings setObject:[NSNumber numberWithInt:switchItem.isOn ? 0 : INT_MAX] forKey:@"muteUntil"];
            [self updateNotificationSettingsItems:false];
            
            static int actionId = 0;
            [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/changePeerSettings/(%lld)/(pc%d)", _conversation.conversationId, actionId++] options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithLongLong:_conversation.conversationId], @"peerId", [NSNumber numberWithInt:switchItem.isOn ? 0 : INT_MAX], @"muteUntil", nil] watcher:TGTelegraphInstance];
        }
        else if (switchItem.tag == TGGroupTypeTag)
        {
            _createChatBroadcast = switchItem.isOn;
            [self updateCreateChatMode];
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
    else if ([action isEqualToString:@"buttonsMenuItemAction"])
    {
        NSString *buttonAction = options[@"action"];
        
        if ([buttonAction isEqualToString:@"addMember"])
            [self addParticipantButtonPressed];
        else if ([buttonAction isEqualToString:@"leaveGroup"])
            [self leaveConversationButtonPressed];
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
        id<ASWatcher> watcher = _watcher.delegate;
        if ([options objectForKey:@"imageData"] != nil && watcher != nil && [watcher respondsToSelector:@selector(actionStageActionRequested:options:)])
        {
            [watcher actionStageActionRequested:@"cameraDataSelected" options:nil];
        }
        
        UIImage *photo = [options objectForKey:@"image"];
        NSData *photoData = [options objectForKey:@"imageData"];
        
        TGImageProcessor filter = [TGRemoteImageView imageProcessorForName:@"profileAvatar"];
        UIImage *avatarImage = filter(photo);
        
        if (_cameraWindow != nil)
        {
            if (photo != nil)
            {                        
                [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
                
                double ignoreDelayInSeconds = 0.29;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(ignoreDelayInSeconds * TGAnimationSpeedFactor() * NSEC_PER_SEC)), dispatch_get_main_queue(), ^
                {
                    [[UIApplication sharedApplication] endIgnoringInteractionEvents];
                    
                    [_avatarView loadImage:avatarImage];
                    _addPhotoButton.hidden = true;
                    _avatarViewEdit.hidden = false;
                    
                    if (_createChat)
                    {
                        _createChatPhotoData = photoData;
                        _createChatPhotoThumbnail = avatarImage;
                        _avatarView.userInteractionEnabled = true;
                    }
                    else
                    {
                        _updatingAvatar = true;
                        [self setShowAvatarActivity:true animated:true];
                        
                        NSMutableDictionary *uploadOptions = [[NSMutableDictionary alloc] init];
                        [uploadOptions setObject:photoData forKey:@"imageData"];
                        [uploadOptions setObject:[NSNumber numberWithLongLong:_conversation.conversationId] forKey:@"conversationId"];
                        [uploadOptions setObject:avatarImage forKey:@"currentImage"];
                        
                        [ActionStageInstance() dispatchOnStageQueue:^
                        {
                            static int actionId = 0;
                            [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/conversation/(%lld)/updateAvatar/(a%d)", _conversation.conversationId, actionId] options:uploadOptions watcher:self];
                            [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/conversation/(%lld)/updateAvatar/(a%d)", _conversation.conversationId, actionId++] options:uploadOptions watcher:TGTelegraphInstance];
                        }];
                    }
                });
                
                
                [_cameraWindow dismissToRect:[_headerViewContents convertRect:_avatarView.frame toView:self.view.window] fromImage:photo toImage:avatarImage toView:self.view aboveView:_tableView interfaceOrientation:self.interfaceOrientation];
                _cameraWindow = nil;
            }
        }
#endif
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
            
            [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/changePeerSettings/(%lld)/(pe%d)", _conversation.conversationId, actionId++] options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithLongLong:_conversation.conversationId], @"peerId", [NSNumber numberWithInt:[nIndex intValue]], @"soundId", nil] watcher:TGTelegraphInstance];
        }
    }
    else if ([action isEqualToString:@"openImage"])
    {
#if TG_MEDIA_LIST_SHOW_IMAGES
        NSValue *nRect = [options objectForKey:@"rectInWindowCoords"];
        UIImage *image = [options objectForKey:@"image"];
        NSNumber *nTag = [options objectForKey:@"tag"];
        TGImageInfo *imageInfo = [options objectForKey:@"imageInfo"];
        
        if (image == nil || nTag == nil || imageInfo == nil)
            return;
        
        int mid = [nTag intValue];
        
        UIView *hideView = [_mediaListView viewForItemId:mid];
        
        CGRect windowSpaceFrame = [nRect CGRectValue];
        TGImageViewController *imageViewController = [[TGImageViewController alloc] initWithImageInfo:imageInfo itemId:mid placeholder:image];
        imageViewController.saveToGallery = TGAppDelegateInstance.autosavePhotos;
        imageViewController.ignoreSaveToGalleryUid = TGTelegraphInstance.clientUserId;
        
        TGImageViewControllerCompanion *companion = [[TGImageViewControllerCompanion alloc] initWithPeerId:_conversation.conversationId firstItemId:mid];
        imageViewController.imageViewCompanion = companion;
        companion.imageViewController = imageViewController;
        
        [imageViewController animateAppear:self.view anchorForImage:_tableView fromRect:windowSpaceFrame fromImage:image];
        imageViewController.tags = [[NSMutableDictionary alloc] initWithObjectsAndKeys:nTag, @"tag", nil];
        imageViewController.watcherHandle = _actionHandle;
        
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.08 * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void)
        {
            hideView.alpha = 0.0f;
        });
        
        [TGAppDelegateInstance presentContentController:imageViewController];
        
        /*popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * TGAnimationSpeedFactor() * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^
        {
            hideView.hidden = false;
        });*/
        
#endif
    }
    else if ([action isEqualToString:@"hideImage"])
    {
#if TG_MEDIA_LIST_SHOW_IMAGES
        int messageId = [[options objectForKey:@"messageId"] intValue];
        if (messageId != 0)
        {
            [_mediaListView viewForItemId:messageId].alpha = [[options objectForKey:@"hide"] boolValue] ? 0.0f : 1.0f;
        }
#endif
    }
    else if ([action isEqualToString:@"closeImage"])
    {
        TGImageViewController *imageViewController = [options objectForKey:@"sender"];
        
        CGRect targetRect = [_avatarView convertRect:_avatarView.bounds toView:self.view.window];
        UIImage *targetImage = [_avatarView currentImage];
        
        if (targetImage == nil)
            targetRect = CGRectZero;
        
        [imageViewController animateDisappear:self.view anchorForImage:_tableView toRect:targetRect toImage:targetImage swipeVelocity:0.0f completion:^
        {
            _avatarView.alpha = 1.0f;
            
            [TGAppDelegateInstance dismissContentController];
        }];
        
        [((TGNavigationController *)self.navigationController) updateControllerLayout:false];
        
#if TG_MEDIA_LIST_SHOW_IMAGES
        TGImageViewController *imageViewController = [options objectForKey:@"sender"];
        NSTimeInterval duration = [[options objectForKey:@"duration"] doubleValue];
        
        int currentMessageId = [[imageViewController currentItemId] intValue];
        
        CGRect targetRect = CGRectZero;
        
        UIView *showView = nil;
        
        UIImage *currentImage = nil;
        
        if (currentMessageId != 0)
        {
            showView = [_mediaListView viewForItemId:currentMessageId];
            if (showView != nil)
            {
                targetRect = [self.view.window convertRect:showView.bounds fromView:showView];
                showView.alpha = 0.0f;
                
                currentImage = ((TGRemoteImageView *)showView).currentImage;
            }
        }
        
        if (currentImage == nil)
            targetRect = CGRectZero;
        
        [imageViewController animateDisappear:self.view anchorForImage:_tableView toRect:targetRect toImage:currentImage];
        
        id<TGAppManager> appManager = TGAppDelegateInstance;
        
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration * TGAnimationSpeedFactor() * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^
        {
            [appManager dismissContentController];
            showView.hidden = false;
            showView.alpha = 1.0f;
        });
        
        [((TGNavigationController *)self.navigationController) updateControllerLayout:false];
#endif
    }
}

- (void)actorCompleted:(int)resultCode path:(NSString *)path result:(id)__unused result
{
    if ([path hasPrefix:[NSString stringWithFormat:@"/tg/conversations/(%lld)/mediahistory/", _conversation.conversationId]])
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            _mediaListLoading = false;
            
#if TG_MEDIA_LIST_SHOW_IMAGES
            bool mediaListWasEmpty = _mediaList.count == 0;
#endif
            
            if (resultCode == ASStatusSuccess)
            {
                NSDictionary *dict = ((SGraphObjectNode *)result).object;
                
                _mediaListTotalCount = [[dict objectForKey:@"count"] intValue];
                
#if TG_MEDIA_LIST_SHOW_IMAGES
                NSArray *mediaItems = [[dict objectForKey:@"messages"] sortedArrayUsingComparator:^NSComparisonResult(TGMessage *message1, TGMessage *message2)
                {
                    return message1.date < message2.date ? NSOrderedDescending : NSOrderedAscending;
                }];
                
                [_mediaList removeAllObjects];
                [_mediaList addObjectsFromArray:mediaItems];
                
                [_mediaListView mediaListReloaded:_mediaList];
#endif
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
#if TG_MEDIA_LIST_SHOW_IMAGES
                            if ((_mediaList.count == 0) != mediaListWasEmpty)
                                [cell setIsExpanded:_mediaList.count != 0 animated:!appearAnimation];
#endif
                        }
                        
#if TG_MEDIA_LIST_SHOW_IMAGES
                        bool appearAnimation = _appearAnimation;
                        
                        if (appearAnimation)
                            [UIView setAnimationsEnabled:false];
                        [_tableView beginUpdates];
                        [_tableView endUpdates];
                        if (appearAnimation)
                            [UIView setAnimationsEnabled:true];
#endif
                        
                        break;
                    }
                }
            }
        });
    }
    else if ([path hasPrefix:[NSString stringWithFormat:@"/tg/peerSettings/(%lld", _conversation.conversationId]])
    {
        NSDictionary *notificationSettings = ((SGraphObjectNode *)result).object;
        
        dispatch_async(dispatch_get_main_queue(), ^
        {
            _peerNotificationSettings = [notificationSettings mutableCopy];
            [self updateNotificationSettingsItems:false];
        });
    }
    else if ([path hasPrefix:[NSString stringWithFormat:@"/tg/conversation/(%lld)/addMember/(", _conversation.conversationId]])
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            NSRange range = [path rangeOfString:@"/addMember/("];
            int uid = [[path substringFromIndex:(range.location + range.length)] intValue];
            
            _usersWithActionInProgress.erase(uid);
            
            for (UITableViewCell *cell in _tableView.visibleCells)
            {
                if ([cell isKindOfClass:[TGUserMenuItemCell class]])
                {
                    TGUserMenuItemCell *userCell = (TGUserMenuItemCell *)cell;
                    if (userCell.uid == uid)
                    {
                        [userCell setIsDisabled:false animated:true];
                        break;
                    }
                }
            }
            
            if (resultCode != ASStatusSuccess)
            {
                bool found = false;
                for (NSNumber *nUid in _conversation.chatParticipants.chatParticipantUids)
                {
                    if ([nUid intValue] == uid)
                    {
                        found = true;
                        break;
                    }
                }
                if (!found)
                {
                    int sectionIndex = -1;
                    for (TGMenuSection *section in _sectionList)
                    {
                        sectionIndex++;
                        if (section.tag == TGMembersSectionTag)
                        {
                            int itemIndex = -1;
                            for (TGMenuItem *item in section.items)
                            {
                                itemIndex++;
                                if (item.type == TGUserMenuItemType)
                                {
                                    if (((TGUserMenuItem *)item).user.uid == uid)
                                    {
                                        [section.items removeObjectAtIndex:itemIndex];
                                        
                                        _lastListUpdateDate = CFAbsoluteTimeGetCurrent();
                                        
                                        [_tableView beginUpdates];
                                        [_tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:itemIndex inSection:sectionIndex]] withRowAnimation:UITableViewRowAnimationMiddle];
                                        [_tableView endUpdates];
                                        
                                        if (section.items.count != 0)
                                        {
                                            if (itemIndex != 0)
                                            {
                                                UITableViewCell *cellBefore = [_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:itemIndex - 1 inSection:sectionIndex]];
                                                if ([cellBefore isKindOfClass:[TGGroupedCell class]])
                                                {
                                                    TGGroupedCell *groupedCellBefore = (TGGroupedCell *)cellBefore;
                                                    updateGroupedCellBackground(groupedCellBefore, itemIndex - 1 == 0, itemIndex == (int)section.items.count, true);
                                                }
                                            }
                                        }
                                        
                                        [self updateEditableStates];
                                        
                                        break;
                                    }
                                }
                            }
                            
                            break;
                        }
                    }
                }
                
                NSString *errorText = TGLocalized(@"ConversationProfile.UnknownAddMemberError");
                if (resultCode == -2)
                {
                    TGUser *user = [TGDatabaseInstance() loadUser:uid];
                    if (user != nil)
                        errorText = [[NSString alloc] initWithFormat:TGLocalized(@"ConversationProfile.UserLeftChatError"), user.displayName];
                }
                else if (resultCode == -3)
                {
                    errorText = TGLocalized(@"ConversationProfile.UsersTooMuchError");
                }
                    
                UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:nil message:errorText delegate:nil cancelButtonTitle:NSLocalizedString(@"Common.OK", nil) otherButtonTitles:nil];
                [alertView show];
            }
            else
            {
                NSDictionary *dict = ((SGraphObjectNode *)result).object;
                int version = [[dict objectForKey:@"version"] intValue];
                
                _conversation = [_conversation copy];
                _conversation.chatVersion = version;
            }
            
            if (uid == TGTelegraphInstance.clientUserId)
            {
                [self updateTitle];
            }
        });
    }
    else if ([path hasPrefix:[NSString stringWithFormat:@"/tg/conversation/(%lld)/deleteMember/(", _conversation.conversationId]])
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            NSRange range = [path rangeOfString:@"/deleteMember/("];
            int uid = [[path substringFromIndex:(range.location + range.length)] intValue];
            
            _usersWithActionInProgress.erase(uid);
            
            for (UITableViewCell *cell in _tableView.visibleCells)
            {
                if ([cell isKindOfClass:[TGUserMenuItemCell class]])
                {
                    TGUserMenuItemCell *userCell = (TGUserMenuItemCell *)cell;
                    if (userCell.uid == uid)
                    {
                        [userCell setIsDisabled:false animated:true];
                        break;
                    }
                }
            }
            
            if (resultCode == ASStatusSuccess)
            {
                NSDictionary *dict = ((SGraphObjectNode *)result).object;
                int version = [[dict objectForKey:@"version"] intValue];
                
                _conversation = [_conversation copy];
                _conversation.chatVersion = version;
                
                int sectionIndex = -1;
                for (TGMenuSection *section in _sectionList)
                {
                    sectionIndex++;
                    if (section.tag == TGMembersSectionTag)
                    {
                        int itemIndex = -1;
                        for (TGMenuItem *item in section.items)
                        {
                            itemIndex++;
                            if (item.type == TGUserMenuItemType)
                            {
                                if (((TGUserMenuItem *)item).user.uid == uid)
                                {
                                    [section.items removeObjectAtIndex:itemIndex];
                                    
                                    _lastListUpdateDate = CFAbsoluteTimeGetCurrent();
                                    
                                    [_tableView beginUpdates];
                                    [_tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:itemIndex inSection:sectionIndex]] withRowAnimation:UITableViewRowAnimationFade];
                                    [_tableView endUpdates];
                                    
                                    if (section.items.count != 0)
                                    {
                                        if (itemIndex != 0)
                                        {
                                            UITableViewCell *cellBefore = [_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:itemIndex - 1 inSection:sectionIndex]];
                                            if ([cellBefore isKindOfClass:[TGGroupedCell class]])
                                            {
                                                TGGroupedCell *groupedCellBefore = (TGGroupedCell *)cellBefore;
                                                updateGroupedCellBackground(groupedCellBefore, itemIndex - 1 == 0, itemIndex == (int)section.items.count, true);
                                            }
                                        }
                                    }
                                    
                                    [self updateEditableStates];
                                    
                                    break;
                                }
                            }
                        }
                        
                        break;
                    }
                }
            }
            else
            {
                UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:nil message:NSLocalizedString(@"An error occured", nil) delegate:nil cancelButtonTitle:NSLocalizedString(@"Common.OK", nil) otherButtonTitles:nil];
                [alertView show];
            }
            
            if (uid == TGTelegraphInstance.clientUserId)
            {
                [self updateTitle];
            }
        });
    }
    else if ([path hasPrefix:[NSString stringWithFormat:@"/tg/conversation/(%lld)/changeTitle", _conversation.conversationId]])
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            _currentUpdatingTitle = nil;
            _updatingTitle = false;
            
            if (resultCode == ASStatusSuccess)
            {
                TGConversation *resultConversation = ((SGraphObjectNode *)result).object;
                _conversationTitleField.text = resultConversation.chatTitle;
                _conversationTitleLabel.text = resultConversation.chatTitle;
            }
            else
            {
                _conversationTitleField.text = _conversation.chatTitle;
                _conversationTitleLabel.text = _conversation.chatTitle;
            }
            
            _conversationTitleField.userInteractionEnabled = true;
            _conversationTitleField.textColor = [UIColor blackColor];
            
            _conversationTitleLabel.textColor = UIColorRGB(0x333537);
        });
    }
    else if ([path hasPrefix:[NSString stringWithFormat:@"/tg/conversation/(%lld)/updateAvatar", _conversation.conversationId]])
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            _currentUploadingImage = nil;
            _updatingAvatar = false;
            
            if (resultCode == ASStatusSuccess)
            {
                TGConversation *resultConversation = ((SGraphObjectNode *)result).object;
                _avatarView.currentUrl = resultConversation.chatPhotoSmall;
                
                [self setShowAvatarActivity:false animated:resultConversation.chatPhotoSmall.length != 0];
            }
            else
            {
                if (_conversation.chatPhotoSmall.length == 0)
                {
                    [_avatarView loadImage:nil];
                    _addPhotoButton.hidden = false;
                    _avatarViewEdit.hidden = true;
                }
                else
                {
                    [_avatarView loadImage:_conversation.chatPhotoSmall filter:@"profileAvatar" placeholder:nil];
                    _addPhotoButton.hidden = true;
                    _avatarViewEdit.hidden = false;
                }
                
                [self setShowAvatarActivity:false animated:false];
            }
        });
    }
    else if ([path hasPrefix:@"/tg/conversation/createChat/"])
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            [_progressWindow dismiss:true];
            _progressWindow = nil;
            
            if (resultCode == ASStatusSuccess)
            {
                id<ASWatcher> watcher = _watcher.delegate;
                if (watcher != nil && [watcher respondsToSelector:@selector(actionStageActionRequested:options:)])
                    [watcher actionStageActionRequested:@"chatCreated" options:nil];
                
                TGConversation *conversation = ((SGraphObjectNode *)result).object;
                
                if (_createChatPhotoData != nil && _createChatPhotoThumbnail != nil)
                {
                    NSMutableDictionary *uploadOptions = [[NSMutableDictionary alloc] init];
                    [uploadOptions setObject:_createChatPhotoData forKey:@"imageData"];
                    [uploadOptions setObject:[NSNumber numberWithLongLong:conversation.conversationId] forKey:@"conversationId"];
                    
                    [uploadOptions setObject:_createChatPhotoThumbnail forKey:@"currentImage"];
                    
                    [ActionStageInstance() dispatchOnStageQueue:^
                    {
                        static int actionId = 0;
                        [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/conversation/(%lld)/updateAvatar/(cr%d)", conversation.conversationId, actionId++] options:uploadOptions watcher:TGTelegraphInstance];
                    }];
                }
                
                [[TGInterfaceManager instance] navigateToConversationWithId:conversation.conversationId conversation:conversation forwardMessages:nil atMessageId:0 clearStack:true openKeyboard:true animated:true];
            }
            else
            {
                UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:nil message:NSLocalizedString(@"ConversationProfile.ErrorCreatingConversation", @"") delegate:nil cancelButtonTitle:NSLocalizedString(@"Common.OK", @"") otherButtonTitles:nil];
                [alertView show];
            }
        });
    }
}

- (NSUInteger)sectionIndexForTag:(int)tag
{
    int iSection = -1;
    for (TGMenuSection *section in _sectionList)
    {
        iSection++;
        
        if (section.tag == tag)
            return iSection;
    }
    
    return NSNotFound;
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

- (void)updateNotificationSettingsItems:(bool)__unused animated
{
    int muteUntil = [[_peerNotificationSettings objectForKey:@"muteUntil"] intValue];
    int soundId = [[_peerNotificationSettings objectForKey:@"soundId"] intValue];
    
    _notificationsMenuItem.isOn = muteUntil == 0;
    
    NSArray *soundsArray = [TGAppDelegateInstance alertSoundTitles];
    if (soundId >= 0 && soundId < (int)soundsArray.count)
        _customSoundMenuItem.variant = [soundsArray objectAtIndex:soundId];
    else
        _customSoundMenuItem.variant = [[NSString alloc] initWithFormat:@"Sound %d", soundId];
    
    int sectionIndex = 0;
    int itemIndex = 0;
    if ([self findMenuItem:_notificationsMenuItem.tag sectionIndex:&sectionIndex itemIndex:&itemIndex])
    {
        TGSwitchItemCell *switchCell = (TGSwitchItemCell *)[_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:itemIndex inSection:sectionIndex]];
        if ([switchCell isKindOfClass:[TGSwitchItemCell class]])
            [switchCell setIsOn:_notificationsMenuItem.isOn];
    }
    
    if ([self findMenuItem:_customSoundMenuItem.tag sectionIndex:&sectionIndex itemIndex:&itemIndex])
    {
        TGVariantMenuItemCell *variantCell = (TGVariantMenuItemCell *)[_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:itemIndex inSection:sectionIndex]];
        if ([variantCell isKindOfClass:[TGVariantMenuItemCell class]])
            [variantCell setVariant:_customSoundMenuItem.variant];
    }
}

- (void)updateCreateChatMode
{
    [UIView animateWithDuration:0.3 animations:^
    {
        [self setExplicitTableInset:UIEdgeInsetsMake(_createChatBroadcast ? -59 : 0, 0, 0, 0) scrollIndicatorInset:UIEdgeInsetsZero];
        
        _headerView.alpha = _createChatBroadcast ? 0.0f : 1.0f;
        [_tableView layoutSubviews];
    }];
    
    self.titleText = _createChatBroadcast ? @"Broadcast" : TGLocalized(@"Compose.NewGroup");
    
    if ([self.navigationItem.rightBarButtonItem.customView isKindOfClass:[TGToolbarButton class]])
    {
        NSString *withoutWhitespace = [_conversationTitleField.text stringByReplacingOccurrencesOfString:@" " withString:@"" options:NSLiteralSearch range:NSMakeRange(0, _conversationTitleField.text.length)];
        
        ((TGToolbarButton *)self.navigationItem.rightBarButtonItem.customView).enabled = _createChatBroadcast ? true : withoutWhitespace.length != 0;
        ((TGToolbarButton *)self.navigationItem.rightBarButtonItem.customView).text = _createChatBroadcast ? TGLocalized(@"Common.Next") : TGLocalized(@"Compose.Create");
        [((TGToolbarButton *)self.navigationItem.rightBarButtonItem.customView) sizeToFit];
    }

    /*[_tableView beginUpdates];
    [_tableView reloadSections:[[NSIndexSet alloc] initWithIndex:0] withRowAnimation:UITableViewRowAnimationFade];
    [_tableView endUpdates];*/
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    alertView.delegate = nil;
    
    if (alertView == _currentAlertView)
        _currentAlertView = nil;
    
    if (alertView.tag == TGAddMemberConfirmationAlertTag)
    {
        if (buttonIndex != alertView.cancelButtonIndex)
        {
            int uid = _actionSheetUid;
            
            TGUser *user = [TGDatabaseInstance() loadUser:uid];
            if (user != nil)
            {
                _usersWithActionInProgress.insert(uid);
                
                int sectionIndex = -1;
                for (TGMenuSection *section in _sectionList)
                {
                    sectionIndex++;
                    if (section.tag == TGMembersSectionTag)
                    {
                        bool found = false;
                        for (TGMenuItem *item in section.items)
                        {
                            if (item.type == TGUserMenuItemType)
                            {
                                if (((TGUserMenuItem *)item).user.uid == user.uid)
                                {
                                    found = true;
                                    break;
                                }
                            }
                        }
                        
                        if (!found)
                        {
                            TGUserMenuItem *userItem = [[TGUserMenuItem alloc] init];
                            userItem.user = user;
                            [section.items insertObject:userItem atIndex:section.items.count];
                            
                            section.items = [[self updateUsersSortingInArray:section.items] mutableCopy];
                            
                            [_tableView reloadData];
                            
                            [self updateEditableStates];
                        }
                        
                        break;
                    }
                }
                
                [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/conversation/(%lld)/addMember/(%d)", _conversation.conversationId, uid] options:[[NSDictionary alloc] initWithObjectsAndKeys:[NSNumber numberWithLongLong:_conversation.conversationId], @"conversationId", [NSNumber numberWithInt:uid], @"uid", nil] watcher:self];
                
                if (_contactsController != nil && self.navigationController.topViewController == _contactsController)
                {
                    [self.navigationController popViewControllerAnimated:true];
                    _contactsController = nil;
                }
            }
        }
        
        _actionSheetUid = 0;
    }
}

@end
