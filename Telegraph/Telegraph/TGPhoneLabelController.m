#import "TGPhoneLabelController.h"

#import "TGAppDelegate.h"

#import "TGInterfaceAssets.h"

#import "TGActionMenuItemCell.h"

#import "TGSynchronizeContactsActor.h"

#import "TGToolbarButton.h"

@interface TGPhoneLabelController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UITableView *tableView;

@property (nonatomic, strong) NSMutableArray *listModel;
@property (nonatomic, strong) NSMutableArray *additionalListModel;

@property (nonatomic, strong) NSIndexPath *selectedIndexPath;

@end

@implementation TGPhoneLabelController

@synthesize watcherHandle = _watcherHandle;

@synthesize tableView = _tableView;

@synthesize listModel = _listModel;
@synthesize additionalListModel = _additionalListModel;

@synthesize selectedIndexPath = _selectedIndexPath;

- (id)initWithSelectedLabel:(NSString *)label
{
    self = [super initWithNibName:nil bundle:nil];
    if (self)
    {
        _listModel = [[NSMutableArray alloc] init];
        
        NSArray *labels = [TGSynchronizeContactsManager phoneLabels];
        [_listModel addObjectsFromArray:labels];
        
        bool found = false;
        int index = -1;
        for (NSString *listLabel in labels)
        {
            index++;
            if ([listLabel isEqualToString:label])
            {
                _selectedIndexPath = [NSIndexPath indexPathForRow:index inSection:0];
                found = true;
            }
        }
        
        if (!found)
        {
            _additionalListModel = [[NSMutableArray alloc] initWithObjects:label, nil];
            _selectedIndexPath = [NSIndexPath indexPathForRow:0 inSection:1];
        }
    }
    return self;
}

- (void)loadView
{
    [super loadView];
    
    self.titleText = TGLocalized(@"Profile.SelectLabelTitle");
    
    TGToolbarButton *cancelButton = [[TGToolbarButton alloc] initWithType:TGToolbarButtonTypeGeneric];
    cancelButton.text = NSLocalizedString(@"Common.Cancel", @"");
    cancelButton.minWidth = 59;
    [cancelButton sizeToFit];
    [cancelButton addTarget:self action:@selector(cancelButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:cancelButton];
    
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

- (void)viewWillAppear:(BOOL)animated
{
    if (_selectedIndexPath != nil && _selectedIndexPath.section >= 0 && _selectedIndexPath.section < [self numberOfSectionsInTableView:_tableView] && _selectedIndexPath.row >= 0 && _selectedIndexPath.row < [self tableView:_tableView numberOfRowsInSection:_selectedIndexPath.section])
    {
        [_tableView scrollToRowAtIndexPath:_selectedIndexPath atScrollPosition:UITableViewScrollPositionNone animated:false];
    }
    
    [super viewWillAppear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return toInterfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
}

- (BOOL)shouldAutorotate
{
    return true;
}

#pragma mark -

- (NSInteger)numberOfSectionsInTableView:(UITableView *)__unused tableView
{
    return _additionalListModel.count != 0 ? 2 : 1;
}

- (NSInteger)tableView:(UITableView *)__unused tableView numberOfRowsInSection:(NSInteger)section
{
    return section == 0 ? _listModel.count : _additionalListModel.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSArray *sectionModel = indexPath.section == 0 ? _listModel : _additionalListModel;
    NSString *itemText = [sectionModel objectAtIndex:indexPath.row];
    
    bool firstInSection = indexPath.row == 0;
    bool lastInSection = indexPath.row == (int)sectionModel.count - 1;
    
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
    [actionItemCell setHideCheckIndicator:[indexPath compare:_selectedIndexPath] != NSOrderedSame];
    
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
    if ([_selectedIndexPath compare:indexPath] != NSOrderedSame)
    {
        TGActionMenuItemCell *cell = (TGActionMenuItemCell *)[tableView cellForRowAtIndexPath:_selectedIndexPath];
        if (cell != nil)
            [cell setHideCheckIndicator:true];
        
        _selectedIndexPath = indexPath;
        
        cell = (TGActionMenuItemCell *)[tableView cellForRowAtIndexPath:indexPath];
        if (cell != nil)
            [cell setHideCheckIndicator:false];
        
        id<ASWatcher> watcher = _watcherHandle.delegate;
        if (watcher != nil && [watcher respondsToSelector:@selector(actionStageActionRequested:options:)])
            [watcher actionStageActionRequested:@"phoneLabelSelected" options:[[NSDictionary alloc] initWithObjectsAndKeys:cell.title, @"label", nil]];
    }
    else
    {
        id<ASWatcher> watcher = _watcherHandle.delegate;
        if (watcher != nil && [watcher respondsToSelector:@selector(actionStageActionRequested:options:)])
            [watcher actionStageActionRequested:@"phoneLabelSelected" options:nil];
    }
}

#pragma mark -

- (void)cancelButtonPressed
{
    id<ASWatcher> watcher = _watcherHandle.delegate;
    if (watcher != nil && [watcher respondsToSelector:@selector(actionStageActionRequested:options:)])
    {
        [watcher actionStageActionRequested:@"phoneLabelSelected" options:nil];
    }
}

@end
