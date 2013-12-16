#import "TGViewController.h"

#import "TGToolbarButton.h"
#import "TGLabel.h"

#import "TGNavigationController.h"

#import <QuartzCore/QuartzCore.h>

#import "TGHacks.h"

#import <set>

static __strong NSTimer *autorotationEnableTimer = nil;
static bool autorotationDisabled = false;

static __strong NSTimer *userInteractionEnableTimer = nil;

static std::set<int> autorotationLockIds;

@implementation TGAutorotationLock

- (id)init
{
    self = [super init];
    if (self != nil)
    {
        static int nextId = 1;
        _lockId = nextId++;
        
        int lockId = _lockId;
        
        if ([NSThread isMainThread])
        {
            autorotationLockIds.insert(lockId);
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^
            {
                autorotationLockIds.insert(lockId);
            });
        }
    }
    return self;
}

- (void)dealloc
{
    int lockId = _lockId;
    
    if ([NSThread isMainThread])
    {
        autorotationLockIds.erase(lockId);
    }
    else
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            autorotationLockIds.erase(lockId);
        });
    }
}

@end

@interface TGViewController ()

@property (nonatomic, strong) UIView *viewControllerStatusBarBackgroundView;
@property (nonatomic) bool viewControllerIsChangingInterfaceOrientation;
@property (nonatomic) UIInterfaceOrientation viewControllerRotatingFromOrientation;

@property (nonatomic, strong) TGAutorotationLock *autorotationLock;

@end

@implementation TGViewController

+ (UIFont *)titleFontForStyle:(TGViewControllerStyle)__unused style landscape:(bool)landscape
{
    if (!landscape)
    {
        static UIFont *font = nil;
        if (font == nil)
            font = [UIFont boldSystemFontOfSize:20];
        return font;
    }
    else
    {
        static UIFont *font = nil;
        if (font == nil)
            font = [UIFont boldSystemFontOfSize:17];
        return font;
    }
}

+ (UIFont *)titleTitleFontForStyle:(TGViewControllerStyle)__unused style landscape:(bool)landscape
{
    if (!landscape)
    {
        static UIFont *font = nil;
        if (font == nil)
            font = [UIFont boldSystemFontOfSize:16];
        return font;
    }
    else
    {
        static UIFont *font = nil;
        if (font == nil)
            font = [UIFont boldSystemFontOfSize:15];
        return font;
    }
}

+ (UIFont *)titleSubtitleFontForStyle:(TGViewControllerStyle)__unused style landscape:(bool)landscape
{
    if (!landscape)
    {
        static UIFont *font = nil;
        if (font == nil)
            font = [UIFont systemFontOfSize:13];
        return font;
    }
    else
    {
        static UIFont *font = nil;
        if (font == nil)
            font = [UIFont systemFontOfSize:13];
        return font;
    }
}

+ (UIColor *)titleTextColorForStyle:(TGViewControllerStyle)style
{
    if (style == TGViewControllerStyleDefault)
    {
        static UIColor *color = nil;
        if (color == nil)
            color = UIColorRGB(0xffffff);
        return color;
    }
    else
    {
        static UIColor *color = nil;
        if (color == nil)
            color = UIColorRGB(0xffffff);
        return color;
    }
}

+ (UIColor *)titleShadowColorForStyle:(TGViewControllerStyle)style
{
    if (style == TGViewControllerStyleDefault)
    {
        static UIColor *color = nil;
        if (color == nil)
            color = UIColorRGB(0x3d5c81);
        return color;
    }
    else
    {
        static UIColor *color = nil;
        if (color == nil)
            color = UIColorRGB(0x2f3948);
        return color;
    }
}

+ (CGSize)titleShadowOffsetForStyle:(TGViewControllerStyle)style
{
    if (style == TGViewControllerStyleDefault)
    {
        return CGSizeMake(0, -1);
    }
    else
    {
        return CGSizeMake(0, -1);
    }
}

