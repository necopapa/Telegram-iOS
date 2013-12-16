/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "TGMenuItem.h"

#import "TGUser.h"

#define TGUserMenuItemType ((int)0xF3D677EC)

@interface TGUserMenuItem : TGMenuItem

@property (nonatomic, strong) TGUser *user;

@end
