#import "TGNavigationBar.h"

#import "TGToolbarButton.h"
#import "TGLabel.h"

#import "TGViewController.h"
#import "TGNavigationController.h"

#import <QuartzCore/QuartzCore.h>

static UIColor *globalDefaultPortraitBackground;
static UIColor *globalDefaultLandscapeBackground;

static UIImage *globalDefaultPortraitImage;
static UIImage *globalDefaultLandscapeImage;

static UIColor *globalBlackOpaquePortraitBackground;
static UIColor *globalBlackOpaqueLandscapeBackground;

@interface TGNavigationBar ()

@property (nonatomic, strong) UIView *statusBarBackgroundView;

@property (nonatomic, strong) UIView *backgroundContainer;
@property (nonatomic, strong) UIView *defaultView;
@property (nonatomic, strong) UIView *blackView;
@property (nonatomic, strong) UIView *opaqueView;

@property (nonatomic, strong) UIImageView *actionOverlayView;

@property (nonatomic, strong) UIImageView *shadowView;

@property (nonatomic, strong) NSMutableArray *currentNavigationItems;

@property (nonatomic) bool currentBackgroundsAreLandscape;

@property (nonatomic) bool hiddenState;

@end

@implementation TGNavigationBar

+ (void)setDefaultNavigationBarBackground:(UIImage *)portraitImage landscapeImage:(UIImage *)landscapeImage
{
    globalDefaultPortraitImage = portraitImage;
    globalDefaultLandscapeImage = landscapeImage;
    globalDefaultPortraitBackground = [UIColor colorWithPatternImage:portraitImage];
    globalDefaultLandscapeBackground = [UIColor colorWithPatternImage:landscapeImage];
}

+ (void)setBlackOpaqueNavigationBarBackground:(UIImage *)portraitImage landscapeImage:(UIImage *)landscapeImage
{
    globalBlackOpaquePortraitBackground = [UIColor colorWithPatternImage:portraitImage];
    globalBlackOpaqueLandscapeBackground = [UIColor colorWithPatternImage:landscapeImage];
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self != nil)
    {
        [self commonInit];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        [self commonInit];
    }
    return self;
}

- (void)commonInit
{
    [self setBarStyle:UIBarStyleDefault];
    
    _currentNavigationItems = [[NSMutableArray alloc] init];
    
    self.multipleTouchEnabled = false;
    self.exclusiveTouch = true;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        if ([UIImage instancesRespondToSelector:@selector(resizableImageWithCapInsets:)])
        {
            UIImage *rawPortrait = [UIImage imageNamed:@"Header_Corners.png"];
            UIImage *rawLandscape = [UIImage imageNamed:@"Header_Corners_Landscape.png"];
            [TGNavigationBar setDefaultNavigationBarBackground:[rawPortrait resizableImageWithCapInsets:UIEdgeInsetsMake(0, 8, 0, 8)] landscapeImage:[rawLandscape resizableImageWithCapInsets:UIEdgeInsetsMake(0, 8, 0, 8)]];
        }
        else
        {
            [TGNavigationBar setDefaultNavigationBarBackground:[UIImage imageNamed:@"Header.png"] landscapeImage:[UIImage imageNamed:@"Header_Landscape.png"]];
        }
        
        [TGNavigationBar setBlackOpaqueNavigationBarBackground:[UIImage imageNamed:@"HeaderBlackOpaque.png"] landscapeImage:[UIImage imageNamed:@"HeaderBlackOpaque_Landscape.png"]];
    });
    
    _defaultPortraitImage = globalDefaultPortraitImage;
    _defaultLandscapeImage = globalDefaultLandscapeImage;
    
    _backgroundContainer = [[UIView alloc] initWithFrame:self.bounds];
    _backgroundContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _backgroundContainer.userInteractionEnabled = false;
    
    _backgroundContainer.backgroundColor = [UIColor blackColor];
    
    [self addSubview:_backgroundContainer];
    
    _defaultView = [[UIImageView alloc] initWithImage:_defaultPortraitImage];
    
    _defaultView.frame = _backgroundContainer.bounds;
    _defaultView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _currentBackgroundsAreLandscape = false;
    _defaultView.userInteractionEnabled = false;
    _defaultView.opaque = false;
    [_backgroundContainer addSubview:_defaultView];
    
    _blackView = [[UIView alloc] init];
    _blackView.frame = _backgroundContainer.bounds;
    _blackView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _blackView.backgroundColor = globalBlackOpaquePortraitBackground;
    _blackView.userInteractionEnabled = false;
    _blackView.alpha = 0.0f;
    _blackView.opaque = false;
    [_backgroundContainer addSubview:_blackView];
    
    UISwipeGestureRecognizer *swipeRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeGestureRecognized:)];
    swipeRecognizer.direction = UISwipeGestureRecognizerDirectionDown;
    [self addGestureRecognizer:swipeRecognizer];
    
    [self setBackgroundColor:[UIColor clearColor]];
    
    UIImage *shadowImage = [UIImage imageNamed:@"HeaderShadow.png"];
    _shadowView = [[UIImageView alloc] initWithFrame:CGRectMake(0, self.frame.size.height, self.frame.size.width, shadowImage.size.height)];
    _shadowView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    _shadowView.image = shadowImage;
    [self addSubview:_shadowView];
    
    self.clipsToBounds = false;
}

