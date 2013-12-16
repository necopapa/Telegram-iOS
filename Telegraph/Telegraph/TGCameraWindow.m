#if TG_USE_CUSTOM_CAMERA

#import "TGCameraWindow.h"

#import "TGHacks.h"

#import "TGAppDelegate.h"

@interface TGCameraWindow ()

@end

@implementation TGCameraWindow

@synthesize actionHandle = _actionHandle;
@synthesize watcherHandle = _watcherHandle;

@synthesize cameraController = _cameraController;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        [self commonInit];
    }
    return self;
}

- (void)commonInit
{
    _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:true];
    
    self.backgroundColor = [UIColor clearColor];
    self.opaque = false;
    
    self.windowLevel = UIWindowLevelStatusBar + 1;
    
    _cameraController = [[TGCameraController alloc] init];
    _cameraController.watcherHandle = _actionHandle;
    
    self.rootViewController = _cameraController;
}

- (void)dealloc
{
    [_actionHandle reset];
}

#pragma mark -

- (void)show
{
    [self makeKeyAndVisible];
    
    self.alpha = 0.0f;
    [UIView animateWithDuration:0.3f animations:^
    {
        self.alpha = 1.0f;
    } completion:^(BOOL finished)
    {
        if (finished)
        {
            self.backgroundColor = [UIColor blackColor];
            self.opaque = true;
        }
    }];
}

- (void)dismiss
{
    [self dismissToRect:CGRectZero fromImage:nil toImage:nil toView:nil aboveView:nil interfaceOrientation:UIInterfaceOrientationPortrait];
}

- (void)dismissToRect:(CGRect)toRectInWindowSpace fromImage:(UIImage *)fromImage toImage:(UIImage *)toImage toView:(UIView *)toView aboveView:(UIView *)aboveView interfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    self.backgroundColor = [UIColor clearColor];
    self.opaque = false;
    
    [_cameraController viewWillDisappear:true];
    
    [_cameraController dismissToRect:toRectInWindowSpace fromImage:fromImage toImage:toImage toView:toView aboveView:aboveView interfaceOrientation:interfaceOrientation];
    
    if (CGSizeEqualToSize(toRectInWindowSpace.size, CGSizeZero))
    {
        [UIView animateWithDuration:0.3f animations:^
        {
            self.alpha = 0.0f;
        } completion:^(__unused BOOL finished)
        {
            self.hidden = true;
            [_cameraController viewDidDisappear:true];
            
            dispatch_async(dispatch_get_main_queue(), ^
            {
                [TGAppDelegateInstance.window makeKeyWindow];
            });
        }];
    }
    else
    {
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^
        {
            self.hidden = true;
            
            dispatch_async(dispatch_get_main_queue(), ^
            {
                [TGAppDelegateInstance.window makeKeyWindow];
            });
        });
    }
}

#pragma mark -

- (void)actionStageActionRequested:(NSString *)action options:(NSDictionary *)options
{
    if ([action isEqualToString:@"dismissCamera"])
    {
        id<ASWatcher> watcher = _watcherHandle.delegate;
        if (watcher != nil && [watcher respondsToSelector:@selector(actionStageActionRequested:options:)])
        {
            [watcher actionStageActionRequested:action options:options];
        }
    }
    else if ([action isEqualToString:@"cameraCompleted"])
    {
        id<ASWatcher> watcher = _watcherHandle.delegate;
        if (watcher != nil && [watcher respondsToSelector:@selector(actionStageActionRequested:options:)])
        {
            [watcher actionStageActionRequested:action options:options];
        }
    }
}

@end

#endif
