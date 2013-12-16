#import "TGSynchronizationStateRequestActor.h"

#import "ActionStage.h"
#import "SGraphObjectNode.h"

#import "TGSession.h"

@implementation TGSynchronizationStateRequestActor

+ (NSString *)genericPath
{
    return @"/tg/service/synchronizationstate";
}

- (void)execute:(NSDictionary *)__unused options
{
    int state = [ActionStageInstance() requestActorStateNow:@"/tg/service/updatestate"] ? 1 : 0;
    if ([[TGSession instance] isWaitingForFirstData])
        state |= 1;
    if ([[TGSession instance] isConnecting])
        state |= 2;
    if ([[TGSession instance] isOffline])
        state |= 4;
    
    [ActionStageInstance() nodeRetrieved:self.path node:[[SGraphObjectNode alloc] initWithObject:[NSNumber numberWithInt:state]]];
}

@end
