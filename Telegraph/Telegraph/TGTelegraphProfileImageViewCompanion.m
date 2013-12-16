#import "TGTelegraphProfileImageViewCompanion.h"

#import "SGraph.h"
#import "SGraphListNode.h"

#import "TGImageViewController.h"

#import "TGAppDelegate.h"

@interface TGTelegraphProfileImageViewCompanion ()

@property (nonatomic) int uid;

@property (nonatomic) bool loadingFirstItems;

@property (nonatomic, strong) NSMutableArray *items;

@end

@implementation TGTelegraphProfileImageViewCompanion

@synthesize graphHandle = _graphHandle;

@synthesize imageViewController = _imageViewController;
@synthesize reverseOrder = _reverseOrder;

@synthesize loadingFirstItems = _loadingFirstItems;

@synthesize items = _items;

@synthesize uid = _uid;

- (id)initWithUid:(int)uid
{
    self = [super init];
    if (self != nil)
    {
        _graphHandle = [[SGraphHandle alloc] init];
        _graphHandle.delegate = self;
        
        _uid = uid;
        
        _loadingFirstItems = true;
        
        _items = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)dealloc
{
    _graphHandle.delegate = nil;
    
    [[SGraph instance] removeWatcher:self];
}

- (bool)manualSavingEnabled
{
    return true;
}

- (void)forceDismiss
{
    [TGAppDelegateInstance dismissContentController];
}

- (void)updateItems:(int64_t)currentItemId
{
    if (!_loadingFirstItems)
    {
    }
    else
    {
        [_imageViewController applyCurrentItem:0];
    }
}

- (void)loadMoreItems
{
    
}

- (void)preloadCount
{
    [_imageViewController loadingStatusChanged:true];
    
    int64_t minItemId = 0;
    if (_items.count != 0)
        minItemId = ((TGImageItem *)[_items lastObject]).itemId;
    
    [[SGraph instance] requestNode:[NSString stringWithFormat:@"/tg/timeline/(%d)/items/(%lld)", _uid, minItemId] options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:_uid], @"timelineId", [NSNumber numberWithLongLong:minItemId], @"minItemId", nil] watcher:self];
}

- (void)deleteItem:(int64_t)itemId
{
    
}

- (void)forwardItem:(int64_t)itemId
{
    
}

- (void)graphNodeRetrieveCompleted:(int)resultCode path:(NSString *)path node:(SGraphNode *)node
{
    if ([path hasPrefix:[NSString stringWithFormat:@"/tg/timeline/(%d)/items/(", _uid]])
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            if (resultCode == GraphRequestStatusSuccess)
            {
                SGraphListNode *listNode = (SGraphListNode *)node;
                
                NSArray *newItems = [listNode.items sortedArrayUsingComparator:^NSComparisonResult(TGTimelineItem *item1, TGTimelineItem *item2)
                {
                    int64_t itemId1 = item1.itemId;
                    int64_t itemId2 = item2.itemId;
                    
                    if (itemId1 < itemId2)
                        return NSOrderedDescending;
                    return NSOrderedAscending;
                }];
                
                std::set<int64_t> existingItems;
                for (TGImageItem *item in _items)
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
}

@end
