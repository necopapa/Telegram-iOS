#import "TGImageViewPage.h"

#import "TGImageUtils.h"
#import "TGViewController.h"

#import "TGCircularProgressView.h"
#import "TGImageTransitionHelper.h"
#import "TGHacks.h"

#import "SGraphImageNode.h"

#import <QuartzCore/QuartzCore.h>

@protocol TGImageScrollViewDelegate <NSObject>

- (void)scrollViewTapped;
- (void)scrollViewDoubleTapped:(CGPoint)point;
- (void)scrollViewLongPressed;

@end

@interface TGImageScrollView : UIScrollView

@property (nonatomic, strong) NSTimer *touchTimer;

@end

@implementation TGImageScrollView

@synthesize touchTimer = _touchTimer;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        [self commonInit];
    }
    return self;
}

- (id)init
{
    self = [super init];
    if (self != nil)
    {
        [self commonInit];
    }
    return self;
}

- (void)dealloc
{
    self.delegate = nil;
    [_touchTimer invalidate];
    _touchTimer = nil;
}

- (void)commonInit
{
    UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(doubleTapGestureRecognized:)];
    tapRecognizer.numberOfTapsRequired = 2;
    tapRecognizer.delaysTouchesEnded = false;
    [self addGestureRecognizer:tapRecognizer];
    
    [self addGestureRecognizer:[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressRecognized:)]];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{    
    if (_touchTimer != nil)
    {
        [_touchTimer invalidate];
        _touchTimer = nil;
    }
    
    [super touchesBegan:touches withEvent:event];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{   
    if (_touchTimer != nil)
    {
        [_touchTimer invalidate];
        _touchTimer = nil;
    }
    
    _touchTimer = [[NSTimer alloc] initWithFireDate:[[NSDate alloc] initWithTimeIntervalSinceNow:0.27] interval:0.27 target:self selector:@selector(touchTimerEvent) userInfo:nil repeats:false];
    [[NSRunLoop mainRunLoop] addTimer:_touchTimer forMode:NSRunLoopCommonModes];
    
    [super touchesEnded:touches withEvent:event];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (_touchTimer != nil)
    {
        [_touchTimer invalidate];
        _touchTimer = nil;
    }
    
    [super touchesCancelled:touches withEvent:event];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (_touchTimer != nil)
    {
        [_touchTimer invalidate];
        _touchTimer = nil;
    }
    
    [super touchesMoved:touches withEvent:event];
}

- (void)touchTimerEvent
{
    if (_touchTimer != nil)
    {
        [_touchTimer invalidate];
        _touchTimer = nil;
    }
    
    __strong id delegate = self.delegate;
    if (delegate != nil && [delegate conformsToProtocol:@protocol(TGImageScrollViewDelegate)])
        [(id<TGImageScrollViewDelegate>)delegate scrollViewTapped];
}

- (void)doubleTapGestureRecognized:(UITapGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateRecognized)
    {
        __strong id delegate = self.delegate;
        if (delegate != nil && [delegate conformsToProtocol:@protocol(TGImageScrollViewDelegate)])
            [(id<TGImageScrollViewDelegate>)delegate scrollViewDoubleTapped:[recognizer locationInView:self]];
        
        if (_touchTimer != nil)
        {
            [_touchTimer invalidate];
            _touchTimer = nil;
        }
    }
}

- (void)longPressRecognized:(UILongPressGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateBegan)
    {
        __strong id delegate = self.delegate;
        if (delegate != nil && [delegate conformsToProtocol:@protocol(TGImageScrollViewDelegate)])
            [(id<TGImageScrollViewDelegate>)delegate scrollViewLongPressed];
        
        if (_touchTimer != nil)
        {
            [_touchTimer invalidate];
            _touchTimer = nil;
        }
    }
}

@end

@interface TGImageViewPage () <UIScrollViewDelegate, TGImageScrollViewDelegate>

@property (nonatomic, strong) TGRemoteImageView *imageView;
@property (nonatomic) CGSize imageSize;

@property (nonatomic, strong) UIScrollView *scrollView;

@property (nonatomic, strong) UIView *progressContainer;
@property (nonatomic, strong) TGCircularProgressView *progressView;

