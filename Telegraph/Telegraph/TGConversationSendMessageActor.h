/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "ASActor.h"

#import "TL/TLMetaScheme.h"

#import "ActionStage.h"

#ifdef __cplusplus
#import "TGEncryption.h"
#endif

@interface TGConversationSendMessageActor : ASActor <ASWatcher>
@property (nonatomic, strong) ASHandle *actionHandle;

@property (nonatomic) bool hasProgress;
@property (nonatomic) float progress;
@property (nonatomic) int messageLocalMid;

+ (NSString *)genericPath;

- (void)conversationSendMessageRequestSuccess:(id)abstractMessage;
- (void)conversationSendMessageRequestFailed;
- (void)conversationSendMessageQuickAck;

- (void)conversationSendBroadcastSuccess:(NSArray *)messages;
- (void)conversationSendBroadcastFailed;

- (void)sendEncryptedMessageSuccess:(int32_t)date encryptedFile:(TLEncryptedFile *)encryptedFile;
- (void)sendEncryptedMessageFailed;

#ifdef __cplusplus
+ (MessageKeyData)generateMessageKeyData:(NSData *)messageKey incoming:(bool)incoming key:(NSData *)key;
#endif

+ (NSData *)encryptMessage:(NSData *)serializedMessage key:(NSData *)key keyId:(int64_t)keyId;

@end
