/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <UIKit/UIKit.h>

#import "ASWatcher.h"

typedef enum {
    TGConversationActionsPanelTypeUser = 0,
    TGConversationActionsPanelTypeMutichat = 1
} TGConversationActionsPanelType;

@interface TGConversationActionsPanel : UIView

@property (nonatomic, strong) ASHandle *watcherHandle;

@property (nonatomic) bool isBeingShown;

@property (nonatomic) bool isCallingAllowed;
@property (nonatomic) bool isEditingAllowed;
@property (nonatomic) bool isMuted;
@property (nonatomic) bool isBlockAllowed;
@property (nonatomic) bool userIsBlocked;

- (id)initWithFrame:(CGRect)frame type:(TGConversationActionsPanelType)type;

- (void)show:(bool)animated;
- (void)hide:(bool)animated;

@end
