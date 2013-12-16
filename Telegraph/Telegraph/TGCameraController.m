#if TG_USE_CUSTOM_CAMERA

#import "TGCameraController.h"

#import "TGAppDelegate.h"

#import "GPUImage.h"

#import "TGPasstroughFilter.h"

#import "TGImageUtils.h"

#import "Endian.h"

#import "TGRemoteImageView.h"

#import "TGImageTransitionHelper.h"

#import <Accelerate/Accelerate.h>

typedef enum {
    TGCameraControllerStateEmpty = -1,
    TGCameraControllerStateCamera = 0,
    TGCameraControllerStateEditing = 2
} TGCameraControllerState;

static UIImage *makeCameraButtonTextImage(NSString *text, bool isButtonImage)
{
    if (text == nil)
        return nil;
    
    NSString *cacheKey = [[NSString alloc] initWithFormat:@"%@::%d", text, isButtonImage ? 1 : 0];
    
    static NSMutableDictionary *imageCache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        imageCache = [[NSMutableDictionary alloc] init];
    });
    
    UIImage *cacheImage = [imageCache objectForKey:cacheKey];
    if (cacheImage != nil)
        return cacheImage;
    
    UIFont *font = [UIFont boldSystemFontOfSize:14];
    CGSize size = [text sizeWithFont:font];
    size.width = (int)size.width + 2;
    UIGraphicsBeginImageContextWithOptions(size, false, 0.0f);
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetShadowWithColor(context, CGSizeMake(0, 1), 2.0f, UIColorRGBA(0x000000, 0.3f).CGColor);
    CGContextSetFillColorWithColor(context, UIColorRGBA(0xffffff, isButtonImage ? 1.0f : 0.72f).CGColor);
    
    [text drawInRect:CGRectMake(1, 0, size.width, size.height) withFont:font];
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    [imageCache setObject:image forKey:cacheKey];
    
    return image;
}

static AVCaptureDevicePosition currentCameraPosition = AVCaptureDevicePositionBack;

@interface TGCameraController () <UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIScrollViewDelegate>

@property (nonatomic) TGCameraControllerState state;

@property (nonatomic) bool isDismissed;

@property (nonatomic, strong) UIView *cameraPanelTop;
@property (nonatomic, strong) UIView *cameraPanelBottom;

@property (nonatomic, strong) UIView *editingPanelTop;
@property (nonatomic, strong) UIView *editingPanelBottom;

@property (nonatomic, strong) UIButton *flashButton;
@property (nonatomic, strong) UIImageView *flashButtonOnLabel;
@property (nonatomic, strong) UIImageView *flashButtonOffLabel;

@property (nonatomic, strong) UIImageView *fadingImageView;
@property (nonatomic, strong) UIView *colorFadingView;

@property (nonatomic, strong) GPUImageView *gpuImageView;
@property (nonatomic, strong) GPUImageStillCamera *gpuCamera;
@property (nonatomic, strong) GPUImageRawDataInput *gpuPhoto;

@property (nonatomic, strong) UIScrollView *scrollView;

@property (nonatomic, strong) NSArray *memoryCache;

@property (nonatomic) CFAbsoluteTime shotTime;

@property (nonatomic, strong) UIImagePickerController *imagePicker;

@property (nonatomic, strong) UIImageView *cameraFocusIndicator;

@property (nonatomic, strong) UIImage *currentImage;

@property (nonatomic, strong) TGImageTransitionHelper *transitionHelper;

@end

@implementation TGCameraController

@synthesize watcherHandle = _watcherHandle;

@synthesize state = _state;

@synthesize isDismissed = _isDismissed;

@synthesize cameraPanelTop = _cameraPanelTop;
@synthesize cameraPanelBottom = _cameraPanelBottom;

@synthesize flashButton = _flashButton;
@synthesize flashButtonOnLabel = _flashButtonOnLabel;
@synthesize flashButtonOffLabel = _flashButtonOffLabel;

@synthesize editingPanelTop = _editingPanelTop;
@synthesize editingPanelBottom = _editingPanelBottom;

@synthesize fadingImageView = _fadingImageView;
@synthesize colorFadingView = _colorFadingView;

@synthesize gpuImageView = _gpuImageView;
@synthesize gpuCamera = _gpuCamera;
@synthesize gpuPhoto = _gpuPhoto;

@synthesize scrollView = _scrollView;

@synthesize memoryCache = _memoryCache;

@synthesize shotTime = _shotTime;

@synthesize imagePicker = _imagePicker;

@synthesize cameraFocusIndicator = _cameraFocusIndicator;

@synthesize currentImage = _currentImage;

@synthesize transitionHelper = _transitionHelper;

