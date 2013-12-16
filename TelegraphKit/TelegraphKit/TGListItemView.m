#import "TGListItemView.h"

@implementation TGListItemView

@synthesize reuseIdentifier = _reuseIdentifier;

@synthesize index = _index;
@synthesize section = _section;

@synthesize editing = _editing;

@synthesize backgroundRendering = _backgroundRendering;

- (id)initWithFrame:(CGRect)frame reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithFrame:frame];
    if (self)
    {
        _reuseIdentifier = reuseIdentifier;
    }
    return self;
}

- (void)beginBackgroundRendering
{
}

- (void)prepareForRecycle:(TGViewRecycler *)__unused recycler
{
    
}

- (void)prepareForReuse
{
    [self setNeedsLayout];
}

@end
