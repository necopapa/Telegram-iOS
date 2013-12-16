#import "TGSwipeGestureRecognizer.h"

#import <UIKit/UIGestureRecognizerSubclass.h>

@interface TGSwipeGestureRecognizer ()

@property (nonatomic) CGPoint tapPoint;

@property (nonatomic) int lockedDirection;

@property (nonatomic) NSTimeInterval touchStartTime;
@property (nonatomic) bool matchedVelocity;

@end

@implementation TGSwipeGestureRecognizer

@synthesize tapPoint = _tapPoint;

@synthesize lockedDirection = _lockedDirection;

@synthesize touchStartTime = _touchStartTime;
@synthesize matchedVelocity = _matchedVelocity;

@synthesize directionLockThreshold = _directionLockThreshold;
@synthesize horizontalThreshold = _horizontalThreshold;
@synthesize verticalThreshold = _verticalThreshold;

@synthesize velocityThreshold = _velocityThreshold;
@synthesize velocityFailDistance = _velocityFailDistance;

@synthesize direction = _direction;

- (id)initWithTarget:(id)target action:(SEL)action
{
    self = [super initWithTarget:target action:action];
    if (self != nil)
    {
        _directionLockThreshold = 6;
        _horizontalThreshold = 10;
        _verticalThreshold = 20;
        _velocityThreshold = 0;
        _velocityFailDistance = 4;
        _direction = TGSwipeGestureRecognizerDirectionLeft | TGSwipeGestureRecognizerDirectionRight;
    }
    return self;
}

- (void)failGesture
{
    self.state = UIGestureRecognizerStateFailed;
}

- (void)endGesture
{
    self.state = UIGestureRecognizerStateRecognized;
}

- (void)reset
{
    _tapPoint = CGPointZero;
    _matchedVelocity = false;
    
    _lockedDirection = 0;
    
    [super reset];
}

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesBegan:touches withEvent:event];
    
    if ([self numberOfTouches] > 1)
    {
        [self failGesture];
        return;
    }
    
    UITouch *touch = [touches anyObject];
    
    _tapPoint = [touch locationInView:self.view];
    _touchStartTime = touch.timestamp;
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    CGPoint currentPoint = [touch locationInView:self.view];
    CGSize translation = CGSizeMake(currentPoint.x - _tapPoint.x, currentPoint.y - _tapPoint.y);
    
    float translationSquared = translation.width * translation.width + translation.height * translation.height;
    
    if (_lockedDirection == 0)
    {
        if (translationSquared >= _directionLockThreshold * _directionLockThreshold)
        {
            _lockedDirection = ABS(translation.width) > ABS(translation.height) ? 1 : 2;
        }
    }

    if (_lockedDirection == 1)
    {
        //translation.height = 0;
    }
    else if (_lockedDirection == 2)
        translation.width = 0;
    
    float adjustedTranslation = translation.width + (translation.width < -4 ? 4 : (translation.width > 4 ? -4 : 0));
    if (ABS(adjustedTranslation) > FLT_EPSILON && ((adjustedTranslation < 0 && (_direction & TGSwipeGestureRecognizerDirectionLeft) == 0) || (adjustedTranslation > 0 && (_direction & TGSwipeGestureRecognizerDirectionRight) == 0)))
    {
        [self failGesture];
        return;
    }
    
    if (ABS(translation.height) > _verticalThreshold)
    {
        [self failGesture];
        return;
    }
    else if (ABS(translation.width) > _horizontalThreshold)
    {
        [self endGesture];
        return;
    }
    else if (!_matchedVelocity && _velocityThreshold > FLT_EPSILON && translationSquared >= _velocityFailDistance * _velocityFailDistance)
    {
        float velocity = (float)(sqrtf(translationSquared) / (touch.timestamp - _touchStartTime));
        if (velocity < _velocityThreshold)
        {
            //TGLog(@"Failed swipe: %f < %f", velocity, _velocityThreshold);
            [self failGesture];
            return;
        }
        else
            _matchedVelocity = true;
    }
    
    [super touchesMoved:touches withEvent:event];
}

- (void)touchesEnded:(NSSet *)__unused touches withEvent:(UIEvent *)__unused event
{
    [self failGesture];
}

-(void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesCancelled:touches withEvent:event];
    
    [self failGesture];
}

@end
