#import "TGDialogListCell.h"

#import "TGDateUtils.h"

#import "TGHighlightImageView.h"
#import "TGReusableLabel.h"
#import "TGLabel.h"
#import "TGRemoteImageView.h"
#import "TGImageUtils.h"

#import "TGMessage.h"
#import "TGUser.h"

#import "TGDateLabel.h"

#import "TGHighlightTriggerLabel.h"

#import "TGSwipeGestureRecognizer.h"

#ifdef DEBUG
#   define TGTEST 0
#else
#   define TGTEST 0
#endif

#define TG_DELETE_BUTTON_WIDTH 80
#define TG_DELETE_BUTTON_OFFSET 6

static const float edgeDistance = 6;

static UIImage *normalMinusImage()
{
    static UIImage *image = nil;
    if (image == nil)
    {
        image = [UIImage imageNamed:@"ListEditingSwitchMinus.png"];
    }
    return image;
}

static UIImage *activeMinusImage()
{
    static UIImage *image = nil;
    if (image == nil)
    {
        image = [UIImage imageNamed:@"ListEditingSwitchMinus_Active.png"];
    }
    return image;
}

static UIImage *deleteButtonImage()
{
    static UIImage *image = nil;
    if (image == nil)
    {
        UIImage *rawImage = [UIImage imageNamed:@"ListDeleteButton.png"];
        image = [rawImage stretchableImageWithLeftCapWidth:(int)(rawImage.size.width / 2) topCapHeight:0];
    }
    return image;
}

static UIImage *deleteButtonHighlightedImage()
{
    static UIImage *image = nil;
    if (image == nil)
    {
        UIImage *rawImage = [UIImage imageNamed:@"ListDeleteButton_Highlighted.png"];
        image = [rawImage stretchableImageWithLeftCapWidth:(int)(rawImage.size.width / 2) topCapHeight:0];
    }
    return image;
}

static UIImage *deleteShadowImage()
{
    static UIImage *image = nil;
    if (image == nil)
    {
        UIImage *rawImage = [UIImage imageNamed:@"DialogListDeleteShadow.png"];
        image = [rawImage stretchableImageWithLeftCapWidth:(int)(rawImage.size.width - 1) topCapHeight:0];
    }
    return image;
}

static UIImage *deliveredCheckmark()
{
    static UIImage *image = nil;
    if (image == nil)
    {
        image = [UIImage imageNamed:@"DialogListSent.png"];
    }
    return image;
}

static UIImage *deliveredCheckmarkHighlighted()
{
    static UIImage *image = nil;
    if (image == nil)
    {
        image = [UIImage imageNamed:@"DialogListSent_Highlighted.png"];
    }
    return image;
}

static UIImage *readCheckmark()
{
    static UIImage *image = nil;
    if (image == nil)
    {
        image = [UIImage imageNamed:@"DialogListRead.png"];
    }
    return image;
}

static UIImage *readCheckmarkHighlighted()
{
    static UIImage *image = nil;
    if (image == nil)
    {
        image = [UIImage imageNamed:@"DialogListRead_Highlighted.png"];
    }
    return image;
}

static UIImage *arrowImage()
{
    static UIImage *image = nil;
    if (image == nil)
    {
        image = [UIImage imageNamed:@"DialogListArrow.png"];
    }
    return image;
}

static UIImage *arrowHighlightedImage()
{
    static UIImage *image = nil;
    if (image == nil)
    {
        image = [UIImage imageNamed:@"DialogListArrow_Highlighted.png"];
    }
    return image;
}

static UIColor *normalTextColor = nil;
static UIColor *actionTextColor = nil;
static UIColor *mediaTextColor = nil;

@interface TGDialogListTextView : UIView <TGHighlightable>

@property (nonatomic, strong) NSString *title;
@property (nonatomic) CGRect titleFrame;
@property (nonatomic, strong) UIFont *titleFont;
@property (nonatomic, strong) NSString *text;
@property (nonatomic, strong) UIColor *textColor;
@property (nonatomic) CGRect textFrame;
@property (nonatomic, strong) UIFont *textFont;
@property (nonatomic , strong) NSString *authorName;
@property (nonatomic) CGRect authorNameFrame;
@property (nonatomic, strong) UIFont *authorNameFont;

@property (nonatomic) CGRect typingFrame;
@property (nonatomic) bool showTyping;
@property (nonatomic, strong) NSString *typingText;

@property (nonatomic) BOOL highlighted;

@property (nonatomic) bool isMultichat;
@property (nonatomic) bool isEncrypted;
@property (nonatomic) bool isMuted;

@end

@implementation TGDialogListTextView

- (void)setHighlighted:(BOOL)highlighted
{
    if (_highlighted != highlighted)
    {
        _highlighted = highlighted;
        
        [self setNeedsDisplay];
    }
}

