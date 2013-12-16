/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "TGViewController.h"

#import "TGNavigationController.h"

#import "ActionStage.h"

@interface TGForwardTargetController : TGViewController <ASWatcher, TGViewControllerNavigationBarAppearance, TGNavigationControllerItem>

@property (nonatomic, strong) NSString *controllerTitle;
@property (nonatomic, strong) NSString *confirmationPrefix;

@property (nonatomic, strong) ASHandle *actionHandle;
@property (nonatomic, strong) ASHandle *watcherHandle;

- (id)initWithMessages:(NSArray *)messages;
- (id)initWithSelectBlockTarget;

@end
