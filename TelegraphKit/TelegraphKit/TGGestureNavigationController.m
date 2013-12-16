#import "TGGestureNavigationController.h"

#import "TGNavigationBar.h"
#import "TGViewController.h"

#import "TGNavigationController.h"

#import "UIViewController+TG.h"

#import "TGHacks.h"

#pragma mark -

@interface TGGestureNavigationControllerContainerView : UIView

/*@property (nonatomic, strong) TGNavigationBar *navigationBar;
@property (nonatomic) float statusBarHeight;

@property (nonatomic, strong) UIView *currentView;*/

@end

@implementation TGGestureNavigationControllerContainerView

/*- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];

    _currentView.frame = CGRectMake(0, 0, frame.size.width, frame.size.height);
    
    [self _updateNavigationBarFrame];
}

- (void)_updateNavigationBarFrame
{
    CGRect frame = self.frame;
    
    _navigationBar.frame = CGRectMake(0, _statusBarHeight, frame.size.width, (frame.size.width > 320 + FLT_EPSILON) ? 32 : 44);
}

- (void)setCurrentView:(UIView *)currentView
{
    if (currentView == _currentView)
        return;
    
    [_currentView removeFromSuperview];
    
    _currentView = currentView;
    
    if (_currentView != nil)
        [self insertSubview:_currentView atIndex:0];
}

- (void)insertSubview:(UIView *)view atIndex:(NSInteger)index
{
    [super insertSubview:view atIndex:index];
}

- (void)didAddSubview:(UIView *)subview
{
    TGLog(@"add %@", subview);
    [super didAddSubview:subview];
}

@end


#pragma mark -

@interface TGGestureNavigationController ()

@property (nonatomic, strong) TGGestureNavigationControllerContainerView *containerView;

@property (nonatomic, strong) NSMutableArray *controllerList;
@property (nonatomic, strong) UIView *currentView;

@property (nonatomic) bool disableAccessToNavigationBar;
@property (nonatomic, strong) TGNavigationBar *controllerNavigationBar;

@property (nonatomic) bool isChangingInterfaceOrientation;

@end

@implementation TGGestureNavigationController

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self != nil)
    {
        [self _commonInit];
    }
    return self;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self != nil)
    {
        [self _commonInit];
    }
    return self;
}

- (id)initWithRootViewController:(UIViewController *)rootViewController
{
    self = [super initWithRootViewController:rootViewController];
    if (self != nil)
    {
        [self _commonInit];
    }
    return self;
}

- (void)_commonInit
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(statusBarWillChangeFrame:) name:UIApplicationWillChangeStatusBarFrameNotification object:nil];
    
    _controllerList = [[NSMutableArray alloc] init];
    
    self.wantsFullScreenLayout = true;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)loadView
{
    CGSize screenSize = [TGViewController screenSizeForInterfaceOrientation:self.interfaceOrientation];
    
    _containerView = [[TGGestureNavigationControllerContainerView alloc] initWithFrame:CGRectMake(0, 0, screenSize.width, screenSize.height)];
    
    CGRect statusBarFrame = [[UIApplication sharedApplication] statusBarFrame];
    _containerView.statusBarHeight = MIN(statusBarFrame.size.width, statusBarFrame.size.height);
    
    self.view = _containerView;
    
    [self navigationBar];
    
    _containerView.navigationBar = _controllerNavigationBar;
    [_containerView addSubview:_controllerNavigationBar];
}

- (UINavigationBar *)navigationBar
{
    if (_controllerNavigationBar == nil)
    {
        _controllerNavigationBar = [[TGNavigationBar alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
        _controllerNavigationBar.alpha = 0.7f;
    }
    
    return _disableAccessToNavigationBar ? nil : _controllerNavigationBar;
}

- (UIView *)rotatingHeaderView
{
    return nil;
}

- (NSArray *)viewControllers
{
    return _controllerList;
}

#pragma mark -

- (void)statusBarWillChangeFrame:(NSNotification *)notification
{
    if (!_isChangingInterfaceOrientation)
    {
        [UIView animateWithDuration:0.35 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^
        {
            CGRect statusBarFrame = [[[notification userInfo] objectForKey:UIApplicationStatusBarFrameUserInfoKey] CGRectValue];
            _containerView.statusBarHeight = MIN(statusBarFrame.size.width, statusBarFrame.size.height);
            
            [_containerView _updateNavigationBarFrame];
        } completion:nil];
    }
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return toInterfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
}

- (BOOL)shouldAutorotate
{
    return true;
}

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    _isChangingInterfaceOrientation = true;
    
    CGSize screenSize = [TGViewController screenSizeForInterfaceOrientation:toInterfaceOrientation];
    UIViewController *currentController = _controllerList.count == 0 ? nil : [_controllerList lastObject];
    
    [currentController willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
    
    float statusBarHeight = [TGHacks statusBarHeightForOrientation:toInterfaceOrientation];
    
    [UIView animateWithDuration:duration animations:^
    {
        _containerView.statusBarHeight = statusBarHeight;
        [_containerView setFrame:CGRectMake(0, 0, screenSize.width, screenSize.height)];
        
        [currentController willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    }];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)__unused toInterfaceOrientation duration:(NSTimeInterval)__unused duration
{
    
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    _isChangingInterfaceOrientation = false;
    
    UIViewController *currentController = _controllerList.count == 0 ? nil : [_controllerList lastObject];
    
    [currentController didRotateFromInterfaceOrientation:fromInterfaceOrientation];
}

#pragma mark -

- (void)_prepareViewController:(UIViewController *)viewController atPosition:(CGPoint)atPosition
{
    if (!self.isViewLoaded)
        [self loadView];
    
    CGRect currentFrame = _containerView.frame;
    
    [viewController TG_setNavigationController:self];
    UIView *view = viewController.view;
    view.frame = CGRectMake(atPosition.x, atPosition.y, currentFrame.size.width, currentFrame.size.height);
}

#pragma mark -

- (void)setViewControllers:(NSArray *)viewControllers
{
    [self setViewControllers:viewControllers animated:false];
}

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    if (viewController == nil)
        return;
    
    NSMutableArray *array = [[NSMutableArray alloc] initWithArray:_controllerList];
    [array addObject:viewController];
    [self setViewControllers:array animated:animated];
}

- (UIViewController *)popViewControllerAnimated:(BOOL)animated
{
    if (_controllerList.count < 2)
        return nil;
    
    NSArray *removedControllers = [self popToViewController:[_controllerList objectAtIndex:_controllerList.count - 2] animated:animated];
    if (removedControllers.count != 0)
        return [removedControllers lastObject];
    return nil;
}

- (NSArray *)popToRootViewControllerAnimated:(BOOL)animated
{
    if (_controllerList.count == 0)
        return nil;
    
    return [self popToViewController:[_controllerList objectAtIndex:0] animated:animated];
}

#pragma mark -

- (void)setViewControllers:(NSArray *)viewControllers animated:(BOOL)animated
{
    if (viewControllers == _controllerList)
        return;
    
    NSMutableArray *removedControllers = [[NSMutableArray alloc] init];
    for (UIViewController *controller in _controllerList)
    {
        if (![viewControllers containsObject:controller])
            [removedControllers addObject:controller];
    }
    
    animated = false;

    UIViewController *disappearingTopViewController = nil;
    UIViewController *appearingTopViewController = nil;
    
    if (_controllerList.count != 0)
        disappearingTopViewController = [_controllerList lastObject];
    
    [_controllerList removeAllObjects];
    [_controllerList addObjectsFromArray:viewControllers];
    
    if (_controllerList.count != 0)
        appearingTopViewController = [_controllerList lastObject];
    
    if (appearingTopViewController != disappearingTopViewController)
    {
        if (disappearingTopViewController != nil)
        {
            [disappearingTopViewController TG_setNavigationController:nil];
            [disappearingTopViewController viewWillDisappear:animated];
        }
        
        if (appearingTopViewController != nil)
        {
            [self _prepareViewController:appearingTopViewController atPosition:CGPointZero];
            [appearingTopViewController viewWillAppear:animated];
        }
        
        _containerView.currentView = nil;
        
        if (disappearingTopViewController != nil)
            [disappearingTopViewController viewDidDisappear:animated];
        
        if (appearingTopViewController != nil)
        {
            _containerView.currentView = appearingTopViewController.view;
            
            UINavigationItem *navigationItem = appearingTopViewController.navigationItem;
            if (navigationItem != nil)
                [_containerView.navigationBar setItems:[[NSArray alloc] initWithObjects:navigationItem, nil]];
            
            [appearingTopViewController viewDidAppear:animated];
            
            [self _endViewControllerTransition];
            [self _processRemovedViewControllers:removedControllers];
        }
    }
    else
    {
        [self _processRemovedViewControllers:removedControllers];
    }
}

- (NSArray *)popToViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    NSMutableArray *newControllers = [[NSMutableArray alloc] init];
    NSMutableArray *removedControllers = [[NSMutableArray alloc] init];
    
    bool processingRemoved = false;
    
    for (TGViewController *controller in _controllerList)
    {
        if (processingRemoved)
            [removedControllers addObject:controller];
        else
        {
            if (controller == viewController)
                processingRemoved = true;
            
            [newControllers addObject:controller];
        }
    }
    
    [self setViewControllers:newControllers animated:animated];
    
    return removedControllers;
}

#pragma mark -

- (void)_processRemovedViewControllers:(NSArray *)array
{
    for (UIViewController *controller in array)
    {
        if ([controller conformsToProtocol:@protocol(TGDestructableViewController)])
            [(id<TGDestructableViewController>)controller cleanupAfterDestruction];
    }
}

- (void)_endViewControllerTransition
{
    NSMutableArray *newControllers = nil;
    
    for (UIViewController *controller in _controllerList)
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
    
    UIViewController *viewController = _controllerList.count != 0 ? [_controllerList lastObject] : nil;
    
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
        }
    }
}*/

@end
