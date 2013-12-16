#import "TGApplication.h"

#import "TGAppDelegate.h"
#import "TGWebController.h"
#import "TGViewController.h"

#import "TGHacks.h"

@interface TGApplication ()

@end

@implementation TGApplication

- (BOOL)openURL:(NSURL *)url forceNative:(BOOL)forceNative
{
    NSString *absoluteString = [url.absoluteString lowercaseString];
    if ([absoluteString hasPrefix:@"tel:"] || [absoluteString hasPrefix:@"facetime:"])
    {
        [TGAppDelegateInstance performPhoneCall:url];
        
        return true;
    }
    
    bool useNative = forceNative;
    if (![absoluteString hasPrefix:@"http://"] && ![absoluteString hasPrefix:@"https://"])
        useNative = true;
    
    if (useNative)
        return [super openURL:url];
    
    if ([self.delegate isKindOfClass:[TGAppDelegate class]])
    {
        TGWebController *webController = [[TGWebController alloc] initWithUrl:[url absoluteString]];
        [TGAppDelegateInstance.mainNavigationController pushViewController:webController animated:true];
        return true;
    }
    
    return false;
}

- (BOOL)openURL:(NSURL *)url
{
    return [self openURL:url forceNative:false];
}

- (void)setStatusBarStyle:(UIStatusBarStyle)statusBarStyle
{
    [self setStatusBarStyle:statusBarStyle animated:false];
}

- (void)setStatusBarStyle:(UIStatusBarStyle)__unused statusBarStyle animated:(BOOL)__unused animated
{
}

- (void)setStatusBarHidden:(BOOL)statusBarHidden
{
    [self setStatusBarHidden:statusBarHidden withAnimation:UIStatusBarAnimationNone];
}

- (void)setStatusBarHidden:(BOOL)hidden withAnimation:(UIStatusBarAnimation)animation
{
    if (_processStatusBarHiddenRequests)
    {   
        [self forceSetStatusBarHidden:hidden withAnimation:animation];
    }
}

- (void)forceSetStatusBarStyle:(UIStatusBarStyle)statusBarStyle animated:(BOOL)animated
{
    [super setStatusBarStyle:statusBarStyle animated:animated];
}

- (void)forceSetStatusBarHidden:(BOOL)hidden withAnimation:(UIStatusBarAnimation)animation
{
    [super setStatusBarHidden:hidden withAnimation:animation];
}

@end
