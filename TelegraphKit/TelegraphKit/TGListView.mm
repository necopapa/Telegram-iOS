#import "TGListView.h"

#import "TGViewRecycler.h"

#import <vector>

/*@interface TGListItem : NSObject

@property (nonatomic) int position;
@property (nonatomic) int height;

@end

@implementation TGListItem

@synthesize position = _position;
@synthesize height = _height;

@end*/

namespace TGListViewNamespace
{

struct ListItem
{
    int position;
    int height;

    ListItem(int position_, int height_) :
        position(position_), height(height_)
    {
    }
};

}

using namespace TGListViewNamespace;

@interface TGListView ()
{
    std::vector<std::vector<ListItem> > vSections;
}

@property (nonatomic, strong) TGViewRecycler *viewRecycler;

@property (nonatomic, strong) NSMutableArray *sections;

@property (nonatomic, strong) NSMutableArray *visibleItemViews;

@end

@implementation TGListView

@synthesize dataSource = _dataSource;

@synthesize stackFromBottom = _stackFromBottom;

@synthesize headerView = _headerView;

@synthesize viewRecycler = _viewRecycler;

@synthesize sections = _sections1;

@synthesize visibleItemViews = _visibleItemViews;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {   
        _viewRecycler = [[TGViewRecycler alloc] init];
        
        //_sections = [[NSMutableArray alloc] init];
        
        _visibleItemViews = [[NSMutableArray alloc] init];
        
        self.bounces = true;
        self.alwaysBounceVertical = true;
    }
    return self;
}

- (void)dealloc
{   
    self.delegate = nil;
}

- (void)setDelegate:(id<UIScrollViewDelegate>)delegate
{
    //if (_passthroughDelegate)
        [super setDelegate:delegate];
    //else _scrollViewDelegate = delegate;
}

- (void)setStackFromBottom:(bool)stackFromBottom
{
    if (_stackFromBottom != stackFromBottom)
    {
        _stackFromBottom = stackFromBottom;
        CGAffineTransform transform = stackFromBottom ? CGAffineTransformMakeRotation((float)M_PI) : CGAffineTransformIdentity;
        self.transform = transform;
        if (_headerView != nil)
            _headerView.transform = transform;
    }
}

- (void)setHeaderView:(UIView *)headerView
{
    if (_headerView != nil)
        [_headerView removeFromSuperview];
    _headerView = headerView;
    if (headerView != nil)
    {
        [self insertSubview:headerView atIndex:0];
        headerView.transform = _stackFromBottom ? CGAffineTransformMakeRotation((float)M_PI) : CGAffineTransformIdentity;
    }
}

- (TGListItemView *)dequeueListItemViewWithIdentifier:(NSString *)identifier
{
    return (TGListItemView *)[_viewRecycler dequeueReusableViewWithIdentifier:identifier];
}

- (void)reloadData
{
    //[_sections removeAllObjects];
    
    vSections.clear();
    
    int contentHeight = 0;
    
    if (_dataSource != nil)
    {
        int numSections = [_dataSource numberOfSectionsInListView:self];
        for (int i = 0; i < numSections; i++)
        {
            //NSMutableArray *sectionArray = [[NSMutableArray alloc] init];
            std::vector<ListItem> sectionArray;
            int numRows = [_dataSource listView:self numberOfRowsInSection:i];
            for (int j = 0; j < numRows; j++)
            {
                /*TGListItem *listItem = [[TGListItem alloc] init];
                listItem.position = contentHeight;
                listItem.height = [_dataSource listView:self heightForItemAtIndex:j section:i];
                [sectionArray addObject:listItem];
                contentHeight += listItem.height;*/
                
                ListItem item(contentHeight, [_dataSource listView:self heightForItemAtIndex:j section:i]);
                sectionArray.push_back(item);
                
                contentHeight += item.height;
            }
            //[_sections addObject:sectionArray];
            vSections.push_back(sectionArray);
        }
    }
    
    self.contentSize = CGSizeMake(self.frame.size.width, contentHeight);
    
    [self discardVisibleItems];
    
    [self setNeedsLayout];
}

