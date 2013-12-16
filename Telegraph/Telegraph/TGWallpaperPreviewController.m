#import "TGWallpaperPreviewController.h"

#import "TGRemoteImageView.h"

#import "TGInterfaceAssets.h"

#import "TGHighlightableButton.h"

#import "TGImageUtils.h"

#import "TGLinearProgressView.h"

@interface TGWallpaperPreviewController () <TGViewControllerNavigationBarAppearance, UIScrollViewDelegate>

@property (nonatomic, strong) NSDictionary *wallpaperInfo;
@property (nonatomic, strong) UIImage *image;

@property (nonatomic, strong) TGRemoteImageView *imageView;
@property (nonatomic, strong) UIView *panelView;

@property (nonatomic, strong) UIScrollView *scrollView;

@property (nonatomic, strong) TGHighlightableButton *setButton;

@end

@implementation TGWallpaperPreviewController

@synthesize actionHandle = _actionHandle;

@synthesize watcherHandle = _watcherHandle;

@synthesize wallpaperInfo = _wallpaperInfo;
@synthesize image = _image;

@synthesize imageView = _imageView;
@synthesize panelView = _panelView;

@synthesize scrollView = _scrollView;

@synthesize setButton = _setButton;

- (id)initWithWallpaperInfo:(NSDictionary *)wallpaperInfo
{
    self = [super initWithNibName:nil bundle:nil];
    if (self)
    {
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:true];
        
        self.wantsFullScreenLayout = true;
        
        _wallpaperInfo = wallpaperInfo;
    }
    return self;
}

- (id)initWithImage:(UIImage *)image
{
    self = [super initWithNibName:nil bundle:nil];
    if (self)
    {
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:true];
        
        self.wantsFullScreenLayout = true;
        
        _image = image;
    }
    return self;
}

- (void)dealloc
{
    [_actionHandle reset];
    
    [self doUnloadView];
}

- (UIBarStyle)requiredNavigationBarStyle
{
    return UIBarStyleDefault;
}

- (bool)navigationBarShouldBeHidden
{
    return true;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return interfaceOrientation == UIInterfaceOrientationPortrait;
}

- (BOOL)shouldAutorotate
{
    return false;
}

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}

- (UIStatusBarStyle)viewControllerPreferredStatusBarStyle
{
    return UIStatusBarStyleBlackTranslucent;
}

