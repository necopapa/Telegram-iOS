#import "TGNavigationController.h"

#import "TGNavigationBar.h"
#import "TGViewController.h"
#import "TGToolbarButton.h"

#import <QuartzCore/QuartzCore.h>

@interface TGNavigationController () <UINavigationControllerDelegate>

@property (nonatomic) bool wasShowingNavigationBar;

@property (nonatomic, strong) TGAutorotationLock *autorotationLock;

@end

@implementation TGNavigationController

+ (TGNavigationController *)navigationControllerWithRootController:(UIViewController *)controller
{
    return [TGNavigationController navigationControllerWithRootController:controller blackCorners:true];
}

+ (TGNavigationController *)navigationControllerWithRootController:(UIViewController *)controller blackCorners:(bool)blackCorners
{
    return [self navigationControllerWithControllers:[NSArray arrayWithObject:controller] blackCorners:blackCorners];
}

+ (TGNavigationController *)navigationControllerWithControllers:(NSArray *)controllers
{
    return [self navigationControllerWithControllers:controllers blackCorners:true];
}

+ (TGNavigationController *)navigationControllerWithControllers:(NSArray *)controllers blackCorners:(bool)blackCorners
{
    // Force load TGNavigationBar class
    [TGNavigationBar description];
    
#if TGUseGestureNavigationController
    blackCorners = false;
#endif
    
    TGNavigationController *navigationController = nil;
    
#if TGUseGestureNavigationController
    navigationController = [[TGNavigationController alloc] initWithNibName:nil bundle:nil];
#else
    navigationController = [[[NSBundle mainBundle] loadNibNamed:@"TGNavigationController" owner:[UIApplication sharedApplication].delegate options:nil] objectAtIndex:0];
#endif
    
    [navigationController setViewControllers:controllers];
    
    ((TGNavigationBar *)navigationController.navigationBar).navigationController = navigationController;
    
    UIImage *cornersImage = [UIImage imageNamed:@"BlackCornersBottom.png"];
    UIImageView *bottomCorners = [[UIImageView alloc] initWithImage:[cornersImage stretchableImageWithLeftCapWidth:(int)(cornersImage.size.width / 2) topCapHeight:0]];
    bottomCorners.frame = CGRectMake(0, navigationController.view.frame.size.height - cornersImage.size.height, navigationController.view.frame.size.width, cornersImage.size.height);
    bottomCorners.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [navigationController.view addSubview:bottomCorners];
    
    if (blackCorners)
    {
        UIView *blackView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 50)];
        blackView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        blackView.backgroundColor = [UIColor blackColor];
        blackView.layer.zPosition = -10;
        [navigationController.view insertSubview:blackView atIndex:0];
    }
    
    return navigationController;
}

- (void)dealloc
{
    self.delegate = nil;
    
    [self doUnloadView];
}

- (void)viewDidLoad
{   
    self.delegate = self;
    
    if (_backgroundView != nil)
    {
        _backgroundView.frame = self.view.bounds;
        [self.view insertSubview:_backgroundView atIndex:0];
    }
    
    [super viewDidLoad];
}

- (void)viewDidUnload
{
    [self doUnloadView];
    
    if (_backgroundView != nil)
        [_backgroundView removeFromSuperview];
    
    [super viewDidUnload];
}

- (void)doUnloadView
{
}

- (void)setBackgroundView:(UIView *)backgroundView
{
    if (_backgroundView != nil)
    {
        [_backgroundView removeFromSuperview];
        _backgroundView = nil;
    }
    
    _backgroundView = backgroundView;
    
    if (_backgroundView != nil)
    {
        _backgroundView.frame = self.view.bounds;
        [self.view insertSubview:_backgroundView atIndex:0];
    }
}

