#import "TGConversationMessageItemView.h"

#import <QuartzCore/QuartzCore.h>

#import "TGConversationController.h"

#import "TGLayoutItem.h"
#import "TGLayoutTextItem.h"
#import "TGLayoutImageItem.h"
#import "TGLayoutRemoteImageItem.h"
#import "TGLayoutSimpleLabelItem.h"
#import "TGLayoutButtonItem.h"

#import "TGClockProgressView.h"

#import "TGReusableView.h"
#import "TGReusableButton.h"
#import "TGSimpleReusableLabel.h"

#import "TGMediaActionButton.h"

#import "TGDateUtils.h"
#import "TGImageUtils.h"
#import "TGStringUtils.h"

#import "TGDateLabel.h"

#import "TGRemoteImageView.h"
#import "TGImageView.h"

#import "TGWeakDelegate.h"

#include <vector>
#include <map>

#import <pthread.h>

#import <CommonCrypto/CommonDigest.h>

#import "TGDoubleTapGestureRecognizer.h"

#define TG_SYNCHRONIZED_DEFINE(lock) pthread_mutex_t TG_SYNCHRONIZED_##lock
#define TG_SYNCHRONIZED_INIT(lock) pthread_mutex_init(&TG_SYNCHRONIZED_##lock, NULL)
#define TG_SYNCHRONIZED_BEGIN(lock) pthread_mutex_lock(&TG_SYNCHRONIZED_##lock);
#define TG_SYNCHRONIZED_END(lock) pthread_mutex_unlock(&TG_SYNCHRONIZED_##lock);

static TG_SYNCHRONIZED_DEFINE(uidToColor) = PTHREAD_MUTEX_INITIALIZER;
static std::map<int, int> uidToColor;

static bool _displayMids = false;

#define TG_DEBUG_VIEWS 0

static int coloredNameForUid(int uid, int currentUserId)
{
    static const int textColors[] = {
        0xee4928,
        0x41a903,
        0xe09602,
        0x0f94ed,
        0x8f3bf7,
        0xfc4380,
        0x00a1c4,
        0xeb7002,
    };
    
    static const int numColors = (sizeof(textColors) / sizeof(textColors[0]));
    
    int colorIndex = 0;
    
    TG_SYNCHRONIZED_BEGIN(uidToColor);
    std::map<int, int>::iterator it = uidToColor.find(uid);
    if (it != uidToColor.end())
        colorIndex = it->second;
    else
    {
        char buf[16];
        snprintf(buf, 16, "%d%d", uid, currentUserId);
        unsigned char digest[CC_MD5_DIGEST_LENGTH];
        CC_MD5(buf, strlen(buf), digest);
        colorIndex = ABS(digest[ABS(uid % 16)]) % numColors;

        uidToColor.insert(std::pair<int, int>(uid, colorIndex));
    }
    TG_SYNCHRONIZED_END(uidToColor);
    
    return textColors[colorIndex];
}

CGSize sizeForConversationMessage(TGConversationMessageItem *messageItem, int metrics, id<TGConversationMessageAssetsSource> assetsSource)
{
    CGSize size = CGSizeZero;
    
    TGMessage *message = messageItem.message;
    
    TGLayoutModel *layout = (TGLayoutModel *)message.cachedLayoutData;
    if (layout != nil && layout.metrics == metrics)
        size = layout.size;
    else
    {
        layout = [TGConversationMessageItemView layoutModelForMessage:messageItem withMetrics:metrics assetsSource:assetsSource];
        message.cachedLayoutData = layout;
        size = layout.size;
    }
    
    UIEdgeInsets bodyMargins = [assetsSource messageBodyMargins];
    size.width += bodyMargins.left + bodyMargins.right;
    size.height += bodyMargins.top + bodyMargins.bottom;
    
    return size;
}

#pragma mark -

@interface TGConversationMessageItemBackgroundView : UIImageView

@property (nonatomic) bool enableStretching;
@property (nonatomic) UIEdgeInsets stretchInsets;
@property (nonatomic, strong) UIImageView *shadowView;

@end

@implementation TGConversationMessageItemBackgroundView

- (void)setImage:(UIImage *)image
{
    [super setImage:image];
    
    static bool needsStretchingInitialized = false;
    static bool needsStretching = false;
    if (!__builtin_expect(needsStretchingInitialized, true))
    {
        needsStretchingInitialized = true;
        needsStretching = ![UIImage instancesRespondToSelector:@selector(resizableImageWithCapInsets:resizingMode:)];
    }
    
    if (needsStretching)
    {
        if (_enableStretching)
        {
            CGSize imageSize = image.size;
            if (imageSize.width < FLT_EPSILON || imageSize.height < FLT_EPSILON)
                self.contentStretch = CGRectMake(0.0f, 0.0f, 1.0f, 1.0f);
            else
                self.contentStretch = CGRectMake(_stretchInsets.left / imageSize.width, _stretchInsets.top / imageSize.height, 1.0f - (_stretchInsets.left +  _stretchInsets.right) / imageSize.width, 1.0f - (_stretchInsets.top +  _stretchInsets.bottom) / imageSize.height);
        }
    }
}
    
- (void)setShadowImage:(UIImage *)shadowImage
{
    if (_shadowView == nil)
    {
        _shadowView = [[UIImageView alloc] initWithFrame:self.bounds];
        _shadowView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:_shadowView];
    }
    
    _shadowView.image = shadowImage;
}

@end

#pragma mark - Content View

@interface TGConversationItemContentView : UIView

@property (nonatomic, strong) TGLayoutModel *layout;

@end

@implementation TGConversationItemContentView

- (void)drawRect:(CGRect)__unused rect
{
    [_layout drawLayout:false];
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
    CGPoint testPoint = point;
    testPoint.x += 18;
    testPoint.y += 18;
    bool inside = [super pointInside:testPoint withEvent:event];
    if (!inside)
    {
        CGSize size = self.frame.size;
        if (testPoint.x >= 0 && testPoint.x < size.width + 18 && testPoint.y >= 0 && testPoint.y < size.height + 18)
            inside = true;
    }
    
    return inside;
}

@end

@interface TGConversationItemAsyncContentView : UIView

@end

@implementation TGConversationItemAsyncContentView

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
    CGPoint testPoint = point;
    testPoint.x += 18;
    testPoint.y += 18;
    bool inside = [super pointInside:testPoint withEvent:event];
    if (!inside)
    {
        CGSize size = self.frame.size;
        if (testPoint.x >= 0 && testPoint.x < size.width + 18 && testPoint.y >= 0 && testPoint.y < size.height + 18)
            inside = true;
    }
    
    return inside;
}

@end

#pragma mark - Rendering Operation

@interface TGConversationMessageRenderingOperation : NSOperation

@property (atomic, strong) TGLayoutModel *layout;
@property (nonatomic) CGSize size;
@property (atomic, strong) TGWeakDelegate *receiver;

@end

@implementation TGConversationMessageRenderingOperation

- (void)main
{
    if (self.isCancelled)
        return;
    
    @autoreleasepool
    {
        UIGraphicsBeginImageContextWithOptions(_size, false, 0);
        
        if (self.isCancelled)
        {
            UIGraphicsEndImageContext();
            
            return;
        }

        [_layout drawLayout:false];
        
        if (self.isCancelled)
        {
            UIGraphicsEndImageContext();
            
            return;
        }
        
        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        if (!self.isCancelled)
        {
            if ([[NSThread currentThread] isMainThread])
            {
                __autoreleasing UIView *receiver = self.receiver.object;
                if (receiver != nil)
                    receiver.layer.contents = (id)(image.CGImage);            
            }
            else
            {
                dispatch_async(dispatch_get_main_queue(), ^
                {
                    __autoreleasing UIView *receiver = self.receiver.object;
                    if (receiver != nil)
                        receiver.layer.contents = (id)(image.CGImage);
                });
            }
        }
        else
        {
            TGLog(@"Cancelled");
        }
    }
}

- (void)cancel
{
    self.receiver = nil;
    
    [super cancel];
}

@end

#pragma mark - Message Item View

@interface TGConversationMessageItemView () <UIGestureRecognizerDelegate, TGDoubleTapGestureRecognizerDelegate>

@property (nonatomic, strong) TGWeakDelegate *asyncContainerWeakDelegate;
@property (nonatomic, strong) TGConversationMessageRenderingOperation *renderingOperation;

@property (nonatomic) int validMetrics;

@property (nonatomic) bool isReallyEditing;

@property (nonatomic, strong) UIImageView *checkView;
@property (nonatomic, strong) UIImageView *editingSeparatorViewBottom;
@property (nonatomic, strong) UIGestureRecognizer *cellTapRecognizer;

@property (nonatomic, strong) UIView *cellBackgroundView;
@property (nonatomic, strong) TGConversationMessageItemBackgroundView *messageNormalBackgroundView;
@property (nonatomic, strong) TGConversationMessageItemBackgroundView *messageHighlightedBackgroundView;
@property (nonatomic, strong) UIImageView *messageHighlightedForegroundView;
@property (nonatomic, strong) TGConversationItemContentView *contentContainer;
@property (nonatomic, strong) UIView *asyncContentContainer;
@property (nonatomic, strong) NSMutableArray *linkHighlightedViews;
@property (nonatomic, strong) UIImageView *dateBackgroundView;
@property (nonatomic, strong) TGDateLabel *dateLabel;
@property (nonatomic, strong) TGRemoteImageView *avatarView;

@property (nonatomic, strong) UIView *statusContainerView;
@property (nonatomic, strong) TGClockProgressView *animatedDeliveryStatusView;
@property (nonatomic, strong) UIImageView *deliveryStatusViewFirst;
@property (nonatomic, strong) UIImageView *deliveryStatusViewFirstBackground;
@property (nonatomic, strong) UIImageView *deliveryStatusViewSecond;
@property (nonatomic, strong) UIImageView *deliveryStatusViewFailed;

@property (nonatomic, strong) TGDoubleTapGestureRecognizer *contentDoubleTapRecognizer;
@property (nonatomic, strong) TGDoubleTapGestureRecognizer *asyncContentDoubleTapRecognizer;

@property (nonatomic, strong) TGReusableView *uploadProgressContainer;
@property (nonatomic, strong) UIImageView *uploadProgressBackground;
@property (nonatomic, strong) UIImageView *uploadProgressForeground;
@property (nonatomic, strong) UIButton *uploadProgressCancelButton;
@property (nonatomic) float uploadProgress;

@property (nonatomic) bool mediaNeedsDownload;
@property (nonatomic, strong) TGMediaActionButton *mediaActionButton;
@property (nonatomic) int mediaSize;

@end

@implementation TGConversationMessageItemView

+ (NSOperationQueue *)backgroundDrawingQueue
{
    static NSOperationQueue *queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        queue = [[NSOperationQueue alloc] init];
        [queue setMaxConcurrentOperationCount:1];
    });
    return queue;
}

+ (void)clearColorMapping
{
    TG_SYNCHRONIZED_BEGIN(uidToColor);
    uidToColor.clear();
    TG_SYNCHRONIZED_END(uidToColor);
}

+ (void)setDisplayMids:(bool)displayMids
{
    _displayMids = displayMids;
}

+ (bool)displayMids
{
    return _displayMids;
}

#if TGUseCollectionView
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
#else
- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
#endif
    if (self)
    {
        self.clipsToBounds = false;
        
        _messageNormalBackgroundView = [[TGConversationMessageItemBackgroundView alloc] init];
        [self.contentView addSubview:_messageNormalBackgroundView];
        
        _contentContainer = [[TGConversationItemContentView alloc] init];
        _contentContainer.exclusiveTouch = true;
        _contentContainer.backgroundColor = nil;
        _contentContainer.opaque = false;
        
        _contentContainer.clipsToBounds = false;
        
        _cellTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(cellTapped:)];
        _cellTapRecognizer.enabled = false;
        [self addGestureRecognizer:_cellTapRecognizer];
        
        _contentDoubleTapRecognizer = [[TGDoubleTapGestureRecognizer alloc] initWithTarget:self action:@selector(containerDoubleTapped:)];
        _contentDoubleTapRecognizer.consumeSingleTap = true;
        _contentDoubleTapRecognizer.delegate = self;
        [_contentContainer addGestureRecognizer:_contentDoubleTapRecognizer];
        UILongPressGestureRecognizer *contentLongPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(containerLongPressed:)];
        contentLongPressRecognizer.minimumPressDuration = 0.3;
        [_contentContainer addGestureRecognizer:contentLongPressRecognizer];
        
#if TG_DEBUG_VIEWS
        if (false)
#endif
        [self.contentView addSubview:_contentContainer];
        
        _asyncContentContainer = [[TGConversationItemAsyncContentView alloc] init];
        _asyncContentContainer.exclusiveTouch = true;
        _asyncContentContainer.backgroundColor = nil;
        _asyncContentContainer.opaque = false;
        
        //UIGestureRecognizer *asyncContentTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(containerTapped:)];
        //[_asyncContentContainer addGestureRecognizer:asyncContentTapRecognizer];
        _asyncContentDoubleTapRecognizer = [[TGDoubleTapGestureRecognizer alloc] initWithTarget:self action:@selector(containerDoubleTapped:)];
        _asyncContentDoubleTapRecognizer.consumeSingleTap = true;
        _asyncContentDoubleTapRecognizer.delegate = self;
        [_asyncContentContainer addGestureRecognizer:_asyncContentDoubleTapRecognizer];
        //[asyncContentTapRecognizer requireGestureRecognizerToFail:_asyncContentDoubleTapRecognizer];
        UILongPressGestureRecognizer *asyncContentLongPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(asyncContainerLongPressed:)];
        asyncContentLongPressRecognizer.minimumPressDuration = 0.3;
        [_asyncContentContainer addGestureRecognizer:asyncContentLongPressRecognizer];
        
#if TG_DEBUG_VIEWS
        if (false)
#endif
        [self.contentView addSubview:_asyncContentContainer];
        
        float retinaPixel = TGIsRetina() ? 0.5f : 0.0f;
        
        _dateBackgroundView = [[UIImageView alloc] init];

#if !TG_DEBUG_VIEWS
        [self.contentView addSubview:_dateBackgroundView];
#endif
        
        _dateLabel = [[TGDateLabel alloc] init];
        _dateLabel.backgroundColor = [UIColor clearColor];
        _dateLabel.userInteractionEnabled = false;
        UIFont *dateFont = [TGGlobalAssetsSource messageDateFont];
        _dateLabel.dateFont = dateFont;
        _dateLabel.dateTextFont = dateFont;
        _dateLabel.dateLabelFont = [TGGlobalAssetsSource messageDateAMPMFont];
        _dateLabel.amWidth = 15;
        _dateLabel.pmWidth = 15;
        _dateLabel.dstOffset = 1 + retinaPixel;
        _dateLabel.textColor = [TGGlobalAssetsSource messageDateColor];
        _dateLabel.shadowColor = [TGGlobalAssetsSource messageDateShadowColor];
        _dateLabel.shadowOffset = CGSizeMake(0, 1);
        
#if !TG_DEBUG_VIEWS
        [self.contentView addSubview:_dateLabel];
#endif
        
        UIImage *unsentBadge = [TGGlobalAssetsSource messageUnsentBadge];
        
        _statusContainerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, unsentBadge.size.width, 20)];
        _statusContainerView.opaque = false;
        
#if TG_DEBUG_VIEWS
        if (false)
#endif
        [self.contentView addSubview:_statusContainerView];
        
        _deliveryStatusViewFirst = [[UIImageView alloc] initWithImage:[TGGlobalAssetsSource messageCheckmarkFullIcon]];
        _deliveryStatusViewFirst.frame = CGRectOffset(_deliveryStatusViewFirst.frame, 35, 4 + retinaPixel);
        _deliveryStatusViewFirst.userInteractionEnabled = false;
        [_statusContainerView addSubview:_deliveryStatusViewFirst];
        
        _deliveryStatusViewFirstBackground = [[UIImageView alloc] initWithImage:[TGGlobalAssetsSource messageCheckmarkHalfIcon]];
        _deliveryStatusViewFirstBackground.frame = _deliveryStatusViewFirst.frame;
        _deliveryStatusViewFirstBackground.userInteractionEnabled = false;
        [_statusContainerView addSubview:_deliveryStatusViewFirstBackground];
        
        _deliveryStatusViewSecond = [[UIImageView alloc] initWithImage:[TGGlobalAssetsSource messageCheckmarkFullIcon]];
        _deliveryStatusViewSecond.frame = CGRectOffset(_deliveryStatusViewSecond.frame, 31, 4 + retinaPixel);
        _deliveryStatusViewSecond.userInteractionEnabled = false;
        [_statusContainerView addSubview:_deliveryStatusViewSecond];
        
        _deliveryStatusViewFailed = [[UIImageView alloc] initWithImage:unsentBadge];
        _deliveryStatusViewFailed.frame = CGRectOffset(_deliveryStatusViewFailed.frame, 0, -retinaPixel);
        UITapGestureRecognizer *statusTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(deliveryStatusTapped:)];
        [_deliveryStatusViewFailed addGestureRecognizer:statusTapRecognizer];
        _deliveryStatusViewFailed.userInteractionEnabled = true;
        [_statusContainerView addSubview:_deliveryStatusViewFailed];
        
        TGClockProgressView *progressView = [[TGClockProgressView alloc] initWithFrame:CGRectMake(31, 2, 15, 15)];
        [_statusContainerView addSubview:progressView];
        
        _animatedDeliveryStatusView = progressView;
        
        _asyncContainerWeakDelegate = [[TGWeakDelegate alloc] init];
    }
    return self;
}

- (void)dealloc
{
    _asyncContainerWeakDelegate.object = nil;
    
    if (_renderingOperation != nil)
    {
        [_renderingOperation cancel];
        _renderingOperation = nil;
    }
}