- (id)init
{
    self = [super initWithNibName:nil bundle:nil];
    if (self)
    {
        self.wantsFullScreenLayout = true;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [self doUnloadView];
    
    runOnMainQueueWithoutDeadlocking(^
    {
        _transitionHelper = nil;
    });
}

- (void)loadView
{
    [super loadView];
    
    self.view.backgroundColor = UIColorRGB(0x222222);
    
    CGSize screenSize = [TGViewController screenSizeForInterfaceOrientation:UIInterfaceOrientationPortrait];
    
    _cameraFocusIndicator = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"CameraFocus.png"]];
    _cameraFocusIndicator.hidden = true;
    _cameraFocusIndicator.alpha = 0.0f;
    [self.view addSubview:_cameraFocusIndicator];
    
    _scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, screenSize.width, screenSize.height)];
    _scrollView.alwaysBounceHorizontal = true;
    _scrollView.alwaysBounceVertical = true;
    _scrollView.showsHorizontalScrollIndicator = false;
    _scrollView.showsVerticalScrollIndicator = false;
    _scrollView.delegate = self;
    [self.view addSubview:_scrollView];
    
    _fadingImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, screenSize.width, screenSize.height)];
    _fadingImageView.hidden = true;
    _fadingImageView.alpha = 1.0f;
    _fadingImageView.transform = CGAffineTransformMakeScale(1.0f, -1.0f);
    [self.view addSubview:_fadingImageView];
    
    _colorFadingView = [[UIView alloc] initWithFrame:_fadingImageView.frame];
    _colorFadingView.backgroundColor = self.view.backgroundColor;
    _colorFadingView.hidden = false;
    _colorFadingView.alpha = 1.0f;
    [self.view addSubview:_colorFadingView];
    
    _cameraPanelTop = [[UIView alloc] initWithFrame:CGRectMake(0, 0, screenSize.width, ([TGViewController isWidescreen] ? 44 : 0) + 68)];
    [self.view addSubview:_cameraPanelTop];
    _cameraPanelBottom = [[UIView alloc] initWithFrame:CGRectMake(0, _cameraPanelTop.frame.size.height + 320, screenSize.width, screenSize.height - (_cameraPanelTop.frame.size.height + 320))];
    
    [self.view addSubview:_cameraPanelBottom];
    
    UIImageView *cameraStripeTopBackgroundView = [[UIImageView alloc] initWithFrame:_cameraPanelTop.bounds];
    cameraStripeTopBackgroundView.image = [[UIImage imageNamed:@"CameraStripeTop.png"] stretchableImageWithLeftCapWidth:6 topCapHeight:20];
    [_cameraPanelTop addSubview:cameraStripeTopBackgroundView];
    
    UIImageView *cameraStripeBottomBackgroundView = [[UIImageView alloc] initWithFrame:_cameraPanelBottom.bounds];
    cameraStripeBottomBackgroundView.image = [[UIImage imageNamed:@"CameraStripeBottom.png"] stretchableImageWithLeftCapWidth:6 topCapHeight:0];
    [_cameraPanelBottom addSubview:cameraStripeBottomBackgroundView];
    
    if (TGIsRetina())
    {
        UIImageView *reverseIcon = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"Camera_Reverse.png"]];
        UIButton *reverseButton = [[UIButton alloc] initWithFrame:CGRectMake((int)((_cameraPanelTop.frame.size.width - reverseIcon.frame.size.width) / 2), 0, reverseIcon.frame.size.width, _cameraPanelTop.frame.size.height - 8)];
        reverseButton.showsTouchWhenHighlighted = true;
        reverseIcon.frame = CGRectOffset(reverseIcon.frame, 0, 17);
        [reverseButton addSubview:reverseIcon];
        [reverseButton addTarget:self action:@selector(reverseButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [_cameraPanelTop addSubview:reverseButton];
    }
    
    UIImageView *flashIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"Camera_Flash.png"]];
    
    _flashButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 80, 60)];
    _flashButton.exclusiveTouch = true;
    _flashButton.showsTouchWhenHighlighted = true;
    flashIconView.frame = CGRectOffset(flashIconView.frame, 17, 21);
    [_flashButton addSubview:flashIconView];
    [_cameraPanelTop addSubview:_flashButton];
    [_flashButton addTarget:self action:@selector(flashButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    
    _flashButtonOnLabel = [[UIImageView alloc] initWithImage:makeCameraButtonTextImage(@"On", false)];
    _flashButtonOnLabel.frame = CGRectOffset(_flashButtonOnLabel.frame, 38, 25);
    _flashButtonOffLabel = [[UIImageView alloc] initWithImage:makeCameraButtonTextImage(@"Off", false)];
    _flashButtonOffLabel.frame = CGRectOffset(_flashButtonOffLabel.frame, 38, 25);
    
    [_flashButton addSubview:_flashButtonOnLabel];
    [_flashButton addSubview:_flashButtonOffLabel];
    
    if (currentCameraPosition != AVCaptureDevicePositionBack)
        _flashButton.hidden = true;
    
    UIImageView *cancelIcon = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"Camera_Cancel.png"]];
    UIImageView *cancelText = [[UIImageView alloc] initWithImage:makeCameraButtonTextImage(@"Cancel", false)];
    
    UIButton *cancelButton = [[UIButton alloc] initWithFrame:CGRectMake(_cameraPanelTop.frame.size.width - cancelIcon.frame.size.width - cancelText.frame.size.width - 13, 0, cancelIcon.frame.size.width + cancelText.frame.size.width + 39, 60)];
    cancelButton.exclusiveTouch = true;
    cancelButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    cancelButton.showsTouchWhenHighlighted = true;
    cancelText.frame = CGRectOffset(cancelText.frame, 4, 23);
    cancelIcon.frame = CGRectOffset(cancelIcon.frame, cancelText.frame.size.width + 5, 21);
    [cancelButton addSubview:cancelIcon];
    [cancelButton addSubview:cancelText];
    [_cameraPanelTop addSubview:cancelButton];
    [cancelButton addTarget:self action:@selector(cancelButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    
    UIButton *libraryButton = [[UIButton alloc] initWithFrame:CGRectMake(7, _cameraPanelBottom.frame.size.height - 62, 84, 38)];
    libraryButton.exclusiveTouch = true;
    [libraryButton setBackgroundImage:[UIImage imageNamed:@"CameraBtn.png"] forState:UIControlStateNormal];
    [libraryButton setBackgroundImage:[UIImage imageNamed:@"CameraBtn_Pressed.png"] forState:UIControlStateHighlighted];
    UIImageView *libraryButtonLabel = [[UIImageView alloc] initWithImage:makeCameraButtonTextImage(@"Library", true)];
    libraryButtonLabel.frame = CGRectOffset(libraryButtonLabel.frame, floorf((libraryButton.frame.size.width - libraryButtonLabel.frame.size.width) / 2), floorf((libraryButton.frame.size.height - libraryButtonLabel.frame.size.height) / 2) - 1);
    [libraryButton addSubview:libraryButtonLabel];
    [libraryButton addTarget:self action:@selector(libraryButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    [_cameraPanelBottom addSubview:libraryButton];
    
#if !TARGET_IPHONE_SIMULATOR
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera])
#endif
    {
        UIImage *shutterButtonBackground = [UIImage imageNamed:@"Camera_MakePhoto.png"];
        UIImage *shutterButtonBackgroundHighlighted = [UIImage imageNamed:@"Camera_MakePhoto-Pressed.png"];
        UIButton *shutterButton = [[UIButton alloc] initWithFrame:CGRectMake((int)((_cameraPanelBottom.frame.size.width - shutterButtonBackground.size.width) / 2), _cameraPanelBottom.frame.size.height - shutterButtonBackground.size.height - 20, shutterButtonBackground.size.width, shutterButtonBackground.size.height)];
        shutterButton.exclusiveTouch = true;
        shutterButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        [shutterButton setBackgroundImage:shutterButtonBackground forState:UIControlStateNormal];
        [shutterButton setBackgroundImage:shutterButtonBackgroundHighlighted forState:UIControlStateHighlighted];
        [_cameraPanelBottom addSubview:shutterButton];
        [shutterButton addTarget:self action:@selector(shutterButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    }
    
    _editingPanelTop = [[UIView alloc] initWithFrame:_cameraPanelTop.frame];
    [self.view addSubview:_editingPanelTop];
    _editingPanelBottom = [[UIView alloc] initWithFrame:_cameraPanelBottom.frame];
    [self.view addSubview:_editingPanelBottom];
    
    _editingPanelTop.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"Camera_DarkBackground.png"]];
    _editingPanelBottom.backgroundColor = _editingPanelTop.backgroundColor;
    
    UIImage *topShadowImage = [UIImage imageNamed:@"Camera_ShadowTop.png"];
    UIImageView *topShadow = [[UIImageView alloc] initWithFrame:CGRectMake(0, _editingPanelTop.frame.size.height - topShadowImage.size.height, _editingPanelTop.frame.size.width, topShadowImage.size.height)];
    topShadow.image = topShadowImage;
    [_editingPanelTop addSubview:topShadow];
    
    UIImage *bottomShadowImage = [UIImage imageNamed:@"Camera_ShadowBottom.png"];
    UIImageView *bottomShadow = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, _editingPanelBottom.frame.size.width, bottomShadowImage.size.height)];
    bottomShadow.image = bottomShadowImage;
    [_editingPanelBottom addSubview:bottomShadow];
    
    UIImage *editingButtonImage = [UIImage imageNamed:@"BlackPhotoBtn.png"];
    UIImage *editingButtonImageHighlighted = [UIImage imageNamed:@"BlackPhotoBtn_Pressed.png"];
    
    UIButton *editingCancelButton = [[UIButton alloc] initWithFrame:CGRectMake(10, _editingPanelBottom.frame.size.height - 61, editingButtonImage.size.width, editingButtonImage.size.height)];
    editingCancelButton.exclusiveTouch = true;
    [editingCancelButton setBackgroundImage:editingButtonImage forState:UIControlStateNormal];
    [editingCancelButton setBackgroundImage:editingButtonImageHighlighted forState:UIControlStateHighlighted];
    UILabel *editingCancelLabel = [[UILabel alloc] init];
    editingCancelLabel.text = @"Cancel";
    editingCancelLabel.backgroundColor = [UIColor clearColor];
    editingCancelLabel.textColor = UIColorRGB(0xffffff);
    editingCancelLabel.shadowColor = UIColorRGBA(0x000000, 0.1);
    editingCancelLabel.font = [UIFont boldSystemFontOfSize:13];
    editingCancelLabel.shadowOffset = CGSizeMake(0, -1);
    [editingCancelLabel sizeToFit];
    editingCancelLabel.frame = CGRectOffset(editingCancelLabel.frame, floorf((editingCancelButton.frame.size.width - editingCancelLabel.frame.size.width) / 2), floorf((editingCancelButton.frame.size.height - editingCancelLabel.frame.size.height) / 2) - 1);
    [editingCancelButton addSubview:editingCancelLabel];
    [editingCancelButton addTarget:self action:@selector(editingCancelButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    [_editingPanelBottom addSubview:editingCancelButton];
    
    UIImage *sendImage = [UIImage imageNamed:@"SendPhoto.png"];
    UIImage *sendImageHighlighted = [UIImage imageNamed:@"SendPhoto_Pressed.png"];
    UIButton *sendButton = [[UIButton alloc] initWithFrame:CGRectMake((int)((_editingPanelBottom.frame.size.width - sendImage.size.width) / 2), _editingPanelBottom.frame.size.height - 67, sendImage.size.width, sendImage.size.height)];
    sendButton.exclusiveTouch = true;
    [sendButton setBackgroundImage:sendImage forState:UIControlStateNormal];
    [sendButton setBackgroundImage:sendImageHighlighted forState:UIControlStateHighlighted];
    UILabel *sendButtonLabel = [[UILabel alloc] init];
    sendButtonLabel.text = TGLocalized(@"Camera.Done");
    sendButtonLabel.backgroundColor = [UIColor clearColor];
    sendButtonLabel.textColor = UIColorRGB(0xffffff);
    sendButtonLabel.shadowColor = UIColorRGB(0x1662c5);
    sendButtonLabel.font = [UIFont boldSystemFontOfSize:18];
    sendButtonLabel.shadowOffset = CGSizeMake(0, -1);
    [sendButtonLabel sizeToFit];
    sendButtonLabel.frame = CGRectOffset(sendButtonLabel.frame, (int)((sendButton.frame.size.width - sendButtonLabel.frame.size.width) / 2) - 1, (int)((sendButton.frame.size.height - sendButtonLabel.frame.size.height) / 2));
    [sendButton addSubview:sendButtonLabel];
    [sendButton addTarget:self action:@selector(sendButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    [_editingPanelBottom addSubview:sendButton];
    
    TGCameraControllerState state = _state;
    _state = TGCameraControllerStateEmpty;
    [self setState:state];
}

- (void)doUnloadView
{
    
}

- (BOOL)shouldAutorotate
{
    return false;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return toInterfaceOrientation == UIInterfaceOrientationPortrait;
}

- (void)viewWillAppear:(BOOL)animated
{
    [self resumeCamera];
    
    //_memoryCache = [[TGRemoteImageView sharedCache] storeMemoryCache];
    //[[TGRemoteImageView sharedCache] clearCache:TGCacheMemory];
    
    [super viewWillAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self pauseCamera];
    
    [super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
    if (_isDismissed)
    {
        [self stopCamera];
    }
    
    if (_memoryCache != nil)
    {
        //[[TGRemoteImageView sharedCache] restoreMemoryCache:_memoryCache];
        _memoryCache = nil;
    }
    
    [super viewDidDisappear:animated];
}

- (void)dismissToRect:(CGRect)toRectInWindowSpace fromImage:(UIImage *)fromImage toImage:(UIImage *)toImage toView:(UIView *)toView aboveView:(UIView *)aboveView interfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    _isDismissed = true;
    
    if (!CGSizeEqualToSize(toRectInWindowSpace.size, CGSizeZero))
    {
        _fadingImageView.image = fromImage;
        _fadingImageView.transform = CGAffineTransformIdentity;
        _fadingImageView.frame = CGRectMake(0, _cameraPanelTop.frame.size.height, 320, 320);
        _fadingImageView.alpha = 1.0f;
        _fadingImageView.hidden = false;
        
        _transitionHelper = [[TGImageTransitionHelper alloc] init];
        [_transitionHelper beginTransitionOut:_fadingImageView fromView:self.view toView:toView aboveView:aboveView interfaceOrientation:interfaceOrientation toRectInWindowSpace:toRectInWindowSpace toImage:toImage keepAspect:false];
        
        _gpuImageView.hidden = true;
        _cameraPanelTop.hidden = true;
        _cameraPanelBottom.hidden = true;
        
        self.view.backgroundColor = [UIColor clearColor];
        
        [UIView animateWithDuration:0.2 animations:^
        {
            _editingPanelTop.alpha = 0.0f;
            _editingPanelBottom.alpha = 0.0f;
        }];
    }
}

#pragma mark -

- (void)cancelButtonPressed
{
    _currentImage = nil;
    
    id<ASWatcher> watcher = _watcherHandle.delegate;
    if (watcher != nil && [watcher respondsToSelector:@selector(actionStageActionRequested:options:)])
    {
        [watcher actionStageActionRequested:@"dismissCamera" options:nil];
    }
}

- (void)reverseButtonPressed
{
    self.view.userInteractionEnabled = false;
    
    if (currentCameraPosition == AVCaptureDevicePositionBack)
        currentCameraPosition = AVCaptureDevicePositionFront;
    else
        currentCameraPosition = AVCaptureDevicePositionBack;
    
    runAsynchronouslyOnVideoProcessingQueue(^
    {
        _gpuImageView.ignoreFrames = true;
        [_gpuCamera pauseCameraCapture];
        
        [_gpuCamera.inputCamera removeObserver:self forKeyPath:@"adjustingFocus"];
        
        [_gpuCamera rotateCamera];
        
        [_gpuCamera.inputCamera addObserver:self forKeyPath:@"adjustingFocus" options:NSKeyValueObservingOptionNew context:NULL];
        
        _gpuImageView.ignoreFrames = false;
        [_gpuCamera resumeCameraCapture];
        
        [self updateFlashIcon];
        
        dispatch_async(dispatch_get_main_queue(), ^
        {
            self.view.userInteractionEnabled = true;
        });
    });
}

- (void)flashButtonPressed
{
    AVCaptureFlashMode flashMode = !_flashButtonOnLabel.hidden ? AVCaptureFlashModeOff : AVCaptureFlashModeOn;
    
    runAsynchronouslyOnVideoProcessingQueue(^
    {
        NSError *error = nil;
        [_gpuCamera.inputCamera lockForConfiguration:&error];
        if (error == nil)
        {
            if ([_gpuCamera.inputCamera isFlashModeSupported:flashMode])
                [_gpuCamera.inputCamera setFlashMode:flashMode];
            else
                [self updateFlashIcon];
            [_gpuCamera.inputCamera unlockForConfiguration];
        }
    });
    [self updateFlashIcon:true flashMode:flashMode];
}

- (void)libraryButtonPressed
{
    [self stopCamera];
    
    [[UIApplication sharedApplication] setStatusBarHidden:true withAnimation:UIStatusBarAnimationNone];
    
    _imagePicker = [[UIImagePickerController alloc] init];
    _imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    _imagePicker.delegate = self;
    [self presentViewController:_imagePicker animated:true completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)__unused picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{   
    picker.delegate = nil;
    UIImage *processedImage = [info objectForKey:UIImagePickerControllerOriginalImage];
    
    CGSize imageSize = processedImage.size;
    imageSize.width /= processedImage.scale;
    imageSize.height /= processedImage.scale;
    int screenWidth = 500;
    imageSize = TGFitSize(imageSize, CGSizeMake(screenWidth, screenWidth));
    
    if (imageSize.height < 320)
    {
        imageSize.width = ceilf(imageSize.width * 320 / imageSize.height);
        imageSize.height = 320;
    }
    if (imageSize.width < 320)
    {
        imageSize.height = ceilf(imageSize.height * 320 / imageSize.width);
        imageSize.width = 320;
    }
    
    UIImage *photo = TGScaleImage(processedImage, imageSize);
    
    CGSize contentSize = CGSizeMake(MAX(imageSize.width, _scrollView.frame.size.width), MAX(imageSize.height + _scrollView.frame.size.height - 320, _scrollView.frame.size.height));
    _scrollView.contentSize = contentSize;
    CGPoint contentOffset = CGPointMake(MAX(0, floorf((contentSize.width - _scrollView.frame.size.width) / 2.0f)), MAX(0, floorf((contentSize.height - _scrollView.frame.size.height) / 2.0f)));
    _scrollView.contentOffset = contentOffset;
    contentOffset.y += 12;
    
    [self setState:TGCameraControllerStateEditing animated:false];
    
    _colorFadingView.alpha = 1.0f;
    _colorFadingView.hidden = false;
    
    if ([self respondsToSelector:@selector(dismissViewControllerAnimated:completion:)])
        [self dismissViewControllerAnimated:true completion:nil];
    else
        [self dismissModalViewControllerAnimated:true];
    
    [[UIApplication sharedApplication] setStatusBarHidden:false withAnimation:UIStatusBarAnimationNone];
    
    runAsynchronouslyOnVideoProcessingQueue(^
    {
        [_gpuCamera pauseCameraCapture];
        [_gpuCamera removeAllTargets];
        
        if (_gpuPhoto != nil)
        {
            [_gpuPhoto removeAllTargets];
            _gpuPhoto = nil;
        }
        
        if (_gpuImageView == nil)
        {
            CGSize screenSize = [TGViewController screenSizeForInterfaceOrientation:UIInterfaceOrientationPortrait];
            _gpuImageView = [[GPUImageView alloc] initWithFrame:CGRectMake(0, 0, screenSize.width, screenSize.height)];
        }
        
        
        _gpuImageView.imageScale = 1.0f;
        _gpuImageView.contentSize = contentSize;
        _gpuImageView.imageTranslation = contentOffset;
        [_gpuImageView setFillMode:kGPUImageFillModeReal];
        
        _gpuPhoto = (GPUImageRawDataInput *)[[GPUImagePicture alloc] initWithImage:photo smoothlyScaleOutput:false];
        
        _gpuImageView.convertYUV = false;
        [_gpuImageView setInputRotation:kGPUImageNoRotation atIndex:0];
        _gpuImageView.ignoreFrames = false;
        [_gpuPhoto addTarget:_gpuImageView];
        
        [(GPUImagePicture *)_gpuPhoto processImage];
        
        dispatch_async(dispatch_get_main_queue(), ^
        {
            _fadingImageView.hidden = true;
            _fadingImageView.alpha = 0.0f;
            
            if (_gpuImageView.superview == nil)
                [self.view insertSubview:_gpuImageView atIndex:0];
            
            [self fadeInCamera];
        });
    });
    
    [self restoreWindowLayout];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)__unused picker
{
    _imagePicker = nil;
    
    _colorFadingView.hidden = false;
    _colorFadingView.alpha = 1.0f;
    
    [self setState:TGCameraControllerStateCamera animated:false];
    [self startCamera];
    
    if ([self respondsToSelector:@selector(dismissViewControllerAnimated:completion:)])
        [self dismissViewControllerAnimated:true completion:nil];
    else
        [self dismissModalViewControllerAnimated:true];
    
    [[UIApplication sharedApplication] setStatusBarHidden:false withAnimation:UIStatusBarAnimationNone];
    
    [self restoreWindowLayout];
}

- (void)restoreWindowLayout
{
    dispatch_async(dispatch_get_main_queue(), ^
    {
        [TGViewController attemptAutorotation];
        
        dispatch_async(dispatch_get_main_queue(), ^
        {
            [[UIApplication sharedApplication] setStatusBarOrientation:TGAppDelegateInstance.window.rootViewController.interfaceOrientation animated:false];
            
            CGSize statusBarSize = [[UIApplication sharedApplication] statusBarFrame].size;
            
            [TGAppDelegateInstance.window.rootViewController.view setNeedsLayout];
            CGRect navigationBarFrame = ((UINavigationController *)TGAppDelegateInstance.window.rootViewController).navigationBar.frame;
            navigationBarFrame.origin.y = statusBarSize.height;
            ((UINavigationController *)TGAppDelegateInstance.window.rootViewController).navigationBar.frame = navigationBarFrame;
            [TGAppDelegateInstance.window.rootViewController.view layoutIfNeeded];
        });
    });
}

- (void)createFadingImage
{
    CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
    [_gpuImageView snapshot:^(UIImage *image)
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            TGLog(@"Snapshot time: %f ms", (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0);
            _fadingImageView.contentMode = UIViewContentModeScaleAspectFill;
            _fadingImageView.image = image;
            _fadingImageView.hidden = false;
            _fadingImageView.alpha = 1.0f;
            
            TGLog(@"Snapshot applied");
        });
    }];
}

- (void)fadeInImage
{
    _fadingImageView.hidden = false;
    
    [UIView animateWithDuration:0.2 animations:^
    {
         _fadingImageView.alpha = 0.0f;
    } completion:^(BOOL finished)
    {
        if (finished)
        {
            _fadingImageView.hidden = true;
            _fadingImageView.image = nil;
        }
    }];
}

- (void)fadeOutCamera
{
    _colorFadingView.hidden = false;
    [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^
    {
        _colorFadingView.alpha = 1.0f;
    } completion:nil];
}

- (void)fadeInCamera
{
    if (_colorFadingView.alpha > FLT_EPSILON)
    {
        [UIView animateWithDuration:0.18 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^
        {
            _colorFadingView.alpha = 0.0f;
        } completion:^(BOOL finished)
        {
            if (finished)
            {
                _colorFadingView.hidden = true;
            }
        }];
    }
}

static void releasePixels(__unused void *info, const void *data, __unused size_t size)
{
    free((void *)data);
}

- (void)shutterButtonPressed
{
    _shotTime = CFAbsoluteTimeGetCurrent();
    
    self.view.userInteractionEnabled = false;
    
    [self setState:TGCameraControllerStateEditing animated:true];
    
    CFAbsoluteTime beginTime = CFAbsoluteTimeGetCurrent();

    reportAvailableMemoryForGPUImage(@"Capture 0");

    runAsynchronouslyOnVideoProcessingQueue(^
    {
        /*if (_gpuCamera.inputCamera.flashMode == AVCaptureFlashModeOff)
        {
            _gpuImageView.ignoreFrames = true;
            [self createFadingImage];
        }*/
        
        [_gpuCamera capturePhotoAsSampleBufferWithCompletionHandler:^(CMSampleBufferRef imageSampleBuffer, NSError *error)
        {
            CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
            TGLog(@"Processing start time: %f ms", (startTime - beginTime) * 1000.0);
            
            CFRetain(imageSampleBuffer);
            
            runAsynchronouslyOnVideoProcessingQueue(^
            {
                reportAvailableMemoryForGPUImage(@"Capture 1");
                
                _gpuImageView.ignoreFrames = true;
                
                if (error != nil)
                {
                    CFRelease(imageSampleBuffer);
                    
                    TGLog(@"%@", error);
                    
                    dispatch_async(dispatch_get_main_queue(), ^
                    {
                        self.view.userInteractionEnabled = true;
                    });
                    
                    _gpuImageView.ignoreFrames = false;
                    [_gpuCamera resumeCameraCapture];
                    
                    return;
                }
                
                CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(imageSampleBuffer);
                
                TGLog(@"Acquire time: %f ms", (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0);
                
                CVPixelBufferLockBaseAddress(imageBuffer, 0);
                
                uint8_t *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
                CVPlanarPixelBufferInfo_YCbCrBiPlanar *bufferInfo = (CVPlanarPixelBufferInfo_YCbCrBiPlanar *)baseAddress;
                
                int width = CVPixelBufferGetWidth(imageBuffer);
                int height = CVPixelBufferGetHeight(imageBuffer);
                
                NSUInteger yOffset = EndianU32_BtoN(bufferInfo->componentInfoY.offset);
                NSUInteger yPitch = EndianU32_BtoN(bufferInfo->componentInfoY.rowBytes);
                
                NSUInteger cbCrOffset = EndianU32_BtoN(bufferInfo->componentInfoCbCr.offset);
                NSUInteger cbCrPitch = EndianU32_BtoN(bufferInfo->componentInfoCbCr.rowBytes);
                
                uint8_t *yBuffer = baseAddress + yOffset;
                uint8_t *cbCrBuffer = baseAddress + cbCrOffset;
                
                int delta = width * height < (1281 * 961) ? 1 : 3;
                
                int requiredWidth = width / delta;
                int requiredHeight = height / delta;
                
                dispatch_async(dispatch_get_main_queue(), ^
                {
                    uint8_t *rgbBuffer = malloc(requiredWidth * requiredHeight * 3);
                    
                    if (delta == 3)
                    {
                        for (int y = 0; y < height; y += 3)
                        {
                            uint8_t * __restrict yBufferLine = &yBuffer[y * yPitch];
                            uint8_t * __restrict cbCrBufferLine = &cbCrBuffer[(y >> 1) * cbCrPitch];
                            
                            uint8_t * __restrict rgbOutput = (uint8_t *)(&rgbBuffer[y / 3 * 3 * requiredWidth]);
                            
                            for (int x = 0; x < width; x += 3)
                            {
                                uint8_t c_cb = cbCrBufferLine[x & ~1];
                                uint8_t c_cr = cbCrBufferLine[x | 1];
                                uint8_t c_y = yBufferLine[0];
                                
                                rgbOutput[0] = c_y;
                                rgbOutput[1] = c_cb;
                                rgbOutput[2] = c_cr;
                                
                                yBufferLine += 3;
                                rgbOutput += 3;
                            }
                        }
                    }
                    else
                    {
                        for (int y = 0; y < height; y += 1)
                        {
                            uint8_t * __restrict yBufferLine = &yBuffer[y * yPitch];
                            uint8_t * __restrict cbCrBufferLine = &cbCrBuffer[(y >> 1) * cbCrPitch];
                            
                            uint8_t * __restrict rgbOutput = (uint8_t *)(&rgbBuffer[(height - 1 - y) / 1 * 3 * requiredWidth]);
                            
                            for (int x = 0; x < width; x += 1)
                            {
                                uint8_t c_cb = cbCrBufferLine[x & ~1];
                                uint8_t c_cr = cbCrBufferLine[x | 1];
                                uint8_t c_y = yBufferLine[0];
                                
                                rgbOutput[0] = c_y;
                                rgbOutput[1] = c_cb;
                                rgbOutput[2] = c_cr;
                                
                                yBufferLine += 1;
                                rgbOutput += 3;
                            }
                        }
                    }

                    TGLog(@"Scale time: %f ms", (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0);
                    
                    CFRelease(imageSampleBuffer);
                    
                    runAsynchronouslyOnVideoProcessingQueue(^
                    {
                        if (_gpuPhoto != nil)
                        {
                            [_gpuPhoto removeAllTargets];
                            _gpuPhoto = nil;
                        }
                            
                        _gpuPhoto = [[GPUImageRawDataInput alloc] initWithBytes:rgbBuffer size:CGSizeMake(requiredWidth, requiredHeight) pixelFormat:GPUPixelFormatRGB type:GL_UNSIGNED_BYTE];
                        
                        [_gpuCamera removeAllTargets];
                        
                        TGLog(@"Prepare time: %f ms", (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0);
                        
                        _gpuImageView.convertYUV = true;
                        [_gpuImageView setInputRotation:kGPUImageRotateRight atIndex:0];
                        [_gpuPhoto addTarget:_gpuImageView];
                        
                        TGDispatchAfter(0.2, [GPUImageOpenGLESContext sharedOpenGLESQueue], ^
                        {
                            [self stopCamera];
                        });
                        
                        TGLog(@"Complete time: %f ms", (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0);
                        
                        dispatch_async(dispatch_get_main_queue(), ^
                        {
                            reportAvailableMemoryForGPUImage(@"Capture 2");
                            
                            _shotTime = CFAbsoluteTimeGetCurrent();
                            
                            CGSize imageSize = CGSizeMake(requiredWidth, requiredHeight);
                            if (TGIsRetina())
                            {
                                imageSize.width /= 2.0f;
                                imageSize.height /= 2.0f;
                            }
                            
                            float tmp = imageSize.width;
                            imageSize.width = imageSize.height;
                            imageSize.height = tmp;
                            
                            float imageScale = _scrollView.frame.size.height / imageSize.height;
                            
                            CGSize contentSize = CGSizeMake(MAX(imageSize.width * imageScale, _scrollView.frame.size.width), MAX(imageSize.height * imageScale + _scrollView.frame.size.height - 320, _scrollView.frame.size.height));
                            CGPoint contentOffset = CGPointMake(MAX(0, floorf((contentSize.width - _scrollView.frame.size.width) / 2.0f)), MAX(0, floorf((contentSize.height - _scrollView.frame.size.height) / 2.0f)));
                            
                            [self fadeInImage];
                            
                            runAsynchronouslyOnVideoProcessingQueue(^
                            {
                                _gpuImageView.fillMode = kGPUImageFillModeReal;
                                _gpuImageView.imageScale = imageScale;
                                _gpuImageView.contentSize = contentSize;
                                _gpuImageView.imageTranslation = contentOffset;
                            });
                            
                            _scrollView.contentSize = contentSize;
                            _scrollView.contentOffset = CGPointMake(contentOffset.x, contentOffset.y - 12);
                        });
                        
                        _gpuImageView.ignoreFrames = false;
                        [_gpuPhoto processData];
                        
                        TGLog(@"Upload time: %f ms", (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0);
                        
                        free(rgbBuffer);
                        
                        dispatch_async(dispatch_get_main_queue(), ^
                        {
                            self.view.userInteractionEnabled = true;
                        });
                    });
                });
                
                [self createFadingImage];
            });
        } captureStartedBlock:^
        {
            /*runAsynchronouslyOnVideoProcessingQueue(^
            {
                if (_gpuCamera.inputCamera.flashMode != AVCaptureFlashModeOff)
                {
                    TGDispatchAfter(1.0 / 5.0, [GPUImageOpenGLESContext sharedOpenGLESQueue], ^
                    {
                        if (_gpuPhoto == nil)
                        {
                            //_gpuImageView.ignoreFrames = true;
                            //[self createFadingImage];
                        }
                    });
                }
                else
                {
                    if (_gpuPhoto == nil)
                    {
                        //_gpuImageView.ignoreFrames = true;
                        //[self createFadingImage];
                    }
                }
            });*/
        } captureCompletedBlock:^
        {
            /*[_gpuCamera pauseCameraCapture];
            _gpuImageView.ignoreFrames = true;
            
            runAsynchronouslyOnVideoProcessingQueue(^
            {
                if (_gpuCamera.inputCamera.flashMode == AVCaptureFlashModeOff)
                {
                    _gpuImageView.ignoreFrames = true;
                    
                    [self createFadingImage];
                }
            });*/
        }];
    });
    
#if TARGET_IPHONE_SIMULATOR
    self.view.userInteractionEnabled = true;
#endif
}

- (void)sendButtonPressed
{
    self.view.userInteractionEnabled = false;
    
    float offsetFromTop = _cameraPanelTop.frame.size.height;
    
    [_gpuImageView snapshot:^(UIImage *image)
    {
        UIImage *resultImage = TGScaleAndRoundCornersWithOffsetAndFlags(image, TGFitSize(image.size, [TGViewController screenSizeForInterfaceOrientation:UIInterfaceOrientationPortrait]), CGPointMake(0, -offsetFromTop), CGSizeMake(320, 320), 0, nil, true, nil, TGScaleImageFlipVerical);
        NSData *imageData = UIImageJPEGRepresentation(resultImage, 0.5f);
        
        dispatch_async(dispatch_get_main_queue(), ^
        {
            self.view.userInteractionEnabled = true;
            
            id<ASWatcher> watcher = _watcherHandle.delegate;
            if (watcher != nil && [watcher respondsToSelector:@selector(actionStageActionRequested:options:)])
            {
                [watcher actionStageActionRequested:@"cameraCompleted" options:[[NSDictionary alloc] initWithObjectsAndKeys:resultImage, @"image", imageData, @"imageData", nil]];
            }
        });
    }];
}

- (void)editingCancelButtonPressed
{
    _currentImage = nil;
    
    if (_state == TGCameraControllerStateEditing && _imagePicker != nil)
    {
        [self libraryButtonPressed];
        return;
    }
    
    if (CFAbsoluteTimeGetCurrent() - _shotTime < 0.21)
        return;
    
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera])
    {
        _cameraPanelBottom.userInteractionEnabled = false;
        _flashButton.userInteractionEnabled = false;
        
        [self startCamera];
    }
    
    [self setState:TGCameraControllerStateCamera animated:true];
    
    [self fadeOutCamera];
}

#pragma mark -

- (void)updateFlashIcon
{
    runAsynchronouslyOnVideoProcessingQueue(^
    {
        bool flashAvailable = _gpuCamera.inputCamera.flashAvailable;
        AVCaptureFlashMode flashMode = _gpuCamera.inputCamera.flashMode;
        
        dispatch_async(dispatch_get_main_queue(), ^
        {
            [self updateFlashIcon:flashAvailable flashMode:flashMode];
        });
    });
}

- (void)updateFlashIcon:(bool)flashAvailable flashMode:(AVCaptureFlashMode)flashMode
{
    if (!flashAvailable)
        _flashButton.hidden = true;
    else
    {
        _flashButton.hidden = false;
        if (flashMode == AVCaptureFlashModeOn)
        {
            _flashButtonOnLabel.hidden = false;
            _flashButtonOffLabel.hidden = true;
        }
        else if (flashMode == AVCaptureFlashModeOff)
        {
            _flashButtonOnLabel.hidden = true;
            _flashButtonOffLabel.hidden = false;
        }
    }
}

- (void)startCamera
{   
    runAsynchronouslyOnVideoProcessingQueue(^
    {
        if (_gpuCamera != nil)
            return;
        
        NSString *preset = (deviceMemorySize() > 300 || !TGIsRetina()) ? AVCaptureSessionPresetPhoto : AVCaptureSessionPresetiFrame960x540;
        
        if (_gpuPhoto != nil)
        {
            [_gpuPhoto removeAllTargets];
            _gpuPhoto = nil;
        }
        
        _gpuCamera = [[GPUImageStillCamera alloc] initWithSessionPreset:preset cameraPosition:currentCameraPosition useYUV:true];
        [_gpuCamera.inputCamera addObserver:self forKeyPath:@"adjustingFocus" options:NSKeyValueObservingOptionNew context:NULL];
        _gpuCamera.outputImageOrientation = UIInterfaceOrientationPortrait;
        
        NSError *error = nil;
        [_gpuCamera.inputCamera lockForConfiguration:&error];
        if (error == nil)
        {
            if (_gpuCamera.inputCamera.flashMode == AVCaptureFlashModeAuto && [_gpuCamera.inputCamera isFlashModeSupported:AVCaptureFlashModeOn])
                [_gpuCamera.inputCamera setFlashMode:AVCaptureFlashModeOn];
            [_gpuCamera.inputCamera unlockForConfiguration];
        }
        
        CGSize screenSize = [TGViewController screenSizeForInterfaceOrientation:UIInterfaceOrientationPortrait];
        if (_gpuImageView == nil)
        {
            _gpuImageView = [[GPUImageView alloc] initWithFrame:CGRectMake(0, 0, screenSize.width, screenSize.height)];
            [_gpuImageView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(gpuImageViewTapped:)]];
        }
        
        [_gpuImageView setFillMode:kGPUImageFillModePreserveAspectRatioAndFill];
        [_gpuImageView setInputRotation:kGPUImageNoRotation atIndex:0];
        _gpuImageView.contentSize = CGSizeZero;
        _gpuImageView.imageScale = 1.0f;
        _gpuImageView.imageTranslation = CGPointZero;
        _gpuImageView.convertYUV = false;
        _gpuImageView.ignoreFrames = false;
        
        [_gpuCamera addTarget:_gpuImageView];
        
        [_gpuCamera startCameraCapture];
        
        [self updateFlashIcon];
        
        dispatch_async(dispatch_get_main_queue(), ^
        {
            if (_gpuImageView.superview == nil)
                [self.view insertSubview:_gpuImageView atIndex:0];
            
            [self cameraDidStart];
        });
    });
}

- (void)stopCamera
{
    runAsynchronouslyOnVideoProcessingQueue(^
    {
        if (_gpuCamera == nil)
            return;
        
        [_gpuCamera pauseCameraCapture];
        [_gpuCamera stopCameraCapture];
        [_gpuCamera removeAllTargets];
        [_gpuCamera.inputCamera removeObserver:self forKeyPath:@"adjustingFocus"];
        _gpuCamera = nil;
        
        dispatch_async(dispatch_get_main_queue(), ^
        {
            [self cameraDidStop];
        });
    });
}

- (void)pauseCamera
{
    runAsynchronouslyOnVideoProcessingQueue(^
    {
        if (_gpuCamera == nil)
            return;
        
        [_gpuCamera pauseCameraCapture];
        [_gpuCamera stopCameraCapture];
        
        dispatch_async(dispatch_get_main_queue(), ^
        {
            [self cameraDidPause];
        });
    });
}

- (void)resumeCamera
{
    runAsynchronouslyOnVideoProcessingQueue(^
    {
        if (_gpuCamera == nil)
            return;
        
        [_gpuCamera resumeCameraCapture];
        [_gpuCamera startCameraCapture];
        
        dispatch_async(dispatch_get_main_queue(), ^
        {
            [self cameraDidResume];
        });
    });
}

#pragma mark -

- (void)setState:(TGCameraControllerState)state
{
    [self setState:state animated:false];
}

- (void)setState:(TGCameraControllerState)state animated:(bool)animated
{
    if (_state != state)
    {
        TGCameraControllerState previousState = _state;
        _state = state;
        
        if (previousState == TGCameraControllerStateEmpty)
        {
            if (state == TGCameraControllerStateCamera)
            {
                _scrollView.hidden = true;
                
                _editingPanelTop.hidden = true;
                _editingPanelTop.frame = CGRectMake(0, -_editingPanelTop.frame.size.height, _editingPanelTop.frame.size.width, _editingPanelTop.frame.size.height);
                _editingPanelBottom.hidden = true;
                _editingPanelBottom.frame = CGRectMake(0, [TGViewController screenSizeForInterfaceOrientation:UIInterfaceOrientationPortrait].height + _editingPanelBottom.frame.size.height, _editingPanelBottom.frame.size.width, _editingPanelBottom.frame.size.height);
                
                _cameraPanelTop.hidden = false;
                _cameraPanelBottom.hidden = false;
                
                if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera])
                {
                    [self startCamera];
                    [self updateFlashIcon:true flashMode:AVCaptureFlashModeOff];
                }
                else
                {
                    [self updateFlashIcon:false flashMode:AVCaptureFlashModeOff];
                }
            }
        }
        else if (previousState == TGCameraControllerStateCamera)
        {
            if (state == TGCameraControllerStateEditing)
            {
                _cameraFocusIndicator.alpha = 0.0f;
                _cameraFocusIndicator.hidden = true;
                
                _scrollView.hidden = false;
                
                _editingPanelTop.hidden = false;
                _editingPanelBottom.hidden = false;
                
                CGRect topFrame = _editingPanelTop.frame;
                topFrame.origin.y = 0;
                CGRect bottomFrame = _editingPanelBottom.frame;
                bottomFrame.origin.y = [TGViewController screenSizeForInterfaceOrientation:UIInterfaceOrientationPortrait].height - bottomFrame.size.height;
                
                if (animated)
                {
                    [UIView animateWithDuration:0.2 animations:^
                    {
                        _editingPanelTop.frame = topFrame;
                        _editingPanelBottom.frame = bottomFrame;
                    } completion:^(BOOL finished)
                    {
                        if (finished)
                        {
                            _cameraPanelTop.hidden = true;
                            _cameraPanelBottom.hidden = true;
                        }
                    }];
                }
                else
                {
                    _editingPanelTop.frame = topFrame;
                    _editingPanelBottom.frame = bottomFrame;
                    _cameraPanelTop.hidden = true;
                    _cameraPanelBottom.hidden = true;
                }
            }
        }
        else if (previousState == TGCameraControllerStateEditing)
        {
            if (state == TGCameraControllerStateCamera)
            {
                _scrollView.hidden = true;
                
                _cameraPanelTop.hidden = false;
                _cameraPanelBottom.hidden = false;
                
                CGRect topFrame = _editingPanelTop.frame;
                topFrame.origin.y = -topFrame.size.height;
                CGRect bottomFrame = _editingPanelBottom.frame;
                bottomFrame.origin.y = [TGViewController screenSizeForInterfaceOrientation:UIInterfaceOrientationPortrait].height;
                
                if (animated)
                {
                    [UIView animateWithDuration:0.2 animations:^
                    {
                        _editingPanelTop.frame = topFrame;
                        _editingPanelBottom.frame = bottomFrame;
                    } completion:^(BOOL finished)
                    {
                        if (finished)
                        {
                            _editingPanelTop.hidden = true;
                            _editingPanelBottom.hidden = true;
                        }
                    }];
                }
                else
                {
                    _editingPanelTop.frame = topFrame;
                    _editingPanelBottom.frame = bottomFrame;
                    _editingPanelTop.hidden = true;
                    _editingPanelBottom.hidden = true;
                }
            }
        }
    }
}

- (void)didEnterBackground:(NSNotification *)__unused notification
{
    [self pauseCamera];
}

- (void)willEnterForeground:(NSNotification *)__unused notification
{
    [self resumeCamera];
}

#pragma mark -

- (void)cameraDidStart
{
    [self fadeInCamera];
    
    _cameraPanelBottom.userInteractionEnabled = true;
    _flashButton.userInteractionEnabled = true;
}

- (void)cameraDidStop
{
    _cameraFocusIndicator.alpha = 0.0f;
    _cameraFocusIndicator.hidden = true;
}

- (void)cameraDidPause
{
    _cameraFocusIndicator.alpha = 0.0f;
    _cameraFocusIndicator.hidden = true;
}

- (void)cameraDidResume
{
}

#pragma mark -

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (!_scrollView.hidden)
    {
        CGPoint contentOffset = scrollView.contentOffset;
        contentOffset.y += 12;
        [_gpuImageView setImageTranslation:contentOffset];
    }
}

- (void)setFocusIndicatorState:(CGPoint)focusPoint show:(bool)show
{
    if (!(isnan(focusPoint.x) || isnan(focusPoint.y)))
        _cameraFocusIndicator.center = focusPoint;
    
    if (show)
    {
        _cameraFocusIndicator.hidden = false;
        if (_cameraFocusIndicator.alpha < 1.0f - FLT_EPSILON)
        {
            [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^
            {
                _cameraFocusIndicator.alpha = 1.0f;
            } completion:nil];
        }
    }
    else
    {
        if (_cameraFocusIndicator.alpha > FLT_EPSILON)
        {
            [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^
            {
                _cameraFocusIndicator.alpha = 0.0f;
            } completion:^(BOOL finished)
            {
                if (finished)
                {
                    _cameraFocusIndicator.hidden = true;
                }
            }];
        }
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)__unused object change:(NSDictionary *)change context:(void *)__unused context
{
    if ([keyPath isEqualToString:@"adjustingFocus"])
    {
        if (!_scrollView.hidden)
            return;
        
        bool adjustingFocus = [[change objectForKey:NSKeyValueChangeNewKey] isEqualToNumber:[NSNumber numberWithInt:1]];
        
        runAsynchronouslyOnVideoProcessingQueue(^
        {
            if (!_gpuCamera.inputCamera.isFocusPointOfInterestSupported)
                return;
            
            CGPoint focusPoint = _gpuCamera.inputCamera.focusPointOfInterest;
            if (isnan(focusPoint.x) || isnan(focusPoint.y) || focusPoint.x < 0 || focusPoint.y < 0 || focusPoint.x > 1.0f || focusPoint.y > 1.0f)
                return;
            
            CGSize screenSize = [TGViewController screenSizeForInterfaceOrientation:UIInterfaceOrientationPortrait];
            if (TGIsRetina())
            {
                screenSize.width *= 2;
                screenSize.height *= 2;
            }
            
            CGSize inputImageSize = [_gpuImageView inputImageSize];
            if (inputImageSize.width < FLT_EPSILON || inputImageSize.height < FLT_EPSILON)
                return;
            
            if (inputImageSize.height < screenSize.height)
            {
                inputImageSize.width = ceilf(inputImageSize.width * screenSize.height / inputImageSize.height);
                inputImageSize.height = screenSize.height;
            }
            if (inputImageSize.width < screenSize.width)
            {
                inputImageSize.height = ceilf(inputImageSize.height * screenSize.width / inputImageSize.width);
                inputImageSize.width = screenSize.width;
            }
            
            focusPoint.x *= inputImageSize.width;
            focusPoint.y *= inputImageSize.height;
            
            focusPoint.x -= floorf((inputImageSize.width - screenSize.width) / 2);
            focusPoint.y -= floorf((inputImageSize.height - screenSize.height) / 2);
            
            if (TGIsRetina())
            {
                focusPoint.x /= 2.0f;
                focusPoint.y /= 2.0f;
            }
            
            dispatch_async(dispatch_get_main_queue(), ^
            {
                [self setFocusIndicatorState:focusPoint show:adjustingFocus];
            });
        });
    }
}

- (void)gpuImageViewTapped:(UITapGestureRecognizer *)recognizer
{
    if (!_scrollView.isHidden || currentCameraPosition != AVCaptureDevicePositionBack)
        return;
    
    if (recognizer.state == UIGestureRecognizerStateRecognized)
    {
        CGPoint imageLocation = [recognizer locationInView:_gpuImageView];
        [self setFocusIndicatorState:[recognizer locationInView:self.view] show:true];
        
        runAsynchronouslyOnVideoProcessingQueue(^
        {
            if (_gpuCamera.inputCamera.focusPointOfInterestSupported && [_gpuCamera.inputCamera isFocusModeSupported:AVCaptureFocusModeAutoFocus])
            {
                NSError *error = nil;
                [_gpuCamera.inputCamera lockForConfiguration:&error];
                if (error == nil)
                {
                    CGPoint location = imageLocation;
                    CGSize screenSize = [TGViewController screenSizeForInterfaceOrientation:UIInterfaceOrientationPortrait];
                    if (TGIsRetina())
                    {
                        screenSize.width *= 2;
                        screenSize.height *= 2;
                        
                        location.x *= 2.0f;
                        location.y *= 2.0f;
                    }
                    
                    CGSize inputImageSize = [_gpuImageView inputImageSize];

                    if (inputImageSize.height < screenSize.height)
                    {
                        inputImageSize.width = ceilf(inputImageSize.width * screenSize.height / inputImageSize.height);
                        inputImageSize.height = screenSize.height;
                    }
                    if (inputImageSize.width < screenSize.width)
                    {
                        inputImageSize.height = ceilf(inputImageSize.height * screenSize.width / inputImageSize.width);
                        inputImageSize.width = screenSize.width;
                    }
                    
                    location.x += floorf((inputImageSize.width - screenSize.width) / 2);
                    location.y += floorf((inputImageSize.height - screenSize.height) / 2);
                    
                    location.x /= inputImageSize.width;
                    location.y /= inputImageSize.height;
                    
                    [_gpuCamera.inputCamera setFocusPointOfInterest:location];
                    [_gpuCamera.inputCamera setFocusMode:AVCaptureFocusModeAutoFocus];
                    
                    if (_gpuCamera.inputCamera.exposurePointOfInterestSupported && [_gpuCamera.inputCamera isExposureModeSupported:AVCaptureExposureModeAutoExpose])
                    {
                        [_gpuCamera.inputCamera setExposurePointOfInterest:location];
                        [_gpuCamera.inputCamera setExposureMode:AVCaptureExposureModeAutoExpose];
                    }
                    
                    [_gpuCamera.inputCamera unlockForConfiguration];
                }
            }
        });
    }
}

@end

#endif
