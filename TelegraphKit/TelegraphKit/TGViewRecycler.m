#import "TGViewRecycler.h"

@interface TGViewRecycler ()

@property (nonatomic, strong) NSMutableDictionary *reusableViews;

@end

@implementation TGViewRecycler

- (id)init
{
    self = [super init];
    if (self != nil)
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveMemoryWarning) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
        });
        
        self.reusableViews = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)didReceiveMemoryWarning
{
    [self removeAllViews];
}

- (UIView<TGReusableView> *)dequeueReusableViewWithIdentifier:(NSString *)reuseIdentifier
{
    NSMutableArray *views = [_reusableViews objectForKey:reuseIdentifier];
    if (views == nil)
        return nil;
    
    UIView<TGReusableView> *view = [views lastObject];
    if (nil != view)
    {
        [views removeLastObject];
        [view prepareForReuse];
    }
    return view;
}

- (void)recycleView:(UIView<TGReusableView> *)view
{
    NSString *reuseIdentifier = [view reuseIdentifier];
    
    if (reuseIdentifier == nil)
    {
        TGLog(@"Warning: reuse identifier not specified");
        reuseIdentifier = NSStringFromClass([view class]);
    }
    
    [view prepareForRecycle:self];
    
    if (reuseIdentifier == nil)
        return;
    
    NSMutableArray* views = [_reusableViews objectForKey:reuseIdentifier];
    if (views == nil)
    {
        views = [[NSMutableArray alloc] init];
        [_reusableViews setObject:views forKey:reuseIdentifier];
    }
    [views addObject:view];
}

- (int)recycledCount:(NSString *)identifier
{
    NSMutableArray *views = [_reusableViews objectForKey:identifier];
    return views.count;
}

- (void)removeAllViews
{
    [_reusableViews removeAllObjects];
}

@end
