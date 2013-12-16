/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <UIKit/UIKit.h>

@interface TGTextField : UITextField

@property (nonatomic, strong) UIColor *placeholderColor;
@property (nonatomic, strong) UIColor *normalPlaceholderColor;
@property (nonatomic, strong) UIColor *highlightedPlaceholderColor;
@property (nonatomic, strong) UIFont *placeholderFont;

@property (nonatomic, strong) UIColor *normalTextColor;
@property (nonatomic, strong) UIColor *highlightedTextColor;

@end
