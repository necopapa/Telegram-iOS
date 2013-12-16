#import "TGTelegraphConversationMessageAssetsSource.h"

#import "TGImageUtils.h"
#import "TGInterfaceAssets.h"

#import "TGTelegraph.h"

#import "TGViewController.h"

int TGBaseFontSize = 16;

@implementation TGTelegraphConversationMessageAssetsSource

+ (TGTelegraphConversationMessageAssetsSource *)instance
{
    static TGTelegraphConversationMessageAssetsSource *singleton = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        singleton = [[TGTelegraphConversationMessageAssetsSource alloc] init];
    });
    
    return singleton;
}

- (int)currentUserId
{
    return TGTelegraphInstance.clientUserId;
}

- (CTFontRef)messageTextFont
{
    static CTFontRef font = nil;
    static int fontSize = 0;
    
    if (font == nil || fontSize != TGBaseFontSize)
    {
        if (font != nil)
            CFRelease(font);
        
        TGLog(@"===== Creating base font");
        
        fontSize = TGBaseFontSize;
        font = CTFontCreateWithName(CFSTR("Helvetica"), TGBaseFontSize, NULL);
    }
    
    return font;
}

- (CTFontRef)messageActionTitleFont
{
    static CTFontRef font = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        font = CFRetain(CTFontCreateWithName(CFSTR("Helvetica-Bold"), 13, NULL));
    });
    
    return font;
}

- (CTFontRef)messageActionSubtitleFont
{
    static CTFontRef font = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        font = CFRetain(CTFontCreateWithName(CFSTR("Helvetica"), 13, NULL));
    });
    
    return font;
}

- (CTFontRef)messageRequestActionFont
{
    static CTFontRef font = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        font = CFRetain(CTFontCreateWithName(CFSTR("Helvetica"), 13, NULL));
    });
    
    return font;
}

- (CTFontRef)messagerequestActorBoldFont
{
    static CTFontRef font = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        font = CFRetain(CTFontCreateWithName(CFSTR("Helvetica-Bold"), 13, NULL));
    });
    
    return font;
}

- (CTFontRef)messageForwardTitleFont
{
    static CTFontRef font = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        font = CFRetain(CTFontCreateWithName(CFSTR("Helvetica"), 13, NULL));
    });
    
    return font;
}

- (CTFontRef)messageForwardNameFont
{
    static CTFontRef font = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        font = CFRetain(CTFontCreateWithName(CFSTR("Helvetica-Bold"), 13, NULL));
    });
    
    return font;
}

- (CTFontRef)messageForwardPhoneFont
{
    return [self messageForwardTitleFont];
}

- (UIFont *)messageLineAttachmentTitleFont
{
    static UIFont *font = nil;
    if (font == nil)
        font = [UIFont boldSystemFontOfSize:15];
    return font;
}

- (UIFont *)messageLineAttachmentSubtitleFont
{
    static UIFont *font = nil;
    if (font == nil)
        font = [UIFont systemFontOfSize:15];
    return font;
}

- (UIFont *)messageDocumentLabelFont
{
    static UIFont *font = nil;
    if (font == nil)
        font = [UIFont systemFontOfSize:10];
    return font;
}
- (UIFont *)messageForwardedUserFont
{
    static UIFont *font = nil;
    if (font == nil)
        font = [UIFont boldSystemFontOfSize:13];
    return font;
}


- (UIFont *)messageForwardedDateFont
{
    static UIFont *font = nil;
    if (font == nil)
        font = [UIFont systemFontOfSize:10];
    return font;
}

- (UIColor *)messageTextColor
{
    static UIColor *color = nil;
    if (color == nil)
        color = [UIColor colorWithRed:(20.0f / 255.0f) green:(22.0f / 255.0f) blue:(23.0f / 255.0f) alpha:1.0f];
    return color;
}

- (UIColor *)messageTextShadowColor
{
    return nil;
    
    /*static UIColor *color = nil;
    if (color == nil)
        color = UIColorRGBA(0xffffff, 0.5f);
    return color;*/
}

- (UIColor *)messageLineAttachmentTitleColor
{
    static UIColor *color = nil;
    if (color == nil)
        color = UIColorRGB(0x62768a);
    return color;
}

- (UIColor *)messageLineAttachmentSubitleColor
{
    static UIColor *color = nil;
    if (color == nil)
        color = UIColorRGB(0x72879b);
    return color;
}

- (UIColor *)messageDocumentLabelColor
{
    static UIColor *color = nil;
    if (color == nil)
        color = UIColorRGB(0xffffff);
    return color;
}

- (UIColor *)messageDocumentLabelShadowColor
{
    static UIColor *color = nil;
    if (color == nil)
        color = UIColorRGB(0x111111);
    return color;
}

- (UIColor *)messageForwardedUserColor
{
    static UIColor *color = nil;
    if (color == nil)
        color = [UIColor colorWithRed:(20.0f / 255.0f) green:(22.0f / 255.0f) blue:(23.0f / 255.0f) alpha:1.0f];
    return color;
}

- (UIColor *)messageForwardedDateColor
{
    static UIColor *color = nil;
    if (color == nil)
        color = UIColorRGB(0x999999);
    return color;
}

- (UIColor *)messageForwardTitleColorIncoming
{
    static UIColor *color = nil;
    if (color == nil)
        color = UIColorRGB(0x0e7acd);
    return color;
}

