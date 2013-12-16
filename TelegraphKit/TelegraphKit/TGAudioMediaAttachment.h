/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "TGMediaAttachment.h"

#define TGAudioMediaAttachmentType 0x3A0E7A32

@interface TGAudioMediaAttachment : TGMediaAttachment

@property (nonatomic) int audioId;
@property (nonatomic) NSTimeInterval date;
@property (nonatomic, strong) NSString *caption;


@end