- (void)discardContent
{
    if (_renderingOperation != nil)
    {
        [_renderingOperation cancel];
        _renderingOperation = nil;
    }
    
    _asyncContentContainer.layer.contents = nil;
    
    if (_contentContainer.subviews.count != 0)
    {
        while (_contentContainer.subviews.count > 0)
        {
            UIView *subview = [_contentContainer.subviews lastObject];
            [_viewRecycler recycleView:(UIView<TGReusableView> *)subview];
            [subview removeFromSuperview];
        }
    }
    if (_asyncContentContainer.subviews.count != 0)
    {
        while (_asyncContentContainer.subviews.count > 0)
        {
            UIView *subview = [_asyncContentContainer.subviews lastObject];
            [_viewRecycler recycleView:(UIView<TGReusableView> *)subview];
            [subview removeFromSuperview];
        }
    }
    
    if (_uploadProgressContainer != nil)
    {
        [_uploadProgressContainer removeFromSuperview];
        [_viewRecycler recycleView:_uploadProgressContainer];
        
        [_uploadProgressCancelButton removeTarget:self action:@selector(uploadCancelButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        
        _uploadProgressContainer = nil;
        _uploadProgressCancelButton = nil;
        _uploadProgressForeground = nil;
        _uploadProgressBackground = nil;
    }
    
    if (_mediaActionButton != nil)
    {
        [_mediaActionButton removeFromSuperview];
        _mediaActionButton.hidden = false;
        _mediaActionButton.alpha = 1.0f;
        [_viewRecycler recycleView:(UIView<TGReusableView> *)_mediaActionButton];
        
        [_mediaActionButton removeTarget:self action:@selector(mediaActionButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        
        _mediaActionButton = nil;
    }
    
    _mediaSize = 0;
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animate
{
    bool wasReallyEditing = _isReallyEditing;
    bool isAction = _message.actionInfo != nil;
    _isReallyEditing = editing && !isAction;
    
    if (_editingSeparatorViewBottom == nil && editing)
    {
        _editingSeparatorViewBottom = [[UIImageView alloc] initWithImage:[TGGlobalAssetsSource messageEditingSeparator]];
        _editingSeparatorViewBottom.alpha = 0.0f;
        _editingSeparatorViewBottom.hidden = true;
        
        [self addSubview:_editingSeparatorViewBottom];
    }
    
    if (!isAction && (_checkView == nil || _isReallyEditing != !_checkView.hidden))
    {
        int indentX = _isReallyEditing && (!_message.outgoing || _message.actionInfo != nil) ? 35 : 0;
        
        UIView *contentView = self.contentView;
        CGRect frame = self.frame;
        frame.origin.x = indentX;
        frame.origin.y = 0;
        frame.size.width -= indentX;
        
        CGRect checkFrameBefore = CGRectMake(wasReallyEditing ? 2 : -35, (int)((self.contentView.frame.size.height - 35) / 2) - 1, 35, 35);
        CGRect checkFrameAfter = CGRectMake(_isReallyEditing ? 2 : -35, (int)((self.contentView.frame.size.height - 35) / 2) - 1, 35, 35);
        
        if (_checkView == nil && _isReallyEditing)
        {
            _checkView = [[UIImageView alloc] initWithFrame:checkFrameBefore];
            _checkView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
            [self addSubview:_checkView];
        }
        
        _checkView.image = _isSelected ? [TGGlobalAssetsSource messageChecked] : [TGGlobalAssetsSource messageUnchecked];
        
        if (!_isReallyEditing)
            _isSelected = false;

        _checkView.frame = checkFrameBefore;
        
        if (animate)
        {
            if (_isReallyEditing)
            {
                _checkView.hidden = false;
                _editingSeparatorViewBottom.hidden = false;
                
                _cellBackgroundView.alpha = 0.0f;
            }
            
            _checkView.alpha = _isReallyEditing ? 0.0f : 1.0f;
            [UIView animateWithDuration:_isReallyEditing ? 0.3 : 0.25 animations:^
            {
                _checkView.alpha = _isReallyEditing ? 1.0f : 0.0f;
                _checkView.frame = checkFrameAfter;
                contentView.frame = frame;
                _statusContainerView.alpha = _isReallyEditing ? 0.0f : 1.0f;
                _dateLabel.alpha = _isReallyEditing ? 0.0f : 1.0f;
                _dateBackgroundView.alpha = _isReallyEditing ? 0.0f : 1.0f;
                _editingSeparatorViewBottom.alpha = _isReallyEditing ? 1.0f : 0.0f;
                
                _cellBackgroundView.alpha = _isReallyEditing ? 1.0f : 0.0f;
                
                if (_uploadProgressContainer != nil)
                    [self layoutProgress];
            } completion:^(__unused BOOL finished)
            {
                _checkView.hidden = !_isReallyEditing;
                _editingSeparatorViewBottom.hidden = !_isReallyEditing;
                
                if (!_isReallyEditing)
                    _cellBackgroundView.hidden = true;
            }];
            
            [self setNeedsLayout];
            [self layoutIfNeeded];
        }
        else
        {
            contentView.frame = frame;
            _checkView.alpha = _isReallyEditing ? 1.0f : 0.0f;
            _checkView.hidden = !_isReallyEditing;
            _checkView.frame = checkFrameAfter;
            _statusContainerView.alpha = _isReallyEditing ? 0.0f : 1.0f;
            _dateLabel.alpha = _isReallyEditing ? 0.0f : 1.0f;
            _dateBackgroundView.alpha = _isReallyEditing ? 0.0f : 1.0f;
            _editingSeparatorViewBottom.alpha = _isReallyEditing ? 1.0f : 0.0f;
            _editingSeparatorViewBottom.hidden = !_isReallyEditing;
            
            if (_cellBackgroundView != nil)
            {
                if (!_isReallyEditing)
                    _cellBackgroundView.hidden = true;
                
                _cellBackgroundView.alpha = _isReallyEditing ? 1.0f : 0.0f;
            }
        }
        
        _cellTapRecognizer.enabled = _isReallyEditing;
        self.contentView.userInteractionEnabled = !_isReallyEditing;
    }
    else
    {
        _statusContainerView.alpha = _isReallyEditing ? 0.0f : 1.0f;
    }
    
    if (isAction && editing != !_editingSeparatorViewBottom.hidden)
    {
        if (animate)
        {
            if (editing)
                _editingSeparatorViewBottom.hidden = false;
            
            [UIView animateWithDuration:editing ? 0.3 : 0.25 animations:^
            {
                _editingSeparatorViewBottom.alpha = editing ? 1.0f : 0.0f;
            } completion:^(BOOL finished)
            {
                if (finished)
                {
                    _editingSeparatorViewBottom.hidden = !editing;
                }
            }];
            
            [self setNeedsLayout];
            [self layoutIfNeeded];
        }
        else
        {
            _editingSeparatorViewBottom.alpha = editing ? 1.0f : 0.0f;
            _editingSeparatorViewBottom.hidden = !editing;
        }
    }
    
#if !TGUseCollectionView
    [super setEditing:editing animated:animate];
#endif
}

- (void)setIsContextSelected:(bool)isContextSelected
{
    [self setIsContextSelected:isContextSelected animated:false];
}

- (void)setIsContextSelected:(bool)isContextSelected animated:(bool)animated
{
    if (isContextSelected != _isContextSelected)
    {
        _isContextSelected = isContextSelected;
        
        if (isContextSelected && _messageHighlightedBackgroundView == nil)
        {
            _messageHighlightedBackgroundView = [[TGConversationMessageItemBackgroundView alloc] init];
            _messageHighlightedBackgroundView.alpha = 0.0f;
            _messageHighlightedBackgroundView.frame = _messageNormalBackgroundView.frame;
            _messageHighlightedBackgroundView.hidden = _messageNormalBackgroundView.hidden;
            [self.contentView insertSubview:_messageHighlightedBackgroundView aboveSubview:_messageNormalBackgroundView];
            [self updateBackground:_message.cachedLayoutData];
        }
        
        if (isContextSelected)
        {
            if (_messageHighlightedForegroundView == nil && ((TGLayoutModel *)_message.cachedLayoutData).hideBackground)
            {
                static UIImage *highlightedOverlayImage = nil;
                if (highlightedOverlayImage == nil)
                {
                    UIImage *rawImage = [UIImage imageNamed:@"MsgAttachmentHighlightedOverlay.png"];
                    highlightedOverlayImage = [rawImage stretchableImageWithLeftCapWidth:(int)(rawImage.size.width / 2) topCapHeight:(int)(rawImage.size.height / 2)];
                }
                _messageHighlightedForegroundView = [[UIImageView alloc] initWithImage:highlightedOverlayImage];
            }
        }
        
        if (isContextSelected && _messageHighlightedBackgroundView.superview == nil)
        {
            [self.contentView insertSubview:_messageHighlightedBackgroundView aboveSubview:_messageNormalBackgroundView];
        }
        
        if (isContextSelected && ((TGLayoutModel *)_message.cachedLayoutData).hideBackground && _message.actionInfo == nil)
        {
            if (_messageHighlightedForegroundView.superview == nil)
            {
                CGRect foregroundFrame = _messageNormalBackgroundView.frame;
                foregroundFrame.origin.y += 3;
                foregroundFrame.size.height -= 5.5f;
                foregroundFrame.origin.x += _message.outgoing ? 3.5f : 7.5f;
                foregroundFrame.size.width -= 11;
                _messageHighlightedForegroundView.frame = foregroundFrame;
                [self.contentView addSubview:_messageHighlightedForegroundView];
            }
        }
        
        if (animated && !isContextSelected)
        {
            _messageNormalBackgroundView.alpha = 1.0f;
            _messageHighlightedBackgroundView.shadowView.alpha = 0.0f;
            
            [UIView animateWithDuration:0.3 animations:^
            {
                _messageHighlightedBackgroundView.alpha = 0.0f;
            } completion:^(BOOL finished)
            {
                if (finished)
                {
                    [_messageHighlightedBackgroundView removeFromSuperview];
                }
            }];
            
            _messageHighlightedForegroundView.alpha = 1.0f;
            [UIView animateWithDuration:0.3 animations:^
            {
                _messageHighlightedForegroundView.alpha = 0.0f;
            } completion:^(BOOL finished)
            {
                if (finished)
                {
                    [_messageHighlightedForegroundView removeFromSuperview];
                }
            }];
        }
        else
        {
            _messageNormalBackgroundView.alpha = isContextSelected ? 0.0f : 1.0f;
            _messageHighlightedBackgroundView.alpha = isContextSelected ? 1.0f : 0.0f;
            _messageHighlightedForegroundView.alpha = isContextSelected ? 1.0f : 0.0f;
            
            _messageHighlightedBackgroundView.shadowView.alpha = 1.0f;
            
            if (!isContextSelected)
            {
                [_messageHighlightedBackgroundView removeFromSuperview];
                [_messageHighlightedForegroundView removeFromSuperview];
            }
        }
    }
}

- (void)beginBackgroundRendering
{
    if (_renderingOperation != nil)
    {
        [_renderingOperation cancel];
        _renderingOperation = nil;
    }
    
    int metrics = 0;
    if (self.frame.size.width <= 321)
        metrics |= TGConversationMessageMetricsPortrait;
    else
        metrics |= TGConversationMessageMetricsLandscape;
    
    if (_showAvatar)
        metrics |= TGConversationMessageMetricsShowAvatars;
    
    TGLayoutModel *layout = (TGLayoutModel *)_message.cachedLayoutData;
    if (layout == nil || layout.metrics != metrics)
    {
        layout = [TGConversationMessageItemView layoutModelForMessage:_messageItem withMetrics:metrics assetsSource:TGGlobalAssetsSource];
        _message.cachedLayoutData = layout;
    }
    
    if (layout == nil)
    {
        TGLog(@"%s:%d: warning: message layout is nil", __PRETTY_FUNCTION__, __LINE__);
        return;
    }
    
    _renderingOperation = [[TGConversationMessageRenderingOperation alloc] init];
    _renderingOperation.threadPriority = 0.4f;
    _asyncContainerWeakDelegate.object = _asyncContentContainer;
    _renderingOperation.receiver = _asyncContainerWeakDelegate;
    _renderingOperation.layout = layout;
    _renderingOperation.size = _asyncContentContainer.frame.size;
    [[TGConversationMessageItemView backgroundDrawingQueue] addOperation:_renderingOperation];
}

- (void)doForegroundRendering
{
    if (_renderingOperation != nil)
    {
        [_renderingOperation cancel];
        _renderingOperation = nil;
    }
    
    int metrics = 0;
    if (self.frame.size.width <= 321)
        metrics |= TGConversationMessageMetricsPortrait;
    else
        metrics |= TGConversationMessageMetricsLandscape;
    
    if (_showAvatar)
        metrics |= TGConversationMessageMetricsShowAvatars;
    
    TGLayoutModel *layout = (TGLayoutModel *)_message.cachedLayoutData;
    if (layout == nil || layout.metrics != metrics)
    {
        layout = [TGConversationMessageItemView layoutModelForMessage:_messageItem withMetrics:metrics assetsSource:TGGlobalAssetsSource];
        _message.cachedLayoutData = layout;
    }
    
    if (layout == nil)
    {
        TGLog(@"%s:%d: warning: message layout is nil", __PRETTY_FUNCTION__, __LINE__);
        return;
    }
    
    _renderingOperation = [[TGConversationMessageRenderingOperation alloc] init];
    _renderingOperation.threadPriority = 0.4f;
    _asyncContainerWeakDelegate.object = _asyncContentContainer;
    _renderingOperation.receiver = _asyncContainerWeakDelegate;
    _renderingOperation.layout = layout;
    _renderingOperation.size = _asyncContentContainer.frame.size;
    [_renderingOperation start];
    _renderingOperation = nil;
}

#pragma mark -

+ (TGLayoutModel *)layoutModelForMessage:(TGConversationMessageItem *)messageItem withMetrics:(int)metrics assetsSource:(id<TGConversationMessageAssetsSource>)assetsSource
{
    TGMessage *message = messageItem.message;
    bool isAction = message.actionInfo != nil;
    
    TGLayoutModel *layout = [[TGLayoutModel alloc] init];
    
    UIEdgeInsets bodyPaddings = message.outgoing ? [assetsSource messageBodyPaddingsOutgoing] : [assetsSource messageBodyPaddingsIncoming];
    CGSize minimalBodySize = [assetsSource messageMinimalBodySize];
    layout.metrics = metrics;
    
    if (isAction)
        bodyPaddings = UIEdgeInsetsMake(0, 0, 0, 0);
    
    CGSize size = CGSizeZero;
    
    int maxWidth = 250;
    int maxImageWidth = maxWidth;
    
    if ((metrics & TGConversationMessageMetricsLandscape) != 0)
        maxWidth = 395;
    
    if (isAction)
    {
        maxWidth = 310;
        if ((metrics & TGConversationMessageMetricsLandscape) != 0)
            maxWidth = 470;
    }
    else
    {
        if ((metrics & TGConversationMessageMetricsShowAvatars) && !message.outgoing)
        {
            maxWidth -= 40;
            maxImageWidth -= 40;
        }
    }
    
    if (!isAction && message.outgoing)
    {
        maxWidth -= 12;
        maxImageWidth -= 12;
    }
    
    maxWidth -= bodyPaddings.left + bodyPaddings.right;
    
    int nextItemTag = 1000;
    [TGConversationMessageItemView recursiveCreateLayoutForMessage:messageItem onLevel:0 minSize:CGSizeMake(minimalBodySize.width - bodyPaddings.left - bodyPaddings.right, minimalBodySize.height) maxWidth:maxWidth maxImageWidth:maxImageWidth into:layout nextItemTag:&nextItemTag currentSize:&size assetsSource:assetsSource];
    
    bool hasImage = false;
    bool disableDoubleTap = false;
    
    NSArray *attachments = message.mediaAttachments;
    if (attachments != nil && attachments.count != 0)
    {
        int attachmentsCount = attachments.count;
        for (int iAttachment = 0; iAttachment < attachmentsCount; iAttachment++)
        {
            TGMediaAttachment *attachment = [attachments objectAtIndex:iAttachment];
            
            switch (attachment.type)
            {
                case TGImageMediaAttachmentType:
                case TGVideoMediaAttachmentType:
                case TGLocationMediaAttachmentType:
                {
                    hasImage = true;
                    break;
                }
                case TGActionMediaAttachmentType:
                {
                    if (((TGActionMediaAttachment *)attachment).actionType == TGMessageActionChatEditPhoto)
                        hasImage = true;
                    break;
                }
                case TGContactMediaAttachmentType:
                {
                    disableDoubleTap = true;
                    break;
                }
                default:
                    break;
            }
        }
    }
    
    if (!hasImage)
    {
        size.width += bodyPaddings.left + bodyPaddings.right;
        size.height += bodyPaddings.bottom + bodyPaddings.top;
    }
    else
    {
        size.width += 3;
        size.height += bodyPaddings.bottom + bodyPaddings.top - 1;
    }
    
    if (size.width < minimalBodySize.width)
        size.width = minimalBodySize.width;
    if (size.height < minimalBodySize.height)
        size.height = minimalBodySize.height;
    
    layout.hideBackground = hasImage;
    layout.disableDoubleTap = disableDoubleTap;
    
    layout.size = size;
    
    return layout;
}

+ (void)recursiveCreateLayoutForMessage:(TGConversationMessageItem *)messageItem onLevel:(int)level minSize:(CGSize)minSize maxWidth:(int)maxWidth maxImageWidth:(int)maxImageWidth into:(TGLayoutModel *)layout nextItemTag:(int *)nextItemTag currentSize:(CGSize *)currentSize assetsSource:(id<TGConversationMessageAssetsSource>)assetsSource
{
    if (messageItem == nil)
    {
        TGLog(@"Warning: message is nil");
        return;
    }
    
    CGSize size = *currentSize;
    
    int metrics = layout.metrics;
    
    bool isRetina = TGIsRetina();
    float retinaPixel = isRetina ? 0.5f : 0.0f;
    int textOffsetY = 0;
    int textSizeOffsetY = 1;
    if (!isRetina)
    {
        textSizeOffsetY = 2;
    }
    
    int imagePaddingTop = -4;
    int imagePaddingBottom = -4;
    
    UIEdgeInsets bodyPaddings = UIEdgeInsetsZero;
    
    if (level > 0)
    {   
        bodyPaddings.left += level * 9;
        bodyPaddings.top = 0;
        bodyPaddings.bottom = 0;
        bodyPaddings.right = 2;
    }
    
    TGMessage *message = messageItem.message;
    TGActionMediaAttachment *messageAction = message.actionInfo;
    NSArray *attachments = message.mediaAttachments;
    NSString *messageText = message.text;
    NSArray *customTextCheckingResults = nil;
    
    if (messageAction != nil)
    {
        bodyPaddings.left += 8;
    }
    
    bool messageOutgoing = message.outgoing;
    
    int maxTextWidth = (int)(maxWidth - bodyPaddings.left - bodyPaddings.right);
    int minTextWidth = (int)(minSize.width - bodyPaddings.left - bodyPaddings.right);
    
    maxImageWidth = (int)(maxImageWidth - bodyPaddings.left - bodyPaddings.right);
    
    size.height += bodyPaddings.top;
    
    int lastAttachmentType = INT_MAX;
    
    if (messageAction != nil)
    {
        if (messageAction.actionType == TGMessageActionChatAddMember || messageAction.actionType == TGMessageActionChatDeleteMember)
        {
            NSNumber *nUid = [[messageAction actionData] objectForKey:@"uid"];
            TGUser *user = nUid != nil ? [messageItem.messageUsers objectForKey:nUid] : nil;
            
            NSRange authorNameRange = NSMakeRange(NSNotFound, 0);
            NSRange userNameRange = NSMakeRange(NSNotFound, 0);

            NSString *actionText = nil;
            if (user.uid == messageItem.author.uid)
            {
                NSString *userDisplayName = user.displayName;
                actionText = [[NSString alloc] initWithFormat:messageAction.actionType == TGMessageActionChatAddMember ? TGLocalizedStatic(@"Notification.JoinedChat") : TGLocalizedStatic(@"Notification.LeftChat"), userDisplayName];
                userNameRange = NSMakeRange(0, userDisplayName.length);
            }
            else
            {
                NSString *userDisplayName = user.displayName;
                NSString *authorDisplayName = messageItem.author.displayName;
                actionText = [[NSString alloc] initWithFormat:messageAction.actionType == TGMessageActionChatAddMember ? TGLocalizedStatic(@"Notification.Invited") : TGLocalizedStatic(@"Notification.Kicked"), authorDisplayName, userDisplayName];
                authorNameRange = NSMakeRange(0, authorDisplayName.length);
                userNameRange = NSMakeRange(actionText.length - userDisplayName.length, userDisplayName.length);
            }
            
            NSArray *textCheckingResults = nil;
            
            if (authorNameRange.length > 0 && userNameRange.length > 0)
            {
                NSTextCheckingResult *authorResult = [NSTextCheckingResult linkCheckingResultWithRange:authorNameRange URL:[[NSURL alloc] initWithString:[[NSString alloc] initWithFormat:@"user://%d", messageItem.author.uid]]];
                NSTextCheckingResult *userResult = [NSTextCheckingResult linkCheckingResultWithRange:userNameRange URL:[[NSURL alloc] initWithString:[[NSString alloc] initWithFormat:@"user://%d", user.uid]]];
                
                textCheckingResults = [[NSArray alloc] initWithObjects:authorResult, userResult, nil];
            }
            else if (userNameRange.length > 0)
            {
                NSTextCheckingResult *userResult = [NSTextCheckingResult linkCheckingResultWithRange:userNameRange URL:[[NSURL alloc] initWithString:[[NSString alloc] initWithFormat:@"user://%d", user.uid]]];
                textCheckingResults = [[NSArray alloc] initWithObjects:userResult, nil];                
            }
            
            CTFontRef titleFont = [assetsSource messageActionTitleFont];
            TGReusableLabelLayoutData *titleLayoutData = [TGReusableLabel calculateLayout:actionText additionalAttributes:nil textCheckingResults:textCheckingResults font:titleFont textColor:[assetsSource messageActionTextColor] frame:CGRectZero orMaxWidth:maxTextWidth - 10 flags:TGReusableLabelLayoutMultiline textAlignment:UITextAlignmentCenter];
            
            CGSize titleTextSize = titleLayoutData.size;
            if (titleTextSize.width < minTextWidth)
                titleTextSize.width = minTextWidth;
            titleTextSize.width = ceilf(titleTextSize.width);
            titleTextSize.height = ceilf(titleTextSize.height);
            
            float actionSize = titleTextSize.width;
            
            TGLayoutTextItem *titleTextItem = [[TGLayoutTextItem alloc] initWithRichText:actionText font:titleFont textColor:[assetsSource messageActionTextColor] shadowColor:[assetsSource messageActionShadowColor] shadowOffset:CGSizeMake(0, 1)];
            titleTextItem.manualDrawing = true;
            titleTextItem.frame = CGRectMake(bodyPaddings.left + (int)((actionSize - titleTextSize.width) / 2), size.height + textOffsetY + 3, titleTextSize.width, titleTextSize.height);
            titleTextItem.precalculatedLayout = titleLayoutData;
            titleTextItem.tag = (*nextItemTag);
            (*nextItemTag) = (*nextItemTag) + 1;
            
            TGLayoutImageItem *imageItem = [[TGLayoutImageItem alloc] initWithImage:[assetsSource systemMessageBackground]];
            imageItem.manualDrawing = true;
            CGRect imageFrame = CGRectInset(titleTextItem.frame, -8, 0);
            imageFrame.size.height += 4;
            if (imageFrame.size.height > 21)
                imageFrame.size.height += 3;
            imageFrame.origin.y -= 1 + retinaPixel;
            if (imageFrame.size.height < 21)
                imageFrame.size.height = 21;
            imageItem.frame = imageFrame;
            imageItem.tag = (*nextItemTag);
            (*nextItemTag) = (*nextItemTag) + 1;
            [layout addLayoutItem:imageItem];
            
            [layout addLayoutItem:titleTextItem];
            
            size.width = MAX(bodyPaddings.left + titleTextSize.width, size.width);
            size.width = MAX(imageFrame.size.width, size.width);
            size.height += titleTextSize.height + 16;
            
            lastAttachmentType = -1;
        }
        else if (messageAction.actionType == TGMessageActionContactRegistered)
        {
            NSString *actionText = [[NSString alloc] initWithFormat:TGLocalizedStatic(@"Notification.Joined"), messageItem.author.displayName];
            
            CTFontRef titleFont = [assetsSource messageActionTitleFont];
            TGReusableLabelLayoutData *titleLayoutData = [TGReusableLabel calculateLayout:actionText additionalAttributes:nil textCheckingResults:nil font:titleFont textColor:[assetsSource messageActionTextColor] frame:CGRectZero orMaxWidth:maxTextWidth - 10 flags:TGReusableLabelLayoutMultiline textAlignment:UITextAlignmentCenter];
            
            CGSize titleTextSize = titleLayoutData.size;
            if (titleTextSize.width < minTextWidth)
                titleTextSize.width = minTextWidth;
            titleTextSize.width = ceilf(titleTextSize.width);
            titleTextSize.height = ceilf(titleTextSize.height);
            
            float actionSize = titleTextSize.width;
            
            TGLayoutTextItem *titleTextItem = [[TGLayoutTextItem alloc] initWithRichText:actionText font:titleFont textColor:[assetsSource messageActionTextColor] shadowColor:[assetsSource messageActionShadowColor] shadowOffset:CGSizeMake(0, 1)];
            titleTextItem.manualDrawing = true;
            titleTextItem.frame = CGRectMake(bodyPaddings.left + (int)((actionSize - titleTextSize.width) / 2), size.height + textOffsetY + 2, titleTextSize.width, titleTextSize.height);
            titleTextItem.precalculatedLayout = titleLayoutData;
            titleTextItem.tag = (*nextItemTag);
            (*nextItemTag) = (*nextItemTag) + 1;
            
            TGLayoutImageItem *imageItem = [[TGLayoutImageItem alloc] initWithImage:[assetsSource systemMessageBackground]];
            imageItem.manualDrawing = true;
            CGRect imageFrame = CGRectInset(titleTextItem.frame, -8, 0);
            imageFrame.size.height += 4;
            if (imageFrame.size.height > 21)
                imageFrame.size.height += 3;
            imageFrame.origin.y -= 1 + retinaPixel;
            if (imageFrame.size.height < 21)
                imageFrame.size.height = 21;
            imageItem.frame = imageFrame;
            imageItem.tag = (*nextItemTag);
            (*nextItemTag) = (*nextItemTag) + 1;
            [layout addLayoutItem:imageItem];
            
            [layout addLayoutItem:titleTextItem];
            
            size.width = MAX(bodyPaddings.left + titleTextSize.width, size.width);
            size.width = MAX(imageFrame.size.width, size.width);
            size.height += titleTextSize.height + 16;
            
            lastAttachmentType = -1;
        }
        else if (messageAction.actionType == TGMessageActionChatEditTitle)
        {
            NSString *title = [messageAction.actionData objectForKey:@"title"];
            NSString *actionText = [[NSString alloc] initWithFormat:TGLocalizedStatic(@"Notification.ChangedGroupName"), messageItem.author.displayName, title];
            
            CTFontRef titleFont = [assetsSource messageActionTitleFont];
            TGReusableLabelLayoutData *titleLayoutData = [TGReusableLabel calculateLayout:actionText additionalAttributes:nil textCheckingResults:nil font:titleFont textColor:[assetsSource messageActionTextColor] frame:CGRectZero orMaxWidth:maxTextWidth - 10 flags:TGReusableLabelLayoutMultiline textAlignment:UITextAlignmentCenter];
            
            CGSize titleTextSize = titleLayoutData.size;
            if (titleTextSize.width < minTextWidth)
                titleTextSize.width = minTextWidth;
            titleTextSize.width = ceilf(titleTextSize.width);
            titleTextSize.height = ceilf(titleTextSize.height);
            
            float actionSize = titleTextSize.width;
            
            TGLayoutTextItem *titleTextItem = [[TGLayoutTextItem alloc] initWithRichText:actionText font:titleFont textColor:[assetsSource messageActionTextColor] shadowColor:[assetsSource messageActionShadowColor] shadowOffset:CGSizeMake(0, 1)];
            titleTextItem.manualDrawing = true;
            titleTextItem.frame = CGRectMake(bodyPaddings.left + (int)((actionSize - titleTextSize.width) / 2), size.height + textOffsetY + 2, titleTextSize.width, titleTextSize.height);
            titleTextItem.precalculatedLayout = titleLayoutData;
            titleTextItem.tag = (*nextItemTag);
            (*nextItemTag) = (*nextItemTag) + 1;
            size.width = MAX(bodyPaddings.left + titleTextSize.width, size.width);
            size.height += titleTextSize.height;
            
            TGLayoutImageItem *imageItem = [[TGLayoutImageItem alloc] initWithImage:[assetsSource systemMessageBackground]];
            imageItem.manualDrawing = true;
            CGRect imageFrame = CGRectInset(titleTextItem.frame, -8, 0);
            imageFrame.size.height += 4;
            if (imageFrame.size.height > 21)
                imageFrame.size.height += 3;
            imageFrame.origin.y -= 1 + retinaPixel;
            if (imageFrame.size.height < 21)
                imageFrame.size.height = 21;
            imageItem.frame = imageFrame;
            imageItem.tag = (*nextItemTag);
            (*nextItemTag) = (*nextItemTag) + 1;
            [layout addLayoutItem:imageItem];
            
            [layout addLayoutItem:titleTextItem];
            
            size.width = MAX(imageFrame.size.width, size.width);
            size.height += 16;
            
            lastAttachmentType = -1;
        }
        else if (messageAction.actionType == TGMessageActionChatEditPhoto)
        {
            NSString *actionText = nil;
            TGImageMediaAttachment *imageAttachment = [messageAction.actionData objectForKey:@"photo"];
            CGSize avatarSize = CGSizeMake(70, 70);
            NSString *imageUrl = [imageAttachment.imageInfo closestImageUrlWithSize:avatarSize resultingSize:&avatarSize];
            
            if (imageUrl != nil)
                actionText = [[NSString alloc] initWithFormat:TGLocalizedStatic(@"Notification.ChangedGroupPhoto"), messageItem.author.displayName];
            else
                actionText = [[NSString alloc] initWithFormat:TGLocalizedStatic(@"Notification.RemovedGroupPhoto"), messageItem.author.displayName];
            
            CTFontRef titleFont = [assetsSource messageActionTitleFont];
            TGReusableLabelLayoutData *titleLayoutData = [TGReusableLabel calculateLayout:actionText additionalAttributes:nil textCheckingResults:nil font:titleFont textColor:[assetsSource messageActionTextColor] frame:CGRectZero orMaxWidth:maxTextWidth - 10 flags:TGReusableLabelLayoutMultiline textAlignment:UITextAlignmentCenter];
            
            CGSize titleTextSize = titleLayoutData.size;
            if (titleTextSize.width < minTextWidth)
                titleTextSize.width = minTextWidth;
            titleTextSize.width = ceilf(titleTextSize.width);
            titleTextSize.height = ceilf(titleTextSize.height);
            
            float actionSize = titleTextSize.width;
            
            TGLayoutTextItem *titleTextItem = [[TGLayoutTextItem alloc] initWithRichText:actionText font:titleFont textColor:[assetsSource messageActionTextColor] shadowColor:[assetsSource messageActionShadowColor] shadowOffset:CGSizeMake(0, 1)];
            titleTextItem.manualDrawing = true;
            titleTextItem.frame = CGRectMake(bodyPaddings.left + (int)((actionSize - titleTextSize.width) / 2), size.height + textOffsetY + 2, titleTextSize.width, titleTextSize.height);
            titleTextItem.precalculatedLayout = titleLayoutData;
            titleTextItem.tag = (*nextItemTag);
            (*nextItemTag) = (*nextItemTag) + 1;
            
            TGLayoutImageItem *imageItem = [[TGLayoutImageItem alloc] initWithImage:[assetsSource systemMessageBackground]];
            imageItem.manualDrawing = true;
            CGRect imageFrame = CGRectInset(titleTextItem.frame, -8, 0);
            imageFrame.size.height += 4;
            imageFrame.origin.y -= 1 + retinaPixel;
            if (imageFrame.size.height < 21)
                imageFrame.size.height = 21;
            imageItem.frame = imageFrame;
            imageItem.tag = (*nextItemTag);
            (*nextItemTag) = (*nextItemTag) + 1;
            [layout addLayoutItem:imageItem];
            
            [layout addLayoutItem:titleTextItem];
            
            size.width = MAX(bodyPaddings.left + titleTextSize.width, size.width);
            size.width = MAX(imageFrame.size.width, size.width);
            size.height += titleTextSize.height + 2;
            
            if (imageUrl != nil)
            {
                size.height += 8;
                
                TGLayoutRemoteImageItem *remoteImageItem = [[TGLayoutRemoteImageItem alloc] init];
                remoteImageItem.url = imageUrl;
                remoteImageItem.filter = @"profileAvatar";
                remoteImageItem.placeholder = [assetsSource messageActionConversationPhotoPlaceholder];
                if (imageAttachment.imageInfo != nil)
                    remoteImageItem.attachmentInfo = [NSDictionary dictionaryWithObject:imageAttachment.imageInfo forKey:@"imageInfo"];
                remoteImageItem.frame = CGRectMake((int)((size.width - 70) / 2), size.height, 70, 70);
                remoteImageItem.tag = (*nextItemTag);
                
                (*nextItemTag) = (*nextItemTag) + 1;
                [layout addLayoutItem:remoteImageItem];
                
                size.height += 78;
            }
            
            lastAttachmentType = -1;
        }
        else if (messageAction.actionType == TGMessageActionUserChangedPhoto)
        {
            NSString *actionText = nil;
            TGImageMediaAttachment *imageAttachment = [messageAction.actionData objectForKey:@"photo"];
            CGSize avatarSize = CGSizeMake(70, 70);
            NSString *imageUrl = [imageAttachment.imageInfo closestImageUrlWithSize:avatarSize resultingSize:&avatarSize];
            
            if (imageUrl != nil)
                actionText = [[NSString alloc] initWithFormat:TGLocalizedStatic(@"Notification.ChangedUserPhoto"), messageItem.author.displayFirstName];
            else
                actionText = [[NSString alloc] initWithFormat:TGLocalizedStatic(@"Notification.RemovedUserPhoto"), messageItem.author.displayFirstName];
            
            CTFontRef titleFont = [assetsSource messageActionTitleFont];
            TGReusableLabelLayoutData *titleLayoutData = [TGReusableLabel calculateLayout:actionText additionalAttributes:nil textCheckingResults:nil font:titleFont textColor:[assetsSource messageActionTextColor] frame:CGRectZero orMaxWidth:maxTextWidth - 10 flags:TGReusableLabelLayoutMultiline textAlignment:UITextAlignmentCenter];
            
            CGSize titleTextSize = titleLayoutData.size;
            if (titleTextSize.width < minTextWidth)
                titleTextSize.width = minTextWidth;
            titleTextSize.width = ceilf(titleTextSize.width);
            titleTextSize.height = ceilf(titleTextSize.height);
            
            float actionSize = titleTextSize.width;
            
            TGLayoutTextItem *titleTextItem = [[TGLayoutTextItem alloc] initWithRichText:actionText font:titleFont textColor:[assetsSource messageActionTextColor] shadowColor:[assetsSource messageActionShadowColor] shadowOffset:CGSizeMake(0, 1)];
            titleTextItem.manualDrawing = true;
            titleTextItem.frame = CGRectMake(bodyPaddings.left + (int)((actionSize - titleTextSize.width) / 2), size.height + textOffsetY + 2, titleTextSize.width, titleTextSize.height);
            titleTextItem.precalculatedLayout = titleLayoutData;
            titleTextItem.tag = (*nextItemTag);
            (*nextItemTag) = (*nextItemTag) + 1;
            
            TGLayoutImageItem *imageItem = [[TGLayoutImageItem alloc] initWithImage:[assetsSource systemMessageBackground]];
            imageItem.manualDrawing = true;
            CGRect imageFrame = CGRectInset(titleTextItem.frame, -8, 0);
            imageFrame.size.height += 4;
            imageFrame.origin.y -= 1 + retinaPixel;
            if (imageFrame.size.height < 21)
                imageFrame.size.height = 21;
            imageItem.frame = imageFrame;
            imageItem.tag = (*nextItemTag);
            (*nextItemTag) = (*nextItemTag) + 1;
            [layout addLayoutItem:imageItem];
            
            [layout addLayoutItem:titleTextItem];
            
            size.width = MAX(bodyPaddings.left + titleTextSize.width, size.width);
            size.width = MAX(imageFrame.size.width, size.width);
            size.height += titleTextSize.height + 2;
            
            if (imageUrl != nil)
            {
                size.height += 8;
                
                TGLayoutRemoteImageItem *remoteImageItem = [[TGLayoutRemoteImageItem alloc] init];
                remoteImageItem.url = imageUrl;
                remoteImageItem.filter = @"profileAvatar";
                remoteImageItem.placeholder = [assetsSource messageActionConversationPhotoPlaceholder];
                if (imageAttachment.imageInfo != nil)
                    remoteImageItem.attachmentInfo = [NSDictionary dictionaryWithObject:imageAttachment.imageInfo forKey:@"imageInfo"];
                remoteImageItem.frame = CGRectMake((int)((size.width - 70) / 2), size.height, 70, 70);
                remoteImageItem.tag = (*nextItemTag);
                
                (*nextItemTag) = (*nextItemTag) + 1;
                [layout addLayoutItem:remoteImageItem];
                
                size.height += 78;
            }
            
            lastAttachmentType = -1;
        }
        else if (messageAction.actionType == TGMessageActionCreateChat)
        {
            NSString *title = [messageAction.actionData objectForKey:@"title"];
            NSString *actionText = [[NSString alloc] initWithFormat:TGLocalizedStatic(@"Notification.CreatedChatWithTitle"), messageItem.author.displayName, title];
            
            CTFontRef titleFont = [assetsSource messageActionTitleFont];
            TGReusableLabelLayoutData *titleLayoutData = [TGReusableLabel calculateLayout:actionText additionalAttributes:nil textCheckingResults:nil font:titleFont textColor:[assetsSource messageActionTextColor] frame:CGRectZero orMaxWidth:maxTextWidth - 10 flags:TGReusableLabelLayoutMultiline textAlignment:UITextAlignmentCenter];
            
            CGSize titleTextSize = titleLayoutData.size;
            if (titleTextSize.width < minTextWidth)
                titleTextSize.width = minTextWidth;
            titleTextSize.width = ceilf(titleTextSize.width);
            titleTextSize.height = ceilf(titleTextSize.height);
            
            float actionSize = titleTextSize.width;
            
            TGLayoutTextItem *titleTextItem = [[TGLayoutTextItem alloc] initWithRichText:actionText font:titleFont textColor:[assetsSource messageActionTextColor] shadowColor:[assetsSource messageActionShadowColor] shadowOffset:CGSizeMake(0, 1)];
            titleTextItem.manualDrawing = true;
            titleTextItem.frame = CGRectMake(bodyPaddings.left + (int)((actionSize - titleTextSize.width) / 2), size.height + textOffsetY + 2, titleTextSize.width, titleTextSize.height);
            titleTextItem.precalculatedLayout = titleLayoutData;
            titleTextItem.tag = (*nextItemTag);
            (*nextItemTag) = (*nextItemTag) + 1;
            
            TGLayoutImageItem *imageItem = [[TGLayoutImageItem alloc] initWithImage:[assetsSource systemMessageBackground]];
            imageItem.manualDrawing = true;
            CGRect imageFrame = CGRectInset(titleTextItem.frame, -8, 0);
            imageFrame.size.height += 4;
            if (imageFrame.size.height > 21)
                imageFrame.size.height += 3;
            imageFrame.origin.y -= 1 + retinaPixel;
            if (imageFrame.size.height < 21)
                imageFrame.size.height = 21;
            imageItem.frame = imageFrame;
            imageItem.tag = (*nextItemTag);
            (*nextItemTag) = (*nextItemTag) + 1;
            [layout addLayoutItem:imageItem];
            
            [layout addLayoutItem:titleTextItem];
            
            size.width = MAX(titleTextSize.width, size.width);
            size.width = MAX(imageFrame.size.width, size.width);
            size.height += titleTextSize.height;
            
            size.height += 16;
            
            lastAttachmentType = -1;
        }
        else if (messageAction.actionType == TGMessageActionEncryptedChatRequest)
        {
            NSString *actionText = TGLocalizedStatic(@"Notification.EncryptedChatRequested");
            
            CTFontRef titleFont = [assetsSource messageActionTitleFont];
            TGReusableLabelLayoutData *titleLayoutData = [TGReusableLabel calculateLayout:actionText additionalAttributes:nil textCheckingResults:nil font:titleFont textColor:[assetsSource messageActionTextColor] frame:CGRectZero orMaxWidth:maxTextWidth - 10 flags:TGReusableLabelLayoutMultiline textAlignment:UITextAlignmentCenter];
            
            CGSize titleTextSize = titleLayoutData.size;
            if (titleTextSize.width < minTextWidth)
                titleTextSize.width = minTextWidth;
            titleTextSize.width = ceilf(titleTextSize.width);
            titleTextSize.height = ceilf(titleTextSize.height);
            
            float actionSize = titleTextSize.width;
            
            TGLayoutTextItem *titleTextItem = [[TGLayoutTextItem alloc] initWithRichText:actionText font:titleFont textColor:[assetsSource messageActionTextColor] shadowColor:[assetsSource messageActionShadowColor] shadowOffset:CGSizeMake(0, 1)];
            titleTextItem.manualDrawing = true;
            titleTextItem.frame = CGRectMake(bodyPaddings.left + (int)((actionSize - titleTextSize.width) / 2), size.height + textOffsetY + 2, titleTextSize.width, titleTextSize.height);
            titleTextItem.precalculatedLayout = titleLayoutData;
            titleTextItem.tag = (*nextItemTag);
            (*nextItemTag) = (*nextItemTag) + 1;
            
            TGLayoutImageItem *imageItem = [[TGLayoutImageItem alloc] initWithImage:[assetsSource systemMessageBackground]];
            imageItem.manualDrawing = true;
            CGRect imageFrame = CGRectInset(titleTextItem.frame, -8, 0);
            imageFrame.size.height += 4;
            if (imageFrame.size.height > 21)
                imageFrame.size.height += 3;
            imageFrame.origin.y -= 1 + retinaPixel;
            if (imageFrame.size.height < 21)
                imageFrame.size.height = 21;
            imageItem.frame = imageFrame;
            imageItem.tag = (*nextItemTag);
            (*nextItemTag) = (*nextItemTag) + 1;
            [layout addLayoutItem:imageItem];
            
            [layout addLayoutItem:titleTextItem];
            
            size.width = MAX(titleTextSize.width, size.width);
            size.width = MAX(imageFrame.size.width, size.width);
            size.height += titleTextSize.height;
            
            size.height += 16;
            
            if (!message.outgoing)
            {
                TGLayoutButtonItem *buttonItem = [[TGLayoutButtonItem alloc] init];
                buttonItem.tag = (*nextItemTag);
                (*nextItemTag) = (*nextItemTag) + 1;
                [layout addLayoutItem:buttonItem];
                
                static UIImage *backgroundImage = nil;
                static UIImage *backgroundHighlightedImage = nil;
                
                static dispatch_once_t onceToken;
                dispatch_once(&onceToken, ^
                {
                    UIImage *rawImage = [UIImage imageNamed:@"MediaActionButton.png"];
                    backgroundImage = [rawImage stretchableImageWithLeftCapWidth:(int)(rawImage.size.width / 2) topCapHeight:0];
                    rawImage = [UIImage imageNamed:@"MediaActionButton_Highlighted.png"];
                    backgroundHighlightedImage = [rawImage stretchableImageWithLeftCapWidth:(int)(rawImage.size.width / 2) topCapHeight:0];
                });
                
                buttonItem.title = TGLocalized(@"Message.EncryptedChatAcceptButton");
                buttonItem.backgroundImage = backgroundImage;
                buttonItem.backgroundHighlightedImage = backgroundHighlightedImage;
                buttonItem.titleColor = UIColorRGB(0x506e8d);
                buttonItem.titleHighlightedColor = buttonItem.titleColor;
                buttonItem.titleShadow = UIColorRGBA(0xffffff, 0.7f);
                buttonItem.titleHighlightedShadow = UIColorRGBA(0xffffff, 0.5f);
                buttonItem.titleShadowOffset = CGSizeMake(0, 1);
                buttonItem.titleFont = [UIFont boldSystemFontOfSize:13];
                buttonItem.frame = CGRectMake(floorf((size.width - 80) / 2), size.height - 4, 80, backgroundImage.size.height);
                
                size.height += buttonItem.frame.size.height + 4;
            }
            
            lastAttachmentType = -1;
        }
        else if (messageAction.actionType == TGMessageActionEncryptedChatAccept || messageAction.actionType == TGMessageActionEncryptedChatDecline)
        {
            NSString *actionText = messageAction.actionType == TGMessageActionEncryptedChatAccept ? TGLocalizedStatic(@"Notification.EncryptedChatAccepted") : TGLocalizedStatic(@"Notification.EncryptedChatRejected");
            
            CTFontRef titleFont = [assetsSource messageActionTitleFont];
            TGReusableLabelLayoutData *titleLayoutData = [TGReusableLabel calculateLayout:actionText additionalAttributes:nil textCheckingResults:nil font:titleFont textColor:[assetsSource messageActionTextColor] frame:CGRectZero orMaxWidth:maxTextWidth - 10 flags:TGReusableLabelLayoutMultiline textAlignment:UITextAlignmentCenter];
            
            CGSize titleTextSize = titleLayoutData.size;
            if (titleTextSize.width < minTextWidth)
                titleTextSize.width = minTextWidth;
            titleTextSize.width = ceilf(titleTextSize.width);
            titleTextSize.height = ceilf(titleTextSize.height);
            
            float actionSize = titleTextSize.width;
            
            TGLayoutTextItem *titleTextItem = [[TGLayoutTextItem alloc] initWithRichText:actionText font:titleFont textColor:[assetsSource messageActionTextColor] shadowColor:[assetsSource messageActionShadowColor] shadowOffset:CGSizeMake(0, 1)];
            titleTextItem.manualDrawing = true;
            titleTextItem.frame = CGRectMake(bodyPaddings.left + (int)((actionSize - titleTextSize.width) / 2), size.height + textOffsetY + 2, titleTextSize.width, titleTextSize.height);
            titleTextItem.precalculatedLayout = titleLayoutData;
            titleTextItem.tag = (*nextItemTag);
            (*nextItemTag) = (*nextItemTag) + 1;
            
            TGLayoutImageItem *imageItem = [[TGLayoutImageItem alloc] initWithImage:[assetsSource systemMessageBackground]];
            imageItem.manualDrawing = true;
            CGRect imageFrame = CGRectInset(titleTextItem.frame, -8, 0);
            imageFrame.size.height += 4;
            if (imageFrame.size.height > 21)
                imageFrame.size.height += 3;
            imageFrame.origin.y -= 1 + retinaPixel;
            if (imageFrame.size.height < 21)
                imageFrame.size.height = 21;
            imageItem.frame = imageFrame;
            imageItem.tag = (*nextItemTag);
            (*nextItemTag) = (*nextItemTag) + 1;
            [layout addLayoutItem:imageItem];
            
            [layout addLayoutItem:titleTextItem];
            
            size.width = MAX(titleTextSize.width, size.width);
            size.width = MAX(imageFrame.size.width, size.width);
            size.height += titleTextSize.height;
            
            size.height += 16;
            
            lastAttachmentType = -1;
        }
        else if (messageAction.actionType == TGMessageActionEncryptedChatMessageLifetime)
        {
            int messageLifetime = [messageAction.actionData[@"messageLifetime"] intValue];
            
            NSString *actionText = nil;
            
            if (messageLifetime == 0)
            {
                actionText = [[NSString alloc] initWithFormat:TGLocalizedStatic(@"Notification.MessageLifetimeRemoved"), messageItem.author.displayFirstName];
            }
            else
            {
                NSString *lifetimeString = @"";
                
                if (messageLifetime <= 2)
                    lifetimeString = TGLocalized(@"Notification.MessageLifetime2s");
                else if (messageLifetime <= 5)
                    lifetimeString = TGLocalized(@"Notification.MessageLifetime5s");
                else if (messageLifetime <= 1 * 60)
                    lifetimeString = TGLocalized(@"Notification.MessageLifetime1m");
                else if (messageLifetime <= 60 * 60)
                    lifetimeString = TGLocalized(@"Notification.MessageLifetime1h");
                else if (messageLifetime <= 24 * 60 * 60)
                    lifetimeString = TGLocalized(@"Notification.MessageLifetime1d");
                else if (messageLifetime <= 7 * 24 * 60 * 60)
                    lifetimeString = TGLocalized(@"Notification.MessageLifetime1w");
                
                if (message.outgoing)
                    actionText = [[NSString alloc] initWithFormat:TGLocalizedStatic(@"Notification.MessageLifetimeChangedOutgoing"), lifetimeString];
                else
                    actionText = [[NSString alloc] initWithFormat:TGLocalizedStatic(@"Notification.MessageLifetimeChanged"), messageItem.author.displayFirstName, lifetimeString];
            }
            
            CTFontRef titleFont = [assetsSource messageActionTitleFont];
            TGReusableLabelLayoutData *titleLayoutData = [TGReusableLabel calculateLayout:actionText additionalAttributes:nil textCheckingResults:nil font:titleFont textColor:[assetsSource messageActionTextColor] frame:CGRectZero orMaxWidth:maxTextWidth - 10 flags:TGReusableLabelLayoutMultiline textAlignment:UITextAlignmentCenter];
            
            CGSize titleTextSize = titleLayoutData.size;
            if (titleTextSize.width < minTextWidth)
                titleTextSize.width = minTextWidth;
            titleTextSize.width = ceilf(titleTextSize.width);
            titleTextSize.height = ceilf(titleTextSize.height);
            
            float actionSize = titleTextSize.width;
            
            TGLayoutTextItem *titleTextItem = [[TGLayoutTextItem alloc] initWithRichText:actionText font:titleFont textColor:[assetsSource messageActionTextColor] shadowColor:[assetsSource messageActionShadowColor] shadowOffset:CGSizeMake(0, 1)];
            titleTextItem.manualDrawing = true;
            titleTextItem.frame = CGRectMake(bodyPaddings.left + (int)((actionSize - titleTextSize.width) / 2), size.height + textOffsetY + 2, titleTextSize.width, titleTextSize.height);
            titleTextItem.precalculatedLayout = titleLayoutData;
            titleTextItem.tag = (*nextItemTag);
            (*nextItemTag) = (*nextItemTag) + 1;
            
            TGLayoutImageItem *imageItem = [[TGLayoutImageItem alloc] initWithImage:[assetsSource systemMessageBackground]];
            imageItem.manualDrawing = true;
            CGRect imageFrame = CGRectInset(titleTextItem.frame, -8, 0);
            imageFrame.size.height += 4;
            if (imageFrame.size.height > 21)
                imageFrame.size.height += 3;
            imageFrame.origin.y -= 1 + retinaPixel;
            if (imageFrame.size.height < 21)
                imageFrame.size.height = 21;
            imageItem.frame = imageFrame;
            imageItem.tag = (*nextItemTag);
            (*nextItemTag) = (*nextItemTag) + 1;
            [layout addLayoutItem:imageItem];
            
            [layout addLayoutItem:titleTextItem];
            
            size.width = MAX(bodyPaddings.left + titleTextSize.width, size.width);
            size.width = MAX(imageFrame.size.width, size.width);
            size.height += titleTextSize.height + 16;
            
            lastAttachmentType = -1;
        }
        else if (messageAction.actionType == TGMessageActionContactRequest || messageAction.actionType == TGMessageActionAcceptContactRequest)
        {
            NSString *authorName = messageItem.author.displayName;
            
            NSString *actionText = nil;
            if (messageAction.actionType == TGMessageActionContactRequest)
            {
                if (message.outgoing)
                {
                    actionText = @"You sent contact request";
                    authorName = nil;
                }
                else
                {
                    if ([[messageAction.actionData objectForKey:@"hasPhone"] boolValue])
                        actionText = [[NSString alloc] initWithFormat:@"%@ knows your phone number, but is not in your contact list yet.", authorName];
                    else
                        actionText = [[NSString alloc] initWithFormat:@"%@ would like to exchange phone numbers with you.", authorName];
                }
            }
            else
            {
                if (message.outgoing)
                {
                    actionText = [[NSString alloc] initWithFormat:@"You have accepted contact request"];
                    authorName = nil;
                }
                else
                    actionText = [[NSString alloc] initWithFormat:@"%@ has accepted your contact request", authorName];
            }
            
            CTFontRef actionFont = [assetsSource messageRequestActionFont];
            CTFontRef actionBoldFont = [assetsSource messagerequestActorBoldFont];
            
            NSArray *additionalAttributes = nil;
            if (authorName != nil)
            {
                NSArray *fontAttributes = [[NSArray alloc] initWithObjects:(__bridge id)actionBoldFont, (NSString *)kCTFontAttributeName, nil];
                NSRange range = NSMakeRange(0, authorName.length);
                additionalAttributes = [[NSArray alloc] initWithObjects:[[NSValue alloc] initWithBytes:&range objCType:@encode(NSRange)], fontAttributes, nil];
            }
            
            TGReusableLabelLayoutData *titleLayoutData = [TGReusableLabel calculateLayout:actionText additionalAttributes:additionalAttributes textCheckingResults:nil font:actionFont textColor:[assetsSource messageActionTextColor] frame:CGRectZero orMaxWidth:maxTextWidth flags:TGReusableLabelLayoutMultiline textAlignment:UITextAlignmentCenter];
            
            CGSize titleTextSize = titleLayoutData.size;
            if (titleTextSize.width < minTextWidth)
                titleTextSize.width = minTextWidth;
            titleTextSize.width = ceilf(titleTextSize.width);
            titleTextSize.height = ceilf(titleTextSize.height);
            
            float actionSize = titleTextSize.width;
            
            TGLayoutTextItem *titleTextItem = [[TGLayoutTextItem alloc] initWithRichText:actionText font:actionFont textColor:[assetsSource messageActionTextColor] shadowColor:[assetsSource messageActionShadowColor] shadowOffset:CGSizeMake(0, 1)];
            titleTextItem.manualDrawing = true;
            titleTextItem.frame = CGRectMake(bodyPaddings.left + (int)((actionSize - titleTextSize.width) / 2), size.height + textOffsetY, titleTextSize.width, titleTextSize.height);
            titleTextItem.precalculatedLayout = titleLayoutData;
            titleTextItem.tag = (*nextItemTag);
            (*nextItemTag) = (*nextItemTag) + 1;
            [layout addLayoutItem:titleTextItem];
            
            size.width = MAX(bodyPaddings.left + titleTextSize.width, size.width);
            size.height += titleTextSize.height;
            
            size.height += 15;
            
            lastAttachmentType = -1;
        }
    }
    else
    {
        bool haveImage = false;
        int forwardIndex = -1;
        
        if (attachments != nil && attachments.count != 0)
        {
            int attachmentCount = attachments.count;
            for (int i = 0; i < attachmentCount; i++)
            {
                TGMediaAttachment *attachment = [attachments objectAtIndex:i];
                
                switch (attachment.type)
                {
                    case TGImageMediaAttachmentType:
                    case TGVideoMediaAttachmentType:
                    case TGContactMediaAttachmentType:
                    case TGLocationMediaAttachmentType:
                    {
                        forwardIndex = -1;
                        haveImage = true;
                        break;
                    }
                    case TGForwardedMessageMediaAttachmentType:
                    {
                        if (!haveImage)
                            forwardIndex = i;
                        break;
                    }
                    case TGUnsupportedMediaAttachmentType:
                    {
                        messageText = TGLocalized(@"Conversation.UnsupportedMedia");
                        customTextCheckingResults = [[NSArray alloc] initWithObjects:[NSTextCheckingResult linkCheckingResultWithRange:NSMakeRange(messageText.length - 26, 26) URL:[[NSURL alloc] initWithString:@"http://telegram.org/update"]], nil];
                        break;
                    }
                    default:
                        break;
                }
            }
        }
        
        if (messageText.length != 0)
        {
            if (!message.outgoing && metrics & TGConversationMessageMetricsShowAvatars)
            {
                int textColor = coloredNameForUid(messageItem.author.uid, [assetsSource currentUserId]);
                
                NSString *authorName = messageItem.author.displayName;
                CTFontRef authorCoreTextFont = [assetsSource messageAuthorNameFont];
                
                TGLayoutTextItem *textItem = [[TGLayoutTextItem alloc] initWithText:authorName font:[assetsSource messageAuthorNameUIFont] textColor:UIColorRGB(textColor) shadowColor:[assetsSource messageAuthorNameShadowColor] highlightedTextColor:nil highlightedShadowColor:nil shadowOffset:CGSizeMake(0, 1) richText:false];
                textItem.numberOfLines = 1;
                textItem.manualDrawing = true;
                
                TGReusableLabelLayoutData *layoutData = [TGReusableLabel calculateLayout:authorName additionalAttributes:nil textCheckingResults:nil font:authorCoreTextFont textColor:[assetsSource messageTextColor] frame:CGRectZero orMaxWidth:maxTextWidth flags:TGReusableLabelLayoutMultiline textAlignment:UITextAlignmentLeft];
                
                CGSize nameSize = CGSizeMake(MIN(maxTextWidth, ceilf(layoutData.size.width + 1)), 16);
                
                textItem.frame = CGRectMake(bodyPaddings.left, size.height + 2, nameSize.width + 4, nameSize.height);
                textItem.tag = (*nextItemTag);
                (*nextItemTag) = (*nextItemTag) + 1;
                [layout addLayoutItem:textItem];
                
                size.height += nameSize.height + 1;
                size.width = MAX(bodyPaddings.left + nameSize.width, size.width);
            }
        }
        
        if (attachments != nil && attachments.count != 0)
        {
            if (forwardIndex != -1)
            {
                TGMediaAttachment *attachment = [attachments objectAtIndex:forwardIndex];
                
                if (attachment.type == TGForwardedMessageMediaAttachmentType)
                {
                    TGForwardedMessageMediaAttachment *forwardedMessageAttachment = (TGForwardedMessageMediaAttachment *)attachment;
                    
                    TGUser *user = forwardedMessageAttachment.forwardUid != 0 ? [messageItem.messageUsers objectForKey:[[NSNumber alloc] initWithInt:forwardedMessageAttachment.forwardUid]] : nil;
                    
                    int maxNameWidth = maxTextWidth - 32 - 8;
                    
                    NSString *titleText = TGLocalizedStatic(@"Message.ForwardedMessage");
                    NSString *namePrefix = TGLocalizedStatic(@"Message.ForwardedMessageFromPrefix");
                    NSString *nameText = user.displayName;
                    
                    CTFontRef titleFont = [assetsSource messageForwardTitleFont];
                    CTFontRef nameFont = [assetsSource messageForwardNameFont];
                    
                    TGReusableLabelLayoutData *titleLayoutData = [TGReusableLabel calculateLayout:titleText additionalAttributes:nil textCheckingResults:nil font:titleFont textColor:messageOutgoing ? [assetsSource messageForwardTitleColorOutgoing] : [assetsSource messageForwardTitleColorIncoming] frame:CGRectZero orMaxWidth:maxTextWidth flags:0 textAlignment:UITextAlignmentLeft];
                    CGSize titleTextSize = CGSizeMake(ceilf(titleLayoutData.size.width), ceilf(titleLayoutData.size.height));
                    TGLayoutTextItem *titleTextItem = [[TGLayoutTextItem alloc] initWithRichText:titleText font:titleFont textColor:nil shadowColor:nil shadowOffset:CGSizeMake(0, 1)];
                    titleTextItem.manualDrawing = true;
                    titleTextItem.frame = CGRectMake(bodyPaddings.left, size.height + textOffsetY + 3, titleTextSize.width, titleTextSize.height);
                    titleTextItem.precalculatedLayout = titleLayoutData;
                    titleTextItem.tag = (*nextItemTag);
                    (*nextItemTag) = (*nextItemTag) + 1;
                    [layout addLayoutItem:titleTextItem];
                    
                    size.width = MAX(bodyPaddings.left + titleTextSize.width, size.width);
                    size.height += titleTextSize.height + 3;
                    
                    TGReusableLabelLayoutData *namePrefixLayoutData = [TGReusableLabel calculateLayout:namePrefix additionalAttributes:nil textCheckingResults:nil font:titleFont textColor:messageOutgoing ? [assetsSource messageForwardTitleColorOutgoing] : [assetsSource messageForwardTitleColorIncoming] frame:CGRectZero orMaxWidth:maxTextWidth flags:0 textAlignment:UITextAlignmentLeft];
                    CGSize namePrefixTextSize = CGSizeMake(ceilf(namePrefixLayoutData.size.width), ceilf(namePrefixLayoutData.size.height));
                    TGLayoutTextItem *namePrefixTextItem = [[TGLayoutTextItem alloc] initWithRichText:titleText font:titleFont textColor:nil shadowColor:nil shadowOffset:CGSizeMake(0, 1)];
                    namePrefixTextItem.manualDrawing = true;
                    namePrefixTextItem.frame = CGRectMake(bodyPaddings.left, size.height + 1, namePrefixTextSize.width, namePrefixTextSize.height);
                    namePrefixTextItem.precalculatedLayout = namePrefixLayoutData;
                    namePrefixTextItem.tag = (*nextItemTag);
                    (*nextItemTag) = (*nextItemTag) + 1;
                    [layout addLayoutItem:namePrefixTextItem];
                    
                    NSTextCheckingResult *result = [NSTextCheckingResult linkCheckingResultWithRange:NSMakeRange(0, nameText.length) URL:[[NSURL alloc] initWithString:[[NSString alloc] initWithFormat:@"user://%d", user.uid]]];
                    
                    TGReusableLabelLayoutData *nameLayoutData = [TGReusableLabel calculateLayout:nameText additionalAttributes:nil textCheckingResults:[[NSArray alloc] initWithObjects:result, nil] font:nameFont textColor:messageOutgoing ? [assetsSource messageForwardNameColorOutgoing] : [assetsSource messageForwardNameColorIncoming] frame:CGRectZero orMaxWidth:maxNameWidth flags:0 textAlignment:UITextAlignmentLeft];
                    CGSize nameTextSize = CGSizeMake(ceilf(nameLayoutData.size.width), ceilf(nameLayoutData.size.height));
                    TGLayoutTextItem *nameTextItem = [[TGLayoutTextItem alloc] initWithRichText:nameText font:titleFont textColor:nil shadowColor:nil shadowOffset:CGSizeMake(0, 1)];
                    nameTextItem.manualDrawing = true;
                    nameTextItem.frame = CGRectMake(bodyPaddings.left + namePrefixTextSize.width + 4, size.height + 1, nameTextSize.width, nameTextSize.height);
                    nameTextItem.precalculatedLayout = nameLayoutData;
                    nameTextItem.tag = (*nextItemTag);
                    (*nextItemTag) = (*nextItemTag) + 1;
                    [layout addLayoutItem:nameTextItem];
                    size.width = MAX(size.width, nameTextItem.frame.origin.x + nameTextItem.frame.size.width);
                    
                    size.height += 18;
                    
                    lastAttachmentType = -1;
                }
            }
        }
    }
    
    if (messageText.length != 0)
    {   
        CGSize textSize = CGSizeZero;
        
        CTFontRef font = [assetsSource messageTextFont];
        TGReusableLabelLayoutData *layoutData = [TGReusableLabel calculateLayout:messageText additionalAttributes:nil textCheckingResults:customTextCheckingResults != nil ? customTextCheckingResults : [message textCheckingResults] font:font textColor:[assetsSource messageTextColor] frame:CGRectZero orMaxWidth:maxTextWidth flags:TGReusableLabelLayoutMultiline | TGReusableLabelLayoutHighlightLinks textAlignment:UITextAlignmentLeft];
        
        textSize = layoutData.size;
        if (textSize.width < minTextWidth)
            textSize.width = minTextWidth;
        textSize.width = ceilf(textSize.width);
        textSize.height = ceilf(textSize.height);
        
        TGLayoutTextItem *textItem = [[TGLayoutTextItem alloc] initWithRichText:messageText font:[assetsSource messageTextFont] textColor:[assetsSource messageTextColor] shadowColor:[assetsSource messageTextShadowColor] shadowOffset:CGSizeMake(0, 1)];
        textItem.flags = TGReusableLabelLayoutHighlightLinks;
        textItem.manualDrawing = true;
        textItem.frame = CGRectMake(bodyPaddings.left, size.height + textOffsetY, textSize.width, textSize.height);
        textItem.precalculatedLayout = layoutData;
        textItem.tag = (*nextItemTag);
        (*nextItemTag) = (*nextItemTag) + 1;
        [layout addLayoutItem:textItem];
        
        size.width = MAX(bodyPaddings.left + textSize.width, size.width);
        size.height += textSize.height;
        if (textSize.height + bodyPaddings.top + bodyPaddings.bottom > minSize.height)
            size.height += textSizeOffsetY;
        
        lastAttachmentType = -1;
    }
    
    CGSize defaultPhotoSize = CGSizeMake(90, 90);
    CGSize fillPhotoSize = CGSizeMake(82, 82);
    CGSize defaultLocationSize = CGSizeMake(200, 200);
    
    int attachmentIndex = -1;
    
    if (attachments != nil && attachments.count != 0)
    {   
        int attachmentsCount = attachments.count;
        for (int iAttachment = 0; iAttachment < attachmentsCount; iAttachment++)
        {
            attachmentIndex++;
            TGMediaAttachment *attachment = [attachments objectAtIndex:iAttachment];
            
            if (attachment.type == TGImageMediaAttachmentType || attachment.type == TGVideoMediaAttachmentType)
            {
                TGImageInfo *imageInfo = nil;
                TGVideoMediaAttachment *videoAttachment = nil;
                if (attachment.type == TGImageMediaAttachmentType)
                {
                    TGImageMediaAttachment *imageAttachment = (TGImageMediaAttachment *)attachment;
                    imageInfo = imageAttachment.imageInfo;
                }
                else
                {
                    videoAttachment = (TGVideoMediaAttachment *)attachment;
                    imageInfo = videoAttachment.thumbnailInfo;
                }
                
                CGSize imageSize = CGSizeZero;
                NSString *imageUrl = [imageInfo closestImageUrlWithSize:defaultPhotoSize resultingSize:&imageSize];
                if (imageUrl == nil)
                {   
                }
                else
                {
                    CGSize originalImageSize = imageSize;
                    
                    imageSize.width /= 2;
                    imageSize.height /= 2;
                    
                    imageSize = TGFitSize(imageSize, defaultPhotoSize);
                    imageSize = TGFillSize(imageSize, fillPhotoSize);
                    imageSize = TGCropSize(imageSize, CGSizeMake(maxImageWidth - 60, 400));
                    
                    size.height += imagePaddingTop;
                    
                    TGLayoutRemoteImageItem *remoteImageItem = [[TGLayoutRemoteImageItem alloc] init];
                    remoteImageItem.url = imageUrl;
                    remoteImageItem.filter = [NSString stringWithFormat:@"%@:%dx%d,%dx%d", @"attachmentImageOutgoing", (int)imageSize.width, (int)imageSize.height, (int)originalImageSize.width, (int)originalImageSize.height];
                    remoteImageItem.placeholder = messageOutgoing ? [assetsSource messageAttachmentImagePlaceholderOutgoing] : [assetsSource messageAttachmentImagePlaceholderIncoming];
                    if (attachment.type == TGImageMediaAttachmentType)
                    {
                        if (imageInfo != nil)
                            remoteImageItem.attachmentInfo = [[NSDictionary alloc] initWithObjectsAndKeys:imageInfo, @"imageInfo", nil];
                    }
                    else
                    {
                        if (videoAttachment != nil)
                            remoteImageItem.attachmentInfo = [[NSDictionary alloc] initWithObjectsAndKeys:videoAttachment, @"videoAttachment", nil];
                    }
                    remoteImageItem.frame = CGRectMake(messageOutgoing ? -9 : -11, size.height, imageSize.width, imageSize.height);
                    remoteImageItem.tag = (*nextItemTag);
                    
                    UIImage *placeholderOverlay = [assetsSource messageAttachmentImageLoadingIcon];
                    remoteImageItem.placeholderOverlay = placeholderOverlay;
                    remoteImageItem.placeholderOverlayFrame = CGRectMake(floorf((imageSize.width - placeholderOverlay.size.width) / 2) + (messageOutgoing ? 0 : 0), floorf((imageSize.height - placeholderOverlay.size.height) / 2), placeholderOverlay.size.width, placeholderOverlay.size.height);
                    
                    (*nextItemTag) = (*nextItemTag) + 1;
                    [layout addLayoutItem:remoteImageItem];
                    
                    if (videoAttachment != nil)
                    {
                        static UIImage *barImage = nil;
                        static UIImage *videoIconImage = nil;
                        static UIFont *labelFont = nil;
                        if (barImage == nil)
                        {
                            UIImage *rawImage = [UIImage imageNamed:@"MessageMediaBar.png"];
                            barImage = [rawImage stretchableImageWithLeftCapWidth:(int)(rawImage.size.width / 2) topCapHeight:0];
                            
                            videoIconImage = [UIImage imageNamed:@"MessageInlineVideoIcon.png"];
                            
                            labelFont = [UIFont boldSystemFontOfSize:10];
                        }
                        
                        TGLayoutImageItem *barItem = [[TGLayoutImageItem alloc] initWithImage:barImage];
                        barItem.additionalTag = 1;
                        CGRect imageFrame = remoteImageItem.frame;
                        barItem.frame = CGRectMake(imageFrame.origin.x + 2.5f, imageFrame.origin.y + imageFrame.size.height - 2.5f - barImage.size.height, imageFrame.size.width - 5, barImage.size.height);
                        barItem.tag = *nextItemTag;
                        (*nextItemTag) = (*nextItemTag) + 1;
                        barItem.userInteractionEnabled = false;
                        [layout addLayoutItem:barItem];
                        
                        TGLayoutImageItem *iconItem = [[TGLayoutImageItem alloc] initWithImage:videoIconImage];
                        iconItem.additionalTag = 2;
                        iconItem.frame = CGRectMake(imageFrame.origin.x + 8, imageFrame.origin.y + imageFrame.size.height - 2.5f - barImage.size.height + 5, videoIconImage.size.width, videoIconImage.size.height);
                        iconItem.tag = *nextItemTag;
                        (*nextItemTag) = (*nextItemTag) + 1;
                        iconItem.userInteractionEnabled = false;
                        [layout addLayoutItem:iconItem];
                        
                        TGLayoutSimpleLabelItem *labelItem = [[TGLayoutSimpleLabelItem alloc] init];
                        labelItem.additionalTag = 2;
                        labelItem.frame = CGRectMake(imageFrame.origin.x + imageFrame.size.width - 2.5f - 4 - 30, imageFrame.origin.y + imageFrame.size.height - 2.5f - barImage.size.height, 30, 18);
                        labelItem.tag = *nextItemTag;
                        (*nextItemTag) = (*nextItemTag) + 1;
                        labelItem.userInteractionEnabled = false;
                        labelItem.font = labelFont;
                        labelItem.textColor = [UIColor whiteColor];
                        labelItem.backgroundColor = [UIColor clearColor];
                        labelItem.textAlignment = UITextAlignmentRight;
                        int minutes = videoAttachment.duration / 60;
                        int seconds = videoAttachment.duration % 60;
                        labelItem.text = [[NSString alloc] initWithFormat:@"%d:%02d", minutes, seconds];
                        [layout addLayoutItem:labelItem];
                        
                        TGLayoutSimpleLabelItem *progressLabelItem = [[TGLayoutSimpleLabelItem alloc] init];
                        progressLabelItem.additionalTag = 3;
                        progressLabelItem.frame = CGRectMake(imageFrame.origin.x + 3, imageFrame.origin.y + imageFrame.size.height - 2.5f - barImage.size.height, imageFrame.size.width - 6, 18);
                        progressLabelItem.tag = *nextItemTag;
                        (*nextItemTag) = (*nextItemTag) + 1;
                        progressLabelItem.userInteractionEnabled = false;
                        progressLabelItem.font = labelFont;
                        progressLabelItem.textColor = [UIColor whiteColor];
                        progressLabelItem.backgroundColor = [UIColor clearColor];
                        progressLabelItem.textAlignment = UITextAlignmentCenter;
                        progressLabelItem.text = nil;
                        [layout addLayoutItem:progressLabelItem];
                    }
                    
                    size.width = MAX(size.width, imageSize.width + 3);
                    size.height += imageSize.height;
                    size.height += imagePaddingBottom;
                }
            }
            else if (attachment.type == TGLocationMediaAttachmentType)
            {
                TGLocationMediaAttachment *locationAttachment = (TGLocationMediaAttachment *)attachment;
                
                CGSize imageSize = defaultLocationSize;
                
                NSString *imageUrl = [NSString stringWithFormat:@"https://maps.googleapis.com/maps/api/staticmap?center=%.5f,%.5f&zoom=15&size=%dx%d&sensor=false&scale=%d&sensor=true&format=jpg&mobile=true", locationAttachment.latitude, locationAttachment.longitude, (int)(imageSize.width / 2), (int)(imageSize.height / 2 + 12), 2];
                
                layout.containsAnimatedViews = true;
                
                imageSize.width /= 2;
                imageSize.height /= 2;
                
                size.height += imagePaddingTop;
                
                TGLayoutRemoteImageItem *remoteImageItem = [[TGLayoutRemoteImageItem alloc] init];
                remoteImageItem.url = imageUrl;
                remoteImageItem.filter = @"attachmentLocationOutgoing";
                remoteImageItem.placeholder = [UIImage imageNamed:@"AttachmentMapPlaceholder.png"];
                remoteImageItem.attachmentInfo = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithDouble:locationAttachment.latitude], @"latitude", [NSNumber numberWithDouble:locationAttachment.longitude], @"longitude", [[NSNumber alloc] initWithInt:(int)message.fromUid], @"authorUid", nil];
                remoteImageItem.frame = CGRectMake(messageOutgoing ? -9 : -11, size.height, imageSize.width, imageSize.height);
                
                remoteImageItem.placeholderOverlayIsProgress = true;
                remoteImageItem.placeholderOverlayProgressCenter = CGPointMake(floorf(imageSize.width / 2), floorf(imageSize.height / 2));
                
                //UIImage *placeholderOverlay = [assetsSource messageAttachmentImageLoadingIcon];
                //remoteImageItem.placeholderOverlay = placeholderOverlay;
                //remoteImageItem.placeholderOverlayFrame = CGRectMake(floorf((imageSize.width - placeholderOverlay.size.width) / 2) + (messageOutgoing ? 0 : 0), floorf((imageSize.height - placeholderOverlay.size.height) / 2), placeholderOverlay.size.width, placeholderOverlay.size.height);
                
                remoteImageItem.tag = (*nextItemTag);
                (*nextItemTag) = (*nextItemTag) + 1;
                [layout addLayoutItem:remoteImageItem];
                
                size.width = MAX(size.width, imageSize.width + 3);
                size.height += imageSize.height;
                size.height += imagePaddingBottom;
            }
            else if (attachment.type == TGContactMediaAttachmentType)
            {
                TGContactMediaAttachment *contactAttachment = (TGContactMediaAttachment *)attachment;
                
                TGUser *user = contactAttachment.uid != 0 ? [messageItem.messageUsers objectForKey:[[NSNumber alloc] initWithInt:contactAttachment.uid]] : nil;
                
                int maxNameWidth = maxTextWidth - 32 - 8;
                
                NSString *titleText = TGLocalizedStatic(@"Message.SharedContact");
                NSString *nameText = nil;
                if (contactAttachment.firstName.length != 0 && contactAttachment.lastName.length != 0)
                    nameText = [[NSString alloc] initWithFormat:@"%@ %@", contactAttachment.firstName, contactAttachment.lastName];
                else if (contactAttachment.lastName.length != 0)
                    nameText = contactAttachment.lastName;
                else
                    nameText = contactAttachment.firstName;
                NSString *phoneText = [TGStringUtils formatPhone:contactAttachment.phoneNumber forceInternational:false];
                
                CTFontRef titleFont = [assetsSource messageForwardTitleFont];
                CTFontRef nameFont = [assetsSource messageForwardNameFont];
                CTFontRef phoneFont = [assetsSource messageForwardPhoneFont];
                
                TGReusableLabelLayoutData *titleLayoutData = [TGReusableLabel calculateLayout:titleText additionalAttributes:nil textCheckingResults:nil font:titleFont textColor:messageOutgoing ? [assetsSource messageForwardTitleColorOutgoing] : [assetsSource messageForwardTitleColorIncoming] frame:CGRectZero orMaxWidth:maxTextWidth flags:0 textAlignment:UITextAlignmentCenter];
                CGSize titleTextSize = CGSizeMake(ceilf(titleLayoutData.size.width), ceilf(titleLayoutData.size.height));
                TGLayoutTextItem *titleTextItem = [[TGLayoutTextItem alloc] initWithRichText:titleText font:titleFont textColor:nil shadowColor:nil shadowOffset:CGSizeMake(0, 1)];
                titleTextItem.manualDrawing = true;
                titleTextItem.frame = CGRectMake(bodyPaddings.left, size.height + textOffsetY + 3, titleTextSize.width, titleTextSize.height);
                titleTextItem.precalculatedLayout = titleLayoutData;
                titleTextItem.tag = (*nextItemTag);
                (*nextItemTag) = (*nextItemTag) + 1;
                [layout addLayoutItem:titleTextItem];
                
                size.width = MAX(bodyPaddings.left + titleTextSize.width, size.width);
                size.height += titleTextSize.height + 4;
                
                TGLayoutRemoteImageItem *remoteImageItem = [[TGLayoutRemoteImageItem alloc] init];
                remoteImageItem.url = user.photoUrlSmall;
                remoteImageItem.filter = @"inlineMessageAvatar";
                remoteImageItem.placeholder = user.uid > 0 && user.photoUrlSmall == nil ? [assetsSource messageInlineAvatarPlaceholder:user.uid] : [assetsSource messageInlineGenericAvatarPlaceholder];
                remoteImageItem.frame = CGRectMake(bodyPaddings.left + 0.5f, size.height + 2 + 0.5f, 30, 30);
                
                remoteImageItem.tag = (*nextItemTag);
                (*nextItemTag) = (*nextItemTag) + 1;
                [layout addLayoutItem:remoteImageItem];
                
                TGLayoutImageItem *imageItem = [[TGLayoutImageItem alloc] initWithImage:[UIImage imageNamed:@"InlineAvatarOverlay.png"]];
                imageItem.tag = (*nextItemTag);
                (*nextItemTag) = (*nextItemTag) + 1;
                imageItem.frame = CGRectMake(bodyPaddings.left, size.height + 2, 31, 32);
                imageItem.userInteractionEnabled = false;
                [layout addLayoutItem:imageItem];
                
                TGReusableLabelLayoutData *nameLayoutData = [TGReusableLabel calculateLayout:nameText additionalAttributes:nil textCheckingResults:nil font:nameFont textColor:messageOutgoing ? [assetsSource messageForwardNameColorOutgoing] : [assetsSource messageForwardNameColorIncoming] frame:CGRectZero orMaxWidth:maxNameWidth flags:0 textAlignment:UITextAlignmentCenter];
                CGSize nameTextSize = CGSizeMake(ceilf(nameLayoutData.size.width), ceilf(nameLayoutData.size.height));
                TGLayoutTextItem *nameTextItem = [[TGLayoutTextItem alloc] initWithRichText:nameText font:titleFont textColor:nil shadowColor:nil shadowOffset:CGSizeMake(0, 1)];
                nameTextItem.manualDrawing = true;
                nameTextItem.frame = CGRectMake(bodyPaddings.left + 32 + 6, size.height + 1, nameTextSize.width, nameTextSize.height);
                nameTextItem.precalculatedLayout = nameLayoutData;
                nameTextItem.tag = (*nextItemTag);
                (*nextItemTag) = (*nextItemTag) + 1;
                [layout addLayoutItem:nameTextItem];
                size.width = MAX(size.width, nameTextItem.frame.origin.x + nameTextItem.frame.size.width);
                
                TGReusableLabelLayoutData *phoneLayoutData = [TGReusableLabel calculateLayout:phoneText additionalAttributes:nil textCheckingResults:nil font:phoneFont textColor:[assetsSource messageForwardPhoneColor] frame:CGRectZero orMaxWidth:maxNameWidth flags:0 textAlignment:UITextAlignmentCenter];
                CGSize phoneTextSize = CGSizeMake(ceilf(phoneLayoutData.size.width), ceilf(phoneLayoutData.size.height));
                TGLayoutTextItem *phoneTextItem = [[TGLayoutTextItem alloc] initWithRichText:nameText font:titleFont textColor:nil shadowColor:nil shadowOffset:CGSizeMake(0, 1)];
                phoneTextItem.manualDrawing = true;
                phoneTextItem.frame = CGRectMake(bodyPaddings.left + 32 + 6, size.height + 18, phoneTextSize.width, phoneTextSize.height);
                phoneTextItem.precalculatedLayout = phoneLayoutData;
                phoneTextItem.tag = (*nextItemTag);
                (*nextItemTag) = (*nextItemTag) + 1;
                [layout addLayoutItem:phoneTextItem];
                size.width = MAX(size.width, phoneTextItem.frame.origin.x + phoneTextItem.frame.size.width);
                
                size.height += 32 + 7;
                
                lastAttachmentType = -1;
            }
            
            if (attachment != nil)
                lastAttachmentType = attachment.type;
        }
    }
    
    size.height += bodyPaddings.bottom;
    
    *currentSize = size;
}

+ (NSString *)generateMapUrl:(double)latitude longitude:(double)longitude
{
    return [[NSString alloc] initWithFormat:@"https://maps.googleapis.com/maps/api/staticmap?center=%.5f,%.5f&zoom=15&size=%dx%d&sensor=false&scale=%d&sensor=true&format=jpg&mobile=true", latitude, longitude, (int)(200 / 2), (int)(200 / 2 + 12), 2];
}

- (void)resetView:(int)metrics
{
    //TGLog(@"Rebuild %x", (int)self);
    
    if (_message.deliveryState == TGMessageDeliveryStatePending)
    {
        TGLog(@"Display pending");
    }
    
    [self discardContent];
    
    bool isAction = _message.actionInfo != nil;
    
    _dateLabel.hidden = isAction;
    _avatarView.hidden = isAction;
    
    [self.layer removeAllAnimations];
    self.frame = self.frame;
    self.layer.transform = self.layer.transform;
    
    [self clearLinkHighlights];
    
    if (_isContextSelected)
        [self setIsContextSelected:false animated:false];
    
    TGLayoutModel *layout = (TGLayoutModel *)_message.cachedLayoutData;
    if (layout == nil || layout.metrics != metrics)
    {
        layout = [TGConversationMessageItemView layoutModelForMessage:_messageItem withMetrics:metrics assetsSource:TGGlobalAssetsSource];
        _message.cachedLayoutData = layout;
    }
    
    if (layout == nil)
    {
        TGLog(@"Warning: message layout is nil in rebuildView");
        return;
    }
    
    if (_showAvatar && !_message.outgoing)
    {
        if (_avatarView == nil)
        {
            _avatarView = [[TGRemoteImageView alloc] initWithFrame:CGRectMake(0, 0, 38, 38)];
            _avatarView.userInteractionEnabled = true;
            UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(avatarTapped:)];
            [_avatarView addGestureRecognizer:tapRecognizer];
            _avatarView.fadeTransition = true;
            
            [self.contentView addSubview:_avatarView];
        }
        
        _avatarView.fadeTransitionDuration = 0.14;
        if (_avatarUrl == nil)
        {
            [_avatarView loadImage:[TGGlobalAssetsSource messageAvatarPlaceholder:(int)_message.fromUid]];
        }
        else
        {
            [_avatarView loadImage:_avatarUrl filter:@"conversationAvatar" placeholder:[TGGlobalAssetsSource messageGenericAvatarPlaceholder]];
        }
    }
    else
    {
        if (_avatarView != nil)
            _avatarView.hidden = true;
    }
    
    CGSize layoutSize = layout.size;
    
    [self updateBackground:layout];
    
    if (_displayMids)
        _dateLabel.dateText = [[NSString alloc] initWithFormat:@"%d", _message.mid];
    else
        _dateLabel.dateText = [TGDateUtils stringForShortTime:(((int)(_message.date)))];
    
    _dateBackgroundView.image = _message.outgoing ? [TGGlobalAssetsSource messageDateBadgeOutgoing] : [TGGlobalAssetsSource messageDateBadgeIncoming];
    
    CGSize dateSize = [_dateLabel measureTextSize];
    _dateLabel.frame = CGRectMake(0, 0, dateSize.width, dateSize.height);
    
    const bool forceBackground = false;
    
    if (!_disableBackgroundDrawing && (forceBackground || layoutSize.height > [TGGlobalAssetsSource messageMinimalBodySize].height * 12))
    {
        _contentContainer.frame = CGRectZero;
        _contentContainer.hidden = true;
        
        _asyncContentContainer.frame = CGRectMake(0, 0, layoutSize.width, layoutSize.height);
        _asyncContentContainer.hidden = false;
        [self beginBackgroundRendering];
        [layout inflateLayoutToView:_asyncContentContainer viewRecycler:_viewRecycler actionTarget:self];
    }
    else
    {
        _contentContainer.frame = CGRectMake(0, 0, layoutSize.width, layoutSize.height);
        _contentContainer.hidden = false;
        _contentContainer.layout = layout;
        [layout inflateLayoutToView:_contentContainer viewRecycler:_viewRecycler actionTarget:self];
        [_contentContainer setNeedsDisplay];
        
        _asyncContentContainer.hidden = true;
        _asyncContentContainer.layer.contents = nil;
    }
    
    _validMetrics = layout.metrics;
    
    [_deliveryStatusViewFirst.layer removeAllAnimations];
    _deliveryStatusViewFirst.transform = CGAffineTransformIdentity;

    [_deliveryStatusViewFirstBackground.layer removeAllAnimations];
    _deliveryStatusViewFirstBackground.transform = CGAffineTransformIdentity;
    
    [_deliveryStatusViewSecond.layer removeAllAnimations];
    _deliveryStatusViewSecond.transform = CGAffineTransformIdentity;
    
    [_deliveryStatusViewFailed.layer removeAllAnimations];
    _deliveryStatusViewFailed.transform = CGAffineTransformIdentity;
    
    [_animatedDeliveryStatusView.layer removeAllAnimations];
    _animatedDeliveryStatusView.transform = CGAffineTransformIdentity;
    if (_animatedDeliveryStatusView.isAnimating)
        [_animatedDeliveryStatusView stopAnimating];
    
    _messageNormalBackgroundView.hidden = isAction || layout.hideBackground;
    if (_messageHighlightedBackgroundView != nil)
        _messageHighlightedBackgroundView.hidden = _messageNormalBackgroundView.hidden;
    
    _statusContainerView.hidden = isAction || !_message.outgoing;
    
    _deliveryStatusViewFailed.hidden = true;
    
    [self updateMediaActionButton];
    
    [self updateStatusViews];
}

- (void)updateStatusViews
{
    bool isAction = _message.actionInfo != nil;
    
    if (!isAction)
    {
        if (_message.outgoing)
        {
            if (_message.unread)
            {
                if (_message.deliveryState == TGMessageDeliveryStateDelivered)
                {
                    _deliveryStatusViewFirst.hidden = true;
                    _deliveryStatusViewFirstBackground.hidden = true;
                    _deliveryStatusViewSecond.hidden = false;
                    _animatedDeliveryStatusView.hidden = true;
                }
                else if (_message.deliveryState == TGMessageDeliveryStateFailed)
                {
                    _deliveryStatusViewFailed.hidden = false;
                    
                    _deliveryStatusViewFirst.hidden = true;
                    _deliveryStatusViewFirstBackground.hidden = true;
                    _deliveryStatusViewSecond.hidden = true;
                    _animatedDeliveryStatusView.hidden = true;
                }
                else
                {
                    _deliveryStatusViewFirst.hidden = true;
                    _deliveryStatusViewFirstBackground.hidden = true;
                    _deliveryStatusViewSecond.hidden = true;
                    _animatedDeliveryStatusView.hidden = false;
                    if (!_animatedDeliveryStatusView.isAnimating)
                        [_animatedDeliveryStatusView startAnimating];
                }
            }
            else
            {
                _deliveryStatusViewFirst.hidden = true;
                _deliveryStatusViewFirstBackground.hidden = false;
                _deliveryStatusViewSecond.hidden = false;
                _animatedDeliveryStatusView.hidden = true;
            }
        }
        else
        {
            _deliveryStatusViewFirst.hidden = true;
            _deliveryStatusViewFirstBackground.hidden = true;
            _deliveryStatusViewSecond.hidden = true;
            _animatedDeliveryStatusView.hidden = true;
        }
    }
    else
    {
        _deliveryStatusViewFirst.hidden = true;
        _deliveryStatusViewFirstBackground.hidden = true;
        _deliveryStatusViewSecond.hidden = true;
        _animatedDeliveryStatusView.hidden = true;
    }
    
    _dateLabel.hidden = isAction || _message.deliveryState == TGMessageDeliveryStateFailed;
    _dateBackgroundView.hidden = _dateLabel.hidden;
}

- (void)updateState:(bool)force
{
    if (!force)
    {
        if (_animatedDeliveryStatusView.isAnimating != !_animatedDeliveryStatusView.hidden)
        {
            if (_animatedDeliveryStatusView.hidden)
                [_animatedDeliveryStatusView stopAnimating];
            else
                [_animatedDeliveryStatusView startAnimating];
        }
    }
    else
    {
        if (_animatedDeliveryStatusView.hidden)
            [_animatedDeliveryStatusView stopAnimating];
        else
        {
            _animatedDeliveryStatusView.isAnimating = true;
            [_animatedDeliveryStatusView stopAnimating];
            [_animatedDeliveryStatusView startAnimating];
        }
    }
    
    if (_message.cachedLayoutData != nil && ((TGLayoutModel *)_message.cachedLayoutData).containsAnimatedViews)
    {
        [self findAndResumeAnimatedViews:self.contentView];
    }
}

- (void)findAndResumeAnimatedViews:(UIView *)parent
{
    for (UIView *view in parent.subviews)
    {
        if ([view isKindOfClass:[UIActivityIndicatorView class]])
            [(UIActivityIndicatorView *)view startAnimating];
        else
            [self findAndResumeAnimatedViews:view];
    }
}

- (void)changeAvatarAnimated:(NSString *)url
{
    _avatarUrl = url;
    if (_avatarView != nil)
    {
        UIImage *placeholder = [_avatarView currentImage];
        _avatarView.fadeTransition = 0.3;
        
        if (_avatarUrl == nil)
            [_avatarView loadImage:[TGGlobalAssetsSource messageAvatarPlaceholder:(int)_message.fromUid]];
        else
            [_avatarView loadImage:_avatarUrl filter:@"conversationAvatar" placeholder:placeholder == nil ? [TGGlobalAssetsSource messageGenericAvatarPlaceholder] : placeholder forceFade:true];
    }
}

- (void)updateBackground:(TGLayoutModel *)layout
{
    bool isOutgoing = _message.outgoing;
    
    if (_messageHighlightedBackgroundView != nil)
    {
        _messageHighlightedBackgroundView.enableStretching = false;
        if (isOutgoing)
        {
            if (layout.size.height >= 48)
            {
                _messageHighlightedBackgroundView.enableStretching = true;
                _messageHighlightedBackgroundView.stretchInsets = UIEdgeInsetsMake(15, 17, 15, 40 - 17 - 1);
                _messageHighlightedBackgroundView.image = [TGGlobalAssetsSource messageBackgroundBubbleOutgoingDoubleHighlighted];
            }
            else
            {
                _messageHighlightedBackgroundView.enableStretching = false;
                _messageHighlightedBackgroundView.image = [TGGlobalAssetsSource messageBackgroundBubbleOutgoingHighlighted];
            }
            
            [_messageHighlightedBackgroundView setShadowImage:[TGGlobalAssetsSource messageBackgroundBubbleOutgoingHighlightedShadow]];
        }
        else
        {
            if (layout.size.height >= 48)
            {
                _messageHighlightedBackgroundView.enableStretching = true;
                _messageHighlightedBackgroundView.stretchInsets = UIEdgeInsetsMake(15, 23, 15, 40 - 23  - 1);
                _messageHighlightedBackgroundView.image = [TGGlobalAssetsSource messageBackgroundBubbleIncomingDoubleHighlighted];
            }
            else
            {
                _messageHighlightedBackgroundView.enableStretching = false;
                _messageHighlightedBackgroundView.image = [TGGlobalAssetsSource messageBackgroundBubbleIncomingHighlighted];
            }
            
            [_messageHighlightedBackgroundView setShadowImage:[TGGlobalAssetsSource messageBackgroundBubbleIncomingHighlightedShadow]];
        }
    }

    if (isOutgoing)
    {
        if (layout.size.height >= 48)
        {
            _messageNormalBackgroundView.enableStretching = true;
            _messageNormalBackgroundView.stretchInsets = UIEdgeInsetsMake(15, 17, 15, 40 - 17 - 1);
            _messageNormalBackgroundView.image = [TGGlobalAssetsSource messageBackgroundBubbleOutgoingDouble];
        }
        else
        {
            _messageNormalBackgroundView.enableStretching = false;
            _messageNormalBackgroundView.image = [TGGlobalAssetsSource messageBackgroundBubbleOutgoingSingle];
        }
    }
    else
    {
        if (layout.size.height >= 48)
        {
            _messageNormalBackgroundView.enableStretching = true;
            _messageNormalBackgroundView.stretchInsets = UIEdgeInsetsMake(15, 23, 15, 40 - 23  - 1);
            _messageNormalBackgroundView.image = [TGGlobalAssetsSource messageBackgroundBubbleIncomingDouble];
        }
        else
        {
            _messageNormalBackgroundView.enableStretching = false;
            _messageNormalBackgroundView.image = [TGGlobalAssetsSource messageBackgroundBubbleIncomingSingle];
        }
    }
}

- (void)animateState:(TGMessage *)newState
{
    bool isAction = _message.actionInfo != nil;
    if (isAction)
        return;
    
    bool animateFirstStatus = false;
    bool animateSecondStatus = false;
    
    if (_message.outgoing)
    {
        if (_message.deliveryState == TGMessageDeliveryStatePending && newState.deliveryState == TGMessageDeliveryStateDelivered)
        {
            animateSecondStatus = true;
            TGLog(@"Display delivered");
        }
        
        if (_message.unread == true && newState.unread == false)
        {
            animateFirstStatus = true;
        }
    }
    
    _message = newState;
    
    [self updateStatusViews];
    
    if (animateFirstStatus || animateSecondStatus)
    {
        if (animateSecondStatus)
            _deliveryStatusViewSecond.transform = CGAffineTransformMakeScale(0.8f, 0.8f);
        if (animateFirstStatus)
            _deliveryStatusViewFirstBackground.transform = CGAffineTransformMakeScale(0.8f, 0.8f);
        [UIView animateWithDuration:0.1 animations:^
        {
            if (animateSecondStatus)
                _deliveryStatusViewSecond.transform = CGAffineTransformMakeScale(1.3f, 1.3f);
            if (animateFirstStatus)
                _deliveryStatusViewFirstBackground.transform = CGAffineTransformMakeScale(1.2f, 1.2f);
        } completion:^(BOOL finished)
        {
            if (finished)
            {
                [UIView animateWithDuration:0.1 animations:^
                {
                    if (animateSecondStatus)
                        _deliveryStatusViewSecond.transform = CGAffineTransformIdentity;
                    if (animateFirstStatus)
                        _deliveryStatusViewFirstBackground.transform = CGAffineTransformIdentity;
                }];
            }
            else
            {
                if (animateSecondStatus)
                    _deliveryStatusViewSecond.transform = CGAffineTransformIdentity;
                if (animateFirstStatus)
                    _deliveryStatusViewFirstBackground.transform = CGAffineTransformIdentity;
            }
        }];
    }
}

- (void)setIsSelected:(bool)isSelected
{
    if (_isSelected != isSelected)
    {
        _isSelected = isSelected;
        
        if (_checkView != nil)
            _checkView.image = isSelected ? [TGGlobalAssetsSource messageChecked] : [TGGlobalAssetsSource messageUnchecked];
        
        if (isSelected && _cellBackgroundView == nil)
        {
            _cellBackgroundView = [[UIView alloc] init];
            _cellBackgroundView.layer.backgroundColor = [TGGlobalAssetsSource messageBackgroundColorUnread].CGColor;
            [self insertSubview:_cellBackgroundView belowSubview:self.contentView];
        }
        
        if (_cellBackgroundView != nil)
        {
            _cellBackgroundView.hidden = !isSelected;
        }
    }
}

- (UIView *)uploadProgressContainer
{
    if (_uploadProgressContainer == nil)
    {
        _uploadProgressContainer = (TGReusableView *)[_viewRecycler dequeueReusableViewWithIdentifier:@"InlineProgress"];
        
        if (_uploadProgressContainer == nil)
        {
            _uploadProgressContainer = [[TGReusableView alloc] init];
            ((TGReusableView *)_uploadProgressContainer).reuseIdentifier = @"InlineProgress";
            
            UIImage *cancelButtonImage = [TGGlobalAssetsSource messageProgressCancelButton];
            UIImage *cancelButtonImageHighlighted = [TGGlobalAssetsSource messageProgressCancelButtonHighlighted];
            
            UIButton *uploadProgressCancelButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, cancelButtonImage.size.width, cancelButtonImage.size.height)];
            uploadProgressCancelButton.exclusiveTouch = true;
            uploadProgressCancelButton.tag = 100;
            [uploadProgressCancelButton setBackgroundImage:cancelButtonImage forState:UIControlStateNormal];
            [uploadProgressCancelButton setBackgroundImage:cancelButtonImageHighlighted forState:UIControlStateHighlighted];
            [_uploadProgressContainer addSubview:uploadProgressCancelButton];
            
            UIImageView *uploadProgressBackground = [[UIImageView alloc] initWithImage:[TGGlobalAssetsSource messageProgressBackground]];
            uploadProgressBackground.tag = 101;
            [_uploadProgressContainer addSubview:uploadProgressBackground];
            UIImageView *uploadProgressForeground = [[UIImageView alloc] initWithImage:[TGGlobalAssetsSource messageProgressForeground]];
            uploadProgressForeground.tag = 102;
            [_uploadProgressContainer addSubview:uploadProgressForeground];
        }
        
        _uploadProgressCancelButton = (UIButton *)[_uploadProgressContainer viewWithTag:100];
        _uploadProgressBackground = (UIImageView *)[_uploadProgressContainer viewWithTag:101];
        _uploadProgressForeground = (UIImageView *)[_uploadProgressContainer viewWithTag:102];
        
        [_uploadProgressCancelButton addTarget:self action:@selector(uploadCancelButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        
        _uploadProgressContainer.hidden = true;
        
        _uploadProgressCancelButton.autoresizingMask = _message.outgoing ? 0 : UIViewAutoresizingFlexibleLeftMargin;
        
        [self addSubview:_uploadProgressContainer];
    }
    
    return _uploadProgressContainer;
}

- (void)uploadCancelButtonPressed
{
    id<ASWatcher> watcher = _watcher.delegate;
    if (watcher != nil && [watcher respondsToSelector:@selector(actionStageActionRequested:options:)])
    {
        [watcher actionStageActionRequested:@"cancelMessageProgress" options:[[NSDictionary alloc] initWithObjectsAndKeys:[[NSNumber alloc] initWithInt:_message.mid], @"mid", nil]];
    }
}

- (void)mediaActionButtonPressed
{
    if (_mediaNeedsDownload)
    {
        if (_messageItem.progressMediaId != nil)
            [_watcher requestAction:@"downloadMedia" options:_messageItem.progressMediaId];
    }
    else
    {
        UIView *container = _asyncContentContainer.hidden ? _contentContainer : _asyncContentContainer;
        for (TGLayoutItem *item in ((TGLayoutModel *)_message.cachedLayoutData).items)
        {
            if ([self activateMedia:item container:container])
                return;
        }
    }
}

- (void)setProgress:(bool)visible progress:(float)progress animated:(bool)animated
{
    if (visible)
    {   
        if (animated)
        {
            if (self.uploadProgressContainer.hidden)
            {
                self.uploadProgressContainer.hidden = false;
                
                _uploadProgress = 0.0f;
                
                [self layoutProgress];
                if (_uploadProgressForeground.hidden)
                    _uploadProgressForeground.alpha = 0.0f;
                
                _uploadProgress = progress;
            }
            
            _uploadProgress = progress;
            
            [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseOut animations:^
            {
                [self layoutProgress];
                if (!_uploadProgressForeground.hidden)
                    _uploadProgressForeground.alpha = 1.0f;
            } completion:nil];
        }
        else
        {
            _uploadProgress = progress;
            
            self.uploadProgressContainer.hidden = false;
            [self layoutProgress];
        }
        
        _mediaActionButton.hidden = true;
        
        if (_mediaSize > 0)
        {
            [self setHiddenToItemsWithAdditionalTag:2 hidden:true];
            [self setHiddenToItemsWithAdditionalTag:3 hidden:false];
            
            int labelTag = [self itemWithAdditionalTag:3].tag;
            UIView *view = [self.contentView viewWithTag:labelTag];
            if (view != nil && [view isKindOfClass:[TGSimpleReusableLabel class]])
            {
                NSString *progressText = nil;
                if (_mediaSize > 1024)
                    progressText = [[NSString alloc] initWithFormat:@"%.1f %@ %.1f Mb", _mediaSize * progress / (1024.0f * 1024.0f), TGLocalizedStatic(@"Common.of"), _mediaSize / (1024.0f * 1024.0f)];
                else
                    progressText = [[NSString alloc] initWithFormat:@"%d %@ %d Kb", (int)(_mediaSize * progress / 1024), TGLocalizedStatic(@"Common.of"), _mediaSize / 1024];
                
                ((TGSimpleReusableLabel *)view).text = progressText;
            }
        }
    }
    else
    {
        _uploadProgress = progress;
        
        if (_uploadProgressContainer != nil)
        {
            _uploadProgressContainer.hidden = true;
        }
        
        _mediaActionButton.hidden = false;
        
        if (_mediaActionButton != nil && _mediaSize > 0)
        {
            [self setHiddenToItemsWithAdditionalTag:2 hidden:false];
            [self setHiddenToItemsWithAdditionalTag:3 hidden:true];
        }
    }
}

- (void)updateMediaActionButton
{
    if ([_messageItem hasSomeAttachment])
    {
        NSString *actionText = nil;
        NSString *shortActionText = nil;
        
        for (TGMediaAttachment *attachment in _messageItem.message.mediaAttachments)
        {
            int type = attachment.type;
            if (type == TGImageMediaAttachmentType)
            {
                if (_mediaNeedsDownload)
                {
                    actionText = TGLocalizedStatic(@"Conversation.DownloadPhoto");
                    shortActionText = TGLocalizedStatic(@"Conversation.Download");
                }
                else
                    actionText = TGLocalizedStatic(@"Conversation.ViewPhoto");
                
                break;
            }
            else if (type == TGVideoMediaAttachmentType)
            {
                if (_mediaNeedsDownload)
                {
                    TGVideoMediaAttachment *videoAttachment = (TGVideoMediaAttachment *)attachment;
                    int size = 0;
                    [videoAttachment.videoInfo urlWithQuality:0 actualQuality:NULL actualSize:&size];
                    
                    _mediaSize = size;
                    if (size > 1024)
                        actionText = [[NSString alloc] initWithFormat:TGLocalized(@"Conversation.DownloadMegabytes"), size / (1024.0f * 1024.0f)];
                    else
                        actionText = [[NSString alloc] initWithFormat:TGLocalizedStatic(@"Conversation.DownloadKilobytes"), size / 1024];
                    shortActionText = TGLocalizedStatic(@"Conversation.Download");
                }
                else
                    actionText = TGLocalizedStatic(@"Conversation.PlayVideo");
                
                break;
            }
            else if (type == TGLocationMediaAttachmentType)
            {
                actionText = TGLocalizedStatic(@"Conversation.ViewLocation");
            }
        }
        
        if (actionText != nil)
        {
            if (_mediaActionButton == nil)
            {
                _mediaActionButton = (TGMediaActionButton *)[_viewRecycler dequeueReusableViewWithIdentifier:@"MAB"];
                if (_mediaActionButton == nil)
                {
                    static UIImage *buttonImage = nil;
                    static UIImage *buttonHighlightedImage = nil;
                    if (buttonImage == nil)
                    {
                        UIImage *rawButtonImage = [UIImage imageNamed:@"MediaActionButton.png"];
                        buttonImage = [rawButtonImage stretchableImageWithLeftCapWidth:(int)(rawButtonImage.size.width / 2) topCapHeight:0];
                        rawButtonImage = [UIImage imageNamed:@"MediaActionButton_Highlighted.png"];
                        buttonHighlightedImage = [rawButtonImage stretchableImageWithLeftCapWidth:(int)(rawButtonImage.size.width / 2) topCapHeight:0];
                    }
                    
                    _mediaActionButton = [[TGMediaActionButton alloc] init];
                    _mediaActionButton.reuseIdentifier = @"MAB";
                    _mediaActionButton.multipleTouchEnabled = false;
                    [_mediaActionButton setBackgroundImage:buttonImage forState:UIControlStateNormal];
                    [_mediaActionButton setBackgroundImage:buttonHighlightedImage forState:UIControlStateHighlighted];
                    
                    [_mediaActionButton setTitleColor:UIColorRGB(0x506e8d) forState:UIControlStateNormal];
                    [_mediaActionButton setTitleShadowColor:UIColorRGBA(0xffffff, 0.7f) forState:UIControlStateNormal];
                    [_mediaActionButton setTitleShadowColor:UIColorRGBA(0xffffff, 0.5f) forState:UIControlStateHighlighted];
                    _mediaActionButton.titleLabel.shadowOffset = CGSizeMake(0, 1);
                    _mediaActionButton.titleLabel.font = [UIFont boldSystemFontOfSize:13];
                    if (TGIsRetina())
                        _mediaActionButton.titleEdgeInsets = UIEdgeInsetsMake(0.5f, 0, 0, 0);
                    _mediaActionButton.contentEdgeInsets = UIEdgeInsetsMake(0, 15, 0, 15);
                }
                
                [_mediaActionButton addTarget:self action:@selector(mediaActionButtonPressed) forControlEvents:UIControlEventTouchUpInside];
                [self.contentView addSubview:_mediaActionButton];
            }
            
            _mediaActionButton.alpha = 1.0f;
            [_mediaActionButton setTitleText:actionText shortTitleText:shortActionText == nil ? actionText : shortActionText];
            //[_mediaActionButton setTitle:actionText forState:UIControlStateNormal];
        }
        
        [self setNeedsLayout];
    }
}

- (void)setMediaNeedsDownload:(bool)mediaNeedsDownload
{
    _mediaNeedsDownload = mediaNeedsDownload;
    
    if (_mediaActionButton != nil)
        [self updateMediaActionButton];
}

- (void)reloadImageThumbnailWithUrl:(NSString *)url
{
    for (TGLayoutItem *item in ((TGLayoutModel *)_message.cachedLayoutData).items)
    {
        if (item.type == TGLayoutItemTypeRemoteImage)
        {
            TGLayoutRemoteImageItem *imageItem = (TGLayoutRemoteImageItem *)item;
            
            TGRemoteImageView *imageView = (TGRemoteImageView *)[_asyncContentContainer.hidden ? _contentContainer : _asyncContentContainer viewWithTag:item.tag];
            if ([imageView isKindOfClass:[TGRemoteImageView class]])
            {
                if ([imageItem.url isEqualToString:url])
                {
                    UIImage *image = imageView.currentImage;
                    imageView.placeholderOverlay.hidden = image != nil;
                    [imageView loadImage:imageItem.url filter:imageItem.filter placeholder:image != nil ? image : imageItem.placeholder forceFade:true];
                }
            }
        }
    }
}

- (UIView *)currentContentView
{
    return _asyncContentContainer.hidden ? _contentContainer : _asyncContentContainer;
}

- (UIView *)currentBackgroundView
{
    return _messageNormalBackgroundView;   
}

- (CGRect)contentFrameInView:(UIView *)view
{
    if (!_contentContainer.hidden)
    {
        CGRect rect = [self.contentView convertRect:_contentContainer.frame toView:view];
        rect.size.width = MAX(10, rect.size.width - 24);
        rect.size.height = MAX(10, rect.size.height - 12);
        if (_message.actionInfo != nil)
            rect.origin.x += 14;
        return rect;
    }
    else if (!_asyncContentContainer.hidden)
    {
        CGRect rect = [self.contentView convertRect:_asyncContentContainer.frame toView:view];
        rect.size.width = MAX(10, rect.size.width - 24);
        rect.size.height = MAX(10, rect.size.height - 12);
        if (_message.actionInfo != nil)
            rect.origin.x += 14;
        return rect;
    }
    
    return CGRectZero;
}

- (CGRect)rectForItemWithClass:(Class)itemClass
{   
    if (!_asyncContentContainer.hidden)
    {
        UIView *view = nil;
        for (UIView *subview in _asyncContentContainer.subviews)
        {
            if ([subview isKindOfClass:itemClass])
            {
                view = subview;
                break;
            }
        }
        if (view != nil)
            return [self convertRect:view.bounds fromView:view];
    }
    else
    {
        UIView *view = nil;
        for (UIView *subview in _contentContainer.subviews)
        {
            if ([subview isKindOfClass:itemClass])
            {
                view = subview;
                break;
            }
        }
        if (view != nil)
        {
            CGRect rect = view.bounds;
            return [self convertRect:rect fromView:view];
        }
    }
    
    return CGRectZero;
}

- (UIView *)viewForItemWithClass:(Class)itemClass
{
    if (!_asyncContentContainer.hidden)
    {
        UIView *view = nil;
        for (UIView *subview in _asyncContentContainer.subviews)
        {
            if ([subview isKindOfClass:itemClass])
            {
                view = subview;
                break;
            }
        }
        
        return view;
    }
    else
    {
        UIView *view = nil;
        for (UIView *subview in _contentContainer.subviews)
        {
            if ([subview isKindOfClass:itemClass])
            {
                view = subview;
                break;
            }
        }
        
        return view;
    }
    
    return nil;
}

- (TGLayoutItem *)itemWithAdditionalTag:(int)additionalTag
{
    for (TGLayoutItem *item in ((TGLayoutModel *)_message.cachedLayoutData).items)
    {
        if (item.additionalTag == additionalTag && item.tag != 0)
            return item;
    }
    
    return nil;
}

- (void)setAlphaToItemsWithAdditionalTag:(int)additionalTag alpha:(float)alpha
{
    for (TGLayoutItem *item in ((TGLayoutModel *)_message.cachedLayoutData).items)
    {
        if (item.additionalTag == additionalTag && item.tag != 0)
        {
            UIView *view = [self.contentView viewWithTag:item.tag];
            view.alpha = alpha;
        }
    }
}

- (void)setHiddenToItemsWithAdditionalTag:(int)additionalTag hidden:(bool)hidden
{
    for (TGLayoutItem *item in ((TGLayoutModel *)_message.cachedLayoutData).items)
    {
        if (item.additionalTag == additionalTag && item.tag != 0)
        {
            UIView *view = [self.contentView viewWithTag:item.tag];
            view.hidden = hidden;
        }
    }
}

- (void)transitionContent:(NSTimeInterval)__unused duration
{
}

- (void)refreshLayout:(int)__unused metrics
{
    if (_message != nil && _message.cachedLayoutData != nil)
    {
        [(TGLayoutModel *)_message.cachedLayoutData updateLayoutInView:self];
        _validMetrics = ((TGLayoutModel *)_message.cachedLayoutData).metrics;
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    if (_message == nil)
    {
        TGLog(@"%s:%d: warning: message is nil", __PRETTY_FUNCTION__, __LINE__);
        return;
    }
    
    float retinaPixel = TGIsRetina() ? 0.5f : 0.0f;
    
    bool isAction = _message.actionInfo != nil;
    
    int indentX = 0;
    bool editing = _isReallyEditing;
    if (editing && (!_message.outgoing || isAction))
    {
        indentX = 35;
    }
    
    CGRect contentViewFrame = self.frame;
    
    if (_cellBackgroundView != nil)
        _cellBackgroundView.frame = CGRectMake(0, -1, contentViewFrame.size.width, contentViewFrame.size.height - 1);
    
    if (_editingSeparatorViewBottom != nil)
        _editingSeparatorViewBottom.frame = CGRectMake(0, -2, contentViewFrame.size.width, 2);
    
    contentViewFrame.origin.y = 0;
    contentViewFrame.origin.x = indentX;
    contentViewFrame.size.width -= indentX;
    self.contentView.frame = contentViewFrame;
    
    int metrics = 0;
    if (self.frame.size.width <= 321)
        metrics |= TGConversationMessageMetricsPortrait;
    else
        metrics |= TGConversationMessageMetricsLandscape;
    
    if (_showAvatar)
        metrics |= TGConversationMessageMetricsShowAvatars;
    
    bool refreshContentContainerFrame = false;
    
    TGLayoutModel *layout = (TGLayoutModel *)_message.cachedLayoutData;
    if (layout != nil && layout.metrics == metrics)
    {
        if (metrics != _validMetrics)
        {
            [self refreshLayout:metrics];
            [self updateBackground:_message.cachedLayoutData];
            if (!_contentContainer.hidden)
            {
                _contentContainer.layout = layout;
            }
            refreshContentContainerFrame = true;
        }
    }
    else
    {
        layout = [TGConversationMessageItemView layoutModelForMessage:_messageItem withMetrics:metrics assetsSource:TGGlobalAssetsSource];
        _message.cachedLayoutData = layout;
        [self refreshLayout:metrics];
        [self updateBackground:_message.cachedLayoutData];
        
        if (!_contentContainer.hidden)
        {
            _contentContainer.layout = layout;
        }
        refreshContentContainerFrame = true;
        
        //VKLog(@"Recalculated layout %x", (int)self);
    }
    
    bool singleMessage = false;
    
    if (layout == nil)
    {
        TGLog(@"%s:%d: warning: layout is nil", __PRETTY_FUNCTION__, __LINE__);
        return;
    }
    
    int selfWidth = (int)self.frame.size.width;
    
    CGSize layoutSize = layout.size;
    
    bool isIncoming = !_message.outgoing;
    
    UIEdgeInsets bodyMargins = singleMessage ? UIEdgeInsetsMake(0, 0, 0, 0) : [TGGlobalAssetsSource messageBodyMargins];
    UIEdgeInsets bodyPaddings = singleMessage ? UIEdgeInsetsMake(0, 0, 0, 0) : (isIncoming ? [TGGlobalAssetsSource messageBodyPaddingsIncoming] : [TGGlobalAssetsSource messageBodyPaddingsOutgoing]);
    
    if (isAction)
        bodyPaddings = UIEdgeInsetsMake(5, 0, 4, 0);
    
    CGRect bodyFrame = CGRectMake(floorf(bodyMargins.left), floorf(bodyMargins.top), floorf(layoutSize.width), floorf(layoutSize.height));
    if (singleMessage)
        bodyFrame.size.width = self.frame.size.width - bodyMargins.left - bodyMargins.right;
    
    if (!isIncoming && !singleMessage && !isAction)
        bodyFrame.origin.x = selfWidth - bodyFrame.size.width - bodyMargins.right;
    
    if (isAction)
    {
        bodyFrame.origin.x = (int)((selfWidth - bodyFrame.size.width) / 2);
    }
    else if ((metrics & TGConversationMessageMetricsShowAvatars) && !_message.outgoing && !isAction)
    {
        const int avatarWidth = 38;
        const int avatarHeight = 38;
        
        if (isIncoming)
        {
            _avatarView.frame = CGRectMake(bodyFrame.origin.x + 4, bodyFrame.origin.y + bodyFrame.size.height - avatarHeight - 1, avatarWidth, avatarHeight);
            bodyFrame.origin.x += avatarWidth + 4;
        }
        else
        {
            _avatarView.frame = CGRectMake(bodyFrame.origin.x + bodyFrame.size.width - avatarWidth - 4, bodyFrame.origin.y + bodyFrame.size.height - avatarHeight - 1, avatarWidth, avatarHeight);
            bodyFrame.origin.x -= avatarWidth + 4;
        }
    }
    
    CGRect dateFrame = _dateLabel.frame;
    if (isIncoming)
        dateFrame.origin.x = bodyFrame.origin.x + bodyFrame.size.width + 12;
    else
        dateFrame.origin.x = bodyFrame.origin.x - 26 - retinaPixel - dateFrame.size.width;
    dateFrame.origin.y = bodyFrame.origin.y + bodyFrame.size.height - 22;
    _dateLabel.frame = dateFrame;
    
    _dateBackgroundView.frame = isIncoming ? CGRectMake(dateFrame.origin.x - 10, dateFrame.origin.y - 3 - retinaPixel, dateFrame.size.width + 16, 21) : CGRectMake(dateFrame.origin.x - 5, dateFrame.origin.y - 3 - retinaPixel, dateFrame.size.width + 29, 21);
    
    CGRect contentFrame = _contentContainer.hidden ? _asyncContentContainer.frame : _contentContainer.frame;
    contentFrame.origin = CGPointMake(bodyFrame.origin.x + bodyPaddings.left, bodyFrame.origin.y + bodyPaddings.top);
    if (refreshContentContainerFrame)
    {
        contentFrame.size = CGSizeMake(layout.size.width, layout.size.height);
        
        if (!_contentContainer.hidden)
        {
            _contentContainer.frame = contentFrame;
            [_contentContainer setNeedsDisplay];
        }
        
        if (!_asyncContentContainer.hidden)
        {
            _asyncContentContainer.frame = contentFrame;
            [self doForegroundRendering];
        }
    }
    else
    {
        if (!_contentContainer.hidden)
            _contentContainer.frame = contentFrame;
        if (!_asyncContentContainer.hidden)
            _asyncContentContainer.frame = contentFrame;
    }
    
    _statusContainerView.frame = CGRectMake(dateFrame.origin.x + dateFrame.size.width - 30, _dateLabel.frame.origin.y - 3, _statusContainerView.frame.size.width, 20);
    
    if (_checkView != nil)
        _checkView.frame = CGRectMake(editing ? 2 : (-35), (int)((self.contentView.frame.size.height - 35) / 2) - 1, 35, 35);
    
    _messageNormalBackgroundView.frame = bodyFrame;
    if (_messageHighlightedBackgroundView != nil)
        _messageHighlightedBackgroundView.frame = bodyFrame;
    if (_messageHighlightedForegroundView != nil)
    {
        CGRect foregroundFrame = bodyFrame;
        foregroundFrame.origin.y += 3;
        foregroundFrame.size.height -= 5.5f;
        foregroundFrame.origin.x += !isIncoming ? 3.5f : 7.5f;
        foregroundFrame.size.width -= 11;
        _messageHighlightedForegroundView.frame = foregroundFrame;
    }
    
    if (_uploadProgressContainer != nil)
        [self layoutProgress];
    
    if (_mediaActionButton != nil)
    {
        float maxButtonWidth = MAX(0, isIncoming ? (contentViewFrame.size.width - (bodyFrame.origin.x + bodyFrame.size.width + 7)) : 1000);
        CGSize buttonSize = [_mediaActionButton sizeThatFits:CGSizeMake(maxButtonWidth, 100)];
        
        CGRect actionButtonFrame = _mediaActionButton.frame;
        actionButtonFrame.size = buttonSize;
        
        actionButtonFrame.origin.x = isIncoming ? (bodyFrame.origin.x + bodyFrame.size.width + 7) : (bodyFrame.origin.x - actionButtonFrame.size.width - 8);
        actionButtonFrame.origin.y = bodyFrame.origin.y + MIN(bodyFrame.size.height - 24 - actionButtonFrame.size.height - 13, floorf((bodyFrame.size.height - actionButtonFrame.size.height) / 2) - 2);
        
        //if (actionButtonFrame.origin.x + actionButtonFrame.size.width > contentViewFrame.size.width)
        //    actionButtonFrame.size.width = MAX(0, contentViewFrame.size.width - actionButtonFrame.origin.x);
        
        _mediaActionButton.frame = actionButtonFrame;
    }
}

- (void)layoutProgress
{
    CGRect contentViewFrame = self.frame;
    CGRect bodyFrame = _messageNormalBackgroundView.frame;
    
    bool isOutgoing = _message.outgoing;
    float startX = (isOutgoing ? 8 : (bodyFrame.origin.x + bodyFrame.size.width + 4)) + (_isReallyEditing ? 30 : 0);
    float width = isOutgoing ? (bodyFrame.origin.x - startX - 4) : (contentViewFrame.size.width - 8 - startX);
    
    CGRect buttonFrame = _uploadProgressCancelButton.frame;
    buttonFrame.origin.x = isOutgoing ? 0 : (_uploadProgressContainer.frame.size.width - buttonFrame.size.width);
    _uploadProgressCancelButton.frame = buttonFrame;
    _uploadProgressContainer.frame = CGRectMake(startX, bodyFrame.origin.y + floorf((bodyFrame.size.height - 26) / 2), width, _uploadProgressContainer.frame.size.height);
    _uploadProgressBackground.frame = CGRectMake(isOutgoing ? 25 : 0, 4, _uploadProgressContainer.frame.size.width - 25, _uploadProgressBackground.frame.size.height);
    float progressWidthFloat = _uploadProgress * (_uploadProgressBackground.frame.size.width - 2);
    int progressWidth = MAX(_uploadProgress > FLT_EPSILON ? 13 : 0, ((int)(progressWidthFloat * 2.0f)) / 2);
    _uploadProgressForeground.hidden = progressWidth < 13;
    _uploadProgressForeground.frame = CGRectMake(_uploadProgressBackground.frame.origin.x + 1, 5, MAX(progressWidth, 13), _uploadProgressForeground.frame.size.height);
}

#pragma mark - actions

- (void)deliveryStatusTapped:(UITapGestureRecognizer *)recognizer
{
    if (_message.deliveryState == TGMessageDeliveryStateFailed && recognizer.state == UIGestureRecognizerStateEnded && !self.editing)
    {
        if (_watcher != nil && _watcher.delegate != nil && [_watcher.delegate respondsToSelector:@selector(actionStageActionRequested:options:)])
        {
            [_watcher.delegate actionStageActionRequested:[NSString stringWithFormat:@"/tg/conversation/showMessageResendMenu/(%d)", _message.mid] options:nil];
        }
    }
}

- (void)dateTapped:(UITapGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateRecognized && !self.editing)
    {
        CGRect frame = [_dateBackgroundView convertRect:_dateBackgroundView.bounds toView:self];
        [_watcher requestAction:@"showMessageDateTooltip" options:[[NSDictionary alloc] initWithObjectsAndKeys:[[NSNumber alloc] initWithInt:_message.mid], @"mid", self, @"cell", [NSValue valueWithCGRect:frame], @"frame", nil]];
    }
}

- (void)avatarTapped:(UITapGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateRecognized && !self.editing)
    {
        if (_watcher != nil && _watcher.delegate != nil && [_watcher.delegate respondsToSelector:@selector(actionStageActionRequested:options:)])
        {
            [_watcher.delegate actionStageActionRequested:[NSString stringWithFormat:@"/tg/conversation/avatarTapped"] options:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:(int)_message.fromUid] forKey:@"uid"]];
        }
    }
}

