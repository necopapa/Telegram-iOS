/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <UIKit/UIKit.h>

#import "TGGroupedCell.h"

@interface TGNearbyUserCell : TGGroupedCell

@property (nonatomic) int uid;

@property (nonatomic, strong) NSString *avatarUrl;
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *subtitle;

- (void)resetView:(bool)keepState;

@end
