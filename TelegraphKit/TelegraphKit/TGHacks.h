/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <UIKit/UIKit.h>

typedef void (^TGAlertHandler)(UIAlertView *alertView);

typedef enum {
    TGStatusBarAppearanceAnimationSlideDown = 1,
    TGStatusBarAppearanceAnimationSlideUp = 2
} TGStatusBarAppearanceAnimation;

@interface TGHacks : NSObject

+ (void)hackSetAnimationDuration;
+ (void)setAnimationDurationFactor:(float)factor;
+ (void)setSecondaryAnimationDurationFactor:(float)factor;

+ (void)hackDrawPlaceholderInRect;
+ (void)setTextFieldPlaceholderColor:(UITextField *)textField color:(UIColor *)color;
+ (void)setTextFieldPlaceholderFont:(UITextField *)textField font:(UIFont *)font;
+ (void)setTextFieldClearOffset:(UITextField *)textField offset:(float)offset;

+ (void)setLayoutDelegateForContainerView:(id)view layoutDelegate:(id)layoutDelegate;

+ (void)setWebScrollViewContentInsetEnabled:(UIScrollView *)scrollView enabled:(bool)enabled;

+ (void)overrideApplicationStatusBarSetStyle:(id)delegate;
+ (void)setApplicationStatusBarAlpha:(float)alpha;
+ (void)animateApplicationStatusBarAppearance:(TGStatusBarAppearanceAnimation)statusBarAnimation duration:(NSTimeInterval)duration completion:(void (^)())completion;
+ (float)statusBarHeightForOrientation:(UIInterfaceOrientation)orientation;

+ (bool)isKeyboardVisible;
+ (float)keyboardHeightForOrientation:(UIInterfaceOrientation)orientation;

@end

#ifdef __cplusplus
extern "C" {
#endif

float TGAnimationSpeedFactor();

#ifdef __cplusplus
}
#endif