- (void)drawRect:(CGRect)rect
{
    static CGColorRef titleColor = nil;
    static CGColorRef encryptedTitleColor = nil;
    static CGColorRef highlightedColor = nil;
    static CGColorRef authorNameColor = nil;
    if (titleColor == nil)
    {
        titleColor = CGColorRetain([UIColorRGB(0x111111) CGColor]);
        encryptedTitleColor = CGColorRetain([UIColorRGB(0x229a0a) CGColor]);
        highlightedColor = CGColorRetain([[UIColor whiteColor] CGColor]);
        authorNameColor = CGColorRetain([UIColorRGB(0x345f8f) CGColor]);
    }
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGRect frame = self.frame;
    CGRect titleFrame = CGRectOffset(_titleFrame, -frame.origin.x, -frame.origin.y);
    CGRect textFrame = CGRectOffset(_textFrame, -frame.origin.x, -frame.origin.y);
    CGRect authorNameFrame = CGRectOffset(_authorNameFrame, -frame.origin.x, -frame.origin.y);
    CGRect typingFrame = CGRectOffset(_typingFrame, -frame.origin.x, -frame.origin.y);
    
    if (_isEncrypted)
    {
        UIImage *image = nil;
        
        if (!_highlighted)
        {
            static UIImage *multichatImage = nil;
            if (multichatImage == nil)
                multichatImage = [UIImage imageNamed:@"DialogListEncryptedChatIcon.png"];
            image = multichatImage;
        }
        else
        {
            static UIImage *multichatHighlightedImage = nil;
            if (multichatHighlightedImage == nil)
                multichatHighlightedImage = [UIImage imageNamed:@"DialogListEncryptedChatIcon_Highlighted.png"];
            image = multichatHighlightedImage;
        }
        
        [image drawAtPoint:CGPointMake(0, 3) blendMode:_highlighted ? kCGBlendModeCopy : kCGBlendModeNormal alpha:1.0f];
    }
    else if (_isMultichat)
    {
        UIImage *image = nil;
        
        if (!_highlighted)
        {
            static UIImage *multichatImage = nil;
            if (multichatImage == nil)
                multichatImage = [UIImage imageNamed:@"DialogListGroupChatIcon.png"];
            image = multichatImage;
        }
        else
        {
            static UIImage *multichatHighlightedImage = nil;
            if (multichatHighlightedImage == nil)
                multichatHighlightedImage = [UIImage imageNamed:@"DialogListGroupChatIcon_Highlighted.png"];
            image = multichatHighlightedImage;
        }
        
        [image drawAtPoint:CGPointMake(0, 4) blendMode:_highlighted ? kCGBlendModeCopy : kCGBlendModeNormal alpha:1.0f];
    }
    
    if (!_highlighted)
        CGContextSetFillColorWithColor(context, _isEncrypted ? encryptedTitleColor : titleColor);
    else
        CGContextSetFillColorWithColor(context, highlightedColor);
    if (CGRectIntersectsRect(rect, titleFrame))
    {
        [_title drawInRect:titleFrame withFont:_titleFont lineBreakMode:NSLineBreakByTruncatingTail];
    }
    
    if (_showTyping)
    {
        if (!_highlighted)
            CGContextSetFillColorWithColor(context, actionTextColor.CGColor);
        [_typingText drawInRect:typingFrame withFont:_textFont lineBreakMode:NSLineBreakByClipping];
    }
    else
    {
        if (CGRectIntersectsRect(rect, textFrame))
        {
            if (!_highlighted)
                CGContextSetFillColorWithColor(context, _textColor.CGColor);
            [_text drawInRect:textFrame withFont:_textFont lineBreakMode:NSLineBreakByTruncatingTail];
            //CGContextFillRect(context, textFrame);
        }
    
        if (_authorName != nil && _authorName.length != 0)
        {
            if (!_highlighted)
                CGContextSetFillColorWithColor(context, authorNameColor);
            if (CGRectIntersectsRect(rect, authorNameFrame))
            {
                [_authorName drawInRect:authorNameFrame withFont:_authorNameFont lineBreakMode:NSLineBreakByTruncatingTail];
                //CGContextFillRect(context, authorNameFrame);
            }
        }
    }
    
    /*UIImage *currentArrowImage = nil;
    if (!_highlighted)
    {
        static UIImage *normalArrowImage = nil;
        if (normalArrowImage == nil)
            normalArrowImage = arrowImage();
        currentArrowImage = normalArrowImage;
    }
    else
    {
        static UIImage *highlightedArrowImage = nil;
        if (highlightedArrowImage == nil)
            highlightedArrowImage = arrowHighlightedImage();
        currentArrowImage = highlightedArrowImage;
    }
    
    [currentArrowImage drawAtPoint:CGPointMake(frame.size.width - 21, 27)];*/
}

@end

#pragma mark - Cell

@interface TGDialogListCell ()

@property (nonatomic, strong) TGDialogListTextView *textView;

@property (nonatomic, strong) TGRemoteImageView *avatarView;
@property (nonatomic, strong) UIImageView *authorAvatarStrokeView;

@property (nonatomic, strong) TGDateLabel *dateLabel;

@property (nonatomic, strong) UIImageView *unreadCountBackgrond;
@property (nonatomic, strong) TGLabel *unreadCountLabel;

@property (nonatomic, strong) UIImageView *deliveryErrorBackgrond;

@property (nonatomic, strong) UIImageView *deliveredCheckmark;
@property (nonatomic, strong) UIImageView *readCheckmark;
@property (nonatomic, strong) UIImageView *pendingIndicator;

@property (nonatomic, strong) NSString *dateString;

@property (nonatomic, strong) TGHighlightTriggerLabel *highlightTrigger;

@property (nonatomic) int validViews;
@property (nonatomic) CGSize validSize;

@property (nonatomic) bool hideAuthorName;

@property (nonatomic, strong) UIButton *switchButton;
@property (nonatomic, strong) UIImageView *editingButtonLabel;
@property (nonatomic, strong) UIImageView *switchButtonMinus;
@property (nonatomic) bool editingIsActive;

@property (nonatomic, strong) UIImageView *deleteShadowView;

@property (nonatomic, strong) UIColor *messageTextColor;

@property (nonatomic, strong) UIImageView *arrowView;

@property (nonatomic, strong) UIImageView *muteIcon;

@property (nonatomic, strong) UIView *typingDotsContainer;
@property (nonatomic) bool animatingTyping;
@property (nonatomic, strong) NSTimer *typingDotsTimer;
@property (nonatomic) int typingDotsAnimationStep;

@end

