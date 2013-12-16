#import "TGNotificationSettingsController.h"

#import "SGraphObjectNode.h"

#import "TGInterfaceAssets.h"

#import "TGActionTableView.h"

#import "TGMenuSection.h"

#import "TGActionMenuItem.h"
#import "TGActionMenuItemCell.h"

#import "TGSwitchItem.h"
#import "TGSwitchItemCell.h"

#import "TGVariantMenuItem.h"
#import "TGVariantMenuItemCell.h"

#import "TGCommentMenuItem.h"
#import "TGCommentMenuItemView.h"

#import "TGButtonMenuItem.h"
#import "TGButtonMenuItemCell.h"

#import "TGCustomNotificationController.h"

#import "TGAppDelegate.h"

#import "TGTelegraph.h"

#import "TGSettingsController.h"

typedef enum {
    TGDialogMessageNotifications = 1,
    TGDialogMessageSound,
    TGDialogMessagePreview,
    TGGroupMessageNotifications,
    TGGroupMessageSound,
    TGGroupMessagePreview,
    TGInAppSound,
    TGInAppVibrate,
    TGInAppBanner,
    TGAlwaysCheckNearby,
    TGAlwaysCheckNearbyComment
} TGNotificationSettingsTags;

@interface TGNotificationSettingsController () <UITableViewDataSource, UITableViewDelegate, UIActionSheetDelegate>

@property (nonatomic, strong) TGActionTableView *tableView;
@property (nonatomic) float currentTableWidth;

@property (nonatomic, strong) NSArray *sectionList;

@property (nonatomic, strong) NSArray *sectionHeaderViews;

@property (nonatomic, strong) NSMutableDictionary *messageNotificationSettings;
@property (nonatomic, strong) NSMutableDictionary *groupNotificationSettings;

@property (nonatomic, strong) UIActionSheet *currentActionSheet;

@end

@implementation TGNotificationSettingsController

@synthesize actionHandle = _actionHandle;

@synthesize tableView = _tableView;
@synthesize currentTableWidth = _currentTableWidth;

@synthesize sectionList = _sectionList;

@synthesize sectionHeaderViews = _sectionHeaderViews;

@synthesize messageNotificationSettings = _messageNotificationSettings;
@synthesize groupNotificationSettings = _groupNotificationSettings;

@synthesize currentActionSheet = _currentActionSheet;

