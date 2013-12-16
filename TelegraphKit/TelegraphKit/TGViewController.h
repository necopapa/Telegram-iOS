/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <UIKit/UIKit.h>

typedef enum {
    TGViewControllerStyleDefault = 0,
    TGViewControllerStyleBlack = 1
} TGViewControllerStyle;

@class TGLabel;
@class TGNavigationController;

typedef enum {
    TGViewControllerNavigationBarAnimationNone = 0,
    TGViewControllerNavigationBarAnimationSlide = 1,
    TGViewControllerNavigationBarAnimationFade = 2,
    TGViewControllerNavigationBarAnimationSlideFar = 3
} TGViewControllerNavigationBarAnimation;

@protocol TGViewControllerNavigationBarAppearance <NSObject>

- (UIBarStyle)requiredNavigationBarStyle;
- (bool)navigationBarShouldBeHidden;

@optional

- (bool)navigationBarHasAction;
- (void)navigationBarAction;
- (void)navigationBarSwipeDownAction;

@optional

- (bool)statusBarShouldBeHidden;
- (UIStatusBarStyle)viewControllerPreferredStatusBarStyle;

@end

@interface TGViewController : UIViewController <TGViewControllerNavigationBarAppearance>

+ (UIFont *)titleFontForStyle:(TGViewControllerStyle)style landscape:(bool)landscape;
+ (UIFont *)titleTitleFontForStyle:(TGViewControllerStyle)style landscape:(bool)landscape;
+ (UIFont *)titleSubtitleFontForStyle:(TGViewControllerStyle)style landscape:(bool)landscape;
+ (UIColor *)titleTextColorForStyle:(TGViewControllerStyle)style;
+ (UIColor *)titleShadowColorForStyle:(TGViewControllerStyle)style;
+ (CGSize)titleShadowOffsetForStyle:(TGViewControllerStyle)style;

+ (CGSize)screenSize:(UIDeviceOrientation)orientation;
+ (CGSize)screenSizeForInterfaceOrientation:(UIInterfaceOrientation)orientation;
+ (bool)isWidescreen;

+ (void)disableAutorotation;
+ (void)enableAutorotation;
+ (void)disableAutorotationFor:(NSTimeInterval)timeInterval;
+ (void)disableAutorotationFor:(NSTimeInterval)timeInterval reentrant:(bool)reentrant;
+ (bool)autorotationAllowed;
+ (void)attemptAutorotation;

+ (void)disableUserInteractionFor:(NSTimeInterval)timeInterval;

@property (nonatomic) TGViewControllerStyle style;

@property (nonatomic, strong) NSString *titleText;
@property (nonatomic, strong) NSString *subtitleText;
@property (nonatomic, strong) UIFont *titleTextFontPortrait;
@property (nonatomic, strong) UIFont *titleTextFontLandscape;
@property (nonatomic) SEL backAction;

@property (nonatomic, readonly) float controllerStatusBarHeight;
@property (nonatomic, readonly) UIEdgeInsets controllerCleanInset;
@property (nonatomic, readonly) UIEdgeInsets controllerInset;
@property (nonatomic, readonly) UIEdgeInsets controllerScrollInset;
@property (nonatomic) UIEdgeInsets parentInsets;
@property (nonatomic) UIEdgeInsets explicitTableInset;
@property (nonatomic) UIEdgeInsets explicitScrollIndicatorInset;

@property (nonatomic) bool navigationBarShouldBeHidden;

@property (nonatomic) bool autoManageStatusBarBackground;
@property (nonatomic) bool automaticallyManageScrollViewInsets;
@property (nonatomic) bool ignoreKeyboardWhenAdjustingScrollViewInsets;

@property (nonatomic, strong) NSArray *scrollViewsForAutomaticInsetsAdjustment;

@property (nonatomic, strong) TGLabel *titleLabel;

@property (nonatomic, weak) UIViewController *customParentViewController;

@property (nonatomic, strong) TGNavigationController *customNavigationController;

- (void)setExplicitTableInset:(UIEdgeInsets)explicitTableInset scrollIndicatorInset:(UIEdgeInsets)scrollIndicatorInset;

- (void)setBackAction:(SEL)backAction animated:(bool)animated;

- (void)adjustToInterfaceOrientation:(UIInterfaceOrientation)orientation;

- (void)setBackAction:(SEL)backAction imageNormal:(UIImage *)imageNormal imageNormalHighlighted:(UIImage *)imageNormalHighlighted imageLadscape:(UIImage *)imageLandscape imageLandscapeHighlighted:(UIImage *)imageLandscapeHighlighted textColor:(UIColor *)textColor shadowColor:(UIColor *)shadowColor;

- (void)fadeInTitleText;

- (bool)_updateControllerInset:(bool)force;
- (bool)_updateControllerInsetForOrientation:(UIInterfaceOrientation)orientation force:(bool)force notify:(bool)notify;
- (void)controllerInsetUpdated:(UIEdgeInsets)previousInset;

- (void)setNavigationBarHidden:(bool)navigationBarHidden animated:(BOOL)animated;
- (void)setNavigationBarHidden:(bool)navigationBarHidden withAnimation:(TGViewControllerNavigationBarAnimation)animation;
- (void)setNavigationBarHidden:(bool)navigationBarHidden withAnimation:(TGViewControllerNavigationBarAnimation)animation duration:(NSTimeInterval)duration;
- (float)statusBarBackgroundAlpha;

- (UIView *)statusBarBackgroundView;
- (void)setStatusBarBackgroundAlpha:(float)alpha;

- (UIView *)selectActiveInputView;

- (void)acquireRotationLock;
- (void)releaseRotationLock;

@end

@protocol TGDestructableViewController <NSObject>

- (void)cleanupBeforeDestruction;
- (void)cleanupAfterDestruction;

@optional

- (void)contentControllerWillBeDismissed;

@end

@interface TGAutorotationLock : NSObject

@property (nonatomic) int lockId;

@end