- (bool)activateMedia:(TGLayoutItem *)item container:(UIView *)container
{
    if (item.type == TGLayoutItemTypeRemoteImage)
    {
        TGLayoutRemoteImageItem *remoteImageItem = (TGLayoutRemoteImageItem *)item;
        TGRemoteImageView *imageView = (TGRemoteImageView *)[container viewWithTag:remoteImageItem.tag];
        if (imageView == nil || ![imageView isKindOfClass:[TGRemoteImageView class]])
            return false;
        
        if ([remoteImageItem.attachmentInfo objectForKey:@"imageInfo"] != nil)
        {
            UIImage *currentImage = imageView.currentImage;
            
            TGImageInfo *imageInfo = [remoteImageItem.attachmentInfo objectForKey:@"imageInfo"];
            
            if (currentImage != nil && imageInfo && _watcher != nil && _watcher.delegate != nil && [_watcher.delegate respondsToSelector:@selector(actionStageActionRequested:options:)])
            {
                NSMutableDictionary *options = [[NSMutableDictionary alloc] init];
                [options setObject:imageView forKey:@"imageView"];
                [options setObject:self forKey:@"cell"];
                [options setObject:[NSNumber numberWithInt:_message.mid] forKey:@"messageId"];
                [options setObject:imageInfo forKey:@"imageInfo"];
                [options setObject:currentImage forKey:@"thumbnail"];
                if (imageView.currentUrl != nil)
                    [options setObject:imageView.currentUrl forKey:@"thumbnailUrl"];
                [options setObject:[NSNumber numberWithInt:item.tag] forKey:@"attachmentTag"];
                CGRect rect = [imageView convertRect:imageView.bounds toView:self.window];
                [options setObject:[NSValue valueWithCGRect:rect] forKey:@"windowSpaceFrame"];
                
                [_watcher.delegate actionStageActionRequested:@"openImage" options:options];
                
                return true;
            }
        }
        else if ([remoteImageItem.attachmentInfo objectForKey:@"videoAttachment"] != nil)
        {
            if (_mediaNeedsDownload)
            {
                if (_uploadProgressContainer.alpha < FLT_EPSILON)
                {
                    if (_messageItem.progressMediaId != nil)
                        [_watcher requestAction:@"downloadMedia" options:_messageItem.progressMediaId];
                }
                return false;
            }
            
            UIImage *currentImage = imageView.currentImage;
            
            TGVideoMediaAttachment *videoAttachment = [remoteImageItem.attachmentInfo objectForKey:@"videoAttachment"];
            
            if (currentImage != nil && videoAttachment && _watcher != nil && _watcher.delegate != nil && [_watcher.delegate respondsToSelector:@selector(actionStageActionRequested:options:)])
            {
                NSMutableDictionary *options = [[NSMutableDictionary alloc] init];
                [options setObject:imageView forKey:@"imageView"];
                [options setObject:self forKey:@"cell"];
                [options setObject:[NSNumber numberWithInt:_message.mid] forKey:@"messageId"];
                [options setObject:videoAttachment forKey:@"videoAttachment"];
                [options setObject:currentImage forKey:@"thumbnail"];
                if (imageView.currentUrl != nil)
                    [options setObject:imageView.currentUrl forKey:@"thumbnailUrl"];
                [options setObject:[NSNumber numberWithInt:item.tag] forKey:@"attachmentTag"];
                CGRect rect = [imageView convertRect:imageView.bounds toView:self.window];
                [options setObject:[NSValue valueWithCGRect:rect] forKey:@"windowSpaceFrame"];
                
                [_watcher.delegate actionStageActionRequested:@"openImage" options:options];
                
                return true;
            }
        }
        else if ([remoteImageItem.attachmentInfo objectForKey:@"latitude"] != nil)
        {
            if (_watcher != nil && _watcher.delegate != nil && [_watcher.delegate respondsToSelector:@selector(actionStageActionRequested:options:)] && _message != nil)
            {
                [_watcher.delegate actionStageActionRequested:@"openMap" options:@{
                    @"locationInfo": remoteImageItem.attachmentInfo,
                    @"message": _message
                }];
                
                return true;
            }
        }
    }
    
    return false;
}

