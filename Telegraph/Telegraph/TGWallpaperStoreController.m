#import "TGWallpaperStoreController.h"

#import "TGInterfaceAssets.h"

#import "TGActionMenuItemCell.h"
#import "TGWallpaperItemsCell.h"
#import "TGWallpapersMenuItemCell.h"

#import "TGNavigationController.h"

#import "TGImageInfo.h"

#import "TGImageUtils.h"

#import "TGRemoteImageView.h"

#import "TGWallpaperPreviewController.h"

#import "TGAppDelegate.h"
#import "TGTelegraphConversationCompanion.h"

#import <QuartzCore/QuartzCore.h>

@interface TGWallpaperTableView : UITableView

@property (nonatomic, strong) UIImageView *listBackgroundView;

@end

@implementation TGWallpaperTableView

@synthesize listBackgroundView = _listBackgroundView;

- (id)initWithFrame:(CGRect)frame style:(UITableViewStyle)style
{
    self = [super initWithFrame:frame style:style];
    if (self != nil)
    {
        _listBackgroundView = [[UIImageView alloc] initWithImage:[TGInterfaceAssets groupedCellSingle]];
        [self insertSubview:_listBackgroundView atIndex:0];
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    if ([self.subviews objectAtIndex:0] != _listBackgroundView)
        [self sendSubviewToBack:_listBackgroundView];
    CGRect backgroundFrame = CGRectMake(9, 78, self.frame.size.width - 18, self.contentSize.height - 78 - 20);
    if (!CGRectEqualToRect(backgroundFrame, _listBackgroundView.frame))
        _listBackgroundView.frame = backgroundFrame;
}

@end

@interface TGWallpaperStoreController () <UITableViewDataSource, UITableViewDelegate, TGWallpaperItemsCellDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@property (nonatomic, strong) TGWallpaperTableView *tableView;
@property (nonatomic) int imagesInRow;

@property (nonatomic, strong) UIView *firstSectionView;
@property (nonatomic, strong) UIView *secondSectionView;
@property (nonatomic, strong) UIView *secondFooterView;

@property (nonatomic, strong) NSMutableArray *wallpaperList;

@property (nonatomic, strong) NSString *selectedUrl;

@end

@implementation TGWallpaperStoreController

- (id)init
{
    self = [super initWithNibName:nil bundle:nil];
    if (self)
    {
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:true];
        
        _wallpaperList = [[NSMutableArray alloc] init];
        
        _selectedUrl = @"local://wallpaper-thumb-default";
        
        NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true) objectAtIndex:0];
        NSString *wallpapersPath = [documentsDirectory stringByAppendingPathComponent:@"wallpapers"];
        NSData *customData = [[NSData alloc] initWithContentsOfFile:[wallpapersPath stringByAppendingPathComponent:@"_custom-meta"]];
        if (customData != nil)
            _selectedUrl = [[NSString alloc] initWithData:customData encoding:NSUTF8StringEncoding];
        
        [ActionStageInstance() watchForPath:@"/tg/assets/wallpaperList" watcher:self];
        [ActionStageInstance() requestActor:@"/tg/assets/wallpaperList/(cached)" options:nil flags:0 watcher:self];
    }
    return self;
}

- (void)dealloc
{
    [_actionHandle reset];
    [ActionStageInstance() removeWatcher:self];
    
    [self doUnloadView];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
}

- (BOOL)shouldAutorotate
{
    return true;
}

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

- (void)loadView
{
    [super loadView];
    
    self.view.backgroundColor = [[TGInterfaceAssets instance] linesBackground];
    
    self.backAction = @selector(performClose);
    self.titleText = TGLocalized(@"Wallpaper.Title");
    
    _firstSectionView = [[UIView alloc] init];
    _secondSectionView = [[UIView alloc] init];
    _secondFooterView = [[UIView alloc] init];
    
    _imagesInRow = (int)((self.view.frame.size.width - 26) / (86 + 8));
    
    _tableView = [[TGWallpaperTableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    _tableView.clipsToBounds = true;
    _tableView.backgroundColor = [UIColor clearColor];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.view addSubview:_tableView];
    
    UISwipeGestureRecognizer *rightSwipeRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(tableViewSwiped:)];
    rightSwipeRecognizer.direction = UISwipeGestureRecognizerDirectionRight;
    [_tableView addGestureRecognizer:rightSwipeRecognizer];
}

