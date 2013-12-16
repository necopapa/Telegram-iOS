/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <UIKit/UIKit.h>

@class TGNavigationController;

@interface TGNavigationBar : UINavigationBar

@property (nonatomic, weak) TGNavigationController *navigationController;

+ (void)setDefaultNavigationBarBackground:(UIImage *)portraitImage landscapeImage:(UIImage *)landscapeImage;
+ (void)setBlackOpaqueNavigationBarBackground:(UIImage *)portraitImage landscapeImage:(UIImage *)landscapeImage;

@property (nonatomic, strong) UIImage *defaultPortraitImage;
@property (nonatomic, strong) UIImage *defaultLandscapeImage;

@property (nonatomic, strong) UIView *progressView;

- (void)setBarStyle:(UIBarStyle)barStyle animated:(bool)animated;
- (void)resetBarStyle;

- (void)setShadowMode:(bool)dark;

- (void)updateBackground;

- (void)setHiddenState:(bool)hidden animated:(bool)animated;

@end
