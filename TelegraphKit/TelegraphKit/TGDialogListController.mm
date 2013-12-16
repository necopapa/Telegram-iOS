#import "TGDialogListController.h"

#import "TGDialogListCompanion.h"

#import "TGTabControllerChild.h"

#import "TGSearchDisplayMixin.h"

#import "TGConversation.h"
#import "TGUser.h"
#import "TGMessage.h"

#import "SGraphObjectNode.h"

#import "TGHighlightImageView.h"
#import "TGRemoteImageView.h"

#import "TGDialogListCell.h"
#import "TGDialogListSearchCell.h"

#import "TGToolbarButton.h"

#import "TGActionTableView.h"

#import "TGHacks.h"
#import "TGSearchBar.h"
#import "TGImageUtils.h"
#import "TGLabel.h"

#import "TGObserverProxy.h"

#import "TGConversationController.h"

#import <QuartzCore/QuartzCore.h>

#import <objc/runtime.h>

#import "TGActivityIndicatorView.h"

#include <map>
#include <set>

static bool _debugDoNotJump = false;

@protocol TGDialogListTableViewDelegate <NSObject>

- (void)dismissEditingControls;

@end

@interface TGDialogListTableView : TGActionTableView

@property (nonatomic, strong) TGDialogListCell *focusCell;
@property (nonatomic) bool ignoreTouches;

@end

@implementation TGDialogListTableView

@synthesize focusCell = _focusCell;
@synthesize ignoreTouches = _ignoreTouches;

- (void)setContentInset:(UIEdgeInsets)contentInset
{
    [super setContentInset:contentInset];
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
}

- (void)setFocusCell:(TGDialogListCell *)focusCell
{
    if (focusCell != nil)
        self.scrollEnabled = false;
    else
        self.scrollEnabled = true;
    
    if (_focusCell == focusCell)
        return;
    
    if (_focusCell != nil)
    {
        [_focusCell dismissEditingControls:true];
        _focusCell = nil;
    }
    
    _focusCell = focusCell;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    if (_focusCell != nil)
    {
        UIView *buttonHitTest = [_focusCell hitTest:CGPointMake(point.x - _focusCell.frame.origin.x, point.y - _focusCell.frame.origin.y) withEvent:event];
        if ([buttonHitTest isKindOfClass:[UIButton class]])
        {
            return buttonHitTest;
        }
        else
        {
            [_focusCell dismissEditingControls:true];
            self.focusCell = nil;
            _ignoreTouches = true;
            
            id delegate = self.delegate;
            if ([delegate conformsToProtocol:@protocol(TGDialogListTableViewDelegate)])
            {
                [(id<TGDialogListTableViewDelegate>)delegate dismissEditingControls];
            }
        }
        
        return self;
    }
    else if (_ignoreTouches && event.type == UIEventTypeTouches)
    {
        return self;
    }
    
    return [super hitTest:point withEvent:event];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (!_ignoreTouches)
        [super touchesBegan:touches withEvent:event];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (!_ignoreTouches)
        [super touchesMoved:touches withEvent:event];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (_ignoreTouches)
        _ignoreTouches = false;
    else
        [super touchesCancelled:touches withEvent:event];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{   
    if (_ignoreTouches)
        _ignoreTouches = false;
    else
        [super touchesEnded:touches withEvent:event];
}

@end

#pragma mark -

static UIImage *backgroundNormal = nil;
static UIImage *backgroundNormalHighlighted = nil;

@interface TGDialogListController () <TGTabControllerChild, TGViewControllerNavigationBarAppearance, UITableViewDelegate, UITableViewDataSource, UIActionSheetDelegate, TGDialogListTableViewDelegate, TGSearchDisplayMixinDelegate>
{
    std::map<int64_t, NSString *> _usersTypingInConversation;
}

@property (nonatomic, strong) UIBarButtonItem *editBarButtonItem;
@property (nonatomic, strong) UIBarButtonItem *doneBarButtonItem;
@property (nonatomic, strong) TGToolbarButton *editButton;
@property (nonatomic, strong) TGToolbarButton *doneButton;
@property (nonatomic, strong) TGToolbarButton *composeButton;

@property (nonatomic, retain) UIBarButtonItem *controllerRightBarButtonItem;

@property (nonatomic, strong) TGSearchBar *searchBar;
@property (nonatomic, strong) TGSearchDisplayMixin *searchMixin;
@property (nonatomic) bool searchControllerWasLoaded;

@property (nonatomic, strong) TGDialogListTableView *tableView;
@property (nonatomic) int tableViewLastScrollPosition;
@property (nonatomic) bool editingMode;

@property (nonatomic, strong) NSMutableArray *listModel;

@property (nonatomic, strong) NSMutableArray *searchResults;

@property (nonatomic, strong) NSMutableArray *preparedCellQueue;

@property (nonatomic) bool isLoading;

@property (nonatomic, strong) UIView *titleStatusContainer;
@property (nonatomic, strong) TGLabel *titleStatusLabel;
@property (nonatomic, strong) TGActivityIndicatorView *titleStatusIndicator;
@property (nonatomic) bool showTitleStatus;

@property (nonatomic) int64_t conversationIdToDelete;

@property (nonatomic, strong) UIActionSheet *currentActionSheet;

@property (nonatomic, strong) UIView *emptyListContainer;

@property (nonatomic, strong) TGObserverProxy *significantTimeChangeProxy;
@property (nonatomic, strong) TGObserverProxy *didEnterBackgroundProxy;
@property (nonatomic, strong) TGObserverProxy *willEnterForegroundProxy;

@end

@implementation TGDialogListController

+ (void)setDebugDoNotJump:(bool)debugDoNotJump
{
    _debugDoNotJump = debugDoNotJump;
}

+ (bool)debugDoNotJump
{
    return _debugDoNotJump;
}

- (id)initWithCompanion:(TGDialogListCompanion *)companion
{
    self = [super initWithNibName:nil bundle:nil];
    if (self)
    {
        self.automaticallyManageScrollViewInsets = true;
        self.ignoreKeyboardWhenAdjustingScrollViewInsets = true;
        
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:true];
        
        _listModel = [[NSMutableArray alloc] init];
        
        _searchResults = [[NSMutableArray alloc] init];
        
        _dialogListCompanion = companion;
        _dialogListCompanion.dialogListController = self;
        
        _significantTimeChangeProxy = [[TGObserverProxy alloc] initWithTarget:self targetSelector:@selector(significantTimeChange:) name:UIApplicationSignificantTimeChangeNotification];
        _didEnterBackgroundProxy = [[TGObserverProxy alloc] initWithTarget:self targetSelector:@selector(didEnterBackground:) name:UIApplicationDidEnterBackgroundNotification];
        _willEnterForegroundProxy = [[TGObserverProxy alloc] initWithTarget:self targetSelector:@selector(willEnterForeground:) name:UIApplicationWillEnterForegroundNotification];
    }
    return self;
}

