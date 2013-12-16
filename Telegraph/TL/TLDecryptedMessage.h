/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <Foundation/Foundation.h>

#import "TLObject.h"
#import "TLMetaRpc.h"

@class TLDecryptedMessageMedia;

@interface TLDecryptedMessage : NSObject <TLObject>

@property (nonatomic) int64_t random_id;
@property (nonatomic, retain) NSData *random_bytes;
@property (nonatomic) int32_t from_id;
@property (nonatomic) int32_t date;
@property (nonatomic, retain) NSString *message;
@property (nonatomic, retain) TLDecryptedMessageMedia *media;

@end

@interface TLDecryptedMessage$decryptedMessage : TLDecryptedMessage


@end

@interface TLDecryptedMessage$decryptedMessageForwarded : TLDecryptedMessage

@property (nonatomic) int32_t fwd_from_id;
@property (nonatomic) int32_t fwd_date;

@end

