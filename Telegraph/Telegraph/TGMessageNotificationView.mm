#import "TGMessageNotificationView.h"

#import "TGRemoteImageView.h"
#import "TGInterfaceAssets.h"

#import "TGImageUtils.h"

#import "TGNotificationWindow.h"

@interface TGMessageNotificationView ()

@property (nonatomic, strong) UIImageView *backgroundView;
@property (nonatomic, strong) TGRemoteImageView *avatarView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *messageLabel;
@property (nonatomic, strong) UIButton *dismissButton;

@property (nonatomic, strong) NSMutableAttributedString *attributedText;

@end

@implementation TGMessageNotificationView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        
        _backgroundView = [[UIImageView alloc] initWithFrame:CGRectMake(-1, 0, self.bounds.size.width + 2, 45)];
        _backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _backgroundView.image = [TGInterfaceAssets notificationBackground];
        _backgroundView.highlightedImage = [TGInterfaceAssets notificationBackgroundHighlighted];
        [self addSubview:_backgroundView];
        
        float retinaPixel = TGIsRetina() ? 0.5f : 0.0f;
        
        _avatarView = [[TGRemoteImageView alloc] initWithFrame:CGRectMake(4 + retinaPixel, 5 + (TGIsRetina() ? 0.5f : 0.0f), 34, 34)];
        [self addSubview:_avatarView];
        
        _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(4 + 32 + 8 + retinaPixel, 2, self.bounds.size.width - (8 + 32) * 2, 18)];
        _titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.textColor = UIColorRGB(0x363a40);
        _titleLabel.font = [UIFont boldSystemFontOfSize:14];
        _titleLabel.numberOfLines = 1;
        _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self addSubview:_titleLabel];
        
        _messageLabel = [[UILabel alloc] initWithFrame:CGRectMake(4 + 32 + 8 + retinaPixel, 21 + retinaPixel, self.bounds.size.width - (8 + 32) * 2, 18)];
        _messageLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _messageLabel.backgroundColor = [UIColor clearColor];
        _messageLabel.textColor = [UIColor blackColor];
        _messageLabel.font = [UIFont systemFontOfSize:14];
        _messageLabel.numberOfLines = 1;
        _messageLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self addSubview:_messageLabel];
        
        _dismissButton = [[UIButton alloc] initWithFrame:CGRectMake(self.bounds.size.width - 21 - 19 - retinaPixel, 2 + retinaPixel, 40, 40)];
        _dismissButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        _dismissButton.exclusiveTouch = true;
        [_dismissButton setBackgroundImage:[UIImage imageNamed:@"BannerClose.png"] forState:UIControlStateNormal];
        [_dismissButton setBackgroundImage:[UIImage imageNamed:@"BannerClose_Highlighted.png"] forState:UIControlStateHighlighted];
        [self addSubview:_dismissButton];
        
        [_dismissButton addTarget:self action:@selector(dismissButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        
        _titleLabel.userInteractionEnabled = false;
        _messageLabel.userInteractionEnabled = false;
        _avatarView.userInteractionEnabled = false;
        
        _backgroundView.userInteractionEnabled = true;
        UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapGestureRecognized:)];
        [_backgroundView addGestureRecognizer:tapRecognizer];
    }
    return self;
}