- (void)dealloc
{
    [_actionHandle reset];
    [ActionStageInstance() removeWatcher:self];
    
    _dialogListCompanion.dialogListController = nil;
    
    [self doUnloadView];
    
    _currentActionSheet.delegate = nil;
}

- (NSString *)controllerTitle
{
    return TGLocalized(@"DialogList.Title");
}

- (UIView *)titleStatusContainer
{
    if (_titleStatusContainer == nil)
    {
        _titleStatusContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 40, 30)];
        _titleStatusContainer.clipsToBounds = false;
        
        _titleStatusLabel = [[TGLabel alloc] initWithFrame:CGRectZero];
        _titleStatusLabel.clipsToBounds = false;
        _titleStatusLabel.backgroundColor = [UIColor clearColor];
        _titleStatusLabel.textColor = [UIColor whiteColor];
        _titleStatusLabel.shadowColor = UIColorRGB(0x415a7e);
        _titleStatusLabel.shadowOffset = CGSizeMake(0, -1);
        _titleStatusLabel.font = [UIFont boldSystemFontOfSize:15];
        _titleStatusLabel.verticalAlignment = TGLabelVericalAlignmentTop;
        [_titleStatusContainer addSubview:_titleStatusLabel];
        
        _titleStatusIndicator = [[TGActivityIndicatorView alloc] initWithStyle:TGActivityIndicatorViewStyleSmallWhite];
        [_titleStatusContainer addSubview:_titleStatusIndicator];
    }
    
    return _titleStatusContainer;
}

- (UIView *)controllerTitleView:(float)__unused titleWidth
{
    if (_showTitleStatus)
    {
        return [self titleStatusContainer];
    }

    return nil;
}

- (UIBarButtonItem *)controllerLeftBarButtonItem
{
    if (![_dialogListCompanion showListEditingControl])
        return nil;
    
    if (!_editingMode)
    {
        if (_editButton == nil)
        {
            _editButton = [[TGToolbarButton alloc] initWithType:TGToolbarButtonTypeGeneric];
            _editButton.text = NSLocalizedString(@"Common.Edit", @"");
            _editButton.minWidth = 51;
            _editButton.paddingLeft = 10;
            _editButton.paddingRight = 10;
            [_editButton sizeToFit];
            [_editButton addTarget:self action:@selector(editButtonPressed) forControlEvents:UIControlEventTouchUpInside];
            _editBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:_editButton];
        }
        
        return _editBarButtonItem;
    }
    else
    {
        if (_doneBarButtonItem == nil)
        {
            _doneButton = [[TGToolbarButton alloc] initWithType:TGToolbarButtonTypeDone];
            _doneButton.text = NSLocalizedString(@"Common.Done", @"");
            _doneButton.minWidth = 51;
            _doneButton.paddingLeft = 10;
            _doneButton.paddingRight = 10;
            [_doneButton sizeToFit];
            [_doneButton addTarget:self action:@selector(doneButtonPressed) forControlEvents:UIControlEventTouchUpInside];
            _doneBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:_doneButton];
        }
        
        return _doneBarButtonItem;
    }
    
    return nil;
}

- (void)scrollToTopRequested
{
    [_tableView setContentOffset:CGPointMake(0, -_tableView.contentInset.top) animated:true];
}

- (void)titleStateUpdated:(NSString *)text isLoading:(bool)isLoading;
{
    [self titleStatusContainer];
    
    _showTitleStatus = isLoading;
    _titleStatusLabel.text = text;
    [_titleStatusLabel sizeToFit];
    _titleStatusLabel.frame = CGRectIntegral(CGRectMake((_titleStatusLabel.superview.frame.size.width - _titleStatusLabel.frame.size.width + _titleStatusIndicator.frame.size.width + 5) / 2, (_titleStatusLabel.superview.frame.size.height - _titleStatusLabel.frame.size.height) / 2 - 1, _titleStatusLabel.frame.size.width, _titleStatusLabel.frame.size.height));
    _titleStatusIndicator.frame = CGRectMake(_titleStatusLabel.frame.origin.x - _titleStatusIndicator.frame.size.width - 5, _titleStatusLabel.frame.origin.y + 3, _titleStatusIndicator.frame.size.width, _titleStatusIndicator.frame.size.height);
    
    if (_titleStatusIndicator.isAnimating != isLoading)
    {
        if (isLoading)
            [_titleStatusIndicator startAnimating];
        else
            [_titleStatusIndicator stopAnimating];
    }
    
    [_dialogListCompanion updateTitle:true];
}

- (void)userTypingInConversationUpdated:(int64_t)conversationId typingString:(NSString *)typingString
{
    bool updated = false;
    
    if (typingString.length != 0)
    {
        std::map<int64_t, NSString *>::iterator conversationIt = _usersTypingInConversation.find(conversationId);
        
        if (conversationIt == _usersTypingInConversation.end())
        {
            updated = true;
            _usersTypingInConversation.insert(std::pair<int64_t, NSString *>(conversationId, typingString));
        }
        else
        {
            if (![conversationIt->second isEqualToString:typingString])
            {
                updated = true;
                _usersTypingInConversation[conversationId] = typingString;
            }
        }
    }
    else if (typingString.length == 0 && _usersTypingInConversation.find(conversationId) != _usersTypingInConversation.end())
    {
        updated = true;
        _usersTypingInConversation.erase(conversationId);
    }
    
    if (updated)
    {
        Class dialogListCellClass = [TGDialogListCell class];
        for (UITableViewCell *cell in [_tableView visibleCells])
        {
            if ([cell isKindOfClass:dialogListCellClass])
            {
                TGDialogListCell *dialogCell = (TGDialogListCell *)cell;
                if (dialogCell.conversationId == conversationId)
                {
                    [dialogCell setTypingString:typingString animated:true];
                    
                    break;
                }
            }
        }
    }
}

