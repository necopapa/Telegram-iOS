/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <Foundation/Foundation.h>

typedef enum {
    TGConversationItemTypeMessage = 0,
    TGConversationItemTypeDate = 1,
    TGConversationItemTypeUnread = 2
} TGConversationItemType;

@interface TGConversationItem : NSObject

@property (nonatomic) TGConversationItemType type;

- (id)initWithType:(TGConversationItemType)type;

@end
