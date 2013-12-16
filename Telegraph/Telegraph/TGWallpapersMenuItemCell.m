#import "TGWallpapersMenuItemCell.h"

#import "TGInterfaceAssets.h"

#import "TGImageInfo.h"

#import "TGRemoteImageView.h"

#import "ActionStage.h"

#import "TGWallpaperListRequestActor.h"

@interface TGWallpapersMenuItemCell ()

@property (nonatomic, strong) NSMutableArray *imageViews;
@property (nonatomic, strong) NSMutableArray *wallpaperList;
@property (nonatomic, strong) NSString *selectedUrl;

@end

@implementation TGWallpapersMenuItemCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self)
    {
        self.backgroundColor = nil;
        self.opaque = false;
        
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:true];
        
        self.backgroundView = [[UIImageView alloc] initWithImage:[TGInterfaceAssets groupedCellSingle]];
        self.selectedBackgroundView = [[UIImageView alloc] initWithImage:[TGInterfaceAssets groupedCellSingleHighlighted]];
        
        _imageViews = [[NSMutableArray alloc] init];
        for (int i = 0; i < 5; i++)
        {
            TGRemoteImageView *imageView = [self generateWallpaperImageView];
            [self.contentView addSubview:imageView];
            [_imageViews addObject:imageView];
        }
        
        _wallpaperList = [[NSMutableArray alloc] init];
        
        _selectedUrl = @"local://wallpaper-thumb-default";
        
        NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true) objectAtIndex:0];
        NSString *wallpapersPath = [documentsDirectory stringByAppendingPathComponent:@"wallpapers"];
        NSData *customData = [[NSData alloc] initWithContentsOfFile:[wallpapersPath stringByAppendingPathComponent:@"_custom-meta"]];
        if (customData != nil)
        {
            _selectedUrl = [[NSString alloc] initWithData:customData encoding:NSUTF8StringEncoding];
        }
        
        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(11, self.frame.size.height - 32, self.contentView.frame.size.width - 30, 20)];
        titleLabel.contentMode = UIViewContentModeLeft;
        titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
        titleLabel.font = [UIFont boldSystemFontOfSize:17];
        titleLabel.backgroundColor = [UIColor whiteColor];
        titleLabel.textColor = [UIColor blackColor];
        titleLabel.highlightedTextColor = [UIColor whiteColor];
        titleLabel.text = TGLocalized(@"Settings.ChatBackground");
        [self.contentView addSubview:titleLabel];
        
        UIImageView *disclosureIndicator = [[UIImageView alloc] initWithImage:[TGInterfaceAssets groupedCellDisclosureArrow] highlightedImage:[TGInterfaceAssets groupedCellDisclosureArrowHighlighted]];
        disclosureIndicator.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;
        disclosureIndicator.frame = CGRectOffset(disclosureIndicator.frame, self.contentView.frame.size.width - disclosureIndicator.frame.size.width - 11, self.frame.size.height - disclosureIndicator.frame.size.height - 14);
        [self.contentView addSubview:disclosureIndicator];
        
        NSArray *cachedList = [TGWallpapersMenuItemCell filterWallpapersWithLocal:[TGWallpaperListRequestActor cachedList]];
        if (cachedList.count != 0)
            [_wallpaperList addObjectsFromArray:cachedList];
        
        [self reloadData:true];
        
        [ActionStageInstance() watchForPath:@"/tg/assets/wallpaperList" watcher:self];
        [ActionStageInstance() watchForPath:@"/tg/assets/currentWallpaperUrl" watcher:self];
        [ActionStageInstance() requestActor:@"/tg/assets/wallpaperList/(cached)" options:nil flags:0 watcher:self];
    }
    return self;
}

- (TGRemoteImageView *)generateWallpaperImageView
{
    TGRemoteImageView *imageView = [[TGRemoteImageView alloc] init];
    imageView.fadeTransition = true;
    imageView.fadeTransitionDuration = 0.2;
    imageView.userInteractionEnabled = true;
    [imageView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(imageViewTapped:)]];
    
    UIImageView *checkView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"WallpaperPhotoCheck.png"]];
    checkView.frame = CGRectOffset(checkView.frame, imageView.frame.size.width - checkView.frame.size.width - 3, imageView.frame.size.height - checkView.frame.size.height - 2);
    checkView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;
    checkView.tag = 100;
    [imageView addSubview:checkView];
    
    return imageView;
}

- (void)reloadData:(bool)synchronous
{
    for (int i = 0; i < (int)_wallpaperList.count && i < (int)_imageViews.count; i++)
    {
        TGRemoteImageView *imageView = [_imageViews objectAtIndex:i];
        imageView.hidden = false;
        
        TGImageInfo *imageInfo = [[_wallpaperList objectAtIndex:i] objectForKey:@"imageInfo"];
        
        NSString *url = [imageInfo closestImageUrlWithWidth:172 resultingSize:NULL];
        if (synchronous)
            imageView.contentHints = TGRemoteImageContentHintLoadFromDiskSynchronously;
        [imageView loadImage:url filter:nil placeholder:[TGInterfaceAssets mediaGridImagePlaceholder]];
        imageView.contentHints = 0;
        
        [imageView viewWithTag:100].hidden = ![url isEqualToString:_selectedUrl];
    }
    
    for (int i = _wallpaperList.count; i < (int)_imageViews.count; i++)
    {
        TGRemoteImageView *imageView = [_imageViews objectAtIndex:i];
        [imageView loadImage:nil];
        imageView.hidden = true;
    }
    
    [self setNeedsLayout];
}

