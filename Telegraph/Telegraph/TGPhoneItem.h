/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "TGMenuItem.h"

#define TGPhoneItemType ((int)0x2E6506CC)

@interface TGPhoneItem : TGMenuItem <NSCopying>

@property (nonatomic, strong) NSString *label;
@property (nonatomic, strong) NSString *phone;
@property (nonatomic) bool isMainPhone;
@property (nonatomic) bool highlightMainPhone;
@property (nonatomic) bool disabled;

- (void)setFormattedPhone:(NSString *)formattedPhone;
- (NSString *)formattedPhone;

@end