- (void)updateControllerLayout:(bool)__unused animated
{
    /*UIBarStyle barStyle = UIBarStyleDefault;
     bool navigationBarShouldBeHidden = false;
     UIStatusBarStyle statusBarStyle = UIStatusBarStyleBlackOpaque;
     bool statusBarShouldBeHidden = false;
     if ([self.topViewController conformsToProtocol:@protocol(TGViewControllerNavigationBarAppearance)])
     {
     id<TGViewControllerNavigationBarAppearance> appearance = (id<TGViewControllerNavigationBarAppearance>)self.topViewController;
     barStyle = [appearance requiredNavigationBarStyle];
     navigationBarShouldBeHidden = [appearance navigationBarShouldBeHidden];
     if ([appearance respondsToSelector:@selector(viewControllerPreferredStatusBarStyle)])
     statusBarStyle = [appearance viewControllerPreferredStatusBarStyle];
     if ([appearance respondsToSelector:@selector(statusBarShouldBeHidden)])
     statusBarShouldBeHidden = [appearance statusBarShouldBeHidden];
     }
     
     if ([self.navigationBar barStyle] != barStyle)
     [(TGNavigationBar *)self.navigationBar setBarStyle:barStyle animated:(_wasShowingNavigationBar == !self.navigationBarHidden)];
     if ([[UIApplication sharedApplication] isStatusBarHidden] != statusBarShouldBeHidden)
     [[UIApplication sharedApplication] setStatusBarHidden:statusBarShouldBeHidden withAnimation:animated ? UIStatusBarAnimationFade : UIStatusBarAnimationNone];
     if ([[UIApplication sharedApplication] statusBarStyle] != statusBarStyle)
     [[UIApplication sharedApplication] setStatusBarStyle:statusBarStyle animated:animated];*/
    
    //[self setNavigationBarHidden:!self.navigationBarHidden animated:false];
    //[self setNavigationBarHidden:!self.navigationBarHidden animated:false];
}

- (void)setupNavigationBarForController:(UIViewController *)viewController animated:(bool)animated
{
    UIBarStyle barStyle = UIBarStyleDefault;
    bool navigationBarShouldBeHidden = false;
    UIStatusBarStyle statusBarStyle = UIStatusBarStyleBlackOpaque;
    bool statusBarShouldBeHidden = false;
    
    if ([viewController conformsToProtocol:@protocol(TGViewControllerNavigationBarAppearance)])
    {
        id<TGViewControllerNavigationBarAppearance> appearance = (id<TGViewControllerNavigationBarAppearance>)viewController;
        
        barStyle = [appearance requiredNavigationBarStyle];
        navigationBarShouldBeHidden = [appearance navigationBarShouldBeHidden];
        if ([appearance respondsToSelector:@selector(viewControllerPreferredStatusBarStyle)])
            statusBarStyle = [appearance viewControllerPreferredStatusBarStyle];
        if ([appearance respondsToSelector:@selector(statusBarShouldBeHidden)])
            statusBarShouldBeHidden = [appearance statusBarShouldBeHidden];
    }
    
    if (navigationBarShouldBeHidden != self.navigationBarHidden)
    {
        [self setNavigationBarHidden:navigationBarShouldBeHidden animated:animated];
    }
    
    if ([self.navigationBar barStyle] != barStyle)
        [(TGNavigationBar *)self.navigationBar setBarStyle:barStyle animated:(_wasShowingNavigationBar == !self.navigationBarHidden)];
    if ([[UIApplication sharedApplication] isStatusBarHidden] != statusBarShouldBeHidden)
        [[UIApplication sharedApplication] setStatusBarHidden:statusBarShouldBeHidden withAnimation:animated ? UIStatusBarAnimationFade : UIStatusBarAnimationNone];
    if ([[UIApplication sharedApplication] statusBarStyle] != statusBarStyle)
        [[UIApplication sharedApplication] setStatusBarStyle:statusBarStyle animated:animated];
}

#if !TGUseGestureNavigationController

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if (_restrictLandscape)
        return interfaceOrientation == UIInterfaceOrientationPortrait;
    
    if (self.topViewController != nil)
        return [self.topViewController shouldAutorotateToInterfaceOrientation:interfaceOrientation];
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