- (bool)findAndActivateMedia:(CGPoint)point container:(UIView *)container
{
    for (TGMediaAttachment *attachment in _message.mediaAttachments)
    {
        if (attachment.type == TGContactMediaAttachmentType)
        {
            TGContactMediaAttachment *contactAttachment = (TGContactMediaAttachment *)attachment;
            [_watcher requestAction:@"openContact" options:[[NSDictionary alloc] initWithObjectsAndKeys:contactAttachment, @"contactAttachment", nil]];
            return true;
        }
    }
    
    TGLayoutModel *layout = (TGLayoutModel *)_message.cachedLayoutData;
    if (layout != nil)
    {
        TGLayoutItem *item = [layout itemAtPoint:point];
        if ([self activateMedia:item container:container])
            return true;
    }
    
    return false;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    if (_uploadProgressContainer != nil && !_uploadProgressContainer.hidden)
    {
        if (CGRectContainsPoint([_uploadProgressCancelButton convertRect:_uploadProgressCancelButton.bounds toView:self], point))
            return [_uploadProgressCancelButton hitTest:[_uploadProgressCancelButton convertPoint:point fromView:self] withEvent:event];
    }
    
    if (!_dateBackgroundView.hidden && CGRectContainsPoint(_dateBackgroundView.frame, point))
        return _dateBackgroundView;
    
    return [super hitTest:point withEvent:event];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesBegan:touches withEvent:event];
    
    if (!self.editing)
    {
        CGPoint location;
        CGPoint containerPosition;
        if (!_asyncContentContainer.hidden)
        {
            location = [[touches anyObject] locationInView:_asyncContentContainer];
            containerPosition = _asyncContentContainer.frame.origin;
        }
        else
        {
            location = [[touches anyObject] locationInView:_contentContainer];
            containerPosition = _contentContainer.frame.origin;
        }
        
        [self tapLink:location containerPosition:containerPosition highlight:true action:false];
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesEnded:touches withEvent:event];
    
    [self clearLinkHighlights];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesCancelled:touches withEvent:event];
    
    [self clearLinkHighlights];
}

