#import "TGFileUploadActor.h"

#import "TGTelegraph.h"
#import "TGTelegraphProtocols.h"

#import "ActionStage.h"
#import "SGraphObjectNode.h"

#import "TL/TLMetaScheme.h"

#import <Security/Security.h>
#import <CommonCrypto/CommonCrypto.h>

#import "TGSecurity.h"

#import <vector>

#define PHOTO_PART_SIZE 8 * 1024
#define VIDEO_PART_SIZE 64 * 1024

struct FilePart
{
    int index;
    int length;
    bool uploading;
    
    FilePart(int index_, int length_) :
        index(index_), length(length_), uploading(false)
    {
    }
};

@interface TGFileUploadActor () <TGFileUploadActor>
{
    std::vector<FilePart> _partsToUpload;
    
    bool _isEncrypted;
    NSData *_encryptionKey;
    NSData *_encryptionIv;
    NSMutableData *_encryptionRunningIv;
    int64_t _encryptionKeyFingerprint;
    NSData *_thumbnail;
    
    int _thumbnailWidth;
    int _thumbnailHeight;
    int _width;
    int _height;
    int _fileSize;
    
    CC_MD5_CTX _md5;
}
@property (nonatomic, strong) NSInputStream *is;

@property (nonatomic) int64_t fileId;
@property (nonatomic) int partCount;

@property (nonatomic, strong) NSString *fileExtension;

@property (nonatomic, strong) NSMutableArray *cancelTokenList;

@end

@implementation TGFileUploadActor

+ (NSString *)genericPath
{
    return @"/tg/upload/@";
}

- (id)initWithPath:(NSString *)path
{
    self = [super initWithPath:path];
    if (self != nil)
    {
        _cancelTokenList = [[NSMutableArray alloc] init];
        
        CC_MD5_Init(&_md5);
    }
    return self;
}

- (void)dealloc
{
    [_is close];
}

- (void)execute:(NSDictionary *)options
{
    _isEncrypted = [options[@"encrypt"] boolValue];
    _thumbnail = options[@"thumbnail"];
    
    _thumbnailWidth = [options[@"thumbnailWidth"] intValue];
    _thumbnailHeight = [options[@"thumbnailHeight"] intValue];
    _width = [options[@"width"] intValue];
    _height = [options[@"height"] intValue];
    _fileSize = [options[@"fileSize"] intValue];
    
    SecRandomCopyBytes(kSecRandomDefault, 8, (uint8_t *)&_fileId);
    
    if (_isEncrypted)
    {
        uint8_t rawKey[32];
        SecRandomCopyBytes(kSecRandomDefault, 32, rawKey);
        _encryptionKey = [[NSData alloc] initWithBytes:rawKey length:32];
        uint8_t rawIv[32];
        SecRandomCopyBytes(kSecRandomDefault, 32, rawIv);
        _encryptionIv = [[NSData alloc] initWithBytes:rawIv length:32];
        _encryptionRunningIv = [[NSMutableData alloc] initWithData:_encryptionIv];
    }
    
    _fileExtension = [options objectForKey:@"ext"];
    if (_fileExtension == nil)
        _fileExtension = @"jpg";
    
    if ([options objectForKey:@"data"] != nil)
    {
        NSData *data = [options objectForKey:@"data"];
        if (data == nil || data.length == 0)
        {
            [ActionStageInstance() nodeRetrieveFailed:self.path];
        }
        else
        {
            int length = data.length;
            int index = -1;
            for (int i = 0; i < length; i += PHOTO_PART_SIZE)
            {
                index++;
                int blockSize = MIN(PHOTO_PART_SIZE, length - i);
                _partsToUpload.push_back(FilePart(index, blockSize));
            }
            
            _partCount = _partsToUpload.size();
            
            TGLog(@"Uploading %d kbytes (%d parts)", length / 1024, _partCount);
            
            _is = [[NSInputStream alloc] initWithData:data];
            [_is open];
            
            [self sendAnyPart];
        }
    }
    else if ([options objectForKey:@"file"] != nil)
    {
        NSString *fileName = [options objectForKey:@"file"];
        
        static NSFileManager *fileManager = [[NSFileManager alloc] init];
        NSDictionary *attributes = [fileManager attributesOfItemAtPath:fileName error:nil];
        int fileSize = [[attributes objectForKey:NSFileSize] intValue];
        
        _fileSize = fileSize;
        
        if (attributes == nil || fileSize == 0)
        {
            [ActionStageInstance() nodeRetrieveFailed:self.path];
        }
        else
        {
            int partSize = VIDEO_PART_SIZE;
            if (fileSize > 1 * 1024 * 1024)
            {
                //partSize = VIDEO_PART_SIZE * 2;
            }
            
            int length = fileSize;
            int index = -1;
            for (int i = 0; i < length; i += partSize)
            {
                index++;
                int blockSize = MIN(partSize, length - i);
                _partsToUpload.push_back(FilePart(index, blockSize));
            }
            
            _partCount = _partsToUpload.size();
            
            TGLog(@"Uploading %d kbytes (%d parts)", length / 1024, _partCount);
            
            _is = [[NSInputStream alloc] initWithFileAtPath:fileName];
            [_is open];
            
            if (_is.streamStatus != NSStreamStatusOpen)
                [ActionStageInstance() nodeRetrieveFailed:self.path];
            else
                [self sendAnyPart];
        }
    }
    else
    {
        [ActionStageInstance() nodeRetrieveFailed:self.path];
    }
}

