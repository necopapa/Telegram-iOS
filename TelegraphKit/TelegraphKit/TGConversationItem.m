#import "TGConversationItem.h"

@implementation TGConversationItem

@synthesize type = _type;

- (id)initWithType:(TGConversationItemType)type
{
    self = [super init];
    if (self != nil)
    {
        _type = type;
    }
    return self;
}

@end
