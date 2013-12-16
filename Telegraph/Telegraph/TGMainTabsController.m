#import "TGMainTabsController.h"

#import "TGViewController.h"
#import "TGTabControllerChild.h"

#import "TGNavigationBar.h"

#import "TGLabel.h"

#import "TGImageUtils.h"

#import <QuartzCore/QuartzCore.h>

#import <objc/runtime.h>

#import "TGHacks.h"

@protocol TGTabBarDelegate <NSObject>

- (void)tabBarSelectedItem:(int)index;

@end

@interface TGTabBar : UIView

@property (nonatomic, weak) id<TGTabBarDelegate> tabDelegate;

@property (nonatomic, strong) UIImageView *backgroundView;
@property (nonatomic, strong) UIImageView *selectedView;

@property (nonatomic, strong) NSMutableArray *buttonViews;
@property (nonatomic, strong) NSMutableArray *labelViews;

@property (nonatomic, strong) UIView *unreadBadgeContainer;
@property (nonatomic, strong) UIImageView *unreadBadgeBackground;
@property (nonatomic, strong) UILabel *unreadBadgeLabel;

@property (nonatomic) int selectedIndex;

@end

@implementation TGTabBar

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.multipleTouchEnabled = false;
        self.exclusiveTouch = true;
        
        _backgroundView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"TabBarBackground.png"]];
        _backgroundView.frame = self.bounds;
        [self addSubview:_backgroundView];
        
        UIImage *rawSelectedImage = [UIImage imageNamed:@"TabBarSelected.png"];
        _selectedView = [[UIImageView alloc] initWithImage:[rawSelectedImage stretchableImageWithLeftCapWidth:(int)(rawSelectedImage.size.width / 2) topCapHeight:0]];
        [self addSubview:_selectedView];
        
        _buttonViews = [[NSMutableArray alloc] init];
        
        UIImageView *contactsIcon = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"TabIconContacts.png"] highlightedImage:[UIImage imageNamed:@"TabIconContacts_Highlighted.png"]];
        [self addSubview:contactsIcon];
        [_buttonViews addObject:contactsIcon];
        
        UIImageView *messagesIcon = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"TabIconMessages.png"] highlightedImage:[UIImage imageNamed:@"TabIconMessages_Highlighted.png"]];
        [self addSubview:messagesIcon];
        [_buttonViews addObject:messagesIcon];
        
        UIImageView *settingsIcon = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"TabIconSettings.png"] highlightedImage:[UIImage imageNamed:@"TabIconSettings_Highlighted.png"]];
        [self addSubview:settingsIcon];
        [_buttonViews addObject:settingsIcon];
        
        _labelViews = [[NSMutableArray alloc] init];
        
        UILabel *contactsLabel = [[UILabel alloc] init];
        contactsLabel.backgroundColor = [UIColor clearColor];
        contactsLabel.textColor = UIColorRGB(0x999999);
        contactsLabel.highlightedTextColor = [UIColor whiteColor];
        contactsLabel.font = [UIFont boldSystemFontOfSize:10];
        contactsLabel.text = TGLocalized(@"Contacts.TabTitle");
        [contactsLabel sizeToFit];
        [self addSubview:contactsLabel];
        [_labelViews addObject:contactsLabel];
        
        UILabel *messagesLabel = [[UILabel alloc] init];
        messagesLabel.backgroundColor = [UIColor clearColor];
        messagesLabel.textColor = UIColorRGB(0x999999);
        messagesLabel.highlightedTextColor = [UIColor whiteColor];
        messagesLabel.font = [UIFont boldSystemFontOfSize:10];
        messagesLabel.text = TGLocalized(@"DialogList.TabTitle");
        [messagesLabel sizeToFit];
        [self addSubview:messagesLabel];
        [_labelViews addObject:messagesLabel];
        
        UILabel *settingsLabel = [[UILabel alloc] init];
        settingsLabel.backgroundColor = [UIColor clearColor];
        settingsLabel.textColor = UIColorRGB(0x999999);
        settingsLabel.highlightedTextColor = [UIColor whiteColor];
        settingsLabel.font = [UIFont boldSystemFontOfSize:10];
        settingsLabel.text = TGLocalized(@"Settings.TabTitle");
        [settingsLabel sizeToFit];
        [self addSubview:settingsLabel];
        [_labelViews addObject:settingsLabel];
    }
    return self;
}

