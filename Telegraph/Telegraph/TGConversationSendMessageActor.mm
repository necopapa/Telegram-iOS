#import "TGConversationSendMessageActor.h"

#import "ActionStage.h"
#import "SGraphListNode.h"
#import "SGraphObjectNode.h"

#import "TGConversation+Telegraph.h"

#import "TGImageUtils.h"

#import "TGUpdateStateRequestBuilder.h"

#import "TGUserDataRequestBuilder.h"

#import "TGTelegraph.h"
#import "TGTelegraphProtocols.h"

#import "TGDatabase.h"

#import "TGMessage+Telegraph.h"

#import "TGImageInputMediaAttachment.h"
#import "TGVideoInputMediaAttachment.h"
#import "TGLocationInputMediaAttachment.h"
#import "TGContactInputMediaAttachment.h"
#import "TGForwardedMessageInputMediaAttachment.h"

#import "TGConversationAddMessagesActor.h"

#import "TGRemoteImageView.h"
#import "TGImageDownloadActor.h"

#import "TGVideoDownloadActor.h"

#import "TGTimer.h"

#import "TGSession.h"

#import "TLMetaClassStore.h"

#import "TGEncryption.h"
#import "TGSecurity.h"

@interface TGConversationSendMessageActor ()

@property (nonatomic) NSTimeInterval messageTimeout;

@property (nonatomic) int64_t tmpId;

@property (nonatomic, strong) NSString *messageText;
@property (nonatomic) int64_t conversationId;
@property (nonatomic, strong) NSMutableArray *uploadedMedia;

@property (nonatomic, strong) NSArray *broadcastUids;

@property (nonatomic, strong) TGLocalMessageMetaMediaAttachment *messageMeta;
@property (nonatomic, strong) NSArray *messageMedia;

@property (nonatomic, strong) TGTimer *timeoutTimer;
@property (nonatomic) NSTimeInterval uploadActivity;

@property (nonatomic, strong) TLInputFile *uploadedVideoFile;
@property (nonatomic, strong) TLInputFile *uploadedVideoThumbnail;
@property (nonatomic) int videoDuration;
@property (nonatomic) CGSize videoDimensions;

@property (nonatomic) bool isEncrypted;
@property (nonatomic) int64_t encryptedConversationId;
@property (nonatomic) int64_t accessHash;
@property (nonatomic) int32_t localDate;

@end

@implementation TGConversationSendMessageActor

+ (NSString *)genericPath
{
    return @"/tg/conversations/@/sendMessage/@";
}

- (id)initWithPath:(NSString *)path
{
    self = [super initWithPath:path];
    if (self != nil)
    {
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:false];
        
        _messageTimeout = 5 * 60;
        
        self.cancelTimeout = 0;
    }
    return self;
}

- (void)dealloc
{
    [_actionHandle reset];
    [ActionStageInstance() removeWatcher:self];
    
    if (_timeoutTimer != nil)
    {
        [_timeoutTimer invalidate];
        _timeoutTimer = nil;
    }
}

- (void)prepare:(NSDictionary *)options
{
    NSString *customQueue = nil;
    
    NSArray *media = [options objectForKey:@"media"];
    if (media != nil)
    {
        _messageMedia = media;
        
        bool isForward = false;
        
        for (TGInputMediaAttachment *attachment in media)
        {
            if ([attachment isKindOfClass:[TGForwardedMessageInputMediaAttachment class]])
            {
                isForward = true;
                break;
            }
        }
        
        for (TGInputMediaAttachment *attachment in media)
        {
            if ([attachment isKindOfClass:[TGImageInputMediaAttachment class]])
            {
                TGImageInputMediaAttachment *imageAttachment = (TGImageInputMediaAttachment *)attachment;
                if (!isForward)
                    customQueue = @"messagesUpload";
                if (imageAttachment.serverImageId == 0)
                {
                    customQueue = @"messagesUpload";
                    _hasProgress = true;
                    [ActionStageInstance() nodeRetrieveProgress:self.path progress:0.0f];
                    break;
                }
            }
            else if ([attachment isKindOfClass:[TGVideoInputMediaAttachment class]])
            {
                TGVideoInputMediaAttachment *videoAttachment = (TGVideoInputMediaAttachment *)attachment;
                if (!isForward)
                    customQueue = @"messagesUpload";
                if (videoAttachment.serverVideoId == 0)
                {
                    customQueue = @"messagesUpload";
                    _hasProgress = true;
                    [ActionStageInstance() nodeRetrieveProgress:self.path progress:0.0f];
                    break;
                }
            }
        }
    }
    
    if (customQueue == nil)
    {
        //self.requestQueueName = @"messages";
    }
    else
        self.requestQueueName = customQueue;
    
    _conversationId = [[options objectForKey:@"conversationId"] longLongValue];
    _messageLocalMid = [[options objectForKey:@"localMid"] intValue];
    _isEncrypted = [options[@"isEncrypted"] boolValue];
    _localDate = [options[@"date"] intValue];
    _encryptedConversationId = [options[@"encryptedConversationId"] longLongValue];
    _accessHash = [options[@"accessHash"] longLongValue];
    
    _broadcastUids = [options objectForKey:@"broadcastUids"];
    
    ASHandle *handle = _actionHandle;
    
    _timeoutTimer = [[TGTimer alloc] initWithTimeout:_messageTimeout repeat:false completion:^
    {
        id<ASWatcher> watcher = handle.delegate;
        if (watcher != nil && [watcher respondsToSelector:@selector(actionStageActionRequested:options:)])
            [watcher actionStageActionRequested:@"terminateSendMessage" options:nil];
    } queue:[ActionStageInstance() globalStageDispatchQueue]];
}

- (int64_t)tmpIdForLocalId:(int)localId
{
    if (_tmpId == 0)
    {
        arc4random_buf(&_tmpId, sizeof(int64_t));
        
        if (_messageMedia.count == 0 && localId != 0)
            [TGDatabaseInstance() setTempIdForMessageId:localId tempId:_tmpId];
    }
    
    return _tmpId;
}

