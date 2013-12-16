#import "TGTimelineCell.h"

#import "TGImageUtils.h"
#import "TGDateUtils.h"

#import "ActionStage.h"
#import "SGraphObjectNode.h"

#import "TGLayoutModel.h"
#import "TGReusableLabel.h"
#import "TGRemoteImageView.h"

#import "TGInterfaceAssets.h"

#import <QuartzCore/QuartzCore.h>

static UIImage *photoShadowImage()
{
    static UIImage *image = nil;
    if (image == nil)
        image = [UIImage imageNamed:@"ActionPhotoShadow.png"];
    return image;
}

@interface TGTimelineCell () <UIGestureRecognizerDelegate>

@property (nonatomic, strong) UIView *photoActionsContainer;
@property (nonatomic, strong) UIGestureRecognizer *photoActionsRecognizer;
@property (nonatomic, strong) UIView *photoShadowTopView;
@property (nonatomic, strong) UIView *photoShadowBottomView;

@property (nonatomic, strong) UIButton *deletePhotoButton;
@property (nonatomic, strong) UIButton *actionPhotoButton;

@property (nonatomic, strong) UIView *cornerTL;
@property (nonatomic, strong) UIView *cornerTR;
@property (nonatomic, strong) UIView *cornerBL;
@property (nonatomic, strong) UIView *cornerBR;
@property (nonatomic, strong) UIImageView *locationIcon;
@property (nonatomic) int descriptionPrefixWidth;

@property (nonatomic, strong) UIImageView *uploadProgressBackground;
@property (nonatomic, strong) UIActivityIndicatorView *uploadProgressActivity;
@property (nonatomic, strong) UIImageView *uploadProgressDone;

@end

@implementation TGTimelineCell

+ (CGSize)timelineItemSize:(TGTimelineItem *)item
{
    TGLayoutModel *layout = item.cachedLayoutData;
    if (layout != nil)
        return layout.size;
    
    int height = 38;
    
    if (item.uploading)
    {
        height += 300;
    }
    else
    {    
        CGSize imageSizeRaw = CGSizeZero;
        
        float scale = TGIsRetina() ? 2.0f : 1.0f;
        [item.imageInfo closestImageUrlWithWidth:(int)(300 * scale) resultingSize:&imageSizeRaw];
        
        imageSizeRaw = TGFitSize(imageSizeRaw, CGSizeMake((int)(300 * scale), FLT_MAX));
        
        imageSizeRaw.width /= scale;
        imageSizeRaw.height /= scale;
        
        height += imageSizeRaw.height;
    }
    
    layout = [[TGLayoutModel alloc] init];
    layout.size = CGSizeMake(320, height);
    item.cachedLayoutData = layout;
    
    return layout.size;
}

@synthesize actionHandle = _actionHandle;

@synthesize date = _date;
@synthesize imageUrl = _imageUrl;
@synthesize imageSize = _imageSize;
@synthesize imageCache = _imageCache;

@synthesize customImage = _customImage;

@synthesize locationLatitude = _locationLatitude;
@synthesize locationLongitude = _locationLongitude;
@synthesize locationName = _locationName;

@synthesize uploading = _uploading;
@synthesize showActions = _showActions;
@synthesize actionHandler = _actionHandler;
@synthesize actionDelete = _actionDelete;
@synthesize actionAction = _actionAction;
@synthesize actionPanelAppeared = _actionPanelAppeared;
@synthesize actionTag = _actionTag;

@synthesize photoView = _photoView;

@synthesize photoActionsContainer = _photoActionsContainer;
@synthesize photoActionsRecognizer = _photoActionsRecognizer;
@synthesize photoShadowTopView = _photoShadowTopView;
@synthesize photoShadowBottomView = _photoShadowBottomView;

@synthesize deletePhotoButton = _deletePhotoButton;
@synthesize actionPhotoButton = _actionPhotoButton;

@synthesize cornerTL = _cornerTL;
@synthesize cornerTR = _cornerTR;
@synthesize cornerBL = _cornerBL;
@synthesize cornerBR = _cornerBR;
@synthesize locationIcon = _locationIcon;
@synthesize descriptionPrefixWidth = _descriptionPrefixWidth;

@synthesize uploadProgressBackground = _uploadProgressBackground;
@synthesize uploadProgressActivity = _uploadProgressActivity;
@synthesize uploadProgressDone = _uploadProgressDone;

