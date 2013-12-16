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


@interface TLDecryptedMessageMedia : NSObject <TLObject>


@end

@interface TLDecryptedMessageMedia$decryptedMessageMediaEmpty : TLDecryptedMessageMedia


@end

@interface TLDecryptedMessageMedia$decryptedMessageMediaPhoto : TLDecryptedMessageMedia

@property (nonatomic, retain) NSData *thumb;
@property (nonatomic, retain) NSData *key;

@end

@interface TLDecryptedMessageMedia$decryptedMessageMediaVideo : TLDecryptedMessageMedia

@property (nonatomic, retain) NSData *thumb;
@property (nonatomic) int32_t duration;
@property (nonatomic, retain) NSData *key;

@end

@interface TLDecryptedMessageMedia$decryptedMessageMediaFile : TLDecryptedMessageMedia

@property (nonatomic, retain) NSString *filename;
@property (nonatomic, retain) NSData *thumb;
@property (nonatomic, retain) NSData *key;

@end

@interface TLDecryptedMessageMedia$decryptedMessageMediaGeoPoint : TLDecryptedMessageMedia

@property (nonatomic) double lat;
@property (nonatomic) double n_long;

@end

@interface TLDecryptedMessageMedia$decryptedMessageMediaContact : TLDecryptedMessageMedia

@property (nonatomic, retain) NSString *phone_number;
@property (nonatomic, retain) NSString *first_name;
@property (nonatomic, retain) NSString *last_name;

@end

