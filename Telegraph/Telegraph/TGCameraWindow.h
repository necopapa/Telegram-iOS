/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#if TG_USE_CUSTOM_CAMERA

#import <UIKit/UIKit.h>

#import "TGCameraController.h"

#import "ASWatcher.h"

@interface TGCameraWindow : UIWindow <ASWatcher>

@property (nonatomic, strong) ASHandle *actionHandle;
@property (nonatomic, strong) ASHandle *watcherHandle;

@property (nonatomic, strong) TGCameraController *cameraController;

- (void)show;
- (void)dismiss;
- (void)dismissToRect:(CGRect)toRectInWindowSpace fromImage:(UIImage *)fromImage toImage:(UIImage *)toImage toView:(UIView *)toView aboveView:(UIView *)aboveView interfaceOrientation:(UIInterfaceOrientation)interfaceOrientation;

@end

#endif