- (void)loadView
{
    [super loadView];
    
    UIView *containerView = [[UIView alloc] initWithFrame:self.view.bounds];
    containerView.clipsToBounds = true;
    containerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:containerView];
    
    //self.view.backgroundColor = [UIColor blackColor];
    
    CGSize screenSize = [TGViewController screenSizeForInterfaceOrientation:self.interfaceOrientation];
    
    float imageHeight = ([TGViewController isWidescreen] ? 501 : 460);
    _imageView = [[TGRemoteImageView alloc] initWithFrame:CGRectMake(0, 20 + floorf((screenSize.height - 20 - ([TGViewController isWidescreen] ? 96 : 0) - imageHeight) / 2), screenSize.width, imageHeight)];
    _imageView.contentMode = UIViewContentModeScaleAspectFill;
    [containerView addSubview:_imageView];
    
    UIImage *panelImage = [TGViewController isWidescreen] ? [UIImage imageNamed:@"WallpaperPanel.png"] : [UIImage imageNamed:@"WallpaperPanel_Transparent.png"];
    _panelView = [[UIView alloc] initWithFrame:CGRectMake(0, screenSize.height - panelImage.size.height, screenSize.width, panelImage.size.height)];
    UIImageView *panelBackgroundView = [[UIImageView alloc] initWithFrame:_panelView.bounds];
    panelBackgroundView.image = panelImage;
    panelBackgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [_panelView addSubview:panelBackgroundView];
    [containerView addSubview:_panelView];
    
    UIImage *rawCancelButtonImage = [UIImage imageNamed:@"WallpaperBlackButton.png"];
    UIImage *cancelButtonImage = [rawCancelButtonImage stretchableImageWithLeftCapWidth:(int)(rawCancelButtonImage.size.width / 2) topCapHeight:0];

    UIImage *rawDoneButtonImage = [UIImage imageNamed:@"WallpaperGrayButton.png"];
    UIImage *doneButtonImage = [rawDoneButtonImage stretchableImageWithLeftCapWidth:(int)(rawDoneButtonImage.size.width / 2) topCapHeight:0];

    UIImage *rawHighlightedButtonImage = [UIImage imageNamed:@"WallpaperGrayButton_Highlighted.png"];
    UIImage *highlightedButtonImage = [rawHighlightedButtonImage stretchableImageWithLeftCapWidth:(int)(rawHighlightedButtonImage.size.width / 2) topCapHeight:0];
    
    float retinaPixel = TGIsRetina() ? 0.5f : 0.0f;
    
    TGHighlightableButton *cancelButton = [[TGHighlightableButton alloc] initWithFrame:CGRectMake(17, 26, 131, cancelButtonImage.size.height)];
    [cancelButton addTarget:self action:@selector(cancelButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    [cancelButton setBackgroundImage:cancelButtonImage forState:UIControlStateNormal];
    [cancelButton setBackgroundImage:highlightedButtonImage forState:UIControlStateHighlighted];
    [cancelButton setTitle:TGLocalized(@"Common.Cancel") forState:UIControlStateNormal];
    cancelButton.titleLabel.font = [UIFont boldSystemFontOfSize:16 + retinaPixel];
    cancelButton.titleLabel.shadowOffset = CGSizeMake(0, -1);
    [cancelButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [cancelButton setTitleShadowColor:[UIColor blackColor] forState:UIControlStateNormal];
    [cancelButton setTitleShadowColor:UIColorRGB(0x085cc4) forState:UIControlStateHighlighted];
    [_panelView addSubview:cancelButton];
    
    _setButton = [[TGHighlightableButton alloc] initWithFrame:CGRectMake(_panelView.frame.size.width - 17 - 131, 26, 131, doneButtonImage.size.height)];
    [_setButton addTarget:self action:@selector(doneButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    _setButton.reverseTitleShadow = true;
    _setButton.normalTitleShadowOffset = CGSizeMake(0, 1);
    [_setButton setBackgroundImage:doneButtonImage forState:UIControlStateNormal];
    [_setButton setBackgroundImage:highlightedButtonImage forState:UIControlStateHighlighted];
    [_setButton setTitle:TGLocalized(@"Wallpaper.Set") forState:UIControlStateNormal];
    _setButton.titleLabel.font = [UIFont boldSystemFontOfSize:16 + retinaPixel];
    _setButton.titleLabel.shadowOffset = CGSizeMake(0, 1);
    [_setButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [_setButton setTitleColor:UIColorRGBA(0x000000, 0.5f) forState:UIControlStateDisabled];
    [_setButton setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
    [_setButton setTitleShadowColor:UIColorRGBA(0xffffff, 0.3f) forState:UIControlStateNormal];
    [_setButton setTitleShadowColor:UIColorRGB(0x085cc4) forState:UIControlStateHighlighted];
    [_panelView addSubview:_setButton];
    
    if (_image != nil)
    {
        _scrollView = [[UIScrollView alloc] initWithFrame:_imageView.frame];
        [containerView insertSubview:_scrollView belowSubview:_imageView];
        
        _scrollView.showsHorizontalScrollIndicator = false;
        _scrollView.showsVerticalScrollIndicator = false;
        _scrollView.delegate = self;
        [_imageView removeFromSuperview];
        [_scrollView addSubview:_imageView];
        
        _imageView.contentMode = UIViewContentModeScaleToFill;
        [_imageView loadImage:_image];
        
        _imageView.frame = CGRectMake(0, 0, _image.size.width, _image.size.height);
        
        [self adjustScrollView];
        _scrollView.zoomScale = _scrollView.minimumZoomScale;
        
        CGSize contentSize = _scrollView.contentSize;
        CGSize viewSize = _scrollView.frame.size;
        _scrollView.contentOffset = CGPointMake(MAX(0, floorf((contentSize.width - viewSize.width) / 2)), MAX(0, floorf((contentSize.height - viewSize.height) / 2)));
    }
    else
    {
        TGImageInfo *imageInfo = [_wallpaperInfo objectForKey:@"imageInfo"];
        NSString *url = [imageInfo closestImageUrlWithSize:CGSizeMake(640, 922) resultingSize:NULL];
        if (url != nil)
        {
            NSString *imageUrl = nil;
            if ([url rangeOfString:@"://"].location != NSNotFound)
                imageUrl = [url substringFromIndex:[url rangeOfString:@"://"].location + 3];
            else
                imageUrl = url;
            
            if ([imageUrl isEqualToString:@"wallpaper-original-default"])
            {
                _imageView.frame = CGRectMake(0, floorf((screenSize.height - 20 - ([TGViewController isWidescreen] ? 96 : 0) - imageHeight) / 2), screenSize.width, imageHeight + 20);
                _imageView.backgroundColor = [[TGInterfaceAssets instance] blueLinenBackground];
                UIImage *rawImage = [UIImage imageNamed:@"ConversationBackgroundShadow.png"];
                UIImage *backgroundOverlay = [rawImage stretchableImageWithLeftCapWidth:(int)(rawImage.size.width / 2) topCapHeight:(int)(rawImage.size.height / 2)];

                UIImageView *backgroundOverlayView = [[UIImageView alloc] initWithFrame:_imageView.bounds];
                backgroundOverlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                backgroundOverlayView.image = backgroundOverlay;
                [_imageView addSubview:backgroundOverlayView];
            }
            else if ([imageUrl isEqualToString:@"wallpaper-original-pattern-default"])
            {
                NSString *filePath = [[NSBundle mainBundle] pathForResource:imageUrl ofType:@"jpg"];
                if (filePath != nil)
                {
                    UIImage *image = [[UIImage alloc] initWithContentsOfFile:filePath];
                    [_imageView loadImage:image];
                }
            }
            else
            {
                ASHandle *actionHandle = _actionHandle;
                
                _imageView.contentHints = TGRemoteImageContentHintLoadFromDiskSynchronously;
                _imageView.useCache = false;
                _imageView.fadeTransition = true;
                _imageView.fadeTransitionDuration = 0.4;
                _imageView.placeholderOverlay = [[TGReusableView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
                _imageView.placeholderOverlay.frame = CGRectOffset(_imageView.placeholderOverlay.frame, floorf((_imageView.frame.size.width - _imageView.placeholderOverlay.frame.size.width) / 2), floorf((_imageView.frame.size.height - _imageView.placeholderOverlay.frame.size.height) / 2) - ([TGViewController isWidescreen] ? 0 : 45));
                _imageView.placeholderOverlay.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
                
                UIImage *rawProgressBackground = [UIImage imageNamed:@"InlineUploadBackground_Mono.png"];
                UIImage *rawProgressForeground = [UIImage imageNamed:@"InlineUploadForeground.png"];
                TGLinearProgressView *progressView = [[TGLinearProgressView alloc] initWithBackgroundImage:[rawProgressBackground stretchableImageWithLeftCapWidth:(int)(rawProgressBackground.size.width / 2) topCapHeight:0] progressImage:[rawProgressForeground stretchableImageWithLeftCapWidth:(int)(rawProgressForeground.size.width / 2) topCapHeight:0]];
                progressView.frame = CGRectMake(floorf((_imageView.placeholderOverlay.frame.size.width - 160) / 2), 10, 160, rawProgressBackground.size.height);
                progressView.tag = 100;
                progressView.alwaysShowMinimum = true;
                [progressView setProgress:0.0f];
                [_imageView.placeholderOverlay addSubview:progressView];
                
                _imageView.progressHandler = ^(TGRemoteImageView *imageView, float progress)
                {
                    TGLinearProgressView *progressView = (TGLinearProgressView *)[imageView.placeholderOverlay viewWithTag:100];
                    [UIView animateWithDuration:0.1 delay:0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveLinear animations:^
                    {
                        [progressView setProgress:progress];
                    } completion:nil];
                    
                    // strict equality
                    if (progress == 1.0)
                    {
                        [actionHandle requestAction:@"imageLoaded" options:[imageView currentImage]];
                    }
                    else
                    {
                        [actionHandle requestAction:@"imageLoading" options:nil];
                    }
                };
                
                UIImage *placeholder = nil;
                NSString *url = [imageInfo closestImageUrlWithWidth:172 resultingSize:NULL];
                if (url != nil)
                    placeholder = [[UIImage alloc] initWithContentsOfFile:[[TGRemoteImageView sharedCache] pathForCachedData:url]];
                if (placeholder == nil)
                    placeholder = [UIImage imageNamed:@"AttachmentImagePlaceholder.png"];
                
                [_imageView loadImage:imageUrl filter:nil placeholder:placeholder];
            }
        }
    }
}

- (void)doUnloadView
{
    _scrollView.delegate = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    if (self.navigationController != nil)
    {
        [self.navigationController setNavigationBarHidden:true animated:animated];
        [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackOpaque animated:animated];
    }
    
    [super viewWillAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    if (self.navigationController != nil)
    {
        [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackTranslucent animated:animated];
    }
}

#pragma mark -

- (void)cancelButtonPressed
{
    if (self.navigationController != nil)
    {
        [self.navigationController popViewControllerAnimated:true];
    }
    else
        [_watcherHandle requestAction:@"wallpaperSelected" options:nil];
}

- (void)doneButtonPressed
{
    if (_image != nil)
    {
        float scale = 1.0f / _scrollView.zoomScale;
        
        CGRect visibleRect;
        visibleRect.origin.x = _scrollView.contentOffset.x * scale;
        visibleRect.origin.y = _scrollView.contentOffset.y * scale;
        visibleRect.size.width = _scrollView.bounds.size.width * scale;
        visibleRect.size.height = _scrollView.bounds.size.height * scale;
        
        UIImage *croppedImage = TGFixOrientationAndCrop(_image, visibleRect, TGFitSize(visibleRect.size, CGSizeMake(1002, 1002)));
        
        [_watcherHandle requestAction:@"wallpaperImageSelected" options:croppedImage];
    }
    else
    {
        [_watcherHandle requestAction:@"wallpaperSelected" options:_wallpaperInfo];
    }
}

#pragma mark -

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
    if (_image == nil)
        return;
    
    CGSize imageSize = _image.size;
    float imageScale = _image.scale;
    imageSize.width /= imageScale;
    imageSize.height /= imageScale;
    
    CGFloat scaleWidth = _scrollView.frame.size.width / imageSize.width;
    CGFloat scaleHeight = _scrollView.frame.size.height / imageSize.height;
    CGFloat minScale = MAX(scaleWidth, scaleHeight);
    
    if (_scrollView.minimumZoomScale != minScale)
        _scrollView.minimumZoomScale = minScale;
    if (_scrollView.maximumZoomScale != minScale * 3.0f)
        _scrollView.maximumZoomScale = minScale * 3.0f;
    
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

#pragma mark -

- (void)actionStageActionRequested:(NSString *)action options:(id)options
{
    if ([action isEqualToString:@"imageLoaded"])
    {
        if (options != nil)
        {
            _setButton.enabled = true;
        }
    }
    else if ([action isEqualToString:@"imageLoading"])
    {
        _setButton.enabled = false;
    }
}

@end
