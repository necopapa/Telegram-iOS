#import "TGTelegraphImageViewControllerCompanion.h"

#import "TGImageViewController.h"

#import "TGMessage.h"

#import "SGraphObjectNode.h"

#import "TGDatabase.h"

#include <set>

@interface TGImageViewControllerCompanion ()

@property (nonatomic) int64_t peerId;

@property (nonatomic, strong) NSMutableArray *messageList;
@property (nonatomic) int totalCount;

@property (nonatomic) int firstItemId;
@property (nonatomic) bool loadingFirstItems;
@property (nonatomic) bool applyFirstItems;

@end

@implementation TGImageViewControllerCompanion

@synthesize graphHandle = _graphHandle;

@synthesize imageViewController = _imageViewController;

@synthesize reverseOrder = _reverseOrder;

@synthesize peerId = _peerId;

@synthesize messageList = _messageList;
@synthesize totalCount = _totalCount;

@synthesize firstItemId = _firstItemId;
@synthesize loadingFirstItems = _loadingFirstItems;
@synthesize applyFirstItems = _applyFirstItems;

- (id)initWithPeerId:(int64_t)peerId itemList:(NSArray *)itemList focusItemId:(int)focusItemId
{
    self = [super init];
    if (self != nil)
    {
        _graphHandle = [[SGraphHandle alloc] init];
        _graphHandle.delegate = self;
        
        _peerId = peerId;
        
        _firstItemId = focusItemId;
        
        _messageList = [[NSMutableArray alloc] init];
        if (itemList != nil)
        {
            for (TGMessage *message in itemList)
            {
                for (TGMediaAttachment *attachment in message.mediaAttachments)
                {
                    if (attachment.type == TGImageMediaAttachmentType)
                    {
                        TGImageItem *imageItem = [[TGImageItem alloc] init];
                        imageItem.imageInfo = ((TGImageMediaAttachment *)attachment).imageInfo;
                        imageItem.message = message;
                        imageItem.author = [TGDatabaseInstance() loadUser:(int)message.fromUid];
                        [_messageList addObject:imageItem];
                        
                        break;
                    }
                }
            }
            
            _totalCount = _messageList.count;
        }
    }
    return self;
}

- (id)initWithPeerId:(int64_t)peerId firstItemId:(int)firstItemId
{
    self = [super init];
    if (self != nil)
    {
        _graphHandle = [[SGraphHandle alloc] init];
        _graphHandle.delegate = self;
        
        _peerId = peerId;
        
        _messageList = [[NSMutableArray alloc] init];
        
        [[SGraph instance] dispatchOnGraphQueue:^
         {
             if (_peerId != 0)
             {
                 _loadingFirstItems = true;
                 
                 _firstItemId = firstItemId;
                 
                 [[SGraph instance] requestNode:[NSString stringWithFormat:@"/tg/conversations/(%lld)/mediahistory/(0-%d)", _peerId, firstItemId] options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:firstItemId], @"atMessageId", [NSNumber numberWithInt:50], @"limit", nil] watcher:self];
             }
         }];
    }
    return self;
}

- (void)dealloc
{
    _graphHandle.delegate = nil;
    [[SGraph instance] removeWatcher:self];
}

#pragma mark -

- (void)updateItems:(int)currentItemId
{
    [[SGraph instance] dispatchOnGraphQueue:^
     {
         if (!_loadingFirstItems)
         {
             NSArray *items = [[NSArray alloc] initWithArray:_messageList];
             
             int currentItemIndex = -1;
             
             int index = -1;
             for (TGImageItem *imageItem in _messageList)
             {
                 index++;
                 
                 if (imageItem.message.mid == currentItemId)
                 {
                     currentItemIndex = index;
                     break;
                 }
             }
             
             dispatch_async(dispatch_get_main_queue(), ^
                            {
                                [_imageViewController itemsChanged:items totalCount:_totalCount canLoadMore:true];
                                [_imageViewController applyCurrentItem:currentItemIndex];
                            });
         }
         else
         {
             _applyFirstItems = true;
         }
     }];
}

- (void)loadMoreItems
{
    [[SGraph instance] dispatchOnGraphQueue:^
     {
         int remoteMessagesProcessed = 0;
         int minMid = INT_MAX;
         int minLocalMid = INT_MAX;
         int index = 0;
         int minDate = INT_MAX;
         
         if (_reverseOrder)
         {
             for (int i = 0; i < _messageList.count && remoteMessagesProcessed < 10; i++)
             {
                 TGImageItem *imageItem = [_messageList objectAtIndex:i];
                 if (!imageItem.message.local)
                 {
                     remoteMessagesProcessed++;
                     if (imageItem.message.mid < minMid)
                         minMid = imageItem.message.mid;
                     index++;
                 }
                 else
                 {
                     if (imageItem.message.mid < minLocalMid)
                         minLocalMid = imageItem.message.mid;
                 }
                 
                 if ((int)imageItem.message.date < minDate)
                     minDate = (int)imageItem.message.date;
             }
         }
         else
         {
             for (int i = _messageList.count - 1; i >= 0 && remoteMessagesProcessed < 10; i--)
             {
                 TGImageItem *imageItem = [_messageList objectAtIndex:i];
                 if (!imageItem.message.local)
                 {
                     remoteMessagesProcessed++;
                     if (imageItem.message.mid < minMid)
                         minMid = imageItem.message.mid;
                     index++;
                 }
                 else
                 {
                     if (imageItem.message.mid < minLocalMid)
                         minLocalMid = imageItem.message.mid;
                 }
                 
                 if ((int)imageItem.message.date < minDate)
                     minDate = (int)imageItem.message.date;
             }
         }
         
         [[SGraph instance] requestNode:[NSString stringWithFormat:@"/tg/conversations/(%lld)/mediahistory/(%d)", _peerId, minMid] options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:index], @"offset", [NSNumber numberWithInt:minLocalMid], @"maxLocalMid", [NSNumber numberWithInt:minDate], @"maxDate", [NSNumber numberWithInt:minMid], @"maxMid", [NSNumber numberWithInt:50], @"limit", [[NSNumber alloc] initWithBool:_reverseOrder], @"reverseOrder", nil] watcher:self];
     }];
}

