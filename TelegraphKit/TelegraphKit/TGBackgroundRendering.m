#import "TGBackgroundRendering.h"

@implementation TGBackgroundRendering

+ (id)requestRendering:(TGWeakDelegate *)__unused receiver operation:(id<TGBackgroundRenderingOperation>)__unused operation
{
    return nil;
}

+ (void)cancelRendering:(id)__unused tag
{
    
}

@end
