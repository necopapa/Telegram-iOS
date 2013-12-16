#import "TGChangePeerBlockStatusActor.h"

#import "ActionStage.h"

#import "TGDatabase.h"

#import "TGTelegraph.h"

@implementation TGChangePeerBlockStatusActor

+ (NSString *)genericPath
{
    return @"/tg/changePeerBlockedStatus/@";
}

- (void)execute:(NSDictionary *)options
{
    int64_t peerId = [[options objectForKey:@"peerId"] longLongValue];
    bool block = [[options objectForKey:@"block"] boolValue];
    
    [TGDatabaseInstance() setPeerIsBlocked:peerId blocked:block writeToActionQueue:true];
    
    [ActionStageInstance() requestActor:@"/tg/service/synchronizeserviceactions/(settings)" options:nil watcher:TGTelegraphInstance];
    
    [ActionStageInstance() actionCompleted:self.path result:nil];
}

@end