- (UIColor *)messageForwardTitleColorOutgoing
{
    static UIColor *color = nil;
    if (color == nil)
        color = UIColorRGB(0x3a8e26);
    return color;
}

- (UIColor *)messageForwardNameColorIncoming
{
    static UIColor *color = nil;
    if (color == nil)
        color = UIColorRGB(0x0e7acd);
    return color;
}

- (UIColor *)messageForwardNameColorOutgoing
{
    static UIColor *color = nil;
    if (color == nil)
        color = UIColorRGB(0x169600);
    return color;
}

- (UIColor *)messageForwardPhoneColor
{
    static UIColor *color = nil;
    if (color == nil)
        color = UIColorRGB(010101);
    return color;
}

- (UIImage *)messageInlineGenericAvatarPlaceholder
{
    return [UIImage imageNamed:@"InlineAvatarPlaceholder.png"];
}

- (UIImage *)messageInlineAvatarPlaceholder:(int)uid
{
    return [[TGInterfaceAssets instance] smallAvatarPlaceholder:uid];
}

- (UIColor *)messageActionTextColor
{
    static UIColor *color = nil;
    if (color == nil)
        color = [UIColor whiteColor];
    return color;
}

- (UIColor *)messageActionShadowColor
{
    return nil;
    
    /*if (_monochromeColor != -1)
    {
        static UIColor *color = nil;
        if (color == nil)
            color = UIColorRGBA(_monochromeColor, 0.15f);
        return color;
    }
    else
    {
        static UIColor *color = nil;
        if (color == nil)
            color = UIColorRGBA(0x5e7590, 0.2f);
        return color;
    }*/
}

- (UIImage *)messageVideoIcon
{
    return [UIImage imageNamed:@"MessageInlineVideoIcon.png"];
}

- (CTFontRef)messageAuthorNameFont
{
    static CTFontRef font = nil;
    if (font == nil)
        font = CFRetain(CTFontCreateWithName(CFSTR("Helvetica-Bold"), 13, NULL));
    return font;
}

- (UIFont *)messageAuthorNameUIFont
{
    static UIFont *font = nil;
    if (font == nil)
        font = [UIFont boldSystemFontOfSize:13];
    return font;
}

- (UIColor *)messageAuthorNameColor
{
    static UIColor *color = nil;
    if (color == nil)
        color = UIColorRGB(0x4d688c);
    return color;
}

- (UIColor *)messageAuthorNameShadowColor
{
    return nil;
    
    /*static UIColor *color = nil;
    if (color == nil)
        color = UIColorRGBA(0xffffff, 0.5f);
    return color;*/
}

- (UIImage *)messageChecked
{
    static UIImage *image = nil;
    if (image == nil)
        image = [UIImage imageNamed:@"MessagesChecked.png"];
    return image;
}

- (UIImage *)messageUnchecked
{
    static UIImage *image = nil;
    if (image == nil)
        image = [UIImage imageNamed:@"MessagesUnchecked.png"];
    return image;
}

- (UIImage *)messageEditingSeparator
{
    static UIImage *image = nil;
    if (image == nil)
        image = [UIImage imageNamed:@"MessagesEditingSeparator.png"];
    return image;
}

- (UIImage *)messageProgressBackground
{
    if (_monochromeColor != -1)
    {
        static int cachedImageColor = -1;
        static UIImage *image = nil;
        if (cachedImageColor != _monochromeColor || image == nil)
        {
            NSArray *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
            NSString *assetsPath = [[NSString alloc] initWithFormat:@"%@/assets/", documentsPath];
            [[NSFileManager defaultManager] createDirectoryAtPath:assetsPath withIntermediateDirectories:true attributes:nil error:nil];
            NSString *filePath = [[NSString alloc] initWithFormat:@"%@/messageProgressBackground_%x%@.png", assetsPath, _monochromeColor, TGIsRetina() ? @"@2x" : @""];
            
            UIImage *rawImage = [UIImage imageWithContentsOfFile:filePath];
            if (rawImage == nil)
            {
                TGLog(@"Generating progress background");
                
                rawImage = [self generateInlineUploadBackground:_monochromeColor];
                [UIImagePNGRepresentation(rawImage) writeToFile:filePath atomically:false];
            }
            
            image = [rawImage stretchableImageWithLeftCapWidth:(int)(rawImage.size.width / 2) topCapHeight:0];
            
            cachedImageColor = _monochromeColor;
        }
        return image;
    }
    else
    {
        static UIImage *image = nil;
        if (image == nil)
        {
            UIImage *rawImage = [UIImage imageNamed:@"InlineUploadBackground.png"];
            image = [rawImage stretchableImageWithLeftCapWidth:(int)(rawImage.size.width / 2) topCapHeight:0];
        }
        return image;
    }
}