+ (CGSize)screenSize:(UIDeviceOrientation)orientation
{
    static bool mainScreenSizeInitialized = false;
    static CGSize mainScreenSize;
    if (!mainScreenSizeInitialized)
    {
        mainScreenSize = [UIScreen mainScreen].bounds.size;
        mainScreenSizeInitialized = true;
    }
    
    CGSize size = CGSizeZero;
    if (UIDeviceOrientationIsPortrait(orientation))
        size = CGSizeMake(mainScreenSize.width, mainScreenSize.height);
    else
        size = CGSizeMake(mainScreenSize.height, mainScreenSize.width);
    return size;
}

+ (CGSize)screenSizeForInterfaceOrientation:(UIInterfaceOrientation)orientation
{
    static bool mainScreenSizeInitialized = false;
    static CGSize mainScreenSize;
    if (!mainScreenSizeInitialized)
    {
        mainScreenSize = [UIScreen mainScreen].bounds.size;
        mainScreenSizeInitialized = true;
    }
    
    CGSize size = CGSizeZero;
    if (UIInterfaceOrientationIsPortrait(orientation))
        size = CGSizeMake(mainScreenSize.width, mainScreenSize.height);
    else
        size = CGSizeMake(mainScreenSize.height, mainScreenSize.width);
    return size;
}

+ (bool)isWidescreen
{
    static bool isWidescreenInitialized = false;
    static bool isWidescreen = false;
    
    if (!isWidescreenInitialized)
    {
        isWidescreenInitialized = true;
        
        CGSize screenSize = [TGViewController screenSizeForInterfaceOrientation:UIInterfaceOrientationPortrait];
        if (screenSize.width > 321 || screenSize.height > 481)
            isWidescreen = true;
    }
    
    return isWidescreen;
}

+ (void)disableAutorotation
{
    autorotationDisabled = true;
}

+ (void)enableAutorotation
{
    autorotationDisabled = false;
}

+ (void)disableAutorotationFor:(NSTimeInterval)timeInterval
{
    [self disableAutorotationFor:timeInterval reentrant:false];
}

+ (void)disableAutorotationFor:(NSTimeInterval)timeInterval reentrant:(bool)reentrant
{
    if (reentrant && autorotationDisabled)
        return;
    
    autorotationDisabled = true;
    
    if (autorotationEnableTimer != nil)
    {
        if ([autorotationEnableTimer isValid])
        {
            [autorotationEnableTimer invalidate];
        }
        autorotationEnableTimer = nil;
    }
    
    autorotationEnableTimer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:timeInterval] interval:0 target:self selector:@selector(enableTimerEvent) userInfo:nil repeats:false];
    [[NSRunLoop mainRunLoop] addTimer:autorotationEnableTimer forMode:NSRunLoopCommonModes];
}

+ (bool)autorotationAllowed
{
    return !autorotationDisabled && autorotationLockIds.empty();
}

+ (void)attemptAutorotation
{
    if ([TGViewController autorotationAllowed])
    {
        if ([(NSObject *)[UIViewController class] respondsToSelector:@selector(attemptRotationToDeviceOrientation)])
        {
            [UIViewController attemptRotationToDeviceOrientation];
        }
    }
}

+ (void)enableTimerEvent
{
    autorotationDisabled = false;

    [self attemptAutorotation];
    
    autorotationEnableTimer = nil;
}

+ (void)disableUserInteractionFor:(NSTimeInterval)timeInterval
{
    if (userInteractionEnableTimer != nil)
    {
        if ([userInteractionEnableTimer isValid])
        {
            [userInteractionEnableTimer invalidate];
            [[UIApplication sharedApplication] endIgnoringInteractionEvents];
        }
        userInteractionEnableTimer = nil;
    }
    
    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
    
    userInteractionEnableTimer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:timeInterval] interval:0 target:self selector:@selector(userInteractionEnableTimerEvent) userInfo:nil repeats:false];
    [[NSRunLoop mainRunLoop] addTimer:userInteractionEnableTimer forMode:NSRunLoopCommonModes];
}

