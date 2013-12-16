#import "TGTokenView.h"

static UIImage *tokenBackgroundImage()
{
    static UIImage *image = nil;
    if (image == nil)
    {
        UIImage *rawImage = [UIImage imageNamed:@"TokenBackground.png"];
        image = [rawImage stretchableImageWithLeftCapWidth:(int)(rawImage.size.width / 2) topCapHeight:0];
    }
    return image;
}

static UIImage *tokenBackgroundHighlightedImage()
{
    static UIImage *image = nil;
    if (image == nil)
    {
        UIImage *rawImage = [UIImage imageNamed:@"TokenBackground_Highlighted.png"];
        image = [rawImage stretchableImageWithLeftCapWidth:(int)(rawImage.size.width / 2) topCapHeight:0];
    }
    return image;
}

@implementation TGTokenView

@synthesize label = _label;
@synthesize preferredWidth = _preferredWidth;

@synthesize tokenId = _tokenId;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        [self commonInit];
    }
    return self;
}

- (void)commonInit
{
    [self setBackgroundImage:tokenBackgroundImage() forState:UIControlStateNormal];
    [self setBackgroundImage:tokenBackgroundHighlightedImage() forState:UIControlStateHighlighted];
    [self setBackgroundImage:tokenBackgroundHighlightedImage() forState:UIControlStateSelected];
    [self setBackgroundImage:tokenBackgroundHighlightedImage() forState:UIControlStateHighlighted | UIControlStateSelected];
    
    self.titleLabel.font = [UIFont systemFontOfSize:15];
    [self setTitleEdgeInsets:UIEdgeInsetsMake(0, 10, 0, 10)];
    
    [self setTitleColor:UIColorRGB(0x2c3742) forState:UIControlStateNormal];
    [self setTitleShadowColor:UIColorRGB(0xd4ebff) forState:UIControlStateNormal];
    
    UIColor *highlightedTextColor = [UIColor whiteColor];
    UIColor *highlightedShadowColor = UIColorRGB(0x1a78c8);
    
    [self setTitleColor:highlightedTextColor forState:UIControlStateHighlighted];
    [self setTitleShadowColor:highlightedShadowColor forState:UIControlStateHighlighted];
    [self setTitleColor:highlightedTextColor forState:UIControlStateSelected];
    [self setTitleShadowColor:highlightedShadowColor forState:UIControlStateSelected];
    [self setTitleColor:highlightedTextColor forState:UIControlStateHighlighted | UIControlStateSelected];
    [self setTitleShadowColor:highlightedShadowColor forState:UIControlStateHighlighted | UIControlStateSelected];
    
    self.titleLabel.shadowOffset = CGSizeMake(0, 1);
    
    [self addTarget:self action:@selector(buttonPressed) forControlEvents:UIControlEventTouchDown];
}

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];
    
    self.titleLabel.shadowOffset = self.selected || highlighted ? CGSizeMake(0, -1) : CGSizeMake(0, -1);
}

- (void)setSelected:(BOOL)selected
{
    [super setSelected:selected];
    
    self.titleLabel.shadowOffset = selected || self.highlighted ? CGSizeMake(0, -1) : CGSizeMake(0, -1);
}

- (void)buttonPressed
{
    [self becomeFirstResponder];
}

- (void)setLabel:(NSString *)label
{
    _label = label;
    
    [self setTitle:label forState:UIControlStateNormal];
    
    _preferredWidth = [label sizeWithFont:self.titleLabel.font].width + 12 * 2;
}

- (float)preferredWidth
{
    return MAX(_preferredWidth, 12 * 2);
}

#pragma mark -

- (BOOL)becomeFirstResponder
{
    if ([super becomeFirstResponder])
    {
        if ([self.superview.superview respondsToSelector:@selector(highlightToken:)])
            [self.superview.superview performSelector:@selector(highlightToken:) withObject:self];
        return true;
    }
    
    return false;
}

- (BOOL)resignFirstResponder
{
    if ([super resignFirstResponder])
    {
        if ([self.superview.superview respondsToSelector:@selector(unhighlightToken:)])
            [self.superview.superview performSelector:@selector(unhighlightToken:) withObject:self];
        return true;
    }
    
    return false;
}

- (void)deleteBackward
{
    if ([self.superview.superview respondsToSelector:@selector(deleteToken:)])
        [self.superview.superview performSelector:@selector(deleteToken:) withObject:self];
}

- (BOOL)hasText
{
    return false;
}

- (void)insertText:(NSString *)__unused text
{
}

- (BOOL)canBecomeFirstResponder
{
    return true;
}

@end
