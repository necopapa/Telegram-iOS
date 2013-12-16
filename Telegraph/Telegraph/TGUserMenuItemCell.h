/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <UIKit/UIKit.h>

#import "TGGroupedCell.h"
#import "TGUser.h"

@interface TGUserMenuItemCell : TGGroupedCell

@property (nonatomic) int uid;
@property (nonatomic, strong) TGUser *user;
@property (nonatomic) bool editable;
@property (nonatomic) bool alwaysNonEditable;

@property (nonatomic, strong) NSString *avatarUrl;
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *subtitle;
@property (nonatomic) bool subtitleActive;

@property (nonatomic) bool isDisabled;

- (void)resetView:(bool)keepState;
- (void)setIsDisabled:(bool)isDisabled animated:(bool)animated;
- (void)updateEditable;
- (void)updateEditable:(bool)animated;

@end