- (UIImage *)generateInlineUploadBackground:(int)baseColor
{
    float backgroundAlpha = 0.4f;
    float shadowAlpha = 0.45f;
    
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(13, 13), false, 0.0f);
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGRect bounds = CGRectMake(0.5f, 0, 12, 12);
    
    CGFloat radius = 0.5f * CGRectGetHeight(bounds);
    
    CGMutablePathRef visiblePath = CGPathCreateMutable();
    CGRect innerRect = CGRectInset(bounds, radius, radius);
    CGPathMoveToPoint(visiblePath, NULL, innerRect.origin.x, bounds.origin.y);
    CGPathAddLineToPoint(visiblePath, NULL, innerRect.origin.x + innerRect.size.width, bounds.origin.y);
    CGPathAddArcToPoint(visiblePath, NULL, bounds.origin.x + bounds.size.width, bounds.origin.y, bounds.origin.x + bounds.size.width, innerRect.origin.y, radius);
    CGPathAddLineToPoint(visiblePath, NULL, bounds.origin.x + bounds.size.width, innerRect.origin.y + innerRect.size.height);
    CGPathAddArcToPoint(visiblePath, NULL,  bounds.origin.x + bounds.size.width, bounds.origin.y + bounds.size.height, innerRect.origin.x + innerRect.size.width, bounds.origin.y + bounds.size.height, radius);
    CGPathAddLineToPoint(visiblePath, NULL, innerRect.origin.x, bounds.origin.y + bounds.size.height);
    CGPathAddArcToPoint(visiblePath, NULL,  bounds.origin.x, bounds.origin.y + bounds.size.height, bounds.origin.x, innerRect.origin.y + innerRect.size.height, radius);
    CGPathAddLineToPoint(visiblePath, NULL, bounds.origin.x, innerRect.origin.y);
    CGPathAddArcToPoint(visiblePath, NULL,  bounds.origin.x, bounds.origin.y, innerRect.origin.x, bounds.origin.y, radius);
    CGPathCloseSubpath(visiblePath);
    
    CGContextSaveGState(context);
    UIColor *aColor = UIColorRGBA(0xffffff, 0.3f);
    CGContextSetShadowWithColor(context, CGSizeMake(0.0f, 1.0f), 1.0f, [aColor CGColor]);
    
    // Fill this path
    aColor = UIColorRGBA(baseColor, backgroundAlpha);
    [aColor setFill];
    CGContextAddPath(context, visiblePath);
    CGContextFillPath(context);
    CGContextRestoreGState(context);
    
    // Now create a larger rectangle, which we're going to subtract the visible path from
    // and apply a shadow
    CGMutablePathRef path = CGPathCreateMutable();
    //(when drawing the shadow for a path whichs bounding box is not known pass "CGPathGetPathBoundingBox(visiblePath)" instead of "bounds" in the following line:)
    //-42 cuould just be any offset > 0
    CGPathAddRect(path, NULL, CGRectInset(bounds, -2, -2));
    
    // Add the visible path (so that it gets subtracted for the shadow)
    CGPathAddPath(path, NULL, visiblePath);
    CGPathCloseSubpath(path);
    
    // Add the visible paths as the clipping path to the context
    CGContextAddPath(context, visiblePath);
    CGContextClip(context);
    
    // Now setup the shadow properties on the context
    aColor = UIColorRGBA(baseColor, shadowAlpha);
    CGContextSaveGState(context);
    CGContextSetShadowWithColor(context, CGSizeMake(0.0f, 1.0f), 1.0f, [aColor CGColor]);
    
    // Now fill the rectangle, so the shadow gets drawn
    [aColor setFill];
    //CGContextSaveGState(context);
    CGContextAddPath(context, path);
    CGContextEOFillPath(context);
    CGContextRestoreGState(context);
    
    // Release the paths
    CGPathRelease(path);
    CGPathRelease(visiblePath);
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

- (UIImage *)messageProgressForeground
{
    static UIImage *image = nil;
    if (image == nil)
    {
        UIImage *rawImage = [UIImage imageNamed:@"InlineUploadForeground.png"];
        image = [rawImage stretchableImageWithLeftCapWidth:(int)(rawImage.size.width / 2) topCapHeight:0];
    }
    return image;
}

- (UIImage *)messageProgressCancelButton
{
    if (_monochromeColor != -1)
    {
        static int cachedImageColor = -1;
        static UIImage *image = nil;
        if (cachedImageColor != _monochromeColor || image == nil)
        {
            NSArray *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
            NSString *assetsPath = [[NSString alloc] initWithFormat:@"%@/assets/", documentsPath];
            [[NSFileManager defaultManager] createDirectoryAtPath:assetsPath withIntermediateDirectories:true attributes:nil error:nil];
            NSString *filePath = [[NSString alloc] initWithFormat:@"%@/messageProgressCancel_%x%@.png", assetsPath, _monochromeColor, TGIsRetina() ? @"@2x" : @""];
            
            UIImage *rawImage = [UIImage imageWithContentsOfFile:filePath];
            if (rawImage == nil)
            {
                TGLog(@"Generating progress cancel background");
                
                rawImage = [self generateInlineCancelButton:_monochromeColor alphaFactor:1.0f];
                [UIImagePNGRepresentation(rawImage) writeToFile:filePath atomically:false];
            }
            
            image = [rawImage stretchableImageWithLeftCapWidth:(int)(rawImage.size.width / 2) topCapHeight:0];
            
            cachedImageColor = _monochromeColor;
        }
        return image;
    }
    else
    {
        static UIImage *image = nil;
        if (image == nil)
            image = [UIImage imageNamed:@"InlineUploadCancel.png"];
        return image;
    }
}

