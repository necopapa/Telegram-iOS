/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "TGConversationItemView.h"

#import "TGLayoutModel.h"
#import "TGMessage.h"

#import "TGViewRecycler.h"

#import "TGConversationMessageAssetsSource.h"
#import "TGConversationMessageItem.h"

#import "ActionStage.h"

#import <CoreText/CoreText.h>

typedef enum {
    TGConversationMessageMetricsPortrait = 1,
    TGConversationMessageMetricsLandscape = 2,
    TGConversationMessageMetricsSingleMessage = 4,
    TGConversationMessageMetricsHighlightUrls = 8,
    TGConversationMessageMetricsShowAvatars = 16
} TGConversationMessageMetrics;

#ifdef __cplusplus
extern "C" {
#endif
CGSize sizeForConversationMessage(TGConversationMessageItem *messageItem, int metrics, id<TGConversationMessageAssetsSource> assetsSource);
#ifdef __cplusplus
}
#endif

@interface TGConversationMessageItemView : TGConversationItemView

+ (TGLayoutModel *)layoutModelForMessage:(TGConversationItem *)messageitem withMetrics:(int)metrics assetsSource:(id<TGConversationMessageAssetsSource>)assetsSource;

+ (NSString *)generateMapUrl:(double)latitude longitude:(double)longitude;

+ (void)clearColorMapping;

+ (void)setDisplayMids:(bool)displayMids;
+ (bool)displayMids;

@property (nonatomic) int messageItemHash;

@property (nonatomic, strong) TGMessage *message;
@property (nonatomic, strong) TGConversationMessageItem *messageItem;

@property (nonatomic) int offsetFromGMT;

@property (nonatomic) bool isSelected;
@property (nonatomic) bool isContextSelected;

@property (nonatomic) bool showAvatar;
@property (nonatomic, strong) NSString *avatarUrl;

@property (nonatomic) bool disableBackgroundDrawing;
@property (nonatomic, strong) TGViewRecycler *viewRecycler;
@property (nonatomic, strong) ASHandle *watcher;

#if TGUseCollectionView
- (id)initWithFrame:(CGRect)frame;
#else
- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier;
#endif

- (void)resetView:(int)metrics;
- (void)changeAvatarAnimated:(NSString *)url;
- (void)animateState:(TGMessage *)newState;
- (void)updateState:(bool)force;

- (void)setIsSelected:(bool)isSelected;
- (void)setIsContextSelected:(bool)isSelected animated:(bool)animated;

- (void)setProgress:(bool)visible progress:(float)progress animated:(bool)animated;
- (void)setMediaNeedsDownload:(bool)mediaNeedsDownload;
- (void)reloadImageThumbnailWithUrl:(NSString *)url;

- (CGRect)contentFrameInView:(UIView *)view;

- (UIView *)currentContentView;
- (UIView *)currentBackgroundView;

- (CGRect)rectForItemWithClass:(Class)itemClass;
- (UIView *)viewForItemWithClass:(Class)itemClass;

- (void)setAlphaToItemsWithAdditionalTag:(int)additionalTag alpha:(float)alpha;

- (void)transitionContent:(NSTimeInterval)duration;

@end
