#import "TGImageUtils.h"

#import <Accelerate/Accelerate.h>

#import <libkern/OSAtomic.h>
#include <map>

#import <objc/runtime.h>

#import "TGStringUtils.h"
#import "TGIdenticonDrawer.h"

//#import <arm_neon.h>

static bool retinaInitialized = false;
static bool isRetina()
{
    static bool retina = false;
    if (!retinaInitialized)
    {
        retina = [[UIScreen mainScreen] scale] > 1.9f;
        retinaInitialized = true;
    }
    return retina;
}

static void addRoundedRectToPath(CGContextRef context, CGRect rect, float ovalWidth, float ovalHeight)
{
    float fw, fh;
    if (ovalWidth == 0 || ovalHeight == 0)
    {
        CGContextAddRect(context, rect);
        return;
    }
    CGContextSaveGState(context);
    CGContextTranslateCTM (context, CGRectGetMinX(rect), CGRectGetMinY(rect));
    CGContextScaleCTM (context, ovalWidth, ovalHeight);
    fw = CGRectGetWidth (rect) / ovalWidth;
    fh = CGRectGetHeight (rect) / ovalHeight;
    CGContextMoveToPoint(context, fw, fh/2);
    CGContextAddArcToPoint(context, fw, fh, fw/2, fh, 1);
    CGContextAddArcToPoint(context, 0, fh, 0, fh/2, 1);
    CGContextAddArcToPoint(context, 0, 0, fw/2, 0, 1);
    CGContextAddArcToPoint(context, fw, 0, fw, fh/2, 1);
    CGContextClosePath(context);
    CGContextRestoreGState(context);
}

static void releasePixels(__unused void *info, const void *data, __unused size_t size)
{
    free((void *)data);
}

static void releaseData(void *info, __unused const void *data, __unused size_t size)
{
    if (info != NULL)
        CFRelease((CFTypeRef)info);
}

