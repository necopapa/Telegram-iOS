/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <UIKit/UIKit.h>

#import "TGUser.h"
#import "TGConversation.h"
#import "TGMessage.h"

#import "TGDialogListCellAssetsSource.h"

@class TGDialogListController;

@interface TGDialogListCompanion : NSObject

@property (nonatomic, weak) TGDialogListController *dialogListController;

@property (nonatomic) bool showListEditingControl;
@property (nonatomic) bool forwardMode;

@property (nonatomic) int unreadCount;

- (id<TGDialogListCellAssetsSource>)dialogListCellAssetsSource;

- (void)dialogListReady;
- (void)updateLeftBarItem:(bool)animated;
- (void)updateTitle:(bool)animated;

- (void)clearData;

- (void)loadMoreItems;

- (void)composeMessage;
- (void)conversationSelected:(TGConversation *)conversation;
- (void)deleteItem:(TGConversation *)conversation animated:(bool)animated;
- (void)clearItem:(TGConversation *)conversation animated:(bool)animated;

- (void)beginSearch:(NSString *)queryString inMessages:(bool)inMessages;
- (void)searchResultSelectedUser:(TGUser *)user;
- (void)searchResultSelectedConversation:(TGConversation *)conversation;
- (void)searchResultSelectedConversation:(TGConversation *)conversation atMessageId:(int)messageId;
- (void)searchResultSelectedMessage:(TGMessage *)message;

- (bool)shouldDisplayEmptyListPlaceholder;

- (void)wakeUp;

@end