- (void)setBackgroundColor:(UIColor *)__unused backgroundColor
{
    static UIColor *clearColor = nil;
    if (clearColor == nil)
        clearColor = [UIColor clearColor];
    [super setBackgroundColor:clearColor];
}

- (void)dealloc
{
}

- (void)setShadowMode:(bool)dark
{
    if (dark)
    {
        UIImage *shadowImage = [UIImage imageNamed:@"HeaderLoginShadow.png"];
        _shadowView.image = shadowImage;
        _shadowView.frame = CGRectMake(0, self.frame.size.height, self.frame.size.width, shadowImage.size.height);
    }
}

- (void)updateBackground
{
    bool isLandscape = self.frame.size.width > 400;
    
    bool supportsStretching = [UIImage instancesRespondToSelector:@selector(resizableImageWithCapInsets:)];
    
    _currentBackgroundsAreLandscape = isLandscape;
    
    if (supportsStretching)
        ((UIImageView *)_defaultView).image = isLandscape ? _defaultLandscapeImage : _defaultPortraitImage;
    else
        _defaultView.backgroundColor = isLandscape ? globalDefaultLandscapeBackground : globalDefaultPortraitBackground;
    
    _blackView.backgroundColor = isLandscape ? globalBlackOpaqueLandscapeBackground : globalBlackOpaquePortraitBackground;
    
    if (_actionOverlayView != nil)
    {
        static UIImage *portraitImage = nil;
        static UIImage *landscapeImage = nil;
        
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^
        {
            UIImage *rawPortraitImage = [UIImage imageNamed:@"HeaderActionOverlay"];
            portraitImage = [rawPortraitImage stretchableImageWithLeftCapWidth:(int)(rawPortraitImage.size.width / 2) topCapHeight:0];
            
            UIImage *rawLandscapeImage = [UIImage imageNamed:@"HeaderActionOverlay_Landscape.png"];
            landscapeImage = [rawLandscapeImage stretchableImageWithLeftCapWidth:(int)(rawLandscapeImage.size.width / 2) topCapHeight:0];
        });
        
        UIImage *image = isLandscape ? landscapeImage : portraitImage;
        _actionOverlayView.image = image;
        CGRect overlayFrame = _actionOverlayView.frame;
        overlayFrame.size.width = self.frame.size.width;
        overlayFrame.size.height = image.size.height;
        _actionOverlayView.frame = overlayFrame;
    }
    
    [_defaultView setNeedsDisplay];
    [_blackView setNeedsDisplay];
}

