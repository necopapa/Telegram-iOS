#import "TGConversationSetStateActor.h"

#import "TGMessage.h"
#import "TGDatabase.h"

#import "ActionStage.h"

@implementation TGConversationSetStateActor

+ (NSString *)genericPath
{
    return @"/tg/conversation/@/setstate/@";
}

- (void)execute:(NSDictionary *)options
{
    int64_t conversationId = [[options objectForKey:@"conversationId"] longLongValue];
    TGMessage *state = [options objectForKey:@"state"];
    if (state == (id)[NSNull null])
        state = nil;
    
    [[TGDatabase instance] storeConversationState:conversationId message:state];
    
    [ActionStageInstance() actionCompleted:self.path result:nil];
}

@end
