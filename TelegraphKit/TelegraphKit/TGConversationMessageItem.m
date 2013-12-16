#import "TGConversationMessageItem.h"

@interface TGConversationMessageItem ()
{
    bool _progressMediaIdInitialized;
    bool _hasSomeAttachment;
}

@end

@implementation TGConversationMessageItem

@synthesize message = _message;
@synthesize author = _author;

@synthesize messageUsers = _messageUsers;

@synthesize progressMediaId = _progressMediaId;

- (id)initWithMessage:(TGMessage *)message
{
    self = [super initWithType:TGConversationItemTypeMessage];
    if (self != nil)
    {
        _message = message;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)__unused zone
{
    TGConversationMessageItem *item = [[TGConversationMessageItem alloc] initWithMessage:[_message copy]];
    item.author = _author;
    item.messageUsers = _messageUsers;
    item.progressMediaId = _progressMediaId;
    item->_progressMediaIdInitialized = _progressMediaIdInitialized;
    item->_hasSomeAttachment = _hasSomeAttachment;
    return item;
}

/*- (void)setMessage:(TGMessage *)message
{
    _progressMediaIdInitialized = false;
    _message = message;
}*/

- (id)progressMediaId
{
    if (_message == nil)
        return nil;
    
    if (_progressMediaIdInitialized)
        return _progressMediaId;
    
    if (_message.mediaAttachments != nil)
    {
        for (TGMediaAttachment *attachment in _message.mediaAttachments)
        {
            int type = attachment.type;
            
            if (type == TGVideoMediaAttachmentType)
            {
                TGVideoMediaAttachment *videoAttachment = (TGVideoMediaAttachment *)attachment;
                _progressMediaId = [[TGMediaId alloc] initWithType:1 itemId:videoAttachment.videoId];
                _hasSomeAttachment = true;
                
                break;
            }
            else if (type == TGImageMediaAttachmentType)
            {
                TGImageMediaAttachment *imageAttachment = (TGImageMediaAttachment *)attachment;
                _progressMediaId = [[TGMediaId alloc] initWithType:2 itemId:imageAttachment.imageId];
                _hasSomeAttachment = true;
                
                break;
            }
            else if (type == TGLocationMediaAttachmentType)
            {
                _hasSomeAttachment = true;
                
                break;
            }
        }
    }
    
    _progressMediaIdInitialized = true;
    
    return _progressMediaId;
}

- (bool)hasSomeAttachment
{
    if (!_progressMediaIdInitialized)
    {
        [self progressMediaId];
    }
    
    return _hasSomeAttachment;
}

@end