@property (nonatomic, strong) TGImageTransitionHelper *transitionHelper;

@property (nonatomic, strong) NSString *currentThumbnailPath;

@end

@implementation TGImageViewPage

@synthesize graphHandle = _graphHandle;

@synthesize watcherHandle = _watcherHandle;

@synthesize imageInfo = _imageInfo;
@synthesize itemId = _itemId;
@synthesize pageIndex = _pageIndex;

@synthesize imageView = _imageView;
@synthesize imageSize = _imageSize;

@synthesize scrollView = _scrollView;

@synthesize progressContainer = _progressContainer;
@synthesize progressView = _progressView;

@synthesize transitionHelper = _transitionHelper;

@synthesize currentThumbnailPath = _currentThumbnailPath;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        _graphHandle = [[SGraphHandle alloc] init];
        _graphHandle.delegate = self;
        
        _scrollView = [[TGImageScrollView alloc] initWithFrame:self.bounds];

        _scrollView.delegate = self;
        [self addSubview:_scrollView];
        
        _scrollView.delaysContentTouches = false;
        _scrollView.scrollsToTop = false;
        _scrollView.showsHorizontalScrollIndicator = false;
        _scrollView.showsVerticalScrollIndicator = false;
        _scrollView.alwaysBounceHorizontal = false;
        _scrollView.alwaysBounceVertical = false;
        
        _imageView = [[TGRemoteImageView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
        _imageView.useCache = false;
        _imageView.contentHints = TGRemoteImageContentHintLargeFile;
        
        _progressContainer = [[UIView alloc] initWithFrame:CGRectIntegral(CGRectMake((int)((self.frame.size.width - 50) / 2), (int)((self.frame.size.height - 50) / 2), 50, 50))];
        _progressContainer.userInteractionEnabled = false;
        _progressContainer.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
        _progressContainer.layer.zPosition = 2;
        _progressContainer.contentMode = UIViewContentModeScaleToFill;
        
        _progressContainer.alpha = 0.0f;
        _progressContainer.hidden = true;
        
        [_progressContainer addSubview:[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"CircularProgressBackgroundBig.png"]]];
        _progressView = [[TGCircularProgressView alloc] init];
        [_progressContainer addSubview:_progressView];
        
        UIView *progressContainer = _progressContainer;
        TGCircularProgressView *progressView = _progressView;
        
        if (false && (TGIsRetina() && cpuCoreCount() < 2))
        {
            _imageView.fadeTransition = true;
            _imageView.fadeTransitionDuration = 0.3;
            _imageView.hidden = true;
            
            /*_secondaryImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height)];
             _secondaryImageView.contentMode = UIViewContentModeScaleAspectFill;
             ((UIImageView *)_secondaryImageView).image = _placeholder;
             [self.view addSubview:_secondaryImageView];*/
        }
        else
        {
            _imageView.hidden = false;
            _imageView.fadeTransition = true;
            _imageView.fadeTransitionDuration = 0.1;
            _imageView.contentMode = UIViewContentModeScaleAspectFill;
        }
        
        [self addSubview:_progressContainer];
        
        _imageView.progressHandler = ^(__unused TGRemoteImageView *imageView, float progress)
        {
            if (progress >= 0.99f)
            {
                if (!progressContainer.hidden && progressContainer.alpha > FLT_EPSILON)
                {
                    [UIView animateWithDuration:0.2f animations:^
                    {
                        progressContainer.alpha = 0.0f;
                    } completion:^(BOOL finished)
                    {
                        if (finished)
                        {
                            progressContainer.hidden = true;
                        }
                    }];
                    
                    [progressView setProgress:1.0f];
                }
            }
            else
            {
                if (progress > 0.95f)
                    progress = 1.0f;
                
                if (progressContainer.hidden)
                {
                    progressContainer.hidden = false;
                    
                    if (progressContainer.alpha < 1.0f - FLT_EPSILON)
                    {
                        [UIView animateWithDuration:0.2f animations:^
                        {
                            progressContainer.alpha = 1.0f;
                        }];
                    }
                }
                
                [progressView setProgress:progress];
            }
        };
    }
    return self;
}

- (void)dealloc
{
    _graphHandle.delegate = nil;
    [[SGraph instance] removeWatcher:self];
}

