#import "TGLayoutImageItem.h"

@implementation TGLayoutImageItem

@synthesize image = _image;
@synthesize manualDrawing = _manualDrawing;

- (id)initWithImage:(UIImage *)image
{
    self = [super initWithType:TGLayoutItemTypeImage];
    if (self != nil)
    {
        _image = image;
    }
    return self;
}

@end
