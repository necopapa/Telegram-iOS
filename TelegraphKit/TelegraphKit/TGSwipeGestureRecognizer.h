/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <UIKit/UIKit.h>

typedef enum {
    TGSwipeGestureRecognizerDirectionRight = 1,
    TGSwipeGestureRecognizerDirectionLeft = 2
} TGSwipeGestureRecognizerDirection;

@interface TGSwipeGestureRecognizer : UIGestureRecognizer

@property (nonatomic) float directionLockThreshold;
@property (nonatomic) float horizontalThreshold;
@property (nonatomic) float verticalThreshold;

@property (nonatomic) float velocityThreshold;
@property (nonatomic) float velocityFailDistance;

@property (nonatomic) int direction;

- (void)failGesture;

@end
