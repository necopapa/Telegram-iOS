#import "TGIdenticonDrawer.h"

@implementation TGIdenticonDrawer

static void fillPoly(CGContextRef context, NSArray *path)
{
    if (path.count >= 2)
    {
        CGContextSaveGState(context);
        
        CGContextBeginPath(context);
        CGContextMoveToPoint(context, [path[0] floatValue], [path[1] floatValue]);
        for (int i = 2; i < (int)path.count; i += 2)
        {
            CGContextAddLineToPoint(context, [path[i] floatValue], [path[i + 1] floatValue]);
        }
        CGContextClosePath(context);
        CGContextFillPath(context);
        
        CGContextRestoreGState(context);
    }
}

static NSArray *getSprite(int shape, float size)
{
    NSMutableArray *result = nil;
    
    switch (shape)
    {
        case 0: // triangle
            result = [[NSMutableArray alloc] initWithArray:@[
                     @(0.5f), @(1.0f),
                     @(1.0f), @(0.0f),
                     @(1.0f), @(1.0f)]];
            break;
        case 1: // parallelogram
            result = [[NSMutableArray alloc] initWithArray:@[
                     @(0.5f), @(0.0f),
                     @(1.0f), @(0.0f),
                     @(0.5f), @(1.0f),
                     @(0.0f), @(1.0f)]];
            break;
        case 2: // mouse ears
            result = [[NSMutableArray alloc] initWithArray:@[
                     @(0.5f), @(0.0f),
                     @(1.0f), @(0.0f),
                     @(1.0f), @(1.0f),
                     @(0.5f), @(1.0f),
                     @(1.0f), @(0.5f)]];
            break;
        case 3: // ribbon
            result = [[NSMutableArray alloc] initWithArray:@[
                     @(0.0f), @(0.5f),
                     @(0.5f), @(0.0f),
                     @(1.0f), @(0.5f),
                     @(0.5f), @(1.0f),
                     @(0.5f), @(0.5f)]];
            break;
        case 4: // sails
            result = [[NSMutableArray alloc] initWithArray:@[
                     @(0.0f), @(0.5f),
                     @(1.0f), @(0.0f),
                     @(1.0f), @(1.0f),
                     @(0.0f), @(1.0f),
                     @(1.0f), @(0.5f)]];
            break;
        case 5: // fins
            result = [[NSMutableArray alloc] initWithArray:@[
                     @(1.0f), @(0.0f),
                     @(1.0f), @(1.0f),
                     @(0.5f), @(1.0f),
                     @(1.0f), @(0.5f),
                     @(0.5f), @(0.5f)]];
            break;
        case 6: // beak
            result = [[NSMutableArray alloc] initWithArray:@[
                     @(0.0f), @(0.0f),
                     @(1.0f), @(0.0f),
                     @(1.0f), @(0.5f),
                     @(0.0f), @(0.0f),
                     @(0.5f), @(1.0f),
                     @(0.0f), @(1.0f)]];
            break;
        case 7: // chevron
            result = [[NSMutableArray alloc] initWithArray:@[
                     @(0.0f), @(0.0f),
                     @(0.5f), @(0.0f),
                     @(1.0f), @(0.5f),
                     @(0.5f), @(1.0f),
                     @(0.0f), @(1.0f),
                     @(0.5f), @(0.5f)]];
            break;
        case 8: // fish
            result = [[NSMutableArray alloc] initWithArray:@[
                     @(0.5f), @(0.0f),
                     @(0.5f), @(0.5f),
                     @(1.0f), @(0.5f),
                     @(1.0f), @(1.0f),
                     @(0.5f), @(1.0f),
                     @(0.5f), @(0.5f),
                     @(0.0f), @(0.5f)]];
            break;
        case 9: // kite
            result = [[NSMutableArray alloc] initWithArray:@[
                     @(0.0f), @(0.0f),
                     @(1.0f), @(0.0f),
                     @(0.5f), @(0.5f),
                     @(1.0f), @(0.5f),
                     @(0.5f), @(1.0f),
                     @(0.5f), @(0.5f),
                     @(0.0f), @(1.0f)]];
            break;
        case 10: // trough
            result = [[NSMutableArray alloc] initWithArray:@[
                     @(0.0f), @(0.5f),
                     @(0.5f), @(1.0f),
                     @(1.0f), @(0.5f),
                     @(0.5f), @(0.0f),
                     @(1.0f), @(0.0f),
                     @(1.0f), @(1.0f),
                     @(0.0f), @(1.0f)]];
            break;
        case 11: // rays
            result = [[NSMutableArray alloc] initWithArray:@[
                     @(0.5f), @(0.0f),
                     @(1.0f), @(0.0f),
                     @(1.0f), @(1.0f),
                     @(0.5f), @(1.0f),
                     @(1.0f), @(0.75f),
                     @(0.5f), @(0.5f),
                     @(1.0f), @(0.25f)]];
            break;
        case 12: // double rhombus
            result = [[NSMutableArray alloc] initWithArray:@[
                     @(0.0f), @(0.5f),
                     @(0.5f), @(0.0f),
                     @(0.5f), @(0.5f),
                     @(1.0f), @(0.0f),
                     @(1.0f), @(0.5f),
                     @(0.5f), @(1.0f),
                     @(0.5f), @(0.5f),
                     @(0.0f), @(1.0f)]];
            break;
        case 13: // crown
            result = [[NSMutableArray alloc] initWithArray:@[
                     @(0.0f), @(0.0f),
                     @(1.0f), @(0.0f),
                     @(1.0f), @(1.0f),
                     @(0.0f), @(1.0f),
                     @(1.0f), @(0.5f),
                     @(0.5f), @(0.25f),
                     @(0.5f), @(0.75f),
                     @(0.0f), @(0.5f),
                     @(0.5f), @(0.25f)]];
            break;
        case 14: // radioactive
            result = [[NSMutableArray alloc] initWithArray:@[
                     @(0.0f), @(0.5f),
                     @(0.5f), @(0.5f),
                     @(0.5f), @(0.0f),
                     @(1.0f), @(0.0f),
                     @(0.5f), @(0.5f),
                     @(1.0f), @(0.5f),
                     @(0.5f), @(1.0f),
                     @(0.5f), @(0.5f),
                     @(0.0f), @(1.0f)]];
            break;
        default: // tiles
            result = [[NSMutableArray alloc] initWithArray:@[
                     @(0.0f), @(0.0f),
                     @(1.0f), @(0.0f),
                     @(0.5f), @(0.5f),
                     @(0.5f), @(0.0f),
                     @(0.0f), @(0.5f),
                     @(1.0f), @(0.5f),
                     @(0.5f), @(1.0f),
                     @(0.5f), @(0.5f),
                     @(0.0f), @(1.0f)]];
            break;
    }
    
    for (int i = 0; i < (int)result.count; i++)
    {
        result[i] = @([result[i] floatValue] * size);
    }
    
    return result;
}