UIImage *scaleImageFast(__unused UIImage *image, __unused CGSize size, __unused int roundCorderRadius)
{
#if 0
    
    CGImageRef cgimage = image.CGImage;
    
    size_t width  = CGImageGetWidth(cgimage);
    size_t height = CGImageGetHeight(cgimage);
    
    __unused CGColorSpaceRef colorSpace = CGImageGetColorSpace(cgimage);
    
    CGBitmapInfo imageBitmapInfo = CGImageGetBitmapInfo(cgimage);
    size_t bpr = CGImageGetBytesPerRow(cgimage);
    size_t bpp = CGImageGetBitsPerPixel(cgimage);
    size_t bpc = CGImageGetBitsPerComponent(cgimage);
    size_t bytes_per_pixel = bpp / bpc;
    
    if (bytes_per_pixel == 4 && bpr >= width * 4)
    {
        CGDataProviderRef provider = CGImageGetDataProvider(cgimage);
        CFDataRef data = CGDataProviderCopyData(provider);
        
        uint8_t *destPixels = NULL;
        CGDataProviderRef destProvider = NULL;
        
        int destBytesPerRow = 0;
        
        if (width == (int)size.width && height == (int)size.height && roundCorderRadius <= 0)
        {
            CFRetain((CFTypeRef)data);
            destProvider = CGDataProviderCreateWithData((void *)data, (void *)CFDataGetBytePtr(data), CFDataGetLength(data), &releaseData);
            destBytesPerRow = bpr;
        }
        else
        {
            int newRowbytes = ((int)size.width) * 4;
            int dataSize = ((int)size.width) * ((int)(size.height)) * 4;
            while ((dataSize % 16) != 0)
            {
                dataSize++;
                newRowbytes++;
            }
            
            destBytesPerRow = newRowbytes;
            
            posix_memalign((void **)&destPixels, 16, dataSize);
            
            vImage_Buffer srcImage;
            srcImage.width = width;
            srcImage.height = height;
            srcImage.rowBytes = bpr;
            srcImage.data = (void *)CFDataGetBytePtr(data);
            
            vImage_Buffer dstImage;
            dstImage.width = (int)size.width;
            dstImage.height = (int)(size.height);
            dstImage.rowBytes = newRowbytes;
            dstImage.data = destPixels;
            
            vImageScale_ARGB8888(&srcImage, &dstImage, NULL, kvImageDoNotTile);
            
            destProvider = CGDataProviderCreateWithData(NULL, destPixels, dataSize, &releasePixels);
        }
        
        if (roundCorderRadius > 0 && destPixels != NULL)
        {
            static std::map<int, uint8_t *> roundedCornerMap;
            static volatile OSSpinLock roundedCornerMapLock = OS_SPINLOCK_INIT;
            
            uint8_t *alphaValues = NULL;
            OSSpinLockLock(&roundedCornerMapLock);
            std::map<int, uint8_t *>::iterator it = roundedCornerMap.find(roundCorderRadius);
            if (it != roundedCornerMap.end())
                alphaValues = it->second;
            OSSpinLockUnlock(&roundedCornerMapLock);
            
            if (alphaValues == NULL)
            {
                //TGLog(@"Generate corners alpha map for %d", roundCorderRadius);
                alphaValues = (uint8_t *)malloc(roundCorderRadius * roundCorderRadius);
                memset(alphaValues, 0xff, roundCorderRadius * roundCorderRadius);
                
                for (int y = 0; y < roundCorderRadius; y++)
                {
                    for (int x = 0; x < roundCorderRadius; x++)
                    {
                        int cx = roundCorderRadius - x;
                        int cy = roundCorderRadius - y;
                        float value = sqrtf(cy*cy + cx*cx);
                        if (value > roundCorderRadius + 1)
                        {
                            alphaValues[y * roundCorderRadius + x] = 0;
                        }
                        else if (value > roundCorderRadius - 1)
                        {
                            float svalue = 9.0f;
                            for (float csy = cy - 0.5f; csy < cy + 0.6f; csy += 0.5f)
                            {
                                for (float csx = cx - 0.5f; csx < cx + 0.6f; csx += 0.5f)
                                {
                                    float rad = sqrtf(csx*csx + csy*csy);
                                    if (rad > roundCorderRadius)
                                        svalue -= rad - roundCorderRadius;
                                }
                            }
                            int alpha = (int)(svalue / 9.0f * 255.0f);
                            if (alpha > 255)
                                alpha = 255;
                            alphaValues[y * roundCorderRadius + x] = (uint8_t)(alpha);
                        }
                    }
                }
                
                OSSpinLockLock(&roundedCornerMapLock);
                roundedCornerMap.insert(std::pair<int, uint8_t *>(roundCorderRadius, alphaValues));
                OSSpinLockUnlock(&roundedCornerMapLock);
            }
            
            if (alphaValues != NULL)
            {
                int targetWidth = (int)size.width;
                int targetHeight = (int)size.width;
                
#define processPixels(r,g,b,a) for (int y = 0; y < roundCorderRadius; y++) \
                { \
                    int yTimesTargetWidth = y * targetWidth; \
                    int invYTimesTargetWidth = (targetHeight - y - 1) * targetWidth; \
                    for (int x = 0; x < roundCorderRadius; x++) \
                    { \
                        int alpha = alphaValues[y * roundCorderRadius + x]; \
                        uint8_t *p1 = &destPixels[(yTimesTargetWidth + x) * 4]; \
                        uint8_t *p2 = &destPixels[(yTimesTargetWidth + targetWidth - x - 1) * 4]; \
                        uint8_t *p3 = &destPixels[(invYTimesTargetWidth + x) * 4]; \
                        uint8_t *p4 = &destPixels[(invYTimesTargetWidth + targetWidth - x - 1) * 4]; \
                         \
                        p1[a] = (uint8_t)alpha; \
                        p2[a] = (uint8_t)alpha; \
                        p3[a] = (uint8_t)alpha; \
                        p4[a] = (uint8_t)alpha; \
                         \
                        /*if (pre) \
                        { \
                            p1[r] = p1[r] * 255 / p1[a]; \
                            p1[g] = p1[g] * 255 / p1[a]; \
                            p1[b] = p1[b] * 255 / p1[a]; \
                        }*/ \
                         \
                        p1[r] = (uint8_t)(p1[r] * alpha / 255); \
                        p1[g] = (uint8_t)(p1[g] * alpha / 255); \
                        p1[b] = (uint8_t)(p1[b] * alpha / 255); \
                         \
                        p2[r] = (uint8_t)(p2[r] * alpha / 255); \
                        p2[g] = (uint8_t)(p2[g] * alpha / 255); \
                        p2[b] = (uint8_t)(p2[b] * alpha / 255); \
                         \
                        p3[r] = (uint8_t)(p3[r] * alpha / 255); \
                        p3[g] = (uint8_t)(p3[g] * alpha / 255); \
                        p3[b] = (uint8_t)(p3[b] * alpha / 255); \
                         \
                        p4[r] = (uint8_t)(p4[r] * alpha / 255); \
                        p4[g] = (uint8_t)(p4[g] * alpha / 255); \
                        p4[b] = (uint8_t)(p4[b] * alpha / 255); \
                    } \
                }
                
                if ((imageBitmapInfo & kCGImageAlphaPremultipliedLast) || (imageBitmapInfo & kCGImageAlphaLast) || (imageBitmapInfo & kCGImageAlphaNoneSkipFirst))
                {
                    //bool premultiplied = (imageBitmapInfo & kCGImageAlphaPremultipliedLast);
                    processPixels(0, 1, 2, 3);
                    imageBitmapInfo &= ~kCGBitmapAlphaInfoMask;
                    imageBitmapInfo |= kCGImageAlphaPremultipliedLast;
                }
                else if ((imageBitmapInfo & kCGImageAlphaPremultipliedFirst) || (imageBitmapInfo & kCGImageAlphaFirst) || (imageBitmapInfo & kCGImageAlphaNoneSkipFirst))
                {
                    //bool premultiplied = (imageBitmapInfo & kCGImageAlphaPremultipliedFirst);
                    processPixels(1, 2, 3, 0);
                    imageBitmapInfo &= ~kCGBitmapAlphaInfoMask;
                    imageBitmapInfo |= kCGImageAlphaPremultipliedFirst;
                }
            }
        }
        
        CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault | kCGImageAlphaPremultipliedFirst;
        bitmapInfo = imageBitmapInfo;
        
        CGColorSpaceRef deviceColorSpace = CGColorSpaceCreateDeviceRGB();
        
        CGImageRef resultImage = CGImageCreate((int)size.width, (int)size.height, 8, 32, destBytesPerRow, deviceColorSpace, bitmapInfo, destProvider, NULL, false, kCGRenderingIntentDefault);
        
        if (data != NULL)
            CFRelease(data);
        if (destProvider != NULL)
            CGDataProviderRelease(destProvider);
        if (deviceColorSpace != NULL)
            CGColorSpaceRelease(deviceColorSpace);
        
        UIImage *result = [[UIImage alloc] initWithCGImage:resultImage];
        CGImageRelease(resultImage);
        return result;
    }
    
#endif
    
    return nil;
}