- (UIBarButtonItem *)controllerRightBarButtonItem
{
    if (_controllerRightBarButtonItem == nil)
    {
        _composeButton = [[TGToolbarButton alloc] initWithType:TGToolbarButtonTypeGeneric];
        _composeButton.image = [UIImage imageNamed:@"ComposeMessageIcon.png"];
        _composeButton.imageLandscape = [UIImage imageNamed:@"ComposeMessageIcon_Landscape.png"];
        _composeButton.paddingLeft = 6;
        _composeButton.paddingRight = 6;
        [_composeButton sizeToFit];
        [_composeButton addTarget:self action:@selector(composeMessageButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
        UIBarButtonItem *newMessageItem = [[UIBarButtonItem alloc] initWithCustomView:_composeButton];
        
        _controllerRightBarButtonItem = newMessageItem;
    }
    
    _composeButton.alpha = _editingMode ? 0.0f : 1.0f;
    
    return _controllerRightBarButtonItem;
}

- (UIBarStyle)requiredNavigationBarStyle
{
    return UIBarStyleDefault;
}

- (void)clearInputFieldBackground:(UIView *)view andSetIcon:(UIImage *)icon
{
    if ([view isKindOfClass:[UITextField class]])
    {
        UITextField *textField = (UITextField *)view;
        [textField setBackground:nil];
        textField.clipsToBounds = false;
        
        [TGHacks setTextFieldPlaceholderColor:textField color:UIColorRGB(0x8d9298)];
        if (TGIsRetina())
            [TGHacks setTextFieldClearOffset:textField offset:0.5f];
        
        SEL clearButtonSelector = NSSelectorFromString([[NSString alloc] initWithFormat:@"%sBu%s", "clear", "tton"]);
        if ([textField respondsToSelector:clearButtonSelector])
        {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            UIButton *clearButton = [textField performSelector:clearButtonSelector];
#pragma clang diagnostic pop
            [clearButton setImage:[UIImage imageNamed:@"ClearInput.png"] forState:UIControlStateNormal];
            [clearButton setImage:[UIImage imageNamed:@"ClearInput_Pressed.png"] forState:UIControlStateHighlighted];
        }
        
        UIImage *inputImage = [UIImage imageNamed:@"SearchInputField.png"];
        inputImage = [inputImage stretchableImageWithLeftCapWidth:(int)(inputImage.size.width / 2) topCapHeight:0];
        UIImageView *inputImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, TGIsRetina() ? 0.5 : 0, textField.frame.size.width, inputImage.size.height)];
        inputImageView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        inputImageView.image = inputImage;
        [textField addSubview:inputImageView];

        UIImageView *iconView = (UIImageView *)[textField leftView];
        if ([iconView isKindOfClass:[UIImageView class]] && icon != nil)
        {
            iconView.image = icon;
            [iconView sizeToFit];
        }
    }
    for (UIView *child in view.subviews)
        [self clearInputFieldBackground:child andSetIcon:icon];
}

- (void)loadView
{
    [super loadView];
    
    if (![self.parentViewController isKindOfClass:[UITabBarController class]])
    {
        self.titleText = [self controllerTitle];
    }
    
    self.view.layer.backgroundColor = [UIColor whiteColor].CGColor;
    
    CGRect tableFrame = self.view.bounds;
    _tableView = [[TGDialogListTableView alloc] initWithFrame:tableFrame style:UITableViewStylePlain];
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.opaque = true;
    _tableView.backgroundColor = [UIColor whiteColor];
    
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, -480, _tableView.frame.size.width, 480)];
    headerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;        
    headerView.backgroundColor = [_dialogListCompanion.dialogListCellAssetsSource dialogListHeaderColor];
    [_tableView addSubview:headerView];
    
    _tableView.showsVerticalScrollIndicator = true;
    
    _searchBar = [[TGSearchBar alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 44)];
    _searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    if ([_searchBar respondsToSelector:@selector(setBackgroundImage:)])
        [_searchBar setBackgroundImage:[UIImage imageNamed:@"SearchBarBackground.png"]];
    
    [_searchBar setScopeBarBackgroundImage:[UIImage imageNamed:@"SearchBarScopeBarBackground.png"]];
    [_searchBar setScopeBarButtonBackgroundImage:[UIImage imageNamed:@"SearchBarScopeButton.png"] forState:UIControlStateNormal];
    [_searchBar setScopeBarButtonBackgroundImage:[UIImage imageNamed:@"SearchBarScopeButton_Highlighted.png"] forState:UIControlStateSelected];
    
    [_searchBar setScopeBarButtonDividerImage:[UIImage imageNamed:@"SearchScopeBarScopeDividerLeft.png"] forLeftSegmentState:UIControlStateSelected rightSegmentState:UIControlStateNormal];
    [_searchBar setScopeBarButtonDividerImage:[UIImage imageNamed:@"SearchScopeBarScopeDividerRight.png"] forLeftSegmentState:UIControlStateNormal rightSegmentState:UIControlStateSelected];
    
    [_searchBar setScopeBarButtonTitleTextAttributes:[[NSDictionary alloc] initWithObjectsAndKeys:
        [UIFont boldSystemFontOfSize:12], UITextAttributeFont,
        [UIColor whiteColor], UITextAttributeTextColor,
        UIColorRGBA(0x112e5c, 0.2f), UITextAttributeTextShadowColor,
    nil] forState:UIControlStateSelected];
    
    [_searchBar setScopeBarButtonTitleTextAttributes:[[NSDictionary alloc] initWithObjectsAndKeys:
        [UIFont boldSystemFontOfSize:12], UITextAttributeFont,
        UIColorRGB(0x5c708b), UITextAttributeTextColor,
        UIColorRGBA(0xffffff, 0.25f), UITextAttributeTextShadowColor,
    nil] forState:UIControlStateNormal];
    
    _searchMixin = [[TGSearchDisplayMixin alloc] init];
    _searchMixin.searchBar = _searchBar;
    _searchMixin.delegate = self;
    
    if (!_dialogListCompanion.forwardMode)
        _searchBar.scopeButtonTitles = @[@"Conversations", @"Messages"];
    
    _tableView.tableHeaderView = _searchBar;
    
    UIImage *searchIcon = [_dialogListCompanion.dialogListCellAssetsSource dialogListSearchIcon];
    if (searchIcon != nil)
        [self clearInputFieldBackground:_searchBar andSetIcon:searchIcon];
    
    _searchBar.placeholder = NSLocalizedString(@"DialogList.SearchLabel", @"");
    
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.alwaysBounceVertical = true;
    _tableView.bounces = true;
    
    _tableView.hidden = _listModel.count == 0;
    
    [self.view addSubview:_tableView];
    
    if (![self _updateControllerInset:false])
        [self controllerInsetUpdated:UIEdgeInsetsZero];
}

- (void)doUnloadView
{
    _tableView.delegate = nil;
    _tableView.dataSource = nil;
    _tableView = nil;
    
    _editBarButtonItem = nil;
    _editButton = nil;
    _doneBarButtonItem = nil;
    _doneButton = nil;
    _composeButton = nil;
    
    _controllerRightBarButtonItem = nil;
    
    _searchBar = nil;
    
    _searchMixin.delegate = nil;
    [_searchMixin unload];
}

- (void)viewDidUnload
{
    [self doUnloadView];
    
    [super viewDidUnload];
}