- (BOOL)shouldAutorotate
{
    if (_restrictLandscape)
        return false;
    
    if (self.topViewController != nil)
    {
        if ([self.topViewController respondsToSelector:@selector(shouldAutorotate)])
            return [self.topViewController shouldAutorotate];
    }
    return true;
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

- (NSUInteger)supportedInterfaceOrientations
{
    if (_restrictLandscape)
        return UIInterfaceOrientationMaskPortrait;
    
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
}

- (void)setNavigationBarHidden:(BOOL)hidden animated:(BOOL)animated
{
    if (!hidden)
        self.navigationBar.alpha = 1.0f;
    
    [(TGNavigationBar *)self.navigationBar setHiddenState:hidden animated:animated];
    
    bool resetStyle = self.navigationBarHidden != hidden;
    [super setNavigationBarHidden:hidden animated:animated];
    
    if (resetStyle)
        [(TGNavigationBar *)self.navigationBar resetBarStyle];
}

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    _wasShowingNavigationBar = !self.navigationBarHidden;
    
    UIBarStyle barStyle = UIBarStyleDefault;
    bool navigationBarShouldBeHidden = false;
    UIStatusBarStyle statusBarStyle = UIStatusBarStyleBlackOpaque;
    bool statusBarShouldBeHidden = false;
    if ([viewController conformsToProtocol:@protocol(TGViewControllerNavigationBarAppearance)])
    {
        id<TGViewControllerNavigationBarAppearance> appearance = (id<TGViewControllerNavigationBarAppearance>)viewController;
        barStyle = [appearance requiredNavigationBarStyle];
        navigationBarShouldBeHidden = [appearance navigationBarShouldBeHidden];
        if ([appearance respondsToSelector:@selector(viewControllerPreferredStatusBarStyle)])
            statusBarStyle = [appearance viewControllerPreferredStatusBarStyle];
        if ([appearance respondsToSelector:@selector(statusBarShouldBeHidden)])
            statusBarShouldBeHidden = [appearance statusBarShouldBeHidden];
    }
    
    UIViewController *currentController = self.topViewController;
    
    [super pushViewController:viewController animated:animated];
    
    if (_wasShowingNavigationBar == !navigationBarShouldBeHidden)
    {
        int currentWidth = (int)[TGViewController screenSizeForInterfaceOrientation:self.interfaceOrientation].width;
        float titleViewWidth = 0;
        
        if (currentController != nil)
        {
            if (currentController.navigationItem.titleView != nil)
            {
                titleViewWidth = currentController.navigationItem.titleView.frame.size.width;
            }
            
            if (currentController.navigationItem.leftBarButtonItem != nil)
            {
                UIView *view = currentController.navigationItem.leftBarButtonItem.customView;
                if ([view conformsToProtocol:@protocol(TGBarItemSemantics)] && [(id<TGBarItemSemantics>)view backSemantics])
                {
                    view.transform = CGAffineTransformIdentity;
                    [UIView animateWithDuration:0.4 animations:^
                    {
                        view.transform = CGAffineTransformMakeTranslation(-view.frame.size.width * 2, 0);
                    } completion:^(__unused BOOL finished)
                    {
                        view.transform = CGAffineTransformIdentity;
                    }];
                }
            }
        }
        
        if (viewController.navigationItem.leftBarButtonItem != nil)
        {
            UIView *customView = viewController.navigationItem.leftBarButtonItem.customView;
            if ([customView conformsToProtocol:@protocol(TGBarItemSemantics)] && [(id<TGBarItemSemantics>)customView backSemantics])
            {
                customView.transform = CGAffineTransformMakeTranslation((int)(currentWidth / 2 - titleViewWidth / 2 - customView.frame.size.width / 2), 0);
                
                [UIView animateWithDuration:0.35 animations:^
                {
                    customView.transform = CGAffineTransformIdentity;
                }];
            }
        }
    }
    
    if ([self.navigationBar barStyle] != barStyle)
        [(TGNavigationBar *)self.navigationBar setBarStyle:barStyle animated:(_wasShowingNavigationBar == !self.navigationBarHidden)];
    if ([[UIApplication sharedApplication] isStatusBarHidden] != statusBarShouldBeHidden)
        [[UIApplication sharedApplication] setStatusBarHidden:statusBarShouldBeHidden withAnimation:animated ? UIStatusBarAnimationFade : UIStatusBarAnimationNone];
    if ([[UIApplication sharedApplication] statusBarStyle] != statusBarStyle)
        [[UIApplication sharedApplication] setStatusBarStyle:statusBarStyle animated:animated];
    
    if (_backgroundView != nil)
    {
        UIView *patternView = [_backgroundView viewWithTag:((int)0xF7E5C50E)];
        UIView *patternTransitionView = [_backgroundView viewWithTag:((int)0x7A461D42)];
        if (patternView != nil && patternTransitionView != nil)
        {
            patternView.frame = CGRectMake(0, 0, patternView.superview.frame.size.width, patternView.superview.frame.size.height);
            patternTransitionView.frame = CGRectMake(patternTransitionView.superview.frame.size.width, 0, patternTransitionView.superview.frame.size.width, patternTransitionView.superview.frame.size.height);
            patternTransitionView.hidden = false;
            
            [UIView animateWithDuration:0.35 animations:^
            {
                patternView.frame = CGRectMake(-patternView.superview.frame.size.width, 0, patternView.superview.frame.size.width, patternView.superview.frame.size.height);
                patternTransitionView.frame = CGRectMake(0, 0, patternTransitionView.superview.frame.size.width, patternTransitionView.superview.frame.size.height);
            } completion:^(BOOL finished)
            {
                if (finished)
                {
                    patternView.frame = CGRectMake(0, 0, patternView.superview.frame.size.width, patternView.superview.frame.size.height);
                    patternTransitionView.hidden = true;
                }
            }];
        }
    }
}