UIImage *TGScaleImage(UIImage *image, CGSize size)
{
    return TGScaleAndRoundCornersWithOffset(image, size, CGPointZero, size, 0, nil, true, nil);
}

UIImage *TGScaleAndRoundCorners(UIImage *image, CGSize size, CGSize imageSize, int radius, UIImage *overlay, bool opaque, UIColor *backgroundColor)
{
    return TGScaleAndRoundCornersWithOffset(image, size, CGPointZero, imageSize, radius, overlay, opaque, backgroundColor);
}

UIImage *TGScaleAndRoundCornersWithOffset(UIImage *image, CGSize size, CGPoint offset, CGSize imageSize, int radius, UIImage *overlay, bool opaque, UIColor *backgroundColor)
{
    return TGScaleAndRoundCornersWithOffsetAndFlags(image, size, offset, imageSize, radius, overlay, opaque, backgroundColor, 0);
}

UIImage *TGScaleAndRoundCornersWithOffsetAndFlags(UIImage *image, CGSize size, CGPoint offset, CGSize imageSize, int radius, UIImage *overlay, bool opaque, UIColor *backgroundColor, int flags)
{
    if (CGSizeEqualToSize(imageSize, CGSizeZero))
        imageSize = size;
    
    float scale = 1.0f;
    if (isRetina())
    {
        scale = 2.0f;
        size.width *= 2;
        size.height *= 2;
        imageSize.width *= 2;
        imageSize.height *= 2;
        radius *= 2;
    }
    
    UIGraphicsBeginImageContextWithOptions(imageSize, opaque, 1.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    if (overlay != nil)
        CGContextSaveGState(context);
    
    if (backgroundColor != nil)
    {
        CGContextSetFillColorWithColor(context, backgroundColor.CGColor);
        CGContextFillRect(context, CGRectMake(0, 0, imageSize.width, imageSize.height));
    }
    else if (opaque)
    {
        static UIColor *whiteColor = nil;
        if (whiteColor == nil)
            whiteColor = [UIColor whiteColor];
        CGContextSetFillColorWithColor(context, whiteColor.CGColor);
        CGContextFillRect(context, CGRectMake(0, 0, imageSize.width, imageSize.height));
    }
    
    if (radius > 0)
    {
        CGContextBeginPath(context);
        CGRect rect = (flags & TGScaleImageRoundCornersByOuterBounds) ? CGRectMake(offset.x * scale, offset.y * scale, imageSize.width, imageSize.height) : CGRectMake(offset.x * scale, offset.y * scale, size.width, size.height);
        addRoundedRectToPath(context, rect, radius, radius);
        CGContextClosePath(context);
        CGContextClip(context);
    }
    
    CGPoint actualOffset = CGPointEqualToPoint(offset, CGPointZero) ? CGPointMake((int)((imageSize.width - size.width) / 2), (int)((imageSize.height - size.height) / 2)) : CGPointMake(offset.x * scale, offset.y * scale);
    if (flags & TGScaleImageFlipVerical)
    {
        CGContextTranslateCTM(context, actualOffset.x + size.width / 2, actualOffset.y + size.height / 2);
        CGContextScaleCTM(context, 1.0f, -1.0f);
        CGContextTranslateCTM(context, -actualOffset.x - size.width / 2, -actualOffset.y - size.height / 2);
    }
    [image drawInRect:CGRectMake(actualOffset.x, actualOffset.y, size.width, size.height) blendMode:kCGBlendModeCopy alpha:1.0f];
    
    if (overlay != nil)
    {
        CGContextRestoreGState(context);
        
        if (flags & TGScaleImageScaleOverlay)
        {
            CGContextScaleCTM(context, scale, scale);
            [overlay drawInRect:CGRectMake(0, 0, imageSize.width / scale, imageSize.height / scale)];
        }
        else
        {
            [overlay drawInRect:CGRectMake(0, 0, overlay.size.width * scale, overlay.size.height * scale)];
        }
    }
    
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return result;
}

UIImage *TGScaleImageToPixelSize(UIImage *image, CGSize size)
{
    UIGraphicsBeginImageContextWithOptions(size, true, 1.0f);
    [image drawInRect:CGRectMake(0, 0, size.width, size.height) blendMode:kCGBlendModeCopy alpha:1.0f];
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return result;
}

UIImage *TGRotateAndScaleImageToPixelSize(UIImage *image, CGSize size)
{
    UIGraphicsBeginImageContextWithOptions(size, true, 1.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextTranslateCTM(context, size.height / 2, size.width / 2);
    CGContextRotateCTM(context, -(float)M_PI_2);
    CGContextTranslateCTM(context, -size.height / 2 + (size.width - size.height) / 2, -size.width / 2 + (size.width - size.height) / 2);
    
    CGContextScaleCTM (context, size.width / image.size.height, size.height / image.size.width);
    
    [image drawAtPoint:CGPointMake(0, 0) blendMode:kCGBlendModeCopy alpha:1.0f];
    
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return result;
}

UIImage *TGFixOrientationAndCrop(UIImage *source, CGRect cropFrame, CGSize imageSize)
{
    /*float scale = 1.0f;
    if (isRetina())
    {
        scale = 2.0f;
        imageSize.width *= 2;
        imageSize.height *= 2;
    }*/
    
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(imageSize.width, imageSize.height), true, 1.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGSize sourceSize = source.size;
    float sourceScale = source.scale;
    sourceSize.width *= sourceScale;
    sourceSize.height *= sourceScale;
    
    CGContextScaleCTM (context, imageSize.width / cropFrame.size.width, imageSize.height / cropFrame.size.height);
    [source drawAtPoint:CGPointMake(-cropFrame.origin.x, -cropFrame.origin.y) blendMode:kCGBlendModeCopy alpha:1.0f];
    //[source drawInRect:CGRectMake(-cropFrame.origin.x, -cropFrame.origin.y, sourceSize.width, sourceSize.height) blendMode:kCGBlendModeCopy alpha:1.0f];
    UIImage *croppedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return croppedImage;
}

UIImage *TGRotateAndCrop(UIImage *source, CGRect cropFrame, CGSize imageSize)
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(imageSize.width, imageSize.height), true, 1.0f);
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextTranslateCTM(context, imageSize.width / 2, imageSize.height / 2);
    CGContextRotateCTM(context, (float)M_PI_2);
    CGContextTranslateCTM(context, -imageSize.width / 2, -imageSize.height / 2);
    
    CGContextScaleCTM (context, imageSize.width / cropFrame.size.width, imageSize.height / cropFrame.size.height);
    
    [source drawAtPoint:CGPointMake(-cropFrame.origin.x, -cropFrame.origin.y) blendMode:kCGBlendModeCopy alpha:1.0f];
    UIImage *croppedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return croppedImage;
}

