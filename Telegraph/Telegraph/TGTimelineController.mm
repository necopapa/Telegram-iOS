#import "TGTimelineController.h"

/*#import "TGAppDelegate.h"
#import "TGTabControllerChild.h"

#import "TGTelegraph.h"
#import "TGUser.h"
#import "TGUserNode.h"

#import "TGInterfaceManager.h"
#import "TGInterfaceAssets.h"

#import "TGSettingsController.h"

#import "TGTableView.h"
#import "TGRemoteImageView.h"

#import "TGTimelineItem.h"
#import "TGTimelineCell.h"

#import "SGraphListNode.h"
#import "SGraphObjectNode.h"

#import "TGDateUtils.h"

#import "TGImageUtils.h"

#import <QuartzCore/QuartzCore.h>

#import "TGLocationRequestActor.h"

#import "TGMapViewController.h"

#import "TGHacks.h"

#import <set>

typedef enum {
    TGTimelineTypeCurrentUser = 0,
    TGTimelineTypeFriend = 1,
    TGTimelineTypeUser = 2
} TGTimelineType;

typedef enum {
    TGTimelineActionSheetTypeChangeStatusPhoto = 20001
} TGTimelineActionSheetType;

@interface TGTimelineController () <TGTabControllerChild, UITableViewDataSource, UITableViewDelegate, UIActionSheetDelegate, UIAlertViewDelegate>

@property (nonatomic) int uid;
@property (nonatomic, strong) TGUser *user;

@property (nonatomic) TGTimelineType type;

@property (nonatomic) NSTimeInterval loadingStartTime;

@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;

@property (nonatomic, strong) TGTableView *tableView;
@property (nonatomic, strong) TGCache *imageCache;

@property (nonatomic, strong) NSMutableArray *listModel;
@property (nonatomic) bool loadingTimeline;
@property (nonatomic) bool canLoadMore;

@property (nonatomic) int lastScrollingPosition;
@property (nonatomic) int lastDisplayIndex;
@property (nonatomic) NSTimeInterval lastPreloadDate;
@property (nonatomic, strong) NSMutableArray *preloadingIndices;

@property (nonatomic, strong) NSMutableArray *uploadingPhotoInternalUrls;

@property (nonatomic, strong) NSString *currentApplyPhotoAction;

- (void)commonInit;

@end

@implementation TGTimelineController
@synthesize actionHandle = _actionHandle;

@synthesize uid = _uid;
@synthesize user = _user;

@synthesize type = _type;

@synthesize loadingStartTime = _loadingStartTime;

@synthesize activityIndicator = _activityIndicator;

@synthesize tableView = _tableView;
@synthesize imageCache = _imageCache;

@synthesize listModel = _listModel;
@synthesize loadingTimeline = _loadingTimeline;
@synthesize canLoadMore = _canLoadMore;

@synthesize lastPreloadDate = _lastPreloadDate;
@synthesize lastScrollingPosition = _lastScrollingPosition;
@synthesize lastDisplayIndex = _lastDisplayIndex;
@synthesize preloadingIndices = _preloadingIndices;

@synthesize uploadingPhotoInternalUrls = _uploadingPhotoInternalUrls;

@synthesize currentApplyPhotoAction = _currentApplyPhotoAction;

- (id)initWithUid:(int)uid
{
    self = [super initWithNibName:nil bundle:nil];
    if (self)
    {
        _uid = uid;
        
        [self commonInit];
    }
    return self;
}

- (id)init
{
    self = [super initWithNibName:nil bundle:nil];
    if (self)
    {
        _uid = INT_MAX;
        
        [self commonInit];
    }
    return self;
}

- (void)commonInit
{
    _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:true];
    
    _listModel = [[NSMutableArray alloc] init];
    _loadingTimeline = false;
    
    _type = TGTimelineTypeUser;
    
    if (_uid == TGTelegraphInstance.clientUserId)
        _type = TGTimelineTypeCurrentUser;
    
    _preloadingIndices = [[NSMutableArray alloc] init];
    
    _uploadingPhotoInternalUrls = [[NSMutableArray alloc] init];
    
    [ActionStageInstance() watchForPath:@"/tg/userdatachanges" watcher:self];
    [ActionStageInstance() watchForPath:@"/tg/userpresencechanges" watcher:self];
    [ActionStageInstance() watchForPath:[NSString stringWithFormat:@"/tg/timeline/(%d)/items", _uid] watcher:self];
}

- (void)dealloc
{
    [_actionHandle reset];
    [ActionStageInstance() removeWatcher:self];
    
    [self doUnloadView];
}

- (void)switchToUid:(int)uid
{
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        [ActionStageInstance() removeWatcher:self];
        
        dispatch_async(dispatch_get_main_queue(), ^
        {
            _uid = uid;
            _user = nil;
            [_listModel removeAllObjects];
            [_tableView reloadData];
            
            TGTimelineType newType = TGTimelineTypeUser;
            if (_uid == TGTelegraphInstance.clientUserId)
                newType = TGTimelineTypeCurrentUser;
            _type = newType;
            
            if (self.isViewLoaded)
            {
                if (_uid != INT_MAX)
                {
                    _loadingStartTime = CFAbsoluteTimeGetCurrent();
                    [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/users/(%d)", uid] options:nil watcher:self];
                }
            }
        });
        
        [ActionStageInstance() watchForPath:@"/tg/userdatachanges" watcher:self];
        [ActionStageInstance() watchForPath:@"/tg/userpresencechanges" watcher:self];
        [ActionStageInstance() watchForPath:[NSString stringWithFormat:@"/tg/timeline/(%d)/items", uid] watcher:self];
    }];
}

- (NSString *)controllerTitle
{
    return NSLocalizedString(@"Timeline.Title", @"");
}

- (void)loadView
{
    [super loadView];
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    self.backAction = @selector(performCloseTimeline);
    
    self.titleText = NSLocalizedString(@"Timeline.Title", @"");
    
    _activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    _activityIndicator.frame = CGRectMake((int)((self.view.frame.size.width - _activityIndicator.frame.size.width)/2), (int)((self.view.frame.size.height - _activityIndicator.frame.size.height)/2), _activityIndicator.frame.size.width, _activityIndicator.frame.size.height);
    _activityIndicator.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    [self.view addSubview:_activityIndicator];
    
    CGSize viewSize = self.view.bounds.size;
    
    _tableView = [[TGTableView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height) style:UITableViewStylePlain reversed:false];
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.backgroundColor = [UIColor clearColor];
    _tableView.delaysContentTouches = false;
    [self.view addSubview:_tableView];
    
    UIView *footerView = [[UIView alloc] initWithFrame:CGRectMake(0, 9, viewSize.width, 10)];
    _tableView.tableFooterView = footerView;
    
    _tableView.contentInset = UIEdgeInsetsMake(0, 0, 0, 0);
    _tableView.scrollInsets = UIEdgeInsetsMake(0, 0, 0, TGIsRetina() ? 0.5f : 0);
    
    if (_uid != INT_MAX)
    {
        _loadingStartTime = CFAbsoluteTimeGetCurrent();
        [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/users/(%d)", _uid] options:nil watcher:self];
    }
    
    [_tableView reloadData];
}

- (void)doUnloadView
{
    _tableView.delegate = nil;
    _tableView.dataSource = nil;
    _tableView = nil;
    [_imageCache clearCache:TGCacheMemory];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)viewDidUnload
{
    [self doUnloadView];
    
    [super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

- (BOOL)shouldAutorotate
{
    return true;
}

#pragma mark - Interface

- (void)performCloseTimeline
{
    if (_uploadingPhotoInternalUrls.count != 0)
    {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:nil message:NSLocalizedString(@"Timeline.InterruptUpload", @"") delegate:self cancelButtonTitle:NSLocalizedString(@"Common.Yes", @"") otherButtonTitles:NSLocalizedString(@"Common.No", @""), nil];
        alertView.tag = 10001;
        [alertView show];
    }
    else
        [self.navigationController popViewControllerAnimated:true];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (alertView.tag == 10001)
    {
        if (buttonIndex == alertView.cancelButtonIndex)
        {
            [self.navigationController popViewControllerAnimated:true];
        }
    }
}

- (void)loadMoreItems
{
    if (!_canLoadMore)
        return;
    
    _loadingTimeline = true;
    
    int64_t minItemId = 0;
    if (_listModel.count != 0)
        minItemId = ((TGTimelineItem *)[_listModel lastObject]).itemId;
    
    [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/timeline/(%d)/items/(%d)", _uid, 0] options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:_uid], @"timelineId", [NSNumber numberWithLongLong:minItemId], @"minItemId", nil] watcher:self];
}

#pragma mark - Data

- (NSInteger)tableView:(UITableView *)__unused tableView numberOfRowsInSection:(NSInteger)__unused section
{
    return _listModel.count;
}

- (CGFloat)tableView:(UITableView *)__unused tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row >= (int)_listModel.count)
        return 50;
    return [TGTimelineCell timelineItemSize:[_listModel objectAtIndex:indexPath.row]].height;
}

static void updateCellLocation(TGTimelineCell *timelineCell, TGTimelineItem *timelineItem)
{
    if (timelineItem.hasLocation)
    {
        NSDictionary *locationComponents = timelineItem.locationComponents;
        if (locationComponents != nil)
        {
            NSString *country = [locationComponents objectForKey:@"country"];
            NSString *state = [locationComponents objectForKey:@"state"];
            NSString *city = [locationComponents objectForKey:@"city"];
            NSString *district = [locationComponents objectForKey:@"district"];
            
            if (state != nil || city != nil)
            {
                if (state != nil && city != nil && ![state isEqualToString:city])
                {
                    timelineCell.locationName = [[NSString alloc] initWithFormat:@"%@, %@", city, state];
                }
                else if (city != nil)
                {
                    timelineCell.locationName = city;
                }
                else
                    timelineCell.locationName = state;
            }
            else if (country != nil)
                timelineCell.locationName = country;
            else if (district != nil)
                timelineCell.locationName = district;
        }
        else
            timelineCell.locationName = nil;
        
        timelineCell.locationLatitude = timelineItem.locationLatitude;
        timelineCell.locationLongitude = timelineItem.locationLongitude;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    TGTimelineItem *timelineItem = nil;
    if (indexPath.row < (int)_listModel.count)
        timelineItem = [_listModel objectAtIndex:indexPath.row];
    
    if (timelineItem != nil)
    {
        static NSString *timelineCellIdentifier = @"TimelineCell";
        
        NSString *currentCellIdentifier = timelineCellIdentifier;
        
        TGTimelineCell *timelineCell = (TGTimelineCell *)[tableView dequeueReusableCellWithIdentifier:currentCellIdentifier];
        if (timelineCell == nil)
        {
            timelineCell = [[TGTimelineCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:currentCellIdentifier];
            timelineCell.imageCache = _imageCache;
        }
        
        timelineCell.date = timelineItem.date;
        
        timelineCell.uploading = timelineItem.uploading;
        
        if (timelineItem.hasLocation)
        {
            NSDictionary *locationComponents = timelineItem.locationComponents;
            if (locationComponents != nil)
            {
                updateCellLocation(timelineCell, timelineItem);
            }
            else
            {
                [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/location/reversecode/(%f,%f)", timelineItem.locationLatitude, timelineItem.locationLongitude] options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithDouble:timelineItem.locationLatitude], @"latitude", [NSNumber numberWithDouble:timelineItem.locationLongitude], @"longitude", nil] watcher:self];
            }
            
            timelineCell.locationLatitude = timelineItem.locationLatitude;
            timelineCell.locationLongitude = timelineItem.locationLongitude;
        }
        else
        {
            timelineCell.locationName = nil;
            timelineCell.locationLatitude = 0.0;
            timelineCell.locationLongitude = 0.0;
        }
        
        timelineCell.showActions = _type == TGTimelineTypeCurrentUser;
        timelineCell.actionHandler = self.actionHandle;
        timelineCell.actionDelete = @"/tg/timeline/deleteItem";
        timelineCell.actionAction = @"/tg/timeline/setItemAsProfilePhoto";
        timelineCell.actionPanelAppeared = @"/tg/timeline/scrollToItem";
        timelineCell.actionTag = [NSNumber numberWithLongLong:timelineItem.itemId];
   
        CGSize imageSize = CGSizeZero;
        float scale = TGIsRetina() ? 2.0f : 1.0f;
        timelineCell.imageUrl = [timelineItem.imageInfo closestImageUrlWithWidth:(300 * scale) resultingSize:&imageSize];
        imageSize = TGFitSize(imageSize, CGSizeMake((int)(300 * scale), FLT_MAX));
        
        imageSize.width /= scale;
        imageSize.height /= scale;
        timelineCell.imageSize = imageSize;
        
        [timelineCell resetView];
        
        return timelineCell;
    }
    
    static NSString *loadingCellIdentifier = @"LoadingCell";
    UITableViewCell *loadingCell = [tableView dequeueReusableCellWithIdentifier:loadingCellIdentifier];
    if (loadingCell == nil)
    {
        loadingCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:loadingCellIdentifier];
        loadingCell.backgroundView = [[UIView alloc] init];
        loadingCell.backgroundView.backgroundColor = [UIColor whiteColor];
        loadingCell.selectionStyle = UITableViewCellSelectionStyleNone;

        UIActivityIndicatorView *activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        activityIndicator.tag = 100;
        activityIndicator.frame = CGRectMake((int)((loadingCell.frame.size.width - activityIndicator.frame.size.width) / 2), (int)((loadingCell.frame.size.height - activityIndicator.frame.size.height) / 2), activityIndicator.frame.size.width, activityIndicator.frame.size.height);
        activityIndicator.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
        [loadingCell addSubview:activityIndicator];
    }
    
    [(UIActivityIndicatorView *)[loadingCell viewWithTag:100] startAnimating];

    return loadingCell;
}

#pragma mark — Interface internal

- (void)tableView:(UITableView *)__unused tableView willDisplayCell:(UITableViewCell *)__unused cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSArray *array = _tableView.indexPathsForVisibleRows;
    if (array.count != 0 && _listModel.count != 0)
    {
        int minIndex = MAX(0, [(NSIndexPath *)[array objectAtIndex:0] row] - 1);
        int maxIndex = MIN((int)_listModel.count - 1, [(NSIndexPath *)[array lastObject] row] + 1);
        int targetMinIndex = MAX(0, minIndex - 1);
        int targetMaxIndex = MIN((int)_listModel.count - 1, maxIndex + 1);
        
        bool forward = true;
        if (indexPath.row < _lastDisplayIndex)
        {
            forward = false;
        }
        
        float scale = TGIsRetina() ? 2.0f : 1.0f;
        
        NSMutableArray *newObjects = [[NSMutableArray alloc] initWithCapacity:2];
        
        if (!forward && minIndex > 0)
        {
            for (int i = minIndex; i >= targetMinIndex; i--)
            {
                TGTimelineItem *item = [_listModel objectAtIndex:i];
                //TGLog(@"request at %d", i);
                
                CGSize imageSize = CGSizeZero;
                NSString *url = [NSString stringWithFormat:@"%@", [item.imageInfo closestImageUrlWithWidth:(int)(300 * scale) resultingSize:&imageSize]];
                imageSize = TGFitSize(imageSize, CGSizeMake((int)(300 * scale), FLT_MAX));
                imageSize.width /= scale;
                imageSize.height /= scale;
                
                NSString *path = [TGRemoteImageView preloadImage:url filter:[NSString stringWithFormat:@"scale:%dx%d", (int)imageSize.width, (int)imageSize.height] cache:_imageCache allowThumbnailCache:true watcher:self];
                if (path != nil)
                    [newObjects addObject:path];
            }
        }
        if (forward && maxIndex < (int)_listModel.count - 1)
        {
            for (int i = maxIndex; i <= targetMaxIndex; i++)
            {
                TGTimelineItem *item = [_listModel objectAtIndex:i];
                //TGLog(@"request at %d", i);
                
                CGSize imageSize = CGSizeZero;
                NSString *url = [NSString stringWithFormat:@"%@", [item.imageInfo closestImageUrlWithWidth:(int)(300 * scale) resultingSize:&imageSize]];
                imageSize = TGFitSize(imageSize, CGSizeMake((int)(300 * scale), FLT_MAX));
                imageSize.width /= scale;
                imageSize.height /= scale;
                
                NSString *path = [TGRemoteImageView preloadImage:url filter:[NSString stringWithFormat:@"scale:%dx%d", (int)imageSize.width, (int)imageSize.height] cache:_imageCache allowThumbnailCache:true watcher:self];
                if (path != nil)
                    [newObjects addObject:path];
            }
        }
        
        for (NSString *path in _preloadingIndices)
        {
            if (![newObjects containsObject:path])
            {
                [ActionStageInstance() removeWatcher:self fromPath:path];
            }
        }
        
        [_preloadingIndices removeAllObjects];
        [_preloadingIndices addObjectsFromArray:newObjects];
    }
    
    _lastDisplayIndex = indexPath.row;
    if (_lastDisplayIndex >= (int)_listModel.count - 5 && _canLoadMore && !_loadingTimeline)
    {
        [self loadMoreItems];
    }
}

#pragma mark - Graph

- (void)actorCompleted:(int)resultCode path:(NSString *)path result:(id)result
{
    if ([path isEqualToString:[NSString stringWithFormat:@"/tg/users/(%d)", _uid]])
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            if (resultCode == ASStatusSuccess)
            {
                _user = ((TGUserNode *)result).user;
                _loadingTimeline = true;
            }
        });
        
        [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/timeline/(%d)/items/(%d)", _uid, 0] options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:_uid], @"timelineId", [NSNumber numberWithLongLong:0], @"minItemId", nil] watcher:self];
    }
    else if ([path hasPrefix:[NSString stringWithFormat:@"/tg/timeline/(%d)/items/(", _uid]])
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            if (resultCode == ASStatusSuccess)
            {
                SGraphListNode *listNode = (SGraphListNode *)result;
                
                NSArray *newItems = [listNode.items sortedArrayUsingComparator:^NSComparisonResult(TGTimelineItem *item1, TGTimelineItem *item2)
                {
                    int64_t itemId1 = item1.itemId;
                    int64_t itemId2 = item2.itemId;
                    
                    if (itemId1 < itemId2)
                        return NSOrderedDescending;
                    return NSOrderedAscending;
                }];
                
                std::set<int64_t> existingItems;
                for (TGTimelineItem *item in _listModel)
                {
                    existingItems.insert(item.itemId);
                }
                
                for (TGTimelineItem *item in newItems)
                {
                    if (existingItems.find(item.itemId) == existingItems.end())
                    {
                        [_listModel addObject:item];
                    }
                }
                
                if (existingItems.empty())
                {
                    _tableView.alpha = 0.0f;
                    [UIView animateWithDuration:0.3 animations:^
                    {
                        _tableView.alpha = 1.0f;
                    }];
                }
                
                [_tableView reloadData];
                
                _canLoadMore = newItems.count != 0;
            }
            else
            {
                _canLoadMore = false;
            }
            
            _loadingTimeline = false;
        });
    }
    else if ([path hasPrefix:@"/tg/location/reversecode/"])
    {
        if (resultCode == ASStatusSuccess)
        {
            NSDictionary *dict = ((SGraphObjectNode *)result).object;
            double locationLatitude = [[dict objectForKey:@"latitude"] doubleValue];
            double locationLongitude = [[dict objectForKey:@"longitude"] doubleValue];
            NSDictionary *components = [dict objectForKey:@"components"];
            
            dispatch_async(dispatch_get_main_queue(), ^
            {
                Class TGTimelineCellClass = [TGTimelineCell class];
                
                for (TGTimelineItem *item in _listModel)
                {
                    if (item.hasLocation && ABS(item.locationLatitude - locationLatitude) < DBL_EPSILON && ABS(item.locationLongitude - locationLongitude) < DBL_EPSILON)
                    {
                        item.locationComponents = components;
                        
                        for (UITableViewCell *cell in [_tableView visibleCells])
                        {
                            if ([cell isKindOfClass:TGTimelineCellClass])
                            {
                                TGTimelineCell *timelineCell = (TGTimelineCell *)cell;
                                
                                if (ABS(timelineCell.locationLatitude - locationLatitude) < DBL_EPSILON && ABS(timelineCell.locationLongitude - locationLongitude) < DBL_EPSILON)
                                {
                                    updateCellLocation(timelineCell, item);
                                    [timelineCell resetLocation];
                                    [timelineCell setNeedsLayout];
                                }
                            }
                        }
                    }
                }
            });
        }
    }
    else if ([path isEqualToString:_currentApplyPhotoAction])
    {
        _currentApplyPhotoAction = nil;
        
        dispatch_async(dispatch_get_main_queue(), ^
        {
            for (TGTimelineItem *item in _listModel)
            {
                item.uploading = false;
            }
            
            for (UITableViewCell *cell in [_tableView visibleCells])
            {
                if ([cell isKindOfClass:[TGTimelineCell class]])
                {
                    TGTimelineCell *timelineCell = (TGTimelineCell *)cell;
                    if (timelineCell.showingActions)
                        [timelineCell toggleShowActions];
                    
                    if (timelineCell.uploading)
                    {
                        [timelineCell setProgress:1.0f];
                        timelineCell.uploading = false;
                    }
                }
            }
        });
    }
    else
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            if ([_preloadingIndices containsObject:path])
                [_preloadingIndices removeObject:path];
        });
    }
}

- (void)actionStageResourceDispatched:(NSString *)path resource:(id)resource arguments:(id)__unused arguments
{
    if ([path isEqualToString:[NSString stringWithFormat:@"/tg/timeline/(%d)/items", _uid]])
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            TGTimelineItem *newItem = ((SGraphObjectNode *)resource).object;
            
            bool found = false;
            for (TGTimelineItem *item in _listModel)
            {
                if (item.itemId == newItem.itemId)
                {
                    found = true;
                    break;
                }
            }
            
            if (!found)
            {
                [_listModel insertObject:newItem atIndex:0];
                [_tableView beginUpdates];
                [_tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:0 inSection:0]] withRowAnimation:UITableViewRowAnimationFade];
                [_tableView endUpdates];
            }
        });
    }
}

- (void)actionStageActionRequested:(NSString *)action options:(NSDictionary *)options
{
    if ([action isEqualToString:@"/tg/timeline/collapseItemsExceptOne"])
    {
        NSNumber *nItemId = [options objectForKey:@"actionTag"];
        
        dispatch_async(dispatch_get_main_queue(), ^
        {
            for (UITableViewCell *cell in [_tableView visibleCells])
            {
                if ([cell isKindOfClass:[TGTimelineCell class]])
                {
                    TGTimelineCell *timelineCell = (TGTimelineCell *)cell;
                    if (![timelineCell.actionTag isEqual:nItemId] && timelineCell.showingActions)
                    {
                        [timelineCell toggleShowActions];
                    }
                }
            }
        });
    }
    else if ([action isEqualToString:@"/tg/timeline/scrollToItem"])
    {
        int64_t itemId = [[options objectForKey:@"actionTag"] longLongValue];
        
        dispatch_async(dispatch_get_main_queue(), ^
        {
            bool found = false;
            int index = -1;
            for (TGTimelineItem *item in _listModel)
            {
                index++;
                if (item.itemId == itemId)
                {
                    found = true;
                    break;
                }
            }

            if (found)
            {
                CGRect originalRect = [_tableView rectForRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]];
                CGRect viewRect = [self.view convertRect:originalRect fromView:_tableView];
                
                if (viewRect.size.height > self.view.frame.size.height)
                {
                    viewRect.origin.y += viewRect.size.height - self.view.frame.size.height;
                    viewRect.size.height = self.view.frame.size.height;
                }
                else
                {
                    viewRect.size.height += 10;
                }
                
                if (viewRect.origin.y + viewRect.size.height > self.view.frame.size.height - 10 || viewRect.origin.y < 10)
                {
                    [_tableView scrollRectToVisible:[self.view convertRect:viewRect toView:_tableView] animated:true];
                }
            }
        });
    }
    else if ([action isEqualToString:@"/tg/timeline/deleteItem"])
    {
        int64_t itemId = [[options objectForKey:@"actionTag"] longLongValue];
        
        dispatch_async(dispatch_get_main_queue(), ^
        {
            bool found = false;
            int index = -1;
            for (TGTimelineItem *item in _listModel)
            {
                index++;
                if (item.itemId == itemId)
                {
                    found = true;
                    break;
                }
            }
            
            if (found)
            {
                [_listModel removeObjectAtIndex:index];
                [_tableView beginUpdates];
                [_tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:index inSection:0]] withRowAnimation:UITableViewRowAnimationFade];
                [_tableView endUpdates];
                
                [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/timeline/(%d)/removeItems/(%lld)", _uid, itemId] options:[NSDictionary dictionaryWithObject:[NSArray arrayWithObject:[NSNumber numberWithLongLong:itemId]] forKey:@"items"] watcher:self];
            }
        });
    }
    else if ([action isEqualToString:@"/tg/timeline/setItemAsProfilePhoto"])
    {
        int64_t itemId = [[options objectForKey:@"actionTag"] longLongValue];
        
        dispatch_async(dispatch_get_main_queue(), ^
        {
            bool found = false;
            for (TGTimelineItem *item in _listModel)
            {
                if (item.itemId == itemId)
                {
                    item.uploading = true;
                    
                    found = true;
                }
            }
            
            if (found)
            {
                for (TGTimelineItem *item in _listModel)
                {
                    if (item.itemId != itemId)
                    {
                        item.uploading = false;
                    }
                }
                
                for (UITableViewCell *cell in [_tableView visibleCells])
                {
                    if ([cell isKindOfClass:[TGTimelineCell class]])
                    {
                        TGTimelineCell *timelineCell = (TGTimelineCell *)cell;
                        if (timelineCell.showingActions)
                            [timelineCell toggleShowActions];
                        
                        if ([((NSNumber *)timelineCell.actionTag) longLongValue] == itemId)
                        {
                            if (!timelineCell.uploading)
                            {
                                timelineCell.uploading = true;
                                [timelineCell resetView];
                                [timelineCell fadeInProgress];
                            }
                        }
                        else if (timelineCell.uploading)
                        {
                            [timelineCell fadeOutProgress];
                            timelineCell.uploading = false;
                        }
                    }
                }
            }
        });
        
        
        if (_currentApplyPhotoAction != nil)
            [ActionStageInstance() removeWatcher:self fromPath:_currentApplyPhotoAction];
        _currentApplyPhotoAction = [NSString stringWithFormat:@"/tg/timeline/(%d)/assignProfilePhoto/(%lld)", _uid, itemId];
        [ActionStageInstance() requestActor:_currentApplyPhotoAction options:nil watcher:self];
    }
    else if ([action isEqualToString:@"openMap"])
    {
        double latitude = [[options objectForKey:@"latitude"] doubleValue];
        double longitude = [[options objectForKey:@"longitude"] doubleValue];
        //TGMapViewController *mapViewController = [[TGMapViewController alloc] initInMapModeWithLatitude:latitude longitude:longitude];
        //[self.navigationController pushViewController:mapViewController animated:true];
    }
}

@end
*/