+ (void)userInteractionEnableTimerEvent
{
    [[UIApplication sharedApplication] endIgnoringInteractionEvents];
    
    userInteractionEnableTimer = nil;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
    {
        [self _commonViewControllerInit];
    }
    return self;
}

- (id)init
{
    self = [super init];
    if (self != nil)
    {
        [self _commonViewControllerInit];
    }
    return self;
}

- (void)_commonViewControllerInit
{
    self.wantsFullScreenLayout = true;
    self.automaticallyManageScrollViewInsets = true;
    self.autoManageStatusBarBackground = true;
    
    if (iosMajorVersion() >= 7)
    {
        static SEL autoAdjustSelector = NULL;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^
        {
            autoAdjustSelector = NSSelectorFromString(TGEncodeText(@"tfuBvupnbujdbmmzBekvtutTdspmmWjfxJotfut;", -1));
        });
        
        if ([self respondsToSelector:autoAdjustSelector])
        {
            NSMethodSignature *signature = [[UIViewController class] instanceMethodSignatureForSelector:autoAdjustSelector];
            if (signature == nil)
            {
                TGLog(@"***** Method not found");
            }
            else
            {
                NSInvocation *inv = [NSInvocation invocationWithMethodSignature:signature];
                [inv setSelector:autoAdjustSelector];
                [inv setTarget:self];
                BOOL value = false;
                [inv setArgument:&value atIndex:2];
                [inv invoke];
            }
        }
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewControllerStatusBarWillChangeFrame:) name:UIApplicationWillChangeStatusBarFrameNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewControllerKeyboardWillChangeFrame:) name:UIKeyboardWillChangeFrameNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewControllerKeyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillChangeStatusBarFrameNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillChangeFrameNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
}

- (UINavigationController *)navigationController
{
    if (_customParentViewController != nil && _customParentViewController.navigationController != nil)
        return _customParentViewController.navigationController;
    return [super navigationController];
}

- (void)acquireRotationLock
{
    if (_autorotationLock == nil)
        _autorotationLock = [[TGAutorotationLock alloc] init];
}

- (void)releaseRotationLock
{
    _autorotationLock = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return [TGViewController autorotationAllowed] && interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
}

- (BOOL)shouldAutorotate
{
    return [self shouldAutorotateToInterfaceOrientation:UIInterfaceOrientationPortrait];
}

- (void)viewDidLoad
{
    if ([self viewControllerPreferredStatusBarStyle] == UIStatusBarStyleBlackOpaque && _autoManageStatusBarBackground)
    {
        _viewControllerStatusBarBackgroundView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 20)];
        _viewControllerStatusBarBackgroundView.userInteractionEnabled = false;
        _viewControllerStatusBarBackgroundView.layer.zPosition = 1000;
        _viewControllerStatusBarBackgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _viewControllerStatusBarBackgroundView.backgroundColor = [UIColor blackColor];
        [self.view addSubview:_viewControllerStatusBarBackgroundView];
    }
    
    [super viewDidLoad];
}

- (void)fadeInTitleText
{
    _titleLabel.alpha = 0.0f;
    [UIView animateWithDuration:0.3 animations:^
    {
        _titleLabel.alpha = 1.0f;
    }];
}

