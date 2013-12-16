#import "TGTextFontController.h"

#import "TGToolbarButton.h"
#import "TGInterfaceAssets.h"

#import "TGActionMenuItemCell.h"

#import "TGAppDelegate.h"
#import "TGTelegraphConversationMessageAssetsSource.h"

@interface TGTextFontController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UITableView *tableView;

@property (nonatomic, strong) NSArray *fontSizes;
@property (nonatomic, strong) NSMutableArray *listModel;

@property (nonatomic) int selectedIndex;

@end

@implementation TGTextFontController

- (id)init
{
    self = [super initWithNibName:nil bundle:nil];
    if (self)
    {
        _listModel = [[NSMutableArray alloc] init];
        
        _fontSizes = @[@(16), @(18), @(20), @(24), @(32), @(40)];
        
        int index = -1;
        for (NSNumber *nSize in _fontSizes)
        {
            index++;
            
            if ([nSize intValue] == TGBaseFontSize)
                _selectedIndex = index;
            
            [_listModel addObject:[[NSString alloc] initWithFormat:@"%dpt", [nSize intValue]]];
        }
    }
    return self;
}

- (void)dealloc
{
}

- (void)loadView
{
    [super loadView];
    
    self.titleText = TGLocalized(@"ChatSettings.TextSize");
    
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
}

#pragma mark -

- (void)cancelButtonPressed
{
    [self.presentingViewController dismissViewControllerAnimated:true completion:nil];
}

- (void)doneButtonPressed
{
    TGBaseFontSize = [_fontSizes[_selectedIndex] intValue];
    [TGAppDelegateInstance saveSettings];
    
    [self.presentingViewController dismissViewControllerAnimated:true completion:nil];
}

@end