- (void)viewWillAppear:(BOOL)animated
{
    int64_t conversationId = [TGConversationController lastConversationIdForBackAction];
    if (conversationId != 0 && !_debugDoNotJump)
    {
        [TGConversationController resetLastConversationIdForBackAction];
        
        if (animated && !_searchMixin.isActive)
        {
            bool found = false;
            
            int index = -1;
            for (TGConversation *conversation in _listModel)
            {
                index++;
                
                if (conversation.conversationId == conversationId)
                {
                    UITableViewScrollPosition scrollPosition = UITableViewScrollPositionNone;
                    
                    CGRect convertRect = [_tableView convertRect:[_tableView rectForRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]] toView:self.view];
                    if (convertRect.origin.y + convertRect.size.height > self.view.frame.size.height - self.controllerInset.bottom)
                        scrollPosition = UITableViewScrollPositionBottom;
                    else if (convertRect.origin.y < self.controllerInset.top)
                        scrollPosition = UITableViewScrollPositionTop;
                    
                    [_tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0] animated:false scrollPosition:scrollPosition];
                    
                    found = true;
                    
                    break;
                }
            }
        }
        else
        {
            if ([_tableView indexPathForSelectedRow] != nil)
                [_tableView deselectRowAtIndexPath:[_tableView indexPathForSelectedRow] animated:false];
        }
    }
    
    if ([_tableView indexPathForSelectedRow] != nil)
    {
        if (cpuCoreCount() > 2)
        {
            [_tableView deselectRowAtIndexPath:[_tableView indexPathForSelectedRow] animated:true];
        }
        else if (cpuCoreCount() > 1)
        {
            double delayInSeconds = 0.05;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)delayInSeconds * NSEC_PER_SEC);
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                [_tableView deselectRowAtIndexPath:[_tableView indexPathForSelectedRow] animated:true];
            });
        }
        else
        {
            double delayInSeconds = 0.1;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)delayInSeconds * NSEC_PER_SEC);
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                [_tableView deselectRowAtIndexPath:[_tableView indexPathForSelectedRow] animated:true];
            });
        }
    }
    
    if (_searchMixin.isActive)
    {
        UITableView *searchTableView = _searchMixin.searchResultsTableView;
        
        if ([searchTableView indexPathForSelectedRow] != nil)
        {
            if (cpuCoreCount() > 2)
            {
                [searchTableView deselectRowAtIndexPath:[searchTableView indexPathForSelectedRow] animated:true];
            }
            else if (cpuCoreCount() > 1)
            {
                double delayInSeconds = 0.05;
                dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
                dispatch_after(popTime, dispatch_get_main_queue(), ^
                {
                    [searchTableView deselectRowAtIndexPath:[searchTableView indexPathForSelectedRow] animated:true];
                });
            }
            else
            {
                double delayInSeconds = 0.1;
                dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
                dispatch_after(popTime, dispatch_get_main_queue(), ^{
                    [searchTableView deselectRowAtIndexPath:[searchTableView indexPathForSelectedRow] animated:true];
                });
            }
        }
    }
    
    /*if (_searchController == nil || !_searchController.isActive)
    {
        if (_tableView.contentOffset.y <= 44)
            [_tableView setContentOffset:CGPointMake(0, 44) animated:false];
    }*/
    
    _composeButton.alpha = _editingMode ? 0.0f : 1.0f;
    
    [super viewWillAppear:animated];
}

- (void)hideStripe:(UIView *)view
{
    if ([view isKindOfClass:[UIImageView class]] && view.frame.size.height == 1)
        view.hidden = true;
    for (UIView *child in view.subviews)
        [self hideStripe:child];
}

- (void)viewDidAppear:(BOOL)animated
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        TGLog(@"===== Dialog list did appear");
    });
    
    [_dialogListCompanion wakeUp];
    
    for (id cell in _tableView.visibleCells)
    {
        if ([cell isKindOfClass:[TGDialogListCell class]])
        {
            [(TGDialogListCell *)cell restartAnimations:false];
        }
    }
    
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
    if (animated)
    {
        for (NSIndexPath *indexPath in _tableView.indexPathsForVisibleRows)
        {
            UITableViewCell *cell = [_tableView cellForRowAtIndexPath:indexPath];
            
            if ([cell isKindOfClass:[TGDialogListCell class]])
            {
                TGDialogListCell *dialogCell = (TGDialogListCell *)cell;
                [dialogCell dismissEditingControls:false];
                [dialogCell stopAnimations];
            }
        }
        
        if (_searchMixin.isActive && _searchBar.selectedScopeButtonIndex == 0)
            [_searchMixin setIsActive:false animated:false];
    }
    
    [super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

- (BOOL)shouldAutorotate
{
    return true;
}

- (void)controllerInsetUpdated:(UIEdgeInsets)previousInset
{
    if (self.navigationBarShouldBeHidden)
    {
        [_tableView setContentOffset:CGPointMake(0, -_tableView.contentInset.top) animated:false];
    }
    
    if (_searchMixin != nil)
        [_searchMixin controllerInsetUpdated:self.controllerInset];
    
    [super controllerInsetUpdated:previousInset];
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    
    if (_searchMixin != nil)
        [_searchMixin controllerLayoutUpdated:[TGViewController screenSizeForInterfaceOrientation:toInterfaceOrientation]];
    
    if (_emptyListContainer != nil)
    {
        _emptyListContainer.frame = CGRectMake(floorf((self.view.frame.size.width - 250) / 2), floorf((self.view.frame.size.height - _emptyListContainer.frame.size.height) / 2), _emptyListContainer.frame.size.width, _emptyListContainer.frame.size.height);
    }
}

- (void)significantTimeChange:(NSNotification *)__unused notification
{
    for (UITableViewCell *cell in _tableView.visibleCells)
    {
        if ([cell isKindOfClass:[TGDialogListCell class]])
        {
            TGDialogListCell *dialogCell = (TGDialogListCell *)cell;
            [dialogCell resetView:true];
        }
    }
}

- (void)didEnterBackground:(NSNotification *)__unused notification
{
    for (UITableViewCell *cell in _tableView.visibleCells)
    {
        if ([cell isKindOfClass:[TGDialogListCell class]])
        {
            TGDialogListCell *dialogCell = (TGDialogListCell *)cell;
            [dialogCell stopAnimations];
        }
    }
}

- (void)willEnterForeground:(NSNotification *)__unused notification
{
    for (UITableViewCell *cell in _tableView.visibleCells)
    {
        if ([cell isKindOfClass:[TGDialogListCell class]])
        {
            TGDialogListCell *dialogCell = (TGDialogListCell *)cell;
            [dialogCell restartAnimations:true];
        }
    }
}

#pragma mark - List management

- (void)reloadData
{
    NSMutableDictionary *temporaryImageCache = [[NSMutableDictionary alloc] init];
    for (UITableViewCell *cell in _tableView.visibleCells)
    {
        if ([cell isKindOfClass:[TGDialogListCell class]])
        {
            [((TGDialogListCell *)cell) collectCachedPhotos:temporaryImageCache];
        }
    }
    [[TGRemoteImageView sharedCache] addTemporaryCachedImagesSource:temporaryImageCache autoremove:true];
    [_tableView reloadData];
}

- (void)resetState
{
    _tableView.hidden = true;
    [_emptyListContainer removeFromSuperview];
    _emptyListContainer = nil;
}

- (void)dialogListFullyReloaded:(NSArray *)items
{
    _isLoading = false;
    
    int64_t selectedConversation = INT64_MAX;
    NSIndexPath *selectedIndexPath = [_tableView indexPathForSelectedRow];
    if (selectedIndexPath != nil)
    {
        if (selectedIndexPath.row < _listModel.count)
        {
            TGConversation *conversation = [_listModel objectAtIndex:selectedIndexPath.row];
            selectedConversation = conversation.conversationId;
        }
    }
    
    [_listModel removeAllObjects];
    [_listModel addObjectsFromArray:items];
    
    [self reloadData];
    
    if (selectedConversation != INT64_MAX)
    {
        int index = -1;
        for (TGConversation *conversation in _listModel)
        {
            index++;
            int64_t conversationId = conversation.conversationId;
            if (conversationId == selectedConversation)
            {
                [_tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0] animated:false scrollPosition:UITableViewScrollPositionNone];
                
                break;
            }
        }
    }
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        TGLog(@"===== Dialog list reloaded");
    });
    
    [self updateEmptyListContainer];
}