- (void)cellTapped:(UITapGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateRecognized && _isReallyEditing)
    {
        if (_watcher != nil && _watcher.delegate != nil && [_watcher.delegate respondsToSelector:@selector(actionStageActionRequested:options:)])
        {
            [_watcher.delegate actionStageActionRequested:[NSString stringWithFormat:@"toggleMessageChecked"] options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:_message.mid], @"mid", [NSNumber numberWithInt:_message.localMid], @"localMid", nil]];
        }
    }
}

- (int)gestureRecognizer:(TGDoubleTapGestureRecognizer *)recognizer shouldFailTap:(CGPoint)point
{
    if ([self activeButtonAtPoint:[recognizer locationInView:recognizer.view]])
        return 2;
    else if (![self tapLink:[recognizer locationInView:recognizer.view] containerPosition:recognizer.view.frame.origin highlight:false action:true])
    {
        if ([self findAndActivateMedia:point container:recognizer.view])
            return 1;
    }
    else
        return 1;
    
    return false;
}

- (void)containerLongPressed:(UILongPressGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateBegan && !self.editing)
    {
        if (![self longPressLink:[recognizer locationInView:_contentContainer]])
        {
            [self longPressMessage];
        }
    }
}

- (void)containerDoubleTapped:(TGDoubleTapGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateRecognized && !self.editing && recognizer.doubleTapped)
    {
        if (![self longPressLink:[recognizer locationInView:_contentContainer]])
        {
            [self longPressMessage];
        }
    }
}