- (void)setSelectedIndex:(int)selectedIndex
{
    if (_selectedIndex >= 0 && _selectedIndex < (int)_buttonViews.count)
    {
        ((UIImageView *)[_buttonViews objectAtIndex:_selectedIndex]).highlighted = false;
        ((UILabel *)[_labelViews objectAtIndex:_selectedIndex]).highlighted = false;
    }
    
    _selectedIndex = selectedIndex;
    
    float indicatorWidth = floorf(self.frame.size.width / 3);
    if (((int)indicatorWidth) % 2 != 0)
        indicatorWidth -= 1;
    
    float paddingLeft = floorf((self.frame.size.width - indicatorWidth * 3) / 2);

    float additionalWidth = 0;
    float additionalOffset = 0;
    if (_selectedIndex == 0 || _selectedIndex == 2)
        additionalWidth += paddingLeft + 1;
    if (_selectedIndex == 0)
        additionalOffset += -paddingLeft - 1;
    
    _selectedView.frame = CGRectMake(paddingLeft + indicatorWidth * _selectedIndex + additionalOffset, 0, indicatorWidth + additionalWidth, 49);
    
    if (_selectedIndex >= 0 && _selectedIndex < (int)_buttonViews.count)
    {
        ((UIImageView *)[_buttonViews objectAtIndex:_selectedIndex]).highlighted = true;
        ((UILabel *)[_labelViews objectAtIndex:_selectedIndex]).highlighted = true;
    }
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesBegan:touches withEvent:event];
    
    UITouch *touch = [touches anyObject];
    int index = MAX(0, MIN((int)_buttonViews.count - 1, (int)([touch locationInView:self].x / (self.frame.size.width / 3))));
    [self setSelectedIndex:index];
    
    __strong id<TGTabBarDelegate> delegate = _tabDelegate;
    [delegate tabBarSelectedItem:index];
}

- (void)loadUnreadBadgeView
{
    if (_unreadBadgeContainer != nil)
        return;
    
    _unreadBadgeContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 20, 20)];
    _unreadBadgeContainer.hidden = true;
    _unreadBadgeContainer.userInteractionEnabled = false;
    _unreadBadgeContainer.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self addSubview:_unreadBadgeContainer];
    
    _unreadBadgeBackground = [[UIImageView alloc] initWithImage:[[UIImage imageNamed:@"TabBarBadge.png"] stretchableImageWithLeftCapWidth:10 topCapHeight:0]];
    [_unreadBadgeContainer addSubview:_unreadBadgeBackground];
    
    float retinaPixel = TGIsRetina() ? 0.5f : 0.0f;
    
    _unreadBadgeLabel = [[UILabel alloc] initWithFrame:CGRectMake(9, 4 + retinaPixel, 28 + retinaPixel, 10)];
    _unreadBadgeLabel.backgroundColor = [UIColor clearColor];
    _unreadBadgeLabel.textColor = [UIColor whiteColor];
    _unreadBadgeLabel.font = [UIFont boldSystemFontOfSize:11];
    [_unreadBadgeContainer addSubview:_unreadBadgeLabel];
    
    [self setNeedsLayout];
}

