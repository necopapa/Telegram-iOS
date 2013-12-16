/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "TGConversationItemView.h"

#import "TGConversationMessageAssetsSource.h"

@interface TGConversationDateItemView : TGConversationItemView

@property (nonatomic, strong) NSString *dateString;

#if TGUseCollectionView
#else
- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier;
#endif

@end
