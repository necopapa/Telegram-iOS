#import "TGCircularProgressView.h"

@interface TGCircularProgressView ()

@property (nonatomic) bool annular;
@property (nonatomic) float progress;

@property (nonatomic, strong) UIColor *progressColor;

@end

@implementation TGCircularProgressView

@synthesize annular = _annular;
@synthesize progress = _progress;

@synthesize progressColor = _progressColor;

- (void)setProgress:(float)progress
{
    if (ABS(progress - _progress) > FLT_EPSILON)
    {
        _progress = progress;
        [self setNeedsDisplay];
    }
}

- (void)setAnnular:(bool)annular
{
	_annular = annular;
	[self setNeedsDisplay];
}

#pragma mark - Lifecycle

- (id)init
{
	return [self initWithFrame:CGRectMake(0, 0, 50, 50)];
}

- (id)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];
	if (self)
    {
		self.backgroundColor = [UIColor clearColor];
		self.opaque = false;
		_progress = 0.0f;
		_annular = true;
		_progressColor = [[UIColor alloc] initWithWhite:1.f alpha:1.f];
	}
	return self;
}


- (void)drawRect:(CGRect)__unused rect
{   
	CGRect allRect = self.bounds;
	CGContextRef context = UIGraphicsGetCurrentContext();
    
	if (_annular)
    {
		UIBezierPath *processPath = [UIBezierPath bezierPath];
		processPath.lineCapStyle = ABS(_progress - 1.0f) < FLT_EPSILON ? kCGLineCapSquare : kCGLineCapRound;
		processPath.lineWidth = 4;
        CGPoint center = CGPointMake(self.bounds.size.width / 2, self.bounds.size.height / 2);
		CGFloat radius = (self.bounds.size.width - 13) / 2;
        float startAngle = -((float)M_PI / 2);
		float endAngle = (_progress * 2 * (float)M_PI) + startAngle;
		[processPath addArcWithCenter:center radius:radius startAngle:startAngle endAngle:endAngle clockwise:YES];
		[_progressColor set];
		[processPath stroke];
	}
    else
    {
		CGPoint center = CGPointMake(allRect.size.width / 2, allRect.size.height / 2);
		CGFloat radius = (allRect.size.width - 4) / 2;
		CGFloat startAngle = - ((float)M_PI / 2);
		CGFloat endAngle = (self.progress * 2 * (float)M_PI) + startAngle;
		CGContextSetRGBFillColor(context, 1.0f, 1.0f, 1.0f, 1.0f);
		CGContextMoveToPoint(context, center.x, center.y);
		CGContextAddArc(context, center.x, center.y, radius, startAngle, endAngle, 0);
		CGContextClosePath(context);
		CGContextFillPath(context);
	}
}

@end
