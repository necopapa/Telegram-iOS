#import "TGConversationAсtionsPanel.h"

#import "TGImageUtils.h"

#import <QuartzCore/QuartzCore.h>

@class TGPanelActionButton;

@protocol TGPanelActionButtonDelegate <NSObject>

- (void)panelActionButtonHighlighted:(TGPanelActionButton *)button;

@end

@interface TGPanelActionButton : UIButton

@property (nonatomic) bool delayTitle;
@property (nonatomic, strong) NSString *delayedTitle;

@property (nonatomic, weak) id<TGPanelActionButtonDelegate> delegate;

@property (nonatomic, strong) UIImageView *highlightView;

@end

@implementation TGPanelActionButton

@synthesize delayTitle = _delayTitle;
@synthesize delayedTitle = _delayedTitle;

@synthesize delegate = _delegate;

@synthesize highlightView = _highlightView;

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];
    
    _highlightView.highlighted = highlighted || self.selected;
    
    __strong id delegate = _delegate;
    [delegate panelActionButtonHighlighted:self];
}

- (void)setSelected:(BOOL)selected
{
    [super setSelected:selected];
    
    _highlightView.highlighted = selected || self.highlighted;
    
    __strong id delegate = _delegate;
    [delegate panelActionButtonHighlighted:self];
}

- (void)setTitle:(NSString *)title forState:(UIControlState)state
{
    if (_delayTitle)
        _delayedTitle = title;
    else
        [super setTitle:title forState:state];
}

- (void)applyDelayedTitle
{
    _delayTitle = nil;
    
    if (_delayedTitle != nil)
    {
        [self setTitle:_delayedTitle forState:UIControlStateNormal];
        _delayedTitle = nil;
    }
}

@end

#pragma mark -

@interface TGConversationActionsPanel () <TGPanelActionButtonDelegate>

@property (nonatomic) TGConversationActionsPanelType type;

@property (nonatomic, strong) UIView *contentContainer;

@property (nonatomic, strong) TGPanelActionButton *actionButton;
@property (nonatomic, strong) UIImageView *firstSeparator;
@property (nonatomic, strong) TGPanelActionButton *editButton;
@property (nonatomic, strong) UIImageView *secondSeparator;
@property (nonatomic, strong) TGPanelActionButton *infoButton;

@end

@implementation TGConversationActionsPanel

@synthesize watcherHandle = _watcherHandle;

@synthesize isBeingShown = _isBeingShown;

@synthesize isCallingAllowed = _isCallingAllowed;
@synthesize isEditingAllowed = _isEditingAllowed;
@synthesize isMuted = _isMuted;
@synthesize isBlockAllowed = _isBlockAllowed;
@synthesize userIsBlocked = _userIsBlocked;

@synthesize type = _type;

@synthesize contentContainer = _contentContainer;

@synthesize actionButton = _actionButton;
@synthesize firstSeparator = _firstSeparator;
@synthesize editButton = _editButton;
@synthesize secondSeparator = _secondSeparator;
@synthesize infoButton = _infoButton;

