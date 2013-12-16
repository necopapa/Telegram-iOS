/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <UIKit/UIKit.h>

@class TGWallpaperItemsCell;

@protocol TGWallpaperItemsCellDelegate

- (void)wallpaperItemsCell:(TGWallpaperItemsCell *)cell imagePressed:(NSDictionary *)wallpaperInfo;

@end

@interface TGWallpaperItemsCell : UITableViewCell

@property (nonatomic, weak) id<TGWallpaperItemsCellDelegate> delegate;

- (void)reset:(int)imagesInRow;
- (void)addImage:(NSDictionary *)wallpaperInfo;

- (void)setCheckedItem:(NSString *)url;

@end