- (void)doubleTapGestureRecognizerSingleTapped:(TGDoubleTapGestureRecognizer *)__unused recognizer
{
    [_watcher requestAction:@"messageBackgroundTapped" options:nil];
}

- (void)asyncContainerLongPressed:(UILongPressGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateBegan)
    {
        if (![self longPressLink:[recognizer locationInView:_asyncContentContainer]])
        {
            [self longPressMessage];
        }
    }
}

- (void)highlightLink:(CGRect)topRegion middleRegion:(CGRect)middleRegion bottomRegion:(CGRect)bottomRegion
{
    UIImageView *topView = nil;
    UIImageView *middleView = nil;
    UIImageView *bottomView = nil;
    
    UIImageView *topCornerLeft = nil;
    UIImageView *topCornerRight = nil;
    UIImageView *bottomCornerLeft = nil;
    UIImageView *bottomCornerRight = nil;

    if (_linkHighlightedViews == nil)
    {
        _linkHighlightedViews = [[NSMutableArray alloc] init];
        
        topView = [[UIImageView alloc] init];
        [_linkHighlightedViews addObject:topView];
        [self.contentView addSubview:topView];
        
        middleView = [[UIImageView alloc] init];
        [_linkHighlightedViews addObject:middleView];
        [self.contentView addSubview:middleView];
        
        bottomView = [[UIImageView alloc] init];
        [_linkHighlightedViews addObject:bottomView];
        [self.contentView addSubview:bottomView];
        
        topCornerLeft = [[UIImageView alloc] init];
        [_linkHighlightedViews addObject:topCornerLeft];
        [self.contentView addSubview:topCornerLeft];
        
        topCornerRight = [[UIImageView alloc] init];
        [_linkHighlightedViews addObject:topCornerRight];
        [self.contentView addSubview:topCornerRight];
        
        bottomCornerLeft = [[UIImageView alloc] init];
        [_linkHighlightedViews addObject:bottomCornerLeft];
        [self.contentView addSubview:bottomCornerLeft];
        
        bottomCornerRight = [[UIImageView alloc] init];
        [_linkHighlightedViews addObject:bottomCornerRight];
        [self.contentView addSubview:bottomCornerRight];
    }
    else
    {
        topView = [_linkHighlightedViews objectAtIndex:0];
        middleView = [_linkHighlightedViews objectAtIndex:1];
        bottomView = [_linkHighlightedViews objectAtIndex:2];
        topCornerLeft = [_linkHighlightedViews objectAtIndex:3];
        topCornerRight = [_linkHighlightedViews objectAtIndex:4];
        bottomCornerLeft = [_linkHighlightedViews objectAtIndex:5];
        bottomCornerRight = [_linkHighlightedViews objectAtIndex:6];
    }
    
    if (topRegion.size.height != 0)
    {
        topView.hidden = false;
        topView.frame = topRegion;
        if (middleRegion.size.height == 0 && bottomRegion.size.height == 0)
            topView.image = [TGGlobalAssetsSource messageLinkFull];
        else
            topView.image = [TGGlobalAssetsSource messageLinkFull];
    }
    else
    {
        topView.hidden = true;
        topView.frame = CGRectZero;
    }
    
    if (middleRegion.size.height != 0)
    {
        middleView.hidden = false;
        middleView.frame = middleRegion;
        if (bottomRegion.size.height == 0)
            middleView.image = [TGGlobalAssetsSource messageLinkFull];
        else
            middleView.image = [TGGlobalAssetsSource messageLinkFull];
    }
    else
    {
        middleView.hidden = true;
        middleView.frame = CGRectZero;
    }
    
    if (bottomRegion.size.height != 0)
    {
        bottomView.hidden = false;
        bottomView.frame = bottomRegion;
        bottomView.image = [TGGlobalAssetsSource messageLinkFull];
    }
    else
    {
        bottomView.hidden = true;
        bottomView.frame = CGRectZero;
    }
    
    topCornerLeft.hidden = true;
    topCornerRight.hidden = true;
    bottomCornerLeft.hidden = true;
    bottomCornerRight.hidden = true;
    
    if (topRegion.size.height != 0 && middleRegion.size.height != 0)
    {
        if (topRegion.origin.x == middleRegion.origin.x)
        {
            topCornerLeft.hidden = false;
            topCornerLeft.image = [TGGlobalAssetsSource messageLinkCornerLR];
            topCornerLeft.frame = CGRectMake(topRegion.origin.x, topRegion.origin.y + topRegion.size.height - 3.5f, 4, 7);
        }
        else if (topRegion.origin.x < middleRegion.origin.x + middleRegion.size.width - 3.5f)
        {
            topCornerLeft.hidden = false;
            topCornerLeft.image = [TGGlobalAssetsSource messageLinkCornerBT];
            topCornerLeft.frame = CGRectMake(topRegion.origin.x - 3.5f, topRegion.origin.y + topRegion.size.height - 4, 7, 4);
        }
        
        if (topRegion.origin.x + topRegion.size.width == middleRegion.origin.x + middleRegion.size.width)
        {
            topCornerRight.hidden = false;
            topCornerRight.image = [TGGlobalAssetsSource messageLinkCornerRL];
            topCornerRight.frame = CGRectMake(topRegion.origin.x + topRegion.size.width - 4, topRegion.origin.y + topRegion.size.height - 3.5f, 4, 7);
        }
        else if (topRegion.origin.x + topRegion.size.width < middleRegion.origin.x + middleRegion.size.width - 3.5f)
        {
            topCornerRight.hidden = false;
            topCornerRight.image = [TGGlobalAssetsSource messageLinkCornerBT];
            topCornerRight.frame = CGRectMake(topRegion.origin.x + topRegion.size.width - 3.5f, topRegion.origin.y + topRegion.size.height - 4, 7, 4);
        }
        else if (bottomRegion.size.height == 0 && topRegion.origin.x < middleRegion.origin.x + middleRegion.size.width - 3.5f && topRegion.origin.x + topRegion.size.width > middleRegion.origin.x + middleRegion.size.width + 3.5f)
        {
            topCornerRight.hidden = false;
            topCornerRight.image = [TGGlobalAssetsSource messageLinkCornerTB];
            topCornerRight.frame = CGRectMake(middleRegion.origin.x + middleRegion.size.width - 3.5f, middleRegion.origin.y, 7, 4);
        }
    }
    
    if (middleRegion.size.height != 0 && bottomRegion.size.height != 0)
    {
        if (middleRegion.origin.x == bottomRegion.origin.x)
        {
            bottomCornerLeft.hidden = false;
            bottomCornerLeft.image = [TGGlobalAssetsSource messageLinkCornerLR];
            bottomCornerLeft.frame = CGRectMake(middleRegion.origin.x, middleRegion.origin.y + middleRegion.size.height - 3.5f, 4, 7);
        }
        
        if (bottomRegion.origin.x + bottomRegion.size.width < middleRegion.origin.x + middleRegion.size.width - 3.5f)
        {
            bottomCornerRight.hidden = false;
            bottomCornerRight.image = [TGGlobalAssetsSource messageLinkCornerTB];
            bottomCornerRight.frame = CGRectMake(bottomRegion.origin.x + bottomRegion.size.width - 3.5f, bottomRegion.origin.y, 7, 4);
        }
    }
}

