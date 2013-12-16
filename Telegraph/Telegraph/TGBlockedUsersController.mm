#import "TGBlockedUsersController.h"

#import "SGraphObjectNode.h"

#import "TGUser.h"
#import "TGContactCell.h"

#import "TGActionTableView.h"

#import "TGToolbarButton.h"

#import "TGActivityIndicatorView.h"

#import "TGAppDelegate.h"
#import "TGDatabase.h"
#import "TGTelegraph.h"
#import "TGInterfaceAssets.h"
#import "TGInterfaceManager.h"

#import "TGBlockActionCell.h"

#import "TGForwardTargetController.h"
#import "TGDialogListCompanion.h"

#include <set>

#pragma mark -

@interface TGBlockedUsersController () <UITableViewDataSource, UITableViewDelegate, TGActionTableViewDelegate>

@property (nonatomic, strong) TGActionTableView *tableView;
@property (nonatomic, strong) UIView *emptyTablePlaceholder;

@property (nonatomic, strong) NSMutableArray *listModel;

@end

@implementation TGBlockedUsersController

@synthesize actionHandle = _actionHandle;

@synthesize tableView = _tableView;
@synthesize emptyTablePlaceholder = _emptyTablePlaceholder;

@synthesize listModel = _listModel;

- (id)init
{
    self = [super init];
    if (self)
    {
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:true];
        
        _listModel = [[NSMutableArray alloc] init];
        
        [ActionStageInstance() dispatchOnStageQueue:^
        {
            [ActionStageInstance() watchForPath:@"/tg/blockedUsers" watcher:self];
            [ActionStageInstance() requestActor:@"/tg/blockedUsers/(cached)" options:nil watcher:self];
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
    
    self.view.backgroundColor = UIColorRGB(0xe9edf3);
    
    self.backAction = @selector(performClose);
    self.titleText = TGLocalized(@"BlockedUsers.Title");
    
    _emptyTablePlaceholder = [[UIView alloc] initWithFrame:CGRectMake(0, floorf((self.view.frame.size.height - 70) / 2), self.view.frame.size.width, 70)];
    _emptyTablePlaceholder.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    
    UILabel *label1 = [[UILabel alloc] init];
    label1.backgroundColor = [UIColor clearColor];
    label1.font = [UIFont boldSystemFontOfSize:14];
    label1.textColor = UIColorRGB(0x8694a4);
    label1.shadowColor = UIColorRGBA(0xffffff, 0.5f);
    label1.shadowOffset = CGSizeMake(0, 1);
    label1.text = TGLocalized(@"BlockedUsers.EmptyListLabel");
    [label1 sizeToFit];
    label1.frame = CGRectOffset(label1.frame, floorf((_emptyTablePlaceholder.frame.size.width - label1.frame.size.width) / 2), 0);
    [_emptyTablePlaceholder addSubview:label1];
    
    UILabel *label2 = [[UILabel alloc] init];
    label2.backgroundColor = [UIColor clearColor];
    label2.font = [UIFont systemFontOfSize:14];
    label2.textColor = UIColorRGB(0x8694a4);
    label2.shadowColor = UIColorRGBA(0xffffff, 0.5f);
    label2.shadowOffset = CGSizeMake(0, 1);
    label2.text = TGLocalized(@"BlockedUsers.EmptyListHelp");
    label2.numberOfLines = 0;
    label2.textAlignment = UITextAlignmentCenter;
    CGSize labelSize = [label2 sizeThatFits:CGSizeMake(260, 1000)];
    label2.frame = CGRectMake(0, 0, labelSize.width, labelSize.height);
    label2.frame = CGRectOffset(label2.frame, floorf((_emptyTablePlaceholder.frame.size.width - label2.frame.size.width) / 2), 26);
    [_emptyTablePlaceholder addSubview:label2];
    
    [self.view addSubview:_emptyTablePlaceholder];
    
    _tableView = [[TGActionTableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableView.delegate = self;
    _tableView.backgroundColor = nil;
    _tableView.opaque = false;
    _tableView.dataSource = self;
    
    [_tableView enableSwipeToLeftAction];
    UISwipeGestureRecognizer *swipeRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeRecognized:)];
    swipeRecognizer.direction = UISwipeGestureRecognizerDirectionRight;
    [self.view addGestureRecognizer:swipeRecognizer];
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.tableFooterView = [[UIView alloc] init];
    
    [self.view addSubview:_tableView];
    
    [self updateEmptyState:false];
}

- (void)doUnloadView
{
    _tableView.delegate = nil;
    _tableView.dataSource = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    if ([_tableView indexPathForSelectedRow] != nil)
        [_tableView deselectRowAtIndexPath:[_tableView indexPathForSelectedRow] animated:animated];
    
    [self updateNavigationButtons:false];
    
    [super viewWillAppear:animated];
}

- (void)updateNavigationButtons:(bool)animated
{
    if (_tableView.editing)
    {
        if (self.navigationItem.leftBarButtonItem.customView.tag != ((int)0x0A214F56))
        {
            TGToolbarButton *addButton = [[TGToolbarButton alloc] initWithType:TGToolbarButtonTypeGeneric];
            addButton.tag = ((int)0x0A214F56);
            addButton.image = [UIImage imageNamed:@"AddIcon.png"];
            addButton.imageLandscape = [UIImage imageNamed:@"AddIcon_Landscape.png"];
            addButton.minWidth = 35;
            [addButton sizeToFit];
            [addButton addTarget:self action:@selector(addButtonPressed) forControlEvents:UIControlEventTouchUpInside];
            [self.navigationItem setLeftBarButtonItem:[[UIBarButtonItem alloc] initWithCustomView:addButton] animated:animated];
            
            addButton.alpha = 0.0f;
        }
        
        if (self.navigationItem.rightBarButtonItem.customView.tag != ((int)0x28DB5B6A))
        {
            TGToolbarButton *doneButton = [[TGToolbarButton alloc] initWithType:TGToolbarButtonTypeDone];
            doneButton.tag = ((int)0x28DB5B6A);
            doneButton.text = NSLocalizedString(@"Common.Done", @"");
            doneButton.minWidth = 51;
            doneButton.paddingLeft = 10;
            doneButton.paddingRight = 10;
            [doneButton sizeToFit];
            [doneButton addTarget:self action:@selector(doneButtonPressed) forControlEvents:UIControlEventTouchUpInside];
            [self.navigationItem setRightBarButtonItem:[[UIBarButtonItem alloc] initWithCustomView:doneButton] animated:animated];
        }
    }
    else
    {
        if (self.navigationItem.leftBarButtonItem.customView.tag != ((int)0x263D9E33))
        {
            [self setBackAction:@selector(performClose) animated:animated];
        }
        
        if (self.navigationItem.rightBarButtonItem.customView.tag != ((int)0x8E2030EA))
        {
            TGToolbarButton *editButton = [[TGToolbarButton alloc] initWithType:TGToolbarButtonTypeGeneric];
            editButton.tag = ((int)0x8E2030EA);
            editButton.text = NSLocalizedString(@"Common.Edit", @"");
            editButton.minWidth = 51;
            editButton.paddingLeft = 10;
            editButton.paddingRight = 10;
            [editButton sizeToFit];
            [editButton addTarget:self action:@selector(editButtonPressed) forControlEvents:UIControlEventTouchUpInside];
            [self.navigationItem setRightBarButtonItem:[[UIBarButtonItem alloc] initWithCustomView:editButton] animated:animated];
        }
        
        float alpha = _listModel.count != 0 ? 1.0f : 0.0f;
        
        if (animated)
        {
            [UIView animateWithDuration:0.3 animations:^
            {
                self.navigationItem.rightBarButtonItem.customView.alpha = alpha;
            } completion:^(BOOL finished)
            {
                if (finished)
                {
                    self.navigationItem.rightBarButtonItem.customView.hidden = alpha < FLT_EPSILON;
                }
            }];
        }
        else
        {
            self.navigationItem.rightBarButtonItem.customView.alpha = alpha;
            self.navigationItem.rightBarButtonItem.customView.hidden = alpha < FLT_EPSILON;
        }
    }
}

- (void)updateEmptyState:(bool)animated
{
    if (_listModel.count == 0)
    {
        _emptyTablePlaceholder.hidden = false;
        _tableView.scrollEnabled = false;
        
        if (animated)
        {
            [UIView animateWithDuration:0.3 animations:^
            {
                _emptyTablePlaceholder.alpha = 1.0f;
                _tableView.backgroundColor = [UIColor clearColor];
            } completion:nil];
        }
        else
        {
            _emptyTablePlaceholder.alpha = 1.0f;
            _tableView.backgroundColor = [UIColor clearColor];
        }
    }
    else
    {
        _tableView.scrollEnabled = true;
        if (animated)
        {
            if (_emptyTablePlaceholder.alpha > FLT_EPSILON)
            {
                [UIView animateWithDuration:0.3 animations:^
                {
                    _emptyTablePlaceholder.alpha = 0.0f;
                    _tableView.backgroundColor = [UIColor whiteColor];
                } completion:^(BOOL finished)
                {
                    if (finished)
                    {
                        _emptyTablePlaceholder.hidden = true;
                    }
                }];
            }
        }
        else
        {
            _emptyTablePlaceholder.hidden = true;
            _emptyTablePlaceholder.alpha = 0.0f;
            _tableView.backgroundColor = [UIColor whiteColor];
        }
    }
    
    for (UITableViewCell *cell in _tableView.visibleCells)
    {
        if ([cell isKindOfClass:[TGBlockActionCell class]])
        {
            TGBlockActionCell *actionCell = (TGBlockActionCell *)cell;
            [actionCell setEnableShadow:_listModel.count == 0 animated:animated];
        }
    }
    
    [self updateNavigationButtons:animated];
}

#pragma mark -

- (NSInteger)numberOfSectionsInTableView:(UITableView *)__unused tableView
{
    return 2;
}

- (CGFloat)tableView:(UITableView *)__unused tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0)
        return 44;
    return 51;
}

