#import "TGHacks.h"

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

#import <objc/runtime.h>

#import "TGNavigationController.h"
#import "TGViewController.h"

static float animationDurationFactor = 1.0f;
static float secondaryAnimationDurationFactor = 1.0f;

static bool forceMovieAnimatedScaleMode = false;

static const char *textFieldPlaceholderColorKey = "telegraph_TextFieldPlaceholder";
static const char *textFieldPlaceholderFontKey = "telegraph_TextFieldFont";
static const char *textFieldClearOffsetKey = "telegraph_TextFieldClearOffset";

static const char *containerViewCustomLayoutDelegate = "containerViewCustomLayoutDelegate";

static const char *webScrollViewContentInsetEnabled = "webScrollViewContentInsetEnabled";

static id applicationStatusBarSetStyleDelegate = nil;

static void SwizzleClassMethod(Class c, SEL orig, SEL new)
{    
    Method origMethod = class_getClassMethod(c, orig);
    Method newMethod = class_getClassMethod(c, new);
    
    c = object_getClass((id)c);
    
    if(class_addMethod(c, orig, method_getImplementation(newMethod), method_getTypeEncoding(newMethod)))
        class_replaceMethod(c, new, method_getImplementation(origMethod), method_getTypeEncoding(origMethod));
    else
        method_exchangeImplementations(origMethod, newMethod);
}

static void SwizzleInstanceMethod(Class c, SEL orig, SEL new)
{
    Method origMethod = nil, newMethod = nil;

    origMethod = class_getInstanceMethod(c, orig);
    newMethod = class_getInstanceMethod(c, new);
    if ((origMethod != nil) && (newMethod != nil))
    {
        if(class_addMethod(c, orig, method_getImplementation(newMethod), method_getTypeEncoding(newMethod)))
            class_replaceMethod(c, new, method_getImplementation(origMethod), method_getTypeEncoding(origMethod));
        else
            method_exchangeImplementations(origMethod, newMethod);
    }
    else
        NSLog(@"Attempt to swizzle nonexistent methods!");
}

static void SwizzleInstanceMethodWithAnotherClass(Class c1, SEL orig, Class c2, SEL new)
{
    Method origMethod = nil, newMethod = nil;
    
    origMethod = class_getInstanceMethod(c1, orig);
    newMethod = class_getInstanceMethod(c2, new);
    if ((origMethod != nil) && (newMethod != nil))
    {
        if(class_addMethod(c1, orig, method_getImplementation(newMethod), method_getTypeEncoding(newMethod)))
            class_replaceMethod(c1, new, method_getImplementation(origMethod), method_getTypeEncoding(origMethod));
        else
            method_exchangeImplementations(origMethod, newMethod);
    }
    else
        NSLog(@"Attempt to swizzle nonexistent methods!");
}

static void AddInstanceMethodFromAnotherClass(Class c1, Class c2, SEL new)
{
    Method newMethod = nil;
    
    newMethod = class_getInstanceMethod(c2, new);
    if (newMethod != nil)
    {
        if (!class_addMethod(c1, new, method_getImplementation(newMethod), method_getTypeEncoding(newMethod)))
            NSLog(@"Attempt to add method failed");
    }
    else
        NSLog(@"Attempt to add nonexistent method");
}

@interface UIView (TGHacks)

+ (void)telegraph_setAnimationDuration:(NSTimeInterval)duration;

@end

@implementation UIView (TGHacks)

+ (void)telegraph_setAnimationDuration:(NSTimeInterval)duration
{
    [self telegraph_setAnimationDuration:(duration * animationDurationFactor)];
}

+ (void)telegraph_animateWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay options:(UIViewAnimationOptions)options animations:(void (^)(void))animations completion:(void (^)(BOOL finished))completion
{
    [self telegraph_animateWithDuration:duration * secondaryAnimationDurationFactor delay:delay options:options animations:animations completion:completion];
}

@end

@interface UITextField (TGHacks)

- (void)telegraph_drawPlaceholderInRect:(CGRect)rect;

@end

@implementation UITextField (TGHacks)

