/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "TGViewController.h"

#import "TGMenuItem.h"

@interface TGListMenuController : TGViewController

@property (nonatomic, strong) UITableView *tableView;

+ (UITableViewCell *)tableView:(UITableView *)tableView cellForMenuItem:(TGMenuItem *)item;

@end