- (UIImage *)generateInlineCancelButton:(int)baseColor alphaFactor:(float)alphaFactor
{
    float backgroundAlpha = 0.4f * alphaFactor;
    float shadowAlpha = 0.2f * alphaFactor;
    
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(21, 21), false, 0.0f);
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGRect bounds = CGRectMake(1, 0, 20, 20);
    
    CGFloat radius = 0.5f * CGRectGetHeight(bounds);
    
    CGMutablePathRef visiblePath = CGPathCreateMutable();
    CGRect innerRect = CGRectInset(bounds, radius, radius);
    CGPathMoveToPoint(visiblePath, NULL, innerRect.origin.x, bounds.origin.y);
    CGPathAddLineToPoint(visiblePath, NULL, innerRect.origin.x + innerRect.size.width, bounds.origin.y);
    CGPathAddArcToPoint(visiblePath, NULL, bounds.origin.x + bounds.size.width, bounds.origin.y, bounds.origin.x + bounds.size.width, innerRect.origin.y, radius);
    CGPathAddLineToPoint(visiblePath, NULL, bounds.origin.x + bounds.size.width, innerRect.origin.y + innerRect.size.height);
    CGPathAddArcToPoint(visiblePath, NULL,  bounds.origin.x + bounds.size.width, bounds.origin.y + bounds.size.height, innerRect.origin.x + innerRect.size.width, bounds.origin.y + bounds.size.height, radius);
    CGPathAddLineToPoint(visiblePath, NULL, innerRect.origin.x, bounds.origin.y + bounds.size.height);
    CGPathAddArcToPoint(visiblePath, NULL,  bounds.origin.x, bounds.origin.y + bounds.size.height, bounds.origin.x, innerRect.origin.y + innerRect.size.height, radius);
    CGPathAddLineToPoint(visiblePath, NULL, bounds.origin.x, innerRect.origin.y);
    CGPathAddArcToPoint(visiblePath, NULL,  bounds.origin.x, bounds.origin.y, innerRect.origin.x, bounds.origin.y, radius);
    CGPathCloseSubpath(visiblePath);
    
    CGContextSaveGState(context);
    
    UIColor *color = UIColorRGBA(0xffffff, 0.3f * alphaFactor);
    CGContextSetShadowWithColor(context, CGSizeMake(0.0f, 1.0f), 1.0f, [color CGColor]);
    
    color = UIColorRGBA(baseColor, backgroundAlpha);
    [color setFill];
    CGContextAddPath(context, visiblePath);
    CGContextFillPath(context);
    
    CGContextRestoreGState(context);
    
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathAddRect(path, NULL, CGRectInset(bounds, -2, -2));
    
    CGPathAddPath(path, NULL, visiblePath);
    CGPathCloseSubpath(path);
    
    CGContextAddPath(context, visiblePath);
    CGContextClip(context);
    
    CGContextSaveGState(context);
    
    color = UIColorRGBA(baseColor, shadowAlpha);
    CGContextSetShadowWithColor(context, CGSizeMake(0.0f, 1.0f), 0.0f, [color CGColor]);
    
    [color setFill];
    CGContextAddPath(context, path);
    CGContextEOFillPath(context);
    
    CGContextRestoreGState(context);
    
    [[UIImage imageNamed:@"InlineUploadCancelCross.png"] drawAtPoint:CGPointMake(6, 5) blendMode:kCGBlendModeNormal alpha:1.0f];
    
    CGPathRelease(path);
    CGPathRelease(visiblePath);
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

- (UIImage *)messageProgressCancelButtonHighlighted
{
    if (_monochromeColor != -1)
    {
        static int cachedImageColor = -1;
        static UIImage *image = nil;
        if (cachedImageColor != _monochromeColor || image == nil)
        {
            TGLog(@"Generating progress cancel background");
            
            NSArray *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
            NSString *assetsPath = [[NSString alloc] initWithFormat:@"%@/assets/", documentsPath];
            [[NSFileManager defaultManager] createDirectoryAtPath:assetsPath withIntermediateDirectories:true attributes:nil error:nil];
            NSString *filePath = [[NSString alloc] initWithFormat:@"%@/messageProgressCancel_Highlighted%x%@.png", assetsPath, _monochromeColor, TGIsRetina() ? @"@2x" : @""];
            
            UIImage *rawImage = [UIImage imageWithContentsOfFile:filePath];
            if (rawImage == nil)
            {
                rawImage = [self generateInlineCancelButton:_monochromeColor alphaFactor:1.4f];
                [UIImagePNGRepresentation(rawImage) writeToFile:filePath atomically:false];
            }
            
            image = [rawImage stretchableImageWithLeftCapWidth:(int)(rawImage.size.width / 2) topCapHeight:0];
            
            cachedImageColor = _monochromeColor;
        }
        return image;
    }
    else
    {
        static UIImage *image = nil;
        if (image == nil)
            image = [UIImage imageNamed:@"InlineUploadCancel_Highlighted.png"];
        return image;
    }
}

- (UIImage *)messageBackgroundBubbleIncomingSingle
{
    static UIImage *image = nil;
    if (image == nil)
        image = [[UIImage imageNamed:@"Msg_In.png"] stretchableImageWithLeftCapWidth:20 topCapHeight:15];
    return image;
}

- (UIImage *)messageBackgroundBubbleIncomingDouble
{
    static UIImage *image = nil;
    if (image == nil)
    {
        UIImage *rawImage = [UIImage imageNamed:@"Msg_In_High.png"];
        if ([rawImage respondsToSelector:@selector(resizableImageWithCapInsets:resizingMode:)])
        {
            image = [rawImage resizableImageWithCapInsets:UIEdgeInsetsMake(15, 23, 15, rawImage.size.width - 23 - 1) resizingMode:UIImageResizingModeStretch];
        }
        else
        {
            image = rawImage;
            //image = [self messageBackgroundBubbleIncomingSingle];
        }
    }
    return image;
}

