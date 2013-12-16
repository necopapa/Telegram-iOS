/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <UIKit/UIKit.h>

#define TGUseCollectionView false

@interface TGConversationItemView
#if TGUseCollectionView
: UICollectionViewCell
#else
: UITableViewCell
#endif

#if TGUseCollectionView
@property (nonatomic) bool editing;

- (void)setEditing:(BOOL)editing animated:(BOOL)animated;

#endif

@end