- (id)init
{
    self = [super initWithNibName:nil bundle:nil];
    if (self)
    {
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:true];
        
        NSMutableArray *sectionList = [[NSMutableArray alloc] init];
        
        TGMenuSection *dialogMessageSection = [[TGMenuSection alloc] init];
        dialogMessageSection.title = TGLocalized(@"Notifications.MessageNotifications");
        [sectionList addObject:dialogMessageSection];
        
        TGSwitchItem *dialogMessageEnabledItem = [[TGSwitchItem alloc] initWithTitle:TGLocalized(@"Notifications.MessageNotificationsAlert")];
        dialogMessageEnabledItem.tag = TGDialogMessageNotifications;
        dialogMessageEnabledItem.isOn = true;
        [dialogMessageSection.items addObject:dialogMessageEnabledItem];
        
        TGSwitchItem *dialogMessagePreviewItem = [[TGSwitchItem alloc] initWithTitle:TGLocalized(@"Notifications.MessageNotificationsPreview")];
        dialogMessagePreviewItem.tag = TGDialogMessagePreview;
        dialogMessagePreviewItem.isOn = true;
        [dialogMessageSection.items addObject:dialogMessagePreviewItem];
        
        TGVariantMenuItem *dialogMessageSoundItem = [[TGVariantMenuItem alloc] init];
        dialogMessageSoundItem.tag = TGDialogMessageSound;
        dialogMessageSoundItem.title = TGLocalized(@"Notifications.MessageNotificationsSound");
        dialogMessageSoundItem.variant = [[TGAppDelegateInstance alertSoundTitles] objectAtIndex:2];
        dialogMessageSoundItem.action = @selector(dialogMessageSoundButtonPressed);
        [dialogMessageSection.items addObject:dialogMessageSoundItem];
        
        TGCommentMenuItem *dialogMessageCommentItem = [[TGCommentMenuItem alloc] initWithComment:TGLocalized(@"Notifications.MessageNotificationsHelp")];
        [dialogMessageSection.items addObject:dialogMessageCommentItem];
        
        TGMenuSection *groupMessageSection = [[TGMenuSection alloc] init];
        groupMessageSection.title = TGLocalized(@"Notifications.GroupNotifications");
        [sectionList addObject:groupMessageSection];
        
        TGSwitchItem *groupMessageEnabledItem = [[TGSwitchItem alloc] initWithTitle:TGLocalized(@"Notifications.GroupNotificationsAlert")];
        groupMessageEnabledItem.tag = TGGroupMessageNotifications;
        groupMessageEnabledItem.isOn = true;
        [groupMessageSection.items addObject:groupMessageEnabledItem];
        
        TGSwitchItem *groupMessagePreviewItem = [[TGSwitchItem alloc] initWithTitle:TGLocalized(@"Notifications.GroupNotificationsPreview")];
        groupMessagePreviewItem.tag = TGGroupMessagePreview;
        groupMessagePreviewItem.isOn = true;
        [groupMessageSection.items addObject:groupMessagePreviewItem];
        
        TGVariantMenuItem *groupMessageSoundItem = [[TGVariantMenuItem alloc] init];
        groupMessageSoundItem.tag = TGGroupMessageSound;
        groupMessageSoundItem.title = TGLocalized(@"Notifications.GroupNotificationsSound");
        groupMessageSoundItem.variant = [[TGAppDelegateInstance alertSoundTitles] objectAtIndex:2];
        groupMessageSoundItem.action = @selector(groupMessageSoundButtonPressed);
        [groupMessageSection.items addObject:groupMessageSoundItem];
        
        TGCommentMenuItem *groupMessageCommentItem = [[TGCommentMenuItem alloc] initWithComment:TGLocalized(@"Notifications.GroupNotificationsHelp")];
        [groupMessageSection.items addObject:groupMessageCommentItem];
        
        TGMenuSection *inAppSection = [[TGMenuSection alloc] init];
        inAppSection.title = TGLocalized(@"Notifications.InAppNotifications");
        [sectionList addObject:inAppSection];
        
        TGSwitchItem *inAppSoundItem = [[TGSwitchItem alloc] initWithTitle:TGLocalized(@"Notifications.InAppNotificationsSounds")];
        inAppSoundItem.tag = TGInAppSound;
        inAppSoundItem.isOn = TGAppDelegateInstance.soundEnabled;
        [inAppSection.items addObject:inAppSoundItem];
        
        TGSwitchItem *inAppVibrateItem = [[TGSwitchItem alloc] initWithTitle:TGLocalized(@"Notifications.InAppNotificationsVibrate")];
        inAppVibrateItem.tag = TGInAppVibrate;
        inAppVibrateItem.isOn = TGAppDelegateInstance.vibrationEnabled;
        [inAppSection.items addObject:inAppVibrateItem];
        
        TGSwitchItem *inAppPreviewItem = [[TGSwitchItem alloc] initWithTitle:TGLocalized(@"Notifications.InAppNotificationsPreview")];
        inAppPreviewItem.tag = TGInAppBanner;
        inAppPreviewItem.isOn = TGAppDelegateInstance.bannerEnabled;
        [inAppSection.items addObject:inAppPreviewItem];
        
        /*TGMenuSection *nearbySection = [[TGMenuSection alloc] init];
        nearbySection.title = TGLocalized(@"Notifications.LocationServices");
        [sectionList addObject:nearbySection];
        
        TGSwitchItem *alwaysCheckNearbyItem = [[TGSwitchItem alloc] initWithTitle:TGLocalized(@"Notifications.LocationServicesPeopleNearby")];
        alwaysCheckNearbyItem.tag = TGAlwaysCheckNearby;
        alwaysCheckNearbyItem.isOn = TGAppDelegateInstance.locationTranslationEnabled;
        [nearbySection.items addObject:alwaysCheckNearbyItem];
        
        TGCommentMenuItem *nearbyCommentItem = [[TGCommentMenuItem alloc] initWithComment:TGLocalized(@"Notifications.LocationServicesHelp")];
        nearbyCommentItem.tag = TGAlwaysCheckNearby;
        [nearbySection.items addObject:nearbyCommentItem];*/
        
#if defined(DEBUG) || defined(INTERNAL_RELEASE)
        TGActionMenuItem *debugItem = [[TGActionMenuItem alloc] initWithTitle:@"Debug"];
        debugItem.action = @selector(debugButtonPressed);
        
        TGMenuSection *debugSection = [[TGMenuSection alloc] init];
        [debugSection.items addObject:debugItem];
        [sectionList addObject:debugSection];
#endif
        
        TGMenuSection *resetSection = [[TGMenuSection alloc] init];
        [sectionList addObject:resetSection];
        
        TGButtonMenuItem *resetItem = [[TGButtonMenuItem alloc] initWithTitle:TGLocalized(@"Notifications.ResetAllNotifications") subtype:TGButtonMenuItemSubtypeRedButton];
        resetItem.action = @selector(resetButtonPressed);
        [resetSection.items addObject:resetItem];
        
        TGCommentMenuItem *resetCommentItem = [[TGCommentMenuItem alloc] initWithComment:TGLocalized(@"Notifications.ResetAllNotificationsHelp")];
        [resetSection.items addObject:resetCommentItem];
        
        _sectionList = sectionList;
        
        [ActionStageInstance() dispatchOnStageQueue:^
        {
            [ActionStageInstance() watchForPath:[NSString stringWithFormat:@"/tg/peerSettings/(%d)", INT_MAX - 1] watcher:self];
            [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/peerSettings/(%d,cached)", INT_MAX - 1] options:[NSDictionary dictionaryWithObject:[NSNumber numberWithLongLong:INT_MAX - 1] forKey:@"peerId"] watcher:self];
            [ActionStageInstance() watchForPath:[NSString stringWithFormat:@"/tg/peerSettings/(%d)", INT_MAX - 2] watcher:self];
            [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/peerSettings/(%d,cached)", INT_MAX - 2] options:[NSDictionary dictionaryWithObject:[NSNumber numberWithLongLong:INT_MAX - 2] forKey:@"peerId"] watcher:self];
        }];
    }
    return self;
}

- (void)dealloc
{
    [self doUnloadView];
    
    _currentActionSheet.delegate = nil;
    
    [_actionHandle reset];
    [ActionStageInstance() removeWatcher:self];
}

- (void)loadView
{
    [super loadView];
    
    self.view.backgroundColor = [[TGInterfaceAssets instance] linesBackground];
    
    self.titleText = TGLocalized(@"Notifications.Title");
    self.backAction = @selector(performClose);
    
    _tableView = [[TGActionTableView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height) style:UITableViewStyleGrouped];
    [_tableView enableSwipeToLeftAction];
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.backgroundColor = [UIColor clearColor];
    _tableView.opaque = false;
    _tableView.backgroundView = nil;
    _currentTableWidth = _tableView.frame.size.width;
    [self.view addSubview:_tableView];
    
    if (_sectionHeaderViews == nil)
        [self generateSectionHeaders];
}

- (void)doUnloadView
{
    _tableView.delegate = nil;
    _tableView.dataSource = nil;
    
    _currentActionSheet.delegate = nil;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    _currentTableWidth = [TGViewController screenSizeForInterfaceOrientation:toInterfaceOrientation].width;
    
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
}

- (void)viewWillAppear:(BOOL)animated
{
    if ([_tableView indexPathForSelectedRow] != nil)
        [_tableView deselectRowAtIndexPath:[_tableView indexPathForSelectedRow] animated:true];
    
    _currentTableWidth = [TGViewController screenSizeForInterfaceOrientation:self.interfaceOrientation].width;
    
    [super viewWillAppear:animated];
}

- (void)generateSectionHeaders
{
    NSMutableArray *array = [[NSMutableArray alloc] init];
    
    UIFont *titleFont = [UIFont boldSystemFontOfSize:17];
    
    for (TGMenuSection *section in _sectionList)
    {
        if (section.title == nil)
            [array addObject:[NSNull null]];
        else
        {
            UILabel *titleFieldLabel = [[UILabel alloc] init];
            titleFieldLabel.text = section.title;
            titleFieldLabel.backgroundColor = [UIColor clearColor];
            titleFieldLabel.font = titleFont;
            titleFieldLabel.textColor = UIColorRGB(0x697487);
            titleFieldLabel.shadowColor = UIColorRGB(0xdae0e8);
            titleFieldLabel.shadowOffset = CGSizeMake(0, 1);
            [titleFieldLabel sizeToFit];
            titleFieldLabel.frame = CGRectOffset(titleFieldLabel.frame, 21, 16);
            
            UIView *labelContainer = [[UIView alloc] init];
            [labelContainer addSubview:titleFieldLabel];
            [array addObject:labelContainer];
        }
    }
    
    _sectionHeaderViews = array;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
}

- (BOOL)shouldAutorotate
{
    return true;
}

#pragma mark -

- (NSInteger)numberOfSectionsInTableView:(UITableView *)__unused tableView
{
    return _sectionList.count;
}

- (NSInteger)tableView:(UITableView *)__unused tableView numberOfRowsInSection:(NSInteger)section
{
    return section >= (int)_sectionList.count ? 0 : ((TGMenuSection *)[_sectionList objectAtIndex:section]).items.count;
}

- (CGFloat)tableView:(UITableView *)__unused tableView heightForHeaderInSection:(NSInteger)section
{
    id headerView = [_sectionHeaderViews objectAtIndex:section];
    if (headerView != nil && [headerView isKindOfClass:[UIView class]])
    {
        return 46;
    }
    return 8;
}

- (UIView *)tableView:(UITableView *)__unused tableView viewForHeaderInSection:(NSInteger)section
{
    id headerView = [_sectionHeaderViews objectAtIndex:section];
    if (headerView != nil && [headerView isKindOfClass:[UIView class]])
        return headerView;
    
    return nil;
}

-(CGFloat)tableView:(UITableView*)__unused tableView heightForFooterInSection:(NSInteger)__unused section
{
    return 1;
}

- (CGFloat)tableView:(UITableView *)__unused tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section < (int)_sectionList.count)
    {
        TGMenuSection *section = [_sectionList objectAtIndex:indexPath.section];
        if (indexPath.row < (int)section.items.count)
        {
            TGMenuItem *item = [section.items objectAtIndex:indexPath.row];
            
            if (item.type == TGActionMenuItemType || item.type == TGSwitchItemType || item.type == TGVariantMenuItemType)
                return 44;
            else if (item.type == TGButtonMenuItemType)
                return 45;
            else if (item.type == TGCommentMenuItemType)
                return [(TGCommentMenuItem *)item heightForWidth:_currentTableWidth];
        }
    }
    
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)__unused tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
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
            
            cell = variantItemCell;
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
                if (firstInSection && lastInSection)
                {
                    [(TGGroupedCell *)cell setGroupedCellPosition:TGGroupedCellPositionFirst | TGGroupedCellPositionLast];
                    [(TGGroupedCell *)cell setExtendSelectedBackground:false];
                    
                    ((UIImageView *)cell.backgroundView).image = [TGInterfaceAssets groupedCellSingle];
                    ((UIImageView *)cell.selectedBackgroundView).image = [TGInterfaceAssets groupedCellSingleHighlighted];
                }
                else if (firstInSection)
                {
                    [(TGGroupedCell *)cell setGroupedCellPosition:TGGroupedCellPositionFirst];
                    [(TGGroupedCell *)cell setExtendSelectedBackground:true];
                    
                    ((UIImageView *)cell.backgroundView).image = [TGInterfaceAssets groupedCellTop];
                    ((UIImageView *)cell.selectedBackgroundView).image = [TGInterfaceAssets groupedCellTopHighlighted];
                }
                else if (lastInSection)
                {
                    [(TGGroupedCell *)cell setGroupedCellPosition:TGGroupedCellPositionLast];
                    [(TGGroupedCell *)cell setExtendSelectedBackground:true];
                    
                    ((UIImageView *)cell.backgroundView).image = [TGInterfaceAssets groupedCellBottom];
                    ((UIImageView *)cell.selectedBackgroundView).image = [TGInterfaceAssets groupedCellBottomHighlighted];
                }
                else
                {
                    [(TGGroupedCell *)cell setGroupedCellPosition:0];
                    [(TGGroupedCell *)cell setExtendSelectedBackground:true];
                    
                    ((UIImageView *)cell.backgroundView).image = [TGInterfaceAssets groupedCellMiddle];
                    ((UIImageView *)cell.selectedBackgroundView).image = [TGInterfaceAssets groupedCellMiddleHighlighted];
                }
            }
            
            return cell;
        }
    }
    
    static NSString *emptyCellIdentifier = @"NULL";
    UITableViewCell *emptyCell = [tableView dequeueReusableCellWithIdentifier:emptyCellIdentifier];
    if (emptyCell == nil)
    {
        emptyCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:emptyCellIdentifier];
        emptyCell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    
    return emptyCell;
}