- (void)dealloc
{
    [_actionHandle reset];
    [ActionStageInstance() removeWatcher:self];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGPoint offset = CGPointMake(10, 10);
    
    CGSize viewSize = self.contentView.frame.size;
    
    int imageCount = (int)((viewSize.width - 20 + 10) / (86 + 10));
    float spacing = floorf((viewSize.width - 20 - 86 * imageCount) / (imageCount - 1));
    
    int imageViewCount = _imageViews.count;
    int limit = MIN((int)_wallpaperList.count, imageCount);
    for (int i = 0; i < limit && i < imageViewCount; i++)
    {
        TGRemoteImageView *imageView = [_imageViews objectAtIndex:i];
        imageView.frame = CGRectMake((i == limit - 1) ? (viewSize.width - 10 - 86) : offset.x, offset.y, 86, 124);
        
        offset.x += 86 + spacing;
        
        imageView.hidden = false;
    }
    
    for (int i = limit; i < (int)_imageViews.count; i++)
    {
        TGRemoteImageView *imageView = [_imageViews objectAtIndex:i];
        imageView.hidden = true;
    }
}

#pragma mark -

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
                    [_watcherHandle requestAction:@"openWallpaper" options:[_wallpaperList objectAtIndex:index]];
                }
                
                break;
            }
        }
    }
}

- (void)actionStageResourceDispatched:(NSString *)path resource:(id)resource arguments:(id)__unused arguments
{
    if ([path hasPrefix:@"/tg/assets/wallpaperList"])
    {
        [self actorCompleted:ASStatusSuccess path:path result:resource];
    }
    else if ([path hasPrefix:@"/tg/assets/currentWallpaperUrl"])
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            _selectedUrl = resource;
            
            for (int i = 0; i < (int)_wallpaperList.count && i < (int)_imageViews.count; i++)
            {
                TGRemoteImageView *imageView = [_imageViews objectAtIndex:i];
                [imageView viewWithTag:100].hidden = ![imageView.currentUrl isEqualToString:_selectedUrl];
            }
        });
    }
}

+ (NSArray *)filterWallpapersWithLocal:(NSArray *)array
{
    NSMutableArray *filteredResult = [[NSMutableArray alloc] initWithCapacity:array.count];
    
    for (NSDictionary *dict in array)
    {
        int itemId = [dict[@"id"] intValue];
        
        if (itemId == 1000000 || itemId == 1000001)
        {
            if (itemId == 1000000)
            {
                TGImageInfo *defaultImageInfo = [[TGImageInfo alloc] init];
                [defaultImageInfo addImageWithSize:CGSizeMake(172, 248) url:@"local://wallpaper-thumb-default"];
                [defaultImageInfo addImageWithSize:CGSizeMake(640, 1002) url:@"local://wallpaper-original-default"];
                [filteredResult addObject:[[NSDictionary alloc] initWithObjectsAndKeys:[[NSNumber alloc] initWithInt:itemId], @"id", defaultImageInfo, @"imageInfo", nil]];
            }
            else if (itemId == 1000001)
            {
                TGImageInfo *defaultPattentImageInfo = [[TGImageInfo alloc] init];
                [defaultPattentImageInfo addImageWithSize:CGSizeMake(172, 248) url:@"local://wallpaper-thumb-pattern-default"];
                [defaultPattentImageInfo addImageWithSize:CGSizeMake(640, 1002) url:@"local://wallpaper-original-pattern-default"];
                [filteredResult addObject:[[NSDictionary alloc] initWithObjectsAndKeys:[[NSNumber alloc] initWithInt:itemId], @"id", defaultPattentImageInfo, @"imageInfo", nil]];
            }
        }
        else
            [filteredResult addObject:dict];
    }

    return filteredResult;
}

- (void)actorCompleted:(int)status path:(NSString *)path result:(id)result
{
    if ([path hasPrefix:@"/tg/assets/wallpaperList"])
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            if (status == ASStatusSuccess)
            {
                NSArray *resultArray = result;
                bool modified = false;

                NSArray *filteredResult = [TGWallpapersMenuItemCell filterWallpapersWithLocal:resultArray];
                
                if (_wallpaperList.count == resultArray.count)
                {
                    int index = -1;
                    for (NSDictionary *wallpaperDesc in filteredResult)
                    {
                        index++;
                        NSDictionary *localDesc = [_wallpaperList objectAtIndex:index];
                        if (![[localDesc objectForKey:@"imageInfo"] isEqual:[wallpaperDesc objectForKey:@"imageInfo"]])
                        {
                            modified = true;
                            break;
                        }
                    }
                }
                else
                    modified = true;
                
                if (modified)
                {
                    [_wallpaperList removeAllObjects];
                    [_wallpaperList addObjectsFromArray:filteredResult];
                    [self reloadData:false];
                }
            }
        });
    }
}

@end
