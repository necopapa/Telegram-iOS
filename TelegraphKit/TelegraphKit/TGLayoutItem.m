#import "TGLayoutItem.h"

@implementation TGLayoutItem

@synthesize type = _type;
@synthesize tag = _tag;
@synthesize additionalTag = _additionalTag;

@synthesize frame = _frame;

@synthesize userInteractionEnabled = _userInteractionEnabled;

- (id)initWithType:(TGLayoutItemType)type
{
    self = [super init];
    if (self != nil)
    {
        _type = type;
        
        _userInteractionEnabled = true;
    }
    return self;
}

@end