- (void)execute:(NSDictionary *)options
{
    [_timeoutTimer start];
    
    _messageText = [options objectForKey:@"messageText"];
    NSArray *uploadedMedia = [options objectForKey:@"uploadedMedia"];
    NSArray *media = [options objectForKey:@"media"];
    _messageMeta = [options objectForKey:@"messageMeta"];
    
    if (options[@"tempId"] != nil)
        _tmpId = [options[@"tempId"] longLongValue];
    
    if (_messageText == nil && uploadedMedia == nil && media == nil)
    {
        [self failMessage];
        
        [self failAction];
        return;
    }
    
    int forwardMid = 0;
    TLInputGeoPoint *geoPoint = nil;
    
    bool waitingForUpload = false;
    if (media != nil && uploadedMedia == nil)
    {
        static int uploadIndex = 1;
        for (TGInputMediaAttachment *attachment in media)
        {
            if ([attachment isKindOfClass:[TGImageInputMediaAttachment class]])
            {
                TGImageInputMediaAttachment *imageAttachment = (TGImageInputMediaAttachment *)attachment;
                if (imageAttachment.serverImageId != 0)
                {
                    TLInputMedia$inputMediaPhoto *existingPhoto = [[TLInputMedia$inputMediaPhoto alloc] init];
                    TLInputPhoto$inputPhoto *inputPhoto = [[TLInputPhoto$inputPhoto alloc] init];
                    inputPhoto.n_id = imageAttachment.serverImageId;
                    inputPhoto.access_hash = imageAttachment.serverAccessHash;
                    existingPhoto.n_id = inputPhoto;
                    uploadedMedia = [NSArray arrayWithObject:existingPhoto];
                }
                else
                {
                    NSMutableDictionary *uploadOptions = [[NSMutableDictionary alloc] init];
                    
                    if (_isEncrypted)
                    {
                        UIImage *fullImage = [[UIImage alloc] initWithData:imageAttachment.imageData];
                        CGSize thumbnailSize = TGFitSize(fullImage.size, CGSizeMake(90, 90));
                        NSData *thumbnailData = UIImageJPEGRepresentation(TGScaleImageToPixelSize(fullImage, thumbnailSize), 0.6f);
                        if (thumbnailData != nil)
                            uploadOptions[@"thumbnail"] = thumbnailData;
                        
                        uploadOptions[@"thumbnailWidth"] = @((int)thumbnailSize.width);
                        uploadOptions[@"thumbnailHeight"] = @((int)thumbnailSize.height);
                        
                        uploadOptions[@"width"] = @((int)fullImage.size.width);
                        uploadOptions[@"height"] = @((int)fullImage.size.height);
                    }
                    
                    uploadOptions[@"data"] = imageAttachment.imageData;
                    uploadOptions[@"encrypt"] = @(_isEncrypted);
                    uploadOptions[@"fileSize"] = @(imageAttachment.imageData.length);
                    
                    [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/upload/(photo%d)", uploadIndex++] options:uploadOptions watcher:self];
                    waitingForUpload = true;
                }
            }
            else if ([attachment isKindOfClass:[TGVideoInputMediaAttachment class]])
            {
                TGVideoInputMediaAttachment *videoAttachment = (TGVideoInputMediaAttachment *)attachment;
                
                if (videoAttachment.serverVideoId != 0)
                {
                    TLInputMedia$inputMediaVideo *existingVideo = [[TLInputMedia$inputMediaVideo alloc] init];
                    
                    TLInputVideo$inputVideo *inputVideo = [[TLInputVideo$inputVideo alloc] init];
                    inputVideo.n_id = videoAttachment.serverVideoId;
                    inputVideo.access_hash = videoAttachment.serverAccessHash;
                    
                    existingVideo.n_id = inputVideo;
                    uploadedMedia = [[NSArray alloc] initWithObjects:existingVideo, nil];
                }
                else
                {   
                    NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true) objectAtIndex:0];
                    NSString *videosPath = [documentsDirectory stringByAppendingPathComponent:@"video"];
                    NSString *uploadVideoFile = [videosPath stringByAppendingPathComponent:[[NSString alloc] initWithFormat:@"local%llx.mov", videoAttachment.localVideoId]];
                    
                    _videoDuration = videoAttachment.duration;
                    _videoDimensions = videoAttachment.dimensions;
                    
                    UIImage *thumbnailImage = [[UIImage alloc] initWithData:videoAttachment.thumbnailData];
                    CGSize thumbnailSize = TGFitSize(thumbnailImage.size, CGSizeMake(90, 90));
                    NSData *thumbnailData = UIImageJPEGRepresentation(TGScaleImageToPixelSize(thumbnailImage, thumbnailSize), 0.6f);
                    
                    NSMutableDictionary *uploadOptions = [[NSMutableDictionary alloc] init];
                    uploadOptions[@"file"] = uploadVideoFile;
                    uploadOptions[@"ext"] = @"mov";
                    if (_isEncrypted && thumbnailData != nil)
                    {
                        uploadOptions[@"thumbnail"] = thumbnailData;
                        uploadOptions[@"thumbnailWidth"] = @((int)thumbnailSize.width);
                        uploadOptions[@"thumbnailHeight"] = @((int)thumbnailSize.height);
                    }
                    
                    uploadOptions[@"encrypt"] = @(_isEncrypted);
                    
                    [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/upload/(video_file%d)", uploadIndex++] options:uploadOptions watcher:self];
                    
                    if (!_isEncrypted)
                    {
                        [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/upload/(video_thumbnail%d)", uploadIndex++] options:[NSDictionary dictionaryWithObject:thumbnailData forKey:@"data"] watcher:self];
                    }
                    waitingForUpload = true;
                }
            }
            else if ([attachment isKindOfClass:[TGLocationInputMediaAttachment class]])
            {
                TGLocationInputMediaAttachment *locationAttachment = (TGLocationInputMediaAttachment *)attachment;
                geoPoint = [[TLInputGeoPoint$inputGeoPoint alloc] init];
                ((TLInputGeoPoint$inputGeoPoint *)geoPoint).lat = locationAttachment.latitude;
                ((TLInputGeoPoint$inputGeoPoint *)geoPoint).n_long = locationAttachment.longitude;
            }
            else if ([attachment isKindOfClass:[TGContactInputMediaAttachment class]])
            {
                TGContactInputMediaAttachment *contactAttachment = (TGContactInputMediaAttachment *)attachment;
                
                if (_isEncrypted)
                {
                    TLDecryptedMessageMedia$decryptedMessageMediaContact *contactMedia = [[TLDecryptedMessageMedia$decryptedMessageMediaContact alloc] init];
                    contactMedia.phone_number = contactAttachment.phoneNumber;
                    contactMedia.first_name = contactAttachment.firstName;
                    contactMedia.last_name = contactAttachment.lastName;
                    contactMedia.user_id = contactAttachment.uid;
                    
                    uploadedMedia = [[NSArray alloc] initWithObjects:contactMedia, nil];
                }
                else
                {
                    TLInputMedia$inputMediaContact *contactMedia = [[TLInputMedia$inputMediaContact alloc] init];
                    contactMedia.phone_number = contactAttachment.phoneNumber;
                    contactMedia.first_name = contactAttachment.firstName;
                    contactMedia.last_name = contactAttachment.lastName;
                    
                    uploadedMedia = [[NSArray alloc] initWithObjects:contactMedia, nil];
                }
            }
            else if ([attachment isKindOfClass:[TGForwardedMessageInputMediaAttachment class]])
            {
                TGForwardedMessageInputMediaAttachment *forwardedMessageAttachment = (TGForwardedMessageInputMediaAttachment *)attachment;
                
                forwardMid = forwardedMessageAttachment.forwardMid;
            }
        }
    }
    
    if (!waitingForUpload)
    {
        if (_broadcastUids != nil)
        {
            id inputMedia = nil;
            if (uploadedMedia.count != 0)
                inputMedia = [uploadedMedia objectAtIndex:0];
            else if (geoPoint != nil)
            {
                TLInputMedia$inputMediaGeoPoint *geoMedia = [[TLInputMedia$inputMediaGeoPoint alloc] init];
                geoMedia.geo_point = geoPoint;
                inputMedia = geoMedia;
            }
            self.cancelToken = [TGTelegraphInstance doBroadcastSendMessage:_broadcastUids messageText:_messageText media:inputMedia actor:self];
        }
        else
        {
            NSNumber *nConversationId = [options objectForKey:@"conversationId"];
            
            if (nConversationId == nil)
            {
                NSRange range;
                range.location = [@"/tg/conversations/(" length];
                range.length = [self.path rangeOfString:@")/" options:NSLiteralSearch range:NSMakeRange(range.location, [self.path length] - range.location)].location - range.location;
                int64_t conversationId = [[self.path substringWithRange:range] longLongValue];
                
                range.location = [self.path rangeOfString:@"/(" options:NSLiteralSearch range:NSMakeRange(range.location + range.length + 1, [self.path length] - range.location - range.length - 1)].location + 2;
                range.length = [self.path length] - 1 - range.location;
                
                nConversationId = [NSNumber numberWithLongLong:conversationId];
            }
            
            _conversationId = [nConversationId longLongValue];

            if (forwardMid != 0)
            {
                self.cancelToken = [TGTelegraphInstance doConversationForwardMessage:[nConversationId longLongValue] messageId:forwardMid tmpId:[self tmpIdForLocalId:_messageLocalMid] actor:self];
            }
            else if (uploadedMedia == nil || uploadedMedia.count == 0)
            {
                if (_isEncrypted)
                {
                    int64_t keyId = 0;
                    NSData *key = [TGDatabaseInstance() encryptionKeyForConversationId:_conversationId keyFingerprint:&keyId];
                    
                    if (key != nil)
                    {
                        id media = nil;
                        if (geoPoint != nil && [geoPoint isKindOfClass:[TLInputGeoPoint$inputGeoPoint class]])
                        {
                            TLDecryptedMessageMedia$decryptedMessageMediaGeoPoint *decryptedGeoPoint = [[TLDecryptedMessageMedia$decryptedMessageMediaGeoPoint alloc] init];
                            decryptedGeoPoint.lat = ((TLInputGeoPoint$inputGeoPoint *)geoPoint).lat;
                            decryptedGeoPoint.n_long = ((TLInputGeoPoint$inputGeoPoint *)geoPoint).n_long;
                            media = decryptedGeoPoint;
                        }
                        
                        NSData *encryptedMessage = [TGConversationSendMessageActor prepareEncryptedMessage:_messageText media:media key:key keyId:keyId];
                        if (encryptedMessage != nil)
                        {
                            int64_t randomId = 0;
                            arc4random_buf(&randomId, 8);
                            self.cancelToken = [TGTelegraphInstance doSendEncryptedMessage:_encryptedConversationId accessHash:_accessHash randomId:randomId data:encryptedMessage encryptedFile:options[@"encryptedFile"] actor:self];
                        }
                        else
                        {
                            TGLog(@"***** Couldn't encrypt message for conversation %lld", _encryptedConversationId);
                            
                            [self failMessage];
                            [self failAction];
                        }
                    }
                    else
                    {
                        TGLog(@"***** Couldn't find encryption key for conversation %lld", _encryptedConversationId);
                        
                        [self failMessage];
                        [self failAction];
                    }
                }
                else
                {
                    self.cancelToken = [TGTelegraphInstance doConversationSendMessage:[nConversationId longLongValue] messageText:_messageText geo:geoPoint messageGuid:[options objectForKey:@"guid"] tmpId:[self tmpIdForLocalId:_messageLocalMid] actor:self];
                }
            }
            else
            {
                if (_isEncrypted)
                {
                    int64_t keyId = 0;
                    NSData *key = [TGDatabaseInstance() encryptionKeyForConversationId:[TGDatabaseInstance() peerIdForEncryptedConversationId:_encryptedConversationId] keyFingerprint:&keyId];
                    
                    if (key != nil)
                    {
                        NSData *encryptedMessage = [TGConversationSendMessageActor prepareEncryptedMessage:_messageText media:[uploadedMedia objectAtIndex:0] key:key keyId:keyId];
                        if (encryptedMessage != nil)
                        {
                            int64_t randomId = 0;
                            arc4random_buf(&randomId, 8);
                            self.cancelToken = [TGTelegraphInstance doSendEncryptedMessage:_encryptedConversationId accessHash:_accessHash randomId:randomId data:encryptedMessage encryptedFile:options[@"encryptedFile"] actor:self];
                        }
                        else
                        {
                            TGLog(@"***** Couldn't encrypt message for conversation %lld", _encryptedConversationId);
                            
                            [self failMessage];
                            [self failAction];
                        }
                    }
                    else
                    {
                        TGLog(@"***** Couldn't find encryption key for conversation %lld", _encryptedConversationId);
                        
                        [self failMessage];
                        [self failAction];
                    }
                }
                else
                {
                    self.cancelToken = [TGTelegraphInstance doConversationSendMedia:[nConversationId longLongValue] media:[uploadedMedia objectAtIndex:0] messageGuid:[options objectForKey:@"guid"] tmpId:[self tmpIdForLocalId:_messageLocalMid] actor:self];
                }
            }
        }
    }
}

- (void)conversationSendMessageRequestSuccess:(id)abstractMessage
{
/*#ifdef DEBUG
    self.cancelToken = [TGTelegraphInstance doConversationSendMessage:_conversationId messageText:_messageText geo:nil messageGuid:nil actor:self];
    return;
#endif*/
    TGMessage *message = nil;
    
    int messageMid = 0;
    int messageDate = 0;
    if ([abstractMessage isKindOfClass:[TLmessages_Message$messages_message class]])
    {
        message = [[TGMessage alloc] initWithTelegraphMessageDesc:((TLmessages_Message$messages_message *)abstractMessage).message];
        messageMid = message.mid;
        messageDate = (int)message.date;
    }
    else if ([abstractMessage isKindOfClass:[TLmessages_StatedMessage class]])
    {
        TLmessages_StatedMessage *statedMessage = abstractMessage;
        
        message = [[TGMessage alloc] initWithTelegraphMessageDesc:statedMessage.message];
        messageMid = message.mid;
        messageDate = (int)message.date;
        
        [TGUserDataRequestBuilder executeUserDataUpdate:statedMessage.users];
        if (statedMessage.chats.count != 0)
        {
            NSMutableArray *chats = [[NSMutableArray alloc] init];
            
            for (TLChat *chatDesc in statedMessage.chats)
            {
                TGConversation *conversation = [[TGConversation alloc] initWithTelegraphChatDesc:chatDesc];
                if (conversation != nil)
                    [chats addObject:conversation];
            }
            
            static int actionId = 0;
            [[[TGConversationAddMessagesActor alloc] initWithPath:[[NSString alloc] initWithFormat:@"/tg/addmessage/(sendMessage%d)", actionId++]] execute:[[NSDictionary alloc] initWithObjectsAndKeys:chats, @"chats", nil]];
        }
        
        [[TGSession instance] updatePts:statedMessage.pts date:0 seq:statedMessage.seq];
    }
    else if ([abstractMessage isKindOfClass:[TLmessages_SentMessage class]])
    {
        TLmessages_SentMessage *concreteMessage = abstractMessage;
        
        messageMid = concreteMessage.n_id;
        messageDate = concreteMessage.date;
        
        [[TGSession instance] updatePts:concreteMessage.pts date:0 seq:concreteMessage.seq];
        
        message = [[TGMessage alloc] init];
        message.mid = messageMid;
        message.unread = true;
        message.outgoing = true;
        message.deliveryState = TGMessageDeliveryStateDelivered;
        message.fromUid = TGTelegraphInstance.clientUserId;
        message.toUid = _conversationId;
        message.cid = _conversationId;
        
        message.text = _messageText;
        message.date = messageDate;
        
        //TGLog(@"mid %d, date %d for \"%@\"", messageMid, messageDate, _messageText);
    }

    [self successMessage:message messageMid:messageMid messageDate:messageDate];
    
    [self completeAction:[self.path hasPrefix:@"/tg/conversations/(meta)"] ? @{@"message": message} : [[SGraphListNode alloc] initWithItems:[NSArray arrayWithObject:message]]];
}

- (void)conversationSendMessageQuickAck
{
    if (_messageLocalMid != 0 && _messageMedia.count == 0)
    {
        std::vector<TGDatabaseMessageFlagValue> flags;
        TGDatabaseMessageFlagValue deliveryStateValue = { TGDatabaseMessageFlagDeliveryState, TGMessageDeliveryStateDelivered };
        flags.push_back(deliveryStateValue);
        
        [TGDatabaseInstance() updateMessage:_messageLocalMid flags:flags dispatch:true];
        
        [ActionStageInstance() dispatchMessageToWatchers:self.path messageType:@"messageDelivered" message:[[NSNumber alloc] initWithInt:_messageLocalMid]];
    }
}

- (void)conversationSendMessageRequestFailed
{
    [self failMessage];
    
    [self failAction];
}

- (void)conversationSendBroadcastSuccess:(NSArray *)__unused messages
{
    [self completeAction:nil];
}

- (void)conversationSendBroadcastFailed
{
    [self failAction];
}

- (void)sendEncryptedMessageSuccess:(int32_t)date encryptedFile:(TLEncryptedFile *)encryptedFile
{
    std::vector<TGDatabaseMessageFlagValue> flags;
    TGDatabaseMessageFlagValue deliveryStateValue = { TGDatabaseMessageFlagDeliveryState, TGMessageDeliveryStateDelivered };
    flags.push_back(deliveryStateValue);
    TGDatabaseMessageFlagValue dateValue = { TGDatabaseMessageFlagDate, date };
    flags.push_back(dateValue);
    
    TGMessage *message = [[TGMessage alloc] init];
    message.mid = _messageLocalMid;
    message.unread = true;
    message.outgoing = true;
    message.deliveryState = TGMessageDeliveryStateDelivered;
    message.fromUid = TGTelegraphInstance.clientUserId;
    message.toUid = _conversationId;
    message.cid = _conversationId;
    
    message.text = _messageText;
    message.date = date;
    
    if (_messageMedia.count != 0)
    {
        if ([_messageMedia[0] isKindOfClass:[TGLocationInputMediaAttachment class]])
        {
            TGLocationInputMediaAttachment *locationInputAttachment = _messageMedia[0];
            
            TGLocationMediaAttachment *locationAttachment = [[TGLocationMediaAttachment alloc] init];
            locationAttachment.latitude = locationInputAttachment.latitude;
            locationAttachment.longitude = locationInputAttachment.longitude;
            
            message.mediaAttachments = @[locationAttachment];
        }
        else if ([_messageMedia[0] isKindOfClass:[TGContactInputMediaAttachment class]])
        {
            TGContactInputMediaAttachment *contactInputAttachment = _messageMedia[0];
            
            TGContactMediaAttachment *contactAttachment = [[TGContactMediaAttachment alloc] init];
            contactAttachment.firstName = contactInputAttachment.firstName;
            contactAttachment.lastName = contactInputAttachment.lastName;
            contactAttachment.phoneNumber = contactInputAttachment.phoneNumber;
            contactAttachment.uid = contactInputAttachment.uid;
            
            message.mediaAttachments = @[contactAttachment];
        }
    }
    
    [self successMessage:message messageMid:_messageLocalMid messageDate:date];
    
    [self completeAction:[self.path hasPrefix:@"/tg/conversations/(meta)"] ? @{@"message": message, @"encryptedFile": encryptedFile == nil ? [[TLEncryptedFile$encryptedFileEmpty alloc] init] : encryptedFile} : [[SGraphListNode alloc] initWithItems:[NSArray arrayWithObject:message]]];
}

- (void)sendEncryptedMessageFailed
{
    [self failMessage];
    
    [self failAction];
}

- (void)actorReportedProgress:(NSString *)path progress:(float)progress
{
    if ([path hasPrefix:@"/tg/upload/(photo"] || [path hasPrefix:@"/tg/upload/(video_file"])
    {
        _progress = progress;
        
        [_timeoutTimer resetTimeout:_messageTimeout];
        
        [ActionStageInstance() nodeRetrieveProgress:self.path progress:progress];
    }
}

- (void)actorCompleted:(int)resultCode path:(NSString *)path result:(id)result
{
    if ([path hasPrefix:@"/tg/upload/"])
    {
        if (resultCode == ASStatusSuccess)
        {
            if ([path hasPrefix:@"/tg/upload/(photo"])
            {
                TLInputEncryptedFile *encryptedFile = nil;
                
                if (_isEncrypted)
                {
                    TLInputEncryptedFile$inputEncryptedFileUploaded *inputFile = result[@"file"];
                    
                    TLDecryptedMessageMedia$decryptedMessageMediaPhoto *encryptedPhoto = [[TLDecryptedMessageMedia$decryptedMessageMediaPhoto alloc] init];
                    encryptedPhoto.key = result[@"key"];
                    encryptedPhoto.iv = result[@"iv"];
                    encryptedPhoto.thumb = result[@"thumbnail"];
                    encryptedPhoto.thumb_w = [result[@"thumbnailWidth"] intValue];
                    encryptedPhoto.thumb_h = [result[@"thumbnailHeight"] intValue];
                    encryptedPhoto.w = [result[@"width"] intValue];
                    encryptedPhoto.h = [result[@"height"] intValue];
                    encryptedPhoto.size = [result[@"fileSize"] intValue];
                    
                    if (_uploadedMedia == nil)
                        _uploadedMedia = [[NSMutableArray alloc] init];
                    [_uploadedMedia addObject:encryptedPhoto];
                    
                    encryptedFile = inputFile;
                }
                else
                {
                    TLInputFile *inputFile = result[@"file"];
                    
                    TLInputMedia$inputMediaUploadedPhoto *uploadedPhoto = [[TLInputMedia$inputMediaUploadedPhoto alloc] init];
                    uploadedPhoto.file = inputFile;
                    
                    if (_uploadedMedia == nil)
                        _uploadedMedia = [[NSMutableArray alloc] init];
                    [_uploadedMedia addObject:uploadedPhoto];
                }
                
                NSMutableDictionary *options = [[NSMutableDictionary alloc] init];
                
                if (_broadcastUids != nil)
                    [options setObject:_broadcastUids forKey:@"broadcastUids"];
                else
                    [options setObject:[NSNumber numberWithLongLong:_conversationId] forKey:@"conversationId"];
                
                [options setObject:_uploadedMedia forKey:@"uploadedMedia"];
                if (_messageMeta != nil)
                    [options setObject:_messageMeta forKey:@"messageMeta"];
                
                options[@"tempId"] = @([self tmpIdForLocalId:_messageLocalMid]);
                
                options[@"isEncrypted"] = @(_isEncrypted);
                options[@"encryptedConversationId"] = @(_encryptedConversationId);
                options[@"accessHash"] = @(_accessHash);
                
                if (encryptedFile != nil)
                    options[@"encryptedFile"] = encryptedFile;
                
                [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/conversations/(meta)/sendMessage/(%d)", _messageLocalMid] options:options watcher:self];
            }
            else if ([path hasPrefix:@"/tg/upload/(video"])
            {
                TLInputFile *inputFile = result[@"file"];
                
                if ([path hasPrefix:@"/tg/upload/(video_file"])
                    _uploadedVideoFile = inputFile;
                else if ([path hasPrefix:@"/tg/upload/(video_thumbnail"])
                    _uploadedVideoThumbnail = inputFile;
                
                if (_uploadedVideoFile != nil && (_uploadedVideoThumbnail != nil || _isEncrypted))
                {
                    if (_isEncrypted)
                    {
                        TLDecryptedMessageMedia$decryptedMessageMediaVideo *uploadedVideo = [[TLDecryptedMessageMedia$decryptedMessageMediaVideo alloc] init];
                        uploadedVideo.thumb = result[@"thumbnail"];
                        uploadedVideo.thumb_w = [result[@"thumbnailWidth"] intValue];
                        uploadedVideo.thumb_h = [result[@"thumbnailHeight"] intValue];
                        uploadedVideo.duration = _videoDuration;
                        uploadedVideo.w = (int)_videoDimensions.width;
                        uploadedVideo.h = (int)_videoDimensions.height;
                        uploadedVideo.key = result[@"key"];
                        uploadedVideo.iv = result[@"iv"];
                        uploadedVideo.size = [result[@"fileSize"] intValue];
                        
                        if (_uploadedMedia == nil)
                            _uploadedMedia = [[NSMutableArray alloc] init];
                        [_uploadedMedia addObject:uploadedVideo];
                        
                        NSMutableDictionary *options = [[NSMutableDictionary alloc] init];
                        
                        if (_broadcastUids != nil)
                            [options setObject:_broadcastUids forKey:@"broadcastUids"];
                        else
                            [options setObject:[NSNumber numberWithLongLong:_conversationId] forKey:@"conversationId"];
                        
                        [options setObject:_uploadedMedia forKey:@"uploadedMedia"];
                        if (_messageMeta != nil)
                            [options setObject:_messageMeta forKey:@"messageMeta"];
                        
                        options[@"tempId"] = @([self tmpIdForLocalId:_messageLocalMid]);
                        
                        options[@"isEncrypted"] = @(_isEncrypted);
                        options[@"encryptedConversationId"] = @(_encryptedConversationId);
                        options[@"accessHash"] = @(_accessHash);
                        
                        if (result[@"file"] != nil)
                            options[@"encryptedFile"] = result[@"file"];
                        
                        [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/conversations/(meta)/sendMessage/(%d)", _messageLocalMid] options:options watcher:self];
                    }
                    else
                    {
                        TLInputMedia$inputMediaUploadedThumbVideo *uploadedVideo = [[TLInputMedia$inputMediaUploadedThumbVideo alloc] init];
                        uploadedVideo.file = _uploadedVideoFile;
                        uploadedVideo.thumb = _uploadedVideoThumbnail;
                        uploadedVideo.duration = _videoDuration;
                        uploadedVideo.w = (int)_videoDimensions.width;
                        uploadedVideo.h = (int)_videoDimensions.height;
                        
                        if (_uploadedMedia == nil)
                            _uploadedMedia = [[NSMutableArray alloc] init];
                        [_uploadedMedia addObject:uploadedVideo];
                        
                        NSMutableDictionary *options = [[NSMutableDictionary alloc] init];
                        
                        if (_broadcastUids != nil)
                            [options setObject:_broadcastUids forKey:@"broadcastUids"];
                        else
                            [options setObject:[NSNumber numberWithLongLong:_conversationId] forKey:@"conversationId"];
                        
                        [options setObject:_uploadedMedia forKey:@"uploadedMedia"];
                        if (_messageMeta != nil)
                            [options setObject:_messageMeta forKey:@"messageMeta"];
                        
                        options[@"tempId"] = @([self tmpIdForLocalId:_messageLocalMid]);
                        
                        [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/conversations/(meta)/sendMessage/(%d)", _messageLocalMid] options:options watcher:self];
                    }
                }
            }
            else
            {
                [self failMessage];
            }
        }
        else
        {
            [self failMessage];
            
            [self failAction];
        }
    }
    else if ([path hasPrefix:@"/tg/conversations/(meta)/sendMessage/"])
    {
        if (resultCode == ASStatusSuccess)
        {
            TGMessage *message = result[@"message"];
            
            if (_isEncrypted)
            {
                message.local = true;
                message.mid = _messageLocalMid;
                message.localMid = message.mid;
                
                TLEncryptedFile *encryptedFile = result[@"encryptedFile"];
                
                if (_isEncrypted)
                {
                    if (_messageMedia.count != 0)
                    {
                        if ([_messageMedia[0] isKindOfClass:[TGImageInputMediaAttachment class]])
                        {
                            if (_uploadedMedia.count != 0 && [_uploadedMedia[0] isKindOfClass:[TLDecryptedMessageMedia$decryptedMessageMediaPhoto class]])
                            {
                                TLDecryptedMessageMedia$decryptedMessageMediaPhoto *uploadedPhoto = (TLDecryptedMessageMedia$decryptedMessageMediaPhoto *)_uploadedMedia[0];
                                
                                if ([encryptedFile isKindOfClass:[TLEncryptedFile$encryptedFile class]])
                                {
                                    TLEncryptedFile$encryptedFile *concreteFile = (TLEncryptedFile$encryptedFile *)encryptedFile;
                                    
                                    TGImageMediaAttachment *imageAtachment = [[TGImageMediaAttachment alloc] init];
                                    imageAtachment.imageId = concreteFile.n_id;
                                    imageAtachment.accessHash = concreteFile.access_hash;
                                    TGImageInfo *imageInfo = [[TGImageInfo alloc] init];
                                    imageAtachment.imageInfo = imageInfo;
                                    
                                    NSString *thumbnailUrl = [[NSString alloc] initWithFormat:@"encryptedThumbnail:%lld", concreteFile.n_id];
                                    [imageInfo addImageWithSize:CGSizeMake(uploadedPhoto.thumb_w, uploadedPhoto.thumb_h) url:thumbnailUrl];
                                    
                                    NSString *fileUrl = [[NSString alloc] initWithFormat:@"mt-encrypted-file://?dc=%d&id=%lld&accessHash=%lld&size=%d&decryptedSize=%d&fingerprint=%d&key=%@", concreteFile.dc_id, concreteFile.n_id, concreteFile.access_hash, concreteFile.size, uploadedPhoto.size, concreteFile.key_fingerprint, [uploadedPhoto.key stringByEncodingInHex]];
                                    
                                    [imageInfo addImageWithSize:CGSizeMake(uploadedPhoto.w, uploadedPhoto.h) url:fileUrl];
                                    
                                    message.mediaAttachments = @[imageAtachment];
                                }
                            }
                        }
                        else if ([_messageMedia[0] isKindOfClass:[TGVideoInputMediaAttachment class]])
                        {
                            if (_uploadedMedia.count != 0 && [_uploadedMedia[0] isKindOfClass:[TLDecryptedMessageMedia$decryptedMessageMediaVideo class]])
                            {
                                TLDecryptedMessageMedia$decryptedMessageMediaVideo *uploadedVideo = _uploadedMedia[0];
                                
                                if ([encryptedFile isKindOfClass:[TLEncryptedFile$encryptedFile class]])
                                {
                                    TLEncryptedFile$encryptedFile *concreteFile = (TLEncryptedFile$encryptedFile *)encryptedFile;
                                    
                                    TGVideoMediaAttachment *videoAttachment = [[TGVideoMediaAttachment alloc] init];
                                    
                                    videoAttachment.videoId = concreteFile.n_id;
                                    videoAttachment.accessHash = concreteFile.access_hash;
                                    
                                    videoAttachment.duration = uploadedVideo.duration;
                                    videoAttachment.dimensions = CGSizeMake(uploadedVideo.w, uploadedVideo.h);
                                    
                                    TGImageInfo *thumbnailInfo = [[TGImageInfo alloc] init];
                                    videoAttachment.thumbnailInfo = thumbnailInfo;
                                    NSString *thumbnailUrl = [[NSString alloc] initWithFormat:@"encryptedThumbnail:%lld", concreteFile.n_id];
                                    [thumbnailInfo addImageWithSize:CGSizeMake(uploadedVideo.thumb_w, uploadedVideo.thumb_h) url:thumbnailUrl];
                                    
                                    NSString *fileUrl = [[NSString alloc] initWithFormat:@"mt-encrypted-file://?dc=%d&id=%lld&accessHash=%lld&size=%d&decryptedSize=%d&fingerprint=%d&key=%@", concreteFile.dc_id, concreteFile.n_id, concreteFile.access_hash, concreteFile.size, uploadedVideo.size, concreteFile.key_fingerprint, [uploadedVideo.key stringByEncodingInHex]];
                                    
                                    TGVideoInfo *videoInfo = [[TGVideoInfo alloc] init];
                                    videoAttachment.videoInfo = videoInfo;
                                    [videoInfo addVideoWithQuality:1 url:fileUrl size:uploadedVideo.size];
                                    
                                    message.mediaAttachments = @[videoAttachment];
                                }
                            }
                        }
                    }
                }
            }
            
            [self successMessage:message messageMid:message.mid messageDate:(int)message.date];
            
            [self completeAction:[[SGraphListNode alloc] initWithItems:message != nil ? @[message] : @[]]];
        }
        else
        {
            [self conversationSendMessageRequestFailed];
        }
    }
}

- (void)failMessage
{
    [_timeoutTimer invalidate];
    _timeoutTimer = nil;
    
    if (_messageLocalMid != 0 && _broadcastUids == nil)
    {
        std::vector<TGDatabaseMessageFlagValue> flags;
        TGDatabaseMessageFlagValue deliveryStateValue = { TGDatabaseMessageFlagDeliveryState, TGMessageDeliveryStateFailed };
        flags.push_back(deliveryStateValue);
        
        [[TGDatabase instance] updateMessage:_messageLocalMid flags:flags dispatch:true];
    }
}

- (void)successMessage:(TGMessage *)addedMessage messageMid:(int)messageMid messageDate:(int)messageDate
{
    [_timeoutTimer invalidate];
    _timeoutTimer = nil;
    
    if (_messageLocalMid != 0 && _broadcastUids == nil)
    {
        std::vector<TGDatabaseMessageFlagValue> flags;
        TGDatabaseMessageFlagValue midValue = { TGDatabaseMessageFlagMid, messageMid };
        flags.push_back(midValue);
        TGDatabaseMessageFlagValue deliveryStateValue = { TGDatabaseMessageFlagDeliveryState, TGMessageDeliveryStateDelivered };
        flags.push_back(deliveryStateValue);
        TGDatabaseMessageFlagValue dateValue = { TGDatabaseMessageFlagDate, messageDate };
        flags.push_back(dateValue);
        
        if (_conversationId == TGTelegraphInstance.clientUserId)
        {
            TGDatabaseMessageFlagValue unreadValue = { .flag = TGDatabaseMessageFlagUnread, .value = false };
            flags.push_back(unreadValue);
        }
        
        for (TGInputMediaAttachment *inputAttachment in _messageMedia)
        {
            if ([inputAttachment isKindOfClass:[TGImageInputMediaAttachment class]])
            {
                TGImageInputMediaAttachment *imageInputAttachment = (TGImageInputMediaAttachment *)inputAttachment;
                
                for (TGMediaAttachment *attachment in addedMessage.mediaAttachments)
                {
                    if (attachment.type == TGImageMediaAttachmentType)
                    {
                        TGImageMediaAttachment *imageAttachment = (TGImageMediaAttachment *)attachment;
                        
                        if (imageInputAttachment.assetUrl.length != 0 && !_isEncrypted)
                            [TGImageDownloadActor addServerMediaSataForAssetUrl:imageInputAttachment.assetUrl attachment:imageAttachment];
                        break;
                    }
                }
            }
            else if ([inputAttachment isKindOfClass:[TGVideoInputMediaAttachment class]])
            {
                TGVideoInputMediaAttachment *videoInputAttachment = (TGVideoInputMediaAttachment *)inputAttachment;
                
                for (TGMediaAttachment *attachment in addedMessage.mediaAttachments)
                {
                    if (attachment.type == TGVideoMediaAttachmentType)
                    {
                        TGVideoMediaAttachment *videoAttachment = (TGVideoMediaAttachment *)attachment;
                        
                        if (videoInputAttachment.assetUrl.length != 0 && !_isEncrypted)
                        {
                            [TGImageDownloadActor addServerMediaSataForAssetUrl:videoInputAttachment.assetUrl attachment:videoAttachment];
                        }
                        break;
                    }
                }
            }
        }
        
        if (_messageMeta != nil)
        {
            NSFileManager *fileManager = [[NSFileManager alloc] init];
            
            NSMutableSet *movedFiles = [[NSMutableSet alloc] init];
            
            if (_messageMeta.imageInfoList.count != 0)
            {
                TGImageInfo *localImageInfo = [_messageMeta.imageInfoList objectAtIndex:0];
                TGImageInfo *serverImageInfo = nil;
                TGVideoMediaAttachment *serverVideoAttachment = nil;
                
                for (TGMediaAttachment *attachment in addedMessage.mediaAttachments)
                {
                    if ([attachment isKindOfClass:[TGImageMediaAttachment class]])
                    {
                        TGImageMediaAttachment *imageAttachment = (TGImageMediaAttachment *)attachment;
                        serverImageInfo = imageAttachment.imageInfo;
                        break;
                    }
                    else if ([attachment isKindOfClass:[TGVideoMediaAttachment class]])
                    {
                        TGVideoMediaAttachment *videoAttachment = (TGVideoMediaAttachment *)attachment;
                        serverImageInfo = videoAttachment.thumbnailInfo;
                        serverVideoAttachment = videoAttachment;
                        break;
                    }
                }
                
                if (serverImageInfo != nil)
                {
                    NSDictionary *localSizes = [localImageInfo allSizes];
                    
                    for (NSString *localUrl in localSizes.allKeys)
                    {
                        CGSize localSize = [[localSizes objectForKey:localUrl] CGSizeValue];
                        
                        NSString *remoteUrl = [serverImageInfo imageUrlWithExactSize:localSize];
                        if (remoteUrl == nil && serverVideoAttachment != nil)
                        {
                            remoteUrl = [serverImageInfo closestImageUrlWithSize:localSize resultingSize:NULL];
                        }
                        
                        if (remoteUrl == nil && (int)localSize.width <= 90 && (int)localSize.height <= 90)
                            remoteUrl = [serverImageInfo closestImageUrlWithSize:CGSizeZero resultingSize:NULL];
                        
                        if (remoteUrl == nil)
                            continue;
                        
                        NSString *localFileName = [_messageMeta.imageUrlToDataFile objectForKey:localUrl];
                        if (localFileName != nil)
                        {
                            [movedFiles addObject:localUrl];
                            [[TGRemoteImageView sharedCache] moveToCache:localFileName cacheUrl:remoteUrl];
                            [TGImageDownloadActor addUrlRewrite:localUrl newUrl:remoteUrl];
                        }
                    }
                }
                
                if (serverVideoAttachment != nil)
                {
                    for (TGInputMediaAttachment *inputAttachment in _messageMedia)
                    {
                        if ([inputAttachment isKindOfClass:[TGVideoInputMediaAttachment class]])
                        {
                            TGVideoInputMediaAttachment *videoAttachment = (TGVideoInputMediaAttachment *)inputAttachment;
                            
                            if (videoAttachment.localVideoId != 0)
                            {
                                NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true) objectAtIndex:0];
                                NSString *videosPath = [documentsDirectory stringByAppendingPathComponent:@"video"];
                                NSString *uploadVideoFile = [videosPath stringByAppendingPathComponent:[[NSString alloc] initWithFormat:@"local%llx.mov", videoAttachment.localVideoId]];
                                NSString *serverVideoFile = [videosPath stringByAppendingPathComponent:[[NSString alloc] initWithFormat:@"remote%llx.mov", serverVideoAttachment.videoId]];
                                
                                [[TGRemoteImageView sharedCache] changeCacheItemUrl:[[NSString alloc] initWithFormat:@"video-thumbnail-local%llx.jpg", videoAttachment.localVideoId] newUrl:[[NSString alloc] initWithFormat:@"video-thumbnail-remote%llx.jpg", serverVideoAttachment.videoId]];
                                
                                [[ActionStageInstance() globalFileManager] moveItemAtPath:uploadVideoFile toPath:serverVideoFile error:nil];
                                
                                NSString *remoteUrl = [serverVideoAttachment.videoInfo urlWithQuality:1 actualQuality:NULL actualSize:NULL];
                                [TGVideoDownloadActor rewriteLocalFilePath:[[NSString alloc] initWithFormat:@"local-video:local%llx.mov", videoAttachment.localVideoId] remoteUrl:remoteUrl];
                            }
                        }
                    }
                }
            }
            
            if (_messageMeta.localMediaId != 0)
                [TGDatabaseInstance() replaceMediaInMessagesWithLocalMediaId:_messageMeta.localMediaId media:[addedMessage serializeMediaAttachments:true]];
            
            NSDictionary *localUrls = [_messageMeta.imageUrlToDataFile copy];
            dispatch_async([TGCache diskCacheQueue], ^
            {
                for (NSString *imageUrl in [localUrls allKeys])
                {
                    if (![movedFiles containsObject:imageUrl])
                    {
                        NSString *fileName = [localUrls objectForKey:imageUrl];
                        NSError *error = nil;
                        [fileManager removeItemAtPath:fileName error:&error];
                    }
                }
            });
        }
        
        [[TGDatabase instance] updateMessage:_messageLocalMid flags:flags dispatch:true];
        
        if (_messageMedia.count != 0)
        {
            [TGDatabaseInstance() addMessagesToConversation:[[NSArray alloc] initWithObjects:addedMessage, nil] conversationId:_conversationId updateConversation:nil dispatch:true countUnread:false];
        }
        
        if (_conversationId != 0 && addedMessage != nil)
        {   
            [ActionStageInstance() dispatchResource:[[NSString alloc] initWithFormat:@"/tg/conversation/(%lld)/messagesChanged", _conversationId] resource:[[SGraphObjectNode alloc] initWithObject:[[NSArray alloc] initWithObjects:[[NSNumber alloc] initWithInt:_messageLocalMid], addedMessage, nil]]];
        }
        
        if ([self tmpIdForLocalId:_messageLocalMid] != 0)
        {
            [TGDatabaseInstance() removeTempIds:[[NSArray alloc] initWithObjects:[[NSNumber alloc] initWithLongLong:[self tmpIdForLocalId:_messageLocalMid]], nil]];
        }
        
        if (_conversationId <= INT_MIN)
        {
            //[TGDatabaseInstance() scheduleSelfDestruct:_messageLocalMid conversationId:_conversationId];
        }
    }
}

- (void)actionStageActionRequested:(NSString *)action options:(NSDictionary *)__unused options
{
    if ([action isEqualToString:@"terminateSendMessage"])
    {
        [self cancel];
        
        [self failAction];
    }
}

- (void)cancel
{
    [_timeoutTimer invalidate];
    _timeoutTimer = nil;
    
    _actionHandle.delegate = nil;
    [ActionStageInstance() removeWatcher:self];
    
    [self failMessage];
    
    if (self.cancelToken != nil)
    {
        [TGTelegraphInstance cancelRequestByToken:self.cancelToken];
        self.cancelToken = nil;
    }
    
    [self processDelayedMessages:self.path];
    
    [super cancel];
}

- (void)completeAction:(id)result
{
    NSString *path = self.path;
    
    [ActionStageInstance() actionCompleted:self.path result:result];
    
    [self processDelayedMessages:path];
}

- (void)failAction
{
    NSString *path = self.path;
    
    [ActionStageInstance() actionFailed:self.path reason:-1];
    
    [self processDelayedMessages:path];
}

- (void)processDelayedMessages:(NSString *)path
{
    if (![self.path hasPrefix:@"/tg/conversations/(meta)"])
    {
        [TGUpdateStateRequestBuilder processDelayedMessagesInConversation:_conversationId completedPath:path];
    }
}

+ (MessageKeyData)generateMessageKeyData:(NSData *)messageKey incoming:(bool)incoming key:(NSData *)key
{
    MessageKeyData keyData;
    
    NSData *authKey = key;
    if (authKey == nil || authKey.length == 0)
    {
        MessageKeyData keyData;
        keyData.aesIv = nil;
        keyData.aesKey = nil;
        return keyData;
    }
    
    int x = incoming ? 8 : 0;
    
    NSData *sha1_a = nil;
    {
        NSMutableData *data = [[NSMutableData alloc] init];
        [data appendData:messageKey];
        [data appendBytes:(((int8_t *)authKey.bytes) + x) length:32];
        sha1_a = computeSHA1(data);
    }
    
    NSData *sha1_b = nil;
    {
        NSMutableData *data = [[NSMutableData alloc] init];
        [data appendBytes:(((int8_t *)authKey.bytes) + 32 + x) length:16];
        [data appendData:messageKey];
        [data appendBytes:(((int8_t *)authKey.bytes) + 48 + x) length:16];
        sha1_b = computeSHA1(data);
    }
    
    NSData *sha1_c = nil;
    {
        NSMutableData *data = [[NSMutableData alloc] init];
        [data appendBytes:(((int8_t *)authKey.bytes) + 64 + x) length:32];
        [data appendData:messageKey];
        sha1_c = computeSHA1(data);
    }
    
    NSData *sha1_d = nil;
    {
        NSMutableData *data = [[NSMutableData alloc] init];
        [data appendData:messageKey];
        [data appendBytes:(((int8_t *)authKey.bytes) + 96 + x) length:32];
        sha1_d = computeSHA1(data);
    }
    
    NSMutableData *aesKey = [[NSMutableData alloc] init];
    [aesKey appendBytes:(((int8_t *)sha1_a.bytes)) length:8];
    [aesKey appendBytes:(((int8_t *)sha1_b.bytes) + 8) length:12];
    [aesKey appendBytes:(((int8_t *)sha1_c.bytes) + 4) length:12];
    keyData.aesKey = [[NSData alloc] initWithData:aesKey];
    
    NSMutableData *aesIv = [[NSMutableData alloc] init];
    [aesIv appendBytes:(((int8_t *)sha1_a.bytes) + 8) length:12];
    [aesIv appendBytes:(((int8_t *)sha1_b.bytes)) length:8];
    [aesIv appendBytes:(((int8_t *)sha1_c.bytes) + 16) length:4];
    [aesIv appendBytes:(((int8_t *)sha1_d.bytes)) length:8];
    keyData.aesIv = [[NSData alloc] initWithData:aesIv];
    
    return keyData;
}

+ (NSData *)prepareEncryptedMessage:(NSString *)text media:(TLDecryptedMessageMedia *)media key:(NSData *)key keyId:(int64_t)keyId
{
    TLDecryptedMessage$decryptedMessage *decryptedMessage = [[TLDecryptedMessage$decryptedMessage alloc] init];
    
    int64_t randomId = 0;
    arc4random_buf(&randomId, 8);
    decryptedMessage.random_id = randomId;
    
    decryptedMessage.random_bytes = nil;
    
    decryptedMessage.message = text;
    
    decryptedMessage.media = media == nil ? [TLDecryptedMessageMedia$decryptedMessageMediaEmpty new] : media;
    
    NSOutputStream *os = [[NSOutputStream alloc] initToMemory];
    [os open];
    TLMetaClassStore::serializeObject(os, decryptedMessage, true);
    NSData *result = [self encryptMessage:[os currentBytes] key:key keyId:keyId];
    [os close];
    
    return result;
}

+ (NSData *)encryptMessage:(NSData *)serializedMessage key:(NSData *)key keyId:(int64_t)keyId
{
    NSMutableData *decryptedBytesOriginal = [serializedMessage mutableCopy];
    int32_t messageLength = decryptedBytesOriginal.length;
    [decryptedBytesOriginal replaceBytesInRange:NSMakeRange(0, 0) withBytes:&messageLength length:4];
    
    NSData *messageKeyFull = computeSHA1(decryptedBytesOriginal);
    NSData *messageKey = [[NSData alloc] initWithBytes:(((int8_t *)messageKeyFull.bytes) + messageKeyFull.length - 16) length:16];
    
    uint8_t randomBuf[16];
    arc4random_buf(randomBuf, 16);
    int index = 0;
    
    NSMutableData *decryptedBytes = [[NSMutableData alloc] initWithCapacity:decryptedBytesOriginal.length + 16];
    [decryptedBytes appendData:decryptedBytesOriginal];
    while (decryptedBytes.length % 16 != 0)
    {
        [decryptedBytes appendBytes:randomBuf + index length:1];
        index++;
    }
    
    MessageKeyData keyData = [self generateMessageKeyData:messageKey incoming:false key:key];
    
    encryptWithAESInplace(decryptedBytes, keyData.aesKey, keyData.aesIv, true);
    NSMutableData *data = [[NSMutableData alloc] init];
    [data appendBytes:&keyId length:8];
    [data appendData:messageKey];
    [data appendData:decryptedBytes];
    
    return data;
}

@end