- (void)setTitleText:(NSString *)titleText
{
    _titleText = titleText;
    
    if (_titleLabel == nil)
    {
        _titleLabel = [[TGLabel alloc] init];
        _titleLabel.backgroundColor = [UIColor clearColor];
        
        _titleLabel.portraitFont = _titleTextFontPortrait != nil ? _titleTextFontPortrait : [TGViewController titleFontForStyle:_style landscape:false];
        _titleLabel.landscapeFont = _titleTextFontLandscape != nil ? _titleTextFontLandscape : [TGViewController titleFontForStyle:_style landscape:true];
        _titleLabel.font = UIInterfaceOrientationIsLandscape(self.interfaceOrientation) ? _titleLabel.landscapeFont : _titleLabel.portraitFont;
        _titleLabel.textColor = [TGViewController titleTextColorForStyle:_style];
        _titleLabel.shadowColor = [TGViewController titleShadowColorForStyle:_style];
        _titleLabel.shadowOffset = [TGViewController titleShadowOffsetForStyle:_style];
        
        _titleLabel.verticalAlignment = TGLabelVericalAlignmentTop;
        
        self.navigationItem.titleView = _titleLabel;
    }
    
    _titleLabel.text = _titleText;
    _titleLabel.frame = CGRectMake(0, 0, 480, 44);
    [_titleLabel sizeToFit];
    CGRect titleLabelFrame = _titleLabel.frame;
    titleLabelFrame.size.height += 2;
    titleLabelFrame.origin.x = (int)((self.view.frame.size.width - titleLabelFrame.size.width) / 2);
    titleLabelFrame.origin.y = (int)(((UIInterfaceOrientationIsPortrait(self.interfaceOrientation) ? 44 : 32) - titleLabelFrame.size.height) / 2) + 1;
    _titleLabel.frame = titleLabelFrame;
}

- (void)setSubtitleText:(NSString *)subtitleText
{
    _subtitleText = subtitleText;
}