- (void)loadImage:(TGImageInfo *)imageInfo placeholder:(UIImage *)placeholder willAnimateAppear:(bool)__unused willAnimateAppear
{
    if (_imageInfo == imageInfo)
        return;
    
    _imageInfo = imageInfo;
    _currentThumbnailPath = nil;
    
    _progressContainer.alpha = 0.0f;
    _progressContainer.hidden = true;
    
    [[SGraph instance] removeWatcher:self];
    
    if (imageInfo != nil)
    {
        CGSize screenSize = [TGViewController screenSize:UIDeviceOrientationPortrait];
        
        CGSize size = CGSizeZero;
        NSString *url = [imageInfo closestImageUrlWithHeight:(int)(MAX(screenSize.width, screenSize.height) * (TGIsRetina() ? 2 : 1)) resultingSize:&size];
        
        TGLog(@"Image size: %dx%d", (int)size.width, (int)size.height);
        
        if (TGIsRetina())
        {
            size.width = (int)(size.width / 2.0f);
            size.height = (int)(size.height / 2.0f);
        }
        
        _imageSize = size;
        _imageView.frame = CGRectMake(0, 0, size.width, size.height);
        _imageView.hidden = false;
        
        UIImage *thumbnailImage = placeholder;
        
        if (thumbnailImage == nil)
        {
            CGSize thumbnailPixelSize = CGSizeMake(100, 100);
            if (TGIsRetina())
            {
                thumbnailPixelSize.width *= 2;
                thumbnailPixelSize.height *= 2;
            }
            
            NSString *thumbnailUrl = [imageInfo closestImageUrlWithSize:thumbnailPixelSize resultingSize:NULL];
            
            thumbnailImage = [TGRemoteImageView imageFromCache:thumbnailUrl filter:@"mediaGridImage" cache:[TGRemoteImageView sharedCache]];
            _currentThumbnailPath = [TGRemoteImageView preloadImage:thumbnailUrl filter:@"mediaGridImage" cache:[TGRemoteImageView sharedCache] allowThumbnailCache:false watcher:self];
        }
        
        [_imageView loadImage:url filter:@"maybeScale" placeholder:thumbnailImage];
    }
    else
    {
        _imageView.hidden = true;
        [_imageView loadImage:nil];
    }
}

- (void)animateAppearFromImage:(UIImage *)image fromView:(UIView *)fromView aboveView:(UIView *)aboveView fromRect:(CGRect)fromRect toInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation completion:(dispatch_block_t)completion keepAspect:(bool)keepAspect
{
    CGSize screenSize = [TGViewController screenSizeForInterfaceOrientation:interfaceOrientation];
    
    CGFloat scaleWidth = screenSize.width / _imageSize.width;
    CGFloat scaleHeight = screenSize.height / _imageSize.height;
    CGFloat minScale = MIN(scaleWidth, scaleHeight);
    
    CGSize boundsSize = screenSize;
    CGRect contentsFrame = CGRectMake(0, 0, _imageSize.width * minScale, _imageSize.height * minScale);
    
    if (boundsSize.width > contentsFrame.size.width)
        contentsFrame.origin.x = (boundsSize.width - contentsFrame.size.width) / 2.0f;
    else
        contentsFrame.origin.x = 0;
    
    if (boundsSize.height > contentsFrame.size.height)
        contentsFrame.origin.y = (boundsSize.height - contentsFrame.size.height) / 2.0f;
    else
        contentsFrame.origin.y = 0;
    
    _imageView.hidden = false;
    [_imageView removeFromSuperview];
    [self addSubview:_imageView];
    
    //_imageView.contentMode = keepAspect ? UIViewContentModeScaleAspectFill : UIViewContentModeScaleToFill;
    
    _transitionHelper = [[TGImageTransitionHelper alloc] init];
    [_transitionHelper beginTransitionIn:_imageView fromImage:image fromView:fromView fromRectInWindowSpace:fromRect aboveView:aboveView toView:self toRectInWindowSpace:[self convertRect:contentsFrame toView:self.window] toInterfaceOrientation:interfaceOrientation completion:^
    {
        [self createScrollView];
        
        _transitionHelper = nil;
        
        if (completion)
            completion();
    } keepAspect:keepAspect];
    
    _progressContainer.autoresizingMask = 0;
    
    CGRect viewSourceRect = [self convertRect:fromRect fromView:self.window];
    
    CGSize sourceProgressSize = CGSizeMake(50, 50);
    _progressContainer.frame = CGRectIntegral(CGRectMake(viewSourceRect.origin.x + (viewSourceRect.size.width - sourceProgressSize.width) / 2, viewSourceRect.origin.y + (viewSourceRect.size.height - sourceProgressSize.height) / 2, sourceProgressSize.width, sourceProgressSize.height));
    
    [UIView animateWithDuration:0.3f animations:^
    {
        _progressContainer.frame = CGRectIntegral(CGRectMake((int)((self.frame.size.width - 50) / 2), (int)((self.frame.size.height - 50) / 2), 500, 50));
    } completion:^(BOOL finished)
    {
        if (finished)
        {   
            _progressContainer.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
        }
    }];
}

