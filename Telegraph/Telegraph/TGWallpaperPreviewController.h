/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "TGViewController.h"

#import "TGImageInfo.h"

#import "ASWatcher.h"

@interface TGWallpaperPreviewController : TGViewController <ASWatcher>

@property (nonatomic, strong) ASHandle *actionHandle;

@property (nonatomic, strong) ASHandle *watcherHandle;

- (id)initWithWallpaperInfo:(NSDictionary *)wallpaperInfo;
- (id)initWithImage:(UIImage *)image;

@end
