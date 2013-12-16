/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <UIKit/UIKit.h>

#import "TGLayoutItem.h"

#import "TGViewRecycler.h"

@interface TGLayoutModel : NSObject

@property (nonatomic, strong) NSMutableArray *items;

@property (nonatomic) int metrics;
@property (nonatomic) CGSize size;

@property (nonatomic) bool hideBackground;
@property (nonatomic) bool disableDoubleTap;

@property (nonatomic) bool containsAnimatedViews;

- (void)addLayoutItem:(TGLayoutItem *)item;

- (void)inflateLayoutToView:(UIView *)view viewRecycler:(TGViewRecycler *)viewRecycler actionTarget:(id)actionTarget;
- (void)updateLayoutInView:(UIView *)view;
- (void)drawLayout:(bool)highlighted;

- (NSString *)linkAtPoint:(CGPoint)point topRegion:(CGRect *)topRegion middleRegion:(CGRect *)middleRegion bottomRegion:(CGRect *)bottomRegion;
- (TGLayoutItem *)itemAtPoint:(CGPoint)point;

@end
