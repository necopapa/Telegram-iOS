#import "TGFileDownloadActor.h"

#import "TGTelegraph.h"

#import "ActionStage.h"
#import "SGraphObjectNode.h"

#import "TGImageInfo+Telegraph.h"

#import "TGStringUtils.h"

#import "TGSecurity.h"

@interface TGFileDownloadActor () <TGRawHttpActor>
{
    NSData *_encryptionKey;
    NSData *_encryptionIv;
    
    int _finalFileSize;
}

@property (nonatomic) bool alreadyCompleted;

@end

@implementation TGFileDownloadActor

+ (NSString *)genericPath
{
    return @"/tg/file/@";
}

- (void)prepare:(NSDictionary *)options
{
    NSString *queueName = [options objectForKey:@"queueName"];
    if ([queueName isKindOfClass:[NSString class]])
        self.requestQueueName = queueName;
}

- (void)execute:(NSDictionary *)options
{
    NSString *url = [options objectForKey:@"url"];
    
    if ([url hasPrefix:@"upload/"])
    {
        NSString *localFileUrl = [url substringFromIndex:7];
        NSString *imagePath = [[[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true) objectAtIndex:0] stringByAppendingPathComponent:@"upload"] stringByAppendingPathComponent:localFileUrl];
        
        NSData *data = [[NSData alloc] initWithContentsOfFile:imagePath];
        
        if (data == nil)
            [ActionStageInstance() nodeRetrieveFailed:self.path];
        else
            [ActionStageInstance() nodeRetrieved:self.path node:[[SGraphObjectNode alloc] initWithObject:data]];
        
        return;
    }
    else if ([url hasPrefix:@"http://"] || [url hasPrefix:@"https://"])
    {
        self.cancelToken = [TGTelegraphInstance doRequestRawHttp:[url stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] maxRetryCount:3 acceptCodes:nil actor:self];
        return;
    }
    else if ([url hasPrefix:@"mt-encrypted-file://?"])
    {
        NSDictionary *args = [TGStringUtils argumentDictionaryInUrlString:[url substringFromIndex:@"mt-encrypted-file://?".length]];
        
        if (args[@"dc"] == nil || args[@"id"] == nil || args[@"accessHash"] == nil || args[@"key"] == nil)
        {
            [ActionStageInstance() actionFailed:self.path reason:-1];
            return;
        }
        else
        {
            int dcId = [args[@"dc"] intValue];
            int64_t fileId = [args[@"id"] longLongValue];
            int64_t accessHash = [args[@"accessHash"] longLongValue];
            
            NSData *key = [args[@"key"] dataByDecodingHexString];
            
            int64_t size = [args[@"size"] intValue];
            
            _finalFileSize = [args[@"decryptedSize"] intValue];
            
            if (key.length != 64)
            {
                TGLog(@"***** Invalid file key length");
                [ActionStageInstance() actionFailed:self.path reason:-1];
            }
            else
            {
                _encryptionKey = [key subdataWithRange:NSMakeRange(0, 32)];
                _encryptionIv = [key subdataWithRange:NSMakeRange(32, 32)];
                
                TLInputFileLocation$inputEncryptedFileLocation *location = [[TLInputFileLocation$inputEncryptedFileLocation alloc] init];
                location.n_id = fileId;
                location.access_hash = accessHash;
                
                self.cancelToken = [TGTelegraphInstance doDownloadFilePart:dcId location:location offset:0 length:size actor:self];
            }
        }
        
        return;
    }
    
    int64_t volumeId = 0;
    int fileId = 0;
    int64_t secret = 0;
    int datacenterId = 0;
    
    if (extractFileUrlComponents(url, &datacenterId, &volumeId, &fileId, &secret))
    {
        [ActionStageInstance() nodeRetrieveProgress:self.path progress:0.001f];
        self.cancelToken = [TGTelegraphInstance doDownloadFile:datacenterId volumeId:volumeId fileId:fileId secret:secret actor:self];
    }
    else
    {
        [ActionStageInstance() nodeRetrieveFailed:self.path];
    }
}

- (void)completeWithData:(NSData *)data
{
    if (self.cancelToken != nil)
    {
        [TGTelegraphInstance cancelRequestByToken:self.cancelToken];
        self.cancelToken = nil;
    }
    
    _alreadyCompleted = true;
    
    [ActionStageInstance() nodeRetrieved:self.path node:[[SGraphObjectNode alloc] initWithObject:data]];
}

- (void)fileDownloadSuccess:(int64_t)__unused volumeId fileId:(int)__unused fileId secret:(int64_t)__unused secret data:(NSData *)data
{
    if (_alreadyCompleted)
        return;
    
    [ActionStageInstance() nodeRetrieved:self.path node:[[SGraphObjectNode alloc] initWithObject:data]];
}

- (void)fileDownloadFailed:(int64_t)__unused volumeId fileId:(int)__unused fileId secret:(int64_t)__unused secret
{
    if (_alreadyCompleted)
        return;
    
    [ActionStageInstance() nodeRetrieveFailed:self.path];
}

- (void)fileDownloadProgress:(int64_t)__unused volumeId fileId:(int)__unused fileId secret:(int64_t)__unused secret progress:(float)progress
{
    if (_alreadyCompleted)
        return;
    
    [ActionStageInstance() nodeRetrieveProgress:self.path progress:MAX(0.001f, progress)];
}

- (void)httpRequestSuccess:(NSString *)__unused url response:(NSData *)response
{
    if (_alreadyCompleted)
        return;
    
    [ActionStageInstance() nodeRetrieved:self.path node:[[SGraphObjectNode alloc] initWithObject:response]];
}

- (void)httpRequestProgress:(NSString *)__unused url progress:(float)progress
{
    if (_alreadyCompleted)
        return;
    
    [ActionStageInstance() nodeRetrieveProgress:self.path progress:MAX(0.001f, progress)];
}

- (void)httpRequestFailed:(NSString *)__unused url
{
    if (_alreadyCompleted)
        return;
    
    [ActionStageInstance() nodeRetrieveFailed:self.path];
}

- (void)filePartDownloadProgress:(TLInputFileLocation *)__unused location offset:(int)__unused offset length:(int)__unused length packetLength:(int)__unused packetLength progress:(float)progress
{
    if (_alreadyCompleted)
        return;
    
    [ActionStageInstance() nodeRetrieveProgress:self.path progress:MAX(0.001f, progress)];
}

- (void)filePartDownloadSuccess:(TLInputFileLocation *)__unused location offset:(int)__unused offset length:(int)__unused length data:(NSData *)data
{
    if (_alreadyCompleted)
        return;
    
    NSMutableData *decryptedData = [[NSMutableData alloc] initWithData:data];
    encryptWithAESInplace(decryptedData, _encryptionKey, _encryptionIv, false);
    
    if (_finalFileSize != 0)
        [decryptedData setLength:_finalFileSize];
    
    [ActionStageInstance() nodeRetrieved:self.path node:[[SGraphObjectNode alloc] initWithObject:decryptedData]];
}

- (void)filePartDownloadFailed:(TLInputFileLocation *)__unused location offset:(int)__unused offset length:(int)__unused length
{
    if (_alreadyCompleted)
        return;
    
    [ActionStageInstance() actionFailed:self.path reason:-1];
}

@end
