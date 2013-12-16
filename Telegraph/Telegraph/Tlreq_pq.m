#import "TLReqPq.h"

@implementation TLReqPq

@synthesize nonce = _nonce;

- (void)setNonce:(NSData *)nonce
{
    if (nonce.length != 16)
    {
        TGLog(@"***** Error: %s:%d: nonce should contain 16 bytes", __PRETTY_FUNCTION__, __LINE__);
    }
    else
        _nonce = nonce;
}

- (void)serialize:(NSOutputStream *)os
{
    [os writeInt32:0x60469778];
    
    [os writeData:_nonce];
}

@end