@synthesize showingActions = _showingActions;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self)
    {
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:true];
        
        self.backgroundView = [[UIView alloc] init];
        self.backgroundView.backgroundColor = [UIColor whiteColor];
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        
        _locationIcon = [[UIImageView alloc] initWithImage:[TGInterfaceAssets timelineLocationIcon]];
        [self.contentView addSubview:_locationIcon];
        
        _photoView = [[TGRemoteImageView alloc] initWithFrame:CGRectZero];
        _photoView.fadeTransition = true;
        _photoView.allowThumbnailCache = true;
        _photoView.useCache = true;
        _photoView.fadeTransitionDuration = 0.2;
        _photoView.userInteractionEnabled = true;
        
        UITapGestureRecognizer *photoRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(photoTapped:)];
        [_photoView addGestureRecognizer:photoRecognizer];
        
        [self.contentView addSubview:_photoView];
        
        _photoActionsContainer = [[UIView alloc] initWithFrame:CGRectZero];
        _photoActionsContainer.backgroundColor = [UIColor clearColor];
        
        _photoActionsRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(photoTapped:)];
        _photoActionsRecognizer.delegate = self;
        [_photoActionsContainer addGestureRecognizer:_photoActionsRecognizer];
        
        _photoShadowBottomView = [[UIImageView alloc] initWithImage:photoShadowImage()];
        [_photoActionsContainer addSubview:_photoShadowBottomView];
        
        _deletePhotoButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 245, 46)];
        [_deletePhotoButton setBackgroundImage:[TGInterfaceAssets timelineDeletePhotoButton] forState:UIControlStateNormal];
        [_deletePhotoButton setBackgroundImage:[TGInterfaceAssets timelineDeletePhotoButtonHighlighted] forState:UIControlStateHighlighted];
        [_deletePhotoButton setTitle:NSLocalizedString(@"Timeline.DeletePhoto", @"") forState:UIControlStateNormal];
        [_deletePhotoButton setTitleColor:UIColorRGB(0xffffff) forState:UIControlStateNormal];
        [_deletePhotoButton setTitleShadowColor:UIColorRGB(0xd30815) forState:UIControlStateNormal];
        _deletePhotoButton.titleLabel.font = [UIFont boldSystemFontOfSize:17];
        _deletePhotoButton.titleLabel.shadowOffset = CGSizeMake(0, -1);
        [_deletePhotoButton addTarget:self action:@selector(deleteButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
        [_photoActionsContainer addSubview:_deletePhotoButton];
        
        _actionPhotoButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 245, 46)];
        [_actionPhotoButton setBackgroundImage:[TGInterfaceAssets timelineActionPhotoButton] forState:UIControlStateNormal];
        [_actionPhotoButton setBackgroundImage:[TGInterfaceAssets timelineActionPhotoButtonHighlighted] forState:UIControlStateHighlighted];
        [_actionPhotoButton setTitle:NSLocalizedString(@"Timeline.SetAsProfilePhoto", @"") forState:UIControlStateNormal];
        [_actionPhotoButton setTitleColor:UIColorRGB(0xffffff) forState:UIControlStateNormal];
        [_actionPhotoButton setTitleShadowColor:UIColorRGB(0x140000) forState:UIControlStateNormal];
        _actionPhotoButton.titleLabel.font = [UIFont boldSystemFontOfSize:17];
        _actionPhotoButton.titleLabel.shadowOffset = CGSizeMake(0, -1);
        [_actionPhotoButton addTarget:self action:@selector(actionButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
        [_photoActionsContainer addSubview:_actionPhotoButton];
        
        [self.contentView addSubview:_photoActionsContainer];
        
        NSArray *cornerImages = [TGInterfaceAssets timelineImageCorners];
        _cornerTL = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 2, 2)];
        _cornerTL.layer.contents = (id)[[cornerImages objectAtIndex:0] CGImage];
        [self.contentView addSubview:_cornerTL];
        _cornerTR = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 2, 2)];
        _cornerTR.layer.contents = (id)[[cornerImages objectAtIndex:1] CGImage];
        [self.contentView addSubview:_cornerTR];
        _cornerBL = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 2, 2)];
        _cornerBL.layer.contents = (id)[[cornerImages objectAtIndex:2] CGImage];
        [self.contentView addSubview:_cornerBL];
        _cornerBR = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 2, 2)];
        _cornerBR.layer.contents = (id)[[cornerImages objectAtIndex:3] CGImage];
        [self.contentView addSubview:_cornerBR];
        
    }
    return self;
}