- (NSInteger)tableView:(UITableView *)__unused tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0)
        return 1;
    else if (section == 1)
        return _listModel.count;
    
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0)
    {
        static NSString *actionCellIdentifier = @"BAC";
        TGBlockActionCell *actionCell = (TGBlockActionCell *)[tableView dequeueReusableCellWithIdentifier:actionCellIdentifier];
        if (actionCell == nil)
        {
            actionCell = [[TGBlockActionCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:actionCellIdentifier];
        }
    
        [actionCell setEnableShadow:_listModel.count == 0 animated:false];
        return actionCell;
    }
    else
    {
        TGUser *user = nil;
        if (indexPath.row < (int)_listModel.count)
            user = [_listModel objectAtIndex:indexPath.row];
        
        if (user != nil)
        {
            static NSString *contactCellIdentifier = @"CC";
            TGContactCell *contactCell = (TGContactCell *)[tableView dequeueReusableCellWithIdentifier:contactCellIdentifier];
            if (contactCell == nil)
            {
                contactCell = [[TGContactCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:contactCellIdentifier selectionControls:false editingControls:true];
            }
            
            contactCell.itemId = user.uid;
            contactCell.avatarUrl = user.photoUrlSmall;
            if (user.firstName.length == 0)
            {
                contactCell.titleTextFirst = user.lastName;
                contactCell.titleTextSecond = nil;
            }
            else
            {
                contactCell.titleTextFirst = user.firstName;
                contactCell.titleTextSecond = user.lastName;
            }
            
            [contactCell resetView:false];
            
            return contactCell;
        }
    }
    
    static NSString *emptyCellIdentifier = @"0";
    UITableViewCell *emptyCell = [tableView dequeueReusableCellWithIdentifier:emptyCellIdentifier];
    if (emptyCell == nil)
    {
        emptyCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:emptyCellIdentifier];
    }
    
    return emptyCell;
}

