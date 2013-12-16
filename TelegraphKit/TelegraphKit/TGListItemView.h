/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <UIKit/UIKit.h>

#import "TGReusableView.h"

@interface TGListItemView : UIView <TGReusableView>

@property (nonatomic, strong) NSString *reuseIdentifier;

@property (nonatomic) int index;
@property (nonatomic) int section;

@property (nonatomic) bool editing;

@property (nonatomic) bool backgroundRendering;

- (id)initWithFrame:(CGRect)frame reuseIdentifier:(NSString *)reuseIdentifier;

- (void)beginBackgroundRendering;

@end
