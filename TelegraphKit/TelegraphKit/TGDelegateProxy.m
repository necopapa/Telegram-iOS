#import "TGDelegateProxy.h"

@implementation TGDelegateProxy

@synthesize target = _target;

- (void)forwardInvocation:(NSInvocation *)invocation
{
    if (_target != nil)
        [invocation invokeWithTarget:_target];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector
{
    NSMethodSignature *signature = nil;
    if (_target != nil)
        signature = [(NSObject *)_target methodSignatureForSelector:selector];
    return signature;
}

- (BOOL)respondsToSelector:(SEL)selector
{
    bool result = false;
    if (_target != nil)
        result = [(NSObject *)_target respondsToSelector:selector];
    return result;
}

@end