- (void)tableView:(UITableView *)__unused tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
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
    }
}

#pragma mark -

- (void)performClose
{
    [self.navigationController popViewControllerAnimated:true];
}

- (void)performSwipeToLeftAction
{
    [self performClose];
}

- (void)dialogMessageSoundButtonPressed
{
    int soundId = 2;
    
    NSNumber *nDialogSoundIndex = [_messageNotificationSettings objectForKey:@"soundId"];
    if (nDialogSoundIndex != nil)
        soundId = [nDialogSoundIndex intValue];
    if (soundId == 1)
        soundId = 2;
    
    TGCustomNotificationController *customNotificationController = [[TGCustomNotificationController alloc] initWithMode:TGCustomNotificationControllerModeSettings];
    customNotificationController.watcherHandle = _actionHandle;
    customNotificationController.tag = TGDialogMessageSound;
    customNotificationController.selectedIndex = soundId;
    [customNotificationController skipDefault];
    
    TGNavigationController *navigationController = [TGNavigationController navigationControllerWithRootController:customNotificationController blackCorners:false];
    
    [self presentViewController:navigationController animated:true completion:nil];
}

- (void)groupMessageSoundButtonPressed
{
    int soundId = 2;
    
    NSNumber *nDialogSoundIndex = [_groupNotificationSettings objectForKey:@"soundId"];
    if (nDialogSoundIndex != nil)
        soundId = [nDialogSoundIndex intValue];
    if (soundId == 1)
        soundId = 2;
    
    TGCustomNotificationController *customNotificationController = [[TGCustomNotificationController alloc] initWithMode:TGCustomNotificationControllerModeSettings];
    customNotificationController.watcherHandle = _actionHandle;
    customNotificationController.tag = TGGroupMessageSound;
    customNotificationController.selectedIndex = soundId;
    [customNotificationController skipDefault];
    
    TGNavigationController *navigationController = [TGNavigationController navigationControllerWithRootController:customNotificationController blackCorners:false];
    
    [self presentViewController:navigationController animated:true completion:nil];
}