- (void)insertItemsAtIndices:(NSArray *)indices animated:(bool)__unused animated
{
    int newCount = indices.count;
    if (!vSections.empty())
        newCount += vSections[0].size();
    
    if (_dataSource != nil)
    {
        int modelCount = [_dataSource listView:self numberOfRowsInSection:0];
        if (modelCount != newCount)
        {
            TGLog(@"%s:%d: error: inconsistent table state", __PRETTY_FUNCTION__, __LINE__);
            [self reloadData];
        }
    }
}

- (void)removeItemsAtIndices:(NSArray *)__unused indices animated:(bool)__unused animated
{
    
}

- (void)discardVisibleItems
{
    for (TGListItemView *itemView in _visibleItemViews)
    {
        [itemView removeFromSuperview];
        [_viewRecycler recycleView:itemView];
    }
    
    [_visibleItemViews removeAllObjects];
}

- (void)updateVisibleItems
{    
    int startOffset =(int)(MAX(0, self.contentOffset.y - self.frame.size.height / 2));
    int endOffset = (int)(MIN(self.contentSize.height, startOffset + self.frame.size.height + self.frame.size.height / 2));
    
    int minVisibleY = INT_MAX;
    int maxVisibleY = 0;
    
    for (int i = 0; i < _visibleItemViews.count; i++)
    {
        TGListItemView *itemView = [_visibleItemViews objectAtIndex:i];
        CGRect itemFrame = itemView.frame;
        if (itemFrame.origin.y + itemFrame.size.height < startOffset || itemFrame.origin.y > endOffset)
        {
            [_visibleItemViews removeObjectAtIndex:i];
            i--;
            [itemView removeFromSuperview];
            [_viewRecycler recycleView:itemView];
        }
        else
        {
            minVisibleY = (int)(MIN(minVisibleY, itemView.frame.origin.y));
            maxVisibleY = (int)(MAX(maxVisibleY, itemView.frame.origin.y + itemView.frame.size.height));
        }
    }
    
    if (_visibleItemViews.count != 0)
    {
        if (minVisibleY <= startOffset && maxVisibleY >= endOffset)
        {
            return;
        }
    }
    
    bool modifiedVisibleItems = false;
    
    if (_visibleItemViews.count != 0)
    {
        TGListItemView *firstItemView = [_visibleItemViews objectAtIndex:0];
        TGListItemView *lastItemView = [_visibleItemViews lastObject];
        
        bool doneBackwards = false;
        int backwardsRowY = (int)firstItemView.frame.origin.y;
        for (int i = firstItemView.section; i >= 0; i--)
        {
            //NSMutableArray *items = [_sections objectAtIndex:i];
            std::vector<ListItem> &items = vSections[0];
            for (int j = firstItemView.index - 1; j >= 0; j--)
            {
                //TGListItem *item = [items objectAtIndex:j];
                ListItem &item = items[j];
                if (backwardsRowY < startOffset)
                {
                    doneBackwards = true;
                    break;
                }
                
                if (_dataSource != nil)
                {
                    TGListItemView *itemView = [_dataSource listView:self itemViewAtIndex:j section:i];
                    if (_stackFromBottom)
                        itemView.transform = CGAffineTransformMakeRotation(M_PI);
                    itemView.index = j;
                    itemView.section = i;
                    itemView.frame = CGRectMake(0, backwardsRowY - item.height, self.frame.size.width, item.height);
                    [self insertSubview:itemView atIndex:0];
                    if (itemView.backgroundRendering)
                        [itemView beginBackgroundRendering];
                    [_visibleItemViews addObject:itemView];
                    modifiedVisibleItems = true;
                }
                backwardsRowY -= item.height;
            }
            
            if (doneBackwards)
                break;
        }
        
        bool doneForward = false;
        int forwardRowY = (int)(lastItemView.frame.origin.y + lastItemView.frame.size.height);
        //int numSections = _sections.count;
        int numSections = vSections.size();
        for (int i = lastItemView.section; i < numSections; i++)
        {
            //NSMutableArray *items = [_sections objectAtIndex:i];
            std::vector<ListItem> &items = vSections[i];
            int numItems = items.size();
            for (int j = lastItemView.index + 1; j < numItems; j++)
            {
                //TGListItem *item = [items objectAtIndex:j];
                ListItem &item = items[j];
                if (forwardRowY >= endOffset)
                {
                    doneForward = true;
                    break;
                }
                
                if (_dataSource != nil)
                {
                    TGListItemView *itemView = [_dataSource listView:self itemViewAtIndex:j section:i];
                    if (_stackFromBottom)
                        itemView.transform = CGAffineTransformMakeRotation(M_PI);
                    itemView.index = j;
                    itemView.section = i;
                    itemView.frame = CGRectMake(0, forwardRowY, self.frame.size.width, item.height);
                    [self insertSubview:itemView atIndex:0];
                    if (itemView.backgroundRendering)
                        [itemView beginBackgroundRendering];
                    [_visibleItemViews addObject:itemView];
                    modifiedVisibleItems = true;
                }
                forwardRowY += item.height;
            }
            
            if (doneForward)
                break;
        }
    }
    else
    {
        int currentRowY = 0;
        //int numSections = _sections.count;
        int numSections = vSections.size();
        for (int i = 0; i < numSections; i++)
        {
            //NSMutableArray *items = [_sections objectAtIndex:i];
            std::vector<ListItem> &items = vSections[i];
            //int numItems = items.count;
            int numItems = items.size();
            for (int j = 0; j < numItems; j++)
            {
                //TGListItem *item = [items objectAtIndex:j];
                ListItem &item = items[j];
                
                if (currentRowY + item.height >= startOffset && currentRowY < endOffset)
                {
                    bool found = false;
                    for (TGListItemView *visibleItem in _visibleItemViews)
                    {
                        if (visibleItem.index == j && visibleItem.section == i)
                        {
                            found = true;
                            break;
                        }
                    }
                    if (!found)
                    {
                        if (_dataSource != nil)
                        {
                            TGListItemView *itemView = [_dataSource listView:self itemViewAtIndex:j section:i];
                            if (_stackFromBottom)
                                itemView.transform = CGAffineTransformMakeRotation(M_PI);
                            itemView.index = j;
                            itemView.section = i;
                            itemView.frame = CGRectMake(0, currentRowY, self.frame.size.width, item.height);
                            [self insertSubview:itemView atIndex:0];
                            if (itemView.backgroundRendering)
                                [itemView beginBackgroundRendering];
                            [_visibleItemViews addObject:itemView];
                            modifiedVisibleItems = true;
                        }
                    }
                }
                else if (currentRowY >= endOffset)
                    break;
                
                currentRowY += item.height;
            }
        }
    }
    
    if (modifiedVisibleItems)
    {
        [_visibleItemViews sortUsingComparator:^NSComparisonResult(id obj1, id obj2)
        {
            TGListItemView *itemView1 = obj1;
            TGListItemView *itemView2 = obj2;
            if (itemView1.section < itemView2.section)
                return NSOrderedAscending;
            else if (itemView1.section > itemView2.section)
                return NSOrderedDescending;
            else
            {
                if (itemView1.index < itemView2.index)
                    return NSOrderedAscending;
                else if (itemView1.index > itemView2.index)
                    return NSOrderedDescending;
                else
                {
                    TGLog(@"Warning: list items with same indices found");
                    return NSOrderedSame;
                }
            }
        }];
    }
    
    /*for (TGListItemView *itemView in _visibleItemViews)
    {
        TGLog(@"index: %d", itemView.index);
    }*/
    
    //TGLog(@"updateVisibleItems: %d ms", (int)([[NSDate date] timeIntervalSince1970] - methodStartDate));
    
    //TGLog(@"visible items: %d, subviews: %d", _visibleItemViews.count, self.subviews.count);
}

- (void)layoutSubviews
{
    if (_stackFromBottom)
    {
        self.scrollIndicatorInsets = UIEdgeInsetsMake(0, 0, 0, self.frame.size.width - 9);
    }
    
    [self updateVisibleItems];
    
    [super layoutSubviews];
}

- (void)setFrame:(CGRect)frame
{   
    if (frame.size.width != self.frame.size.width)
    {
        self.contentSize = CGSizeMake(frame.size.width, self.contentSize.height);
        
        [UIView setAnimationsEnabled:false];
        [self updateVisibleItems];
        for (TGListItemView *itemView in _visibleItemViews)
        {
            [itemView setNeedsLayout];
            [itemView layoutIfNeeded];
        }
        [UIView setAnimationsEnabled:true];
    }
    
    [super setFrame:frame];
}

@end
