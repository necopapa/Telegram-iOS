#import "TGReusableActivityIndicatorView.h"

@implementation TGReusableActivityIndicatorView

- (void)prepareForReuse
{
}

- (void)prepareForRecycle:(TGViewRecycler *)__unused recycler
{
    if (self.isAnimating)
        [self stopAnimating];
}

@end
