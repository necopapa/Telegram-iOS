/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <UIKit/UIKit.h>

#import "ASWatcher.h"

#import "TGGroupedCell.h"

@interface TGPhoneItemCell : TGGroupedCell

@property (nonatomic, strong) ASHandle *watcherHandle;

@property (nonatomic, strong) NSString *label;
@property (nonatomic, strong) NSString *phone;

- (void)setIsMainPhone:(bool)isMainPhone;
- (void)setDisabled:(bool)disabled;
- (void)resetView;

- (bool)hasFocus;
- (void)requestFocus;

- (void)fadeOutEditingControls;

@end
