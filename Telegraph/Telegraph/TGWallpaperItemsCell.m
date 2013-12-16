#import "TGWallpaperItemsCell.h"

#import "TGRemoteImageView.h"

#import "TGInterfaceAssets.h"

#import "TGImageInfo.h"

@interface TGWallpaperItemsCell ()

@property (nonatomic) int imagesInRow;

@property (nonatomic, strong) NSMutableArray *imageViews;
@property (nonatomic, strong) NSMutableArray *wallpaperInfos;

@end

@implementation TGWallpaperItemsCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self)
    {
        self.backgroundColor = nil;
        self.opaque = false;
        
        _imageViews = [[NSMutableArray alloc] init];
        _wallpaperInfos = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)reset:(int)imagesInRow
{
    _imagesInRow = imagesInRow;
    
    for (TGRemoteImageView *imageView in _imageViews)
    {
        [imageView loadImage:nil];
        imageView.hidden = true;
    }
    
    [_wallpaperInfos removeAllObjects];
}

- (void)addImage:(NSDictionary *)wallpaperInfo
{
    TGRemoteImageView *imageView = nil;
    
    if (_wallpaperInfos.count < _imageViews.count)
        imageView = [_imageViews objectAtIndex:_wallpaperInfos.count];
    else
    {
        imageView = [[TGRemoteImageView alloc] init];
        imageView.fadeTransition = true;
        imageView.fadeTransitionDuration = 0.2;
        imageView.userInteractionEnabled = true;
        [imageView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(imageViewTapped:)]];
        [self.contentView addSubview:imageView];
        [_imageViews addObject:imageView];
        
        UIImageView *checkView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"WallpaperPhotoCheck.png"]];
        checkView.frame = CGRectOffset(checkView.frame, imageView.frame.size.width - checkView.frame.size.width - 3, imageView.frame.size.height - checkView.frame.size.height - 2);
        checkView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;
        checkView.tag = 100;
        [imageView addSubview:checkView];
    }
    
    imageView.hidden = false;
    [imageView viewWithTag:100].hidden = true;
    
    TGImageInfo *imageInfo = [wallpaperInfo objectForKey:@"imageInfo"];
    
    NSString *url = [imageInfo closestImageUrlWithWidth:172 resultingSize:NULL];
    [imageView loadImage:url filter:nil placeholder:[TGInterfaceAssets mediaGridImagePlaceholder]];
    [_wallpaperInfos addObject:wallpaperInfo];
}

- (void)setCheckedItem:(NSString *)url
{
    for (TGRemoteImageView *imageView in _imageViews)
    {
        if ([imageView.currentUrl isEqualToString:url])
            [imageView viewWithTag:100].hidden = false;
        else
            [imageView viewWithTag:100].hidden = true;
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    int imageCount = _wallpaperInfos.count;
    
    CGSize imageSize = CGSizeMake(86, 124);
    int widthSpacing = 8;
    float currentX = (int)((self.frame.size.width - (_imagesInRow * imageSize.width + (_imagesInRow - 1) * widthSpacing)) / 2);
    
    int count = _imageViews.count;
    int limit = MAX(count, imageCount);
    for (int i = 0; i < limit; i++)
    {
        TGRemoteImageView *imageView = [_imageViews objectAtIndex:i];
        
        if (i < imageCount)
        {
            imageView.frame = CGRectMake(currentX, 4, imageSize.width, imageSize.height);
            currentX += imageSize.width + widthSpacing;
        }
    }
}

- (void)imageViewTapped:(UITapGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateRecognized)
    {
        int index = -1;
        for (TGRemoteImageView *imageView in _imageViews)
        {
            index++;
            
            if (imageView == [recognizer view])
            {
                if ([imageView currentImage] != nil)
                {
                    __strong id delegate = _delegate;
                    if (delegate != nil)
                        [delegate wallpaperItemsCell:self imagePressed:[_wallpaperInfos objectAtIndex:index]];
                }
                
                break;
            }
        }
    }
}

@end