- (void)doUnloadView
{
    
}

- (void)viewDidUnload
{
    [self doUnloadView];
    
    [super viewDidUnload];
}

- (void)cleanupBeforeDestruction
{
    if ([self presentedViewController] != nil)
        [self dismissViewControllerAnimated:false completion:nil];
}

- (void)cleanupAfterDestruction
{
}

- (void)viewWillAppear:(BOOL)animated
{
    CGAffineTransform tableTransform = _tableView.transform;
    _tableView.transform = CGAffineTransformIdentity;
    
    CGSize screenSize = [TGViewController screenSizeForInterfaceOrientation:self.interfaceOrientation];
    
    CGRect tableFrame = CGRectMake(0, 0, screenSize.width, screenSize.height);
    _tableView.frame = tableFrame;
    
    int newImagesInRow = (int)((self.view.frame.size.width - 26) / (86 + 8));
    if (newImagesInRow != _imagesInRow)
    {
        _imagesInRow = newImagesInRow;
        [self reloadTable];
    }
    
    _tableView.transform = tableTransform;
    
    [super viewWillAppear:animated];
}

- (void)statusBarWillChangeFrame:(NSNotification *)notification
{
    if (!self.isViewLoaded)
        return;
    
    [UIView animateWithDuration:0.35 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^
    {
        CGRect statusBarFrame = [[[notification userInfo] objectForKey:UIApplicationStatusBarFrameUserInfoKey] CGRectValue];
        
        CGAffineTransform tableTransform = _tableView.transform;
        _tableView.transform = CGAffineTransformIdentity;
        
        CGSize screenSize = [TGViewController screenSizeForInterfaceOrientation:self.interfaceOrientation];
        
        CGSize statusBarSize = statusBarFrame.size;
        screenSize.height -= MIN(statusBarSize.width, statusBarSize.height);
        screenSize.height -= UIInterfaceOrientationIsPortrait(self.interfaceOrientation) ? 44 : 32;
        
        CGRect tableFrame = CGRectMake(0, 0, screenSize.width, screenSize.height);
        _tableView.frame = tableFrame;
        
        _tableView.transform = tableTransform;
    } completion:nil];
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    _tableView.clipsToBounds = false;
    
    UIGraphicsBeginImageContextWithOptions(self.view.bounds.size, true, 0.0f);
    [self.view.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *tableImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    UIImageView *temporaryImageView = [[UIImageView alloc] initWithImage:tableImage];
    temporaryImageView.frame = self.view.bounds;
    [self.view insertSubview:temporaryImageView aboveSubview:_tableView];
    
    [UIView animateWithDuration:duration animations:^
    {
        temporaryImageView.alpha = 0.0f;
    } completion:^(__unused BOOL finished)
    {
        [temporaryImageView removeFromSuperview];
    }];
    
    dispatch_async(dispatch_get_main_queue(), ^
    {
        CGSize screenSize = [TGViewController screenSizeForInterfaceOrientation:toInterfaceOrientation];
        
        CGAffineTransform tableTransform = _tableView.transform;
        _tableView.transform = CGAffineTransformIdentity;
        
        CGRect tableFrame = CGRectMake(0, 0, screenSize.width, screenSize.height);
        _tableView.frame = tableFrame;
        
        _imagesInRow = (int)((self.view.frame.size.width - 26) / (86 + 8));
        
        [self reloadTable];
        
        _tableView.transform = tableTransform;
    });
    
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    _tableView.clipsToBounds = true;
    
    [super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
}

#pragma mark -

- (void)performClose
{
    [self.navigationController popViewControllerAnimated:true];
}

- (void)tableViewSwiped:(UISwipeGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateRecognized)
    {
        if (recognizer.direction == UISwipeGestureRecognizerDirectionRight)
        {
            [self performClose];
        }
    }
}

- (void)wallpaperItemsCell:(TGWallpaperItemsCell *)__unused cell imagePressed:(NSDictionary *)wallpaperInfo
{
    TGWallpaperPreviewController *wallpaperPreviewController = [[TGWallpaperPreviewController alloc] initWithWallpaperInfo:wallpaperInfo];
    wallpaperPreviewController.watcherHandle = _actionHandle;
    
    [self presentViewController:wallpaperPreviewController animated:true completion:nil];
}

#pragma mark -

- (void)reloadTable
{
    [_tableView reloadData];
}

- (CGFloat)tableView:(UITableView *)__unused tableView heightForHeaderInSection:(NSInteger)__unused section
{
    if (section == 0)
        return 15;
    else if (section == 1)
        return 25;
    
    return 0;
}

- (CGFloat)tableView:(UITableView *)__unused tableView heightForFooterInSection:(NSInteger)section
{
    if (section == 1)
        return 30;
    
    return 0;
}

- (CGFloat)tableView:(UITableView *)__unused tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0)
        return 48;
    
    return 132;
}

