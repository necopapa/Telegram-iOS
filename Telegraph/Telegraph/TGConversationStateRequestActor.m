#import "TGConversationStateRequestActor.h"

#import "TGDatabase.h"

#import "ActionStage.h"
#import "SGraphObjectNode.h"

@implementation TGConversationStateRequestActor

+ (NSString *)genericPath
{
    return @"/tg/conversation/@/state";
}

- (void)execute:(NSDictionary *)options
{
    int64_t conversationId = [[options objectForKey:@"conversationId"] longLongValue];
    
    [[TGDatabase instance] loadConversationState:conversationId completion:^(TGMessage *state)
    {
        [ActionStageInstance() nodeRetrieved:self.path node:[[SGraphObjectNode alloc] initWithObject:state]];
    }];
}

@end
