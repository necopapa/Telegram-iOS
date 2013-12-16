#import "TGTextField.h"

#import "TGHighlightTriggerLabel.h"

@interface TGTextField () <TGAdvancedHighlightable>

@property (nonatomic) bool advancedHighlighted;

@end

@implementation TGTextField

@synthesize placeholderColor = _placeholderColor;
@synthesize normalPlaceholderColor = _normalPlaceholderColor;
@synthesize highlightedPlaceholderColor = _highlightedPlaceholderColor;
@synthesize placeholderFont = _placeholderFont;

@synthesize normalTextColor = _normalTextColor;
@synthesize highlightedTextColor = _highlightedTextColor;

@synthesize advancedHighlighted = _advancedHighlighted;

- (id)init
{
    self = [super init];
    if (self != nil)
    {
        
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        
    }
    return self;
}

- (void)didAddSubview:(UIView *)subview
{
    if ([subview isKindOfClass:[UIButton class]])
    {
        UIButton *clearButton = (UIButton *)subview;
        if ([clearButton imageForState:UIControlStateSelected] == nil)
            [clearButton setImage:[UIImage imageNamed:@"ClearInput_Inverted.png"] forState:UIControlStateSelected];
    }
    
    [super didAddSubview:subview];
}

- (void)drawPlaceholderInRect:(CGRect)rect
{
    if (_placeholderColor == nil || _placeholderFont == nil)
    {
        [super drawPlaceholderInRect:rect];
    }
    else
    {
        CGContextSetFillColorWithColor(UIGraphicsGetCurrentContext(), _placeholderColor.CGColor);
        [self.placeholder drawInRect:rect withFont:_placeholderFont];
    }
}

- (void)advancedSetHighlighted:(bool)highlighted
{
    if (_advancedHighlighted != highlighted)
    {
        _advancedHighlighted = highlighted;
        
        if (_normalTextColor != nil && _highlightedTextColor != nil)
        {
            self.textColor = highlighted ? _highlightedTextColor : _normalTextColor;
            if (_highlightedPlaceholderColor != nil && _normalPlaceholderColor != nil)
                self.placeholderColor = highlighted ? _highlightedPlaceholderColor : _normalPlaceholderColor;
            NSString *placeholder = self.placeholder;
            self.placeholder = nil;
            self.placeholder = placeholder;
        }
    }
    
    [super setHighlighted:highlighted];
}

@end