@implementation TGDialogListCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier assetsSource:(id<TGDialogListCellAssetsSource>)assetsSource
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self)
    {
        self.multipleTouchEnabled = false;
        self.exclusiveTouch = true;
        
        _assetsSource = assetsSource;

        _textView = [[TGDialogListTextView alloc] initWithFrame:CGRectMake(73, 2, self.contentView.frame.size.width - 73, 46)];
        _textView.contentMode = UIViewContentModeLeft;
        _textView.titleFont = [UIFont boldSystemFontOfSize:16];
        _textView.textFont = [UIFont systemFontOfSize:14];
        _textView.authorNameFont = [UIFont boldSystemFontOfSize:14];
        _textView.opaque = true;
        _textView.backgroundColor = [UIColor whiteColor];
        
        _highlightTrigger = [[TGHighlightTriggerLabel alloc] initWithFrame:CGRectZero];
        _highlightTrigger.targetViews = [NSArray arrayWithObject:_textView];
        _highlightTrigger.hidden = true;
        
        [self.contentView addSubview:_highlightTrigger];
        
        [self.contentView addSubview:_textView];
        
        _dateString = [[NSMutableString alloc] initWithCapacity:16];
        
        _dateLabel = [[TGDateLabel alloc] init];
        _dateLabel.amWidth = 19;
        _dateLabel.pmWidth = 19;
        _dateLabel.dstOffset = 2;
        _dateLabel.dateFont = [UIFont systemFontOfSize:13];
        _dateLabel.dateTextFont = [UIFont boldSystemFontOfSize:13];
        _dateLabel.dateLabelFont = [UIFont systemFontOfSize:11];
        _dateLabel.textColor = UIColorRGB(0x337acc);
        _dateLabel.backgroundColor = [UIColor whiteColor];
        _dateLabel.highlightedTextColor = [UIColor whiteColor];
        _dateLabel.opaque = true;
        _dateLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        
#if !TGTEST
        [self.contentView addSubview:_dateLabel];
#endif
        
        bool fadeTransition = cpuCoreCount() > 1;
        
        _avatarView = [[TGRemoteImageView alloc] initWithFrame:CGRectMake(8, 8, 56, 56)];
        _avatarView.fadeTransition = fadeTransition;
        [self.contentView addSubview:_avatarView];
        
        _unreadCountBackgrond = [[UIImageView alloc] initWithImage:[_assetsSource dialogListUnreadCountBadge] highlightedImage:[_assetsSource dialogListUnreadCountBadgeHighlighted]];
        
#if !TGTEST
        [self.contentView addSubview:_unreadCountBackgrond];
#endif
        
        _unreadCountLabel = [[TGLabel alloc] initWithFrame:CGRectMake(0, 0, 50, 20)];
        _unreadCountLabel.textColor = [UIColor whiteColor];
        _unreadCountLabel.normalShadowColor = UIColorRGB(0x8091a6);
        _unreadCountLabel.shadowColor = _unreadCountLabel.normalShadowColor;
        _unreadCountLabel.shadowOffset = CGSizeMake(0, -1);
        _unreadCountLabel.highlightedShadowColor = [UIColor clearColor];
        _unreadCountLabel.highlightedTextColor = UIColorRGB(0x2371c2);
        _unreadCountLabel.font = [UIFont boldSystemFontOfSize:14];
        
#if !TGTEST
        [self.contentView addSubview:_unreadCountLabel];
#endif
        
        _unreadCountLabel.backgroundColor = [UIColor clearColor];
        
        _arrowView = [[UIImageView alloc] initWithImage:arrowImage() highlightedImage:arrowHighlightedImage()];
        _arrowView.frame = CGRectOffset(_arrowView.frame, self.frame.size.width - _arrowView.frame.size.width - 6, 33);
        _arrowView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        
#if !TGTEST
        [self addSubview:_arrowView];
#endif
        
        TGSwipeGestureRecognizer *swipeRecognizer = [[TGSwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeGestureRecognized:)];
        [self addGestureRecognizer:swipeRecognizer];
        
        static UIImage *switchButtonImage = nil;
        static UIImage *deleteTextImage = nil;
        
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^
        {
            switchButtonImage = [UIImage imageNamed:@"ListEditingSwitch.png"];
            
            UIFont *font = [UIFont boldSystemFontOfSize:13];
            CGSize size = [TGLocalized(@"Common.ListDelete") sizeWithFont:font];
            size.width = (int)size.width + 2;
            UIGraphicsBeginImageContextWithOptions(size, false, 0.0f);
            
            CGContextRef context = UIGraphicsGetCurrentContext();
            CGContextSetShadowWithColor(context, CGSizeMake(0, -1), 0.0f, UIColorRGBA(0xa30f0a, 0.2f).CGColor);
            CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
            
            [TGLocalized(@"Common.ListDelete") drawInRect:CGRectMake(1, 0, size.width, size.height) withFont:font];
            
            deleteTextImage = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
        });
        
        _switchButton = [[UIButton alloc] initWithFrame:CGRectMake(-30 - 5, (int)((73 - 30) / 2), 30, 30)];
        _switchButton.exclusiveTouch = true;
        _switchButton.adjustsImageWhenHighlighted = false;
        _switchButton.adjustsImageWhenDisabled = false;
        [_switchButton setBackgroundImage:switchButtonImage forState:UIControlStateNormal];
        [_switchButton addTarget:self action:@selector(switchButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        
        _switchButtonMinus = [[UIImageView alloc] initWithImage:normalMinusImage()];
        _switchButtonMinus.center = CGPointMake(15, 14);
        [_switchButton addSubview:_switchButtonMinus];
        
        _deleteShadowView = [[UIImageView alloc] initWithFrame:CGRectMake(self.frame.size.width, 1, 90, 71)];
        _deleteShadowView.image = deleteShadowImage();
        _deleteShadowView.alpha = 0.0f;
        _deleteShadowView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        
        _editingButton = [[UIButton alloc] init];
        _editingButton.exclusiveTouch = true;
        _editingButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        [_editingButton setBackgroundImage:deleteButtonImage() forState:UIControlStateNormal];
        [_editingButton setBackgroundImage:deleteButtonHighlightedImage() forState:UIControlStateHighlighted];
        
        [_editingButton addTarget:self action:@selector(deleteButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        
        _editingButton.frame = CGRectMake(self.frame.size.width - 10 - 61, 20, 61, 31);
        _editingButton.alpha = 0.0f;
        
        UIImageView *deleteTextView = [[UIImageView alloc] initWithImage:deleteTextImage];
        deleteTextView.frame = CGRectOffset(deleteTextView.frame, floorf((_editingButton.frame.size.width - deleteTextView.frame.size.width) / 2), 7);
        deleteTextView.contentMode = UIViewContentModeLeft;
        deleteTextView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        _editingButtonLabel = deleteTextView;
        [_editingButton addSubview:deleteTextView];
        
        _editingButton.frame = CGRectMake(self.frame.size.width - edgeDistance - 2, _editingButton.frame.origin.y, 2, _editingButton.frame.size.height);
        
        _deliveredCheckmark = [[UIImageView alloc] initWithImage:deliveredCheckmark() highlightedImage:deliveredCheckmarkHighlighted()];
        
        _readCheckmark = [[UIImageView alloc] initWithImage:readCheckmark() highlightedImage:readCheckmarkHighlighted()];
        
#if !TGTEST
        [self.contentView addSubview:_readCheckmark];
        [self.contentView addSubview:_deliveredCheckmark];
#endif
        
        _validSize = CGSizeZero;
    }
    return self;
}

- (void)dealloc
{
    [_avatarView cancelLoading];
    
    ((TGHighlightImageView *)self.selectedBackgroundView).targetView = nil;
    _highlightTrigger.targetViews = nil;
    
    if (_typingDotsTimer != nil)
    {
        [_typingDotsTimer invalidate];
        _typingDotsTimer = nil;
    }
}

- (void)prepareForReuse
{
    [self stopTypingAnimation];
    
    [super prepareForReuse];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    bool wasSelected = self.selected;
    
    [super setSelected:selected animated:animated];
    
    if ((selected && !wasSelected))
    {
        [self adjustOrdering];
    }
    
    if ((selected && !wasSelected) || (!selected && wasSelected))
    {
        UIView *selectedView = self.selectedBackgroundView;
        if (selectedView != nil && (self.selected || self.highlighted))
            selectedView.frame = CGRectMake(0, -1, selectedView.frame.size.width, selectedView.frame.size.height + 1);
    }
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
    bool wasHighlighted = self.highlighted;
    
    [super setHighlighted:highlighted animated:animated];
    
    if ((highlighted && !wasHighlighted))
    {
        [self adjustOrdering];
    }
    
    if ((highlighted && !wasHighlighted) && (!highlighted && wasHighlighted))
    {
        UIView *selectedView = self.selectedBackgroundView;
        if (selectedView != nil && (self.selected || self.highlighted))
            selectedView.frame = CGRectMake(0, -1, selectedView.frame.size.width, selectedView.frame.size.height + 1);
    }
}

- (void)adjustOrdering
{
    UIView *selectedView = self.selectedBackgroundView;
    if (selectedView != nil)
    {
        selectedView.frame = CGRectMake(0, -1, selectedView.frame.size.width, selectedView.frame.size.height + 1);
    }
    
    if ([self.superview isKindOfClass:[UITableView class]])
    {
        Class UITableViewCellClass = [UITableViewCell class];
        Class UISearchBarClass = [UISearchBar class];
        int maxCellIndex = 0;
        int index = -1;
        int selfIndex = 0;
        for (UIView *view in self.superview.subviews)
        {
            index++;
            if ([view isKindOfClass:UITableViewCellClass] || [view isKindOfClass:UISearchBarClass])
            {
                maxCellIndex = index;
                
                if (view == self)
                    selfIndex = index;
            }
        }
        
        if (selfIndex < maxCellIndex)
        {
            [self.superview insertSubview:self atIndex:maxCellIndex];
        }
    }
}

- (void)setTypingString:(NSString *)typingString
{
    [self setTypingString:typingString animated:false];
}

- (void)setTypingString:(NSString *)typingString animated:(bool)__unused animated
{
    _typingString = typingString;
    
    if (((_textView.typingText == nil) != (typingString == nil)) || (typingString != nil) != _textView.showTyping || ![_textView.typingText isEqualToString:typingString])
    {
        //typingString = @"Someone With The Largest Name is typing";
        
        _textView.showTyping = typingString != nil;
        _textView.typingText = typingString;
        
        if (typingString != nil)
            [self startTypingAnimation:false];
        else
            [self stopTypingAnimation];
        
        [_textView setNeedsDisplay];
        _validSize = CGSizeZero;
        [self setNeedsLayout];
    }
    
    /*if (!(typingString == nil && _typingIcon == nil))
    {
        self.typingIcon.hidden = typingString == nil;
    }*/
}

- (void)collectCachedPhotos:(NSMutableDictionary *)dict
{
    [_avatarView tryFillCache:dict];
}

- (UIView *)typingDotsContainer
{
    if (_typingDotsContainer == nil)
    {
        _typingDotsContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
        
        for (int i = 0; i < 3; i++)
        {
            UILabel *typingDot = [[UILabel alloc] init];
            typingDot.tag = 100 + i;
            typingDot.text = @".";
            typingDot.textColor = actionTextColor;
            typingDot.font = _textView.textFont;
            typingDot.backgroundColor = [UIColor clearColor];
            typingDot.frame = CGRectMake(4 * i, 0, 4, 10);
            typingDot.alpha = i == 0 ? 0.0f : 0.0f;
            
            [_typingDotsContainer addSubview:typingDot];
        }
    }
    
    return _typingDotsContainer;
}

- (void)restartAnimations:(bool)force
{
    if (_animatingTyping)
    {
        _animatingTyping = false;
        
        if (_typingDotsTimer != nil)
        {
            [_typingDotsTimer invalidate];
            _typingDotsTimer = nil;
        }
    }
    
    if (_textView.showTyping)
        [self startTypingAnimation:force];
}

- (void)stopAnimations
{
    [self stopTypingAnimation];
}

- (void)startTypingAnimation:(bool)force
{
    if (!_animatingTyping)
    {
        UIView *typingDotsContainer = [self typingDotsContainer];
        
        _animatingTyping = true;
        
        if (typingDotsContainer.superview != self.contentView)
        {
            [self.contentView addSubview:typingDotsContainer];
            _validSize = CGSizeZero;
            [self layoutSubviews];
        }
        
        if (self.window != nil)
        {
            UIApplicationState state = [UIApplication sharedApplication].applicationState;
            if (state == UIApplicationStateActive || state == UIApplicationStateInactive || force)
                [self _loopTypingAnimation:nil];
        }
    }
}

- (void)stopTypingAnimation
{
    if (_animatingTyping)
    {
        _animatingTyping = false;
        
        if (_typingDotsTimer != nil)
        {
            [_typingDotsTimer invalidate];
            _typingDotsTimer = nil;
        }
        
        [_typingDotsContainer removeFromSuperview];
    }
}

- (void)_loopTypingAnimation:(NSTimer *)timer
{
    if (timer != _typingDotsTimer)
        return;
    
    if (_typingDotsTimer != nil)
    {
        [_typingDotsTimer invalidate];
        _typingDotsTimer = nil;
    }
    
    _typingDotsAnimationStep = 0;
    [self _typingAnimationStep:nil];
}

- (void)_typingAnimationStep:(NSTimer *)timer
{
    if (timer != _typingDotsTimer)
        return;
    
    if (_typingDotsTimer != nil)
    {
        [_typingDotsTimer invalidate];
        _typingDotsTimer = nil;
    }
    
    _typingDotsAnimationStep++;
    
    for (UIView *dotView in _typingDotsContainer.subviews)
    {
        if (dotView.tag >= 100)
        {
            int dotIndex = dotView.tag - 100;
            dotView.alpha = dotIndex < (_typingDotsAnimationStep - 1) ? 1.0f : 0.0f;
        }
    }
    
    if (_typingDotsAnimationStep > 3)
    {
        _typingDotsTimer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:0.22] interval:0.22 target:self selector:@selector(_loopTypingAnimation:) userInfo:nil repeats:false];
        [[NSRunLoop mainRunLoop] addTimer:_typingDotsTimer forMode:NSRunLoopCommonModes];
    }
    else
    {   
        _typingDotsTimer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:_typingDotsAnimationStep == 1 ? 0.22 : 0.12] interval:0.12 target:self selector:@selector(_typingAnimationStep:) userInfo:nil repeats:false];
        [[NSRunLoop mainRunLoop] addTimer:_typingDotsTimer forMode:NSRunLoopCommonModes];
    }
}

