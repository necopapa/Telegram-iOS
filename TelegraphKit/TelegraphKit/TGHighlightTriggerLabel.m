#import "TGHighlightTriggerLabel.h"

@implementation TGHighlightTriggerLabel

@synthesize targetViews = _targetViews;
@synthesize advanced = _advanced;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
    }
    return self;
}

- (void)setHighlighted:(BOOL)highlighted
{
    if (_targetViews != nil)
    {
        for (id<TGHighlightable> target in _targetViews)
        {
            if (_advanced)
                [(id<TGAdvancedHighlightable>)target advancedSetHighlighted:highlighted];
            else
                [target setHighlighted:highlighted];
        }
    }
}

@end
