#import "TGShemeTests.h"

#import "TL/TLMetaScheme.h"
#import "TLMetaClassStore.h"
#import <Security/Security.h>

#import "TLMessageContainer.h"

@implementation TGShemeTests

+ (void)testObject:(id<TLObject>)object
{
}

+ (void)runTests
{
    TGLog(@"====== Running tests");
    
    {
        TLResPQ$resPQ *object = [[TLResPQ$resPQ alloc] init];
        uint8_t bytes[16] = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};
        object.nonce = [NSData dataWithBytes:bytes length:16];
        object.server_nonce = [NSData dataWithBytes:bytes length:16];
        object.pq = [NSData dataWithBytes:bytes length:4];
        object.server_public_key_fingerprints = [NSArray arrayWithObject:[NSNumber numberWithLongLong:0x1234567890123]];
        
        [TGShemeTests testObject:object];
    }
    
    {
        TLServer_DH_Params$server_DH_params_fail *object = [[TLServer_DH_Params$server_DH_params_fail alloc] init];
        uint8_t bytes[16] = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};
        object.nonce = [NSData dataWithBytes:bytes length:16];
        object.server_nonce = [NSData dataWithBytes:bytes length:16];
        object.n_new_nonce_hash = [NSData dataWithBytes:bytes length:16];
        
        [TGShemeTests testObject:object];
    }
    
    {
        TLServer_DH_Params$server_DH_params_ok *object = [[TLServer_DH_Params$server_DH_params_ok alloc] init];
        uint8_t bytes[16] = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};
        object.nonce = [NSData dataWithBytes:bytes length:16];
        object.server_nonce = [NSData dataWithBytes:bytes length:16];
        object.encrypted_answer = [NSData dataWithBytes:bytes length:16];
        
        [TGShemeTests testObject:object];
        
        TLRpcResult$rpc_result *result = [[TLRpcResult$rpc_result alloc] init];
        result.req_msg_id = 12345;
        result.result = object;
        
        [TGShemeTests testObject:result];
    }
    
    {
        TLMsgsStateReq$msgs_state_req *object = [[TLMsgsStateReq$msgs_state_req alloc] init];
        object.msg_ids = @[@1, @2];
        
        [TGShemeTests testObject:object];
    }
    
    TGLog(@"====== Done");
}

@end