- (void)updateEmptyListContainer
{
    if (_listModel.count == 0 && _emptyListContainer == nil)
    {
        _emptyListContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 250, 0)];
        [self.view insertSubview:_emptyListContainer belowSubview:_tableView];
        
        UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"NoMessages.png"]];
        iconView.frame = CGRectOffset(iconView.frame, floorf((_emptyListContainer.frame.size.width - iconView.frame.size.width) / 2), 0);
        [_emptyListContainer addSubview:iconView];
        
        UILabel *titleLabel = [[UILabel alloc] init];
        titleLabel.backgroundColor = [UIColor clearColor];
        titleLabel.textColor = UIColorRGB(0x8b97a5);
        titleLabel.font = [UIFont boldSystemFontOfSize:15];
        titleLabel.text = TGLocalized(@"DialogList.NoMessagesTitle");
        [titleLabel sizeToFit];
        titleLabel.frame = CGRectOffset(titleLabel.frame, floorf((_emptyListContainer.frame.size.width - titleLabel.frame.size.width) / 2), iconView.frame.origin.y + iconView.frame.size.height + 21);
        [_emptyListContainer addSubview:titleLabel];
        
        UILabel *textLabel = [[UILabel alloc] init];
        textLabel.textAlignment = UITextAlignmentCenter;
        textLabel.lineBreakMode = UILineBreakModeWordWrap;
        textLabel.numberOfLines = 0;
        textLabel.backgroundColor = [UIColor clearColor];
        textLabel.textColor = UIColorRGB(0x8b97a5);
        textLabel.font = [UIFont systemFontOfSize:14];
        textLabel.text = TGLocalized(@"DialogList.NoMessagesText");
        CGSize textLabelSize = [textLabel sizeThatFits:CGSizeMake(232, 1000)];
        textLabel.frame = CGRectMake(floorf((_emptyListContainer.frame.size.width - textLabelSize.width) / 2), titleLabel.frame.origin.y + titleLabel.frame.size.height + 8, textLabelSize.width, textLabelSize.height);
        [_emptyListContainer addSubview:textLabel];
        
        float containerHeight = textLabel.frame.origin.y + textLabel.frame.size.height;
        
        _emptyListContainer.frame = CGRectMake(floorf((self.view.frame.size.width - 250) / 2), floorf((self.view.frame.size.height - containerHeight) / 2), _emptyListContainer.frame.size.width, containerHeight);
    }
    else if (_emptyListContainer != nil && _listModel.count != 0)
    {
        [_emptyListContainer removeFromSuperview];
        _emptyListContainer = nil;
    }
    
    _tableView.hidden = _listModel.count == 0;
    if (_emptyListContainer != nil)
        _emptyListContainer.hidden = ![_dialogListCompanion shouldDisplayEmptyListPlaceholder];
}

- (void)dialogListItemsChanged:(NSArray *)__unused insertedIndices insertedItems:(NSArray *)__unused insertedItems updatedIndices:(NSArray *)__unused updatedIndices updatedItems:(NSArray *)__unused updatedItems removedIndices:(NSArray *)__unused removedIndices
{
    int countBefore = _listModel.count;
    
    NSMutableArray *removedIndexPaths = [[NSMutableArray alloc] init];
    for (NSNumber *nRemovedIndex in removedIndices)
    {
        [_listModel removeObjectAtIndex:[nRemovedIndex intValue]];
        [removedIndexPaths addObject:[NSIndexPath indexPathForRow:[nRemovedIndex intValue] inSection:0]];
    }
    
    if (removedIndexPaths.count != 0)
    {
        [_tableView beginUpdates];
        [_tableView deleteRowsAtIndexPaths:removedIndexPaths withRowAnimation:UITableViewRowAnimationRight];
        [_tableView endUpdates];
    }
    
    int index = -1;
    for (NSNumber *nUpdatedIndex in updatedIndices)
    {
        index++;
        [_listModel replaceObjectAtIndex:[nUpdatedIndex intValue] withObject:[updatedItems objectAtIndex:index]];
    }
    
    for (NSNumber *nUpdatedIndex in updatedIndices)
    {
        TGDialogListCell *cell = (TGDialogListCell *)[_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:[nUpdatedIndex intValue] inSection:0]];
        if (cell != nil)
        {
            TGConversation *conversation = [_listModel objectAtIndex:[nUpdatedIndex intValue]];
            
            [self prepareCell:cell forConversation:conversation animated:true isSearch:false];
        }
    }
    
    if ((countBefore == 0) != (_listModel.count == 0))
    {
        [self updateEmptyListContainer];
        
        if (_listModel.count == 0)
            [self setupEditingMode:false setupTable:true];
    }
}

- (void)searchResultsReloaded:(NSArray *)items searchString:(NSString *)searchString
{
    [_searchResults removeAllObjects];
    if (items != nil)
        [_searchResults addObjectsFromArray:items];
    
    [_searchMixin reloadSearchResults];
    
    [_searchMixin setSearchResultsTableViewHidden:searchString.length == 0];
}

#pragma mark - Interface logic

- (void)editButtonPressed
{
    [_editButton setSelected:true];
    
    [self setupEditingMode:!_editingMode];
}

- (void)doneButtonPressed
{
    [_doneButton setSelected:true];
    
    [self setupEditingMode:!_editingMode];
    
    for (UITableViewCell *cell in _tableView.visibleCells)
    {
        if ([cell isKindOfClass:[TGDialogListCell class]])
        {
            [(TGDialogListCell *)cell dismissEditingControls:true];
        }
    }
}

- (void)setupEditingMode:(bool)editing
{
    [self setupEditingMode:editing setupTable:true];
}

- (void)setupEditingMode:(bool)editing setupTable:(bool)setupTable
{
    _editingMode = editing;
    if (setupTable)
        [_tableView setEditing:editing animated:true];
    
    if (editing)
        [_doneButton setSelected:false];
    else
        [_editButton setSelected:false];
    
    [_dialogListCompanion updateLeftBarItem:true];
    
    [UIView animateWithDuration:0.3 animations:^
    {
        _composeButton.alpha = editing ? 0.0f : 1.0f;
    }];
}

