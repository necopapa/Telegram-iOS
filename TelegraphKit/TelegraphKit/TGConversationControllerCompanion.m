#import "TGConversationControllerCompanion.h"

#import <UIKit/UIKit.h>

@interface TGConversationControllerCompanion ()

@end

@implementation TGConversationControllerCompanion

- (id)init
{
    self = [super init];
    if (self != nil)
    {        
        _conversationItems = [[NSMutableArray alloc] init];
    }
    return self;
}

#pragma mark - Interface Assets

- (void)setConversationTitle:(NSString *)conversationTitle
{
    _conversationTitle = conversationTitle;
    dispatch_async(dispatch_get_main_queue(), ^
    {
        _safeConversationTitle = conversationTitle;
    });
}

- (void)setConversationSubtitle:(NSString *)conversationSubtitle
{
    _conversationSubtitle = conversationSubtitle;
    dispatch_async(dispatch_get_main_queue(), ^
    {
        _safeConversationSubtitle = conversationSubtitle;
    });
}

- (int64_t)conversationId
{
    return 0;
}

- (UIColor *)conversationBackground
{
    return nil;
}

- (UIImage *)conversationBackgroundImage
{
    return nil;
}

- (UIImage *)conversationBackgroundOverlay
{
    return nil;
}

- (UIImage *)inputContainerShadowImage
{
    return nil;
}

- (UIImage *)inputFieldBackground
{
    return nil;
}

- (UIImage *)inputContainerRawBackground
{
    return nil;
}

- (UIImage *)attachButtonImage
{
    return nil;
}

- (UIImage *)attachButtonImageHighlighted
{
    return nil;
}

- (UIImage *)attachButtonArrowImageUp
{
    return nil;
}

- (UIImage *)attachButtonArrowImageDown
{
    return nil;
}

- (UIImage *)sendButtonImage
{
    return nil;
}

- (UIImage *)sendButtonImageHighlighted
{
    return nil;
}

- (CGSize)titleAvatarSize:(UIDeviceOrientation)__unused orientation
{
    return CGSizeZero;
}

- (UIImage *)titleAvatarPlaceholder
{
    return nil;
}

- (UIImage *)titleAvatarPlaceholderGeneric
{
    return nil;
}

- (UIImage *)titleAvatarOverlay:(UIInterfaceOrientation)__unused orientation
{
    return nil;
}

- (UIImage *)unreadCountBadgeImage
{
    return nil;
}

- (UIImage *)chatArrowDownImage
{
    return nil;
}

- (UIImage *)chatArrowUpImage
{
    return nil;
}

- (UIColor *)attachmentPanelBackground
{
    return nil;
}

- (UIImage *)attachmentPanelShadow;
{
    return nil;
}

- (UIImage *)attachmentPanelDivider
{
    return nil;
}

- (UIImage *)attachmentCameraImage
{
    return nil;
}

- (UIImage *)attachmentCameraImageHighlighted
{
    return nil;
}

- (UIImage *)attachmentGalleryImage
{
    return nil;
}

- (UIImage *)attachmentGalleryImageHighlighted
{
    return nil;
}

- (UIImage *)attachmentLocationImage
{
    return nil;
}

- (UIImage *)attachmentLocationImageHighlighted
{
    return nil;
}

- (UIImage *)attachmentAudioImage
{
    return nil;
}

- (UIImage *)attachmentAudioImageHighlighted
{
    return nil;
}

- (UIColor *)membersPanelBackground
{
    return nil;
}

- (UIImage *)membersPanelBackgroundImage
{
    return nil;
}

- (UIImage *)actionBarBackgroundImage
{
    return nil;
}

- (UIImage *)editingDeleteButtonBackground
{
    return nil;
}

- (UIImage *)editingDeleteButtonBackgroundHighlighted
{
    return nil;
}

- (UIImage *)editingDeleteButtonIcon
{
    return nil;
}

- (UIImage *)editingForwardButtonBackground
{
    return nil;
}

- (UIImage *)editingForwardButtonBackgroundHighlighted
{
    return nil;
}

- (UIImage *)editingForwardButtonIcon
{
    return nil;
}

- (UIImage *)inlineButton
{
    return nil;
}

- (UIImage *)inlineButtonHighlighted
{
    return nil;
}

- (UIImage *)headerActionArrowUp
{
    return nil;
}