UIImage *TGAttachmentImage(UIImage *source, CGSize sourceSize, CGSize size, __unused bool incoming, bool location)
{
    static UIImage *bubbleOverlay = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        UIImage *rawImage = [UIImage imageNamed:@"AttachmentPhotoBubble.png"];
        bubbleOverlay = [rawImage stretchableImageWithLeftCapWidth:(int)(rawImage.size.width / 2) topCapHeight:(int)(rawImage.size.height / 2)];
    });
    
    float scale = 1.0f;
    if (isRetina())
    {
        scale = 2.0f;
        size.width *= 2;
        size.height *= 2;
    }
    
    UIGraphicsBeginImageContextWithOptions(size, false, 1.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextSaveGState(context);
    
    CGContextBeginPath(context);
    CGRect rect = CGRectMake(2 * scale, 1.5f * scale, size.width - 4 * scale, size.height - (1.5f + 2) * scale);
    
    float radius = 8.0f * scale;
    
    CGContextMoveToPoint(context, rect.origin.x, rect.origin.y + radius);
    CGContextAddArcToPoint(context, rect.origin.x, rect.origin.y, rect.origin.x + radius, rect.origin.y, radius);
    CGContextAddLineToPoint(context, rect.origin.x + rect.size.width - radius, rect.origin.y);
    CGContextAddArcToPoint(context, rect.origin.x + rect.size.width, rect.origin.y, rect.origin.x + rect.size.width, rect.origin.y + radius, radius);
    CGContextAddLineToPoint(context, rect.origin.x + rect.size.width, rect.origin.y + rect.size.height - radius);
    CGContextAddArcToPoint(context, rect.origin.x + rect.size.width, rect.origin.y + rect.size.height, rect.origin.x + rect.size.width - radius, rect.origin.y + rect.size.height, radius);
    CGContextAddLineToPoint(context, rect.origin.x + radius, rect.origin.y + rect.size.height);
    CGContextAddArcToPoint(context, rect.origin.x, rect.origin.y + rect.size.height, rect.origin.x, rect.size.height - radius, radius);
    CGContextAddLineToPoint(context, rect.origin.x, rect.origin.y + radius);
    CGContextClosePath(context);
    CGContextClip(context);
    
    if (location)
        [source drawAtPoint:CGPointMake(0, 4) blendMode:kCGBlendModeCopy alpha:1.0f];
    else
    {
        //CGSize sourceSize = source.size;
        //float sourceScale = source.scale;
        //sourceSize.width *= sourceScale;
        //sourceSize.height *= sourceScale;
        
        sourceSize = TGFillSize(sourceSize, rect.size);
        rect.origin.x -= (sourceSize.width - rect.size.width) / 2;
        rect.size.width += sourceSize.width - rect.size.width;
        rect.origin.y -= (sourceSize.height - rect.size.height) / 2;
        rect.size.height += sourceSize.height - rect.size.height;
        [source drawInRect:rect blendMode:kCGBlendModeCopy alpha:1.0f];
    }
    
    //CGContextSetFillColorWithColor(context, [UIColor redColor].CGColor);
    //CGContextFillRect(context, CGRectMake(0, 0, size.width, size.height));
    
    CGContextRestoreGState(context);
    
    if (location)
    {
        static UIImage *markerImage = nil;
        static dispatch_once_t onceToken;
        static CGSize imageSize;
        dispatch_once(&onceToken, ^
        {
            markerImage = [UIImage imageNamed:@"MapThumbnailMarker.png"];
            imageSize = markerImage.size;
        });
        
        [markerImage drawInRect:CGRectMake(floorf((size.width - imageSize.width) / 2) - 4 * scale, floorf((size.height - imageSize.height) / 2) - 5 * scale, imageSize.width * scale, imageSize.height * scale)];
    }
    
    CGContextScaleCTM(context, scale, scale);
    
    [bubbleOverlay drawInRect:CGRectMake(0, 0, size.width / scale, size.height / scale) blendMode:kCGBlendModeNormal alpha:1.0f];
    
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return result;
}

