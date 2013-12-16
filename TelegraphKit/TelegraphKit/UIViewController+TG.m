#import "UIViewController+TG.h"

#import <objc/runtime.h>

#import "TGNavigationController.h"

#import "TGViewController.h"

static const char *customNavigationControllerKey = "_customNavigationController";

@implementation UIViewController (TG)

- (void)TG_setNavigationController:(UINavigationController *)navigationController
{
    if ([self respondsToSelector:@selector(setCustomNavigationController:)])
        [(TGViewController *)self setCustomNavigationController:(TGNavigationController *)navigationController];
    else
        objc_setAssociatedObject(self, customNavigationControllerKey, navigationController, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UINavigationController *)TG_navigationController
{
    id result = nil;
    
    if ([self respondsToSelector:@selector(customNavigationController)])
        result = [(TGViewController *)self customNavigationController];
    else
        result = objc_getAssociatedObject(self, customNavigationControllerKey);
    
    if (result == nil)
        result = [self.parentViewController navigationController];
    
    if (result == nil)
        result = [self TG_navigationController];
    
    return result;
}

@end
