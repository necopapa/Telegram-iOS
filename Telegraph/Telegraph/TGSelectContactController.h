/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "TGContactsController.h"

#import "TGNavigationController.h"

@interface TGSelectContactController : TGContactsController <TGNavigationControllerItem>

@property (nonatomic) bool shouldBeRemovedFromNavigationAfterHiding;

@property (nonatomic, strong) ASHandle *actionsHandle;

- (id)initWithCreateGroup:(bool)createGroup createEncrypted:(bool)createEncrypted;

@end
