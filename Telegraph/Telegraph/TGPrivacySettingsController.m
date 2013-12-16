#import "TGPrivacySettingsController.h"

#import "TGInterfaceAssets.h"

#import "TGRemoteImageView.h"

#import "TGActionTableView.h"

#import "SGraphObjectNode.h"

#import "TGInterfaceAssets.h"

#import "TGMenuSection.h"

#import "TGActionMenuItem.h"
#import "TGActionMenuItemCell.h"

#import "TGSwitchItem.h"
#import "TGSwitchItemCell.h"

#import "TGCommentMenuItem.h"
#import "TGCommentMenuItemView.h"

#import "TGAppDelegate.h"

#import "TGTelegraph.h"

typedef enum {
    TGShowLastVisit = 1,
    TGShowContacts,
    TGSuggestMe
} TGPrivacySettingsTags;

@interface TGPrivacySettingsController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) TGActionTableView *tableView;
@property (nonatomic) float currentTableWidth;

@property (nonatomic, strong) NSArray *sectionList;

@property (nonatomic, strong) NSArray *sectionHeaderViews;

@property (nonatomic, strong) NSMutableDictionary *privacySettings;

@end

@implementation TGPrivacySettingsController

@synthesize actionHandle = _actionHandle;

@synthesize tableView = _tableView;
@synthesize currentTableWidth = _currentTableWidth;

@synthesize sectionList = _sectionList;

@synthesize sectionHeaderViews = _sectionHeaderViews;

@synthesize privacySettings = _privacySettings;

- (id)init
{
    self = [super initWithNibName:nil bundle:nil];
    if (self)
    {
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:true];
        
        NSMutableArray *sectionList = [[NSMutableArray alloc] init];
        
        TGMenuSection *lastSeenSection = [[TGMenuSection alloc] init];
        [sectionList addObject:lastSeenSection];
        
        TGSwitchItem *lastVisitItem = [[TGSwitchItem alloc] initWithTitle:TGLocalized(@"Privacy.ShowLastSeen")];
        lastVisitItem.tag = TGShowLastVisit;
        lastVisitItem.isOn = true;
        [lastSeenSection.items addObject:lastVisitItem];
        
        TGCommentMenuItem *lastSeenCommentItem = [[TGCommentMenuItem alloc] initWithComment:TGLocalized(@"Privacy.ShowLastSeenHelp")];
        [lastSeenSection.items addObject:lastSeenCommentItem];
        
        TGMenuSection *suggestionsSection = [[TGMenuSection alloc] init];
        [sectionList addObject:suggestionsSection];
        
        TGSwitchItem *suggestionsItem = [[TGSwitchItem alloc] initWithTitle:TGLocalized(@"Privacy.RecommendMe")];
        suggestionsItem.tag = TGSuggestMe;
        suggestionsItem.isOn = true;
        [suggestionsSection.items addObject:suggestionsItem];
        
        TGCommentMenuItem *suggestionsCommentItem = [[TGCommentMenuItem alloc] initWithComment:TGLocalized(@"Privacy.RecommendMeHelp")];
        [suggestionsSection.items addObject:suggestionsCommentItem];
        
        TGMenuSection *contactsSection = [[TGMenuSection alloc] init];
        [sectionList addObject:contactsSection];
        
        TGSwitchItem *contactsItem = [[TGSwitchItem alloc] initWithTitle:TGLocalized(@"Privacy.SuggestContacts")];
        contactsItem.tag = TGShowContacts;
        contactsItem.isOn = true;
        [contactsSection.items addObject:contactsItem];
        
        TGCommentMenuItem *contactsCommentItem = [[TGCommentMenuItem alloc] initWithComment:TGLocalized(@"Privacy.SuggestContactsHelp")];
        [contactsSection.items addObject:contactsCommentItem];
        
        _sectionList = sectionList;
        
        [ActionStageInstance() dispatchOnStageQueue:^
        {
            [ActionStageInstance() requestActor:@"/tg/privacySettings/(cached)" options:nil watcher:self];
            [ActionStageInstance() watchForPath:@"/tg/privacySettings" watcher:self];
        }];
    }
    return self;
}

- (void)dealloc
{
    [self doUnloadView];
    
    [_actionHandle reset];
    [ActionStageInstance() removeWatcher:self];
}