- (UIImage *)messageBackgroundBubbleIncomingHighlighted
{
    static UIImage *image = nil;
    if (image == nil)
    {
        UIImage *rawImage = [UIImage imageNamed:@"Msg_In_Selected.png"];
        image = [rawImage stretchableImageWithLeftCapWidth:20 topCapHeight:15];
    }
    return image;
}
    
- (UIImage *)messageBackgroundBubbleIncomingHighlightedShadow
{
    static UIImage *image = nil;
    if (image == nil)
    {
        UIImage *rawImage = [UIImage imageNamed:@"Msg_In_Selected_Shadow.png"];
        image = [rawImage stretchableImageWithLeftCapWidth:20 topCapHeight:15];
    }
    return image;
}

- (UIImage *)messageBackgroundBubbleIncomingDoubleHighlighted
{
    static UIImage *image = nil;
    if (image == nil)
    {
        UIImage *rawImage = [UIImage imageNamed:@"Msg_In_High_Selected.png"];
        if ([rawImage respondsToSelector:@selector(resizableImageWithCapInsets:resizingMode:)])
        {
            image = [rawImage resizableImageWithCapInsets:UIEdgeInsetsMake(15, 23, 15, rawImage.size.width - 23 - 1) resizingMode:UIImageResizingModeStretch];
        }
        else
        {
            image = rawImage;
            //image = [self messageBackgroundBubbleIncomingSingle];
        }
    }
    return image;
}

- (UIImage *)messageBackgroundBubbleOutgoingSingle
{
    static UIImage *image = nil;
    if (image == nil)
    {
        image = [[UIImage imageNamed:@"Msg_Out.png"] stretchableImageWithLeftCapWidth:15 topCapHeight:15];
    }
    return image;
}

- (UIImage *)messageBackgroundBubbleOutgoingDouble
{
    static UIImage *image = nil;
    if (image == nil)
    {
        UIImage *rawImage = [UIImage imageNamed:@"Msg_Out_High.png"];
        if ([rawImage respondsToSelector:@selector(resizableImageWithCapInsets:resizingMode:)])
        {
            image = [rawImage resizableImageWithCapInsets:UIEdgeInsetsMake(15, 17, 15, rawImage.size.width - 17 - 1) resizingMode:UIImageResizingModeStretch];
        }
        else
        {
            image = rawImage;
            //image = [self messageBackgroundBubbleOutgoingSingle];
        }
    }
    return image;
}

- (UIImage *)messageBackgroundBubbleOutgoingHighlighted
{
    static UIImage *image = nil;
    if (image == nil)
    {
        UIImage *rawImage = [UIImage imageNamed:@"Msg_Out_Selected.png"];
        //if ([rawImage respondsToSelector:@selector(resizableImageWithCapInsets:resizingMode:)])
        //    image = [rawImage resizableImageWithCapInsets:UIEdgeInsetsMake(14, 16, 15, rawImage.size.width - 16) resizingMode:UIImageResizingModeStretch];
        //else
            image = [rawImage stretchableImageWithLeftCapWidth:15 topCapHeight:15];
    }
    return image;
}
    
- (UIImage *)messageBackgroundBubbleOutgoingHighlightedShadow
{
    static UIImage *image = nil;
    if (image == nil)
    {
        UIImage *rawImage = [UIImage imageNamed:@"Msg_Out_Selected_Shadow.png"];
        image = [rawImage stretchableImageWithLeftCapWidth:15 topCapHeight:15];
    }
    return image;
}

- (UIImage *)messageBackgroundBubbleOutgoingDoubleHighlighted
{
    static UIImage *image = nil;
    if (image == nil)
    {
        UIImage *rawImage = [UIImage imageNamed:@"Msg_Out_High_Selected.png"];
        if ([rawImage respondsToSelector:@selector(resizableImageWithCapInsets:resizingMode:)])
        {
            image = [rawImage resizableImageWithCapInsets:UIEdgeInsetsMake(15, 17, 15, rawImage.size.width - 17 - 1) resizingMode:UIImageResizingModeStretch];
        }
        else
        {
            image = rawImage;
            //image = [self messageBackgroundBubbleOutgoingSingle];
        }
    }
    return image;
}

- (UIImage *)messageDateBadgeOutgoing
{
    static UIImage *image = nil;
    if (image == nil)
    {
        UIImage *rawImage = [UIImage imageNamed:@"MessageTimestampBackground.png"];
        image = [rawImage stretchableImageWithLeftCapWidth:(int)(rawImage.size.width / 2) topCapHeight:0];
    }
    return image;
}

- (UIImage *)messageDateBadgeIncoming
{
    static UIImage *image = nil;
    if (image == nil)
    {
        UIImage *rawImage = [UIImage imageNamed:@"MessageTimestampBackgroundIncoming.png"];
        image = [rawImage stretchableImageWithLeftCapWidth:(int)(rawImage.size.width / 2) topCapHeight:0];
    }
    return image;
}

