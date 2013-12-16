/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <Foundation/Foundation.h>

#import "TGWeakDelegate.h"

@protocol TGBackgroundRenderingOperation <NSObject>

- (void)render;

@end

@interface TGBackgroundRendering : NSObject

+ (id)requestRendering:(TGWeakDelegate *)receiver operation:(id<TGBackgroundRenderingOperation>)operation;
+ (void)cancelRendering:(id)tag;

@end