- (void)resetView:(bool)keepState
{
    if (self.selectionStyle != UITableViewCellSelectionStyleBlue)
        self.selectionStyle = UITableViewCellSelectionStyleBlue;
    
    _dateString = _date == 0 ? nil : [TGDateUtils stringForMessageListDate:(int)_date];
    
    _textView.title = _titleText;
    
    if (normalTextColor == nil)
    {
        normalTextColor = UIColorRGB(0x888888);
        actionTextColor = UIColorRGB(0x536c8c);
        mediaTextColor = UIColorRGB(0x536c8c);
    }
    
    bool attachmentFound = false;
    _hideAuthorName = !_isGroupChat;
    
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
                        _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.RenamedChat"), user.displayName];
                        _messageTextColor = actionTextColor;
                        attachmentFound = true;
                        
                        _hideAuthorName = true;
                        
                        break;
                    }
                    case TGMessageActionChatEditPhoto:
                    {
                        TGUser *user = [_users objectForKey:@"author"];
                        if ([(TGImageMediaAttachment *)[actionAttachment.actionData objectForKey:@"photo"] imageInfo] == nil)
                            _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.RemovedGroupPhoto"), user.displayName];
                        else
                            _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.ChangedGroupPhoto"), user.displayName];
                        _messageTextColor = actionTextColor;
                        attachmentFound = true;
                        
                        _hideAuthorName = true;
                        
                        break;
                    }
                    case TGMessageActionUserChangedPhoto:
                    {
                        TGUser *user = [_users objectForKey:@"author"];
                        if ([(TGImageMediaAttachment *)[actionAttachment.actionData objectForKey:@"photo"] imageInfo] == nil)
                            _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.RemovedUserPhoto"), user.displayFirstName];
                        else
                            _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.ChangedUserPhoto"), user.displayFirstName];
                        _messageTextColor = actionTextColor;
                        attachmentFound = true;
                        
                        _hideAuthorName = true;
                        
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
                                _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.JoinedChat"), authorUser.displayName];
                            else
                                _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.Invited"), authorUser.displayName, subjectUser.displayName];
                            _messageTextColor = actionTextColor;
                            attachmentFound = true;
                            
                            _hideAuthorName = true;
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
                                _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.LeftChat"), authorUser.displayName];
                            else
                                _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.Kicked"), authorUser.displayName, subjectUser.displayName];
                            _messageTextColor = actionTextColor;
                            attachmentFound = true;
                            
                            _hideAuthorName = true;
                        }
                        
                        break;
                    }
                    case TGMessageActionCreateChat:
                    {
                        TGUser *user = [_users objectForKey:@"author"];
                        _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.CreatedChat"), user.displayName];
                        _messageTextColor = actionTextColor;
                        attachmentFound = true;
                        
                        _hideAuthorName = true;
                        
                        break;
                    }
                    case TGMessageActionContactRequest:
                    {
                        _messageText = [[NSString alloc] initWithFormat:@"%@ sent contact request", _authorName];
                        _messageTextColor = actionTextColor;
                        attachmentFound = true;
                        
                        _hideAuthorName = true;
                        
                        break;
                    }
                    case TGMessageActionAcceptContactRequest:
                    {
                        _messageText = [[NSString alloc] initWithFormat:@"%@ accepted contact request", _authorName];
                        _messageTextColor = actionTextColor;
                        attachmentFound = true;
                        
                        _hideAuthorName = true;
                        
                        break;
                    }
                    case TGMessageActionContactRegistered:
                    {
                        _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.Joined"), _authorName];
                        _messageTextColor = actionTextColor;
                        attachmentFound = true;
                        
                        _hideAuthorName = true;
                        
                        break;
                    }
                    case TGMessageActionEncryptedChatRequest:
                    {
                        _messageText = TGLocalized(@"Notification.EncryptedChatRequested");
                        _messageTextColor = actionTextColor;
                        attachmentFound = true;
                        
                        break;
                    }
                    case TGMessageActionEncryptedChatAccept:
                    {
                        _messageText = TGLocalized(@"Notification.EncryptedChatAccepted");
                        _messageTextColor = actionTextColor;
                        attachmentFound = true;
                        
                        break;
                    }
                    case TGMessageActionEncryptedChatDecline:
                    {
                        _messageText = TGLocalized(@"Notification.EncryptedChatRejected");
                        _messageTextColor = actionTextColor;
                        attachmentFound = true;
                        
                        break;
                    }
                    case TGMessageActionEncryptedChatMessageLifetime:
                    {
                        int messageLifetime = [actionAttachment.actionData[@"messageLifetime"] intValue];
                        
                        _messageTextColor = actionTextColor;
                        attachmentFound = true;
                        
                        if (messageLifetime == 0)
                        {
                            _messageText = [[NSString alloc] initWithFormat:TGLocalizedStatic(@"Notification.MessageLifetimeRemoved"), _encryptionFirstName];
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
                            
                            if (_outgoing)
                                _messageText = [[NSString alloc] initWithFormat:TGLocalizedStatic(@"Notification.MessageLifetimeChangedOutgoing"), lifetimeString];
                            else
                                _messageText = [[NSString alloc] initWithFormat:TGLocalizedStatic(@"Notification.MessageLifetimeChanged"), _encryptionFirstName, lifetimeString];
                        }
                        
                        break;
                    }
                    default:
                        break;
                }
            }
            else if (attachment.type == TGImageMediaAttachmentType)
            {
                _messageText = TGLocalized(@"Message.Photo");
                _messageTextColor = mediaTextColor;
                attachmentFound = true;
                break;
            }
            else if (attachment.type == TGVideoMediaAttachmentType)
            {
                _messageText = TGLocalized(@"Message.Video");
                _messageTextColor = mediaTextColor;
                attachmentFound = true;
                break;
            }
            else if (attachment.type == TGLocationMediaAttachmentType)
            {
                _messageText = TGLocalized(@"Message.Location");
                _messageTextColor = mediaTextColor;
                attachmentFound = true;
                break;
            }
            else if (attachment.type == TGContactMediaAttachmentType)
            {
                _messageText = TGLocalized(@"Message.Contact");
                _messageTextColor = mediaTextColor;
                attachmentFound = true;
                break;
            }
        }
    }
    
    if (!attachmentFound)
    {
        _messageTextColor = normalTextColor;
    }
    
    if (_messageText.length == 0)
    {
        _messageTextColor = actionTextColor;
        if (_isEncrypted)
        {
            if (_encryptionStatus == 1)
                _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"DialogList.AwaitingEncryption"), _encryptionFirstName];
            else if (_encryptionStatus == 2)
                _messageText = TGLocalized(@"DialogList.EncryptionProcessing");
            else if (_encryptionStatus == 3)
                _messageText = TGLocalized(@"DialogList.EncryptionRejected");
            else if (_encryptionStatus == 4)
            {
                if (_encryptionOutgoing)
                    _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"DialogList.EncryptedChatStartedOutgoing"), _encryptionFirstName];
                else
                    _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"DialogList.EncryptedChatStartedIncoming"), _encryptionFirstName];
            }
        }
    }
    
    _textView.text = _messageText;
    _textView.textColor = _messageTextColor;
    
    if (_unreadCount != 0 || _serviceUnreadCount != 0)
    {
        _unreadCountBackgrond.hidden = false;
        _unreadCountLabel.hidden = false;
        
        int totalCount = _unreadCount + _serviceUnreadCount;
        
        if (totalCount < 1000)
            _unreadCountLabel.text = [[NSString alloc] initWithFormat:@"%d", totalCount];
        else
            _unreadCountLabel.text = [[NSString alloc] initWithFormat:@"%dK", totalCount / 1000];
    }
    else
    {
        _unreadCountBackgrond.hidden = true;
        _unreadCountLabel.hidden = true;
    }
    
    if (_deliveryState == TGMessageDeliveryStateFailed)
    {
        _unreadCountBackgrond.hidden = true;
        _unreadCountLabel.hidden = true;
        
        if (_deliveryErrorBackgrond == nil)
        {
            _deliveryErrorBackgrond = [[UIImageView alloc] initWithImage:[_assetsSource dialogListDeliveryErrorBadge] highlightedImage:[_assetsSource dialogListDeliveryErrorBadgeHighlighted]];
            [self.contentView addSubview:_deliveryErrorBackgrond];
        }
        else if (_deliveryErrorBackgrond.superview != self.contentView)
            [self.contentView addSubview:_deliveryErrorBackgrond];
        
        _deliveryErrorBackgrond.highlighted = _textView.highlighted;
    }
    else if (_deliveryErrorBackgrond != nil && _deliveryErrorBackgrond.superview == self.contentView)
    {
        [_deliveryErrorBackgrond removeFromSuperview];
    }
    
    static UIColor *normalBackground = nil;
    static UIColor *unreadBackground = nil;
    static UIColor *normalMessage = nil;
    static UIColor *unreadMessage = nil;
    if (normalBackground == nil)
    {
        normalBackground = [UIColor whiteColor];
        unreadBackground = UIColorRGB(0xebf0f5);
        normalMessage = UIColorRGB(0x888888);
        unreadMessage = UIColorRGB(0x5b646e);
    }
    
    _textView.authorName = _hideAuthorName ? nil : _authorName;
        
    _avatarView.hidden = false;
    
    if (_avatarUrl != nil)
    {
        _avatarView.fadeTransitionDuration = keepState ? 0.3 : 0.14;
        
        if (![_avatarView.currentUrl isEqualToString:_avatarUrl])
        {
            if (keepState)
            {
                [_avatarView loadImage:_avatarUrl filter:@"avatar56" placeholder:(_avatarView.currentImage != nil ? _avatarView.currentImage : (_isGroupChat ? [_assetsSource groupAvatarPlaceholderGeneric] : [_assetsSource avatarPlaceholderGeneric])) forceFade:true];
            }
            else
            {
                [_avatarView loadImage:_avatarUrl filter:@"avatar56" placeholder:(_isGroupChat ? [_assetsSource groupAvatarPlaceholderGeneric] : [_assetsSource avatarPlaceholderGeneric]) forceFade:false];
            }
        }
    }
    else
    {
        _avatarView.fadeTransitionDuration = 0.14;
        
        [_avatarView loadImage:[[NSString alloc] initWithFormat:@"dialogListPlaceholder:%lld", _isEncrypted ? _encryptedUserId : _conversationId] filter:nil placeholder:[_assetsSource groupAvatarPlaceholderGeneric] forceFade:false];
    }
    
    ((TGHighlightImageView *)self.selectedBackgroundView).targetView = nil;
    
    _textView.isMultichat = _isGroupChat;
    _textView.isEncrypted = _isEncrypted;
    
    _dateLabel.dateText = _dateString;
    
    _validSize = CGSizeZero;
    
    [_textView setNeedsDisplay];
    
    if (_editingIsActive)
    {
        _editingIsActive = false;
        _switchButtonMinus.transform = CGAffineTransformIdentity;
        _switchButtonMinus.center = CGPointMake(15, 14);
        _switchButtonMinus.image = normalMinusImage();
    }
    
    if (_editingButton.alpha > FLT_EPSILON)
    {
        _editingButton.alpha = 0.0f;
        [_editingButton removeFromSuperview];
        
        _dateLabel.alpha = 1.0f;
        _deliveredCheckmark.alpha = 1.0f;
        _readCheckmark.alpha = 1.0f;
        
        [_deleteShadowView removeFromSuperview];
        _deleteShadowView.alpha = 0.0f;
        CGRect shadowFrame = _deleteShadowView.frame;
        shadowFrame.origin.x = self.frame.size.width;
        _deleteShadowView.frame = shadowFrame;
    }
    
    if (_outgoing)
    {
        if (_deliveryState == TGMessageDeliveryStateDelivered && !_unread)
        {
            _deliveredCheckmark.hidden = true;
            _readCheckmark.hidden = false;
        }
        else if (_deliveryState == TGMessageDeliveryStateDelivered && _unread)
        {
            _deliveredCheckmark.hidden = false;
            _readCheckmark.hidden = true;
        }
        else
        {
            _deliveredCheckmark.hidden = true;
            _readCheckmark.hidden = true;
        }
        
        if (_deliveryState == TGMessageDeliveryStatePending)
        {
            if (_pendingIndicator == nil)
            {
                static UIImage *pendingImage = nil;
                static UIImage *pendingHighlightedImage = nil;
                if (pendingImage == nil)
                {
                    pendingImage = [UIImage imageNamed:@"DialogListPending.png"];
                    pendingHighlightedImage = [UIImage imageNamed:@"DialogListPending_Highlighted.png"];
                }
                
                _pendingIndicator = [[UIImageView alloc] initWithImage:pendingImage highlightedImage:pendingHighlightedImage];
                [self.contentView addSubview:_pendingIndicator];
            }
            
            _pendingIndicator.hidden = false;
        }
        else
        {
            _pendingIndicator.hidden = true;
        }
    }
    else
    {
        _deliveredCheckmark.hidden = true;
        _readCheckmark.hidden = true;
        
        _pendingIndicator.hidden = true;
    }
    
    if (_isMuted)
    {
        if (_muteIcon == nil)
        {
            _muteIcon = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"DialogList_Muted.png"] highlightedImage:[UIImage imageNamed:@"DialogList_Muted_Highlighted.png"]];
        }
        
        if (_muteIcon.superview == nil)
            [self.contentView addSubview:_muteIcon];
    }
    else if (_muteIcon != nil)
    {
        [_muteIcon removeFromSuperview];
    }
    
    [self setNeedsLayout];
}