- (void)clearLinkHighlights
{
    for (UIView *view in _linkHighlightedViews)
    {
        view.hidden = true;
    }
}

- (bool)tapLink:(CGPoint)point containerPosition:(CGPoint)containerPosition highlight:(bool)highlight action:(bool)action
{
    if (_message == nil)
    {
        TGLog(@"%s:%d: warning: message is nil", __PRETTY_FUNCTION__, __LINE__);
        return false;
    }
    
    int metrics = 0;
    if (self.frame.size.width <= 321)
        metrics |= TGConversationMessageMetricsPortrait;
    else
        metrics |= TGConversationMessageMetricsLandscape;
    
    if (_showAvatar)
        metrics |= TGConversationMessageMetricsShowAvatars;
    
    TGLayoutModel *layout = (TGLayoutModel *)_message.cachedLayoutData;
    if (layout != nil && layout.metrics == metrics)
    {
        TGLayoutItem *item = [layout itemAtPoint:point];
        if (item != nil)
        {
            if (item.type == TGLayoutItemTypeText && (((TGLayoutTextItem *)item).flags & TGReusableLabelLayoutHighlightLinks) == 0)
                highlight = false;
            
            CGRect topRegion = CGRectZero;
            CGRect middleRegion = CGRectZero;
            CGRect bottomRegion = CGRectZero;
            NSString *link = [layout linkAtPoint:point topRegion:&topRegion middleRegion:&middleRegion bottomRegion:&bottomRegion];
            if (link != nil)
            {
                if (highlight)
                {
                    CGSize offset = CGSizeZero;
                    
                    offset.height = item.frame.origin.y;
                    offset.width = item.frame.origin.x;
                    
                    topRegion.origin.x += containerPosition.x + offset.width;
                    topRegion.origin.y += containerPosition.y + offset.height;

                    middleRegion.origin.x += containerPosition.x + offset.width;
                    middleRegion.origin.y += containerPosition.y + offset.height;
                    
                    bottomRegion.origin.x += containerPosition.x + offset.width;
                    bottomRegion.origin.y += containerPosition.y + offset.height;
                    
                    [self highlightLink:topRegion middleRegion:middleRegion bottomRegion:bottomRegion];
                }
                else
                {
                    [self clearLinkHighlights];
                }
                
                if (action)
                {
                    if (_watcher != nil && _watcher.delegate != nil && [_watcher.delegate respondsToSelector:@selector(actionStageActionRequested:options:)])
                    {
                        [_watcher.delegate actionStageActionRequested:[NSString stringWithFormat:@"openLink"] options:[NSDictionary dictionaryWithObject:link forKey:@"url"]];
                    }
                }
                
                return true;
            }
        }
    }
    
    return false;
}
    