- (void)dismissEditingControls
{
    if (_editingMode && !_tableView.editing)
        [self setupEditingMode:false setupTable:false];
}

- (void)composeMessageButtonPressed:(id)__unused sender
{
    [_dialogListCompanion composeMessage];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    static bool canSelect = true;
    if (canSelect)
    {
        canSelect = false;
        dispatch_async(dispatch_get_main_queue(), ^
        {
            canSelect = true;
        });
    }
    else
        return;
    
    if (tableView == _tableView)
    {
        UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
        if (cell.selectionStyle != UITableViewCellSelectionStyleNone)
        {
            TGConversation *conversation = nil;
            if (indexPath.row < _listModel.count)
                conversation = [_listModel objectAtIndex:indexPath.row];
            
            if (conversation != nil)
            {
                [_dialogListCompanion conversationSelected:conversation];
            }
        }
    }
    else
    {
        id result = nil;
        if (indexPath.row < _searchResults.count)
            result = [_searchResults objectAtIndex:indexPath.row];
        
        if ([result isKindOfClass:[TGConversation class]])
        {
            TGConversation *conversation = (TGConversation *)result;
            if ([conversation.additionalProperties objectForKey:@"searchMessageId"] != nil)
                [_dialogListCompanion searchResultSelectedConversation:(TGConversation *)result atMessageId:[[conversation.additionalProperties objectForKey:@"searchMessageId"] intValue]];
            else
                [_dialogListCompanion searchResultSelectedConversation:(TGConversation *)result];
        }
        else if ([result isKindOfClass:[TGUser class]])
        {
            [_dialogListCompanion searchResultSelectedUser:(TGUser *)result];
        }
        else if ([result isKindOfClass:[TGMessage class]])
        {
            [_dialogListCompanion searchResultSelectedMessage:(TGMessage *)result];
        }
    }
    
    if (_dialogListCompanion.forwardMode)
        [tableView deselectRowAtIndexPath:indexPath animated:true];
}

