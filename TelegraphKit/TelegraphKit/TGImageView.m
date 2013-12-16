#import "TGImageView.h"

@implementation TGImageView

@synthesize reuseIdentifier = _reuseIdentifier;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        _reuseIdentifier = @"ImageView";
    }
    return self;
}

- (void)prepareForRecycle:(TGViewRecycler *)__unused recycler
{
    self.image = nil;
}

- (void)prepareForReuse
{
    self.image = nil;
}

@end
