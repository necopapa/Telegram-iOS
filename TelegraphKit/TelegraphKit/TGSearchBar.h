/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <UIKit/UIKit.h>

@class TGSearchBar;

@protocol TGSearchBarDelegate <NSObject>

- (void)searchBar:(TGSearchBar *)searchBar willChangeHeight:(float)newHeight;

@end

@interface TGSearchBar : UISearchBar

@property (nonatomic) UIEdgeInsets searchContentInset;

@property (nonatomic) bool searchBarShouldShowScopeControl;

@property (nonatomic) bool useDarkStyle;

- (void)setSearchPlaceholderColor:(UIColor *)color;

- (void)setSearchBarCombinesBars:(BOOL)searchBarCombinesBars;

@end
