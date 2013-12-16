/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <UIKit/UIKit.h>

#import "ActionStage.h"

@interface TGNotificationWindow : UIWindow

@property (nonatomic, readonly) bool isDismissed;

@property (nonatomic) float windowHeight;

@property (nonatomic, strong) ASHandle *watcher;
@property (nonatomic, strong) NSString *watcherAction;
@property (nonatomic, strong) NSDictionary *watcherOptions;

- (void)adjustToInterfaceOrientation:(UIInterfaceOrientation)orientation;

- (void)setContentView:(UIView *)view;
- (UIView *)contentView;

- (void)animateIn;
- (void)animateOut;
- (void)performTapAction;

@end
