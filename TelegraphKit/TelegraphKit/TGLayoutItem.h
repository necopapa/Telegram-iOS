/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <UIKit/UIKit.h>

typedef int TGLayoutItemType;

@interface TGLayoutItem : NSObject

@property (nonatomic) TGLayoutItemType type;
@property (nonatomic) int tag;
@property (nonatomic) int additionalTag;

@property (nonatomic) CGRect frame;
@property (nonatomic) bool userInteractionEnabled;

- (id)initWithType:(TGLayoutItemType)type;

@end