- (void)setUnreadCount:(int)unreadCount
{
    if (unreadCount <= 0 && _unreadBadgeLabel == nil)
        return;
    
    [self loadUnreadBadgeView];
    
    if (unreadCount <= 0)
        _unreadBadgeContainer.hidden = true;
    else
    {
        NSString *text = nil;
        if (unreadCount < 1000)
            text = [[NSString alloc] initWithFormat:@"%d", unreadCount];
        else if (unreadCount < 1000000)
            text = [[NSString alloc] initWithFormat:@"%dK", unreadCount / 1000];
        else
            text = [[NSString alloc] initWithFormat:@"%dM", unreadCount / 1000000];
        
        float retinaPixel = TGIsRetina() ? 0.5f : 0.0f;
        
        _unreadBadgeLabel.text = text;
        _unreadBadgeContainer.hidden = false;
        
        CGRect frame = _unreadBadgeBackground.frame;
        int textWidth = (int)[text sizeWithFont:_unreadBadgeLabel.font constrainedToSize:_unreadBadgeLabel.bounds.size lineBreakMode:NSLineBreakByTruncatingTail].width;
        frame.size.width = MAX(20, textWidth + 12 + retinaPixel * 2);
        frame.origin.x = _unreadBadgeBackground.superview.frame.size.width - frame.size.width;
        _unreadBadgeBackground.frame = frame;
        
        CGRect labelFrame = _unreadBadgeLabel.frame;
        labelFrame.origin.x = 6 + retinaPixel + frame.origin.x;
        _unreadBadgeLabel.frame = labelFrame;
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGSize viewSize = self.frame.size;
    
    _backgroundView.frame = CGRectMake(0, 0, viewSize.width, viewSize.height);
    
    float indicatorWidth = floorf(viewSize.width / 3);
    if (((int)indicatorWidth) % 2 != 0)
        indicatorWidth -= 1;
    
    float paddingLeft = floorf((viewSize.width - indicatorWidth * 3) / 2);
    float additionalWidth = 0;
    float additionalOffset = 0;
    if (_selectedIndex == 0 || _selectedIndex == 2)
        additionalWidth += paddingLeft + 1;
    if (_selectedIndex == 0)
        additionalOffset += -paddingLeft - 1;
    
    _selectedView.frame = CGRectMake(paddingLeft + indicatorWidth * _selectedIndex + additionalOffset, 0, indicatorWidth + additionalWidth, 49);
    
    int index = -1;
    for (UIView *iconView in _buttonViews)
    {
        index++;
        
        CGRect frame = iconView.frame;
        frame.origin.x = paddingLeft + index * indicatorWidth + floorf((indicatorWidth - frame.size.width) / 2);
        frame.origin.y = 4;
        iconView.frame = frame;
        
        if (index == 1)
        {
            if (_unreadBadgeContainer != nil)
            {
                CGRect unreadBadgeContainerFrame = _unreadBadgeContainer.frame;
                unreadBadgeContainerFrame.origin.x = frame.origin.x + frame.size.width - 9;
                unreadBadgeContainerFrame.origin.y = 2;
                _unreadBadgeContainer.frame = unreadBadgeContainerFrame;
            }
        }
        
        UILabel *labelView = [_labelViews objectAtIndex:index];
        
        CGRect labelFrame = labelView.frame;
        labelFrame.origin.x = paddingLeft + index * indicatorWidth + floorf((indicatorWidth - labelFrame.size.width) / 2);
        labelFrame.origin.y = 35;
        labelView.frame = labelFrame;
    }
}

@end

#pragma mark -

@interface TGTabsContainerViewDelegate : NSObject

@end

@implementation TGTabsContainerViewDelegate

- (void)layoutSubviews:(UIView *)view
{
    static Class containerClass = NULL;
    static Class transitionViewClass = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        containerClass = NSClassFromString(TGEncodeText(@"VJMbzpvuDpoubjofsWjfx", -1));
        transitionViewClass = NSClassFromString(TGEncodeText(@"VJUsbotjujpoWjfx", -1));
    });
    
    if ([view isKindOfClass:containerClass])
    {
        for (UIView *subview in view.subviews)
        {
            if ([subview isKindOfClass:transitionViewClass])
            {
                subview.frame = view.bounds;
                break;
            }
        }
    }
    else
    {
        for (UIView *subview in view.subviews)
        {
            subview.frame = view.bounds;
        }
    }
    
    /*if (containerView != nil)
    {
        CGRect frame = view.frame;
        
        containerView.frame = CGRectMake(0, 0, frame.size.width, frame.size.height);
    }*/
    
    /*double delayInSeconds = 2.0;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void)
    {
        TGDumpViews(view.window, @"");
        //TGLog(@"frame: %@", NSStringFromCGRect(view.window.frame));
    });*/
}

@end

#pragma mark -

@interface TGMainTabsController () <UITabBarControllerDelegate, TGTabBarDelegate>

@property (nonatomic, strong) TGLabel *titleLabel;
@property (nonatomic, strong) UIView *titleLabelContainer;

@property (nonatomic, strong) TGTabBar *customTabBar;

@end

@implementation TGMainTabsController

- (id)init
{
    self = [super initWithNibName:nil bundle:nil];
    if (self)
    {
        self.delegate = self;
    }
    return self;
}

- (void)loadView
{
    [super loadView];

    [TGHacks setLayoutDelegateForContainerView:self.view layoutDelegate:[[TGTabsContainerViewDelegate alloc] init]];
    [TGHacks setLayoutDelegateForContainerView:self.view.subviews[0] layoutDelegate:[[TGTabsContainerViewDelegate alloc] init]];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    _customTabBar = [[TGTabBar alloc] initWithFrame:CGRectMake(0, self.view.frame.size.height - 49, self.view.frame.size.width, 49)];
    _customTabBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    _customTabBar.tabDelegate = self;
    [self.view insertSubview:_customTabBar aboveSubview:self.tabBar];
    
    //_customTabBar.alpha = 0.5f;
    
    self.tabBar.hidden = true;
}

