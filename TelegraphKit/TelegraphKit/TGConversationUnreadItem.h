/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "TGConversationItem.h"

@interface TGConversationUnreadItem : TGConversationItem

@property (nonatomic) int unreadCount;

- (id)initWithUnreadCount:(int)unreadCount;

- (NSString *)title;
- (int)token;

@end
