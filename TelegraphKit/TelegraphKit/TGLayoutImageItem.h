/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "TGLayoutItem.h"

#define TGLayoutItemTypeImage ((int)0x1b4d7e0b)

@interface TGLayoutImageItem : TGLayoutItem

@property (nonatomic, strong) UIImage *image;
@property (nonatomic) bool manualDrawing;

- (id)initWithImage:(UIImage *)image;

@end
