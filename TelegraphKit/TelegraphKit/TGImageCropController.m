#import "TGImageCropController.h"

#import "TGImageUtils.h"

#import "TGRemoteImageView.h"

@interface TGCropScrollView : UIScrollView

@property (nonatomic) UIEdgeInsets extendedInsets;

@end

@implementation TGCropScrollView

@synthesize extendedInsets = _extendedInsets;

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    UIView *result = [super hitTest:point withEvent:event];
    if (result != nil)
        return result;
    
    //CGRect frame = self.frame;
    //if (CGRectContainsPoint(CGRectMake(-_extendedInsets.left, -_extendedInsets.top, frame.size.width + _extendedInsets.left + _extendedInsets.right, frame.size.height + _extendedInsets.top + _extendedInsets.bottom), point))
        return self;
    
    return nil;
}

@end

#pragma mark -

@interface TGImageCropController () <TGViewControllerNavigationBarAppearance, UIScrollViewDelegate>

@property (nonatomic, strong) UIView *panelView;
@property (nonatomic, strong) UIButton *cancelButton;
@property (nonatomic, strong) UIButton *doneButton;

@property (nonatomic, strong) UIImageView *fieldSquareView;
@property (nonatomic, strong) UIView *leftShadeView;
@property (nonatomic, strong) UIView *rightShadeView;
@property (nonatomic, strong) UIView *topShadeView;
@property (nonatomic, strong) UIView *bottomShadeView;

@property (nonatomic, strong) TGCropScrollView *scrollView;
@property (nonatomic, strong) TGRemoteImageView *imageView;

@property (nonatomic) CGSize imageSize;
@property (nonatomic, strong) UIImage *thumbnailImage;
@property (nonatomic, strong) NSString *imageUrl;

@end

@implementation TGImageCropController

- (id)initWithAsset:(ALAsset *)asset
{
    self = [super initWithNibName:nil bundle:nil];
    if (self)
    {
        [self commonInit];
        
        if ([ALAssetRepresentation instancesRespondToSelector:@selector(dimensions)])
        {
            _imageSize = asset.defaultRepresentation.dimensions;
        }
        else
        {
            CGImageRef fullImage = asset.defaultRepresentation.fullScreenImage;
            if (fullImage != NULL)
                _imageSize = CGSizeMake(CGImageGetWidth(fullImage), CGImageGetHeight(fullImage));
        }
        
        _thumbnailImage = [[UIImage alloc] initWithCGImage:asset.aspectRatioThumbnail];
        _imageUrl = [[NSString alloc] initWithFormat:@"asset-original:%@", [asset.defaultRepresentation.url absoluteString]];
    }
    return self;
}

- (id)initWithImageInfo:(TGImageInfo *)imageInfo thumbnail:(UIImage *)thumbnail
{
    self = [super initWithNibName:nil bundle:nil];
    if (self)
    {
        [self commonInit];
        
        CGSize size = CGSizeZero;
        _imageUrl = [imageInfo closestImageUrlWithSize:CGSizeMake(1136, 1136) resultingSize:&size pickLargest:true];
        _imageSize = size;
        _thumbnailImage = thumbnail;
    }
    return self;
}

- (void)commonInit
{
    self.wantsFullScreenLayout = true;
    self.automaticallyManageScrollViewInsets = false;
    self.autoManageStatusBarBackground = false;
    
    _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:true];
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

- (bool)statusBarShouldBeHidden
{
    return false;
}

- (UIStatusBarStyle)viewControllerPreferredStatusBarStyle
{
    return UIStatusBarStyleBlackTranslucent;
}