- (void)findAndAlignButtons:(UIView *)view landscape:(bool)landscape
{
    if (view == nil)
        return;
    
    if ([view isKindOfClass:[TGToolbarButton class]])
    {
        [(TGToolbarButton *)view setIsLandscape:landscape];
    }
    else if ([view respondsToSelector:@selector(setLandscape:)])
    {
        [(id)view setLandscape:landscape];
    }
    
    for (UIView *subview in view.subviews)
    {
        [self findAndAlignButtons:subview landscape:landscape];
    }
}

- (void)layoutSubviews
{
    [self sendSubviewToBack:_backgroundContainer];
    
    bool isLandscape = self.frame.size.width > 400;
    
    if (isLandscape != _currentBackgroundsAreLandscape)
    {
        [self updateBackground];
    }
    
    [self findAndAlignButtons:self landscape:isLandscape];
    
    [super layoutSubviews];
    
    if (iosMajorVersion() >= 7)
    {
        CGRect selfFrame = self.frame;
        
        UINavigationItem *topItem = self.topItem;
        if (topItem != nil)
        {
            UIView *leftView = topItem.leftBarButtonItem.customView;
            if (leftView != nil)
            {
                CGRect frame = leftView.frame;
                if (!isLandscape)
                    frame.origin = CGPointMake(5, floorf((selfFrame.size.height - frame.size.height) / 2));
                else
                    frame.origin = CGPointMake(3, floorf((selfFrame.size.height - frame.size.height) / 2));
                leftView.frame = frame;
            }
            
            UIView *rightView = topItem.rightBarButtonItem.customView;
            if (rightView != nil)
            {
                CGRect frame = rightView.frame;
                if (!isLandscape)
                    frame.origin = CGPointMake(selfFrame.size.width - frame.size.width - 5, floorf((selfFrame.size.height - frame.size.height) / 2));
                else
                    frame.origin = CGPointMake(selfFrame.size.width - frame.size.width - 3, floorf((selfFrame.size.height - frame.size.height) / 2));
                rightView.frame = frame;
            }
            
            UIView *titleView = topItem.titleView;
            if (titleView != nil)
            {
                CGRect frame = titleView.frame;
                frame.origin = CGPointMake(floorf((selfFrame.size.width - frame.size.width) / 2), floorf((selfFrame.size.height - frame.size.height) / 2));
                titleView.frame = frame;
            }
        }
    }
    
    for (UIView *child in self.subviews)
    {
        child.clipsToBounds = false;
    }
    
    if (_actionOverlayView != nil)
    {
        _actionOverlayView.frame = CGRectIntegral(CGRectMake((_backgroundContainer.frame.size.width - _actionOverlayView.frame.size.width) / 2, 0, _actionOverlayView.frame.size.width, _actionOverlayView.frame.size.height));
    }
}

- (void)setBarStyle:(UIBarStyle)barStyle
{
    [self setBarStyle:barStyle animated:false];
}

- (void)setBarStyle:(UIBarStyle)__unused barStyle animated:(bool)__unused animated
{
    if (self.barStyle != UIBarStyleBlackTranslucent || barStyle != UIBarStyleBlackTranslucent)
    {
        barStyle = UIBarStyleBlackTranslucent;
    }
    
    [super setBarStyle:barStyle];
}

- (void)setBarStyle:(UIBarStyle)barStyle animated:(bool)animated duration:(NSTimeInterval)duration
{
    UIBarStyle previousBarStyle = self.barStyle;
    
    if (previousBarStyle != barStyle)
        [self updateBarStyle:barStyle previousBarStyle:previousBarStyle animated:animated duration:duration];
    
    [super setBarStyle:barStyle];
}