static NSArray *getCenter(int shape, float size)
{
    NSMutableArray *result = nil;
    
    switch (shape)
    {
        case 0: // empty
            result = [[NSMutableArray alloc] initWithArray:@[]];
            break;
        case 1: // fill
            result = [[NSMutableArray alloc] initWithArray:@[
                     @(0.0f), @(0.0f),
                     @(1.0f), @(0.0f),
                     @(1.0f), @(1.0f),
                     @(0.0f), @(1.0f)]];
            break;
        case 2: // diamond
            result = [[NSMutableArray alloc] initWithArray:@[
                     @(0.5f), @(0.0f),
                     @(1.0f), @(0.5f),
                     @(0.5f), @(1.0f),
                     @(0.0f), @(0.5f)]];
            break;
        case 3: // reverse diamond
            result = [[NSMutableArray alloc] initWithArray:@[
                     @(0.0f), @(0.0f),
                     @(1.0f), @(0.0f),
                     @(1.0f), @(1.0f),
                     @(0.0f), @(1.0f),
                     @(0.0f), @(0.5f),
                     @(0.5f), @(1.0f),
                     @(1.0f), @(0.5f),
                     @(0.5f), @(0.0f),
                     @(0.0f), @(0.5f)]];
            break;
        case 4: // cross
            result = [[NSMutableArray alloc] initWithArray:@[
                     @(0.25f), @(0.0f),
                     @(0.75f), @(0.0f),
                     @(0.5f), @(0.5f),
                     @(1.0f), @(0.25f),
                     @(1.0f), @(0.75f),
                     @(0.5f), @(0.5f),
                     @(0.75f), @(1.0f),
                     @(0.25f), @(1.0f),
                     @(0.5f), @(0.5f),
                     @(0.0f), @(0.75f),
                     @(0.0f), @(0.25f),
                     @(0.5f), @(0.5f)]];
            break;
        case 5: // morning star
            result = [[NSMutableArray alloc] initWithArray:@[
                     @(0.0f), @(0.0f),
                     @(0.5f), @(0.25f),
                     @(1.0f), @(0.0f),
                     @(0.75f), @(0.5f),
                     @(1.0f), @(1.0f),
                     @(0.5f), @(0.75f),
                     @(0.0f), @(1.0f),
                     @(0.25f), @(0.5f)]];
            break;
        case 6: // small square
            result = [[NSMutableArray alloc] initWithArray:@[
                     @(0.33f), @(0.33f),
                     @(0.67f), @(0.33f),
                     @(0.67f), @(0.67f),
                     @(0.33f), @(0.67f)]];
            break;
        case 7: // checkerboard
            result = [[NSMutableArray alloc] initWithArray:@[
                     @(0.0f), @(0.0f),
                     @(0.33f), @(0.0f),
                     @(0.33f), @(0.33f),
                     @(0.66f), @(0.33f),
                     @(0.67f), @(0.0f),
                     @(1.0f), @(0.0f),
                     @(1.0f), @(0.33f),
                     @(0.67f), @(0.33f),
                     @(0.67f), @(0.67f),
                     @(1.0f), @(0.67f),
                     @(1.0f), @(1.0f),
                     @(0.67f), @(1.0f),
                     @(0.67f), @(0.67f),
                     @(0.33f), @(0.67f),
                     @(0.33f), @(1.0f),
                     @(0.0f), @(1.0f),
                     @(0.0f), @(0.67f),
                     @(0.33f), @(0.67f),
                     @(0.33f), @(0.33f),
                     @(0.0f), @(0.33f)]];
            break;
        default: // tiles
            result = [[NSMutableArray alloc] initWithArray:@[
                     @(0.0f), @(0.0f),
                     @(1.0f), @(0.0f),
                     @(0.5f), @(0.5f),
                     @(0.5f), @(0.0f),
                     @(0.0f), @(0.5f),
                     @(1.0f), @(0.5f),
                     @(0.5f), @(1.0f),
                     @(0.5f), @(0.5f),
                     @(0.0f), @(1.0f)]];
            break;
    }
    
    for (int i = 0; i < (int)result.count; i++)
    {
        result[i] = @([result[i] floatValue] * size);
    }
    
    return result;
}

