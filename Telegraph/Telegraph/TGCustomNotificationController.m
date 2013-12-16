#import "TGCustomNotificationController.h"

#import "TGAppDelegate.h"

#import "TGInterfaceAssets.h"

#import "TGActionMenuItemCell.h"

#import "TGToolbarButton.h"

#import "SGraphObjectNode.h"

@interface TGCustomNotificationController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UITableView *tableView;

@property (nonatomic, strong) NSMutableArray *listModel;

@property (nonatomic) bool skipDefaultItem;
@property (nonatomic) int defaultSoundId;

@end

@implementation TGCustomNotificationController

@synthesize actionHandle = _actionHandle;
@synthesize watcherHandle = _watcherHandle;

@synthesize tag = _tag;

@synthesize tableView = _tableView;

@synthesize listModel = _listModel;

@synthesize skipDefaultItem = _skipDefaultItem;
@synthesize defaultSoundId = _defaultSoundId;

@synthesize selectedIndex = _selectedIndex;

- (id)initWithMode:(TGCustomNotificationControllerMode)mode
{
    self = [super initWithNibName:nil bundle:nil];
    if (self)
    {
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:true];
        
        _listModel = [[NSMutableArray alloc] init];
        [_listModel addObjectsFromArray:[TGAppDelegateInstance alertSoundTitles]];
        
        _defaultSoundId = 2;
        
        if (mode == TGCustomNotificationControllerModeUser)
        {
            [ActionStageInstance() dispatchOnStageQueue:^
            {
                [ActionStageInstance() watchForPath:[NSString stringWithFormat:@"/tg/peerSettings/(%d)", INT_MAX - 1] watcher:self];
                [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/peerSettings/(%d,cached)", INT_MAX - 1] options:[NSDictionary dictionaryWithObject:[NSNumber numberWithLongLong:INT_MAX - 1] forKey:@"peerId"] watcher:self];
            }];
        }
        else if (mode == TGCustomNotificationControllerModeGroup)
        {
            [ActionStageInstance() watchForPath:[NSString stringWithFormat:@"/tg/peerSettings/(%d)", INT_MAX - 2] watcher:self];
            [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/peerSettings/(%d,cached)", INT_MAX - 2] options:[NSDictionary dictionaryWithObject:[NSNumber numberWithLongLong:INT_MAX - 2] forKey:@"peerId"] watcher:self];
        }
    }
    return self;
}

- (void)dealloc
{
    [_actionHandle reset];
    [ActionStageInstance() removeWatcher:self];
    _actionHandle = nil;
}

- (void)skipDefault
{
    _skipDefaultItem = true;
    [_listModel removeObjectAtIndex:1];
    if (_selectedIndex >= 1)
        _selectedIndex--;
}

- (void)loadView
{
    [super loadView];
    
    self.titleText = TGLocalized(@"Nofications.CustomSound.Title");
    
    TGToolbarButton *cancelButton = [[TGToolbarButton alloc] initWithType:TGToolbarButtonTypeGeneric];
    cancelButton.text = NSLocalizedString(@"Common.Cancel", @"");
    cancelButton.minWidth = 59;
    [cancelButton sizeToFit];
    [cancelButton addTarget:self action:@selector(cancelButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:cancelButton];
    
    TGToolbarButton *doneButton = [[TGToolbarButton alloc] initWithType:TGToolbarButtonTypeDone];
    doneButton.text = NSLocalizedString(@"Common.Done", @"");
    doneButton.minWidth = 51;
    [doneButton sizeToFit];
    [doneButton addTarget:self action:@selector(doneButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:doneButton];
    
    self.view.backgroundColor = [[TGInterfaceAssets instance] linesBackground];
    
    _tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.rowHeight = 44;
    _tableView.backgroundView = nil;
    _tableView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_tableView];
    
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

#pragma mark -

- (NSInteger)tableView:(UITableView *)__unused tableView numberOfRowsInSection:(NSInteger)__unused section
{
    return _listModel.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *itemText = [_listModel objectAtIndex:indexPath.row];
    
    bool firstInSection = indexPath.row == 0;
    bool lastInSection = indexPath.row == (int)_listModel.count - 1;
    
    UITableViewCell *cell = nil;
    
    static NSString *actionItemCellIdentifier = @"AI";
    TGActionMenuItemCell *actionItemCell = (TGActionMenuItemCell *)[tableView dequeueReusableCellWithIdentifier:actionItemCellIdentifier];
    if (actionItemCell == nil)
    {
        actionItemCell = [[TGActionMenuItemCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:actionItemCellIdentifier];
        
        UIImageView *backgroundView = [[UIImageView alloc] init];
        actionItemCell.backgroundView = backgroundView;
        UIImageView *selectedBackgroundView = [[UIImageView alloc] init];
        actionItemCell.selectedBackgroundView = selectedBackgroundView;
        
        [actionItemCell setHideCheckIndicator:false];
    }
    
    actionItemCell.title = itemText;
    [actionItemCell setHideDisclosureIndicator:true];
    [actionItemCell setHideCheckIndicator:indexPath.row != _selectedIndex];
    
    cell = actionItemCell;
    
    if (cell != nil)
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
        
        return cell;
    }
    
    return nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:true];
    
    if (_selectedIndex != indexPath.row)
    {
        TGActionMenuItemCell *cell = (TGActionMenuItemCell *)[tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:_selectedIndex inSection:0]];
        if (cell != nil)
            [cell setHideCheckIndicator:true];
        
        _selectedIndex = indexPath.row;
        
        cell = (TGActionMenuItemCell *)[tableView cellForRowAtIndexPath:indexPath];
        if (cell != nil)
            [cell setHideCheckIndicator:false];
    }
    
    int playSoundIndex = _selectedIndex;
    if (_skipDefaultItem && playSoundIndex > 0)
        playSoundIndex++;
    else if (!_skipDefaultItem && playSoundIndex == 1)
        playSoundIndex = _defaultSoundId;
    
    if (playSoundIndex >= 1 && playSoundIndex <= 2)
        playSoundIndex = 2;
    
    if (playSoundIndex == 0)
        playSoundIndex = INT_MAX;
    else if (playSoundIndex == 1)
        playSoundIndex = 0;
    else if (playSoundIndex == 2)
        playSoundIndex = 0;
    
    if (playSoundIndex != INT_MAX)
        [TGAppDelegateInstance playNotificationSound:[[NSString alloc] initWithFormat:@"%d", playSoundIndex]];
}

#pragma mark -

- (void)cancelButtonPressed
{
    id<ASWatcher> watcher = _watcherHandle.delegate;
    if (watcher != nil && [watcher respondsToSelector:@selector(actionStageActionRequested:options:)])
    {
        [watcher actionStageActionRequested:@"customSoundSelected" options:[NSDictionary dictionaryWithObjectsAndKeys:[[NSNumber alloc] initWithInt:_tag], @"tag", nil]];
    }
}

- (void)doneButtonPressed
{
    id<ASWatcher> watcher = _watcherHandle.delegate;
    if (watcher != nil && [watcher respondsToSelector:@selector(actionStageActionRequested:options:)])
    {
        int selectedIndex = _selectedIndex;
        if (_skipDefaultItem)
            if (selectedIndex >= 1)
                selectedIndex++;
        [watcher actionStageActionRequested:@"customSoundSelected" options:[NSDictionary dictionaryWithObjectsAndKeys:[[NSNumber alloc] initWithInt:_tag], @"tag", [[NSNumber alloc] initWithInt:selectedIndex], @"index", nil]];
    }
}

#pragma mark -

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
                _defaultSoundId = [[notificationSettings objectForKey:@"soundId"] intValue];
            });
        }
    }
}

@end
