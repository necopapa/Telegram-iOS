#import "TGReusableView.h"

@implementation TGReusableView

@synthesize reuseIdentifier = _reuseIdentifier;

- (void)prepareForReuse
{
}

- (void)prepareForRecycle:(TGViewRecycler *)__unused recycler
{
}

@end