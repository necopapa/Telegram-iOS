#import "TGChatSettingsController.h"

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

#import "TGTelegraphConversationMessageAssetsSource.h"

#import "TGTextFontController.h"

#import "TGProgressWindow.h"

#define TGTextFontSizeTag ((int)0xA3DB2D05) 

@interface TGChatSettingsController () <UITableViewDataSource, UITableViewDelegate, UIActionSheetDelegate, UIAlertViewDelegate>

@property (nonatomic, strong) TGActionTableView *tableView;
@property (nonatomic) float currentTableWidth;

@property (nonatomic, strong) NSArray *sectionList;

@property (nonatomic, strong) NSArray *sectionHeaderViews;

@property (nonatomic, strong) UIActionSheet *currentActionSheet;
@property (nonatomic, strong) UIAlertView *currentAlertView;

@property (nonatomic, strong) TGProgressWindow *progressWindow;

@end

@implementation TGChatSettingsController

- (id)init
{
    self = [super initWithNibName:nil bundle:nil];
    if (self)
    {
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:true];
        
        NSMutableArray *sectionList = [[NSMutableArray alloc] init];
        _sectionList = sectionList;
        
        TGMenuSection *appearanceSection = [[TGMenuSection alloc] init];
        appearanceSection.title = TGLocalized(@"ChatSettings.Appearance");
        [sectionList addObject:appearanceSection];
        
        TGVariantMenuItem *textSizeItem = [[TGVariantMenuItem alloc] init];
        textSizeItem.tag = TGTextFontSizeTag;
        textSizeItem.title = TGLocalized(@"ChatSettings.TextSize");
        textSizeItem.variant = [[NSString alloc] initWithFormat:@"%dpt", TGBaseFontSize];
        textSizeItem.action = @selector(textSizeItemPressed);
        [appearanceSection.items addObject:textSizeItem];
        
        TGMenuSection *mediaSection = [[TGMenuSection alloc] init];
        mediaSection.title = TGLocalized(@"ChatSettings.AutomaticPhotoDownload");
        [sectionList addObject:mediaSection];
        
        TGSwitchItem *groupsItem = [[TGSwitchItem alloc] initWithTitle:TGLocalized(@"ChatSettings.Groups")];
        groupsItem.isOn = TGAppDelegateInstance.autoDownloadPhotosInGroups;
        groupsItem.action = @selector(autoDownloadPhotosInGroupsChanged);
        [mediaSection.items addObject:groupsItem];
        
        TGSwitchItem *privateChatsItem = [[TGSwitchItem alloc] initWithTitle:TGLocalized(@"ChatSettings.PrivateChats")];
        privateChatsItem.isOn = TGAppDelegateInstance.autoDownloadPhotosInPrivateChats;
        privateChatsItem.action = @selector(autoDownloadPhotosInPrivateChatsChanged);
        [mediaSection.items addObject:privateChatsItem];
        
        TGMenuSection *securitySection = [[TGMenuSection alloc] init];
        securitySection.title = TGLocalized(@"ChatSettings.Security");
        [sectionList addObject:securitySection];
        
        TGActionMenuItem *clearSessionsItem = [[TGActionMenuItem alloc] initWithTitle:TGLocalized(@"ChatSettings.ClearOtherSessions")];
        clearSessionsItem.action = @selector(clearSessionsPressed);
        [securitySection.items addObject:clearSessionsItem];
        
        TGCommentMenuItem *clearSessionsHelpItem = [[TGCommentMenuItem alloc] initWithComment:TGLocalized(@"ChatSettings.ClearOtherSessionsHelp")];
        [securitySection.items addObject:clearSessionsHelpItem];
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

- (void)loadView
{
    [super loadView];
    
    self.view.backgroundColor = [[TGInterfaceAssets instance] linesBackground];
    
    self.titleText = TGLocalized(@"ChatSettings.Title");
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
    
    int section = 0;
    int item = 0;
    if ([self findMenuItem:TGTextFontSizeTag sectionIndex:&section itemIndex:&item])
    {
        TGVariantMenuItem *variantItem = ((TGMenuSection *)_sectionList[section]).items[item];
        variantItem.variant = [[NSString alloc] initWithFormat:@"%dpt", TGBaseFontSize];
        
        id cell = [_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:item inSection:section]];
        if ([cell isKindOfClass:[TGVariantMenuItemCell class]])
            ((TGVariantMenuItemCell *)cell).variant = variantItem.variant;
    }
    
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

#pragma mark -

- (void)actionStageActionRequested:(NSString *)action options:(NSDictionary *)options
{
    if ([action isEqualToString:@"toggleSwitchItem"])
    {
        TGSwitchItem *switchItem = [options objectForKey:@"itemId"];
        if (switchItem == nil)
            return;
        
        NSNumber *nValue = [options objectForKey:@"value"];
        switchItem.isOn = [nValue boolValue];
        
        if (switchItem.action != NULL && [self respondsToSelector:switchItem.action])
        {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [self performSelector:switchItem.action];
#pragma clang diagnostic pop
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

- (void)textSizeItemPressed
{
    TGNavigationController *controller = [TGNavigationController navigationControllerWithControllers:@[[[TGTextFontController alloc] init]]];
    [self presentViewController:controller animated:true completion:nil];
}

- (void)autoDownloadPhotosInGroupsChanged
{
    TGAppDelegateInstance.autoDownloadPhotosInGroups = !TGAppDelegateInstance.autoDownloadPhotosInGroups;
    [TGAppDelegateInstance saveSettings];
}

- (void)autoDownloadPhotosInPrivateChatsChanged
{
    TGAppDelegateInstance.autoDownloadPhotosInPrivateChats = !TGAppDelegateInstance.autoDownloadPhotosInPrivateChats;
    [TGAppDelegateInstance saveSettings];
}

- (void)clearSessionsPressed
{
    if ([_tableView indexPathForSelectedRow] != nil)
        [_tableView deselectRowAtIndexPath:[_tableView indexPathForSelectedRow] animated:true];
    
    _currentAlertView.delegate = nil;
    
    _currentAlertView = [[UIAlertView alloc] initWithTitle:nil message:TGLocalized(@"ChatSettings.ClearOtherSessionsConfirmation") delegate:self cancelButtonTitle:TGLocalized(@"Common.Cancel") otherButtonTitles:TGLocalized(@"Common.OK"), nil];
    [_currentAlertView show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex != alertView.cancelButtonIndex)
    {
        _progressWindow = [[TGProgressWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
        [_progressWindow show:true];
        
        [ActionStageInstance() requestActor:@"/tg/service/revokesessions" options:nil watcher:self];
    }
    
    if (alertView == _currentAlertView)
    {
        _currentAlertView = nil;
        alertView.delegate = nil;
    }
}

- (void)actorCompleted:(int)status path:(NSString *)path result:(id)__unused result
{
    if ([path isEqualToString:@"/tg/service/revokesessions"])
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            if (status == ASStatusSuccess)
            {
                [_progressWindow dismissWithSuccess];
            }
            else
            {
                [_progressWindow dismiss:true];
                
                [[[UIAlertView alloc] initWithTitle:nil message:TGLocalized(@"ChatSettings.ClearOtherSessionsFailed") delegate:nil cancelButtonTitle:TGLocalized(@"Common.OK") otherButtonTitles:nil] show];
            }
            
            _progressWindow = nil;
        });
    }
}

@end