- (UIView *)tableView:(UITableView *)__unused tableView viewForHeaderInSection:(NSInteger)section
{
    return section == 0 ? _firstSectionView : _secondSectionView;
}

- (UIView *)tableView:(UITableView *)__unused tableView viewForFooterInSection:(NSInteger)section
{
    if (section == 1)
        return _secondFooterView;
    
    return nil;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)__unused tableView
{
    return 2;
}

- (NSInteger)tableView:(UITableView *)__unused tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0)
        return 1;
    else if (section == 1)
        return _wallpaperList.count / _imagesInRow + (_wallpaperList.count % _imagesInRow != 0 ? 1 : 0);
    
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0)
    {
        static NSString *actionCellIdentifier = @"AC";
        TGActionMenuItemCell *actionCell = (TGActionMenuItemCell *)[tableView dequeueReusableCellWithIdentifier:actionCellIdentifier];
        if (actionCell == nil)
        {
            actionCell = [[TGActionMenuItemCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:actionCellIdentifier];
            
            actionCell.forcePaddings = true;
            
            UIImageView *backgroundView = [[UIImageView alloc] init];
            actionCell.backgroundView = backgroundView;
            UIImageView *selectedBackgroundView = [[UIImageView alloc] init];
            actionCell.selectedBackgroundView = selectedBackgroundView;
            
            ((UIImageView *)actionCell.backgroundView).image = [TGInterfaceAssets groupedCellSingle];
            ((UIImageView *)actionCell.selectedBackgroundView).image = [TGInterfaceAssets groupedCellSingleHighlighted];
            [(TGGroupedCell *)actionCell setExtendSelectedBackground:false];
        }
        
        actionCell.title = TGLocalized(@"Wallpaper.CameraRoll");
        
        return actionCell;
    }
    else if (indexPath.section == 1)
    {
        int rowStartIndex = indexPath.row * _imagesInRow;
        if (rowStartIndex < (int)_wallpaperList.count)
        {
            static NSString *wallpaperCellIdentifier = @"WC";
            TGWallpaperItemsCell *wallpaperCell = (TGWallpaperItemsCell *)[tableView dequeueReusableCellWithIdentifier:wallpaperCellIdentifier];
            if (wallpaperCell == nil)
            {
                wallpaperCell = [[TGWallpaperItemsCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:wallpaperCellIdentifier];
                wallpaperCell.selectionStyle = UITableViewCellSelectionStyleNone;
                wallpaperCell.delegate = self;
            }
            
            [wallpaperCell reset:_imagesInRow];
            
            int wallpaperListCount = _wallpaperList.count;
            for (int i = rowStartIndex; i < rowStartIndex + _imagesInRow && i < wallpaperListCount; i++)
            {
                NSDictionary *wallpaperInfo = [_wallpaperList objectAtIndex:i];
                [wallpaperCell addImage:wallpaperInfo];
            }
            
            [wallpaperCell setCheckedItem:_selectedUrl];
            
            return wallpaperCell;
        }
    }
    
    static NSString *emptyCellIdentifier = @"EC";
    UITableViewCell *emptyCell = [tableView dequeueReusableCellWithIdentifier:emptyCellIdentifier];
    if (emptyCell == nil)
        emptyCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:emptyCellIdentifier];
    return emptyCell;
}

