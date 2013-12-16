/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <Foundation/Foundation.h>

#import "TGConversationItem.h"

#import "TGMessage.h"
#import "TGUser.h"

@interface TGConversationMessageItem : TGConversationItem <NSCopying>

@property (nonatomic, strong) TGMessage *message;
@property (nonatomic, strong) TGUser *author;

@property (nonatomic, strong) NSDictionary *messageUsers;

@property (nonatomic) id progressMediaId;

- (id)initWithMessage:(TGMessage *)message;
- (bool)hasSomeAttachment;

@end