- (void)dealloc
{
    [_actionHandle reset];
    [ActionStageInstance() removeWatcher:self];
}

- (void)hideProgress
{
    _uploadProgressBackground.hidden = true;
    [_uploadProgressActivity stopAnimating];
}

- (void)fadeInProgress
{
    if (!_uploading)
        return;
    
    _uploadProgressBackground.hidden = false;
    
    [_uploadProgressActivity startAnimating];
    _uploadProgressBackground.alpha = 0.0f;
    [UIView animateWithDuration:0.2 animations:^
    {
        _uploadProgressBackground.alpha = 1.0f;
    }];
    
    [self setNeedsLayout];
    [self layoutIfNeeded];
}

- (void)fadeOutProgress
{
    if (!_uploading)
        return;
    
    [UIView animateWithDuration:0.2 animations:^
    {
        _uploadProgressBackground.alpha = 0.0f;
    } completion:^(BOOL finished)
    {
        if (finished)
        {
            [_uploadProgressActivity stopAnimating];

            [_uploadProgressBackground removeFromSuperview];
            _uploadProgressBackground = nil;
            _uploadProgressActivity = nil;
            _uploadProgressDone = nil;
        }
    }];
}

- (void)setProgress:(float)value
{
    if (ABS(value - 1.0f) <= FLT_EPSILON)
    {
        [_uploadProgressActivity stopAnimating];
        
        [UIView animateWithDuration:0.1 animations:^
        {
            _uploadProgressActivity.alpha = 0.0f;
        }];
        
        [UIView animateWithDuration:0.2 animations:^
        {
            _uploadProgressDone.alpha = 1.0f;
        } completion:^(__unused BOOL finished)
        {
        }];
        
        [UIView animateWithDuration:0.3 delay:0.8 options:0 animations:^
        {
            _uploadProgressBackground.alpha = 0.0f;
        } completion:^(__unused BOOL finished)
        {
            [_uploadProgressBackground removeFromSuperview];
            _uploadProgressBackground = nil;
            _uploadProgressActivity = nil;
            _uploadProgressDone = nil;
        }];
    }
}

- (void)resetView
{   
    if (_imageCache != nil)
        _photoView.cache = _imageCache;

    if (_customImage != nil)
    {
        [_photoView loadImage:_customImage];
    }
    else if (_imageUrl == nil)
    {
        [_photoView loadImage:nil];
    }
    else
    {
        if (_photoView.currentUrl == nil || ![_photoView.currentUrl isEqualToString:_imageUrl])
            [_photoView loadImage:_imageUrl filter:[NSString stringWithFormat:@"scale:%dx%d", (int)_imageSize.width, (int)_imageSize.height] placeholder:[TGInterfaceAssets timelineImagePlaceholder]];
    }
    
    [_photoView.layer removeAllAnimations];
    _photoView.layer.transform = CATransform3DIdentity;
    
    _photoActionsContainer.hidden = true;
    [_photoActionsContainer.layer removeAllAnimations];
    _photoActionsContainer.transform = CGAffineTransformIdentity;
    
    [_deletePhotoButton.layer removeAllAnimations];
    _deletePhotoButton.transform = CGAffineTransformIdentity;
    [_actionPhotoButton.layer removeAllAnimations];
    _actionPhotoButton.transform = CGAffineTransformIdentity;
    
    [_photoShadowTopView.layer removeAllAnimations];
    _photoShadowTopView.transform = CGAffineTransformIdentity;
    [_photoShadowBottomView.layer removeAllAnimations];
    _photoShadowBottomView.transform = CGAffineTransformIdentity;
    
    _showingActions = false;
    
    if (_uploading)
    {
        if (_uploadProgressBackground == nil)
        {
            _uploadProgressBackground = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 64, 64)];
            _uploadProgressBackground.image = [[UIImage imageNamed:@"PhotoUploadProgress_Background.png"] stretchableImageWithLeftCapWidth:8 topCapHeight:8];
            [self.contentView addSubview:_uploadProgressBackground];
            
            _uploadProgressActivity = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
            _uploadProgressActivity.frame = CGRectOffset(_uploadProgressActivity.frame, (int)((_uploadProgressBackground.frame.size.width - _uploadProgressActivity.frame.size.width) / 2), (int)((_uploadProgressBackground.frame.size.height - _uploadProgressActivity.frame.size.height) / 2));
            [_uploadProgressBackground addSubview:_uploadProgressActivity];
            
            _uploadProgressDone = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"PhotoUploadProgress_Sent.png"]];
            _uploadProgressDone.frame = CGRectOffset(_uploadProgressDone.frame, (int)((_uploadProgressBackground.frame.size.width - _uploadProgressDone.frame.size.width) / 2), (int)((_uploadProgressBackground.frame.size.height - _uploadProgressDone.frame.size.height) / 2));
            [_uploadProgressBackground addSubview:_uploadProgressDone];
            _uploadProgressDone.alpha = 0.0f;
        }
        
        _uploadProgressBackground.hidden = false;
        _uploadProgressActivity.hidden = false;
        _uploadProgressActivity.alpha = 1.0f;
        _uploadProgressDone.alpha = 0.0f;
        [_uploadProgressActivity startAnimating];
    }
    else
    {
        _uploadProgressBackground.hidden = true;
        [_uploadProgressActivity stopAnimating];
    }
    
    if (_locationLatitude != 0.0 || _locationLongitude != 0.0)
    {
        _locationIcon.hidden = false;
    }
    else
    {
        _locationIcon.hidden = true;        
    }
}