- (void)performPopTransition:(UIViewController *)__unused previousController lastController:(UIViewController *)lastController barStyle:(UIBarStyle)barStyle navigationBarShouldBeHidden:(bool)navigationBarShouldBeHidden animated:(bool)animated
{
    if (navigationBarShouldBeHidden != self.navigationBarHidden)
    {
        [self setNavigationBarHidden:navigationBarShouldBeHidden animated:false];
    }
    
    if (_wasShowingNavigationBar == !navigationBarShouldBeHidden)
    {
        int currentWidth = (int)([TGViewController screenSizeForInterfaceOrientation:[[UIApplication sharedApplication] statusBarOrientation]].width);
        
        UIViewController *viewController = self.topViewController;
        
        if (animated)
        {
            if (lastController != nil)
            {
                if (lastController.navigationItem.leftBarButtonItem != nil)
                {
                    int targetX = (int)(currentWidth / 4);
                    
                    UIView *view = lastController.navigationItem.leftBarButtonItem.customView;
                    if ([view conformsToProtocol:@protocol(TGBarItemSemantics)] && [(id<TGBarItemSemantics>)view backSemantics])
                    {
                        if (viewController.navigationItem != nil && viewController.navigationItem.titleView != nil)
                        {
                            targetX = (int)(-view.frame.origin.x + viewController.navigationItem.titleView.frame.origin.x + (viewController.navigationItem.titleView.frame.size.width - view.frame.size.width) / 2);
                        }
                        
                        [UIView animateWithDuration:0.355 animations:^
                        {
                            view.transform = CGAffineTransformMakeTranslation(targetX, 0);
                        } completion:^(__unused BOOL finished)
                        {
                            view.transform = CGAffineTransformIdentity;
                        }];
                    }
                }
            }
            
            if (viewController.navigationItem.leftBarButtonItem != nil)
            {
                UIView *titleView = viewController.navigationItem.titleView;
                [titleView.layer removeAllAnimations];
                titleView.alpha = 0.0;
                titleView.transform = CGAffineTransformMakeTranslation((int)(-currentWidth / 2 - 0 * titleView.frame.size.width / 2), 0);
                [UIView animateWithDuration:0.355 animations:^
                {
                    titleView.alpha = 1.0;
                    titleView.transform = CGAffineTransformIdentity;
                } completion:nil];
                
                UIView *view = viewController.navigationItem.leftBarButtonItem.customView;
                if ([view conformsToProtocol:@protocol(TGBarItemSemantics)] && [(id<TGBarItemSemantics>)view backSemantics])
                {
                    view.transform = CGAffineTransformMakeTranslation(-view.frame.size.width*2, 0);
                    
                    [UIView animateWithDuration:0.355 animations:^
                    {
                        view.transform = CGAffineTransformIdentity;
                    } completion:^(__unused BOOL finished)
                    {
                        view.transform = CGAffineTransformIdentity;
                    }];
                }
            }
        }
    }
    
    if ([self.navigationBar barStyle] != barStyle)
        [(TGNavigationBar *)self.navigationBar setBarStyle:barStyle animated:animated];
    
    if (_backgroundView != nil)
    {
        UIView *patternView = [_backgroundView viewWithTag:((int)0xF7E5C50E)];
        UIView *patternTransitionView = [_backgroundView viewWithTag:((int)0x7A461D42)];
        if (patternView != nil && patternTransitionView != nil)
        {
            patternView.frame = CGRectMake(0, 0, patternView.superview.frame.size.width, patternView.superview.frame.size.height);
            patternTransitionView.frame = CGRectMake(-patternTransitionView.superview.frame.size.width, 0, patternTransitionView.superview.frame.size.width, patternTransitionView.superview.frame.size.height);
            patternTransitionView.hidden = false;
            
            [UIView animateWithDuration:0.35 animations:^
            {
                patternView.frame = CGRectMake(patternView.superview.frame.size.width, 0, patternView.superview.frame.size.width, patternView.superview.frame.size.height);
                patternTransitionView.frame = CGRectMake(0, 0, patternTransitionView.superview.frame.size.width, patternTransitionView.superview.frame.size.height);
            } completion:^(BOOL finished)
            {
                if (finished)
                {
                    patternView.frame = CGRectMake(0, 0, patternView.superview.frame.size.width, patternView.superview.frame.size.height);
                    patternTransitionView.hidden = true;
                }
            }];
        }
    }
}