- (void)telegraph_drawPlaceholderInRect:(CGRect)rect
{
    UIColor *color = objc_getAssociatedObject(self, textFieldPlaceholderColorKey);
    if (color != nil)
    {
        UIFont *font = objc_getAssociatedObject(self, textFieldPlaceholderFontKey);
        CGContextSetFillColorWithColor(UIGraphicsGetCurrentContext(), color.CGColor);
        [self.placeholder drawInRect:rect withFont:font == nil ? self.font : font lineBreakMode:NSLineBreakByTruncatingTail alignment:self.textAlignment];
    }
    else
    {
        [self telegraph_drawPlaceholderInRect:rect];
    }
}

- (CGRect)telegraph_clearButtonRectForBounds:(CGRect)bounds
{
    NSNumber *offset = objc_getAssociatedObject(self, textFieldClearOffsetKey);
    if (offset == nil)
        return [self telegraph_clearButtonRectForBounds:bounds];
    else
        return CGRectOffset([self telegraph_clearButtonRectForBounds:bounds], 0, [offset floatValue]);
}

- (BOOL)tg_keyboardInputShouldDelete:(id)object
{
    bool result = [self tg_keyboardInputShouldDelete:object];
    
    if (result && self.text.length == 0 && [self respondsToSelector:@selector(deleteLastBackward)])
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            [self performSelector:@selector(deleteLastBackward)];
        });
    }
    
    return result;
}

@end

/*@interface TGActivitySortHelper : NSObject

- (void)setSortActivities:(id)arg1;

@end

@implementation TGActivitySortHelper

- (void)setSortActivities:(id)arg1
{
    NSArray *destArray = arg1;
    
    NSArray *sourceArray = arg1;
    if (sourceArray.count != 0 && ![[sourceArray objectAtIndex:0] respondsToSelector:@selector(isTGKitActivity)])
    {
        NSMutableArray *newArray = [[NSMutableArray alloc] initWithCapacity:sourceArray.count];
        for (id object in sourceArray)
        {
            if ([object respondsToSelector:@selector(isTGKitActivity)])
                [newArray addObject:object];
        }
        
        for (id object in sourceArray)
        {
            if (![object respondsToSelector:@selector(isTGKitActivity)])
                [newArray addObject:object];
        }
        
        destArray = newArray;
    }
    
    Method method = class_getInstanceMethod([TGActivitySortHelper class], @selector(setSortActivities:));
    void (*impl)(id, SEL, id) = (void (*)(id, SEL, id))method_getImplementation(method);
    impl(self, @selector(setSortActivities:), destArray);
}

@end*/

@interface UISearchBar (TGHacks)

@end

@implementation UISearchBar (TGHacks)

- (BOOL)TG_searchBarMethod1
{
    return false;
}

@end

@interface UINavigationBar (TGHacks)

@end

@implementation UINavigationBar (TGHacks)

- (BOOL)TG_method1
{
    return false;
}

@end

@interface TGStatusBarBackgroundView : UIView

@end

@implementation TGStatusBarBackgroundView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewContentModeBottomRight;
        self.backgroundColor = [UIColor blueColor];
    }
    return self;
}

@end

@interface TGStatusBar : UIView

@end

@implementation TGStatusBar

- (void)TGStatusBar_method1
{
    static Class backgroundViewClass = nil;
    static Class customBackgroundViewClass = nil;
    static void (*impl)(id, SEL) = NULL;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        backgroundViewClass = NSClassFromString(TGEncodeText(@"VJTubuvtCbsCbdlhspvoeWjfx", -1));
        customBackgroundViewClass = [TGStatusBarBackgroundView class];
        
        Method method = class_getInstanceMethod([TGStatusBar class], @selector(TGStatusBar_method1));
        if (method != NULL)
            impl = (void (*)(id, SEL))method_getImplementation(method);
    });
    
    if (impl)
        impl(self, @selector(TGStatusBar_method1));
}

@end

#pragma mark -

@interface UINavigationController (TGHacks)

@end

@implementation UINavigationController (TGHacks)

- (void)TGNavigationController_method1:(BOOL)__unused arg1 edge:(int)__unused arg2
{
}

@end

@interface UIViewController (TGHacks)

@end

@implementation UIViewController (TGHacks)

- (void)UIViewController_method1:(UIEdgeInsets)__unused inset
{
    
}

@end

@protocol TGLayoutContainerViewDelegate <NSObject>

- (void)layoutSubviews:(UIView *)view;

@end