- (void)resetLocation
{
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    int topPadding = 38;
    
    CGSize size = self.frame.size;
    
    CGRect photoFrame = CGRectMake((int)((size.width - _imageSize.width) / 2), topPadding, _imageSize.width, _imageSize.height);
    _photoView.frame = photoFrame;
    _photoActionsContainer.frame = photoFrame;
    int shadowHeight = (int)(photoShadowImage().size.height);
    _photoShadowBottomView.frame = CGRectMake(0, _photoActionsContainer.frame.size.height - shadowHeight, _photoActionsContainer.frame.size.width, shadowHeight);
    _cornerTL.frame = CGRectMake(photoFrame.origin.x, photoFrame.origin.y, 2, 2);
    _cornerTR.frame = CGRectMake(photoFrame.origin.x + photoFrame.size.width - 2, photoFrame.origin.y, 2, 2);
    _cornerBL.frame = CGRectMake(photoFrame.origin.x, photoFrame.origin.y + photoFrame.size.height - 2, 2, 2);
    _cornerBR.frame = CGRectMake(photoFrame.origin.x + photoFrame.size.width - 2, photoFrame.origin.y + photoFrame.size.height - 2, 2, 2);
    
    CGSize actionButtonSize = CGSizeMake(_photoActionsContainer.frame.size.width - 24, 43);
    _deletePhotoButton.frame = CGRectMake(((int)(_photoActionsContainer.frame.size.width - actionButtonSize.width) / 2), ((int)(_photoActionsContainer.frame.size.height - actionButtonSize.height * 2 - 8 - 12)), actionButtonSize.width, actionButtonSize.height);
    _actionPhotoButton.frame = CGRectOffset(_deletePhotoButton.frame, 0, actionButtonSize.height + 8);
    
    if (_uploadProgressBackground != nil)
    {
        _uploadProgressBackground.frame = CGRectMake((int)((size.width - _uploadProgressBackground.frame.size.width) / 2), topPadding + (int)((photoFrame.size.height - _uploadProgressBackground.frame.size.height) / 2), _uploadProgressBackground.frame.size.width, _uploadProgressBackground.frame.size.height);
    }
}

#pragma mark - Actions

- (void)deleteButtonPressed:(id)__unused sender
{
    if (_actionTag == nil)
        return;
    
    id<ASWatcher> watcher = _actionHandler.delegate;
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        if (watcher != nil && [watcher respondsToSelector:@selector(actionStageActionRequested:options:)])
            [watcher actionStageActionRequested:_actionDelete options:[NSDictionary dictionaryWithObject:_actionTag forKey:@"actionTag"]];
    }];
}

