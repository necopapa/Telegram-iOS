/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "TGInputMediaAttachment.h"

#import <UIKit/UIKit.h>

#import "TGImageMediaAttachment.h"

@interface TGImageInputMediaAttachment : TGInputMediaAttachment

@property (nonatomic, strong) NSData *imageData;
@property (nonatomic, strong) NSData *thumbnailData;

@property (nonatomic) CGSize imageSize;
@property (nonatomic) CGSize thumbnailSize;

@property (nonatomic, strong) UIImage *image;

@property (nonatomic, strong) NSString *assetUrl;

@property (nonatomic) int64_t serverImageId;
@property (nonatomic) int64_t serverAccessHash;
@property (nonatomic, strong) TGImageMediaAttachment *serverImageAttachment;

@end
