#import "TGAlertDelegateProxy.h"

@interface TGAlertDelegateProxy ()

@property (nonatomic, weak) id<UIAlertViewDelegate> target;

@end

@implementation TGAlertDelegateProxy

- (instancetype)initWithTarget:(id<UIAlertViewDelegate>)target
{
    self = [super init];
    if (self != nil)
    {
        _target = target;
    }
    return self;
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    id target = _target;
    if ([target respondsToSelector:@selector(alertView:clickedButtonAtIndex:)])
        [target alertView:alertView clickedButtonAtIndex:buttonIndex];
}

@end
