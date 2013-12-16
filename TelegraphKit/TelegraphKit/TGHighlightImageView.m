#import "TGHighlightImageView.h"

@implementation TGHighlightImageView

@synthesize targetView = _targetView;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
    }
    return self;
}

- (void)setHidden:(BOOL)hidden
{
    if (_targetView != nil)
        [_targetView setHidden:hidden];
    [super setHidden:hidden];
}

- (void)setAlpha:(CGFloat)alpha
{
    if (_targetView != nil)
        [_targetView setAlpha:alpha];
    [super setAlpha:alpha];
}

@end
