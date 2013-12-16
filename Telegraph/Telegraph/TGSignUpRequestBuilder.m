#import "TGSignUpRequestBuilder.h"

#import "ActionStage.h"
#import "SGraphObjectNode.h"

#import "TGTelegraph.h"
#import "TGSchema.h"
#import "TGUser.h"
#import "TGUserDataRequestBuilder.h"

@implementation TGSignUpRequestBuilder

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
    return @"/tg/service/auth/signUp/@";
}

- (void)execute:(NSDictionary *)options
{
    NSString *phoneNumber = [options objectForKey:@"phoneNumber"];
    NSString *phoneHash = [options objectForKey:@"phoneCodeHash"];
    NSString *phoneCode = [options objectForKey:@"phoneCode"];
    NSString *firstName = [options objectForKey:@"firstName"];
    NSString *lastName = [options objectForKey:@"lastName"];
    NSString *emailAddress = [options objectForKey:@"emailAddress"];
    if (phoneNumber == nil || phoneHash == nil || phoneCode == nil || firstName == nil || lastName == nil)
    {
        [self signUpFailed:TGSignUpResultInternalError];
        return;
    }
    [TGTelegraphInstance doSignUp:phoneNumber phoneHash:phoneHash phoneCode:phoneCode firstName:firstName lastName:lastName emailAddress:emailAddress requestBuilder:self];
}

- (void)signUpSuccess:(TLauth_Authorization *)authorization
{
    int userId = authorization.user.n_id;
    
    [TGUserDataRequestBuilder executeUserDataUpdate:[NSArray arrayWithObject:authorization.user]];
    
    bool activated = true;
    if ([authorization.user isKindOfClass:[TLUser$userSelf class]])
        activated = !((TLUser$userSelf *)authorization.user).inactive;
    
    [TGTelegraphInstance processAuthorizedWithUserId:userId clientIsActivated:activated];
    
    [ActionStageInstance() actionCompleted:self.path result:[[SGraphObjectNode alloc] initWithObject:[[NSDictionary alloc] initWithObjectsAndKeys:[[NSNumber alloc] initWithBool:activated], @"activated", nil]]];
}

- (void)signUpFailed:(TGSignUpResult)reason
{
    [ActionStageInstance() actionFailed:self.path reason:reason];
}

@end