- (UIImage *)messageUnsentBadge
{
    static UIImage *image = nil;
    if (image == nil)
    {
        UIImage *rawImage = [UIImage imageNamed:@"MessageTimestampErrorBackground.png"];
        UIImage *backgroundImage = [rawImage stretchableImageWithLeftCapWidth:(int)(rawImage.size.width / 2) topCapHeight:0];
        
        UIFont *font = [UIFont boldSystemFontOfSize:11 + (TGIsRetina() ? 0.5f : 0.0f)];
        CGSize size = [TGLocalized(@"Conversation.Unsent") sizeWithFont:font];
        size.width = (int)size.width + 15;
        size.height = backgroundImage.size.height;
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0f);
        
        [backgroundImage drawInRect:CGRectMake(0, 0, size.width, size.height) blendMode:kCGBlendModeCopy alpha:1.0f];
        
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextSetShadowWithColor(context, CGSizeMake(0, -1), 0.0f, UIColorRGB(0xcc1e2c).CGColor);
        CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
        
        [TGLocalized(@"Conversation.Unsent") drawInRect:CGRectMake(6, 3, size.width, size.height) withFont:font];
        
        image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }
    return image;
}

- (UIImage *)messageDocumentLabelBackground
{
    static UIImage *image = nil;
    if (image == nil)
        image = [[UIImage imageNamed:@"DocumentLabelBg.png"] stretchableImageWithLeftCapWidth:8 topCapHeight:1];
    return image;
}

- (UIImage *)messageForwardedStripe
{
    static UIImage *image = nil;
    if (image == nil)
        image = [[UIImage imageNamed:@"AttachedMessageBackground.png"] stretchableImageWithLeftCapWidth:10 topCapHeight:5];
    return image;
}

- (UIImage *)messageCheckmarkFullIcon
{
    static UIImage *image = nil;
    if (image == nil)
        image = [UIImage imageNamed:@"MessageCheckFull.png"];
    return image;
}

- (UIImage *)messageCheckmarkHalfIcon
{
    static UIImage *image = nil;
    if (image == nil)
        image = [UIImage imageNamed:@"MessageCheckHalf.png"];
    return image;
}

- (UIImage *)messageNotSentIcon
{
    static UIImage *image = nil;
    if (image == nil)
        image = [UIImage imageNamed:@"NotSent.png"];
    return image;
}

- (UIColor *)messageBackgroundColorNormal
{
    static UIColor *color = nil;
    if (color == nil)
        color = [UIColor clearColor];
    return color;
}

- (UIColor *)messageBackgroundColorUnread
{
    static UIColor *color = nil;
    if (color == nil)
        color = UIColorRGBA(0x003871, 0.07f);
    return color;
}

- (UIFont *)messageDateFont
{
    static UIFont *font = nil;
    if (font == nil)
        font = [UIFont systemFontOfSize:11.0f];
    return font;
}

- (UIFont *)messageDateAMPMFont
{
    static UIFont *font = nil;
    if (font == nil)
        font = [UIFont systemFontOfSize:9.0f];
    return font;
}

- (UIColor *)messageDateColor
{
    static UIColor *color = nil;
    if (color == nil)
        color = UIColorRGB(0x232d37);
    return color;
}

- (UIColor *)messageDateShadowColor
{
    return nil;
}

- (UIImage *)messageLinkFull
{
    static UIImage *image = nil;
    if (image == nil)
    {
        UIImage *rawImage = [UIImage imageNamed:@"LinkFull.png"];
        image = [rawImage stretchableImageWithLeftCapWidth:(int)(rawImage.size.width / 2) topCapHeight:(int)(rawImage.size.height / 2)];
    }
    return image;
}

- (UIImage *)messageLinkCornerTB
{
    static UIImage *image = nil;
    if (image == nil)
    {
        image = [UIImage imageNamed:@"LinkCornerTB.png"];
    }
    return image;
}

- (UIImage *)messageLinkCornerBT
{
    static UIImage *image = nil;
    if (image == nil)
    {
        image = [UIImage imageNamed:@"LinkCornerBT.png"];
    }
    return image;
}

- (UIImage *)messageLinkCornerLR
{
    static UIImage *image = nil;
    if (image == nil)
    {
        image = [UIImage imageNamed:@"LinkCornerLR.png"];
    }
    return image;
}

- (UIImage *)messageLinkCornerRL
{
    static UIImage *image = nil;
    if (image == nil)
    {
        image = [UIImage imageNamed:@"LinkCornerRL.png"];
    }
    return image;
}

- (UIImage *)messageAvatarPlaceholder:(int)uid
{
    return [TGInterfaceAssets conversationAvatarPlaceholder:uid];
}

- (UIImage *)messageGenericAvatarPlaceholder
{
    return [TGInterfaceAssets conversationGenericAvatarPlaceholder:_monochromeColor != -1];
}

- (UIImage *)messageAttachmentImagePlaceholderIncoming
{
    return [self messageAttachmentImagePlaceholderOutgoing];
}

- (UIImage *)messageAttachmentImagePlaceholderOutgoing
{
    static UIImage *image = nil;
    if (image == nil)
    {
        UIImage *rawImage = [UIImage imageNamed:@"AttachmentPhotoBubblePlaceholder.png"];
        image = [rawImage stretchableImageWithLeftCapWidth:(int)(rawImage.size.width / 2) topCapHeight:(int)(rawImage.size.height / 2)];
    }
    return image;
}

