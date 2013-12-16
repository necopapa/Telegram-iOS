/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <UIKit/UIKit.h>

#import "TGMediaListView.h"

#import "TGGroupedCell.h"

@interface TGContactMediaItemCell : TGGroupedCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier mediaListView:(TGMediaListView *)mediaListView;

- (void)setTitle:(NSString *)title;
- (void)setCount:(int)count;
- (void)setIsLoading:(bool)isLoading;
- (void)setIsExpanded:(bool)isExpanded animated:(bool)animated;

@end
