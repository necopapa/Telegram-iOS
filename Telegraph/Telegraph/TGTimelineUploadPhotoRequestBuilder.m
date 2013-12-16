#import "TGTimelineUploadPhotoRequestBuilder.h"

#import <UIKit/UIKit.h>

#import <CommonCrypto/CommonDigest.h>

#import "ActionStage.h"
#import "SGraphObjectNode.h"

#import "TGTelegraph.h"
#import "TGUser+Telegraph.h"
#import "TGTimelineItem.h"
#import "TGImageMediaAttachment+Telegraph.h"

#import "TGImageUtils.h"

#import "TGUserDataRequestBuilder.h"

#import "TGRemoteImageView.h"

#import "TGDatabase.h"

#import <Security/Security.h>

#define FILE_CHUNK_SIZE (16 * 1024)

@interface TGTimelineUploadPhotoRequestBuilder ()

@property (nonatomic, strong) NSString *originalFileUrl;

@property (nonatomic, strong) NSData *fileData;

@property (nonatomic) double locationLatitude;
@property (nonatomic) double locationLongitude;

@end

@implementation TGTimelineUploadPhotoRequestBuilder

@synthesize actionHandle = _actionHandle;

@synthesize originalFileUrl = _originalFileUrl;

@synthesize currentPhoto = _currentPhoto;
@synthesize currentLoginBigPhoto = _currentLoginBigPhoto;

@synthesize fileData = _fileData;

@synthesize locationLatitude = _locationLatitude;
@synthesize locationLongitude = _locationLongitude;

+ (NSString *)genericPath
{
    return @"/tg/timeline/@/uploadPhoto/@";
}

- (id)initWithPath:(NSString *)path
{
    self = [super initWithPath:path];
    if (self != nil)
    {
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:false];
        
        self.cancelTimeout = 0;
        
        NSRange range = [self.path rangeOfString:@")/uploadPhoto/"];
        int timelineId = [[self.path substringWithRange:NSMakeRange(14, range.location - 14)] intValue];
        self.requestQueueName = [NSString stringWithFormat:@"timeline/%d", timelineId];
    }
    return self;
}

- (void)dealloc
{
    [_actionHandle reset];
    [ActionStageInstance() removeWatcher:self];
}

- (void)execute:(NSDictionary *)options
{
    _originalFileUrl = [options objectForKey:@"originalFileUrl"];
    
    NSString *tmpImagesPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true) objectAtIndex:0] stringByAppendingPathComponent:@"upload"];
    static NSFileManager *fileManager = nil;
    if (fileManager == nil)
        fileManager = [[NSFileManager alloc] init];
    NSError *error = nil;
    [fileManager createDirectoryAtPath:tmpImagesPath withIntermediateDirectories:true attributes:nil error:&error];
    NSString *absoluteFilePath = [tmpImagesPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.bin", _originalFileUrl]];
    
    NSData *imageData = [[NSData alloc] initWithContentsOfFile:absoluteFilePath];
    
    _locationLatitude = [[options objectForKey:@"latitude"] doubleValue];
    _locationLongitude = [[options objectForKey:@"longitude"] doubleValue];
    
    if (imageData == nil)
    {
        [self removeFromActionQueue];
        
        [ActionStageInstance() actionFailed:self.path reason:-1];
        
        return;
    }
    
    if (![[options objectForKey:@"restoringFromFutureAction"] boolValue])
    {
        [TGDatabaseInstance() storeFutureActions:[[NSArray alloc] initWithObjects:[[TGUploadAvatarFutureAction alloc] initWithOriginalFileUrl:_originalFileUrl latitude:_locationLatitude longitude:_locationLongitude], nil]];
    }
    
    _currentPhoto = [options objectForKey:@"currentPhoto"];
    if (_currentPhoto == nil)
    {
        UIImage *originalImage = [[UIImage alloc] initWithData:imageData];
        
        TGImageProcessor filter = [TGRemoteImageView imageProcessorForName:@"profileAvatar"];
        UIImage *toImage = filter(originalImage);
        
        dispatch_async(dispatch_get_main_queue(), ^
        {
            _currentPhoto = toImage;
        });
    }
    
    _fileData = imageData;

    static int actionId = 0;
    [ActionStageInstance() requestActor:[[NSString alloc] initWithFormat:@"/tg/upload/(userAvatar%d)", actionId++] options:[[NSDictionary alloc] initWithObjectsAndKeys:_fileData, @"data", nil] watcher:self];
}

