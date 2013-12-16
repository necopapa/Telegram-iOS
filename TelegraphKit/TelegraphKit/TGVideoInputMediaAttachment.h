/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "TGInputMediaAttachment.h"

#import "TGVideoMediaAttachment.h"

@interface TGVideoInputMediaAttachment : TGInputMediaAttachment

@property (nonatomic) int64_t localVideoId;
@property (nonatomic) CGSize thumbnailSize;
@property (nonatomic, strong) NSData *thumbnailData;

@property (nonatomic) CGSize previewSize;
@property (nonatomic, strong) NSData *previewData;

@property (nonatomic) int size;
@property (nonatomic) int duration;
@property (nonatomic) CGSize dimensions;

@property (nonatomic) int64_t serverVideoId;
@property (nonatomic) int64_t serverAccessHash;

@property (nonatomic, strong) NSString *tmpFilePath;

@property (nonatomic, strong) NSString *assetUrl;

@property (nonatomic, strong) TGVideoMediaAttachment *serverVideoAttachment;

@end
