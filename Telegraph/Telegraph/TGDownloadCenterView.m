#import "TGDownloadCenterView.h"

#import "TGLinearProgressView.h"

@interface TGDownloadCenterView ()

@property (nonatomic, strong) UILabel *countLabel;
@property (nonatomic, strong) TGLinearProgressView *progressView;

@end

@implementation TGDownloadCenterView

@synthesize countLabel = _countLabel;
@synthesize progressView = _progressView;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        [self commonInit];
    }
    return self;
}

- (void)commonInit
{
    self.backgroundColor = UIColorRGBA(0x000000, 0.5f);
    self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y, 160, 34);
    self.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;
    
    static UIImage *progressBackgroundImage = nil;
    static UIImage *progressForegroundImage = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        UIImage *rawBackground = [UIImage imageNamed:@"LinearProgressBackground.png"];
        progressBackgroundImage = [rawBackground stretchableImageWithLeftCapWidth:(int)(rawBackground.size.width / 2) topCapHeight:0];
        UIImage *rawForeground = [UIImage imageNamed:@"LinearProgressForeground.png"];
        progressForegroundImage = [rawForeground stretchableImageWithLeftCapWidth:(int)(rawForeground.size.width / 2) topCapHeight:0];
    });
    
    _countLabel = [[UILabel alloc] initWithFrame:CGRectMake(4, 4, self.frame.size.width - 8, 18)];
    _countLabel.backgroundColor = [UIColor clearColor];
    _countLabel.textColor = [UIColor whiteColor];
    _countLabel.font = [UIFont boldSystemFontOfSize:11];
    [self addSubview:_countLabel];
    
    _progressView = [[TGLinearProgressView alloc] initWithBackgroundImage:progressBackgroundImage progressImage:progressForegroundImage];
    _progressView.frame = CGRectMake(2, 22, self.frame.size.width - 4, self.frame.size.height);
    [self addSubview:_progressView];
}

- (void)setItems:(int)count
{
    if (count != 0)
    {
        NSString *text = [[NSString alloc] initWithFormat:@"Downloading %d video%s", count, count == 1 ? "" : "s"];
        if (![text isEqualToString:_countLabel.text])
            _countLabel.text = text;
    }
}

- (void)setProgress:(float)progress animated:(BOOL)animated
{
    if (animated && _progressView.progress < progress)
    {
        [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^
        {
            [_progressView setProgress:progress];
        } completion:nil];
    }
    else
    {
        [_progressView setProgress:progress];
    }
}

@end
