/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "TGViewController.h"

#import "ASWatcher.h"

typedef enum {
    TGCustomNotificationControllerModeUser = 0,
    TGCustomNotificationControllerModeGroup = 1,
    TGCustomNotificationControllerModeSettings = 2
} TGCustomNotificationControllerMode;

@interface TGCustomNotificationController : TGViewController <ASWatcher>

@property (nonatomic, strong) ASHandle *actionHandle;
@property (nonatomic, strong) ASHandle *watcherHandle;

@property (nonatomic) int tag;

@property (nonatomic) int selectedIndex;

- (void)skipDefault;

- (id)initWithMode:(TGCustomNotificationControllerMode)mode;

@end
