/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "TGLayoutItem.h"

#define TGLayoutItemTypeButton ((int)0x56DE49AA)

@interface TGLayoutButtonItem : TGLayoutItem

@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) UIImage *backgroundImage;
@property (nonatomic, strong) UIImage *backgroundHighlightedImage;
@property (nonatomic, strong) UIFont *titleFont;
@property (nonatomic, strong) UIColor *titleColor;
@property (nonatomic, strong) UIColor *titleShadow;
@property (nonatomic, strong) UIColor *titleHighlightedColor;
@property (nonatomic, strong) UIColor *titleHighlightedShadow;
@property (nonatomic) CGSize titleShadowOffset;

@end