- (void)resetBarStyle
{
    if (self.barStyle == UIBarStyleDefault)
    {
        _defaultView.alpha = 1.0f;
        _blackView.alpha = 0.0f;
    }
    else if (self.barStyle == UIBarStyleBlack)
    {
        _defaultView.alpha = 0.0f;
        _blackView.alpha = 1.0f;
    }
}

- (void)setCenter:(CGPoint)center
{
    [super setCenter:center];
    
    if (_statusBarBackgroundView != nil && _statusBarBackgroundView.superview != nil)
    {
        _statusBarBackgroundView.frame = CGRectMake(0, -self.frame.origin.y, self.frame.size.width, 20);
    }
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    
    if (_statusBarBackgroundView != nil && _statusBarBackgroundView.superview != nil)
    {
        _statusBarBackgroundView.frame = CGRectMake(0, -self.frame.origin.y, self.frame.size.width, 20);
    }
}

- (void)setHiddenState:(bool)hidden animated:(bool)animated
{
    if (animated)
    {
        if (_hiddenState != hidden)
        {
            _hiddenState = hidden;
            
            if (_statusBarBackgroundView == nil)
            {
                _statusBarBackgroundView = [[UIView alloc] initWithFrame:CGRectMake(0, -self.frame.origin.y, self.frame.size.width, 20)];
                _statusBarBackgroundView.backgroundColor = [UIColor blackColor];
            }
            else
                _statusBarBackgroundView.frame = CGRectMake(0, -self.frame.origin.y, self.frame.size.width, 20);
            
            [self addSubview:_statusBarBackgroundView];
            
            [UIView animateWithDuration:0.3 animations:^
            {
                _shadowView.alpha = hidden ? 0.0f : 1.0f;
                _progressView.alpha = hidden ? 0.0f : 1.0f;
            } completion:^(BOOL finished)
            {
                if (finished)
                    [_statusBarBackgroundView removeFromSuperview];
            }];
        }
        else
        {
            _shadowView.alpha = hidden ? 0.0f : 1.0f;
            _progressView.alpha = hidden ? 0.0f : 1.0f;
        }
    }
    else
    {
        _hiddenState = hidden;
        
        _shadowView.alpha = hidden ? 0.0f : 1.0f;
        _progressView.alpha = hidden ? 0.0f : 1.0f;
    }
}

- (void)updateBarStyle:(UIBarStyle)barStyle previousBarStyle:(UIBarStyle)__unused previousBarStyle animated:(bool)animated duration:(NSTimeInterval)duration
{
    if (barStyle == UIBarStyleDefault)
    {
        [_backgroundContainer bringSubviewToFront:_defaultView];
        
        dispatch_block_t block = ^
        {
            _defaultView.alpha = 1.0f;
            _navigationController.cornersImageView.alpha = 1.0f;
        };
        
        [_blackView.layer removeAllAnimations];
        
        if (animated)
        {
            [UIView animateWithDuration:duration animations:block completion:^(BOOL finished)
            {
                if (finished)
                {
                    _blackView.alpha = 0.0f;
                }
            }];
        }
        else
        {
            block();
            _blackView.alpha = 0.0f;
        }
    }
    else if (barStyle == UIBarStyleBlackOpaque)
    {
        [_backgroundContainer bringSubviewToFront:_blackView];
        
        dispatch_block_t block = ^
        {
            _blackView.alpha = 1.0f;
            _navigationController.cornersImageView.alpha = 1.0f;
        };
        
        [_defaultView.layer removeAllAnimations];
        
        if (animated)
        {
            [UIView animateWithDuration:duration animations:block completion:^(BOOL finished)
            {
                if (finished)
                {
                    _defaultView.alpha = 0.0f;
                }
            }];
        }
        else
        {
            block();
            _defaultView.alpha = 0.0f;
        }
    }
    else if (barStyle == UIBarStyleBlackTranslucent)
    {
        [_backgroundContainer bringSubviewToFront:_blackView];
        
        dispatch_block_t block = ^
        {
            _blackView.alpha = 0.5f;
            _navigationController.cornersImageView.alpha = 0.0f;
            _defaultView.alpha = 0.0f;
        };
        
        [_defaultView.layer removeAllAnimations];
        
        if (animated)
        {
            [UIView animateWithDuration:duration animations:block completion:^(BOOL finished)
            {
                if (finished)
                {
                }
            }];
        }
        else
        {
            block();
        }
    }
}

