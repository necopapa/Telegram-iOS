#import "TGDialogListCompanion.h"

@implementation TGDialogListCompanion

@synthesize dialogListController = _dialogListController;

@synthesize showListEditingControl = _showListEditingControl;
@synthesize forwardMode = _forwardMode;

@synthesize unreadCount = _unreadCount;

- (id<TGDialogListCellAssetsSource>)dialogListCellAssetsSource
{
    return nil;
}

- (void)dialogListReady
{
    
}

- (void)updateLeftBarItem:(bool)__unused animated
{
    
}

- (void)updateTitle:(bool)__unused animated
{
    
}

- (void)clearData
{
    
}

- (void)loadMoreItems
{
    
}

- (void)composeMessage
{
    
}

- (void)conversationSelected:(TGConversation *)__unused conversation
{
}

- (void)deleteItem:(TGConversation *)__unused conversation animated:(bool)__unused animated;
{
}

- (void)clearItem:(TGConversation *)__unused conversation animated:(bool)__unused animated
{
}

- (void)beginSearch:(NSString *)__unused queryString inMessages:(bool)__unused inMessages
{
    
}

- (void)searchResultSelectedUser:(TGUser *)__unused user
{
    
}

- (void)searchResultSelectedConversation:(TGConversation *)__unused conversation
{
    
}

- (void)searchResultSelectedConversation:(TGConversation *)__unused conversation atMessageId:(int)__unused messageId
{
    
}

- (void)searchResultSelectedMessage:(TGMessage *)__unused message
{
    
}

- (bool)shouldDisplayEmptyListPlaceholder
{
    return true;
}

- (void)wakeUp
{
    
}

@end