- (void)viewWillAppear:(BOOL)animated
{
    UIView *inputView = [self selectActiveInputView];
    if (inputView != nil)
        [inputView becomeFirstResponder];
    
    if ([self.navigationController isKindOfClass:[TGNavigationController class]])
        [(TGNavigationController *)self.navigationController setupNavigationBarForController:self animated:animated];
    
    [self _updateControllerInsetForOrientation:self.interfaceOrientation force:false notify:true];
    
    [self adjustToInterfaceOrientation:self.interfaceOrientation];
    
    [super viewWillAppear:animated];
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    //TGLog(@"Will rotate");
    _viewControllerIsChangingInterfaceOrientation = true;
    _viewControllerRotatingFromOrientation = self.interfaceOrientation;
    
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [self adjustToInterfaceOrientation:toInterfaceOrientation];
    
    float additionalKeyboardHeight = [self _keyboardAdditionalDeltaHeightWhenRotatingFrom:_viewControllerRotatingFromOrientation toOrientation:toInterfaceOrientation];
    
    [self _updateControllerInsetForOrientation:toInterfaceOrientation statusBarHeight:[TGHacks statusBarHeightForOrientation:toInterfaceOrientation] keyboardHeight:[self _currentKeyboardHeight:toInterfaceOrientation] + additionalKeyboardHeight force:false notify:true];
    
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    //TGLog(@"Did rotate");
    _viewControllerIsChangingInterfaceOrientation = false;
    
    [super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
}

- (float)_currentKeyboardHeight:(UIInterfaceOrientation)orientation
{
    if ([TGHacks isKeyboardVisible])
        return [TGHacks keyboardHeightForOrientation:orientation];
    
    return 0.0f;
}

- (float)_keyboardAdditionalDeltaHeightWhenRotatingFrom:(UIInterfaceOrientation)fromOrientation toOrientation:(UIInterfaceOrientation)toOrientation
{
    if ([TGHacks isKeyboardVisible])
    {
        if (UIInterfaceOrientationIsPortrait(fromOrientation) != UIInterfaceOrientationIsPortrait(toOrientation))
        {
        }
    }
    
    return 0.0f;
}

- (float)_currentStatusBarHeight
{
    CGRect statusBarFrame = [[UIApplication sharedApplication] statusBarFrame];
    return MIN(statusBarFrame.size.width, statusBarFrame.size.height);
}

- (void)viewControllerStatusBarWillChangeFrame:(NSNotification *)notification
{
    if (!_viewControllerIsChangingInterfaceOrientation)
    {
        CGRect statusBarFrame = [[[notification userInfo] objectForKey:UIApplicationStatusBarFrameUserInfoKey] CGRectValue];
        float statusBarHeight = MIN(statusBarFrame.size.width, statusBarFrame.size.height);
        
        float keyboardHeight = [self _currentKeyboardHeight:self.interfaceOrientation];
        
        [UIView animateWithDuration:0.35 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^
        {
            [self _updateControllerInsetForOrientation:self.interfaceOrientation statusBarHeight:statusBarHeight keyboardHeight:keyboardHeight force:false notify:true];
        } completion:nil];
    }
}

- (void)viewControllerKeyboardWillChangeFrame:(NSNotification *)notification
{
    if (!_viewControllerIsChangingInterfaceOrientation)
    {
        float statusBarHeight = [self _currentStatusBarHeight];
        
        CGRect keyboardFrame = [[[notification userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
        float keyboardHeight = MIN(keyboardFrame.size.height, keyboardFrame.size.width);
        double duration = ([[[notification userInfo] objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue]);
        
        [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^
        {
            [self _updateControllerInsetForOrientation:self.interfaceOrientation statusBarHeight:statusBarHeight keyboardHeight:keyboardHeight force:false notify:true];
        } completion:nil];
    }
}

- (void)viewControllerKeyboardWillHide:(NSNotification *)notification
{
    if (!_viewControllerIsChangingInterfaceOrientation)
    {
        float statusBarHeight = [self _currentStatusBarHeight];
        
        float keyboardHeight = 0.0f;
        double duration = ([[[notification userInfo] objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue]);
        
        [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^
        {
            [self _updateControllerInsetForOrientation:self.interfaceOrientation statusBarHeight:statusBarHeight keyboardHeight:keyboardHeight force:false notify:true];
        } completion:nil];
    }
}

#pragma mark -

- (void)setBackAction:(SEL)backAction
{
    [self setBackAction:backAction animated:false];
}

- (void)setBackAction:(SEL)backAction animated:(bool)animated
{
    _backAction = backAction;
    
    if (backAction != nil)
    {
        TGToolbarButton *backButton = [[TGToolbarButton alloc] initWithType:TGToolbarButtonTypeBack];
        backButton.tag = ((int)0x263D9E33);
        backButton.text = NSLocalizedString(@"Common.Back", @"");
        [backButton sizeToFit];
        [backButton addTarget:self action:backAction forControlEvents:UIControlEventTouchUpInside];
        UIBarButtonItem *backItem = [[UIBarButtonItem alloc] initWithCustomView:backButton];
        [self.navigationItem setLeftBarButtonItem:backItem animated:animated];
    }
}

- (void)setBackAction:(SEL)backAction imageNormal:(UIImage *)imageNormal imageNormalHighlighted:(UIImage *)imageNormalHighlighted imageLadscape:(UIImage *)imageLandscape imageLandscapeHighlighted:(UIImage *)imageLandscapeHighlighted textColor:(UIColor *)textColor shadowColor:(UIColor *)shadowColor
{
    _backAction = backAction;
    
    if (backAction != nil)
    {
        TGToolbarButton *backButton = [[TGToolbarButton alloc] initWithCustomImages:imageNormal imageNormalHighlighted:imageNormalHighlighted imageLandscape:imageLandscape imageLandscapeHighlighted:imageLandscapeHighlighted textColor:textColor shadowColor:shadowColor];
        backButton.backSemantics = true;
        backButton.paddingLeft = 15;
        backButton.paddingRight = 9;
        backButton.text = NSLocalizedString(@"Common.Back", @"");
        [backButton sizeToFit];
        [backButton addTarget:self action:backAction forControlEvents:UIControlEventTouchUpInside];
        UIBarButtonItem *backItem = [[UIBarButtonItem alloc] initWithCustomView:backButton];
        self.navigationItem.leftBarButtonItem = backItem;
    }
}

- (void)adjustNavigationItem:(UIInterfaceOrientation)orientation
{
    if (_titleLabel != nil)
    {
        CGSize screenSize = [TGViewController screenSizeForInterfaceOrientation:orientation];
        int maxWidth = (int)screenSize.width;
        [_titleLabel setLandscape:UIInterfaceOrientationIsLandscape(orientation)];
        _titleLabel.frame = CGRectMake(0, 0, maxWidth, UIInterfaceOrientationIsPortrait(orientation) ? 44 : 32);
        [_titleLabel sizeToFit];
        CGRect titleLabelFrame = _titleLabel.frame;
        titleLabelFrame.size.height += 2;
        _titleLabel.frame = titleLabelFrame;
    }
}

#pragma mark -

- (UIBarStyle)requiredNavigationBarStyle
{
    return UIBarStyleDefault;
}

- (bool)navigationBarHasAction
{
    return false;
}

- (void)navigationBarAction
{
}

- (void)navigationBarSwipeDownAction
{
}

- (bool)statusBarShouldBeHidden
{
    return false;
}

- (UIStatusBarStyle)viewControllerPreferredStatusBarStyle
{
    return UIStatusBarStyleBlackOpaque;
}

- (void)adjustToInterfaceOrientation:(UIInterfaceOrientation)orientation
{
    [self adjustNavigationItem:orientation];
}

- (void)setExplicitTableInset:(UIEdgeInsets)explicitTableInset
{
    [self setExplicitTableInset:explicitTableInset scrollIndicatorInset:_explicitScrollIndicatorInset];
}

- (void)setExplicitScrollIndicatorInset:(UIEdgeInsets)explicitScrollIndicatorInset
{
    [self setExplicitTableInset:_explicitTableInset scrollIndicatorInset:explicitScrollIndicatorInset];
}

- (void)setExplicitTableInset:(UIEdgeInsets)explicitTableInset scrollIndicatorInset:(UIEdgeInsets)scrollIndicatorInset
{
    _explicitTableInset = explicitTableInset;
    _explicitScrollIndicatorInset = scrollIndicatorInset;
    
    float statusBarHeight = [self _currentStatusBarHeight];
    float keyboardHeight = [self _currentKeyboardHeight:self.interfaceOrientation];
    
    [self _updateControllerInsetForOrientation:self.interfaceOrientation statusBarHeight:statusBarHeight keyboardHeight:keyboardHeight force:false notify:true];
}

- (bool)_updateControllerInset:(bool)force
{
    return [self _updateControllerInsetForOrientation:self.interfaceOrientation force:force notify:true];
}

- (bool)_updateControllerInsetForOrientation:(UIInterfaceOrientation)orientation force:(bool)force notify:(bool)notify
{
    float statusBarHeight = [self _currentStatusBarHeight];   
    float keyboardHeight = [self _currentKeyboardHeight:self.interfaceOrientation];
    
    return [self _updateControllerInsetForOrientation:orientation statusBarHeight:statusBarHeight keyboardHeight:keyboardHeight force:(bool)force notify:notify];
}

- (bool)_updateControllerInsetForOrientation:(UIInterfaceOrientation)orientation statusBarHeight:(float)statusBarHeight keyboardHeight:(float)keyboardHeight force:(bool)force notify:(bool)notify
{
    CGSize screenSize = [TGViewController screenSizeForInterfaceOrientation:orientation];
    
    float navigationBarHeight = [self navigationBarShouldBeHidden] ? 0 : (UIInterfaceOrientationIsPortrait(orientation) ? 44 : 32);
    UIEdgeInsets edgeInset = UIEdgeInsetsMake(statusBarHeight + navigationBarHeight, 0, 0, 0);
    
    edgeInset.left += _parentInsets.left;
    edgeInset.top += _parentInsets.top;
    edgeInset.right += _parentInsets.right;
    edgeInset.bottom += _parentInsets.bottom;
    
    if ([self.parentViewController isKindOfClass:[UITabBarController class]])
        edgeInset.bottom += 49;
    
    if (!_ignoreKeyboardWhenAdjustingScrollViewInsets)
        edgeInset.bottom = MAX(edgeInset.bottom, keyboardHeight);
    
    UIEdgeInsets previousInset = _controllerInset;
    UIEdgeInsets previousCleanInset = _controllerCleanInset;
    UIEdgeInsets previousIndicatorInset = _controllerScrollInset;
    
    UIEdgeInsets scrollEdgeInset = edgeInset;
    scrollEdgeInset.left += _explicitScrollIndicatorInset.left;
    scrollEdgeInset.right += _explicitScrollIndicatorInset.right;
    scrollEdgeInset.top += _explicitScrollIndicatorInset.top;
    scrollEdgeInset.bottom += _explicitScrollIndicatorInset.bottom;
    
    UIEdgeInsets cleanInset = edgeInset;
    
    edgeInset.left += _explicitTableInset.left;
    edgeInset.right += _explicitTableInset.right;
    edgeInset.top += _explicitTableInset.top;
    edgeInset.bottom += _explicitTableInset.bottom;
    
    CGRect statusBarBackgroundFrame = CGRectMake(0, _viewControllerStatusBarBackgroundView.frame.origin.y < 0 ? -statusBarHeight : 0, screenSize.width, statusBarHeight);
    if (!CGRectEqualToRect(statusBarBackgroundFrame, _viewControllerStatusBarBackgroundView.frame))
        _viewControllerStatusBarBackgroundView.frame = statusBarBackgroundFrame;
    
    if (force || !UIEdgeInsetsEqualToEdgeInsets(previousInset, edgeInset) || !UIEdgeInsetsEqualToEdgeInsets(previousIndicatorInset, scrollEdgeInset) || !UIEdgeInsetsEqualToEdgeInsets(previousCleanInset, cleanInset))
    {
        _controllerInset = edgeInset;
        _controllerCleanInset = cleanInset;
        _controllerScrollInset = scrollEdgeInset;
        _controllerStatusBarHeight = statusBarHeight;
        
        if (notify)
            [self controllerInsetUpdated:previousInset];
        
        return true;
    }
    
    return false;
}

- (void)_autoAdjustInsetsForScrollView:(UIScrollView *)scrollView previousInset:(UIEdgeInsets)previousInset
{
    CGPoint contentOffset = scrollView.contentOffset;
    
    UIEdgeInsets finalInset = self.controllerInset;
    
    scrollView.contentInset = finalInset;
    scrollView.scrollIndicatorInsets = self.controllerScrollInset;
    
    if (!UIEdgeInsetsEqualToEdgeInsets(previousInset, UIEdgeInsetsZero))
    {
        contentOffset.y += previousInset.top - finalInset.top;
        float maxOffset = scrollView.contentSize.height - (scrollView.frame.size.height - finalInset.bottom);
        contentOffset.y = MAX(-finalInset.top, MIN(contentOffset.y, maxOffset));
        [scrollView setContentOffset:contentOffset animated:false];
    }
    else if (contentOffset.y < finalInset.top)
    {
        contentOffset.y = -finalInset.top;
        [scrollView setContentOffset:contentOffset animated:false];
    }
}

- (void)controllerInsetUpdated:(UIEdgeInsets)previousInset
{
    if (self.isViewLoaded)
    {
        if (_automaticallyManageScrollViewInsets)
        {
            for (UIView *view in self.view.subviews)
            {
                if ([view isKindOfClass:[UIScrollView class]])
                {
                    [self _autoAdjustInsetsForScrollView:(UIScrollView *)view previousInset:previousInset];
                    
                    break;
                }
            }
            
            if (_scrollViewsForAutomaticInsetsAdjustment != nil)
            {
                for (UIScrollView *scrollView in _scrollViewsForAutomaticInsetsAdjustment)
                {
                    [self _autoAdjustInsetsForScrollView:scrollView previousInset:previousInset];
                }
            }
        }
    }
}

- (void)setNavigationBarHidden:(bool)navigationBarHidden animated:(BOOL)animated
{
    [self setNavigationBarHidden:navigationBarHidden withAnimation:animated ? TGViewControllerNavigationBarAnimationSlide : TGViewControllerNavigationBarAnimationNone];
}

- (void)setNavigationBarHidden:(bool)navigationBarHidden withAnimation:(TGViewControllerNavigationBarAnimation)animation
{
    [self setNavigationBarHidden:navigationBarHidden withAnimation:animation duration:0.3f];
}

- (void)setNavigationBarHidden:(bool)navigationBarHidden withAnimation:(TGViewControllerNavigationBarAnimation)animation duration:(NSTimeInterval)duration
{
    if (navigationBarHidden != self.navigationController.navigationBarHidden || navigationBarHidden != self.navigationBarShouldBeHidden)
    {
        self.navigationBarShouldBeHidden = navigationBarHidden;
        
        if (animation == TGViewControllerNavigationBarAnimationFade)
        {
            if (navigationBarHidden != self.navigationController.navigationBarHidden)
            {
                if (!navigationBarHidden)
                {
                    [self.navigationController setNavigationBarHidden:false animated:false];
                    self.navigationController.navigationBar.alpha = 0.0f;
                }
                [UIView animateWithDuration:duration animations:^
                {
                    self.navigationController.navigationBar.alpha = navigationBarHidden ? 0.0f : 1.0f;
                } completion:^(BOOL finished)
                {
                    if (finished)
                    {
                        if (navigationBarHidden)
                        {
                            self.navigationController.navigationBar.alpha = 1.0f;
                            [self.navigationController setNavigationBarHidden:true animated:false];
                        }
                    }
                }];
            }
        }
        else if (animation == TGViewControllerNavigationBarAnimationSlideFar)
        {
            if (navigationBarHidden != self.navigationController.navigationBarHidden)
            {
                float barHeight = UIInterfaceOrientationIsPortrait(self.interfaceOrientation) ? 44 : 32;
                float statusBarHeight = [TGHacks statusBarHeightForOrientation:self.interfaceOrientation];
                
                CGSize screenSize = [TGViewController screenSizeForInterfaceOrientation:self.interfaceOrientation];
                
                if (!navigationBarHidden)
                {
                    [self.navigationController setNavigationBarHidden:false animated:false];
                    self.navigationController.navigationBar.frame = CGRectMake(0, -barHeight, screenSize.width, barHeight);
                }
                
                [UIView animateWithDuration:duration delay:0 options:0 animations:^
                {
                    if (navigationBarHidden)
                        self.navigationController.navigationBar.frame = CGRectMake(0, -barHeight, screenSize.width, barHeight);
                    else
                        self.navigationController.navigationBar.frame = CGRectMake(0, statusBarHeight, screenSize.width, barHeight);
                } completion:^(BOOL finished)
                {
                    if (finished)
                    {
                        if (navigationBarHidden)
                            [self.navigationController setNavigationBarHidden:true animated:false];
                    }
                }];
            }
        }
        else
        {
            [self.navigationController setNavigationBarHidden:navigationBarHidden animated:animation == TGViewControllerNavigationBarAnimationSlide];
        }
        
        [UIView animateWithDuration:UINavigationControllerHideShowBarDuration delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^
        {
            [self _updateControllerInset:false];
        } completion:nil];
    }
}

- (float)statusBarBackgroundAlpha
{
    return _viewControllerStatusBarBackgroundView.alpha;
}

- (UIView *)statusBarBackgroundView
{
    return _viewControllerStatusBarBackgroundView;
}

- (void)setStatusBarBackgroundAlpha:(float)alpha
{
    _viewControllerStatusBarBackgroundView.alpha = alpha;
}

#pragma mark -

- (UIView *)selectActiveInputView
{
    return nil;
}

@end