#pragma mark -

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{   
    if (indexPath.section == 0 && indexPath.row == 0)
    {
        UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
        imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        imagePicker.delegate = self;
        
        [self presentViewController:imagePicker animated:true completion:^
        {
            [tableView deselectRowAtIndexPath:indexPath animated:false];
        }];
    }
}

- (void)imagePickerController:(UIImagePickerController *)__unused picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    UIImage *image = [info objectForKey:UIImagePickerControllerOriginalImage];
    
    TGWallpaperPreviewController *wallpaperPreviewController = [[TGWallpaperPreviewController alloc] initWithImage:image];
    wallpaperPreviewController.watcherHandle = _actionHandle;
    [picker pushViewController:wallpaperPreviewController animated:true];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)__unused picker
{
    if ([self respondsToSelector:@selector(dismissViewControllerAnimated:completion:)])
        [self dismissViewControllerAnimated:true completion:nil];
    else
        [self dismissModalViewControllerAnimated:true];
}

- (void)actionStageActionRequested:(NSString *)action options:(id)options
{
    if ([action isEqualToString:@"wallpaperSelected"])
    {
        if ([self respondsToSelector:@selector(dismissViewControllerAnimated:completion:)])
            [self dismissViewControllerAnimated:true completion:nil];
        else
            [self dismissModalViewControllerAnimated:true];
        
        TGImageInfo *imageInfo = [options objectForKey:@"imageInfo"];
        int tintColor = [options objectForKey:@"color"] == nil ? 0 : [[options objectForKey:@"color"] intValue];
        
        if (imageInfo == nil)
            return;
        
        NSString *thumbnailUrl = [imageInfo closestImageUrlWithWidth:172 resultingSize:NULL];
        if (thumbnailUrl == nil)
            return;
        
        NSFileManager *fileManager = [[NSFileManager alloc] init];
        NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true) objectAtIndex:0];
        NSString *wallpapersPath = [documentsDirectory stringByAppendingPathComponent:@"wallpapers"];
        [fileManager createDirectoryAtPath:wallpapersPath withIntermediateDirectories:true attributes:nil error:nil];
        [fileManager removeItemAtPath:[wallpapersPath stringByAppendingPathComponent:@"_custom.jpg"] error:nil];
        [fileManager removeItemAtPath:[wallpapersPath stringByAppendingPathComponent:@"_custom_mono.dat"] error:nil];
        [fileManager removeItemAtPath:[wallpapersPath stringByAppendingPathComponent:@"_custom-meta"] error:nil];
        
        NSString *url = [imageInfo closestImageUrlWithSize:CGSizeMake(640, 922) resultingSize:NULL];
        if (url != nil)
        {
            NSString *imageUrl = nil;
            if ([url rangeOfString:@"://"].location != NSNotFound)
                imageUrl = [url substringFromIndex:[url rangeOfString:@"://"].location + 3];
            else
                imageUrl = url;
            
            if (![imageUrl isEqualToString:@"wallpaper-original-default"])
            {
                NSString *filePath = nil;
                
                if ([imageUrl isEqualToString:@"wallpaper-original-pattern-default"])
                {
                    filePath = [[NSBundle mainBundle] pathForResource:imageUrl ofType:@"jpg"];
                    tintColor = 0x0c3259;
                }
                else
                    filePath = [[TGRemoteImageView sharedCache] pathForCachedData:imageUrl];
                
                if (filePath != nil)
                {
                    [fileManager copyItemAtPath:filePath toPath:[wallpapersPath stringByAppendingPathComponent:@"_custom.jpg"] error:nil];
                    [[thumbnailUrl dataUsingEncoding:NSUTF8StringEncoding] writeToFile:[wallpapersPath stringByAppendingPathComponent:@"_custom-meta"] atomically:false];
                    
                    [(tintColor == -1 ? [NSData data] : [[NSData alloc] initWithBytes:&tintColor length:4]) writeToFile:[wallpapersPath stringByAppendingPathComponent:@"_custom_mono.dat"] atomically:false];
                    
                    _selectedUrl = thumbnailUrl;
                    [ActionStageInstance() dispatchResource:@"/tg/assets/currentWallpaperUrl" resource:thumbnailUrl];
                    
                    TGAppDelegateInstance.customChatBackground = true;
                    [TGAppDelegateInstance saveSettings];
                    [TGTelegraphConversationCompanion resetBackgroundImage];
                }
            }
            else
            {
                _selectedUrl = thumbnailUrl;
                [ActionStageInstance() dispatchResource:@"/tg/assets/currentWallpaperUrl" resource:thumbnailUrl];
                
                [[NSData data] writeToFile:[wallpapersPath stringByAppendingPathComponent:@"_custom_mono.dat"] atomically:false];
                TGAppDelegateInstance.customChatBackground = false;
                [TGAppDelegateInstance saveSettings];
                [TGTelegraphConversationCompanion resetBackgroundImage];
            }
        }
        
        for (UITableViewCell *cell in _tableView.visibleCells)
        {
            if ([cell isKindOfClass:[TGWallpaperItemsCell class]])
            {
                [(TGWallpaperItemsCell *)cell setCheckedItem:_selectedUrl];
            }
        }
    }
    else if ([action isEqualToString:@"wallpaperImageSelected"])
    {
        UIImage *image = options;
        
        NSFileManager *fileManager = [[NSFileManager alloc] init];
        NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true) objectAtIndex:0];
        NSString *wallpapersPath = [documentsDirectory stringByAppendingPathComponent:@"wallpapers"];
        [fileManager createDirectoryAtPath:wallpapersPath withIntermediateDirectories:true attributes:nil error:nil];
        [fileManager removeItemAtPath:[wallpapersPath stringByAppendingPathComponent:@"_custom.jpg"] error:nil];
        [fileManager removeItemAtPath:[wallpapersPath stringByAppendingPathComponent:@"_custom_mono.dat"] error:nil];
        [fileManager removeItemAtPath:[wallpapersPath stringByAppendingPathComponent:@"_custom-meta"] error:nil];
        
        CGSize imageSize = TGFitSize(image.size, CGSizeMake(1136, 10000));
        image = TGScaleImageToPixelSize(image, imageSize);
        
        NSData *data = UIImageJPEGRepresentation(image, 0.9f);
        if (data != nil)
        {
            if ([data writeToFile:[wallpapersPath stringByAppendingPathComponent:@"_custom.jpg"] atomically:false])
            {
                [[@"image_from_gallery" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:[wallpapersPath stringByAppendingPathComponent:@"_custom-meta"] atomically:false];
                int zero = 0;
                [[NSData dataWithBytes:&zero length:4] writeToFile:[wallpapersPath stringByAppendingPathComponent:@"_custom_mono.dat"] atomically:false];
            }
        }
        
        _selectedUrl = @"image_from_gallery";
        [ActionStageInstance() dispatchResource:@"/tg/assets/currentWallpaperUrl" resource:_selectedUrl];
        
        TGAppDelegateInstance.customChatBackground = true;
        [TGAppDelegateInstance saveSettings];
        
        [TGTelegraphConversationCompanion resetBackgroundImage];
        
        for (UITableViewCell *cell in _tableView.visibleCells)
        {
            if ([cell isKindOfClass:[TGWallpaperItemsCell class]])
            {
                [(TGWallpaperItemsCell *)cell setCheckedItem:_selectedUrl];
            }
        }
        
        if ([self respondsToSelector:@selector(dismissViewControllerAnimated:completion:)])
            [self dismissViewControllerAnimated:true completion:nil];
        else
            [self dismissModalViewControllerAnimated:true];
    }
}