- (UIViewController *)popViewControllerAnimated:(BOOL)animated
{
    _wasShowingNavigationBar = !self.navigationBarHidden;
    
    UIViewController *previousController = self.viewControllers.count < 2 ? nil : [self.viewControllers objectAtIndex:(self.viewControllers.count - 2)];
    
    UIBarStyle barStyle = UIBarStyleDefault;
    bool navigationBarShouldBeHidden = false;
    if ([previousController conformsToProtocol:@protocol(TGViewControllerNavigationBarAppearance)])
    {
        barStyle = [(id<TGViewControllerNavigationBarAppearance>)previousController requiredNavigationBarStyle];
        navigationBarShouldBeHidden = [(id<TGViewControllerNavigationBarAppearance>)previousController navigationBarShouldBeHidden];
    }
    
    if (self.viewControllers.count != 0)
    {
        if ([[self.viewControllers lastObject] conformsToProtocol:@protocol(TGDestructableViewController)])
        {
            [(id<TGDestructableViewController>)[self.viewControllers lastObject] cleanupBeforeDestruction];
        }
    }
    
    UIViewController *lastController = [super popViewControllerAnimated:animated];
    
    if ([lastController conformsToProtocol:@protocol(TGDestructableViewController)])
        [(id<TGDestructableViewController>)lastController cleanupAfterDestruction];
    
    [self performPopTransition:previousController lastController:lastController barStyle:barStyle navigationBarShouldBeHidden:self.navigationBarHidden animated:animated];
    
    return lastController;
}