- (UIImage *)currentLoginBigPhoto
{
    if (_currentLoginBigPhoto == nil)
    {
        UIImage *image = [[UIImage alloc] initWithData:_fileData];
        TGImageProcessor filter = [TGRemoteImageView imageProcessorForName:@"inactiveAvatar"];
        _currentLoginBigPhoto = filter(image);
    }
    
    return _currentLoginBigPhoto;
}

- (void)timelineUploadPhotoSuccess:(TLphotos_Photo *)photo
{
    [self removeFromActionQueue];
    
    TGTimelineItem *createdItem = [[TGTimelineItem alloc] initWithDescription:photo.photo];
    
    for (TLUser *userDesc in photo.users)
    {
        if (userDesc.n_id == TGTelegraphInstance.clientUserId)
        {
            TGUser *user = [[TGUser alloc] initWithTelegraphUserDesc:userDesc];
            if (user.photoUrlSmall != nil)
            {
                UIImage *originalImage = [[UIImage alloc] initWithData:_fileData];
                UIImage *scaledImage = TGScaleImageToPixelSize(originalImage, TGFitSize(originalImage.size, CGSizeMake(160, 160)));
                
                NSData *scaledData = UIImageJPEGRepresentation(scaledImage, 0.89f);
                [[TGRemoteImageView sharedCache] cacheImage:nil withData:scaledData url:user.photoUrlSmall availability:TGCacheDisk];
                
                NSData *fullData = UIImageJPEGRepresentation(TGScaleImageToPixelSize(originalImage, CGSizeMake(600, 600)), 0.6f);
                [[TGRemoteImageView sharedCache] cacheImage:nil withData:fullData url:user.photoUrlBig availability:TGCacheDisk];
            }
            break;
        }
    }
    [TGUserDataRequestBuilder executeUserDataUpdate:photo.users];
    
    TGImageMediaAttachment *imageAttachment = [[TGImageMediaAttachment alloc] initWithTelegraphDesc:photo.photo];
    if (imageAttachment != nil)
        [TGDatabaseInstance() storePeerProfilePhotos:TGTelegraphInstance.clientUserId photosArray:@[imageAttachment] append:true];
    
    [ActionStageInstance() actionCompleted:self.path result:[[SGraphObjectNode alloc] initWithObject:createdItem]];
}

- (void)timelineUploadPhotoFailed
{
    [self removeFromActionQueue];
    
    [ActionStageInstance() actionFailed:self.path reason:-1];
}

- (void)actorCompleted:(int)status path:(NSString *)path result:(id)result
{
    if ([path hasPrefix:@"/tg/upload/"])
    {
        if (status == ASStatusSuccess)
        {
            TLInputFile *inputFile = result[@"file"];
            
            self.cancelToken = [TGTelegraphInstance doUploadTimelinePhoto:inputFile.n_id parts:inputFile.parts md5:inputFile.md5_checksum hasLocation:ABS(_locationLatitude) > DBL_EPSILON || ABS(_locationLongitude) > DBL_EPSILON latitude:_locationLatitude longitude:_locationLongitude actor:self];
        }
        else
        {
            [self timelineUploadPhotoFailed];
        }
    }
}

- (void)cancel
{
    [self removeFromActionQueue];
    
    [ActionStageInstance() removeWatcher:self];
    
    [super cancel];
}

- (void)removeFromActionQueue
{
    NSArray *avatarActions = [TGDatabaseInstance() loadFutureActionsWithType:TGUploadAvatarFutureActionType];
    if (avatarActions.count != 0)
    {
        for (TGUploadAvatarFutureAction *action in avatarActions)
        {
            if ([action.originalFileUrl isEqualToString:_originalFileUrl])
            {
                [TGDatabaseInstance() removeFutureAction:action.uniqueId type:action.type randomId:action.randomId];
            }
        }
    }
}

@end
