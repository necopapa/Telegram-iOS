#import "TGHighlightableButton.h"

@implementation TGHighlightableButton

@synthesize reverseTitleShadow = _reverseTitleShadow;
@synthesize normalTitleShadowOffset = _normalTitleShadowOffset;

- (void)setHighlighted:(BOOL)highlighted
{
    for (UIView *view in self.subviews)
    {
        if ([view isKindOfClass:[UILabel class]])
            [(UILabel *)view setHighlighted:highlighted];
        else if ([view isKindOfClass:[UIImageView class]])
            [(UIImageView *)view setHighlighted:highlighted];
    }
    
    if (_reverseTitleShadow)
        self.titleLabel.shadowOffset = highlighted ? CGSizeMake(-_normalTitleShadowOffset.width, -_normalTitleShadowOffset.height) : _normalTitleShadowOffset;
    
    [super setHighlighted:highlighted];
}

@end