#define TGFullscreenContainerClass(ClassName) \
@interface ClassName : UIView \
@end \
@implementation ClassName \
 \
- (void)layoutSubviewsTG \
{ \
    id layoutDelegate = objc_getAssociatedObject(self, containerViewCustomLayoutDelegate); \
    if (layoutDelegate != nil) \
    { \
        [(id<TGLayoutContainerViewDelegate>)layoutDelegate layoutSubviews:self]; \
    } \
    else \
    { \
        static void (*impl)(id, SEL) = NULL; \
        static dispatch_once_t onceToken; \
        dispatch_once(&onceToken, ^ \
        { \
            Method method = class_getInstanceMethod([ClassName class], @selector(layoutSubviewsTG)); \
            impl = (void (*)(id, SEL))method_getImplementation(method); \
        }); \
        \
        if (impl) \
            impl(self, @selector(layoutSubviewsTG)); \
    } \
} \
@end

TGFullscreenContainerClass(TGLayoutContainerView)
TGFullscreenContainerClass(TGTransitionView)
TGFullscreenContainerClass(TGNavigationTransitionView)
TGFullscreenContainerClass(TGViewControllerWrapperView)

#pragma mark -

@interface TGWebViewScrollHelper : UIScrollView
@end

@implementation TGWebViewScrollHelper

- (void)TG_setContentInset:(UIEdgeInsets)inset
{
    NSNumber *nEnabled = objc_getAssociatedObject(self, webScrollViewContentInsetEnabled);
    if (nEnabled == nil || [nEnabled boolValue])
    {
        [self TG_setContentInset:inset];
    }
}

- (void)TG_setScrollIndicatorInsets:(UIEdgeInsets)inset
{
    NSNumber *nEnabled = objc_getAssociatedObject(self, webScrollViewContentInsetEnabled);
    if (nEnabled == nil || [nEnabled boolValue])
    {
        [self TG_setScrollIndicatorInsets:inset];
    }
}

@end

@implementation TGHacks

+ (void)hackSetAnimationDuration
{
    SwizzleClassMethod([UIView class], @selector(setAnimationDuration:), @selector(telegraph_setAnimationDuration:));
    SwizzleClassMethod([UIView class], @selector(animateWithDuration:delay:options:animations:completion:), @selector(telegraph_animateWithDuration:delay:options:animations:completion:));
    
    SwizzleInstanceMethod([UIViewController class], @selector(navigationController), @selector(TG_navigationController));
    
    SwizzleInstanceMethod([UINavigationBar class], NSSelectorFromString(encodeText(@"jtMpdlfe", -1)), @selector(TG_method1));
    
    Class webScrollViewClass = NSClassFromString(TGEncodeText(@"VJXfcTdspmmWjfx", -1));
    SwizzleInstanceMethodWithAnotherClass(webScrollViewClass, @selector(setContentInset:), [TGWebViewScrollHelper class], @selector(TG_setContentInset:));
    SwizzleInstanceMethodWithAnotherClass(webScrollViewClass, @selector(setScrollIndicatorInsets:), [TGWebViewScrollHelper class], @selector(TG_setScrollIndicatorInsets:));
    
#warning ios 7 bug?
    if (iosMajorVersion() >= 7)
    {
        SwizzleInstanceMethod([UIViewController class], NSSelectorFromString(TGEncodeText(@"`tfuObwjhbujpoDpouspmmfsDpoufouJotfuBekvtunfou;", -1)), @selector(UIViewController_method1:));
    }
    
    SEL searchBarShadowSelector = NSSelectorFromString(TGEncodeText(@"`tipvmeEjtqmbzTibepx", -1));
    if ([UISearchBar instancesRespondToSelector:searchBarShadowSelector])
        SwizzleInstanceMethod([UISearchBar class], searchBarShadowSelector, @selector(TG_searchBarMethod1));
    
    //SwizzleInstanceMethodWithAnotherClass(NSClassFromString(encodeText(@"VJTubuvtCbs", -1)), @selector(layoutSubviews), [TGStatusBar class], @selector(TGStatusBar_method1));
    
#if TGUseGestureNavigationController
    
    SwizzleInstanceMethod([UINavigationController class], NSSelectorFromString(encodeText(@"`qptjujpoObwjhbujpoCbsIjeefo;fehf;", -1)), @selector(TGNavigationController_method1:edge:));
#endif
    
    //SwizzleInstanceMethodWithAnotherClass(NSClassFromString(TGEncodeText(@"VJUsbotjujpoWjfx", -1)), @selector(setFrame:), [TGViewControllerWrapperView1 class], @selector(setFrameTG:));
    
    {
        NSArray *classPairs = @[
            @[TGEncodeText(@"VJMbzpvuDpoubjofsWjfx", -1), [TGLayoutContainerView class]],
            //@[TGEncodeText(@"VJUsbotjujpoWjfx", -1), [TGTransitionView class]],
            //@[TGEncodeText(@"VJObwjhbujpoUsbotjujpoWjfx", -1), [TGNavigationTransitionView class]],
            //@[TGEncodeText(@"VJWjfxDpouspmmfsXsbqqfsWjfx", -1), [TGViewControllerWrapperView class]]
        ];
        
        for (NSArray *classPair in classPairs)
        {
            SwizzleInstanceMethodWithAnotherClass(NSClassFromString(classPair[0]), @selector(layoutSubviews), classPair[1], @selector(layoutSubviewsTG));
            //SwizzleInstanceMethodWithAnotherClass(NSClassFromString(classPair[0]), @selector(setFrame:), classPair[1], @selector(setFrameTG:));
        }
    }
}