- (UIImage *)headerActionArrowDown
{
    return nil;
}

- (id<TGAppManager>)applicationManager
{
    return nil;
}

- (id<TGConversationMessageAssetsSource>)messageAssetsSource
{
    return nil;
}

- (bool)shouldAutosavePhotos
{
    return false;
}

- (int)ignoreSaveToGalleryUid
{
    return 0;
}

- (void)updateUnreadCount
{
}

- (void)addUnreadMarkIfNeeded
{
}

#pragma mark - Logic

- (int)offsetFromGMT
{
    return 0;
}

- (void)sendMessageIfAny
{
    
}

- (bool)isAssetUrlOnServer:(NSString *)__unused assetUrl
{
    return false;
}

- (TGImageInputMediaAttachment *)createImageAttachmentFromImage:(UIImage *)__unused image assetUrl:(NSString *)__unused assetUrl
{
    return nil;
}

- (TGVideoInputMediaAttachment *)createVideoAttachmentFromVideo:(NSString *)__unused fileName thumbnailImage:(UIImage *)__unused thumbnailImage duration:(int)__unused duration dimensions:(CGSize)__unused dimensions assetUrl:(NSString *)__unused assetUrl
{
    return nil;
}

- (void)loadMoreHistory
{
}

- (void)loadMoreHistoryDownwards
{
}

- (void)reloadHistoryShortcut
{
}

- (void)userAvatarPressed
{
    
}

- (void)conversationMemberSelected:(int)__unused uid
{
    
}

- (void)messageTypingActivity
{
    
}

- (void)changeConversationTitle:(NSString *)__unused title
{
    
}

- (void)showConversationProfile:(bool)__unused activateCamera activateTitleChange:(bool)__unused activateTitleChange
{
    
}

- (void)openContact:(TGContactMediaAttachment *)__unused contactAttachment
{
}

- (void)doManualRefresh
{
}

- (void)storeConversationState:(NSString *)__unused messageText
{
}

- (void)clearUnreadIfNeeded:(bool)__unused force;
{
}

- (void)unloadOldItemsIfNeeded
{
    
}

- (void)sendMessage:(NSString *)__unused text attachments:(NSArray *)__unused attachments clearText:(bool)__unused clearText
{
}

- (void)sendMediaMessages:(NSArray *)__unused attachments clearText:(bool)__unused clearText
{
}

- (void)retryMessage:(int)__unused mid
{   
}

- (void)retryAllMessages
{
}

- (void)cancelMessageProgress:(int)__unused mid
{
}

- (void)cancelMediaProgress:(id)__unused mediaId
{
}

- (void)forwardMessages:(NSArray *)__unused array
{
}

- (void)deleteMessages:(NSArray *)__unused mids
{
}

- (void)clearAllMessages
{
}

- (void)sendContactRequest
{
}

- (void)acceptContactRequest
{
}

- (void)blockUser
{
}

- (void)unblockUser
{
}

- (void)muteConversation:(bool)__unused mute
{
}

- (void)leaveGroup
{
}

- (void)acceptEncryptionRequest
{
}

- (void)downloadMedia:(TGMessage *)__unused message changePriority:(bool)__unused changePriority
{
}

- (id<TGImageViewControllerCompanion>)createImageViewControllerCompanion:(int)__unused firstItemId reverseOrder:(bool)__unused reverseOrder
{
    return nil;
}

- (id<TGImageViewControllerCompanion>)createGroupPhotoImageViewControllerCompanion:(id<TGMediaItem>)__unused mediaItem
{
    return nil;
}

- (id<TGImageViewControllerCompanion>)createUserPhotoImageViewControllerCompanion:(id<TGMediaItem>)__unused mediaItem
{
    return nil;
}

- (id<TGMediaItem>)createMediaItemFromMessage:(TGMessage *)__unused message author:(TGUser *)__unused author imageInfo:(TGImageInfo *)__unused imageInfo
{
    return nil;
}

- (id<TGMediaItem>)createMediaItemFromAvatarMessage:(TGMessage *)__unused message
{
    return nil;
}

- (id<TGMediaItem>)createMediaItemFromMessage:(TGMessage *)__unused message author:(TGUser *)__unused author videoAttachment:(TGVideoMediaAttachment *)__unused videoAttachment
{
    return nil;
}

- (void)ignoreContactRequest
{
}

@end
