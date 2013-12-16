/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <UIKit/UIKit.h>

#ifdef __cplusplus
extern "C" {
#endif
    
typedef enum {
    TGScaleImageFlipVerical = 1,
    TGScaleImageScaleOverlay = 2,
    TGScaleImageRoundCornersByOuterBounds = 4
} TGScaleImageFlags;

UIImage *TGScaleImage(UIImage *image, CGSize size);
UIImage *TGScaleAndRoundCorners(UIImage *image, CGSize size, CGSize imageSize, int radius, UIImage *overlay, bool opaque, UIColor *backgroundColor);
UIImage *TGScaleAndRoundCornersWithOffset(UIImage *image, CGSize size, CGPoint offset, CGSize imageSize, int radius, UIImage *overlay, bool opaque, UIColor *backgroundColor);
UIImage *TGScaleAndRoundCornersWithOffsetAndFlags(UIImage *image, CGSize size, CGPoint offset, CGSize imageSize, int radius, UIImage *overlay, bool opaque, UIColor *backgroundColor, int flags);

UIImage *TGScaleImageToPixelSize(UIImage *image, CGSize size);
UIImage *TGRotateAndScaleImageToPixelSize(UIImage *image, CGSize size);

UIImage *TGFixOrientationAndCrop(UIImage *source, CGRect cropFrame, CGSize imageSize);
UIImage *TGRotateAndCrop(UIImage *source, CGRect cropFrame, CGSize imageSize);
    
UIImage *TGAttachmentImage(UIImage *source, CGSize sourceSize, CGSize size, bool incoming, bool location);
    
UIImage *TGIdenticonImage(NSData *data, CGSize size);
    
#ifdef __cplusplus
}
#endif

@interface UIImage (Preloading)

- (UIImage *)preloadedImage;
- (void)tgPreload;

- (void)setMediumImage:(UIImage *)image;
- (UIImage *)mediumImage;

- (CGSize)screenSize;

@end

#ifdef __cplusplus
extern "C" {
#endif

CGSize TGFitSize(CGSize size, CGSize maxSize);
CGSize TGFillSize(CGSize size, CGSize maxSize);
CGSize TGCropSize(CGSize size, CGSize maxSize);
    
bool TGIsRetina();

#ifdef __cplusplus
}
#endif