- (void)loadView
{
    [super loadView];
    
    self.view.clipsToBounds = true;
    self.view.backgroundColor = [UIColor blackColor];
    
    float retinaPixel = TGIsRetina() ? 0.5f : 0.0f;
    
    _imageView = [[TGRemoteImageView alloc] init];
    _imageView.cache = _customCache;
    _imageView.fadeTransition = true;
    
    _scrollView = [[TGCropScrollView alloc] init];
    _scrollView.delegate = self;
    _scrollView.showsHorizontalScrollIndicator = false;
    _scrollView.showsVerticalScrollIndicator = false;
    _scrollView.clipsToBounds = false;
    _scrollView.decelerationRate = UIScrollViewDecelerationRateFast;
    [_scrollView addSubview:_imageView];
    [self.view addSubview:_scrollView];
    
    UIImage *rawFieldImage = [UIImage imageNamed:@"ImageCrop_Field.png"];
    _fieldSquareView = [[UIImageView alloc] initWithImage:[rawFieldImage stretchableImageWithLeftCapWidth:(int)(rawFieldImage.size.width / 2) topCapHeight:(int)(rawFieldImage.size.height / 2)]];
    [self.view addSubview:_fieldSquareView];
    
    _leftShadeView = [[UIView alloc] init];
    _leftShadeView.userInteractionEnabled = false;
    _rightShadeView = [[UIView alloc] init];
    _rightShadeView.userInteractionEnabled = false;
    _topShadeView = [[UIView alloc] init];
    _topShadeView.userInteractionEnabled = false;
    _bottomShadeView = [[UIView alloc] init];
    _bottomShadeView.userInteractionEnabled = false;
    
    [self.view addSubview:_leftShadeView];
    [self.view addSubview:_rightShadeView];
    [self.view addSubview:_topShadeView];
    [self.view addSubview:_bottomShadeView];
    
    _leftShadeView.backgroundColor = UIColorRGBA(0x000000, 0.4f);
    _rightShadeView.backgroundColor = _leftShadeView.backgroundColor;
    _topShadeView.backgroundColor = _leftShadeView.backgroundColor;
    _bottomShadeView.backgroundColor = _leftShadeView.backgroundColor;
    
    _panelView = [[UIView alloc] initWithFrame:CGRectMake(0, self.view.frame.size.height - 48, self.view.frame.size.width, 48)];
    _panelView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [self.view addSubview:_panelView];
    
    UIImageView *panelBackgroundView = [[UIImageView alloc] initWithFrame:_panelView.bounds];
    panelBackgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    panelBackgroundView.image = [UIImage imageNamed:@"ImagePickerPanel.png"];
    [_panelView addSubview:panelBackgroundView];
    
    _cancelButton = [[UIButton alloc] initWithFrame:CGRectMake(7, 7 + retinaPixel, 62, 34)];
    _cancelButton.exclusiveTouch = true;
    [_cancelButton setBackgroundImage:[[UIImage imageNamed:@"ImagePickerGrayButton.png"] stretchableImageWithLeftCapWidth:11 topCapHeight:0] forState:UIControlStateNormal];
    [_cancelButton setBackgroundImage:[[UIImage imageNamed:@"ImagePickerGrayButton_Highlighted.png"] stretchableImageWithLeftCapWidth:11 topCapHeight:0] forState:UIControlStateHighlighted];
    [_cancelButton setTitle:self.navigationController.viewControllers.count == 1 ? TGLocalized(@"Common.Cancel") : TGLocalized(@"Common.Back") forState:UIControlStateNormal];
    [_cancelButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [_cancelButton setTitleShadowColor:UIColorRGB(0x181818) forState:UIControlStateNormal];
    _cancelButton.titleLabel.font = [UIFont boldSystemFontOfSize:TGIsRetina() ? 12.5f : 13.0f];
    if (TGIsRetina())
        _cancelButton.contentEdgeInsets = UIEdgeInsetsMake(0.5f, 0, 0, 0);
    _cancelButton.titleLabel.shadowOffset = CGSizeMake(0, -1);
    _cancelButton.exclusiveTouch = true;
    [_cancelButton addTarget:self action:@selector(cancelButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    [_panelView addSubview:_cancelButton];
    
    _doneButton = [[UIButton alloc] initWithFrame:CGRectMake(_panelView.frame.size.width - 7 - 62, 7 + retinaPixel, 62, 34)];
    _doneButton.exclusiveTouch = true;
    _doneButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [_doneButton setBackgroundImage:[[UIImage imageNamed:@"ImagePickerBlueButton.png"] stretchableImageWithLeftCapWidth:11 topCapHeight:0] forState:UIControlStateNormal];
    [_doneButton setBackgroundImage:[[UIImage imageNamed:@"ImagePickerBlueButton_Highlighted.png"] stretchableImageWithLeftCapWidth:11 topCapHeight:0] forState:UIControlStateHighlighted];
    [_doneButton setTitle:TGLocalized(@"MediaPicker.Choose") forState:UIControlStateNormal];
    [_doneButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [_doneButton setTitleShadowColor:UIColorRGBA(0x044d94, 0.6f) forState:UIControlStateNormal];
    [_doneButton setTitleColor:UIColorRGBA(0xffffff, 0.6f) forState:UIControlStateDisabled];
    _doneButton.adjustsImageWhenDisabled = false;
    _doneButton.adjustsImageWhenHighlighted = false;
    _doneButton.titleLabel.font = [UIFont boldSystemFontOfSize:TGIsRetina() ? 12.5f : 13.0f];
    if (TGIsRetina())
        _doneButton.contentEdgeInsets = UIEdgeInsetsMake(0.5f, 0, 0, 0);
    _doneButton.titleLabel.shadowOffset = CGSizeMake(0, -1);
    _doneButton.exclusiveTouch = true;
    [_doneButton addTarget:self action:@selector(doneButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    [_panelView addSubview:_doneButton];
    
    UILabel *galleryNameLabel = [[UILabel alloc] initWithFrame:CGRectMake(70, 0, _panelView.frame.size.width - 140, _panelView.frame.size.height)];
    galleryNameLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    galleryNameLabel.contentMode = UIViewContentModeCenter;
    galleryNameLabel.textAlignment = UITextAlignmentCenter;
    galleryNameLabel.backgroundColor = [UIColor clearColor];
    galleryNameLabel.textColor = [UIColor whiteColor];
    galleryNameLabel.shadowColor = [UIColor blackColor];
    galleryNameLabel.shadowOffset = CGSizeMake(0, -1);
    galleryNameLabel.font = [UIFont boldSystemFontOfSize:18];
    [_panelView addSubview:galleryNameLabel];
    
    galleryNameLabel.text = @"Move and Scale";
    
    _doneButton.enabled = false;
    
    ASHandle *actionHandle = _actionHandle;
    
    [_imageView setProgressHandler:^(__unused TGRemoteImageView *imageView, float progress)
    {
        if (progress == 1.0f)
        {
            [actionHandle requestAction:@"imageLoaded" options:nil];
        }
    }];
    
    [_imageView loadImage:_imageUrl filter:nil placeholder:_thumbnailImage];
    
    [self updateField];
    
    _imageView.frame = CGRectMake(0, 0, _imageSize.width, _imageSize.height);
    [self adjustScrollView];
    
    _scrollView.zoomScale = _scrollView.minimumZoomScale;
    
    CGSize contentSize = _scrollView.contentSize;
    CGSize viewSize = _scrollView.frame.size;
    _scrollView.contentOffset = CGPointMake(MAX(0, floorf((contentSize.width - viewSize.width) / 2)), MAX(0, floorf((contentSize.height - viewSize.height) / 2)));
}

- (void)doUnloadView
{
    _scrollView.delegate = nil;
}

- (void)updateField
{
    CGSize screenSize = [TGViewController screenSizeForInterfaceOrientation:self.interfaceOrientation];
    
    _fieldSquareView.frame = CGRectMake(0, floorf((screenSize.height - _panelView.frame.size.height - 320) / 2), 320, 320);
    
    _leftShadeView.frame = CGRectMake(0, 0, _fieldSquareView.frame.origin.x, screenSize.height - _panelView.frame.size.height);
    _rightShadeView.frame = CGRectMake(_fieldSquareView.frame.origin.x + _fieldSquareView.frame.size.width, 0, screenSize.width - (_fieldSquareView.frame.origin.x + _fieldSquareView.frame.size.width), screenSize.height - _panelView.frame.size.height);
    _topShadeView.frame = CGRectMake(_leftShadeView.frame.size.width, 0, _rightShadeView.frame.origin.x - _leftShadeView.frame.size.width, _fieldSquareView.frame.origin.y);
    _bottomShadeView.frame = CGRectMake(_leftShadeView.frame.size.width, _fieldSquareView.frame.origin.y + _fieldSquareView.frame.size.height, _rightShadeView.frame.origin.x - _leftShadeView.frame.size.width, screenSize.height - _panelView.frame.size.height - (_fieldSquareView.frame.origin.y + _fieldSquareView.frame.size.height));
    
    _scrollView.frame = _fieldSquareView.frame;
    _scrollView.extendedInsets = UIEdgeInsetsMake(_topShadeView.frame.size.height, _leftShadeView.frame.size.width, _bottomShadeView.frame.size.height, _rightShadeView.frame.size.width);
}

#pragma mark -

- (void)cancelButtonPressed
{
    [self.navigationController popViewControllerAnimated:true];
}

- (void)doneButtonPressed
{
    UIImage *image = [_imageView currentImage];
    if (image == nil)
        return;
    
    CGSize imageSize = image.size;
    
    float scale = 1.0f / _scrollView.zoomScale / (_imageSize.width / imageSize.width);
    
    CGPoint contentOffset = _scrollView.contentOffset;
    
    CGRect visibleRect;
    visibleRect.origin.x = contentOffset.x * scale;
    visibleRect.origin.y = contentOffset.y * scale;
    visibleRect.size.width = _scrollView.frame.size.width * scale;
    visibleRect.size.height = _scrollView.frame.size.height * scale;
    
    UIImage *croppedImage = TGFixOrientationAndCrop(image, visibleRect, CGSizeMake(600, 600));
    [_watcherHandle requestAction:@"imageCropResult" options:croppedImage];
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
    CGSize imageSize = _imageSize;
    float imageScale = 1.0f;
    imageSize.width /= imageScale;
    imageSize.height /= imageScale;
    
    CGSize boundsSize = _scrollView.bounds.size;
    
    CGFloat scaleWidth = boundsSize.width / imageSize.width;
    CGFloat scaleHeight = boundsSize.height / imageSize.height;
    CGFloat minScale = MAX(scaleWidth, scaleHeight);
    
    if (_scrollView.minimumZoomScale != minScale)
        _scrollView.minimumZoomScale = minScale;
    if (_scrollView.maximumZoomScale != minScale * 3.0f)
        _scrollView.maximumZoomScale = minScale * 3.0f;
    
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

- (void)actionStageActionRequested:(NSString *)action options:(id)__unused options
{
    if ([action isEqualToString:@"imageLoaded"])
    {
        _doneButton.enabled = true;
    }
}

@end