- (void)animateDisappearToImage:(UIImage *)__unused toImage toView:(UIView *)toView aboveView:(UIView *)aboveView toRect:(CGRect)toRect toContainerImage:(UIImage *)toContainerImage toInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation keepAspect:(bool)keepAspect
{
    CGRect imageFrame = [self convertRect:_imageView.frame fromView:_scrollView];
    [_imageView removeFromSuperview];
    [self addSubview:_imageView];
    _imageView.frame = imageFrame;
    
    _imageView.contentMode = UIViewContentModeScaleAspectFill;
    
    _transitionHelper = [[TGImageTransitionHelper alloc] init];
    _transitionHelper.fadingColor = [UIColor blackColor];
    [_transitionHelper beginTransitionOut:_imageView fromView:self toView:toView aboveView:aboveView interfaceOrientation:toInterfaceOrientation toRectInWindowSpace:toRect toImage:toContainerImage keepAspect:keepAspect];
    
    if (!CGSizeEqualToSize(toRect.size, CGSizeZero))
    {
        CGRect viewDestRect = [self convertRect:toRect fromView:self.window];
        
        _progressContainer.autoresizingMask = 0;
        
        [UIView animateWithDuration:0.3 animations:^
        {
            _progressContainer.alpha = 0.0f;
            
            CGSize sourceProgressSize = CGSizeMake(50, 50);
            _progressContainer.frame = CGRectIntegral(CGRectMake(viewDestRect.origin.x + (viewDestRect.size.width - sourceProgressSize.width) / 2, viewDestRect.origin.y + (viewDestRect.size.height - sourceProgressSize.height) / 2, sourceProgressSize.width, sourceProgressSize.height));
        }];
    }
    else
    {
        [UIView animateWithDuration:0.3 animations:^
        {
            _progressContainer.alpha = 0.0f;
        }];
    }
}

- (void)createScrollView
{
    _imageView.hidden = false;
    [_imageView removeFromSuperview];
    [_scrollView addSubview:_imageView];
    
    UIImage *mediumImage = [((TGRemoteImageView *)_imageView).currentImage mediumImage];
    if (mediumImage != nil)
    {
        [((TGRemoteImageView *)_imageView).currentImage setMediumImage:nil];
        [(TGRemoteImageView *)_imageView loadImage:mediumImage];
    }
    
    if (((TGRemoteImageView *)_imageView).fadeTransition)
        ((TGRemoteImageView *)_imageView).fadeTransitionDuration = 0.15;
    
    [self resetScrollView];
}

- (void)resetScrollView
{
    _imageView.contentMode = UIViewContentModeScaleToFill;
    
    _scrollView.minimumZoomScale = 1.0f;
    _scrollView.maximumZoomScale = 1.0f;
    _scrollView.zoomScale = 1.0f;
    _scrollView.contentSize = _imageSize;
    _imageView.frame = CGRectMake(0, 0, _imageSize.width, _imageSize.height);
    
    [self adjustScrollView];
    _scrollView.zoomScale = _scrollView.minimumZoomScale;
}

- (UIImage *)currentImage
{
    return [_imageView currentImage];
}

- (NSString *)currentImageUrl
{
    return [_imageView currentUrl];
}

