/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <UIKit/UIKit.h>

#import "TGViewController.h"

#import "TGConversationControllerCompanion.h"
#import "TGConversationItem.h"

#import "ActionStage.h"

#import "TGUser.h"

#ifdef __cplusplus
#include <map>
#include <tr1/memory>
#endif

extern __strong id<TGConversationMessageAssetsSource> TGGlobalAssetsSource;

typedef enum {
    TGConversationControllerUpdateFlagsScrollDown = 1,
    TGConversationControllerUpdateFlagsScrollKeep = 2,
    TGConversationControllerUpdateFlagsScrollToUnread = 4
} TGConversationControllerUpdateFlags;

@interface TGConversationController : TGViewController <TGDestructableViewController, TGViewControllerNavigationBarAppearance>
@property (nonatomic, strong, readonly) ASHandle *actionHandle;

@property (nonatomic, strong) TGConversationControllerCompanion *conversationCompanion;

@property (nonatomic) bool shouldRemoveAllPreviousControllers;

@property (nonatomic) bool openKeyboardAutomatically;

+ (void)setGlobalAssetsSource:(id<TGConversationMessageAssetsSource>)assetsSource;

+ (void)preloadGraphics;

+ (int64_t)lastConversationIdForBackAction;
+ (void)resetLastConversationIdForBackAction;

+ (CGSize)preferredInlineThumbnailSize;

+ (void)clearSharedCache;

- (id)initWithConversationControllerCompanion:(TGConversationControllerCompanion *)companion unreadCount:(int)unreadCount;

- (bool)shouldReadHistory;
- (void)timeToLoadMoreHistory;

- (void)setMessageText:(NSString *)text;

- (void)disableSendButton:(bool)disable;

- (void)conversationSignleParticipantChanged:(TGUser *)singleParticipant;
- (void)conversationParticipantDataChanged:(TGUser *)user;
- (void)conversationAvatarChanged:(NSString *)url;
- (void)conversationParticipantPresenceChanged:(int)uid presence:(TGUserPresence)presence;
- (void)conversationTitleChanged:(NSString *)title subtitle:(NSString *)subtitle typingSubtitle:(NSString *)typingSubtitle isContact:(bool)isContact;
- (void)messageLifetimeChanged:(int)messageLifetime;
- (void)synchronizationStatusChanged:(TGConversationControllerSynchronizationState)state;
- (void)conversationLinkChanged:(int)link;
- (void)setUserBlocked:(bool)userBlocked;
- (void)setConversationMuted:(bool)conversationMuted;
- (void)setEncryptionStatus:(int)status;
- (void)precalculateItemMetrics:(TGConversationItem *)item;
- (void)scrollDownOnNextUpdate:(bool)andClearText;
- (void)clearInputText;
- (void)conversationMessagesCleared;

- (void)freezeConversation:(bool)freeze;
- (void)conversationHistoryFullyReloaded:(NSArray *)items;
- (void)conversationHistoryFullyReloaded:(NSArray *)items scrollToMid:(int)scrollToMid scrollFlags:(int)scrollFlags;

#ifdef __cplusplus
- (void)conversationMessageUploadProgressChanged:(std::tr1::shared_ptr<std::map<int, float> >)pMessageUploadProgress;
#endif
- (void)conversationMediaDownloadProgressChanged:(NSMutableDictionary *)mediaDownloadProgress;
- (void)addProcessedMediaDownloadedStatuses:(NSDictionary *)dict;

- (void)reloadImageThumbnailsWithUrl:(NSString *)url;
- (void)messageIdsChanged:(NSArray *)mapping;

- (void)conversationMessagesChanged:(NSArray *)insertedIndices insertedItems:(NSArray *)insertedItems removedAtIndices:(NSArray *)removedIndices updatedAtIndices:(NSArray *)updatedIndices updatedItems:(NSArray *)updatedItems delay:(bool)delay scrollDownFlags:(int)scrollDownFlags;
- (void)changeModelItems:(NSArray *)indices items:(NSArray *)items;
- (void)conversationHistoryLoadingCompleted;
- (void)conversationDownwardsHistoryLoadingCompleted;

- (void)linkActionInProgress:(int)action inProgress:(bool)inProgress;

- (void)unreadCountChanged:(int)unreadCount;

- (void)displayNewMessagesTooltip;

- (void)showProgressWindow:(bool)show;

@end