- (void)dismissEditingControls:(bool)animated
{
    if (animated)
    {
        [self animateDeleteButton:false];
        
        if (_editingIsActive)
        {
            [self switchButtonPressed];
        }
    }
    else
    {
        if (_editingButton.alpha > FLT_EPSILON)
        {
            _editingButton.alpha = 0.0f;
            [_editingButton removeFromSuperview];
        }
        
        if (_editingIsActive)
        {
            _editingIsActive = false;
            _switchButtonMinus.transform = CGAffineTransformIdentity;
            _switchButtonMinus.center = CGPointMake(15, 14);
            _switchButtonMinus.image = normalMinusImage();
        }
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    UIView *selectedView = self.selectedBackgroundView;
    if (selectedView != nil)
        selectedView.frame = CGRectMake(0, -1, selectedView.frame.size.width, selectedView.frame.size.height + 1);
    
    CGSize size = self.frame.size;
    bool editing = self.editing;
    
    if (!CGSizeEqualToSize(_validSize, size))
    {
        if (_textView != nil)
        {
            if (!CGSizeEqualToSize(_textView.frame.size, CGRectMake(73, 6, size.width - 73, 58).size))
            {
                _textView.frame = CGRectMake(73, 6, size.width - 73, 58);
                [_textView setNeedsDisplay];
            }
        }
        
        float retinaPixel = TGIsRetina() ? 0.5f : 0.0f;
        int rightPadding = 16;
        
        int countTextWidth = (int)([_unreadCountLabel.text sizeWithFont:_unreadCountLabel.font].width);
        
        float backgroundWidth = MAX(27, countTextWidth + 10);
        CGRect unreadCountBackgroundFrame = CGRectMake(size.width - 28 - backgroundWidth, 29, backgroundWidth, 21);
        _unreadCountBackgrond.frame = unreadCountBackgroundFrame;
        CGRect unreadCountLabelFrame = _unreadCountLabel.frame;
        unreadCountLabelFrame.origin = CGPointMake(unreadCountBackgroundFrame.origin.x + (float)((unreadCountBackgroundFrame.size.width - countTextWidth) / 2) - (TGIsRetina() ? 0.0f : 0.0f), unreadCountBackgroundFrame.origin.y);
        _unreadCountLabel.frame = unreadCountLabelFrame;
        
        if (!_unreadCountBackgrond.hidden)
            rightPadding += unreadCountBackgroundFrame.size.width + 7;
        
        if (_deliveryErrorBackgrond != nil && _deliveryErrorBackgrond.superview != nil)
        {
            rightPadding += 26 + 7;
            _deliveryErrorBackgrond.frame = CGRectMake(size.width - 28 - 26, 29, 26, 20);
        }
        
        float messageTextOffset = 0;
        
        int titleY = 6;
        float dateY = 9;
        
        CGSize dateTextSize = [_dateLabel measureTextSize];
        
        int dateWidth = _date == 0 ? 0 : (int)(dateTextSize.width);
        CGRect dateFrame = CGRectMake((editing ? -32 : 0) + size.width - dateWidth - 9, dateY, 75, 15);
        _dateLabel.frame = dateFrame;
        float titleLabelWidth = (int)(dateFrame.origin.x - 4 - 73 - 18);
        int groupChatIconWidth = 0;
        if (_isEncrypted)
        {
            groupChatIconWidth = 15;
            titleLabelWidth -= groupChatIconWidth;
        }
        else if (_isGroupChat)
        {
            groupChatIconWidth = 21;
            titleLabelWidth -= groupChatIconWidth;
        }
        
        if (_isMuted)
            titleLabelWidth -= 12;
        
        titleLabelWidth = MIN(titleLabelWidth, [_titleText sizeWithFont:_textView.titleFont].width);
        
        _deliveredCheckmark.frame = CGRectMake(dateFrame.origin.x - 15, 11 + retinaPixel, 13, 11);
        _readCheckmark.frame = CGRectMake(dateFrame.origin.x - 20, 11 + retinaPixel, 18, 11);
        
        if (_pendingIndicator != nil)
            _pendingIndicator.frame = CGRectMake(dateFrame.origin.x - 16, 11, 12, 12);
        
        CGRect titleRect = CGRectMake(73 + groupChatIconWidth, titleY, titleLabelWidth, 20);
        
        CGRect messageRect = CGRectMake(73 + messageTextOffset, 29, size.width - 73 - 10, 40);
        messageRect.size.width = size.width - 73 - 10 - rightPadding - messageTextOffset;
        
        CGRect typingRect = messageRect;
        typingRect.size.height = 10;
        typingRect.size.width -= 10;
        _textView.typingFrame = typingRect;
        
        if (_typingDotsContainer.superview != nil)
        {
            CGSize typingSize = [_textView.typingText sizeWithFont:_textView.textFont constrainedToSize:typingRect.size lineBreakMode:NSLineBreakByTruncatingTail];
            
            CGRect typingDotsFrame = _typingDotsContainer.frame;
            typingDotsFrame.origin.x = typingRect.origin.x + typingSize.width;
            typingDotsFrame.origin.y = typingRect.origin.y + 4;
            _typingDotsContainer.frame = typingDotsFrame;
        }
        
        if (_authorName != nil && !_hideAuthorName)
        {
            _textView.authorNameFrame = CGRectMake(73, 29, size.width - 73 - 10 - rightPadding, 20);
            
            messageRect.origin.y += 9;
            messageRect.size.height -= 12;
        }
        
        titleRect.size.width = titleLabelWidth;
        
        if (_authorName != nil && !_hideAuthorName && [_messageText sizeWithFont:_textView.textFont constrainedToSize:messageRect.size].height < 20)
            messageRect.origin.y += 9;
        
        if (_isMuted)
        {
            CGRect muteRect = _muteIcon.frame;
            muteRect.origin = CGPointMake(titleRect.origin.x + titleRect.size.width + 3, titleRect.origin.y + 6);
            _muteIcon.frame = muteRect;
        }
        
        _textView.titleFrame = titleRect;
        _textView.textFrame = messageRect;
    
        _validSize = size;
    }
}

#pragma mark -

- (void)setEditing:(BOOL)editing animated:(BOOL)animated
{
    [super setEditing:editing animated:animated];
    
    if (animated)
    {
        if (editing)
        {
            if (_switchButton.superview == nil)
                [self addSubview:_switchButton];
            
            [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^
            {
                _switchButton.alpha = editing ? 1.0f : 0.0f;
                CGRect frame = _switchButton.frame;
                frame.origin.x = editing ? 4 : (-30 - 5);
                _switchButton.frame = frame;
                
                _validSize = CGSizeZero;
                [self layoutSubviews];
                [_textView setNeedsDisplay];
                
                CGRect arrowFrame = _arrowView.frame;
                arrowFrame.origin.x = self.frame.size.width - arrowFrame.size.width - 12 + (editing ? arrowFrame.size.width + 12 + 32 : 0);
                _arrowView.frame = arrowFrame;
                
                _unreadCountLabel.alpha = 0.0f;
                _unreadCountBackgrond.alpha = 0.0f;
            } completion:nil];
        }
        else
        {
            [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^
            {
                _switchButton.alpha = editing ? 1.0f : 0.0f;
                CGRect frame = _switchButton.frame;
                frame.origin.x = editing ? 4 : (-30 - 5);
                _switchButton.frame = frame;
                
                _validSize = CGSizeZero;
                [self layoutSubviews];
                [_textView setNeedsDisplay];
                
                CGRect arrowFrame = _arrowView.frame;
                arrowFrame.origin.x = self.frame.size.width - arrowFrame.size.width - 12 + (editing ? arrowFrame.size.width + 12 + 32: 0);
                _arrowView.frame = arrowFrame;
                
                _unreadCountLabel.alpha = 1.0f;
                _unreadCountBackgrond.alpha = 1.0f;
            } completion:^(BOOL finished)
            {
                if (finished)
                {
                    [_switchButton removeFromSuperview];
                    
                    if (_editingIsActive)
                    {
                        _editingIsActive = false;
                        _switchButtonMinus.transform = CGAffineTransformIdentity;
                        _switchButtonMinus.center = CGPointMake(15, 14);
                        _switchButtonMinus.image = normalMinusImage();
                    }
                }
            }];
        }
    }
    else
    {
        if (editing)
        {
            if (_switchButton.superview == nil)
                [self addSubview:_switchButton];
        }
        else if (_switchButton.superview != nil)
            [_switchButton removeFromSuperview];
        
        _switchButton.alpha = editing ? 1.0f : 0.0f;
        CGRect frame = _switchButton.frame;
        frame.origin.x = editing ? 4 : (-30 - 5);
        _switchButton.frame = frame;
        
        if (_editingIsActive)
        {
            _editingIsActive = false;
            _switchButtonMinus.transform = CGAffineTransformIdentity;
            _switchButtonMinus.center = CGPointMake(15, 14);
            _switchButtonMinus.image = normalMinusImage();
        }
        
        CGRect arrowFrame = _arrowView.frame;
        arrowFrame.origin.x = self.frame.size.width - arrowFrame.size.width - 12 + (editing ? arrowFrame.size.width + 12 + 32 : 0);
        _arrowView.frame = arrowFrame;
        
        _unreadCountLabel.alpha = editing ? 0.0f : 1.0f;
        _unreadCountBackgrond.alpha = editing ? 0.0f : 1.0f;
    }
}

- (void)switchButtonPressed
{
    bool editingIsActive = _editingIsActive;
    _editingIsActive = !editingIsActive;
    
    [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^
    {
        if (editingIsActive)
        {
            _switchButtonMinus.image = normalMinusImage();
            _switchButtonMinus.transform = CGAffineTransformIdentity;
            _switchButtonMinus.center = CGPointMake(15, 14);
        }
        else
        {
            _switchButtonMinus.image = activeMinusImage();
            _switchButtonMinus.transform = CGAffineTransformMakeRotation((float)(-M_PI_2));
            _switchButtonMinus.center = CGPointMake(14.5f, 14.5f);
        }
    } completion:nil];
    
    if (editingIsActive)
    {
        [self animateDeleteButton:false];
    }
    else
    {
        [self animateDeleteButton:true];
    }
}

- (void)animateDeleteButton:(bool)show
{
    if (show && _editingButton.alpha < 1.0f - FLT_EPSILON)
    {
        if (_deleteShadowView.superview == nil)
            [self insertSubview:_deleteShadowView aboveSubview:_arrowView];
        if (_editingButton.superview == nil)
            [self insertSubview:_editingButton aboveSubview:_deleteShadowView];
        
        _editingButton.frame = CGRectMake(self.frame.size.width - edgeDistance - 2, _editingButton.frame.origin.y, 2, _editingButton.frame.size.height);
        _editingButtonLabel.alpha = 0.0f;
        
        [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^
        {
            _editingButton.alpha = 1.0f;
            _editingButton.frame = CGRectMake(self.frame.size.width - edgeDistance - 61, _editingButton.frame.origin.y, 61, _editingButton.frame.size.height);
            _editingButtonLabel.alpha = 1.0f;
            
            _dateLabel.alpha = 0.0f;
            _deliveredCheckmark.alpha = 0.0f;
            _readCheckmark.alpha = 0.0f;
            
            CGRect shadowFrame = _deleteShadowView.frame;
            shadowFrame.origin.x = self.frame.size.width - shadowFrame.size.width;
            _deleteShadowView.frame = shadowFrame;
            _deleteShadowView.alpha = 1.0f;
        } completion:nil];
        
        id<ASWatcher> watcher = _watcherHandle.delegate;
        if (watcher != nil && [watcher respondsToSelector:@selector(actionStageActionRequested:options:)])
        {
            [watcher actionStageActionRequested:@"setFocusCell" options:[NSDictionary dictionaryWithObject:self forKey:@"cell"]];
        }
    }
    else if (!show && _editingButton.alpha > FLT_EPSILON)
    {
        [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^
        {
            _editingButton.alpha = 0.0f;
            _editingButton.frame = CGRectMake(self.frame.size.width - edgeDistance - 2, _editingButton.frame.origin.y, 2, _editingButton.frame.size.height);
            _editingButtonLabel.alpha = 0.0f;
            
            _dateLabel.alpha = 1.0f;
            _deliveredCheckmark.alpha = 1.0f;
            _readCheckmark.alpha = 1.0f;
            
            CGRect shadowFrame = _deleteShadowView.frame;
            shadowFrame.origin.x = self.frame.size.width;
            _deleteShadowView.frame = shadowFrame;
            _deleteShadowView.alpha = 0.0f;
        } completion:^(BOOL finished)
        {
            if (finished)
            {
                [_editingButton removeFromSuperview];
                [_deleteShadowView removeFromSuperview];
                _deleteShadowView.alpha = 0.0f;
            }
        }];
    }
}

- (bool)showingDeleteConfirmationButton
{
    return _editingButton.alpha > FLT_EPSILON;
}

#pragma mark -

- (void)swipeGestureRecognized:(TGSwipeGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateRecognized && !self.editing)
    {
        if (!_enableEditing)
            return;
        
        [self setSelected:false];
        [self setHighlighted:false];
        
        [self animateDeleteButton:true];
    }
}

- (void)deleteButtonPressed
{
    [self animateDeleteButton:false];
    
    id<ASWatcher> watcher = _watcherHandle.delegate;
    if (watcher != nil && [watcher respondsToSelector:@selector(actionStageActionRequested:options:)])
    {
        [watcher actionStageActionRequested:@"conversationDeleteRequested" options:[NSDictionary dictionaryWithObject:[NSNumber numberWithLongLong:_conversationId] forKey:@"conversationId"]];
    }
}

@end