- (void)scrollViewTapped
{
    __strong id<SGraphWatcher> watcher = _watcherHandle.delegate;
    if (watcher != nil && [watcher respondsToSelector:@selector(graphActionRequested:options:)])
    {
        [watcher graphActionRequested:@"animateDisappear" options:nil];
    }
}

- (void)scrollViewDoubleTapped:(CGPoint)point
{
    if (ABS(_scrollView.zoomScale - _scrollView.minimumZoomScale) < FLT_EPSILON)
    {
        CGPoint pointInView = [_scrollView convertPoint:point toView:_imageView];
        
        CGFloat newZoomScale = _scrollView.maximumZoomScale;
        newZoomScale = MIN(newZoomScale, _scrollView.maximumZoomScale);
        
        CGSize scrollViewSize = _scrollView.bounds.size;
        
        CGFloat w = scrollViewSize.width / newZoomScale;
        CGFloat h = scrollViewSize.height / newZoomScale;
        CGFloat x = pointInView.x - (w / 2.0f);
        CGFloat y = pointInView.y - (h / 2.0f);
        
        CGRect rectToZoomTo = CGRectMake(x, y, w, h);
        
        [_scrollView zoomToRect:rectToZoomTo animated:true];
    }
    else
    {
        [_scrollView setZoomScale:_scrollView.minimumZoomScale animated:true];
    }
}

- (void)scrollViewLongPressed
{
    if (_imageView.currentUrl != nil && _imageView.currentImage != nil)
    {
        id<SGraphWatcher> watcher = _watcherHandle.delegate;
        if (watcher != nil && [watcher respondsToSelector:@selector(graphActionRequested:options:)])
        {
            [watcher graphActionRequested:@"pageLongPressed" options:[[NSDictionary alloc] initWithObjectsAndKeys:[[NSNumber alloc] initWithInt:_itemId], @"itemId", nil]];
        }
    }
}

- (void)scrollViewDidZoom:(UIScrollView *)__unused scrollView
{
    [self adjustScrollView];
}

- (void)scrollViewDidEndZooming:(UIScrollView *)__unused scrollView withView:(UIView *)__unused view atScale:(float)__unused scale
{
    [self adjustScrollView];
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)__unused scrollView
{
    return _imageView;
}

- (void)adjustScrollView
{
    if (_imageSize.width < FLT_EPSILON || _imageSize.height < FLT_EPSILON)
        return;
    
    CGFloat scaleWidth = _scrollView.frame.size.width / _imageSize.width;
    CGFloat scaleHeight = _scrollView.frame.size.height / _imageSize.height;
    CGFloat minScale = MIN(scaleWidth, scaleHeight);
    
    if (_scrollView.minimumZoomScale != minScale)
        _scrollView.minimumZoomScale = minScale;
    if (_scrollView.maximumZoomScale != minScale * 2.0f)
        _scrollView.maximumZoomScale = minScale * 2.0f;
    
    CGSize boundsSize = _scrollView.bounds.size;
    CGRect contentsFrame = _imageView.frame;
    
    if (boundsSize.width > contentsFrame.size.width)
        contentsFrame.origin.x = (boundsSize.width - contentsFrame.size.width) / 2.0f;
    else
        contentsFrame.origin.x = 0;
    
    if (boundsSize.height > contentsFrame.size.height)
        contentsFrame.origin.y = (boundsSize.height - contentsFrame.size.height) / 2.0f;
    else
        contentsFrame.origin.y = 0;
    
    _imageView.frame = contentsFrame;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    if (!CGRectEqualToRect(_scrollView.frame, self.bounds))
    {
        _scrollView.frame = self.bounds;
        [self adjustScrollView];
        _scrollView.zoomScale = _scrollView.minimumZoomScale;
    }
}

- (void)graphNodeRetrieveCompleted:(int)resultCode path:(NSString *)path node:(SGraphNode *)node
{
    dispatch_async(dispatch_get_main_queue(), ^
    {
        if ([path isEqualToString:_currentThumbnailPath])
        {
            if (resultCode == GraphRequestStatusSuccess)
            {
                UIImage *image = ((SGraphImageNode *)node).image;
                if (image != nil)
                {
                    [_imageView loadPlaceholder:image];
                }
            }
        }
    });
}

@end