static void drawRotatedPolygon(CGContextRef context, NSArray *sprite, float x, float y, float shapeAngle, float angle, float size)
{
    float halfSize = size / 2.0f;
    
    CGContextSaveGState(context);
    CGContextTranslateCTM(context, x, y);
    CGContextRotateCTM(context, (float)(angle * M_PI / 180.0f));
    
    CGContextTranslateCTM(context, halfSize, halfSize);
    NSMutableArray *tmpSprite = [[NSMutableArray alloc] init];
    for (int p = 0; p < (int)sprite.count; p++)
    {
        [tmpSprite addObject:@([sprite[p] floatValue] - halfSize)];
    }
    CGContextRotateCTM(context, shapeAngle);
    fillPoly(context, tmpSprite);
    CGContextRestoreGState(context);
}

static int32_t hexSubstring(NSString *string, int position, int length)
{
    unsigned int result = 0;
    NSScanner *scanner = [[NSScanner alloc] initWithString:[string substringWithRange:NSMakeRange(position, length)]];
    [scanner scanHexInt:&result];
    
    return (int32_t)result;
}

static void draw(CGContextRef context, NSString *hash, float width)
{
    int csh = hexSubstring(hash, 0, 1);
    int ssh = hexSubstring(hash, 1, 1);
    int xsh = hexSubstring(hash, 2, 1) & 7;
    
    float halfPi = (float)M_PI_2;
    float cro = halfPi * (hexSubstring(hash, 3, 1) & 3);
    float sro = halfPi * (hexSubstring(hash, 4, 1) & 3);
    int32_t xbg = hexSubstring(hash, 5, 1) & 2;
    
    float cfr = hexSubstring(hash, 6, 2) / 255.0f;
    float cfg = hexSubstring(hash, 8, 2) / 255.0f;
    float cfb = hexSubstring(hash, 10, 2) / 255.0f;
    
    float sfr = hexSubstring(hash, 12, 2) / 255.0f;
    float sfg = hexSubstring(hash, 14, 2) / 255.0f;
    float sfb = hexSubstring(hash, 16, 2) / 255.0f;
    
    float size = width / 3.0f;
    float totalSize = width;
    
    NSArray *corner = getSprite(csh, size);
    
    CGContextSetFillColorWithColor(context, [[UIColor alloc] initWithRed:cfr green:cfg blue:cfb alpha:1.0f].CGColor);
    
    drawRotatedPolygon(context, corner, 0, 0, cro, 0, size);
    drawRotatedPolygon(context, corner, totalSize, 0, cro, 90, size);
    drawRotatedPolygon(context, corner, totalSize, totalSize, cro, 180, size);
    drawRotatedPolygon(context, corner, 0, totalSize, cro, 270, size);
    
    NSArray *side = getSprite(ssh, size);
    
    CGContextSetFillColorWithColor(context, [[UIColor alloc] initWithRed:sfr green:sfg blue:sfb alpha:1.0f].CGColor);
    
    drawRotatedPolygon(context, side, 0, size, sro, 0, size);
    drawRotatedPolygon(context, side, 2.0f * size, 0, sro, 90, size);
    drawRotatedPolygon(context, side, 3.0f * size, 2.0f * size, sro, 180, size);
    drawRotatedPolygon(context, side, size, 3 * size, sro, 270, size);
    
    NSArray *center = getCenter(xsh, size);
    
    if (xbg > 0 && (ABS(cfr - sfr) > 0.5f || ABS(cfg - sfg) > 0.5f || ABS(cfb - sfb) > 0.5f))
    {
        CGContextSetFillColorWithColor(context, [[UIColor alloc] initWithRed:sfr green:sfg blue:sfb alpha:1.0f].CGColor);
    }
    else
    {
        CGContextSetFillColorWithColor(context, [[UIColor alloc] initWithRed:cfr green:cfg blue:cfb alpha:1.0f].CGColor);
    }
    
    drawRotatedPolygon(context, center, size, size, 0, 0, size);
}