- (UIImage *)messageAttachmentImageIncomingTopCorners
{
    static UIImage *image = nil;
    if (image == nil)
    {
        UIImage *rawImage = [UIImage imageNamed:@"AttachmentCornersIncomingTop.png"];
        image = [rawImage stretchableImageWithLeftCapWidth:(int)(rawImage.size.width / 2) topCapHeight:0];
    }
    return image;
}

- (UIImage *)messageAttachmentImageIncomingTopCornersHighlighted
{
    static UIImage *image = nil;
    if (image == nil)
    {
        UIImage *rawImage = [UIImage imageNamed:@"AttachmentCornersIncomingTop_Highlighted.png"];
        image = [rawImage stretchableImageWithLeftCapWidth:(int)(rawImage.size.width / 2) topCapHeight:0];
    }
    return image;
}

- (UIImage *)messageAttachmentImageIncomingBottomCorners
{
    static UIImage *image = nil;
    if (image == nil)
    {
        UIImage *rawImage = [UIImage imageNamed:@"AttachmentCornersIncomingBottom.png"];
        image = [rawImage stretchableImageWithLeftCapWidth:(int)(rawImage.size.width / 2) topCapHeight:0];
    }
    return image;
}

- (UIImage *)messageAttachmentImageIncomingBottomCornersHighlighted
{
    static UIImage *image = nil;
    if (image == nil)
    {
        UIImage *rawImage = [UIImage imageNamed:@"AttachmentCornersIncomingBottom_Highlighted.png"];
        image = [rawImage stretchableImageWithLeftCapWidth:(int)(rawImage.size.width / 2) topCapHeight:0];
    }
    return image;
}

- (UIImage *)messageAttachmentImageOutgoingTopCorners
{
    static UIImage *image = nil;
    if (image == nil)
    {
        UIImage *rawImage = [UIImage imageNamed:@"AttachmentCornersOutgoingTop.png"];
        image = [rawImage stretchableImageWithLeftCapWidth:(int)(rawImage.size.width / 2) topCapHeight:0];
    }
    return image;
}

- (UIImage *)messageAttachmentImageOutgoingTopCornersHighlighted
{
    static UIImage *image = nil;
    if (image == nil)
    {
        UIImage *rawImage = [UIImage imageNamed:@"AttachmentCornersIncomingTop_Highlighted.png"];
        image = [rawImage stretchableImageWithLeftCapWidth:(int)(rawImage.size.width / 2) topCapHeight:0];
    }
    return image;
}

- (UIImage *)messageAttachmentImageOutgoingBottomCorners
{
    static UIImage *image = nil;
    if (image == nil)
    {
        UIImage *rawImage = [UIImage imageNamed:@"AttachmentCornersOutgoingBottom.png"];
        image = [rawImage stretchableImageWithLeftCapWidth:(int)(rawImage.size.width / 2) topCapHeight:0];
    }
    return image;
}

- (UIImage *)messageAttachmentImageOutgoingBottomCornersHighlighted
{
    static UIImage *image = nil;
    if (image == nil)
    {
        UIImage *rawImage = [UIImage imageNamed:@"AttachmentCornersIncomingBottom_Highlighted.png"];
        image = [rawImage stretchableImageWithLeftCapWidth:(int)(rawImage.size.width / 2) topCapHeight:0];
    }
    return image;
}

- (UIImage *)messageAttachmentImageLoadingIcon
{
    static UIImage *image = nil;
    if (image == nil)
        image = [UIImage imageNamed:@"MediaInlineDownloadingIcon.png"];
    return image;
}

- (UIImage *)messageActionConversationPhotoPlaceholder
{
    if (_monochromeColor != -1)
    {
        static UIImage *image = nil;
        if (image == nil)
        {
            UIImage *rawImage = [UIImage imageNamed:@"ProfilePhotoPlaceholder_Mono.png"];
            image = [rawImage stretchableImageWithLeftCapWidth:(int)(rawImage.size.width / 2) topCapHeight:0];
        }
        return image;
    }
    else
        return [TGInterfaceAssets profileGroupAvatarPlaceholder];
    
    return nil;
}

- (UIImage *)systemMessageBackground
{
    if (_monochromeColor != -1)
    {
        static int cachedImageColor = -1;
        static UIImage *image = nil;
        if (cachedImageColor != _monochromeColor || image == nil)
        {
            NSArray *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
            NSString *assetsPath = [[NSString alloc] initWithFormat:@"%@/assets/", documentsPath];
            [[NSFileManager defaultManager] createDirectoryAtPath:assetsPath withIntermediateDirectories:true attributes:nil error:nil];
            NSString *filePath = [[NSString alloc] initWithFormat:@"%@/systemMessageBackground_%x%@.png", assetsPath, _monochromeColor, TGIsRetina() ? @"@2x" : @""];
            
            UIImage *rawImage = [UIImage imageWithContentsOfFile:filePath];
            if (rawImage == nil)
            {
                TGLog(@"Generating system message background");
                
                rawImage = [self generateSystemMessageBackground:_monochromeColor];
                [UIImagePNGRepresentation(rawImage) writeToFile:filePath atomically:false];
            }
            
            image = [rawImage stretchableImageWithLeftCapWidth:(int)(rawImage.size.width / 2) topCapHeight:(int)(rawImage.size.height / 2)];
            
            cachedImageColor = _monochromeColor;
        }
        return image;
    }
    else
    {
        static UIImage *image = nil;
        if (image == nil)
        {
            UIImage *rawImage = [UIImage imageNamed:@"SystemMessageBackground.png"];
            image = [rawImage stretchableImageWithLeftCapWidth:(int)(rawImage.size.width / 2) topCapHeight:(int)(rawImage.size.height / 2)];
        }
        return image;
    }
}

