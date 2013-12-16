/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "TGLayoutItem.h"

#import "TGReusableLabel.h"

#import <CoreText/CoreText.h>

#define TGLayoutItemTypeText ((int)0xf06f362a)

@interface TGLayoutTextItem : TGLayoutItem

@property (nonatomic, retain) NSString *text;
@property (nonatomic, retain) UIFont *font;
@property (nonatomic, retain) UIColor *textColor;
@property (nonatomic, retain) UIColor *shadowColor;
@property (nonatomic, retain) UIColor *highlightedTextColor;
@property (nonatomic) CGSize shadowOffset;
@property (nonatomic, retain) UIColor *highlightedShadowColor;
@property (nonatomic) int numberOfLines;
@property (nonatomic) UITextAlignment textAlignment;

@property (nonatomic) bool manualDrawing;

@property (nonatomic) int flags;

@property (nonatomic) bool richText;
@property (nonatomic) CTFontRef coreTextFont;
@property (nonatomic, strong) TGReusableLabelLayoutData *precalculatedLayout;

- (id)initWithText:(NSString *)text font:(UIFont *)font textColor:(UIColor *)textColor shadowColor:(UIColor *)shadowColor highlightedTextColor:(UIColor *)highlightedTextColor highlightedShadowColor:(UIColor *)highlightedShadowColor shadowOffset:(CGSize)shadowOffset richText:(bool)richText;
- (id)initWithRichText:(NSString *)text font:(CTFontRef)font textColor:(UIColor *)textColor shadowColor:(UIColor *)shadowColor shadowOffset:(CGSize)shadowOffset;

@end