+ (UIImage *)drawIdenticon:(NSData *)hash size:(float)size
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), true, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
    CGContextFillRect(context, CGRectMake(0, 0, size, size));
    
    if (size < 100.0f)
    {
        uint8_t const *md5Buffer = hash.bytes;
        NSString *hashString = [[NSString alloc] initWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x", md5Buffer[0], md5Buffer[1], md5Buffer[2], md5Buffer[3], md5Buffer[4], md5Buffer[5], md5Buffer[6], md5Buffer[7], md5Buffer[8], md5Buffer[9], md5Buffer[10], md5Buffer[11], md5Buffer[12], md5Buffer[13], md5Buffer[14], md5Buffer[15]];
        
        draw(context, hashString, size);
    }
    else
    {
        float padding = size < 100.0f ? 0.0f : 2.0f;
        
        for (int i = 0; i < 4; i++)
        {
            uint8_t const *md5Buffer = hash.bytes + 9 * i;
            NSString *hashString = [[NSString alloc] initWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x", md5Buffer[0], md5Buffer[1], md5Buffer[2], md5Buffer[3], md5Buffer[4], md5Buffer[5], md5Buffer[6], md5Buffer[7], md5Buffer[8], md5Buffer[9], md5Buffer[10], md5Buffer[11], md5Buffer[12], md5Buffer[13], md5Buffer[14], md5Buffer[15]];
            
            CGContextSaveGState(context);
            float offsetX = (i % 2 == 0) ? padding : (size / 2.0f + padding);
            float offsetY = (i / 2 == 0) ? padding : (size / 2.0f + padding);
            
            CGContextTranslateCTM(context, offsetX, offsetY);
            draw(context, hashString, size / 2.0f - padding * 2.0f);
            CGContextRestoreGState(context);
        }
    }
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

@end
