/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <UIKit/UIKit.h>

#import "TGListItemView.h"

@protocol TGListViewDataSource;

@interface TGListView : UIScrollView

@property (nonatomic, weak) id<TGListViewDataSource> dataSource;

@property (nonatomic) bool stackFromBottom;

@property (nonatomic, strong) UIView *headerView;

- (id)initWithFrame:(CGRect)frame;

- (void)reloadData;

- (void)insertItemsAtIndices:(NSArray *)indices animated:(bool)animated;
- (void)removeItemsAtIndices:(NSArray *)indices animated:(bool)animated;

- (TGListItemView *)dequeueListItemViewWithIdentifier:(NSString *)identifier;

@end

@protocol TGListViewDataSource <NSObject>

@required

- (TGListItemView *)listView:(TGListView *)listView itemViewAtIndex:(int)index section:(int)section;
- (int)listView:(TGListView *)listView heightForItemAtIndex:(int)index section:(int)section;
- (int)numberOfSectionsInListView:(TGListView *)listView;
- (int)listView:(TGListView *)listView numberOfRowsInSection:(int)section;

@end