#pragma mark - Table logic

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)__unused section
{
    if (tableView == _tableView)
    {
        return _listModel.count;
    }
    else
    {
        return _searchResults.count;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (tableView == _tableView)
    {
        int row = indexPath.row;
        if (row >= 0 && row < _listModel.count)
            return 73;
        return 50;
    }
    else
    {
        return _searchBar.selectedScopeButtonIndex == 0 ? 51 : 73;
    }
}

- (void)prepareCell:(TGDialogListCell *)cell forConversation:(TGConversation *)conversation animated:(bool)animated isSearch:(bool)isSearch
{
    if (backgroundNormal == nil)
    {
        backgroundNormal = [[UIImage imageNamed:@"DialogListCell.png"] stretchableImageWithLeftCapWidth:1 topCapHeight:0];
        backgroundNormalHighlighted = [[UIImage imageNamed:@"DialogListCellHighlighted.png"] stretchableImageWithLeftCapWidth:1 topCapHeight:0];
    }
    
    ((UIImageView *)cell.backgroundView).image = backgroundNormal;
    ((UIImageView *)cell.selectedBackgroundView).image = backgroundNormalHighlighted;
    
    if (cell.reuseTag != (int)conversation || cell.conversationId != conversation.conversationId)
    {
        cell.reuseTag = (int)conversation;
        cell.conversationId = conversation.conversationId;
    
        cell.date = conversation.date;
        
        if (conversation.deliveryError)
            cell.deliveryState = TGMessageDeliveryStateFailed;
        else
            cell.deliveryState = conversation.deliveryState;
        
        NSDictionary *dialogListData = conversation.dialogListData;
        
        cell.titleText = [dialogListData objectForKey:@"title"];
        
        cell.isEncrypted = [dialogListData[@"isEncrypted"] boolValue];
        cell.encryptionStatus = [dialogListData[@"encryptionStatus"] intValue];
        cell.encryptedUserId = [dialogListData[@"encryptedUserId"] intValue];
        cell.encryptionOutgoing = [dialogListData[@"encryptionOutgoing"] boolValue];
        cell.encryptionFirstName = dialogListData[@"encryptionFirstName"];
        
        NSNumber *nIsChat = [dialogListData objectForKey:@"isChat"];
        if (nIsChat != nil && [nIsChat boolValue])
        {
            NSArray *chatAvatarUrls = [dialogListData objectForKey:@"chatAvatarUrls"];
            cell.groupChatAvatarCount = chatAvatarUrls.count;
            cell.groupChatAvatarUrls = chatAvatarUrls;
            cell.isGroupChat = true;
            cell.avatarUrl = [dialogListData objectForKey:@"avatarUrl"];
            
            cell.authorName = [dialogListData objectForKey:@"authorName"];
        }
        else
        {
            cell.avatarUrl = [dialogListData objectForKey:@"avatarUrl"];
            cell.isGroupChat = false;
            cell.authorName = [dialogListData objectForKey:@"authorName"];
        }
        
        cell.isMuted = [[dialogListData objectForKey:@"mute"] boolValue];
        
        cell.unread = conversation.unread;
        if (!isSearch)
        {
            cell.unreadCount = conversation.unreadCount;
            cell.serviceUnreadCount = conversation.serviceUnreadCount;
        }
        cell.outgoing = conversation.outgoing;
        
        cell.messageText = conversation.text;
        cell.messageAttachments = conversation.media;
        cell.users = [dialogListData objectForKey:@"users"];
        
        [cell resetView:animated];
    }
    
    if (!isSearch)
    {
        std::map<int64_t, NSString *>::iterator typingIt = _usersTypingInConversation.find(conversation.conversationId);
        if (typingIt == _usersTypingInConversation.end())
            [cell setTypingString:nil];
        else
            [cell setTypingString:typingIt->second];
    }
    
    [cell restartAnimations:false];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    TGUser *user = nil;
    TGConversation *conversation = nil;
    TGMessage *message = nil;
    
    if (tableView == _tableView)
    {
        if (indexPath.row < _listModel.count)
        {
            conversation = [_listModel objectAtIndex:indexPath.row];
        }
    }
    else
    {
        if (indexPath.row < _searchResults.count)
        {
            id result = [_searchResults objectAtIndex:indexPath.row];
            if ([result isKindOfClass:[TGConversation class]])
                conversation = result;
            else if ([result isKindOfClass:[TGUser class]])
                user = result;
            else if ([result isKindOfClass:[TGMessage class]])
                message = result;
        }
    }
    
    if (tableView == _tableView)
    {
        if (conversation != nil)
        {
            static NSString *MessageCellIdentifier = @"MC";
            TGDialogListCell *cell = [tableView dequeueReusableCellWithIdentifier:MessageCellIdentifier];
            
            if (cell == nil)
            {
                if (_preparedCellQueue != nil && _preparedCellQueue.count != 0)
                {
                    cell = [_preparedCellQueue lastObject];
                    [_preparedCellQueue removeLastObject];
                }
                if (cell == nil)
                {
                    cell = [[TGDialogListCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:MessageCellIdentifier assetsSource:[_dialogListCompanion dialogListCellAssetsSource]];
                    cell.watcherHandle = _actionHandle;
                    cell.enableEditing = ![_dialogListCompanion forwardMode];
                    cell.backgroundView = [[UIImageView alloc] init];
                    cell.selectedBackgroundView = [[TGHighlightImageView alloc] init];
                }
            }
            
            [self prepareCell:cell forConversation:conversation animated:false isSearch:false];
            
            return cell;
        }
        
        static NSString *PlaceholderCellIdentifier = @"LC";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:PlaceholderCellIdentifier];
        if (cell == nil)
        {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:PlaceholderCellIdentifier];
            [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
            cell.contentView.backgroundColor = [UIColor clearColor];
            
            UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
            spinner.tag = 10000;
            spinner.frame = CGRectMake(0, 0, 24, 24);
            spinner.center = cell.center;
            spinner.autoresizingMask = (UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin);
            [cell.contentView addSubview:spinner];
        }
        UIActivityIndicatorView *spinner = (UIActivityIndicatorView *)[cell viewWithTag:10000];
        if (_canLoadMore)
        {
            spinner.hidden = false;
            [spinner startAnimating];
        }
        else
        {
            spinner.hidden = true;
            [spinner stopAnimating];
        }
        return cell;
    }
    else
    {
        if ((conversation != nil || user != nil) && _searchBar.selectedScopeButtonIndex == 0)
        {
            static NSString *SearchCellIdentifier = @"UC";
            TGDialogListSearchCell *cell = [tableView dequeueReusableCellWithIdentifier:SearchCellIdentifier];
            if (cell == nil)
            {
                cell = [[TGDialogListSearchCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:SearchCellIdentifier assetsSource:[_dialogListCompanion dialogListCellAssetsSource]];
            }
            
            cell.isEncrypted = false;
            cell.encryptedUserId = 0;
            
            if (conversation != nil)
            {
                NSDictionary *dialogListData = conversation.dialogListData;
                
                cell.titleTextFirst = [dialogListData objectForKey:@"title"];
                
                NSNumber *nIsChat = [dialogListData objectForKey:@"isChat"];
                if (nIsChat != nil && [nIsChat boolValue])
                {
                    cell.isChat = true;
                }
                
                cell.avatarUrl = [dialogListData objectForKey:@"avatarUrl"];
                
                cell.titleTextSecond = nil;
                cell.subtitleText = nil;
                
                cell.conversationId = conversation.conversationId;
                cell.isEncrypted = [dialogListData[@"isEncrypted"] boolValue];
                cell.encryptedUserId = [dialogListData[@"encryptedUserId"] intValue];
            }
            else if (user != nil)
            {
                cell.isChat = false;
                
                cell.avatarUrl = user.photoUrlSmall;
                if (user.firstName.length == 0)
                {
                    cell.titleTextFirst = user.lastName;
                    cell.titleTextSecond = nil;
                }
                else
                {
                    cell.titleTextFirst = user.firstName;
                    cell.titleTextSecond = user.lastName;
                }
                
                cell.subtitleText = nil;
                
                cell.conversationId = user.uid;
            }
            
            [cell resetView:false];
            return cell;
        }
        else if (conversation != nil)
        {
            static NSString *MessageCellIdentifier = @"MC";
            TGDialogListCell *cell = [tableView dequeueReusableCellWithIdentifier:MessageCellIdentifier];
            
            if (cell == nil)
            {
                if (_preparedCellQueue != nil && _preparedCellQueue.count != 0)
                {
                    cell = [_preparedCellQueue lastObject];
                    [_preparedCellQueue removeLastObject];
                }
                if (cell == nil)
                {
                    cell = [[TGDialogListCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:MessageCellIdentifier assetsSource:[_dialogListCompanion dialogListCellAssetsSource]];
                    cell.watcherHandle = _actionHandle;
                    cell.enableEditing = false;
                    cell.backgroundView = [[UIImageView alloc] init];
                    cell.selectedBackgroundView = [[TGHighlightImageView alloc] init];
                }
            }
            
            [self prepareCell:cell forConversation:conversation animated:false isSearch:true];
            
            return cell;
        }
    }
    
    return nil;
}

#pragma mark -

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    if (scrollView == _tableView)
    {
        _tableViewLastScrollPosition = (int)scrollView.contentOffset.y;
        
        for (UITableViewCell *cell in _tableView.visibleCells)
        {
            if ([cell isKindOfClass:[TGDialogListCell class]])
            {
                TGDialogListCell *dialogCell = (TGDialogListCell *)cell;
                [dialogCell dismissEditingControls:true];
            }
        }
    }
    else
    {
        [self.view endEditing:true];
    }
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if (scrollView == _tableView)
    {
        if (iosMajorVersion() < 6 && !decelerate && scrollView.contentOffset.y >= 0 && scrollView.contentOffset.y < 44)
        {
            if (_tableViewLastScrollPosition >= 44)
            {
                if (scrollView.contentOffset.y < 44 - 15)
                    [scrollView setContentOffset:CGPointMake(0, 0) animated:true];
                else
                    [scrollView setContentOffset:CGPointMake(0, 44) animated:true];
            }
            else if (_tableViewLastScrollPosition <= 15)
            {
                if (scrollView.contentOffset.y < 15)
                    [scrollView setContentOffset:CGPointMake(0, 0) animated:true];
                else
                    [scrollView setContentOffset:CGPointMake(0, 44) animated:true];
            }
        }

        if (!decelerate)
            _tableViewLastScrollPosition = (int)scrollView.contentOffset.y;
    }
    
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    if (scrollView == _tableView)
    {
        if (iosMajorVersion() < 6 && scrollView.contentOffset.y >= 0 && scrollView.contentOffset.y < 44)
        {
            if (_tableViewLastScrollPosition >= 44)
            {
                if (scrollView.contentOffset.y < 44 - 15)
                    [scrollView setContentOffset:CGPointMake(0, 0) animated:true];
                else
                    [scrollView setContentOffset:CGPointMake(0, 44) animated:true];
            }
            else if (_tableViewLastScrollPosition <= 15)
            {
                if (scrollView.contentOffset.y < 15)
                    [scrollView setContentOffset:CGPointMake(0, 0) animated:true];
                else
                    [scrollView setContentOffset:CGPointMake(0, 44) animated:true];
            }
        }
        
        _tableViewLastScrollPosition = (int)scrollView.contentOffset.y;
    }
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)__unused cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (tableView == _tableView)
    {
        int listCount = _listModel.count;
        if (_canLoadMore && !_isLoading && listCount != 0 && (listCount < 10 || indexPath.row >= listCount - 10))
        {
            _isLoading = true;
            [_dialogListCompanion loadMoreItems];
        }
    }
    else
    {
        
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (tableView == _tableView)
    {
        return indexPath.row < _listModel.count;
    }
    else
    {
        return false;
    }
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)__unused tableView editingStyleForRowAtIndexPath:(NSIndexPath *)__unused indexPath
{
    return UITableViewCellEditingStyleNone;
}

- (BOOL)tableView:(UITableView *)tableView shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (tableView == _tableView)
        return indexPath.row < _listModel.count;
    return false;
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    _currentActionSheet.delegate = nil;
    _currentActionSheet = nil;
    
    if (buttonIndex != actionSheet.cancelButtonIndex)
    {
        if (buttonIndex == actionSheet.destructiveButtonIndex)
        {
            if (_conversationIdToDelete != 0)
            {
                for (TGConversation *conversation in _listModel)
                {
                    if (conversation.conversationId == _conversationIdToDelete)
                    {
                        [_dialogListCompanion deleteItem:conversation animated:true];
                        break;
                    }
                }
            }
        }
        else
        {
            if (_conversationIdToDelete != 0)
            {
                for (TGConversation *conversation in _listModel)
                {
                    if (conversation.conversationId == _conversationIdToDelete)
                    {
                        [_dialogListCompanion clearItem:conversation animated:true];
                        break;
                    }
                }
            }
        }
    }
    _conversationIdToDelete = 0;
}

#pragma mark -

- (UITableView *)createTableViewForSearchMixin:(TGSearchDisplayMixin *)__unused searchMixin
{
    UITableView *tableView = [[UITableView alloc] init];
    
    tableView.delegate = self;
    tableView.dataSource = self;
    
    tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    if (tableView.tableFooterView == nil)
        tableView.tableFooterView = [[UIView alloc] init];
    
    return tableView;
}

- (UIView *)referenceViewForSearchResults
{
    return _tableView;
}

- (void)searchMixin:(TGSearchDisplayMixin *)__unused searchMixin hasChangedSearchQuery:(NSString *)searchQuery withScope:(int)scope
{
    [_dialogListCompanion beginSearch:searchQuery inMessages:scope == 1];
    
    if (searchQuery.length == 0)
        [_searchMixin setSearchResultsTableViewHidden:true];
}

- (void)searchMixinWillActivate:(bool)animated
{
    _tableView.scrollEnabled = false;
    
    [self setNavigationBarHidden:true animated:animated];
}

- (void)searchMixinWillDeactivate:(bool)animated
{
    _tableView.scrollEnabled = true;
    
    [self setNavigationBarHidden:false animated:animated];
}

#pragma mark -

- (void)searchDisplayControllerDidEndSearch:(UISearchDisplayController *)__unused controller
{
    [_searchBar setSelectedScopeButtonIndex:0];
}

- (BOOL)searchDisplayController:(UISearchDisplayController *)__unused controller shouldReloadTableForSearchString:(NSString *)searchString
{
    [_dialogListCompanion beginSearch:searchString inMessages:_searchBar.selectedScopeButtonIndex == 1];
    
    return FALSE;
}

- (void)searchDisplayController:(UISearchDisplayController *)__unused controller willShowSearchResultsTableView:(UITableView *)__unused tableView
{
    tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    if (tableView.tableFooterView == nil)
        tableView.tableFooterView = [[UIView alloc] init];
    
    tableView.hidden = true;
}

- (void)searchDisplayController:(UISearchDisplayController *)__unused controller willHideSearchResultsTableView:(UITableView *)tableView
{
    tableView.hidden = false;
}

- (BOOL)searchDisplayController:(UISearchDisplayController *)__unused controller shouldReloadTableForSearchScope:(NSInteger)searchOption
{
    [_dialogListCompanion beginSearch:_searchBar.text inMessages:searchOption];
    
    return false;
}

- (void)actionStageActionRequested:(NSString *)action options:(NSDictionary *)options
{
    if ([action isEqualToString:@"conversationMenuOpened"])
    {
        int64_t conversationId = [[options objectForKey:@"conversationId"] longLongValue];
        for (NSIndexPath *indexPath in _tableView.indexPathsForVisibleRows)
        {
            UITableViewCell *cell = [_tableView cellForRowAtIndexPath:indexPath];
            
            if ([cell isKindOfClass:[TGDialogListCell class]])
            {
                TGDialogListCell *dialogCell = (TGDialogListCell *)cell;
                if (dialogCell.conversationId != conversationId)
                {
                    [dialogCell dismissEditingControls:true];
                }
                
                [cell setSelected:false];
                [cell setHighlighted:false];
            }
        }
        
        if (_tableView.indexPathForSelectedRow != nil)
            [_tableView deselectRowAtIndexPath:_tableView.indexPathForSelectedRow animated:false];
    }
    else if ([action isEqualToString:@"conversationDeleteRequested"])
    {
        [_tableView setFocusCell:nil];
        
        if (!_tableView.isEditing)
            [self setupEditingMode:false setupTable:false];
        
        int64_t conversationId = [[options objectForKey:@"conversationId"] longLongValue];
        for (NSIndexPath *indexPath in _tableView.indexPathsForVisibleRows)
        {
            UITableViewCell *cell = [_tableView cellForRowAtIndexPath:indexPath];
            
            if ([cell isKindOfClass:[TGDialogListCell class]])
            {
                TGDialogListCell *dialogCell = (TGDialogListCell *)cell;
                if (dialogCell.conversationId == conversationId)
                {
                    [dialogCell dismissEditingControls:false];
                    
                    TGConversation *conversation = nil;
                    if (indexPath.row < _listModel.count)
                        conversation = [_listModel objectAtIndex:indexPath.row];
                    
                    if (conversation != nil)
                    {
                        if (conversation.isChat)
                        {
                            _conversationIdToDelete = conversation.conversationId;
                            
                            _currentActionSheet.delegate = nil;
                            
                            _currentActionSheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
                            [_currentActionSheet addButtonWithTitle:TGLocalized(@"DialogList.ClearHistoryConfirmation")];
                            _currentActionSheet.destructiveButtonIndex = [_currentActionSheet addButtonWithTitle:TGLocalized(@"DialogList.DeleteConversationConfirmation")];
                            _currentActionSheet.cancelButtonIndex = [_currentActionSheet addButtonWithTitle:TGLocalized(@"Common.Cancel")];
                            
                            [_currentActionSheet showInView:self.navigationController.view];
                        }
                        else
                            [_dialogListCompanion deleteItem:conversation animated:true];
                    }
                    
                    break;
                }
            }
        }
    }
    else if ([action isEqualToString:@"setFocusCell"])
    {
        [_tableView setFocusCell:[options objectForKey:@"cell"]];
        if (!_editingMode)
            [self setupEditingMode:true setupTable:false];
    }
}

@end

