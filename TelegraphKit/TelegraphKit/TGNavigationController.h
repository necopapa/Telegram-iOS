/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <UIKit/UIKit.h>

#import "TGGestureNavigationController.h"

#define TGUseGestureNavigationController false

@interface TGNavigationController :
#if TGUseGestureNavigationController
    TGGestureNavigationController
#else
    UINavigationController
#endif

@property (nonatomic, strong) UIView *cornersImageView;
@property (nonatomic, strong) UIView *backgroundView;

@property (nonatomic) bool restrictLandscape;

+ (TGNavigationController *)navigationControllerWithControllers:(NSArray *)controllers;
+ (TGNavigationController *)navigationControllerWithRootController:(UIViewController *)controller;
+ (TGNavigationController *)navigationControllerWithRootController:(UIViewController *)controller blackCorners:(bool)blackCorners;

- (void)setupNavigationBarForController:(UIViewController *)viewController animated:(bool)animated;

- (void)updateControllerLayout:(bool)animated;

- (void)acquireRotationLock;
- (void)releaseRotationLock;

@end

@protocol TGNavigationControllerItem <NSObject>

@required

- (bool)shouldBeRemovedFromNavigationAfterHiding;

@optional

- (bool)shouldRemoveAllPreviousControllers;

@end

@protocol TGBarItemSemantics <NSObject>

- (bool)backSemantics;

@optional

- (float)barButtonsOffset;

@end