+ (void)setAnimationDurationFactor:(float)factor
{
    animationDurationFactor = factor;
}

+ (void)setSecondaryAnimationDurationFactor:(float)factor
{
    secondaryAnimationDurationFactor = factor;
}

static NSString *encodeText(NSString *string, int key)
{
    return TGEncodeText(string, key);
}

+ (void)hackDrawPlaceholderInRect
{
    SwizzleInstanceMethod([UITextField class], @selector(drawPlaceholderInRect:), @selector(telegraph_drawPlaceholderInRect:));
    SwizzleInstanceMethod([UITextField class], @selector(clearButtonRectForBounds:), @selector(telegraph_clearButtonRectForBounds:));
    if (iosMajorVersion() <= 5)
        SwizzleInstanceMethod([UITextField class], NSSelectorFromString(encodeText(@"lfzcpbseJoqvuTipvmeEfmfuf;", -1)), @selector(tg_keyboardInputShouldDelete:));
}

+ (void)setTextFieldPlaceholderColor:(UITextField *)textField color:(UIColor *)color
{
    if (textField != nil && color != nil)
    {
        objc_setAssociatedObject(textField, textFieldPlaceholderColorKey, color, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

+ (void)setTextFieldPlaceholderFont:(UITextField *)textField font:(UIFont *)font
{
    if (textField != nil && font != nil)
    {
        objc_setAssociatedObject(textField, textFieldPlaceholderFontKey, font, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

+ (void)setTextFieldClearOffset:(UITextField *)textField offset:(float)offset
{
    if (textField != nil)
    {
        objc_setAssociatedObject(textField, textFieldClearOffsetKey, [NSNumber numberWithFloat:offset], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

+ (void)overrideApplicationStatusBarSetStyle:(id)delegate
{
    applicationStatusBarSetStyleDelegate = delegate;
}

+ (void)setApplicationStatusBarAlpha:(float)alpha
{
    static SEL selector = NULL;
    if (selector == NULL)
    {
        NSString *str1 = @"rs`str";
        NSString *str2 = @"A`qVhmcnv";
        
        selector = NSSelectorFromString([[NSString alloc] initWithFormat:@"%@%@", encodeText(str1, 1), encodeText(str2, 1)]);
    }
    
    if ([[UIApplication sharedApplication] respondsToSelector:selector])
    {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        UIWindow *window = [[UIApplication sharedApplication] performSelector:selector];
#pragma clang diagnostic pop
        
        window.alpha = alpha;
    }
}

+ (void)animateApplicationStatusBarAppearance:(TGStatusBarAppearanceAnimation)statusBarAnimation duration:(NSTimeInterval)duration completion:(void (^)())completion
{
    static Class viewClass = nil;
    static SEL selector = NULL;
    if (selector == NULL)
    {
        NSString *str1 = @"rs`str";
        NSString *str2 = @"A`qVhmcnv";
        
        selector = NSSelectorFromString([[NSString alloc] initWithFormat:@"%@%@", encodeText(str1, 1), encodeText(str2, 1)]);
        
        viewClass = NSClassFromString(TGEncodeText(@"VJTubuvtCbs", -1));
    }
    
    if ([[UIApplication sharedApplication] respondsToSelector:selector])
    {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        UIWindow *window = [[UIApplication sharedApplication] performSelector:selector];
#pragma clang diagnostic pop
        
        UIView *view = nil;
        for (UIView *subview in window.subviews)
        {
            if ([subview isKindOfClass:viewClass])
            {
                view = subview;
                break;
            }
        }
        
        if (view != nil)
        {
            CGPoint startPosition = view.layer.position;
            CGPoint position = view.layer.position;
            
            float viewHeight = view.frame.size.height;
            
            if (statusBarAnimation == TGStatusBarAppearanceAnimationSlideDown)
            {
                startPosition = CGPointMake(floorf(view.frame.size.width / 2), floorf(view.frame.size.height / 2) - viewHeight);
                position = CGPointMake(floorf(view.frame.size.width / 2), floorf(view.frame.size.height / 2));
            }
            else if (statusBarAnimation == TGStatusBarAppearanceAnimationSlideUp)
            {
                startPosition = CGPointMake(floorf(view.frame.size.width / 2), floorf(view.frame.size.height / 2));
                position = CGPointMake(floorf(view.frame.size.width / 2), floorf(view.frame.size.height / 2) - viewHeight);
            }
            
            CABasicAnimation *animation = [[CABasicAnimation alloc] init];
            animation.duration = duration;
            animation.fromValue = [NSValue valueWithCGPoint:startPosition];
            animation.toValue = [NSValue valueWithCGPoint:position];
            animation.removedOnCompletion = true;
            animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
            
            [view.layer addAnimation:animation forKey:@"position"];
            
            if (completion)
                TGDispatchAfter(duration, dispatch_get_main_queue(), completion);
        }
    }
    else
    {
        if (completion)
            completion();
    }
}

+ (float)statusBarHeightForOrientation:(UIInterfaceOrientation)orientation
{
    static SEL selector = NULL;
    if (selector == NULL)
    {
        NSString *str1 = @"rs`str";
        NSString *str2 = @"A`qVhmcnv";
        
        selector = NSSelectorFromString([[NSString alloc] initWithFormat:@"%@%@", encodeText(str1, 1), encodeText(str2, 1)]);
    }
    
    if ([[UIApplication sharedApplication] respondsToSelector:selector])
    {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        UIWindow *window = [[UIApplication sharedApplication] performSelector:selector];
#pragma clang diagnostic pop
        
        Class statusBarClass = NSClassFromString(TGEncodeText(@"VJTubuvtCbs", -1));
        
        for (UIView *view in window.subviews)
        {
            if ([view isKindOfClass:statusBarClass])
            {
                SEL selector = NSSelectorFromString(TGEncodeText(@"dvssfouTuzmf", -1));
                NSMethodSignature *signature = [statusBarClass instanceMethodSignatureForSelector:selector];
                if (signature == nil)
                {
                    TGLog(@"***** Method not found");
                    return 20.0f;
                }
                
                NSInvocation *inv = [NSInvocation invocationWithMethodSignature:signature];
                [inv setSelector:selector];
                [inv setTarget:view];
                [inv invoke];
                
                int result = 0;
                [inv getReturnValue:&result];
                
                SEL selector2 = NSSelectorFromString(TGEncodeText(@"ifjhiuGpsTuzmf;psjfoubujpo;", -1));
                NSMethodSignature *signature2 = [statusBarClass methodSignatureForSelector:selector2];
                if (signature2 == nil)
                {
                    TGLog(@"***** Method not found");
                    return 20.0f;
                }
                NSInvocation *inv2 = [NSInvocation invocationWithMethodSignature:signature2];
                [inv2 setSelector:selector2];
                [inv2 setTarget:[view class]];
                [inv2 setArgument:&result atIndex:2];
                [inv2 setArgument:&orientation atIndex:3];
                [inv2 invoke];
                
                float result2 = 0;
                [inv2 getReturnValue:&result2];
                
                return result2;
            }
        }
    }
    
    return 20.0f;
}

+ (bool)isKeyboardVisible
{
    static NSInvocation *invocation = nil;
    static Class keyboardClass = NULL;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        keyboardClass = NSClassFromString(TGEncodeText(@"VJLfzcpbse", -1));
        
        SEL onScreenSelector = NSSelectorFromString(TGEncodeText(@"jtPoTdsffo", -1));
        NSMethodSignature *onScreenSignature = [keyboardClass methodSignatureForSelector:onScreenSelector];
        if (onScreenSignature == nil)
            TGLog(@"***** Method not found");
        else
        {
            invocation = [NSInvocation invocationWithMethodSignature:onScreenSignature];
            [invocation setSelector:onScreenSelector];
        }
    });
    
    if (invocation != nil)
    {
        [invocation setTarget:[keyboardClass class]];
        [invocation invoke];
        
        BOOL result = false;
        [invocation getReturnValue:&result];
        
        return result;
    }
    
    return false;
}

+ (float)keyboardHeightForOrientation:(UIInterfaceOrientation)orientation
{
    static NSInvocation *invocation = nil;
    static Class keyboardClass = NULL;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        keyboardClass = NSClassFromString(TGEncodeText(@"VJLfzcpbse", -1));
        
        SEL selector = NSSelectorFromString(TGEncodeText(@"tj{fGpsJoufsgbdfPsjfoubujpo;", -1));
        NSMethodSignature *signature = [keyboardClass methodSignatureForSelector:selector];
        if (signature == nil)
            TGLog(@"***** Method not found");
        else
        {
            invocation = [NSInvocation invocationWithMethodSignature:signature];
            [invocation setSelector:selector];
        }
    });
    
    if (invocation != nil)
    {
        [invocation setTarget:[keyboardClass class]];
        [invocation setArgument:&orientation atIndex:2];
        [invocation invoke];
        
        CGSize result = CGSizeZero;
        [invocation getReturnValue:&result];
        
        return MIN(result.width, result.height);
    }
    
    return 0.0f;
}

/*+ (void)printMethods:(Class)ofClass
{
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList(ofClass, &methodCount);
    for (int i=0; i<methodCount; i++)
    {
        SEL name = method_getName(methods[i]);
        NSLog(@"Method: %@", NSStringFromSelector(name));
    }
    free(methods);
}*/
    
+ (void)setForceMovieAnimatedScaleMode:(bool)force
{
    forceMovieAnimatedScaleMode = force;
}

+ (void)setLayoutDelegateForContainerView:(id)view layoutDelegate:(id)layoutDelegate
{
    objc_setAssociatedObject(view, containerViewCustomLayoutDelegate, layoutDelegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

+ (void)setWebScrollViewContentInsetEnabled:(UIScrollView *)scrollView enabled:(bool)enabled;
{
    static NSNumber *nEnabled = nil;
    static NSNumber *nDisabled = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        nEnabled = [[NSNumber alloc] initWithBool:true];
        nDisabled = [[NSNumber alloc] initWithBool:false];
    });
    
    objc_setAssociatedObject(scrollView, webScrollViewContentInsetEnabled, enabled ? nEnabled : nDisabled, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

#if TARGET_IPHONE_SIMULATOR
extern CGFloat UIAnimationDragCoefficient(void);
#endif

float TGAnimationSpeedFactor()
{
#if TARGET_IPHONE_SIMULATOR
    return UIAnimationDragCoefficient();
#endif
    
    return 1.0f;
}

/*#ifdef DEBUG

@implementation NSObject (ARCZombie)

+ (void)load
{
    const char *NSZombieEnabled = getenv("NSZombieEnabled");
    if (NSZombieEnabled && tolower(NSZombieEnabled[0]) == 'y')
    {
        Method dealloc = class_getInstanceMethod(self, @selector(dealloc));
        Method arczombie_dealloc = class_getInstanceMethod(self, @selector(arczombie_dealloc));
        method_exchangeImplementations(dealloc, arczombie_dealloc);
    }
}

- (void)arczombie_dealloc
{
    Class aliveClass = object_getClass(self);
    [self arczombie_dealloc];
    Class zombieClass = object_getClass(self);
    
    object_setClass(self, aliveClass);
    objc_destructInstance(self);
    object_setClass(self, zombieClass);
}

@end

#endif*/