- (void)loadView
{
    [super loadView];
    
    self.view.backgroundColor = [[TGInterfaceAssets instance] linesBackground];
    
    self.titleText = TGLocalized(@"Privacy.Title");
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

- (void)doUnloadView
{
    _tableView.delegate = nil;
    _tableView.dataSource = nil;
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
    return 14;
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

- (void)actionStageResourceDispatched:(NSString *)path resource:(id)resource arguments:(id)__unused arguments
{
    if ([path isEqualToString:@"/tg/privacySettings"])
    {
        [self actorCompleted:ASStatusSuccess path:path result:resource];
    }
}

- (void)actorCompleted:(int)resultCode path:(NSString *)path result:(id)result
{
    if ([path hasPrefix:@"/tg/privacySettings"])
    {
        if (resultCode == ASStatusSuccess)
        {
            NSDictionary *privacySettings = ((SGraphObjectNode *)result).object;
            
            dispatch_async(dispatch_get_main_queue(), ^
            {
                _privacySettings = [privacySettings mutableCopy];
                
                [self updatePrivacySettingsControls];
            });
        }
    }
}

- (void)updatePrivacySettingsControls
{
    int sectionIndex = 0;
    int itemIndex = 0;
    
    TGSwitchItem *lastVisitItem = (TGSwitchItem *)[self findMenuItem:TGShowLastVisit sectionIndex:&sectionIndex itemIndex:&itemIndex];
    if (lastVisitItem != nil)
    {
        lastVisitItem.isOn = [[_privacySettings objectForKey:@"hideLastVisit"] intValue] == 0;
        TGSwitchItemCell *switchItemCell = (TGSwitchItemCell *)[_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:itemIndex inSection:sectionIndex]];
        if ([switchItemCell isKindOfClass:[TGSwitchItemCell class]])
            [switchItemCell setIsOn:lastVisitItem.isOn animated:false];
    }
    
    TGSwitchItem *contactsItem = (TGSwitchItem *)[self findMenuItem:TGShowContacts sectionIndex:&sectionIndex itemIndex:&itemIndex];
    if (contactsItem != nil)
    {
        contactsItem.isOn = [[_privacySettings objectForKey:@"hideContacts"] intValue] == 0;
        TGSwitchItemCell *switchItemCell = (TGSwitchItemCell *)[_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:itemIndex inSection:sectionIndex]];
        if ([switchItemCell isKindOfClass:[TGSwitchItemCell class]])
            [switchItemCell setIsOn:contactsItem.isOn animated:false];
    }
    
    TGSwitchItem *suggestionsItem = (TGSwitchItem *)[self findMenuItem:TGSuggestMe sectionIndex:&sectionIndex itemIndex:&itemIndex];
    if (suggestionsItem != nil)
    {
        suggestionsItem.isOn = [[_privacySettings objectForKey:@"disableSuggestions"] intValue] == 0;
        TGSwitchItemCell *switchItemCell = (TGSwitchItemCell *)[_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:itemIndex inSection:sectionIndex]];
        if ([switchItemCell isKindOfClass:[TGSwitchItemCell class]])
            [switchItemCell setIsOn:suggestionsItem.isOn animated:false];
    }
}

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
        
        if (switchItem.tag == TGShowLastVisit)
        {
            [_privacySettings setObject:[NSNumber numberWithBool:!switchItem.isOn] forKey:@"hideLastVisit"];
            [self updatePrivacySettingsControls];
            
            [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/changePrivacySettings/(pc%d)", actionId++] options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:!switchItem.isOn], @"hideLastVisit", nil] watcher:TGTelegraphInstance];
        }
        else if (switchItem.tag == TGShowContacts)
        {
            [_privacySettings setObject:[NSNumber numberWithBool:!switchItem.isOn] forKey:@"hideContacts"];
            [self updatePrivacySettingsControls];
            
            [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/changePrivacySettings/(pc%d)", actionId++] options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:!switchItem.isOn], @"hideContacts", nil] watcher:TGTelegraphInstance];
        }
        else if (switchItem.tag == TGSuggestMe)
        {
            [_privacySettings setObject:[NSNumber numberWithBool:!switchItem.isOn] forKey:@"disableSuggestions"];
            [self updatePrivacySettingsControls];
            
            [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/changePrivacySettings/(pc%d)", actionId++] options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:!switchItem.isOn], @"disableSuggestions", nil] watcher:TGTelegraphInstance];
        }
    }
}

@end