- (UIImage *)generateSystemMessageBackground:(int)baseColor
{    
    float backgroundAlpha = 0.29f;
    
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(21, 21), false, 0.0f);
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGRect bounds = CGRectMake(0.5f, 0, 20, 20);
    
    CGFloat radius = 0.5f * CGRectGetHeight(bounds);
    
    CGMutablePathRef visiblePath = CGPathCreateMutable();
    CGRect innerRect = CGRectInset(bounds, radius, radius);
    CGPathMoveToPoint(visiblePath, NULL, innerRect.origin.x, bounds.origin.y);
    CGPathAddLineToPoint(visiblePath, NULL, innerRect.origin.x + innerRect.size.width, bounds.origin.y);
    CGPathAddArcToPoint(visiblePath, NULL, bounds.origin.x + bounds.size.width, bounds.origin.y, bounds.origin.x + bounds.size.width, innerRect.origin.y, radius);
    CGPathAddLineToPoint(visiblePath, NULL, bounds.origin.x + bounds.size.width, innerRect.origin.y + innerRect.size.height);
    CGPathAddArcToPoint(visiblePath, NULL,  bounds.origin.x + bounds.size.width, bounds.origin.y + bounds.size.height, innerRect.origin.x + innerRect.size.width, bounds.origin.y + bounds.size.height, radius);
    CGPathAddLineToPoint(visiblePath, NULL, innerRect.origin.x, bounds.origin.y + bounds.size.height);
    CGPathAddArcToPoint(visiblePath, NULL,  bounds.origin.x, bounds.origin.y + bounds.size.height, bounds.origin.x, innerRect.origin.y + innerRect.size.height, radius);
    CGPathAddLineToPoint(visiblePath, NULL, bounds.origin.x, innerRect.origin.y);
    CGPathAddArcToPoint(visiblePath, NULL,  bounds.origin.x, bounds.origin.y, innerRect.origin.x, bounds.origin.y, radius);
    CGPathCloseSubpath(visiblePath);
    
    CGContextSaveGState(context);
    
    UIColor *color = nil;
    
    //color = UIColorRGBA(0xffffff, 0.4f);
    //CGContextSetShadowWithColor(context, CGSizeMake(0.0f, 1.0f), 0.0f, [color CGColor]);
    
    color = UIColorRGBA(baseColor, backgroundAlpha);
    [color setFill];
    CGContextAddPath(context, visiblePath);
    CGContextFillPath(context);
    
    CGContextRestoreGState(context);
    
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathAddRect(path, NULL, CGRectInset(bounds, -2, -2));
    
    CGPathAddPath(path, NULL, visiblePath);
    CGPathCloseSubpath(path);
    
    CGContextAddPath(context, visiblePath);
    CGContextClip(context);
    
    CGContextSaveGState(context);
    
    //color = UIColorRGBA(baseColor, shadowAlpha);
    //CGContextSetShadowWithColor(context, CGSizeMake(0.0f, 1.0f), 1.0f, [color CGColor]);
    
    [color setFill];
    CGContextAddPath(context, path);
    CGContextEOFillPath(context);
    
    CGContextRestoreGState(context);
    
    CGPathRelease(path);
    CGPathRelease(visiblePath);
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

- (UIEdgeInsets)messageBodyMargins
{
    return UIEdgeInsetsMake(0, 2, 3, 2);
}
- (CGSize)messageMinimalBodySize
{
    return CGSizeMake(40, 31);
}

- (UIEdgeInsets)messageBodyPaddingsIncoming
{
    return UIEdgeInsetsMake(5, 15 + 1, 5, 9 + 1);
}

- (UIEdgeInsets)messageBodyPaddingsOutgoing
{
    return UIEdgeInsetsMake(5, 9 + 1, 5, 15 + 1);
}

- (UIImage *)membersListAddImage
{
    static UIImage *image = nil;
    if (image == nil)
    {
        image = [UIImage imageNamed:@"ConversationAddMember.png"];
    }
    return image;
}

- (UIImage *)membersListAddImageHighlighted
{
    static UIImage *image = nil;
    if (image == nil)
    {
        image = [UIImage imageNamed:@"ConversationAddMember_Pressed.png"];
    }
    return image;
}

- (UIImage *)membersListEditTitleBackground
{
    static UIImage *image = nil;
    if (image == nil)
    {
        UIImage *rawImage = [UIImage imageNamed:@"ConversationEditTitle.png"];
        image = [rawImage stretchableImageWithLeftCapWidth:(int)(rawImage.size.width / 2) topCapHeight:(int)(rawImage.size.height / 2)];
    }
    return image;
}

- (UIImage *)membersListAvatarPlaceholder
{
    static UIImage *image = nil;
    if (image == nil)
    {
        image = TGScaleAndRoundCornersWithOffset([UIImage imageNamed:@"AvatarPlaceholderSmall.png"], CGSizeMake(40, 40), CGPointMake(2, 2), CGSizeMake(44, 44), 4, [TGInterfaceAssets memberListAvatarOverlay], false, nil);
    }
    return image;
}

- (UIImage *)conversationUserPhotoPlaceholder
{
    return [UIImage imageNamed:@"ConversationUserPhotoPlaceholder.png"];
}

@end
