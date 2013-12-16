/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "TGLayoutItem.h"

#define TGLayoutItemTypeSimpleLabel ((int)0xf5f76767)

@interface TGLayoutSimpleLabelItem : TGLayoutItem

@property (nonatomic, strong) UIFont *font;
@property (nonatomic, strong) NSString *text;
@property (nonatomic) UITextAlignment textAlignment;
@property (nonatomic, strong) UIColor *textColor;
@property (nonatomic, strong) UIColor *backgroundColor;

@end
