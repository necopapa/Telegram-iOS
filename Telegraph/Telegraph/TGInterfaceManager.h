/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <Foundation/Foundation.h>

#import "ActionStage.h"

@class TGMessage;
@class TGConversation;

@interface TGInterfaceManager : NSObject <ASWatcher>

@property (nonatomic, strong) ASHandle *actionHandle;

+ (TGInterfaceManager *)instance;

- (void)preload;

- (void)navigateToConversationWithId:(int64_t)conversationId conversation:(TGConversation *)conversation;
- (void)navigateToConversationWithId:(int64_t)conversationId conversation:(TGConversation *)conversation animated:(bool)animated;
- (void)navigateToConversationWithId:(int64_t)conversationId conversation:(TGConversation *)conversation forwardMessages:(NSArray *)forwardMessages;
- (void)navigateToConversationWithId:(int64_t)conversationId conversation:(TGConversation *)conversation forwardMessages:(NSArray *)forwardMessages animated:(bool)animated;
- (void)navigateToConversationWithId:(int64_t)conversationId conversation:(TGConversation *)conversation forwardMessages:(NSArray *)forwardMessages atMessageId:(int)atMessageId clearStack:(bool)clearStack openKeyboard:(bool)openKeyboard animated:(bool)animated;
- (void)navigateToConversationWithBroadcastUids:(NSArray *)broadcastUids forwardMessages:(NSArray *)forwardMessages;
- (void)navigateToProfileOfUser:(int)uid preferNativeContactId:(int)preferNativeContactId;
- (void)navigateToProfileOfUser:(int)uid;
- (void)navigateToProfileOfUser:(int)uid encryptedConversationId:(int64_t)encryptedConversationId;
- (void)navigateToContact:(int)uid firstName:(NSString *)firstName lastName:(NSString *)lastName phoneNumber:(NSString *)phoneNumber;
- (void)navigateToTimelineOfUser:(int)uid;
- (void)navigateToMediaListOfConversation:(int64_t)conversationId;

- (void)displayBannerIfNeeded:(TGMessage *)message conversationId:(int64_t)conversationId;
- (void)dismissBannerForConversationId:(int64_t)conversationId;

- (void)displayNearbyBannerIdNeeded:(int)peopleCount;

@end
