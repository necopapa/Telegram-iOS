#import "TGRevokeSessionsActor.h"

#import "ActionStage.h"

#import "TGTelegraph.h"

@implementation TGRevokeSessionsActor

+ (NSString *)genericPath
{
    return @"/tg/service/revokesessions";
}

- (void)execute:(NSDictionary *)__unused options
{
    self.cancelToken = [TGTelegraphInstance doRevokeOtherSessions:self];
}

- (void)revokeSessionsSuccess
{
    [ActionStageInstance() actionCompleted:self.path result:nil];
}

- (void)revokeSessionsFailed
{
    [ActionStageInstance() actionFailed:self.path reason:-1];
}

@end
