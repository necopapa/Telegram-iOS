#import "TGRecipientListView.h"



@interface TGRecipientListView ()

@property (nonatomic, strong) NSMutableArray *tokenList;

@end

@implementation TGRecipientListView

@synthesize tokenList = _tokenList;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        [self commonInit];
    }
    return self;
}

- (id)init
{
    self = [super init];
    if (self != nil)
    {
        [self commonInit];
    }
    return self;
}

- (void)commonInit
{
    
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    
}

@end