static int32_t get_bits(uint8_t const *bytes, unsigned int bitOffset, unsigned int numBits)
{
    uint8_t const *data = bytes;
    numBits = (unsigned int)pow(2, numBits) - 1; //this will only work up to 32 bits, of course
    data += bitOffset / 8;
    bitOffset %= 8;
    return (*((int*)data) >> bitOffset) & numBits;
}

UIImage *TGIdenticonImage(NSData *data, CGSize size)
{
    //return [TGIdenticonDrawer drawIdenticon:data size:size.width];
    
    uint8_t bits[128];
    memset(bits, 0, 128);
    
    [data getBytes:bits length:MIN(128, data.length)];
    
    static CGColorRef colors[6];
    
    //int ptr = 0;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        static const int textColors[] =
        {
            0xffffff,
            0xd5e6f3,
            0x2d5775,
            0x2f99c9
        };
        
        for (int i = 0; i < 4; i++)
        {
            colors[i] = CGColorRetain(UIColorRGB(textColors[i]).CGColor);
        }
    });
    
    UIGraphicsBeginImageContextWithOptions(size, true, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    int bitPointer = 0;
    
    float rectSize = floorf(size.width / 8.0f);
    
    for (int iy = 0; iy < 8; iy++)
    {
        for (int ix = 0; ix < 8; ix++)
        {
            int32_t byteValue = get_bits(bits, bitPointer, 2);
            bitPointer += 2;
            int colorIndex = ABS(byteValue) % 4;
            
            //colorIndex = (ptr++) % 4;
            
            CGContextSetFillColorWithColor(context, colors[colorIndex]);
            CGContextFillRect(context, CGRectMake(ix * rectSize, iy * rectSize, rectSize, rectSize));
        }
    }
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

@implementation UIImage (Preloading)

- (UIImage *)preloadedImage
{
    UIGraphicsBeginImageContextWithOptions(self.size, false, 0);
    [self drawInRect:CGRectMake(0, 0, self.size.width, self.size.height)];
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result;
}

- (void)tgPreload
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(1, 1), true, 0);
    [self drawAtPoint:CGPointZero];
    UIGraphicsEndImageContext();
}

