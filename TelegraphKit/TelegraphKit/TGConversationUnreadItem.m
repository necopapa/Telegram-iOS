#import "TGConversationUnreadItem.h"

@interface TGConversationUnreadItem ()

@property (nonatomic, strong) NSString *title;
@property (nonatomic) int token;

@end

@implementation TGConversationUnreadItem

@synthesize unreadCount = _unreadCount;

@synthesize title = _title;
@synthesize token = _token;

- (id)initWithUnreadCount:(int)unreadCount
{
    self = [super initWithType:TGConversationItemTypeUnread];
    if (self != nil)
    {
        _unreadCount = unreadCount;
        
        static int nextToken = 1;
        _token = nextToken++;
    }
    return self;
}

- (NSString *)title
{
    if (_title == nil)
        _title = [[NSString alloc] initWithFormat:@"%d unread message%s", _unreadCount, _unreadCount == 1 ? "" : "s"];
    
    return _title;
}

@end