- (void)viewDidUnload
{
    [super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return [TGViewController autorotationAllowed] && (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

- (BOOL)shouldAutorotate
{
    return [TGViewController autorotationAllowed];
}

- (UIBarStyle)requiredNavigationBarStyle
{
    if (self.selectedViewController == nil)
        return UIBarStyleDefault;
    else if ([self.selectedViewController conformsToProtocol:@protocol(TGViewControllerNavigationBarAppearance)])
        return [(id<TGViewControllerNavigationBarAppearance>)self.selectedViewController requiredNavigationBarStyle];
    else
        return UIBarStyleDefault;
}

- (bool)navigationBarShouldBeHidden
{
    if (self.selectedViewController == nil)
        return false;
    else if ([self.selectedViewController conformsToProtocol:@protocol(TGViewControllerNavigationBarAppearance)])
        return [(id<TGViewControllerNavigationBarAppearance>)self.selectedViewController navigationBarShouldBeHidden];
    else
        return false;
}

- (void)viewWillAppear:(BOOL)animated
{
    [self updateTitleForController:self.selectedViewController switchingTabs:false animateText:false];
    
    [self.view layoutIfNeeded];
    
    [super viewWillAppear:animated];
}

- (BOOL)tabBarController:(UITabBarController *)__unused tabBarController shouldSelectViewController:(UIViewController *)viewController
{
    if (viewController == self.selectedViewController)
        return false;
    
    [self updateTitleForController:viewController switchingTabs:true animateText:false];
    
    return true;
}

- (void)tabBarSelectedItem:(int)index
{
    if ((int)self.selectedIndex != index)
    {
        [self tabBarController:self shouldSelectViewController:[self.viewControllers objectAtIndex:index]];
        [self setSelectedIndex:index];
    }
    else
    {
        if ([self.selectedViewController respondsToSelector:@selector(scrollToTopRequested)])
            [self.selectedViewController performSelector:@selector(scrollToTopRequested)];
    }
}

- (void)setSelectedIndex:(NSUInteger)selectedIndex
{
    [super setSelectedIndex:selectedIndex];
    
    [_customTabBar setSelectedIndex:selectedIndex];
}

- (void)setUnreadCount:(int)unreadCount
{
    [_customTabBar setUnreadCount:unreadCount];
}

- (void)updateLeftBarButtonForCurrentController:(bool)animated
{
    UIViewController *viewController = self.selectedViewController;
    if (viewController == nil)
        return;
    
    if ([viewController conformsToProtocol:@protocol(TGTabControllerChild)])
    {
        id<TGTabControllerChild> childController = (id<TGTabControllerChild>)viewController;
        
        if ([childController respondsToSelector:@selector(controllerLeftBarButtonItem)])
            [self.navigationItem setLeftBarButtonItem:[childController controllerLeftBarButtonItem] animated:animated];
        else
            self.navigationItem.leftBarButtonItem = nil;
    }
}

- (void)updateRightBarButtonForCurrentController:(bool)animated
{
    UIViewController *viewController = self.selectedViewController;
    if (viewController == nil)
        return;
    
    if ([viewController conformsToProtocol:@protocol(TGTabControllerChild)])
    {
        id<TGTabControllerChild> childController = (id<TGTabControllerChild>)viewController;
        
        if ([childController respondsToSelector:@selector(controllerRightBarButtonItem)])
            [self.navigationItem setRightBarButtonItem:[childController controllerRightBarButtonItem] animated:animated];
        else
            self.navigationItem.rightBarButtonItem = nil;
    }
}

- (void)updateTitleForController:(UIViewController *)controller switchingTabs:(bool)switchingTabs animateText:(bool)animateText
{
    UIBarStyle barStyle = UIBarStyleDefault;
    if ([controller conformsToProtocol:@protocol(TGViewControllerNavigationBarAppearance)])
    {
        barStyle = [(id<TGViewControllerNavigationBarAppearance>)controller requiredNavigationBarStyle];
    }
    
    if (self.navigationController.topViewController == self)
    {
        //if ([(TGNavigationBar *)self.navigationController.navigationBar barStyle] != barStyle)
        //    [(TGNavigationBar *)self.navigationController.navigationBar setBarStyle:barStyle animated:!switchingTabs];
    }
    
    TGViewControllerStyle style = TGViewControllerStyleDefault;
    
    if (_titleLabel == nil)
    {
        _titleLabel = [[TGLabel alloc] init];
        _titleLabel.clipsToBounds = false;
        _titleLabel.backgroundColor = [UIColor clearColor];
        
        _titleLabel.font = [TGViewController titleFontForStyle:style landscape:UIDeviceOrientationIsLandscape(self.interfaceOrientation)];
        _titleLabel.portraitFont = [TGViewController titleFontForStyle:style landscape:false];
        _titleLabel.landscapeFont = [TGViewController titleFontForStyle:style landscape:true];
        
        _titleLabel.verticalAlignment = TGLabelVericalAlignmentTop;
        
        _titleLabelContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
        [_titleLabelContainer addSubview:_titleLabel];
    }
    
    _titleLabel.textColor = [TGViewController titleTextColorForStyle:style];
    _titleLabel.shadowColor = [TGViewController titleShadowColorForStyle:style];
    _titleLabel.shadowOffset = [TGViewController titleShadowOffsetForStyle:style];
    
    UIView *controllerTitleView = nil;
    NSString *title = nil;
    
    if ([controller conformsToProtocol:@protocol(TGTabControllerChild)])
    {
        id<TGTabControllerChild> childController = (id<TGTabControllerChild>)controller;
        
        if ([childController respondsToSelector:@selector(controllerTitleView:)])
            controllerTitleView = [childController controllerTitleView:self.view.frame.size.width];
        else
            controllerTitleView = nil;
        
        if ([childController respondsToSelector:@selector(controllerTitle)])
            title = [childController controllerTitle];
        else
            title = nil;
        
        bool hideNavigationBar = false;
        if ([childController respondsToSelector:@selector(navigationBarShouldBeHidden)])
            hideNavigationBar = [childController navigationBarShouldBeHidden];
        
        if (self.navigationController.topViewController == self)
            [self.navigationController setNavigationBarHidden:hideNavigationBar animated:(!switchingTabs)];
    }
    
    [_titleLabel setLandscape:UIDeviceOrientationIsLandscape(self.interfaceOrientation)];
    
    _titleLabel.text = title;
    _titleLabel.frame = CGRectMake(0, 0, 480, 44);
    [_titleLabel sizeToFit];
    CGRect titleLabelFrame = _titleLabel.frame;
    titleLabelFrame.size.height += 2;
    
    titleLabelFrame.origin = CGPointMake(floorf((_titleLabel.superview.frame.size.width - _titleLabel.frame.size.width) / 2), floorf((_titleLabel.superview.frame.size.height - _titleLabel.frame.size.height) / 2));
    
    _titleLabel.frame = titleLabelFrame;
    
    if (controllerTitleView != nil)
    {
        self.navigationItem.titleView = controllerTitleView;
    }
    else
    {
        self.navigationItem.titleView = _titleLabelContainer;
    }
    
    if ([controller conformsToProtocol:@protocol(TGTabControllerChild)])
    {
        id<TGTabControllerChild> childController = (id<TGTabControllerChild>)controller;
        
        if ([childController respondsToSelector:@selector(controllerLeftBarButtonItem)])
            self.navigationItem.leftBarButtonItem = [childController controllerLeftBarButtonItem];
        else
            self.navigationItem.leftBarButtonItem = nil;
        
        if ([childController respondsToSelector:@selector(controllerRightBarButtonItem)])
            self.navigationItem.rightBarButtonItem = [childController controllerRightBarButtonItem];
        else
            self.navigationItem.rightBarButtonItem = nil;
        
        bool hideNavigationBar = false;
        if ([childController respondsToSelector:@selector(navigationBarShouldBeHidden)])
            hideNavigationBar = [childController navigationBarShouldBeHidden];
        
        if (self.navigationController.topViewController == self)
            [self.navigationController setNavigationBarHidden:hideNavigationBar animated:(!switchingTabs)];
    }

    if (animateText && ![_titleLabel.text isEqualToString:title])
    {
        CATransition *transition = [CATransition animation];
        transition.duration = 0.1;
        transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
        [_titleLabel.layer addAnimation:transition forKey:nil];
    }
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    if (_titleLabel != nil)
    {
        _titleLabel.frame = CGRectMake(0, 0, 480, 44);
        [_titleLabel sizeToFit];
        CGRect titleLabelFrame = _titleLabel.frame;
        titleLabelFrame.size.height += 2;
        
        titleLabelFrame.origin = CGPointMake(floorf((_titleLabel.superview.frame.size.width - _titleLabel.frame.size.width) / 2), floorf((_titleLabel.superview.frame.size.height - _titleLabel.frame.size.height) / 2));
        
        _titleLabel.frame = titleLabelFrame;
    }
    
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
}

@end
