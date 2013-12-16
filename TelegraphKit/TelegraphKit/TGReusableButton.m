#import "TGReusableButton.h"

@implementation TGReusableButton

@synthesize reuseIdentifier = _reuseIdentifier;

- (NSString *)reuseIdentifier
{
    if (_reuseIdentifier == nil)
        return @"TGReusableButton";
    
    return _reuseIdentifier;
}

- (void)prepareForReuse
{
}

- (void)prepareForRecycle:(TGViewRecycler *)__unused recycler
{
}

@end
