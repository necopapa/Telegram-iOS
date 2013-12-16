/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "TGConversationControllerCompanion.h"

#import "ActionStage.h"

#import "TGConversation.h"

@interface TGTelegraphConversationCompanion : TGConversationControllerCompanion <ASWatcher>
@property (nonatomic, strong) ASHandle *actionHandle;

@property (nonatomic) int64_t conversationId;
@property (nonatomic) int64_t encryptedConversationId;
@property (nonatomic) int64_t encryptedConversationAccessHash;

@property (nonatomic, strong) NSArray *messagesToForward;

- (id)initWithConversationId:(int64_t)conversationId atMessageId:(int)atMessageId isMultichat:(bool)isMultichat isEncrypted:(bool)isEncrypted conversation:(TGConversation *)conversation unreadCount:(int)unreadCount messagesToForward:(NSArray *)messagesToForward;
- (id)initWithBroadcastUids:(NSArray *)broadcastUids unreadCount:(int)unreadCount;

- (void)removeUnreadMarker;

+ (void)resetBackgroundImage;
+ (void)setDoNotRead:(bool)doNotRead;
+ (bool)doNotRead;

@end
