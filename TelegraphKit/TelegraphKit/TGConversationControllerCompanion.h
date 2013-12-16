/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <Foundation/Foundation.h>

#import "TGConversationMessageAssetsSource.h"
#import "TGAppManager.h"

#import "TGImageViewControllerCompanion.h"

#import "TGImageInputMediaAttachment.h"
#import "TGVideoInputMediaAttachment.h"

#import "TGUser.h"
#import "TGMessage.h"
#import "TGMediaItem.h"

typedef enum {
    TGConversationControllerSynchronizationStateNone = 0,
    TGConversationControllerSynchronizationStateConnecting = 1,
    TGConversationControllerSynchronizationStateUpdating = 2,
    TGConversationControllerSynchronizationStateWaitingForNetwork = 3
} TGConversationControllerSynchronizationState;

@class TGConversationController;

@interface TGConversationControllerCompanion : NSObject

@property (nonatomic, strong) TGConversationController *conversationController;

@property (nonatomic, strong) NSString *conversationTitle;
@property (nonatomic, strong) NSString *conversationSubtitle;
@property (nonatomic, strong) NSString *conversationTypingSubtitle;
@property (nonatomic, strong) NSString *safeConversationTitle;
@property (nonatomic, strong) NSString *safeConversationSubtitle;
@property (nonatomic) bool isMultichat;
@property (nonatomic) bool isBroadcast;
@property (nonatomic) bool isEncrypted;
@property (nonatomic) int encryptedUserId;
@property (nonatomic) bool encryptionIsIncoming;

@property (nonatomic) NSMutableArray *conversationItems;

@property (nonatomic) bool isLoading;
@property (nonatomic) bool canLoadMoreHistory;

@property (nonatomic) bool isLoadingDownwards;
@property (nonatomic) bool canLoadMoreHistoryDownwards;

@property (nonatomic) int messageLifetime;

@property (nonatomic, strong) TGUser *singleParticipant;

- (int64_t)conversationId;

- (UIColor *)conversationBackground;
- (UIImage *)conversationBackgroundImage;
- (UIImage *)conversationBackgroundOverlay;
- (UIImage *)inputContainerShadowImage;
- (UIImage *)inputFieldBackground;
- (UIImage *)inputContainerRawBackground;
- (UIImage *)attachButtonImage;
- (UIImage *)attachButtonImageHighlighted;
- (UIImage *)attachButtonArrowImageUp;
- (UIImage *)attachButtonArrowImageDown;
- (UIImage *)sendButtonImage;
- (UIImage *)sendButtonImageHighlighted;
- (CGSize)titleAvatarSize:(UIDeviceOrientation)orientation;
- (UIImage *)titleAvatarPlaceholder;
- (UIImage *)titleAvatarPlaceholderGeneric;
- (UIImage *)titleAvatarOverlay:(UIInterfaceOrientation)orientation;
- (UIImage *)unreadCountBadgeImage;
- (UIImage *)chatArrowDownImage;
- (UIImage *)chatArrowUpImage;
- (UIColor *)attachmentPanelBackground;
- (UIImage *)attachmentPanelShadow;
- (UIImage *)attachmentPanelDivider;
- (UIImage *)attachmentCameraImage;
- (UIImage *)attachmentCameraImageHighlighted;
- (UIImage *)attachmentGalleryImage;
- (UIImage *)attachmentGalleryImageHighlighted;
- (UIImage *)attachmentLocationImage;
- (UIImage *)attachmentLocationImageHighlighted;
- (UIImage *)attachmentAudioImage;
- (UIImage *)attachmentAudioImageHighlighted;
- (UIColor *)membersPanelBackground;
- (UIImage *)membersPanelBackgroundImage;
- (UIImage *)actionBarBackgroundImage;
- (UIImage *)editingDeleteButtonBackground;
- (UIImage *)editingDeleteButtonBackgroundHighlighted;
- (UIImage *)editingDeleteButtonIcon;
- (UIImage *)editingForwardButtonBackground;
- (UIImage *)editingForwardButtonBackgroundHighlighted;
- (UIImage *)editingForwardButtonIcon;

- (UIImage *)inlineButton;
- (UIImage *)inlineButtonHighlighted;

- (UIImage *)headerActionArrowUp;
- (UIImage *)headerActionArrowDown;

- (id<TGAppManager>)applicationManager;
- (id<TGConversationMessageAssetsSource>)messageAssetsSource;

- (bool)shouldAutosavePhotos;
- (int)ignoreSaveToGalleryUid;

- (void)updateUnreadCount;
- (void)addUnreadMarkIfNeeded;

- (int)offsetFromGMT;

- (void)sendMessageIfAny;
- (bool)isAssetUrlOnServer:(NSString *)assetUrl;
- (TGImageInputMediaAttachment *)createImageAttachmentFromImage:(UIImage *)image assetUrl:(NSString *)assetUrl;
- (TGVideoInputMediaAttachment *)createVideoAttachmentFromVideo:(NSString *)fileName thumbnailImage:(UIImage *)thumbnailImage duration:(int)duration dimensions:(CGSize)dimensions assetUrl:(NSString *)assetUrl;

- (void)loadMoreHistory;
- (void)loadMoreHistoryDownwards;
- (void)reloadHistoryShortcut;

- (void)userAvatarPressed;
- (void)conversationMemberSelected:(int)uid;

- (void)messageTypingActivity;

- (void)changeConversationTitle:(NSString *)title;
- (void)showConversationProfile:(bool)activateCamera activateTitleChange:(bool)activateTitleChange;
- (void)openContact:(TGContactMediaAttachment *)contactAttachment;

- (void)storeConversationState:(NSString *)messageText;
- (void)clearUnreadIfNeeded:(bool)force;
- (void)unloadOldItemsIfNeeded;
- (void)sendMessage:(NSString *)text attachments:(NSArray *)attachments clearText:(bool)clearText;
- (void)sendMediaMessages:(NSArray *)attachments clearText:(bool)clearText;
- (void)retryMessage:(int)mid;
- (void)retryAllMessages;
- (void)cancelMessageProgress:(int)mid;
- (void)cancelMediaProgress:(id)mediaId;
- (void)forwardMessages:(NSArray *)array;
- (void)deleteMessages:(NSArray *)mids;
- (void)clearAllMessages;

- (void)sendContactRequest;
- (void)acceptContactRequest;
- (void)ignoreContactRequest;
- (void)blockUser;
- (void)unblockUser;
- (void)muteConversation:(bool)mute;
- (void)leaveGroup;
- (void)acceptEncryptionRequest;

- (void)downloadMedia:(TGMessage *)message changePriority:(bool)changePriority;

- (id<TGImageViewControllerCompanion>)createImageViewControllerCompanion:(int)firstItemId reverseOrder:(bool)reverseOrder;
- (id<TGImageViewControllerCompanion>)createGroupPhotoImageViewControllerCompanion:(id<TGMediaItem>)mediaItem;
- (id<TGImageViewControllerCompanion>)createUserPhotoImageViewControllerCompanion:(id<TGMediaItem>)mediaItem;
- (id<TGMediaItem>)createMediaItemFromMessage:(TGMessage *)message author:(TGUser *)author imageInfo:(TGImageInfo *)imageInfo;
- (id<TGMediaItem>)createMediaItemFromMessage:(TGMessage *)message author:(TGUser *)author videoAttachment:(TGVideoMediaAttachment *)videoAttachment;
- (id<TGMediaItem>)createMediaItemFromAvatarMessage:(TGMessage *)message;

@end
