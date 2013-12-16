#import "TGLogoutRequestBuilder.h"

#import "ActionStage.h"

#import "TGTelegraph.h"

@implementation TGLogoutRequestBuilder

@synthesize actionHandle = _actionHandle;

+ (NSString *)genericPath
{
    return @"/tg/auth/logout/@";
}

- (id)initWithPath:(NSString *)path
{
    self = [super initWithPath:path];
    if (self != nil)
    {
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:false];
        _actionHandle.delegate = self;
    }
    return self;
}

- (void)dealloc
{
    [_actionHandle reset];
    
    [ActionStageInstance() removeWatcher:self];
}

- (void)execute:(NSDictionary *)options
{
    if (![[options objectForKey:@"force"] boolValue])
    {
        self.cancelToken = [TGTelegraphInstance doRequestLogout:self];
    }
    else
    {
        [self logoutSuccess:true];
    }
}

- (void)logoutSuccess
{
    [self logoutSuccess:false];
}

- (void)logoutSuccess:(bool)force
{
    if (self.cancelToken != nil || force)
    {
        self.cancelToken = nil;
        
        [ActionStageInstance() actionCompleted:self.path result:nil];
        
        [TGTelegraphInstance doLogout];
    }
}

- (void)logoutFailed
{
    [self logoutSuccess:false];
}

@end