- (void)tableView:(UITableView *)__unused tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0)
    {
        [self addButtonPressed];
    }
    else
    {
        TGUser *user = nil;
        if (indexPath.row < (int)_listModel.count)
            user = [_listModel objectAtIndex:indexPath.row];
        
        if (user != nil)
            [[TGInterfaceManager instance] navigateToProfileOfUser:user.uid];
    }
}

- (BOOL)tableView:(UITableView *)__unused tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return indexPath.section == 1;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)__unused tableView editingStyleForRowAtIndexPath:(NSIndexPath *)__unused indexPath
{
    return UITableViewCellEditingStyleNone;
}

- (NSIndexPath *)indexPathForCell:(UITableViewCell *)cell
{
    for (NSIndexPath *indexPath in [_tableView indexPathsForVisibleRows])
    {
        if ([_tableView cellForRowAtIndexPath:indexPath] == cell)
            return indexPath;
    }
    
    return nil;
}

- (void)dismissEditingControls
{
}

- (void)commitAction:(UITableViewCell *)cell
{
    NSIndexPath *indexPath = [self indexPathForCell:cell];
    if (indexPath == nil)
        return;
    
    TGUser *user = [_listModel objectAtIndex:indexPath.row];
    
    [_listModel removeObjectAtIndex:indexPath.row];
    
    [_tableView beginUpdates];
    [_tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
    [_tableView endUpdates];
    
    if (_listModel.count == 0)
        [_tableView setEditing:false animated:true];
    
    [self updateEmptyState:true];
    
    static int actionId = 0;
    [ActionStageInstance() requestActor:[[NSString alloc] initWithFormat:@"/tg/changePeerBlockedStatus/(%d)", actionId++] options:[[NSDictionary alloc] initWithObjectsAndKeys:[[NSNumber alloc] initWithLongLong:user.uid], @"peerId", [[NSNumber alloc] initWithBool:false], @"block", nil] watcher:TGTelegraphInstance];
}

#pragma mark -

- (void)performClose
{
    [self.navigationController popViewControllerAnimated:true];
}

- (void)performSwipeToLeftAction
{
    if (!_tableView.editing)
        [self performClose];
}

- (void)swipeRecognized:(UISwipeGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateRecognized)
    {
        [self performSwipeToLeftAction];
    }
}

