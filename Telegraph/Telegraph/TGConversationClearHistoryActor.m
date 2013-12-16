#import "TGConversationClearHistoryActor.h"

#import "ActionStage.h"

#import "TGTelegraph.h"
#import "TGDatabase.h"

#import "TGUpdateStateRequestBuilder.h"

@implementation TGConversationClearHistoryActor

+ (NSString *)genericPath
{
    return @"/tg/conversation/@/clearHistory";
}

- (void)execute:(NSDictionary *)options
{
    int64_t conversationId = [[options objectForKey:@"conversationId"] longLongValue];
    if (conversationId == 0)
    {
        [ActionStageInstance() actionFailed:self.path reason:-1];
        return;
    }
    
    [TGDatabaseInstance() clearConversation:conversationId populateActionQueue:true];
    
    dispatch_async([ActionStageInstance() globalStageDispatchQueue], ^
    {
        [ActionStageInstance() requestActor:@"/tg/service/synchronizeactionqueue/(global)" options:nil watcher:TGTelegraphInstance];
    });
    
    [ActionStageInstance() actionCompleted:self.path result:nil];
}

@end
