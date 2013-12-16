/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <UIKit/UIKit.h>

#import "TGTimelineItem.h"

#import "TGCache.h"

#import "TGRemoteImageView.h"

#import "ActionStage.h"

@interface TGTimelineCell : UITableViewCell <ASWatcher>
@property (nonatomic, strong) ASHandle *actionHandle;

+ (CGSize)timelineItemSize:(TGTimelineItem *)item;

@property (nonatomic) NSTimeInterval date;
@property (nonatomic, strong) NSString *imageUrl;
@property (nonatomic) CGSize imageSize;
@property (nonatomic, strong) TGCache *imageCache;

@property (nonatomic) UIImage *customImage;

@property (nonatomic) double locationLatitude;
@property (nonatomic) double locationLongitude;
@property (nonatomic, strong) NSString *locationName;

@property (nonatomic) bool showingActions;

@property (nonatomic) bool uploading;
@property (nonatomic) bool showActions;
@property (nonatomic, strong) ASHandle *actionHandler;
@property (nonatomic, strong) NSString *actionDelete;
@property (nonatomic, strong) NSString *actionAction;
@property (nonatomic, strong) NSString *actionPanelAppeared;
@property (nonatomic, strong) NSObject *actionTag;

@property (nonatomic, strong) TGRemoteImageView *photoView;

- (void)hideProgress;
- (void)fadeInProgress;
- (void)fadeOutProgress;
- (void)setProgress:(float)value;

- (void)toggleShowActions;

- (void)resetView;
- (void)resetLocation;

@end