- (NSArray *)popToViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    _wasShowingNavigationBar = !self.navigationBarHidden;
    
    UIViewController *previousController = viewController;
    
    UIBarStyle barStyle = UIBarStyleDefault;
    bool navigationBarShouldBeHidden = false;
    if ([previousController conformsToProtocol:@protocol(TGViewControllerNavigationBarAppearance)])
    {
        barStyle = [(id<TGViewControllerNavigationBarAppearance>)previousController requiredNavigationBarStyle];
        navigationBarShouldBeHidden = [(id<TGViewControllerNavigationBarAppearance>)previousController navigationBarShouldBeHidden];
    }
    
    for (UIViewController *controller in self.viewControllers.reverseObjectEnumerator)
    {
        if (controller == viewController)
            break;
        
        if ([controller conformsToProtocol:@protocol(TGDestructableViewController)])
            [(id<TGDestructableViewController>)controller cleanupBeforeDestruction];
    }
    
    NSArray *lastControllers = [super popToViewController:viewController animated:animated];
    
    for (UIViewController *controller in lastControllers)
    {
        if ([controller conformsToProtocol:@protocol(TGDestructableViewController)])
            [(id<TGDestructableViewController>)controller cleanupAfterDestruction];
    }
    
    UIViewController *lastController = lastControllers.count != 0 ? lastControllers.lastObject : nil;
    
    [self performPopTransition:previousController lastController:lastController barStyle:barStyle navigationBarShouldBeHidden:navigationBarShouldBeHidden animated:animated];
    
    return lastControllers;
}

- (NSArray *)popToRootViewControllerAnimated:(BOOL)animated
{
    if (self.viewControllers.count != 0)
        return [self popToViewController:[self.viewControllers objectAtIndex:0] animated:animated];
    else
        return [super popToRootViewControllerAnimated:animated];
}

- (void)navigationController:(UINavigationController *)__unused navigationController willShowViewController:(UIViewController *)__unused viewController animated:(BOOL)__unused animated
{
}

- (void)navigationController:(UINavigationController *)__unused navigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)__unused animated
{
    NSMutableArray *newControllers = nil;
    
    for (UINavigationController *controller in self.viewControllers)
    {
        if (controller == self.topViewController)
            continue;
        
        if ([[controller class] conformsToProtocol:@protocol(TGNavigationControllerItem)])
        {
            bool value = [(id<TGNavigationControllerItem>)controller shouldBeRemovedFromNavigationAfterHiding];
            if (value)
            {
                if (newControllers == nil)
                    newControllers = [[NSMutableArray alloc] initWithArray:self.viewControllers];
                [newControllers removeObject:controller];
            }
        }
    }
    
    if (newControllers != nil)
        [self setViewControllers:newControllers animated:false];
    
    if ([viewController conformsToProtocol:@protocol(TGNavigationControllerItem)] && [(id<TGNavigationControllerItem>)viewController respondsToSelector:@selector(shouldRemoveAllPreviousControllers)] && [(id<TGNavigationControllerItem>)viewController shouldRemoveAllPreviousControllers])
    {
        if (self.viewControllers.count > 2)
        {
            NSMutableArray *finalViewControllers = [[NSMutableArray alloc] init];
            [finalViewControllers addObject:[self.viewControllers objectAtIndex:0]];
            [finalViewControllers addObject:[self.viewControllers lastObject]];
            
            NSMutableArray *removedViewControllers = [[NSMutableArray alloc] init];
            
            for (int i = 1; i < self.viewControllers.count - 1; i++)
            {
                UIViewController *removedController = [self.viewControllers objectAtIndex:i];
                [removedViewControllers addObject:removedController];
                if ([removedController conformsToProtocol:@protocol(TGDestructableViewController)])
                    [(id<TGDestructableViewController>)removedController cleanupBeforeDestruction];
            }
            
            [self setViewControllers:finalViewControllers animated:false];
            
            for (UIViewController *controller in removedViewControllers)
            {
                if ([controller conformsToProtocol:@protocol(TGDestructableViewController)])
                    [(id<TGDestructableViewController>)controller cleanupAfterDestruction];
            }
        }
    }
    
    //TGDumpViews(self.view.window, @"");
}

#endif

@end
