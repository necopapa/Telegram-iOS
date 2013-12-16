#import "TGMediaListView.h"

#import "TGRemoteImageView.h"

#import "TGMessage.h"

#import "TGImageUtils.h"
#import "TGInterfaceAssets.h"

#import <QuartzCore/QuartzCore.h>

@interface TGMediaListView ()

@property (nonatomic, strong) NSMutableArray *listModel;
@property (nonatomic, strong) UITableView *tableView;

@property (nonatomic, strong) NSMutableArray *remoteImages;
@property (nonatomic, strong) NSMutableArray *shadowViews;

@end

@implementation TGMediaListView

@synthesize watcherHandle = _watcherHandle;

@synthesize listModel = _listModel;
@synthesize tableView = _tableView;

@synthesize remoteImages = _remoteImages;
@synthesize shadowViews = _shadowViews;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        self.layer.anchorPoint = CGPointMake(0.5f, 0.0f);
        
        _listModel = [[NSMutableArray alloc] init];
        
        UIImage *shadowImage = [TGInterfaceAssets mediaListImageShadow];
        
        _remoteImages = [[NSMutableArray alloc] init];
        _shadowViews = [[NSMutableArray alloc] init];
        for (int i = 0; i < 5; i++)
        {
            UIImageView *shadowView = [[UIImageView alloc] initWithImage:shadowImage];
            [self addSubview:shadowView];
            [_shadowViews addObject:shadowView];
            TGRemoteImageView *imageView = [[TGRemoteImageView alloc] initWithFrame:CGRectZero];
            imageView.contentMode = UIViewContentModeScaleAspectFill;
            imageView.clipsToBounds = true;
            [imageView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(imageViewTapped:)]];
            imageView.fadeTransition = true;
            imageView.hidden = true;
            [self addSubview:imageView];
            [_remoteImages addObject:imageView];
        }
    }
    return self;
}

- (void)mediaListReloaded:(NSArray *)items
{
    [_listModel removeAllObjects];
    [_listModel addObjectsFromArray:items];
    
    int listCount = _listModel.count;
    int imagesCount = _remoteImages.count;
    
    CGSize imagePixelSize = CGSizeMake(100, 100);
    if (TGIsRetina())
    {
        imagePixelSize.width *= 2;
        imagePixelSize.height *= 2;
    }
    
    UIImage *placeholder = [TGInterfaceAssets mediaGridImagePlaceholder];
    
    for (int i = 0; i < imagesCount; i++)
    {
        TGRemoteImageView *imageView = [_remoteImages objectAtIndex:i];
        
        if (i < listCount)
        {
            NSString *imageUrl = nil;
            
            TGMessage *message = [_listModel objectAtIndex:i];
            for (TGMediaAttachment *attachment in message.mediaAttachments)
            {
                if (attachment.type == TGImageMediaAttachmentType)
                {
                    TGImageMediaAttachment *imageAttachment = (TGImageMediaAttachment *)attachment;
                    imageUrl = [imageAttachment.imageInfo closestImageUrlWithSize:imagePixelSize resultingSize:NULL];
                    break;
                }
            }
            
            if (imageUrl != nil)
                [imageView loadImage:imageUrl filter:@"mediaListImage" placeholder:placeholder];
            else
                [imageView loadImage:nil];
        }
        else
        {
            [imageView loadImage:nil];
        }
    }
    
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGSize imageSize = CGSizeMake(94, 94);
    
    int currentX = 0;
    
    int nImages = (int)(self.frame.size.width / imageSize.width);
    int spacing = (int)(((self.frame.size.width - imageSize.width * nImages) / (nImages - 1)));
    if (spacing > 6)
    {
        spacing = (int)(((self.frame.size.width - imageSize.width * nImages) / (nImages + 1)));
        currentX += spacing;
    }
    
    for (int i = 0; i < (int)_remoteImages.count; i++)
    {
        TGRemoteImageView *imageView = [_remoteImages objectAtIndex:i];
        UIImageView *shadowView = [_shadowViews objectAtIndex:i];
        imageView.frame = CGRectMake(currentX + 2, 2, imageSize.width - 4, imageSize.height - 4);
        shadowView.frame = CGRectMake(currentX - 1, - 1, imageSize.width + 2, imageSize.height + 2);
        currentX += imageSize.width + spacing;
        
        if (i >= nImages || imageView.currentUrl == nil)
        {
            imageView.hidden = true;
            shadowView.hidden = true;
        }
        else
        {
            imageView.hidden = false;
            shadowView.hidden = false;
        }
    }
}

- (UIView *)viewForItemId:(int)itemId
{
    int index = -1;
    for (TGMessage *message in _listModel)
    {
        index++;
        if (message.mid == itemId)
        {
            if (index < (int)_remoteImages.count)
            {
                UIView *view = [_remoteImages objectAtIndex:index];
                if (!view.hidden)
                    return view;
            }
            
            break;
        }
    }
    
    return nil;
}

#pragma mark -

- (void)imageViewTapped:(UITapGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateRecognized)
    {
        CGPoint point = [recognizer locationInView:self];
        
        int index = -1;
        for (TGRemoteImageView *imageView in _remoteImages)
        {
            index++;
            
            if (!imageView.hidden && CGRectContainsPoint(imageView.frame, point))
            {
                TGMessage *message = nil;
                if (index < (int)_listModel.count)
                    message = [_listModel objectAtIndex:index];
                
                if (message != nil)
                {
                    for (TGMediaAttachment *attachment in message.mediaAttachments)
                    {
                        if (attachment.type == TGImageMediaAttachmentType)
                        {
                            TGImageMediaAttachment *imageAttachment = (TGImageMediaAttachment *)attachment;
                            
                            if (imageAttachment.imageInfo != nil)
                            {
                                UIImage *currentImage = [imageView currentImage];
                                
                                id<ASWatcher> watcher = _watcherHandle.delegate;
                                if (watcher != nil && [watcher respondsToSelector:@selector(actionStageActionRequested:options:)])
                                {
                                    [watcher actionStageActionRequested:@"openImage" options:[[NSDictionary alloc] initWithObjectsAndKeys:currentImage, @"image", imageAttachment.imageInfo, @"imageInfo", [NSValue valueWithCGRect:[imageView convertRect:imageView.bounds toView:self.window]], @"rectInWindowCoords", [NSNumber numberWithInt:message.mid], @"tag", nil]];
                                }
                            }
                        }
                    }
                }
                
                break;
            }
        }
    }
}

@end
