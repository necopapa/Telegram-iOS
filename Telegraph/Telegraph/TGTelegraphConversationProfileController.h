/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "TGViewController.h"

#import "ActionStage.h"

#import "TGConversation.h"
#import "TGNavigationController.h"

@interface TGTelegraphConversationProfileController : TGViewController <ASWatcher, TGNavigationControllerItem>

@property (nonatomic, strong) ASHandle *actionHandle;
@property (nonatomic, strong) ASHandle *watcher;

@property (nonatomic) bool createChat;

@property (nonatomic) bool activateCamera;
@property (nonatomic) bool activatedCamera;
@property (nonatomic) bool activateTitleChange;

- (id)initWithConversation:(TGConversation *)conversation;
- (id)initWithCreateChat;

- (void)setCreateChatParticipants:(NSArray *)participants;

@end
