#import "TGConversationDateItem.h"

#import "TGDateUtils.h"

@implementation TGConversationDateItem

@synthesize date = _date;
@synthesize dateString = _dateString;

- (id)initWithDate:(NSTimeInterval)date
{
    self = [super initWithType:TGConversationItemTypeDate];
    if (self != nil)
    {
        _date = date;
    }
    return self;
}

- (NSString *)dateString
{
    if (_dateString == nil)
    {
        _dateString = [TGDateUtils stringForDialogTime:((int)_date)];
    }
    
    return _dateString;
}

@end