static const char *mediumImageKey = "mediumImage";

- (void)setMediumImage:(UIImage *)image
{
    objc_setAssociatedObject(self, mediumImageKey, image, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIImage *)mediumImage
{
    return (UIImage *)objc_getAssociatedObject(self, mediumImageKey);
}

- (CGSize)screenSize
{
    float scale = TGIsRetina() ? 2.0f : 1.0f;
    if (ABS(self.scale - 1.0) < FLT_EPSILON)
        return CGSizeMake(self.size.width / scale, self.size.height / scale);
    return self.size;
}

@end

CGSize TGFitSize(CGSize size, CGSize maxSize)
{
    if (size.width < 1)
        size.width = 1;
    if (size.height < 1)
        size.height = 1;
    
    if (size.width > maxSize.width)
    {
        size.height = floorf((size.height * maxSize.width / size.width));
        size.width = maxSize.width;
    }
    if (size.height > maxSize.height)
    {
        size.width = floorf((size.width * maxSize.height / size.height));
        size.height = maxSize.height;
    }
    return size;
}

CGSize TGFillSize(CGSize size, CGSize maxSize)
{
    if (size.width < 1)
        size.width = 1;
    if (size.height < 1)
        size.height = 1;
    
    if (/*size.width >= size.height && */size.width < maxSize.width)
    {
        size.height = floorf(maxSize.width * size.height / MAX(1.0f, size.width));
        size.width = maxSize.width;
    }
    
    if (/*size.width <= size.height &&*/ size.height < maxSize.height)
    {
        size.width = floorf(maxSize.height * size.width / MAX(1.0f, size.height));
        size.height = maxSize.height;
    }
    
    return size;
}

CGSize TGCropSize(CGSize size, CGSize maxSize)
{
    if (size.width < 1)
        size.width = 1;
    if (size.height < 1)
        size.height = 1;
    
    return CGSizeMake(MIN(size.width, maxSize.width), MIN(size.height, maxSize.height));
}

bool TGIsRetina()
{
    static bool value = true;
    static bool initialized = false;
    if (!initialized)
    {
        value = [[UIScreen mainScreen] scale] > 1.5f;
        initialized = true;
    }
    return value;
}
