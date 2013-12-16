#import "TGMediaActionButton.h"

@interface TGMediaActionButton ()

@property (nonatomic, strong) NSString *currentTitle;
@property (nonatomic, strong) NSString *currentShortTitle;

@property (nonatomic) float height;

@end

@implementation TGMediaActionButton

@synthesize currentTitle = _currentTitle;
@synthesize currentShortTitle = _currentShortTitle;

@synthesize height = _height;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
    }
    return self;
}

- (void)setTitleText:(NSString *)titleText shortTitleText:(NSString *)shortTitleText
{
    _currentTitle = titleText;
    _currentShortTitle = shortTitleText;
}

- (void)setBackgroundImage:(UIImage *)image forState:(UIControlState)state
{
    [super setBackgroundImage:image forState:state];
    
    if (state == UIControlStateNormal)
        _height = image.size.height;
}

- (CGSize)sizeThatFits:(CGSize)size
{   
    UIEdgeInsets insets = self.contentEdgeInsets;
    float textWidth = [_currentTitle sizeWithFont:self.titleLabel.font].width;
    if (textWidth + insets.left + insets.right > size.width)
    {
        textWidth = [_currentShortTitle sizeWithFont:self.titleLabel.font].width;
        [self setTitle:_currentShortTitle forState:UIControlStateNormal];
    }
    else
        [self setTitle:_currentTitle forState:UIControlStateNormal];
    
    return CGSizeMake(MAX(0, insets.left + textWidth + insets.right), _height);
}

@end
