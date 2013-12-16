#import "TGEncryptedChatResponseActor.h"

#import "TGTelegraph.h"
#import "TGDatabase.h"
#import "TGSecurity.h"
#import "TGStringUtils.h"

#import "TGConversation+Telegraph.h"

#import "TGRequestEncryptedChatActor.h"

#import "TGConversationAddMessagesActor.h"

@interface TGEncryptedChatResponseActor ()
{
    int64_t _encryptedConversationId;
    int64_t _accessHash;
    
    NSMutableData *_key;
    int64_t _keyId;
    
    TLmessages_DhConfig$messages_dhConfig *_currentConfig;
}

@end

@implementation TGEncryptedChatResponseActor

+ (NSString *)genericPath
{
    return @"/tg/encrypted/acceptEncryptedChat/@";
}

- (void)execute:(NSDictionary *)options
{
    _encryptedConversationId = [options[@"encryptedConversationId"] longLongValue];
    _accessHash = [options[@"accessHash"] longLongValue];
    
    _currentConfig = [TGRequestEncryptedChatActor cachedEncryptionConfig];
    self.cancelToken = [TGTelegraphInstance doRequestEncryptionConfig:(TGRequestEncryptedChatActor *)self version:_currentConfig.version];
}

- (void)dhRequestSuccess:(TLmessages_DhConfig *)config
{
    if ([config isKindOfClass:[TLmessages_DhConfig$messages_dhConfig class]])
    {
        _currentConfig = (TLmessages_DhConfig$messages_dhConfig *)config;
        [TGRequestEncryptedChatActor setCachedEncryptionConfig:_currentConfig];
    }
    
    NSData *gABytes = [TGDatabaseInstance() conversationCustomPropertySync:[TGDatabaseInstance() peerIdForEncryptedConversationId:_encryptedConversationId] name:murMurHash32(@"a")];
    NSData *nonce = [TGDatabaseInstance() conversationCustomPropertySync:[TGDatabaseInstance() peerIdForEncryptedConversationId:_encryptedConversationId] name:murMurHash32(@"nonce")];
    
    uint8_t bBytes[256];
    SecRandomCopyBytes(kSecRandomDefault, 256, bBytes);
    
    for (int i = 0; i < 256 && i < (int)config.random.length; i++)
    {
        uint8_t currentByte = ((uint8_t *)config.random.bytes)[i];
        bBytes[i] ^= currentByte;
    }
    
    NSData *b = [[NSData alloc] initWithBytes:bBytes length:256];
    
    int32_t tmpG = _currentConfig.g;
    tmpG = NSSwapInt(tmpG);
    NSData *g = [[NSData alloc] initWithBytes:&tmpG length:4];
    
    NSData *gBBytes = computeExp(g, b, _currentConfig.p);
    
    _key = [computeExp(gABytes, b, _currentConfig.p) mutableCopy];
    
    if (_key.length > 256)
        [_key replaceBytesInRange:NSMakeRange(0, 1) withBytes:NULL length:1];
    while (_key.length < 256)
    {
        uint8_t zero = 0;
        [_key replaceBytesInRange:NSMakeRange(0, 0) withBytes:&zero length:1];
        TGLog(@"(adding key padding)");
    }
    
    for (int i = 0; i < (int)_key.length && i < (int)nonce.length; i++)
    {
        ((uint8_t *)_key.mutableBytes)[i] ^= ((uint8_t *)nonce.bytes)[i];
    }
    
    NSData *keyHash = computeSHA1(_key);
    NSData *nKeyId = [[NSData alloc] initWithBytes:(((uint8_t *)keyHash.bytes) + keyHash.length - 8) length:8];
    [nKeyId getBytes:&_keyId length:8];
    
    self.cancelToken = [TGTelegraphInstance doAcceptEncryptedChat:_encryptedConversationId accessHash:_accessHash gBBytes:gBBytes keyFingerprint:_keyId actor:self];
}

- (void)dhRequestFailed
{
    [ActionStageInstance() actionFailed:self.path reason:-1];
}

- (void)acceptEncryptedChatSuccess:(TLEncryptedChat *)encryptedChat date:(int)date
{
    TGConversation *conversation = [[TGConversation alloc] initWithTelegraphEncryptedChatDesc:encryptedChat];
    
    if (conversation != nil && conversation.conversationId != 0)
    {
        [TGDatabaseInstance() storeEncryptionKeyForConversationId:[TGDatabaseInstance() peerIdForEncryptedConversationId:_encryptedConversationId] key:_key keyFingerprint:_keyId];
        
        conversation.date = date;
        conversation.encryptedData.handshakeState = 4;
        
        static int actionId = 0;
        [[[TGConversationAddMessagesActor alloc] initWithPath:[[NSString alloc] initWithFormat:@"/tg/addmessage/(requestEncryption%d)", actionId++]] execute:@{@"chats": @{@(conversation.conversationId): conversation}}];
        
        [ActionStageInstance() actionCompleted:self.path result:@{@"conversation": conversation}];
    }
    else
        [ActionStageInstance() actionFailed:self.path reason:-1];
}

- (void)acceptEncryptedChatFailed
{
    [ActionStageInstance() actionFailed:self.path reason:-1];
}

@end