- (bool)activeButtonAtPoint:(CGPoint)point
{
    TGLayoutItem *item = [_message.cachedLayoutData itemAtPoint:point];
    if (item != nil)
    {
        if (item.type == TGLayoutItemTypeButton)
            return true;
    }
    
    return false;
}

- (bool)longPressLink:(CGPoint)point
{
    if (_message == nil)
    {
        TGLog(@"%s:%d: warning: message is nil", __PRETTY_FUNCTION__, __LINE__);
        return false;
    }
    
    int metrics = 0;
    if (self.frame.size.width <= 321)
        metrics |= TGConversationMessageMetricsPortrait;
    else
        metrics |= TGConversationMessageMetricsLandscape;
    
    if (_showAvatar)
        metrics |= TGConversationMessageMetricsShowAvatars;
    
    TGLayoutModel *layout = (TGLayoutModel *)_message.cachedLayoutData;
    if (layout != nil && layout.metrics == metrics)
    {
        NSString *link = [layout linkAtPoint:point topRegion:NULL middleRegion:NULL bottomRegion:NULL];
        if (link != nil)
        {
            if (_watcher != nil && _watcher.delegate != nil && [_watcher.delegate respondsToSelector:@selector(actionStageActionRequested:options:)])
            {
                [_watcher.delegate actionStageActionRequested:[NSString stringWithFormat:@"showLinkOptions"] options:[NSDictionary dictionaryWithObject:link forKey:@"url"]];
            }
            
            return true;
        }
        
        for (TGLayoutItem *item in layout.items)
        {
            if (CGRectContainsPoint(item.frame, point))
            {
                if (item.type == TGLayoutItemTypeButton)
                    return true;
            }
        }
        
        //[self clearLinkHighlights];
    }

    return false;
}

- (void)longPressMessage
{
    if (_watcher != nil && _watcher.delegate != nil && [_watcher.delegate respondsToSelector:@selector(actionStageActionRequested:options:)])
    {
        [_watcher.delegate actionStageActionRequested:[NSString stringWithFormat:@"showMessageContextMenu"] options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:_message.mid], @"mid", [NSNumber numberWithInt:_message.localMid], @"localMid", nil]];
    }
}
    
- (void)layoutButtonPressed:(UIButton *)button
{
    TGLayoutModel *layout = (TGLayoutModel *)_message.cachedLayoutData;
    if (layout != nil)
    {
        for (TGLayoutItem *item in layout.items)
        {
            if (item.tag == button.tag)
            {
                if (item.type == TGLayoutItemTypeButton)
                {
                    [_watcher requestAction:@"acceptEncryption" options:nil];
                }
                
                break;
            }
        }
    }
}

@end