- (void)resetButtonPressed
{
    if ([_tableView indexPathForSelectedRow] != nil)
        [_tableView deselectRowAtIndexPath:[_tableView indexPathForSelectedRow] animated:true];
    
    if (_currentActionSheet != nil)
        _currentActionSheet.delegate = nil;
    
    _currentActionSheet = [[UIActionSheet alloc] initWithTitle:TGLocalized(@"Notifications.ResetAllNotificationsHelp") delegate:self cancelButtonTitle:TGLocalized(@"Common.Cancel") destructiveButtonTitle:TGLocalized(@"Notifications.Reset") otherButtonTitles:nil];
    [_currentActionSheet showInView:self.view];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == actionSheet.destructiveButtonIndex)
    {
        [_messageNotificationSettings setObject:[[NSNumber alloc] initWithInt:0] forKey:@"muteUntil"];
        [_messageNotificationSettings setObject:[[NSNumber alloc] initWithInt:1] forKey:@"soundId"];
        [_messageNotificationSettings setObject:[[NSNumber alloc] initWithBool:true] forKey:@"previewText"];
        
        [_groupNotificationSettings setObject:[[NSNumber alloc] initWithInt:0] forKey:@"muteUntil"];
        [_groupNotificationSettings setObject:[[NSNumber alloc] initWithInt:1] forKey:@"soundId"];
        [_groupNotificationSettings setObject:[[NSNumber alloc] initWithBool:true] forKey:@"previewText"];
        
        [self updateNotificationSettingsItems];
        
        TGAppDelegateInstance.soundEnabled = true;
        TGAppDelegateInstance.vibrationEnabled = true;
        TGAppDelegateInstance.bannerEnabled = true;
        [TGAppDelegateInstance saveSettings];
        
        int sectionIndex = 0;
        int itemIndex = 0;
        if ([self findMenuItem:TGInAppSound sectionIndex:&sectionIndex itemIndex:&itemIndex])
            [(TGSwitchItemCell *)[_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:itemIndex inSection:sectionIndex]] setIsOn:true animated:false];
        if ([self findMenuItem:TGInAppVibrate sectionIndex:&sectionIndex itemIndex:&itemIndex])
            [(TGSwitchItemCell *)[_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:itemIndex inSection:sectionIndex]] setIsOn:true animated:false];
        if ([self findMenuItem:TGInAppBanner sectionIndex:&sectionIndex itemIndex:&itemIndex])
            [(TGSwitchItemCell *)[_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:itemIndex inSection:sectionIndex]] setIsOn:true animated:false];
        
        [ActionStageInstance() requestActor:@"/tg/resetPeerSettings" options:nil watcher:TGTelegraphInstance];
    }
}

