#import "TGPagerView.h"

static UIImage *dotImage()
{
    static UIImage *image = nil;
    if (image == nil)
        image = [UIImage imageNamed:@"PagerDot.png"];
    return image;
}

@interface TGPagerView ()

@property (nonatomic, strong) UIImage *dotImage;

@property (nonatomic, strong) NSMutableArray *dotViews;

@end

@implementation TGPagerView

@synthesize dotSpacing = _dotSpacing;
@synthesize dotImage = _dotImage;

@synthesize dotViews = _dotViews;

- (id)init
{
    self = [super init];
    if (self != nil)
    {
        [self commonInit];
    }
    return self;
}

- (UIImage *)dotImage
{
    if (_dotImage == nil)
    {
        _dotImage = dotImage();
    }
    
    return _dotImage;
}

- (void)commonInit
{
    _dotViews = [[NSMutableArray alloc] init];
    _dotSpacing = 8;
}

- (void)setPagesCount:(int)count
{
    if (_dotViews.count != count)
    {
        bool resetPage = false;
        
        if (count < _dotViews.count)
        {
            for (int i = _dotViews.count - 1; i >= count; i--)
            {
                UIView *view = [_dotViews objectAtIndex:i];
                [view removeFromSuperview];
                [_dotViews removeObjectAtIndex:i];
            }
        }
        else if (count > _dotViews.count)
        {
            if (_dotViews.count == 0)
                resetPage = true;
            while (_dotViews.count < count)
            {
                UIImageView *view = [[UIImageView alloc] initWithImage:self.dotImage];
                [_dotViews addObject:view];
                [self addSubview:view];
            }
        }
        
        if (resetPage)
            [self setPage:0];
        
        [self setNeedsLayout];
    }
}

- (void)setPage:(float)page
{
    if (page < 0)
        page = 0;
    else if (page > _dotViews.count - 1)
        page = _dotViews.count - 1;
    
    int index = -1;
    for (UIView *view in _dotViews)
    {
        index++;
        
        float alpha = 0.0f;
        if (ABS(index - page) > 1)
            alpha = 0.0f;
        else
            alpha = 1.0f - (ABS((float)index - page));
        if (alpha < 0.3f)
            alpha = 0.3f;
        if (alpha > 1)
            alpha = 1;
        view.alpha = alpha;
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGSize dotSize = dotImage().size;
    
    float dotSpacing = _dotSpacing;
    float startX = (int)((self.frame.size.width - (dotSize.width * _dotViews.count + dotSpacing * (_dotViews.count - 1))) / 2);
    
    int index = -1;
    for (UIView *view in _dotViews)
    {
        index++;
        CGRect frame = view.frame;
        frame.origin = CGPointMake(startX + index * (dotSize.width + dotSpacing), 0);
        view.frame = frame;
    }
}

@end