- (void)drawRect:(CGRect)__unused rect
{
}

#pragma mark -

- (UIImageView *)actionOverlayView
{
    if (_actionOverlayView == nil)
    {
        _actionOverlayView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, self.frame.size.width, self.frame.size.height)];
        [self updateBackground];
        [_backgroundContainer addSubview:_actionOverlayView];
    }
    
    return _actionOverlayView;
}

static bool findViewHasActions(UIView *currentView, UIView *maxParent)
{
    if (currentView == maxParent || currentView == nil)
        return false;
    
    if (currentView.gestureRecognizers.count != 0)
        return true;
    
    return findViewHasActions(currentView.superview, maxParent);
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    UIView *hitResult = [self hitTest:[touch locationInView:self] withEvent:event];
    if (!findViewHasActions(hitResult, self))
    {
        UIViewController *viewController = _navigationController.topViewController;
        if ([viewController conformsToProtocol:@protocol(TGViewControllerNavigationBarAppearance)] && [viewController respondsToSelector:@selector(navigationBarHasAction)])
        {
            if ([(id<TGViewControllerNavigationBarAppearance>)viewController navigationBarHasAction])
            {
                self.actionOverlayView.hidden = false;
                _actionOverlayView.alpha = 1.0f;
                [_actionOverlayView.layer removeAllAnimations];
            }
        }
    }
    
    [super touchesBegan:touches withEvent:event];
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    UIView *view = [super hitTest:CGPointMake(point.x - 16, point.y) withEvent:event];
    if (view != nil && [view isKindOfClass:[TGToolbarButton class]] && view.alpha > FLT_EPSILON && !view.hidden)
        return view;
    
    return [super hitTest:point withEvent:event];
}

- (void)hideActionOverlay
{
    [UIView animateWithDuration:0.34 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^
    {
        _actionOverlayView.alpha = 0.0f;
    } completion:^(BOOL finished)
    {
        if (finished)
        {
            _actionOverlayView.hidden = true;
        }
    }];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (_actionOverlayView != nil)
    {
        if (_actionOverlayView.alpha > FLT_EPSILON)
        {
            [self hideActionOverlay];
            
            UIViewController *viewController = _navigationController.topViewController;
            if ([viewController conformsToProtocol:@protocol(TGViewControllerNavigationBarAppearance)] && [viewController respondsToSelector:@selector(navigationBarAction)])
            {
                [(id<TGViewControllerNavigationBarAppearance>)viewController navigationBarAction];
            }
        }
    }
    
    [super touchesEnded:touches withEvent:event];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (_actionOverlayView != nil && _actionOverlayView.alpha > FLT_EPSILON)
        [self hideActionOverlay];
    
    [super touchesCancelled:touches withEvent:event];
}

- (void)swipeGestureRecognized:(UISwipeGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateRecognized)
    {
        UIViewController *viewController = _navigationController.topViewController;
        if ([viewController conformsToProtocol:@protocol(TGViewControllerNavigationBarAppearance)] && [viewController respondsToSelector:@selector(navigationBarSwipeDownAction)])
        {
            [(id<TGViewControllerNavigationBarAppearance>)viewController navigationBarSwipeDownAction];
        }
    }
}

#if TGUseGestureNavigationController

/*- (NSArray *)items
{
    return _currentNavigationItems;
}

- (void)setItems:(NSArray *)items
{
    [self setItems:items animated:false];
}

- (void)setItems:(NSArray *)items animated:(BOOL)animated
{
    
}*/

#endif

@end