+ (NSString *)selectWallpaper:(NSDictionary *)wallpaperInfo
{
    TGImageInfo *imageInfo = [wallpaperInfo objectForKey:@"imageInfo"];
    int tintColor = [wallpaperInfo objectForKey:@"color"] == nil ? -1 : [[wallpaperInfo objectForKey:@"color"] intValue];
    
    if (imageInfo == nil)
        return nil;
    
    NSString *thumbnailUrl = [imageInfo closestImageUrlWithWidth:172 resultingSize:NULL];
    if (thumbnailUrl == nil)
        return nil;
    
    NSString *selectedUrl = nil;
    
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true) objectAtIndex:0];
    NSString *wallpapersPath = [documentsDirectory stringByAppendingPathComponent:@"wallpapers"];
    [fileManager createDirectoryAtPath:wallpapersPath withIntermediateDirectories:true attributes:nil error:nil];
    [fileManager removeItemAtPath:[wallpapersPath stringByAppendingPathComponent:@"_custom.jpg"] error:nil];
    [fileManager removeItemAtPath:[wallpapersPath stringByAppendingPathComponent:@"_custom_mono.dat"] error:nil];
    [fileManager removeItemAtPath:[wallpapersPath stringByAppendingPathComponent:@"_custom-meta"] error:nil];
    
    NSString *url = [imageInfo closestImageUrlWithSize:CGSizeMake(640, 922) resultingSize:NULL];
    if (url != nil)
    {
        NSString *imageUrl = nil;
        if ([url rangeOfString:@"://"].location != NSNotFound)
            imageUrl = [url substringFromIndex:[url rangeOfString:@"://"].location + 3];
        else
            imageUrl = url;
        
        if (![imageUrl isEqualToString:@"wallpaper-original-default"])
        {
            NSString *filePath = nil;
            if ([imageUrl isEqualToString:@"wallpaper-original-pattern-default"])
            {
                filePath = [[NSBundle mainBundle] pathForResource:imageUrl ofType:@"jpg"];
                tintColor = 0x0c3259;
            }
            else
                filePath = [[TGRemoteImageView sharedCache] pathForCachedData:imageUrl];
            
            if (filePath != nil)
            {
                [fileManager copyItemAtPath:filePath toPath:[wallpapersPath stringByAppendingPathComponent:@"_custom.jpg"] error:nil];
                [(tintColor == -1 ? [NSData data] : [[NSData alloc] initWithBytes:&tintColor length:4]) writeToFile:[wallpapersPath stringByAppendingPathComponent:@"_custom_mono.dat"] atomically:false];
                [[thumbnailUrl dataUsingEncoding:NSUTF8StringEncoding] writeToFile:[wallpapersPath stringByAppendingPathComponent:@"_custom-meta"] atomically:false];
                selectedUrl = thumbnailUrl;
                [ActionStageInstance() dispatchResource:@"/tg/assets/currentWallpaperUrl" resource:thumbnailUrl];
                
                TGAppDelegateInstance.customChatBackground = true;
                [TGAppDelegateInstance saveSettings];
                [TGTelegraphConversationCompanion resetBackgroundImage];
            }
        }
        else
        {
            selectedUrl = thumbnailUrl;
            [ActionStageInstance() dispatchResource:@"/tg/assets/currentWallpaperUrl" resource:thumbnailUrl];
            
            [[NSData data] writeToFile:[wallpapersPath stringByAppendingPathComponent:@"_custom_mono.dat"] atomically:false];
            TGAppDelegateInstance.customChatBackground = false;
            [TGAppDelegateInstance saveSettings];
            [TGTelegraphConversationCompanion resetBackgroundImage];
        }
    }
    
    return selectedUrl;
}

- (void)actionStageResourceDispatched:(NSString *)path resource:(id)resource arguments:(id)__unused arguments
{
    if ([path hasPrefix:@"/tg/assets/wallpaperList"])
    {
        [self actorCompleted:ASStatusSuccess path:path result:resource];
    }
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
                    [_tableView reloadData];
                }
            }
        });
    }
}

@end