#pragma mark -

- (void)actionStageActionRequested:(NSString *)action options:(NSDictionary *)options
{
    if ([action isEqualToString:@"toggleSwitchItem"])
    {
        static int actionId = 0;
        
        TGSwitchItem *switchItem = [options objectForKey:@"itemId"];
        if (switchItem == nil)
            return;
        
        NSNumber *nValue = [options objectForKey:@"value"];
        
        switchItem.isOn = [nValue boolValue];
        
        if (switchItem.tag == TGDialogMessageNotifications)
        {
            int muteUntil = switchItem.isOn ? 0 : INT_MAX;
            
            [_messageNotificationSettings setObject:[NSNumber numberWithInt:muteUntil] forKey:@"muteUntil"];
            
            [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/changePeerSettings/(%d)/(pc%d)", INT_MAX - 1, actionId++] options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithLongLong:INT_MAX - 1], @"peerId", [NSNumber numberWithInt:muteUntil], @"muteUntil", nil] watcher:TGTelegraphInstance];
        }
        else if (switchItem.tag == TGDialogMessagePreview)
        {
            [_messageNotificationSettings setObject:[NSNumber numberWithBool:switchItem.isOn] forKey:@"previewText"];
            
            [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/changePeerSettings/(%d)/(pc%d)", INT_MAX - 1, actionId++] options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithLongLong:INT_MAX - 1], @"peerId", [NSNumber numberWithBool:switchItem.isOn], @"previewText", nil] watcher:TGTelegraphInstance];
        }
        else if (switchItem.tag == TGGroupMessageNotifications)
        {
            int muteUntil = switchItem.isOn ? 0 : INT_MAX;
            
            [_groupNotificationSettings setObject:[NSNumber numberWithInt:muteUntil] forKey:@"muteUntil"];
            
            [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/changePeerSettings/(%d)/(pc%d)", INT_MAX - 2, actionId++] options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithLongLong:INT_MAX - 2], @"peerId", [NSNumber numberWithInt:muteUntil], @"muteUntil", nil] watcher:TGTelegraphInstance];
        }
        else if (switchItem.tag == TGGroupMessagePreview)
        {
            [_groupNotificationSettings setObject:[NSNumber numberWithBool:switchItem.isOn] forKey:@"previewText"];
            
            [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/changePeerSettings/(%d)/(pc%d)", INT_MAX - 2, actionId++] options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithLongLong:INT_MAX - 2], @"peerId", [NSNumber numberWithBool:switchItem.isOn], @"previewText", nil] watcher:TGTelegraphInstance];
        }
        else if (switchItem.tag == TGInAppSound)
        {
            TGAppDelegateInstance.soundEnabled = switchItem.isOn;
            [TGAppDelegateInstance saveSettings];
        }
        else if (switchItem.tag == TGInAppVibrate)
        {
            TGAppDelegateInstance.vibrationEnabled = switchItem.isOn;
            [TGAppDelegateInstance saveSettings];
        }
        else if (switchItem.tag == TGInAppBanner)
        {
            TGAppDelegateInstance.bannerEnabled = switchItem.isOn;
            [TGAppDelegateInstance saveSettings];
        }
        else if (switchItem.tag == TGAlwaysCheckNearby)
        {
            TGAppDelegateInstance.locationTranslationEnabled = switchItem.isOn;
            [TGAppDelegateInstance saveSettings];
            
            [TGTelegraphInstance locationTranslationSettingsUpdated];
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
        
        if ([_tableView indexPathForSelectedRow] != nil)
            [_tableView deselectRowAtIndexPath:[_tableView indexPathForSelectedRow] animated:true];
        
        int tag = [[options objectForKey:@"tag"] intValue];
        
        static int actionId = 0;
        
        if (tag == TGDialogMessageSound)
        {
            NSNumber *nIndex = [options objectForKey:@"index"];
            if (nIndex != nil)
            {
                int currentSoundId = [[_messageNotificationSettings objectForKey:@"soundId"] intValue];
                if (currentSoundId == [nIndex intValue])
                    return;
                
                [_messageNotificationSettings setObject:[NSNumber numberWithInt:[nIndex intValue]] forKey:@"soundId"];
                [self updateNotificationSettingsItems];
                
                [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/changePeerSettings/(%d)/(pe%d)", INT_MAX - 1, actionId++] options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithLongLong:INT_MAX - 1], @"peerId", [NSNumber numberWithInt:[nIndex intValue]], @"soundId", nil] watcher:TGTelegraphInstance];
            }
        }
        else if (tag == TGGroupMessageSound)
        {
            NSNumber *nIndex = [options objectForKey:@"index"];
            if (nIndex != nil)
            {
                int currentSoundId = [[_groupNotificationSettings objectForKey:@"soundId"] intValue];
                if (currentSoundId == [nIndex intValue])
                    return;
                
                [_groupNotificationSettings setObject:[NSNumber numberWithInt:[nIndex intValue]] forKey:@"soundId"];
                [self updateNotificationSettingsItems];
                
                [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/changePeerSettings/(%d)/(pe%d)", INT_MAX - 2, actionId++] options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithLongLong:INT_MAX - 2], @"peerId", [NSNumber numberWithInt:[nIndex intValue]], @"soundId", nil] watcher:TGTelegraphInstance];
            }
        }
    }
}

- (void)actionStageResourceDispatched:(NSString *)path resource:(id)resource arguments:(id)__unused arguments
{
    if ([path hasPrefix:@"/tg/peerSettings"])
    {
        [self actorCompleted:ASStatusSuccess path:path result:resource];
    }
}

- (void)actorCompleted:(int)resultCode path:(NSString *)path result:(id)result
{
    if ([path hasPrefix:@"/tg/peerSettings/"])
    {
        if (resultCode == ASStatusSuccess)
        {
            NSDictionary *notificationSettings = ((SGraphObjectNode *)result).object;
            
            dispatch_async(dispatch_get_main_queue(), ^
            {
                if ([path hasPrefix:[NSString stringWithFormat:@"/tg/peerSettings/(%d", INT_MAX - 1]])
                {
                    _messageNotificationSettings = [notificationSettings mutableCopy];
                    [self updateNotificationSettingsItems];
                }
                else if ([path hasPrefix:[NSString stringWithFormat:@"/tg/peerSettings/(%d", INT_MAX - 2]])
                {
                    _groupNotificationSettings = [notificationSettings mutableCopy];
                    [self updateNotificationSettingsItems];
                }
            });
        }
    }
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
                if (sectionIndex != NULL)
                    *sectionIndex = iSection;
                if (itemIndex != NULL)
                    *itemIndex = iItem;
                
                return item;
            }
        }
    }
    
    return nil;
}

- (void)updateNotificationSettingsItems
{
    int sectionIndex = 0;
    int itemIndex = 0;
    
    TGSwitchItem *dialogMessageEnabledItem = (TGSwitchItem *)[self findMenuItem:TGDialogMessageNotifications sectionIndex:&sectionIndex itemIndex:&itemIndex];
    if (dialogMessageEnabledItem != nil)
    {
        dialogMessageEnabledItem.isOn = [[_messageNotificationSettings objectForKey:@"muteUntil"] intValue] == 0;
        TGSwitchItemCell *switchItemCell = (TGSwitchItemCell *)[_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:itemIndex inSection:sectionIndex]];
        if ([switchItemCell isKindOfClass:[TGSwitchItemCell class]])
            [switchItemCell setIsOn:dialogMessageEnabledItem.isOn animated:false];
    }
    
    TGVariantMenuItem *dialogMessageSoundItem = (TGVariantMenuItem *)[self findMenuItem:TGDialogMessageSound sectionIndex:&sectionIndex itemIndex:&itemIndex];
    if (dialogMessageSoundItem != nil)
    {
        int soundId = [[_messageNotificationSettings objectForKey:@"soundId"] intValue];
        if (soundId == 1)
            soundId = 2;
        if (soundId >= 0 && soundId < (int)[TGAppDelegateInstance alertSoundTitles].count)
            dialogMessageSoundItem.variant = [[TGAppDelegateInstance alertSoundTitles] objectAtIndex:soundId];
        TGVariantMenuItemCell *variantItemCell = (TGVariantMenuItemCell *)[_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:itemIndex inSection:sectionIndex]];
        if ([variantItemCell isKindOfClass:[TGVariantMenuItemCell class]])
            [variantItemCell setVariant:dialogMessageSoundItem.variant];
    }
    
    TGSwitchItem *dialogMessagePreviewItem = (TGSwitchItem *)[self findMenuItem:TGDialogMessagePreview sectionIndex:&sectionIndex itemIndex:&itemIndex];
    if (dialogMessagePreviewItem != nil)
    {
        dialogMessagePreviewItem.isOn = [[_messageNotificationSettings objectForKey:@"previewText"] boolValue];
        TGSwitchItemCell *switchItemCell = (TGSwitchItemCell *)[_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:itemIndex inSection:sectionIndex]];
        if ([switchItemCell isKindOfClass:[TGSwitchItemCell class]])
            [switchItemCell setIsOn:dialogMessagePreviewItem.isOn animated:false];
    }
    
    TGSwitchItem *groupMessageEnabledItem = (TGSwitchItem *)[self findMenuItem:TGGroupMessageNotifications sectionIndex:&sectionIndex itemIndex:&itemIndex];
    if (groupMessageEnabledItem != nil)
    {
        groupMessageEnabledItem.isOn = [[_groupNotificationSettings objectForKey:@"muteUntil"] intValue] == 0;
        TGSwitchItemCell *switchItemCell = (TGSwitchItemCell *)[_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:itemIndex inSection:sectionIndex]];
        if ([switchItemCell isKindOfClass:[TGSwitchItemCell class]])
            [switchItemCell setIsOn:groupMessageEnabledItem.isOn animated:false];
    }
    
    TGVariantMenuItem *groupMessageSoundItem = (TGVariantMenuItem *)[self findMenuItem:TGGroupMessageSound sectionIndex:&sectionIndex itemIndex:&itemIndex];
    if (groupMessageSoundItem != nil)
    {
        int soundId = [[_groupNotificationSettings objectForKey:@"soundId"] intValue];
        if (soundId == 1)
            soundId = 2;
        if (soundId >= 0 && soundId < (int)[TGAppDelegateInstance alertSoundTitles].count)
            groupMessageSoundItem.variant = [[TGAppDelegateInstance alertSoundTitles] objectAtIndex:soundId];
        TGVariantMenuItemCell *variantItemCell = (TGVariantMenuItemCell *)[_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:itemIndex inSection:sectionIndex]];
        if ([variantItemCell isKindOfClass:[TGVariantMenuItemCell class]])
            [variantItemCell setVariant:groupMessageSoundItem.variant];
    }
    
    TGSwitchItem *groupMessagePreviewItem = (TGSwitchItem *)[self findMenuItem:TGGroupMessagePreview sectionIndex:&sectionIndex itemIndex:&itemIndex];
    if (groupMessagePreviewItem != nil)
    {
        groupMessagePreviewItem.isOn = [[_groupNotificationSettings objectForKey:@"previewText"] boolValue];
        TGSwitchItemCell *switchItemCell = (TGSwitchItemCell *)[_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:itemIndex inSection:sectionIndex]];
        if ([switchItemCell isKindOfClass:[TGSwitchItemCell class]])
            [switchItemCell setIsOn:groupMessagePreviewItem.isOn animated:false];
    }
}

- (void)debugButtonPressed
{
    [self.navigationController pushViewController:[[TGSettingsController alloc] init] animated:true];
}

@end