- (void)sendAnyPart
{
    if (self.cancelled)
        return;
    
    if (_partsToUpload.empty())
    {
        if (_isEncrypted)
        {
            TLInputEncryptedFile$inputEncryptedFileUploaded *inputFile = [[TLInputEncryptedFile$inputEncryptedFileUploaded alloc] init];
            inputFile.parts = _partCount;
            
            unsigned char md5Buffer[16];
            CC_MD5_Final(md5Buffer, &_md5);
            NSString *hash = [[NSString alloc] initWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x", md5Buffer[0], md5Buffer[1], md5Buffer[2], md5Buffer[3], md5Buffer[4], md5Buffer[5], md5Buffer[6], md5Buffer[7], md5Buffer[8], md5Buffer[9], md5Buffer[10], md5Buffer[11], md5Buffer[12], md5Buffer[13], md5Buffer[14], md5Buffer[15]];
            
            inputFile.md5_checksum = hash;
            inputFile.n_id = _fileId;
            
            uint8_t keyPlusIv[32 + 32];
            [_encryptionKey getBytes:keyPlusIv range:NSMakeRange(0, 32)];
            [_encryptionIv getBytes:keyPlusIv + 32 range:NSMakeRange(0, 32)];
            
            unsigned char digest[CC_MD5_DIGEST_LENGTH];
            CC_MD5(keyPlusIv, 32 + 32, digest);
            
            int32_t digestHigh = 0;
            int32_t digestLow = 0;
            memcpy(&digestHigh, digest, 4);
            memcpy(&digestLow, digest + 4, 4);
            
            inputFile.key_fingerprint = digestHigh ^ digestLow;
            
            [ActionStageInstance() nodeRetrieveProgress:self.path progress:1.0f];
            [ActionStageInstance() actionCompleted:self.path result:@{
                @"file": inputFile,
                @"key": _encryptionKey,
                @"iv": _encryptionIv,
                @"thumbnail": _thumbnail == nil ? [NSData data] : _thumbnail,
                @"thumbnailWidth": @(_thumbnailWidth),
                @"thumbnailHeight": @(_thumbnailHeight),
                @"width": @(_width),
                @"height": @(_height),
                @"fileSize": @(_fileSize)
             }];
        }
        else
        {
            TLInputFile$inputFile *inputFile = [[TLInputFile$inputFile alloc] init];
            inputFile.parts = _partCount;
            
            unsigned char md5Buffer[16];
            CC_MD5_Final(md5Buffer, &_md5);
            NSString *hash = [[NSString alloc] initWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x", md5Buffer[0], md5Buffer[1], md5Buffer[2], md5Buffer[3], md5Buffer[4], md5Buffer[5], md5Buffer[6], md5Buffer[7], md5Buffer[8], md5Buffer[9], md5Buffer[10], md5Buffer[11], md5Buffer[12], md5Buffer[13], md5Buffer[14], md5Buffer[15]];
            
            inputFile.md5_checksum = hash;
            inputFile.n_id = _fileId;
            
            inputFile.name = [[NSString alloc] initWithFormat:@"file.%@", _fileExtension];
            
            [ActionStageInstance() nodeRetrieveProgress:self.path progress:1.0f];
            [ActionStageInstance() actionCompleted:self.path result:@{@"file": inputFile}];
        }
    }
    else
    {
        float progress = 0.0f;
        if (_partCount != 0)
            progress = MIN(1.0f, (_partCount - _partsToUpload.size()) / (float)_partCount);
        progress = MAX(0.001f, progress);
        
        [ActionStageInstance() nodeRetrieveProgress:self.path progress:progress];
        
        int concurrentUploads = 16;
        
        for (int i = 0; i < concurrentUploads; i++)
        {
            for (std::vector<FilePart>::iterator it = _partsToUpload.begin(); it != _partsToUpload.end(); it++)
            {
                if (!it->uploading)
                {
                    NSData *partData = [_is readData:it->length];
                    
                    if (_isEncrypted)
                    {
                        NSMutableData *tmpData = [[NSMutableData alloc] initWithData:partData];
                                                  
                        if (tmpData.length % 16 != 0)
                        {
                            while (tmpData.length % 16 != 0)
                            {
                                uint8_t zero = 0;
                                [tmpData appendBytes:&zero length:1];
                            }
                        }
                    
                        encryptWithAESInplaceAndModifyIv(tmpData, _encryptionKey, _encryptionRunningIv, true);
                        partData = tmpData;
                    }
                    
                    CC_MD5_Update(&_md5, [partData bytes], [partData length]);
                    
                    it->uploading = true;
                    id token = [TGTelegraphInstance doUploadFilePart:_fileId partId:it->index data:partData actor:self];
                    if (token != nil)
                        [_cancelTokenList addObject:token];
                    break;
                }
            }
        }
    }
}

- (void)filePartUploadSuccess:(int)partId
{
    for (std::vector<FilePart>::iterator it = _partsToUpload.begin(); it != _partsToUpload.end(); it++)
    {
        if (it->index == partId)
        {
            _partsToUpload.erase(it);
            break;
        }
    }
    
    [self sendAnyPart];
}

- (void)filePartUploadFailed:(int)__unused partId
{
    [ActionStageInstance() nodeRetrieveFailed:self.path];
}

- (void)cancel
{
    for (id token in _cancelTokenList)
    {
        [TGTelegraphInstance cancelRequestByToken:token];
    }
    
    _cancelTokenList = nil;
    
    [super cancel];
}

@end