- (void)actionButtonPressed:(id)__unused sender
{
    if (_actionTag == nil)
        return;
    
    id<ASWatcher> watcher = _actionHandler.delegate;
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        if (watcher != nil && [watcher respondsToSelector:@selector(actionStageActionRequested:options:)])
            [watcher actionStageActionRequested:_actionAction options:[NSDictionary dictionaryWithObject:_actionTag forKey:@"actionTag"]];
    }];
}

- (void)descriptionLabelTapped:(UITapGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateRecognized && (_locationLatitude != 0.0 || _locationLongitude != 0.0))
    {
        id<ASWatcher> watcher = _actionHandler.delegate;
        if (watcher != nil && [watcher respondsToSelector:@selector(actionStageActionRequested:options:)])
            [watcher actionStageActionRequested:@"openMap" options:[NSDictionary dictionaryWithObjectsAndKeys:_actionTag, @"actionTag", [NSNumber numberWithDouble:_locationLatitude], @"latitude", [NSNumber numberWithDouble:_locationLongitude], @"longitude", nil]];
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    if (gestureRecognizer == _photoActionsRecognizer)
    {
        if ([touch.view isKindOfClass:[UIButton class]])
        {
            return false;
        }
    }
    return true;
}

+ (CATransform3D)createRotationTransform:(float)angle
{
    CATransform3D rotationAndPerspectiveTransform = CATransform3DIdentity;
    rotationAndPerspectiveTransform.m34 = 1.0f / -500.0f;
    rotationAndPerspectiveTransform = CATransform3DRotate(rotationAndPerspectiveTransform, angle, 0.0f, 1.0f, 0.0f);
    return rotationAndPerspectiveTransform;
}

- (void)photoTapped:(UITapGestureRecognizer *)recognizer
{
    if (_uploading || !_showActions)
        return;
    
    if (recognizer.state == UIGestureRecognizerStateEnded)
    {
        [self toggleShowActions];
    }
}

- (void)toggleShowActions
{
    _showingActions = !_showingActions;
    
    float shadowHeight = photoShadowImage().size.height;
    
    if (_showingActions)
    {
        id<ASWatcher> watcher = _actionHandler.delegate;
        [ActionStageInstance() dispatchOnStageQueue:^
        {
            if (watcher != nil && [watcher respondsToSelector:@selector(actionStageActionRequested:options:)])
                [watcher actionStageActionRequested:_actionPanelAppeared options:[NSDictionary dictionaryWithObject:_actionTag forKey:@"actionTag"]];
        }];
        
        _photoActionsContainer.hidden = false;
        _photoActionsContainer.alpha = 0.0f;
        _photoShadowBottomView.frame = CGRectMake(_photoShadowBottomView.frame.origin.x, _photoShadowBottomView.superview.frame.size.height - shadowHeight / 10.0f, _photoShadowBottomView.frame.size.width, shadowHeight / 10.0f);
        
        _deletePhotoButton.transform = CGAffineTransformMakeTranslation(0, _deletePhotoButton.frame.size.height / 2 + 8);
        _actionPhotoButton.transform = CGAffineTransformMakeTranslation(0, 16);

        [UIView animateWithDuration:0.25 animations:^
        {
            _photoActionsContainer.alpha = 1.0f;
            
            _photoShadowBottomView.frame = CGRectMake(_photoShadowBottomView.frame.origin.x, _photoShadowBottomView.superview.frame.size.height - shadowHeight, _photoShadowBottomView.frame.size.width, shadowHeight);
            
            _deletePhotoButton.transform = CGAffineTransformIdentity;
            _actionPhotoButton.transform = CGAffineTransformIdentity;
        }];
    }
    else
    {
        [UIView animateWithDuration:0.25 animations:^
        {
            _photoActionsContainer.alpha = 0.0f;
            
            _photoShadowBottomView.frame = CGRectMake(_photoShadowBottomView.frame.origin.x, _photoShadowBottomView.superview.frame.size.height - shadowHeight / 10.0f, _photoShadowBottomView.frame.size.width, shadowHeight / 10.0f);
            
            _deletePhotoButton.transform = CGAffineTransformMakeTranslation(0, _deletePhotoButton.frame.size.height / 2 + 8);
            _actionPhotoButton.transform = CGAffineTransformMakeTranslation(0, 16);
        } completion:^(BOOL finished)
        {
            if (finished)
                _photoActionsContainer.hidden = true;
        }];
    }
}

@end
