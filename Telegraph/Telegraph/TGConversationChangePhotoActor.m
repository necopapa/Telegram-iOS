#import "TGConversationChangePhotoActor.h"

#import "ActionStage.h"
#import "SGraphObjectNode.h"

#import "TGTelegraph.h"

#import "TGMessage+Telegraph.h"

#import "TGConversation+Telegraph.h"

#import "TGUserDataRequestBuilder.h"

#import "TGRemoteImageView.h"

#import "TGImageUtils.h"

#import "TGConversationAddMessagesActor.h"

#import "TGSession.h"

@interface TGConversationChangePhotoActor ()

@property (nonatomic) int64_t conversationId;
@property (nonatomic, strong) NSData *imageData;

@end

@implementation TGConversationChangePhotoActor

@synthesize actionHandle = _actionHandle;

@synthesize currentImage = _currentImage;

@synthesize conversationId = _conversationId;
@synthesize imageData = _imageData;

+ (NSString *)genericPath
{
    return @"/tg/conversation/@/updateAvatar/@";
}

- (id)initWithPath:(NSString *)path
{
    self = [super initWithPath:path];
    if (self != nil)
    {
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:false];
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
    _conversationId = [[options objectForKey:@"conversationId"] longLongValue];
    NSData *photoData = [options objectForKey:@"imageData"];
    if (_conversationId == 0)
    {
        [ActionStageInstance() actionFailed:self.path reason:-1];
        return;
    }
    
    _currentImage = [options objectForKey:@"currentImage"];
    _imageData = photoData;
    
    if (photoData == nil)
    {
        self.cancelToken = [TGTelegraphInstance doChangeConversationPhoto:_conversationId photo:[[TLInputChatPhoto$inputChatPhotoEmpty alloc] init] actor:self];
    }
    else
    {
        static int uploadIndex = 0;
        [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/upload/(%dccp)", uploadIndex++] options:[NSDictionary dictionaryWithObject:photoData forKey:@"data"] watcher:self];
    }
}

- (void)conversationUpdateAvatarSuccess:(TLmessages_StatedMessage *)statedMessage
{
    if (statedMessage.chats.count != 0)
    {
        [TGUserDataRequestBuilder executeUserDataUpdate:statedMessage.users];
        
        TGConversation *chatConversation = nil;
        
        NSMutableDictionary *chats = [[NSMutableDictionary alloc] init];
        
        for (TLChat *chatDesc in statedMessage.chats)
        {
            TGConversation *conversation = [[TGConversation alloc] initWithTelegraphChatDesc:chatDesc];
            if (conversation != nil)
            {
                if (chatConversation == nil)
                    chatConversation = conversation;
                [chats setObject:conversation forKey:[[NSNumber alloc] initWithLongLong:conversation.conversationId]];
            }
        }
        
        TGMessage *message = [[TGMessage alloc] initWithTelegraphMessageDesc:statedMessage.message];
        
        if (_imageData != nil)
        {
            UIImage *originalImage = [[UIImage alloc] initWithData:_imageData];
            
            if (message.actionInfo != nil && message.actionInfo.actionType == TGMessageActionChatEditPhoto)
            {
                TGImageMediaAttachment *imageAttachment = [message.actionInfo.actionData objectForKey:@"photo"];
                if (imageAttachment != nil)
                {
                    CGSize bigSize = CGSizeZero;
                    NSString *bigUrl = [imageAttachment.imageInfo closestImageUrlWithSize:CGSizeMake(600, 600) resultingSize:&bigSize];
                    if (bigUrl != nil)
                    {
                        NSData *bigImageData = UIImageJPEGRepresentation(TGScaleImageToPixelSize(originalImage, bigSize), 0.6f);
                        [[TGRemoteImageView sharedCache] cacheImage:nil withData:bigImageData url:bigUrl availability:TGCacheDisk];
                    }
                }
            }
            
            if (chatConversation.chatPhotoSmall.length != 0)
            {
                NSData *avatarData = UIImageJPEGRepresentation(TGScaleImageToPixelSize(originalImage, CGSizeMake(160, 160)), 0.6f);
                [[TGRemoteImageView sharedCache] cacheImage:nil withData:avatarData url:chatConversation.chatPhotoSmall availability:TGCacheDisk];
            }
        }
        
        static int actionId = 0;
        [[[TGConversationAddMessagesActor alloc] initWithPath:[[NSString alloc] initWithFormat:@"/tg/addmessage/(updateChatPhotoData%d)", actionId++]] execute:[[NSDictionary alloc] initWithObjectsAndKeys:[[NSArray alloc] initWithObjects:chatConversation, nil], @"chats", nil]];
        
        [[[TGConversationAddMessagesActor alloc] initWithPath:[[NSString alloc] initWithFormat:@"/tg/addmessage/(changeChatPhoto%d)", actionId++]] execute:[[NSDictionary alloc] initWithObjectsAndKeys:chats, @"chats", @[message], @"messages", nil]];
    
        [ActionStageInstance() actionCompleted:self.path result:[[SGraphObjectNode alloc] initWithObject:chatConversation]];
    }
    else
    {
        [ActionStageInstance() actionFailed:self.path reason:-1];
    }
    
    [[TGSession instance] updatePts:statedMessage.pts date:0 seq:statedMessage.seq];
}

- (void)conversationUpdateAvatarFailed
{
    [ActionStageInstance() actionFailed:self.path reason:-1];
}

- (void)actorCompleted:(int)resultCode path:(NSString *)path result:(id)result
{
    if ([path hasPrefix:@"/tg/upload/"])
    {
        if (resultCode == ASStatusSuccess)
        {
            TLInputFile *inputFile = result[@"file"];
            
            TLInputChatPhoto$inputChatUploadedPhoto *chatPhoto = [[TLInputChatPhoto$inputChatUploadedPhoto alloc] init];
            chatPhoto.crop = [[TLInputPhotoCrop$inputPhotoCropAuto alloc] init];
            chatPhoto.file = inputFile;
            
            self.cancelToken = [TGTelegraphInstance doChangeConversationPhoto:_conversationId photo:chatPhoto actor:self];
        }
        else
        {
            [ActionStageInstance() actionFailed:self.path reason:-1];
        }
    }
}

- (void)cancel
{
    _actionHandle.delegate = nil;
    [ActionStageInstance() removeWatcher:self];
    
    [super cancel];
}

@end
