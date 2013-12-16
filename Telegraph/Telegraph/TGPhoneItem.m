#import "TGPhoneItem.h"

#import "TGStringUtils.h"

@interface TGPhoneItem ()

@property (nonatomic, strong) NSString *formattedPhone;

@end

@implementation TGPhoneItem

@synthesize label = _label;
@synthesize phone = _phone;
@synthesize isMainPhone = _isMainPhone;
@synthesize highlightMainPhone = _highlightMainPhone;
@synthesize disabled = _disabled;

@synthesize formattedPhone = _formattedPhone;

- (id)init
{
    self = [super initWithType:TGPhoneItemType];
    if (self != nil)
    {
    }
    return self;
}

- (id)copyWithZone:(NSZone *)__unused zone
{
    TGPhoneItem *phoneItem = [[TGPhoneItem alloc] init];
    phoneItem.label = _label;
    phoneItem.phone = _phone;
    phoneItem.isMainPhone = _isMainPhone;
    
    return phoneItem;
}

- (void)setPhone:(NSString *)phone
{
    _formattedPhone = nil;
    _phone = phone;
}

- (void)setFormattedPhone:(NSString *)formattedPhone
{
    _formattedPhone = formattedPhone;
    
    unichar rawPhone[formattedPhone.length];
    int rawPhoneLength = 0;
    
    int length = formattedPhone.length;
    bool expectPlus = true;
    for (int i = 0; i < length; i++)
    {
        unichar c = [formattedPhone characterAtIndex:i];
        if ((c == '+' && expectPlus) || (c >= '0' && c <= '9'))
        {
            expectPlus = false;
            rawPhone[rawPhoneLength++] = c;
        }
    }
    
    _phone = [[NSString alloc] initWithCharacters:rawPhone length:rawPhoneLength];
}

- (NSString *)formattedPhone
{
    if (_formattedPhone != nil)
        return _formattedPhone;

    _formattedPhone = [TGStringUtils formatPhone:_phone forceInternational:false];
    
    return _formattedPhone;
}

@end
