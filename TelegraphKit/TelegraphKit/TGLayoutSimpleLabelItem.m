#import "TGLayoutSimpleLabelItem.h"

@implementation TGLayoutSimpleLabelItem

@synthesize font = _font;
@synthesize text = _text;
@synthesize textAlignment = _textAlignment;
@synthesize textColor = _textColor;
@synthesize backgroundColor = _backgroundColor;

- (id)init
{
    self = [super initWithType:TGLayoutItemTypeSimpleLabel];
    if (self != nil)
    {
    }
    return self;
}

@end