- (void)addButtonPressed
{
    TGForwardTargetController *selectUserController = [[TGForwardTargetController alloc] initWithSelectBlockTarget];
    selectUserController.watcherHandle = _actionHandle;
    TGNavigationController *navigationController = [TGNavigationController navigationControllerWithRootController:selectUserController blackCorners:false];
    
    if (iosMajorVersion() <= 5)
    {
        [TGViewController disableAutorotationFor:0.45];
        [selectUserController view];
        [selectUserController viewWillAppear:false];
        
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
                [selectUserController viewWillDisappear:false];
                [selectUserController viewDidDisappear:false];
                [self presentViewController:navigationController animated:false completion:nil];
            }
        }];
    }
    else
    {
        [self presentViewController:navigationController animated:true completion:nil];
    }
}

- (void)editButtonPressed
{
    if ([self.navigationItem.rightBarButtonItem.customView isKindOfClass:[UIButton class]])
        ((UIButton *)self.navigationItem.rightBarButtonItem.customView).selected = true;
    [_tableView setEditing:true animated:true];
    
    [self updateNavigationButtons:true];
}

- (void)doneButtonPressed
{
    if ([self.navigationItem.rightBarButtonItem.customView isKindOfClass:[UIButton class]])
        ((UIButton *)self.navigationItem.rightBarButtonItem.customView).selected = true;
    [_tableView setEditing:false animated:true];
    
    [self updateNavigationButtons:true];
}

#pragma mark -

- (void)actionStageResourceDispatched:(NSString *)path resource:(id)resource arguments:(id)__unused arguments
{
    if ([path isEqualToString:@"/tg/blockedUsers"])
    {
        [self actorCompleted:ASStatusSuccess path:path result:resource];
    }
}

- (void)actorCompleted:(int)resultCode path:(NSString *)path result:(id)result
{
    if ([path hasPrefix:@"/tg/blockedUsers"])
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            if (resultCode == ASStatusSuccess)
            {
                NSArray *users = ((SGraphObjectNode *)result).object;
                
                std::set<int> currentUsers;
                for (TGUser *user in _listModel)
                    currentUsers.insert(user.uid);
                
                std::set<int> newUsers;
                for (TGUser *user in users)
                    newUsers.insert(user.uid);
                
                if (newUsers != currentUsers)
                {
                    [_listModel removeAllObjects];
                    [_listModel addObjectsFromArray:users];
                    
                    [_tableView reloadData];
                }
                
                [self updateEmptyState:true];
                [self updateNavigationButtons:true];
            }
        });
    }
}

- (void)actionStageActionRequested:(NSString *)action options:(id)options
{
    if ([action isEqualToString:@"blockUser"])
    {
        TGUser *user = options;
        if (user != nil)
        {
            int uid = user.uid;
            bool found = false;
            for (TGUser *listUser in _listModel)
            {
                if (listUser.uid == uid)
                {
                    found = true;
                    break;
                }
            }
            
            if (found)
            {
                UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:nil message:TGLocalized(@"BlockedUsers.AlreadyBlocked") delegate:nil cancelButtonTitle:NSLocalizedString(@"Common.OK", nil) otherButtonTitles:nil];
                [alertView show];
            }
            else
            {
                [_listModel insertObject:user atIndex:0];
                [_tableView reloadData];
                [_tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:1] animated:false scrollPosition:UITableViewScrollPositionNone];
                
                [self updateEmptyState:false];
                [self updateNavigationButtons:false];
                
                static int actionId = 0;
                [ActionStageInstance() requestActor:[[NSString alloc] initWithFormat:@"/tg/changePeerBlockedStatus/(%d)", actionId++] options:[[NSDictionary alloc] initWithObjectsAndKeys:[[NSNumber alloc] initWithLongLong:user.uid], @"peerId", [[NSNumber alloc] initWithBool:true], @"block", nil] watcher:TGTelegraphInstance];
                
                [self dismissViewControllerAnimated:true completion:nil];
            }
        }
    }
    else if ([action isEqualToString:@"leaveConversation"])
    {
        TGConversation *conversation = options;
        
        [TGAppDelegateInstance.dialogListController.dialogListCompanion deleteItem:[[TGConversation alloc] initWithConversationId:conversation.conversationId unreadCount:0 serviceUnreadCount:0] animated:false];
        
        [self dismissViewControllerAnimated:true completion:nil];
    }
}

@end