- (void)resetView
{
    _titleLabel.text = _titleText;
    
    bool attachmentFound = false;
    
    NSString *messageText = _messageText;
    
    if (_messageAttachments != nil && _messageAttachments.count != 0)
    {
        for (TGMediaAttachment *attachment in _messageAttachments)
        {
            if (attachment.type == TGActionMediaAttachmentType)
            {
                TGActionMediaAttachment *actionAttachment = (TGActionMediaAttachment *)attachment;
                switch (actionAttachment.actionType)
                {
                    case TGMessageActionChatEditTitle:
                    {
                        TGUser *user = [_users objectForKey:@"author"];
                        messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.RenamedChat"), user.displayName];
                        attachmentFound = true;
                        
                        break;
                    }
                    case TGMessageActionChatEditPhoto:
                    {
                        TGUser *user = [_users objectForKey:@"author"];
                        if ([(TGImageMediaAttachment *)[actionAttachment.actionData objectForKey:@"photo"] imageInfo] == nil)
                            messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.RemovedGroupPhoto"), user.displayName];
                        else
                            messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.ChangedGroupPhoto"), user.displayName];
                        attachmentFound = true;
                        
                        break;
                    }
                    case TGMessageActionUserChangedPhoto:
                    {
                        TGUser *user = [_users objectForKey:@"author"];
                        if ([(TGImageMediaAttachment *)[actionAttachment.actionData objectForKey:@"photo"] imageInfo] == nil)
                            messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.RemovedUserPhoto"), user.displayName];
                        else
                            messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.ChangedUserPhoto"), user.displayName];
                        attachmentFound = true;
                        
                        break;
                    }
                    case TGMessageActionChatAddMember:
                    {
                        NSNumber *nUid = [actionAttachment.actionData objectForKey:@"uid"];
                        if (nUid != nil)
                        {
                            TGUser *authorUser = [_users objectForKey:@"author"];
                            TGUser *subjectUser = [_users objectForKey:nUid];
                            if (authorUser.uid == subjectUser.uid)
                                messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.JoinedChat"), authorUser.displayName];
                            else
                                messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.Invited"), authorUser.displayName, subjectUser.displayName];
                            attachmentFound = true;
                        }
                        
                        break;
                    }
                    case TGMessageActionChatDeleteMember:
                    {
                        NSNumber *nUid = [actionAttachment.actionData objectForKey:@"uid"];
                        if (nUid != nil)
                        {
                            TGUser *authorUser = [_users objectForKey:@"author"];
                            TGUser *subjectUser = [_users objectForKey:nUid];
                            if (authorUser.uid == subjectUser.uid)
                                messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.LeftChat"), authorUser.displayName];
                            else
                                messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.Kicked"), authorUser.displayName, subjectUser.displayName];
                            attachmentFound = true;
                        }
                        
                        break;
                    }
                    case TGMessageActionCreateChat:
                    {
                        TGUser *user = [_users objectForKey:@"author"];
                        messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.CreatedChat"), user.displayName];
                        attachmentFound = true;
                        
                        break;
                    }
                    case TGMessageActionContactRegistered:
                    {
                        TGUser *user = [_users objectForKey:@"author"];
                        messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.Joined"), user.displayName];
                        attachmentFound = true;
                        
                        break;
                    }
                    case TGMessageActionEncryptedChatRequest:
                    {
                        messageText = TGLocalized(@"Notification.EncryptedChatRequested");
                        attachmentFound = true;
                        
                        break;
                    }
                    case TGMessageActionEncryptedChatAccept:
                    {
                        messageText = TGLocalized(@"Notification.EncryptedChatAccepted");
                        attachmentFound = true;
                        
                        break;
                    }
                    case TGMessageActionEncryptedChatDecline:
                    {
                        messageText = TGLocalized(@"Notification.EncryptedChatRejected");
                        attachmentFound = true;
                        
                        break;
                    }
                    default:
                        break;
                }
            }
            else if (attachment.type == TGImageMediaAttachmentType)
            {
                messageText = TGLocalized(@"Message.Photo");
                attachmentFound = true;
                break;
            }
            else if (attachment.type == TGVideoMediaAttachmentType)
            {
                messageText = TGLocalized(@"Message.Video");
                attachmentFound = true;
                break;
            }
            else if (attachment.type == TGLocationMediaAttachmentType)
            {
                messageText = TGLocalized(@"Message.Location");
                attachmentFound = true;
                break;
            }
            else if (attachment.type == TGContactMediaAttachmentType)
            {
                messageText = TGLocalized(@"Message.Contact");
                attachmentFound = true;
                break;
            }
        }
    }
    
    if (attachmentFound)
        _messageLabel.textColor = UIColorRGB(0x0779d0);
    else
        _messageLabel.textColor = [UIColor blackColor];
    
    _messageLabel.text = messageText;
    
    float retinaPixel = TGIsRetina() ? 0.5f : 0.0f;
    
    if (_isLocationNotification)
    {
        [_avatarView loadImage:[TGInterfaceAssets locationNotificationIcon]];
        
        _titleLabel.font = [UIFont boldSystemFontOfSize:15];
        _titleLabel.textColor = UIColorRGB(0x363a40);
        _titleLabel.frame = CGRectMake(4 + 32 + 4 + retinaPixel, 10, self.bounds.size.width - (4 + 32) * 2, 18);
    }
    else
    {
        _titleLabel.font = [UIFont boldSystemFontOfSize:14];
        _titleLabel.textColor = [[TGInterfaceAssets instance] userColor:_authorUid];
        
        _titleLabel.frame = CGRectMake(4 + 32 + 8 + retinaPixel, 3 + retinaPixel, self.bounds.size.width - (8 + 32) * 2, 18);
        if (_avatarUrl != nil)
            [_avatarView loadImage:_avatarUrl filter:@"notificationAvatar" placeholder:[TGInterfaceAssets notificationAvatarPlaceholderGeneric]];
        else
            [_avatarView loadImage:[TGInterfaceAssets notificationAvatarPlaceholder:_authorUid]];
    }
}

- (void)searchParentAndDismiss:(UIView *)view
{
    if (view == nil)
        return;
    
    if ([view isKindOfClass:[TGNotificationWindow class]])
    {
        [((TGNotificationWindow *)view) animateOut];
    }
    else
        [self searchParentAndDismiss:view.superview];
}

- (void)searchParentAndTap:(UIView *)view
{
    if (view == nil)
        return;
    
    if ([view isKindOfClass:[TGNotificationWindow class]])
    {
        [((TGNotificationWindow *)view) performTapAction];
    }
    else
        [self searchParentAndTap:view.superview];
}

- (void)dismissButtonPressed
{
    [self searchParentAndDismiss:self.superview];
}

- (void)tapGestureRecognized:(UITapGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateRecognized)
    {
        [self searchParentAndTap:self.superview];
    }
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    _backgroundView.highlighted = true;
    [super touchesBegan:touches withEvent:event];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    _backgroundView.highlighted = false;
    [super touchesEnded:touches withEvent:event];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    _backgroundView.highlighted = false;
    [super touchesCancelled:touches withEvent:event];
}

@end
