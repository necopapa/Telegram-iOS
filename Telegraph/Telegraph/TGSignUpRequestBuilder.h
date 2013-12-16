/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "ASActor.h"

#import "TL/TLMetaScheme.h"

typedef enum {
    TGSignUpResultNetworkError = -1,
    TGSignUpResultInternalError = -2,
    TGSignUpResultInvalidToken = -3,
    TGSignUpResultTokenExpired = -4,
    TGSignUpResultFloodWait = -5,
    TGSignUpResultInvalidFirstName = -6,
    TGSignUpResultInvalidLastName = -7
} TGSignUpResult;

@interface TGSignUpRequestBuilder : ASActor

+ (NSString *)genericPath;

- (void)signUpSuccess:(TLauth_Authorization *)authorization;
- (void)signUpFailed:(TGSignUpResult)reason;

@end