- (void)preloadCount
{
    if (_firstItemId != 0)
    {
        [TGDatabaseInstance() loadMediaPositionInConversation:_peerId messageId:_firstItemId completion:^(int position, int count)
         {
             _totalCount = count;
             
             dispatch_async(dispatch_get_main_queue(), ^
                            {
                                int resultPosition = position;
                                int resultCount = count;
                                if (!_reverseOrder)
                                    resultPosition = count - position - 1;
                                [_imageViewController positionInformationChanged:resultPosition totalCount:resultCount];
                            });
         }];
    }
}

- (void)deleteItem:(int)itemId
{
    [[SGraph instance] dispatchOnGraphQueue:^
     {
         static int actionId = 1;
         [[SGraph instance] requestAction:[NSString stringWithFormat:@"/tg/conversation/(%lld)/deleteMessages/(preview%d)", _peerId, actionId++] options:[NSDictionary dictionaryWithObject:[[NSArray alloc] initWithObjects:[[NSNumber alloc] initWithInt:itemId], nil] forKey:@"mids"] watcher:TGTelegraphInstance];
     }];
}

- (void)graphNodeRetrieveCompleted:(int)resultCode path:(NSString *)path node:(SGraphNode *)node
{
    if ([path hasPrefix:[NSString stringWithFormat:@"/tg/conversations/(%lld)/mediahistory/", _peerId]])
    {
        dispatch_async(dispatch_get_main_queue(), ^
                       {
                           bool canLoadMore = false;
                           
                           if (resultCode == GraphRequestStatusSuccess)
                           {
                               NSDictionary *dict = ((SGraphObjectNode *)node).object;
                               NSArray *mediaItems = [[dict objectForKey:@"messages"] sortedArrayUsingComparator:^NSComparisonResult(TGMessage *message1, TGMessage *message2)
                                                      {
                                                          NSTimeInterval delta = message1.date - message2.date;
                                                          if (ABS(delta) < FLT_EPSILON)
                                                          {
                                                              if (message1.local != message2.local)
                                                                  return NSOrderedSame;
                                                              return message1.mid < message2.mid ? NSOrderedDescending : NSOrderedAscending;
                                                          }
                                                          else
                                                              return delta < 0 ? NSOrderedDescending : NSOrderedAscending;
                                                      }];
                               
                               int returnedCount = [[dict objectForKey:@"count"] intValue];
                               if (returnedCount >= 0)
                                   _totalCount = returnedCount;
                               
                               std::set<int> existingMids;
                               for (TGImageItem *imageItem in _messageList)
                               {
                                   existingMids.insert(imageItem.message.mid);
                               }
                               
                               canLoadMore = mediaItems.count != 0;
                               
                               for (TGMessage *message in mediaItems)
                               {
                                   if (existingMids.find(message.mid) != existingMids.end())
                                       continue;
                                   
                                   for (TGMediaAttachment *attachment in message.mediaAttachments)
                                   {
                                       if (attachment.type == TGImageMediaAttachmentType)
                                       {
                                           TGImageItem *imageItem = [[TGImageItem alloc] init];
                                           imageItem.imageInfo = ((TGImageMediaAttachment *)attachment).imageInfo;
                                           imageItem.message = message;
                                           imageItem.author = [TGDatabaseInstance() loadUser:(int)message.fromUid];
                                           [_messageList addObject:imageItem];
                                           break;
                                       }
                                   }
                               }
                           }
                           else
                           {
                               canLoadMore = false;
                           }
                           
                           [_messageList sortUsingComparator:^NSComparisonResult(TGImageItem *message1, TGImageItem *message2)
                            {
                                NSComparisonResult result = NSOrderedSame;
                                
                                NSTimeInterval delta = message1.message.date - message2.message.date;
                                if (ABS(delta) < FLT_EPSILON)
                                {
                                    if (message1.message.local != message2.message.local)
                                        result = NSOrderedSame;
                                    result = message1.message.mid < message2.message.mid ? NSOrderedDescending : NSOrderedAscending;
                                }
                                else
                                    result = delta < 0 ? NSOrderedDescending : NSOrderedAscending;
                                
                                if (_reverseOrder)
                                {
                                    if (result == NSOrderedAscending)
                                        result = NSOrderedDescending;
                                    else if (result == NSOrderedDescending)
                                        result = NSOrderedAscending;
                                }
                                
                                return result;
                            }];
                           
                           if (_loadingFirstItems)
                           {
                               _loadingFirstItems = false;
                               
                               if (_applyFirstItems)
                               {
                                   _applyFirstItems = false;
                                   
                                   [self updateItems:_firstItemId];
                               }
                           }
                           else
                           {
                               NSArray *items = [[NSArray alloc] initWithArray:_messageList];
                               [_imageViewController itemsChanged:items totalCount:_totalCount canLoadMore:canLoadMore];
                           }
                       });
    }
}


@end
