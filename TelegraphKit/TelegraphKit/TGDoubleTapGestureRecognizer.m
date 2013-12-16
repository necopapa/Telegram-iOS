#import "TGDoubleTapGestureRecognizer.h"

#import <UIKit/UIGestureRecognizerSubclass.h>

@interface TGDoubleTapGestureRecognizer ()

@property (nonatomic, strong) NSTimer *tapTimer;
@property (nonatomic) int currentTapCount;

@end

@implementation TGDoubleTapGestureRecognizer

- (id)initWithTarget:(id)target action:(SEL)action
{
    self = [super initWithTarget:target action:action];
    if (self != nil)
    {
    }
    return self;
}

- (void)failGesture
{
    if (_tapTimer != nil)
    {
        [_tapTimer invalidate];
        _tapTimer = nil;
    }
    
    self.state = UIGestureRecognizerStateFailed;
}

- (void)endGesture
{
    if (_tapTimer != nil)
    {
        [_tapTimer invalidate];
        _tapTimer = nil;
    }
    
    self.state = UIGestureRecognizerStateRecognized;
}

- (void)reset
{
    if (_tapTimer != nil)
    {
        [_tapTimer invalidate];
        _tapTimer = nil;
    }
    
    _currentTapCount = 0;
    
    _doubleTapped = false;
    
    [super reset];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesBegan:touches withEvent:event];
    
    if ([self numberOfTouches] > 1)
    {
        [self failGesture];
        return;
    }
    
    if (_tapTimer != nil)
    {
        [_tapTimer invalidate];
        _tapTimer = nil;
    }
    
    if (_currentTapCount == 0)
    {        
        _currentTapCount++;
    }
    else if (_currentTapCount >= 1)
    {
        _doubleTapped = true;
        
        [self endGesture];
    }
}

- (void)touchesMoved:(NSSet *)__unused touches withEvent:(UIEvent *)__unused event
{
    [self failGesture];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (_currentTapCount == 1)
    {
        UITouch *touch = [touches anyObject];
        int failTapType = 0;
        if ([self.delegate conformsToProtocol:@protocol(TGDoubleTapGestureRecognizerDelegate)] && (failTapType = [(id<TGDoubleTapGestureRecognizerDelegate>)self.delegate gestureRecognizer:self shouldFailTap:[touch locationInView:self.view]]))
        {
            _doubleTapped = false;
            if (_consumeSingleTap && failTapType != 2)
                [self endGesture];
            else
                [self failGesture];
        }
        else
        {
            _tapTimer = [[NSTimer alloc] initWithFireDate:[[NSDate alloc] initWithTimeIntervalSinceNow:0.2] interval:0.2 target:self selector:@selector(tapTimerEvent) userInfo:nil repeats:false];
            [[NSRunLoop mainRunLoop] addTimer:_tapTimer forMode:NSRunLoopCommonModes];
        }
    }
    
    [super touchesEnded:touches withEvent:event];
}

- (void)tapTimerEvent
{
    _tapTimer = nil;
    
    _doubleTapped = false;
    
    if ([self.delegate conformsToProtocol:@protocol(TGDoubleTapGestureRecognizerDelegate)] && [self.delegate respondsToSelector:@selector(doubleTapGestureRecognizerSingleTapped:)])
    {
        [(id<TGDoubleTapGestureRecognizerDelegate>)self.delegate doubleTapGestureRecognizerSingleTapped:self];
    }
    
    if (_consumeSingleTap)
        [self endGesture];
    else
        [self failGesture];
}

-(void)touchesCancelled:(NSSet*)touches withEvent:(UIEvent*)event
{
    [super touchesCancelled:touches withEvent:event];
    
    [self failGesture];
}

@end
