#import "TGSignInRequestBuilder.h"

#import "ActionStage.h"
#import "SGraphObjectNode.h"

#import "TGTelegraph.h"
#import "TGSchema.h"
#import "TGUser.h"
#import "TGUserDataRequestBuilder.h"

@implementation TGSignInRequestBuilder

- (id)initWithPath:(NSString *)path
{
    self = [super initWithPath:path];
    if (self != nil)
    {
        self.cancelTimeout = 0;
    }
    return self;
}

+ (NSString *)genericPath
{
    return @"/tg/service/auth/signIn/@";
}

- (void)execute:(NSDictionary *)options
{
    NSString *phoneNumber = [options objectForKey:@"phoneNumber"];
    NSString *phoneHash = [options objectForKey:@"phoneCodeHash"];
    NSString *phoneCode = [options objectForKey:@"phoneCode"];
    if (phoneNumber == nil || phoneHash == nil || phoneCode == nil)
    {
        [self signInFailed:TGSignInResultInvalidToken];
        return;
    }
    
    self.cancelToken = [TGTelegraphInstance doSignIn:phoneNumber phoneHash:phoneHash phoneCode:phoneCode requestBuilder:self];
}

- (void)signInSuccess:(TLauth_Authorization *)authorization
{
    [TGUserDataRequestBuilder executeUserDataUpdate:[NSArray arrayWithObject:authorization.user]];
    
    bool activated = true;
    if ([authorization.user isKindOfClass:[TLUser$userSelf class]])
        activated = !((TLUser$userSelf *)authorization.user).inactive;
    
    [TGTelegraphInstance processAuthorizedWithUserId:authorization.user.n_id clientIsActivated:activated];
    
    [ActionStageInstance() actionCompleted:self.path result:[[SGraphObjectNode alloc] initWithObject:[[NSDictionary alloc] initWithObjectsAndKeys:[[NSNumber alloc] initWithBool:activated], @"activated", nil]]];
}

- (void)signInFailed:(TGSignInResult)reason
{
    [ActionStageInstance() actionFailed:self.path reason:reason];
}

- (void)cancel
{
    if (self.cancelToken != nil)
    {
        [TGTelegraphInstance cancelRequestByToken:self.cancelToken];
        self.cancelToken = nil;
    }
    
    [super cancel];
}

@end