- (id)initWithFrame:(CGRect)frame type:(TGConversationActionsPanelType)type
{
    self = [super initWithFrame:frame];
    if (self)
    {
        _type = type;
        
        _contentContainer = [[UIView alloc] initWithFrame:CGRectMake(floorf((frame.size.width - 320) / 2), -26, 320, 59)];
        _contentContainer.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        [self addSubview:_contentContainer];
        
        self.hidden = true;
        _contentContainer.alpha = 0.0f;
        _contentContainer.layer.anchorPoint = CGPointMake(0.5f, 0.0f);
        _contentContainer.transform = CGAffineTransformMakeScale(0.1f, 0.1f);
        
        _actionButton = [self createButton:0];
        [_actionButton setTitle:(_type == TGConversationActionsPanelTypeUser ? TGLocalized(@"Conversation.Call") : TGLocalized(@"Conversation.Mute")) forState:UIControlStateNormal];
        [_actionButton addTarget:self action:@selector(actionButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [_contentContainer addSubview:_actionButton];
        
        _firstSeparator = [[UIImageView alloc] init];
        [_contentContainer addSubview:_firstSeparator];

        _editButton = [self createButton:1];
        [_editButton setTitle:TGLocalized(@"Conversation.Edit") forState:UIControlStateNormal];
        [_editButton addTarget:self action:@selector(editButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [_contentContainer addSubview:_editButton];
        
        _secondSeparator = [[UIImageView alloc] init];
        [_contentContainer addSubview:_secondSeparator];
        
        _infoButton = [self createButton:2];
        [_infoButton setTitle:TGLocalized(@"Conversation.Info") forState:UIControlStateNormal];
        [_infoButton addTarget:self action:@selector(infoButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [_contentContainer addSubview:_infoButton];
        
        [self updateSeparators];
        
        _isCallingAllowed = true;
        _isEditingAllowed = true;
        _isBlockAllowed = false;
    }
    return self;
}

- (TGPanelActionButton *)createButton:(int)position
{
    static UIImage *buttonImageLeft = nil;
    static UIImage *buttonImageLeftHighlighted = nil;
    static UIImage *buttonImageCenter = nil;
    static UIImage *buttonImageCenterHighlighted = nil;
    static UIImage *buttonImageRight = nil;
    static UIImage *buttonImageRightHighlighted = nil;
    
    if (buttonImageLeft == nil)
    {
        UIImage *rawImage = nil;
        
        rawImage = [UIImage imageNamed:@"ActionMenuButtonLeft.png"];
        buttonImageLeft = [rawImage stretchableImageWithLeftCapWidth:(int)(rawImage.size.width - 6) topCapHeight:0];
        
        rawImage = [UIImage imageNamed:@"ActionMenuButtonLeft_Highlighted.png"];
        buttonImageLeftHighlighted = [rawImage stretchableImageWithLeftCapWidth:(int)(rawImage.size.width - 6) topCapHeight:0];
        
        rawImage = [UIImage imageNamed:@"ActionMenuButtonMiddle.png"];
        buttonImageCenter = rawImage;
        
        rawImage = [UIImage imageNamed:@"ActionMenuButtonMiddle_Highlighted.png"];
        buttonImageCenterHighlighted = rawImage;
        
        rawImage = [UIImage imageNamed:@"ActionMenuButtonRight.png"];
        buttonImageRight = [rawImage stretchableImageWithLeftCapWidth:6 topCapHeight:0];
        
        rawImage = [UIImage imageNamed:@"ActionMenuButtonRight_Highlighted.png"];
        buttonImageRightHighlighted = [rawImage stretchableImageWithLeftCapWidth:6 topCapHeight:0];
    }
    
    TGPanelActionButton *button = [[TGPanelActionButton alloc] init];
    button.delegate = self;
    button.exclusiveTouch = true;
    button.adjustsImageWhenDisabled = false;
    button.adjustsImageWhenHighlighted = false;
    if (position == 0)
    {
        [button setBackgroundImage:buttonImageLeft forState:UIControlStateNormal];
        [button setBackgroundImage:buttonImageLeftHighlighted forState:UIControlStateHighlighted];
        [button setBackgroundImage:buttonImageLeftHighlighted forState:UIControlStateSelected];
        [button setBackgroundImage:buttonImageLeftHighlighted forState:UIControlStateSelected | UIControlStateHighlighted];
    }
    else if (position == 1)
    {
        [button setBackgroundImage:buttonImageCenter forState:UIControlStateNormal];
        [button setBackgroundImage:buttonImageCenterHighlighted forState:UIControlStateHighlighted];
        [button setBackgroundImage:buttonImageCenterHighlighted forState:UIControlStateSelected];
        [button setBackgroundImage:buttonImageCenterHighlighted forState:UIControlStateSelected | UIControlStateHighlighted];
    }
    else if (position == 2)
    {
        [button setBackgroundImage:buttonImageRight forState:UIControlStateNormal];
        [button setBackgroundImage:buttonImageRightHighlighted forState:UIControlStateHighlighted];
        [button setBackgroundImage:buttonImageRightHighlighted forState:UIControlStateSelected];
        [button setBackgroundImage:buttonImageRightHighlighted forState:UIControlStateSelected | UIControlStateHighlighted];
    }
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [button setTitleColor:UIColorRGBA(0xffffff, 0.5f) forState:UIControlStateDisabled];
    [button setTitleShadowColor:UIColorRGBA(0x000000, 0.8f) forState:UIControlStateNormal];
    [button setTitleShadowColor:UIColorRGBA(0x186bcb, 0.6f) forState:UIControlStateHighlighted];
    [button setTitleShadowColor:UIColorRGBA(0x186bcb, 0.6f) forState:UIControlStateSelected];
    [button setTitleShadowColor:UIColorRGBA(0x186bcb, 0.6f) forState:UIControlStateHighlighted | UIControlStateSelected];
    button.titleLabel.shadowOffset = CGSizeMake(0, -1);
    button.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    
    float retinaPixel = TGIsRetina() ? 0.5f : 0.0f;
    [button setTitleEdgeInsets:UIEdgeInsetsMake(8 + retinaPixel, position == 0 ? 7 : 0, 0, position == 2 ? 12 : 0)];
    if (position == 2)
    {
        UIImageView *arrowView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"ActionMenuArrow.png"] highlightedImage:[UIImage imageNamed:@"ActionMenuArrow_Highlighted.png"]];
        arrowView.frame = CGRectOffset(arrowView.frame, button.frame.size.width - 33, 27 + retinaPixel);
        arrowView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        button.highlightView = arrowView;
        [button addSubview:arrowView];
    }
    
    return button;
}

- (void)show:(bool)animated
{
    if (_isBeingShown)
        return;
    
    _isBeingShown = true;
    
    self.hidden = false;
    
    _contentContainer.alpha = 1.0f;
    
    if (animated)
    {
        _contentContainer.layer.rasterizationScale = [[UIScreen mainScreen] scale];
        _contentContainer.layer.shouldRasterize = true;
        [UIView animateWithDuration:0.142 delay:0 options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState animations:^
        {
            _contentContainer.transform = CGAffineTransformMakeScale(1.05f, 1.05f);
        } completion:^(BOOL finished)
        {
            if(finished)
            {
                [UIView animateWithDuration:0.08 delay:0 options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState animations:^
                {
                    _contentContainer.transform = CGAffineTransformMakeScale(0.98f, 0.98f);
                } completion:^(BOOL finished)
                {
                    if (finished)
                    {
                        [UIView animateWithDuration:0.06 delay:0 options:UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionBeginFromCurrentState animations:^
                        {
                            _contentContainer.transform = CGAffineTransformIdentity;
                        } completion:^(BOOL finished)
                        {
                            if (finished)
                            {
                                _contentContainer.layer.shouldRasterize = false;
                            }
                        }];
                    }
                }];
            }
        }];
    }
    else
    {
        _contentContainer.transform = CGAffineTransformIdentity;
    }
    
    [_editButton applyDelayedTitle];
    [_infoButton applyDelayedTitle];
    [_actionButton applyDelayedTitle];
    
    _editButton.selected = false;
    _infoButton.selected = false;
    _actionButton.selected = false;
    [self updateSeparators];
}

- (void)hide:(bool)animated
{
    if (!_isBeingShown)
        return;
    
    _isBeingShown = false;
    
    if (animated)
    {
        [UIView animateWithDuration:0.2 animations:^
        {
            _contentContainer.alpha = 0.0f;
        } completion:^(BOOL finished)
        {
            if (finished)
            {
                self.hidden = true;
                _contentContainer.transform = CGAffineTransformMakeScale(0.1f, 0.1f);
            }
        }];
    }
    else
    {
        _contentContainer.alpha = 0.0f;
        _contentContainer.transform = CGAffineTransformMakeScale(0.1f, 0.1f);
        self.hidden = true;
    }
}

- (void)setIsCallingAllowed:(bool)isCallingAllowed
{
    if (_isCallingAllowed != isCallingAllowed)
    {
        _isCallingAllowed = isCallingAllowed;
        
        _actionButton.enabled = isCallingAllowed;
    }
}

- (void)setIsMuted:(bool)isMuted
{
    if (_isMuted != isMuted)
    {
        _isMuted = isMuted;
        
        [_actionButton setTitle:(isMuted ? TGLocalized(@"Conversation.Unmute") : TGLocalized(@"Conversation.Mute")) forState:UIControlStateNormal];
    }
}

- (void)setIsEditingAllowed:(bool)isEditingAllowed
{
    if (_isEditingAllowed != isEditingAllowed)
    {
        _isEditingAllowed = isEditingAllowed;
        
        _editButton.enabled = isEditingAllowed;
    }
}

- (void)setIsBlockAllowed:(bool)isBlockAllowed
{
    if (_isBlockAllowed != isBlockAllowed)
    {
        _isBlockAllowed = isBlockAllowed;
        [_infoButton setTitle:isBlockAllowed ? (_userIsBlocked ? TGLocalized(@"Conversation.Unblock") : TGLocalized(@"Conversation.Block")) : TGLocalized(@"Conversation.Info") forState:UIControlStateNormal];
        
        _infoButton.highlightView.hidden = isBlockAllowed;
        float retinaPixel = TGIsRetina() ? 0.5f : 0.0f;
        [_infoButton setTitleEdgeInsets:UIEdgeInsetsMake(8 + retinaPixel, isBlockAllowed ? 7 : 0, 0, isBlockAllowed ? 12 : 0)];
    }
}

- (void)setUserIsBlocked:(bool)userIsBlocked
{
    if (_userIsBlocked != userIsBlocked)
    {
        _userIsBlocked = userIsBlocked;
        [_infoButton setTitle:_isBlockAllowed ? (_userIsBlocked ? TGLocalized(@"Conversation.Unblock") : TGLocalized(@"Conversation.Block")) : TGLocalized(@"Conversation.Info") forState:UIControlStateNormal];
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    const float middleButtonWidth = 94;
    const float sideButtonWidth = 98;
    
    CGSize viewSize = CGSizeMake(320, 59);
    
    _editButton.frame = CGRectMake(floorf((viewSize.width - middleButtonWidth) / 2), 0, middleButtonWidth, 59);
    _actionButton.frame = CGRectMake(_editButton.frame.origin.x - sideButtonWidth - 4, 0, sideButtonWidth, 59);
    _infoButton.frame = CGRectMake(_editButton.frame.origin.x + _editButton.frame.size.width + 4, 0, sideButtonWidth, 59);
    
    _firstSeparator.frame = CGRectMake(_editButton.frame.origin.x - 4, 0, 4, 59);
    _secondSeparator.frame = CGRectMake(_editButton.frame.origin.x + _editButton.frame.size.width, 0, 4, 59);
}

#pragma mark -

- (void)backgroundTapped:(UITapGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateRecognized)
    {
        [self hide:true];
    }
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    UIView *result = [super hitTest:point withEvent:event];
    if (result == self)
    {
        [self hide:true];
        
        return nil;
    }
    
    return result;
}

- (void)updateSeparators
{
    if (_actionButton.highlighted || _actionButton.selected)
        _firstSeparator.image = [UIImage imageNamed:@"ActionMenuDivider_RightHighlighted.png"];
    else if (_editButton.highlighted || _editButton.selected)
        _firstSeparator.image = [UIImage imageNamed:@"ActionMenuDivider_LeftHighlighted.png"];
    else
        _firstSeparator.image = [UIImage imageNamed:@"ActionMenuDivider.png"];
    
    if (_editButton.highlighted || _editButton.selected)
        _secondSeparator.image = [UIImage imageNamed:@"ActionMenuDivider_RightHighlighted.png"];
    else if (_infoButton.highlighted || _infoButton.selected)
        _secondSeparator.image = [UIImage imageNamed:@"ActionMenuDivider_LeftHighlighted.png"];
    else
        _secondSeparator.image = [UIImage imageNamed:@"ActionMenuDivider.png"];
}

- (void)panelActionButtonHighlighted:(TGPanelActionButton *)__unused button
{
    [self updateSeparators];
}

- (void)actionButtonPressed
{
    [self hide:true];
    _actionButton.selected = true;
    _actionButton.delayTitle = true;
    
    if (_type == TGConversationActionsPanelTypeUser)
        [_watcherHandle requestAction:@"conversationAction" options:[NSDictionary dictionaryWithObject:@"call" forKey:@"action"]];
    else
        [_watcherHandle requestAction:@"conversationAction" options:[NSDictionary dictionaryWithObject:_isMuted ? @"unmute" : @"mute" forKey:@"action"]];
}

- (void)editButtonPressed
{
    [self hide:true];
    _editButton.selected = true;
    
    [_watcherHandle requestAction:@"conversationAction" options:[NSDictionary dictionaryWithObject:@"edit" forKey:@"action"]];
}

- (void)infoButtonPressed
{
    if (_isBlockAllowed)
        [self hide:true];
    _infoButton.selected = true;
    _infoButton.delayTitle = true;
    
    [_watcherHandle requestAction:@"conversationAction" options:[NSDictionary dictionaryWithObject:_isBlockAllowed ? (_userIsBlocked ? @"unblock" : @"block") : @"info" forKey:@"action"]];
}

@end
