#import "TGReusableLabel.h"

#import <CoreText/CoreText.h>

#import "NSObject+TGLock.h"

#include <tr1/unordered_map>
#include <tr1/unordered_set>
#include <vector>

static inline CTTextAlignment CTTextAlignmentFromUITextAlignment(UITextAlignment alignment)
{
	switch (alignment)
    {
		case UITextAlignmentLeft:
            return kCTNaturalTextAlignment;
		case UITextAlignmentCenter:
            return kCTCenterTextAlignment;
		case UITextAlignmentRight:
            return kCTRightTextAlignment;
		default:
            return kCTNaturalTextAlignment;
	}
}

static inline CTLineBreakMode CTLineBreakModeFromUILineBreakMode(UILineBreakMode lineBreakMode)
{
	switch (lineBreakMode)
    {
		case UILineBreakModeWordWrap: return kCTLineBreakByWordWrapping;
		case UILineBreakModeCharacterWrap: return kCTLineBreakByCharWrapping;
		case UILineBreakModeClip: return kCTLineBreakByClipping;
		case UILineBreakModeHeadTruncation: return kCTLineBreakByTruncatingHead;
		case UILineBreakModeTailTruncation: return kCTLineBreakByTruncatingTail;
		case UILineBreakModeMiddleTruncation: return kCTLineBreakByTruncatingMiddle;
		default: return 0;
	}
}

@interface TGReusableLabelLayoutData ()
{
    std::tr1::unordered_map<int, std::tr1::unordered_map<int, int> > _lineOffsets;
    std::vector<TGLinePosition> _lineOrigins;
    
    std::vector<TGLinkData> _links;
}

#define TG_USE_MANUAL_LAYOUT true

#if TG_USE_MANUAL_LAYOUT
@property (nonatomic, strong) NSArray *textLines;
#else
@property (nonatomic) CTFrameRef textFrame;
#endif
@property (nonatomic) CGSize drawingSize;
@property (nonatomic) CGPoint drawingOffset;

- (std::tr1::unordered_map<int, std::tr1::unordered_map<int, int> > *)lineOffsets;

@end

@implementation TGReusableLabelLayoutData

#if TG_USE_MANUAL_LAYOUT
#else
- (void)setTextFrame:(CTFrameRef)textFrame
{
    if (_textFrame != NULL)
        CFRelease(_textFrame);
    if (textFrame != NULL)
        _textFrame = (CTFrameRef)CFRetain(textFrame);
    else
        _textFrame = NULL;
}
#endif

- (void)dealloc
{
#if TG_USE_MANUAL_LAYOUT
#else
    if (_textFrame != NULL)
    {
        CFRelease(_textFrame);
        _textFrame = NULL;
    }
#endif
}

- (std::tr1::unordered_map<int, std::tr1::unordered_map<int, int> > *)lineOffsets
{
    return &_lineOffsets;
}

- (std::vector<TGLinePosition> *)lineOrigins
{
    return &_lineOrigins;
}

- (std::vector<TGLinkData> *)links
{
    return &_links;
}

- (NSString *)linkAtPoint:(CGPoint)point topRegion:(CGRect *)topRegion middleRegion:(CGRect *)middleRegion bottomRegion:(CGRect *)bottomRegion
{
    if (!_links.empty())
    {
        for (std::vector<TGLinkData>::iterator it = _links.begin(); it != _links.end(); it++)
        {
            if ((it->topRegion.size.height != 0 && CGRectContainsPoint(CGRectInset(it->topRegion, -2, -2), point)) || (it->middleRegion.size.height != 0 && CGRectContainsPoint(CGRectInset(it->middleRegion, -2, -2), point)) || (it->bottomRegion.size.height != 0 && CGRectContainsPoint(CGRectInset(it->bottomRegion, -2, -2), point)))
            {
                if (topRegion != NULL)
                    *topRegion = it->topRegion;
                if (middleRegion != NULL)
                    *middleRegion = it->middleRegion;
                if (bottomRegion != NULL)
                    *bottomRegion = it->bottomRegion;
                return it->url;
            }
        }
    }
    return nil;
}

@end

@interface TGReusableLabel ()

@end

@implementation TGReusableLabel

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        _reuseIdentifier = @"ReusableLabel";
    }
    return self;
}

- (void)prepareForReuse
{
}

- (void)prepareForRecycle:(TGViewRecycler *)__unused recycler
{
    _precalculatedLayout = nil;
}

- (void)setHighlighted:(bool)highlighted
{
    if (highlighted != _highlighted)
    {
        _highlighted = highlighted;
        [self setNeedsDisplay];
    }
}

- (void)setFrame:(CGRect)frame
{
    if (!CGSizeEqualToSize(self.frame.size, frame.size))
    {
        [self setNeedsDisplay];
    }
    [super setFrame:frame];
}

- (void)setText:(NSString *)text
{
    if (text != _text)
    {
        _text = text;
        [self setNeedsDisplay];
    }
}

+ (void)preloadData
{
}

+ (TGReusableLabelLayoutData *)calculateLayout:(NSString *)text additionalAttributes:(NSArray *)additionalAttributes textCheckingResults:(NSArray *)textCheckingResults font:(CTFontRef)font textColor:(UIColor *)textColor frame:(CGRect)frame orMaxWidth:(float)maxWidth flags:(int)flags textAlignment:(UITextAlignment)textAlignment
{
    if (font == NULL || text == nil)
        return nil;
    
    static bool needToOffsetEmoji = false;
    static bool needToOffsetEmojiInitialized = false;
    if (!needToOffsetEmojiInitialized)
    {
        needToOffsetEmojiInitialized = true;
        needToOffsetEmoji = iosMajorVersion() < 6;
    }
    
    TGReusableLabelLayoutData *layout = [[TGReusableLabelLayoutData alloc] init];
    
    float fontAscent = CTFontGetAscent(font);
    float fontDescent = CTFontGetDescent(font);
    
    float fontLineHeight = floorf(fontAscent + fontDescent);
    float fontLineSpacing = floorf(fontLineHeight * 1.2f);
    
    NSMutableDictionary *attributes = [[NSMutableDictionary alloc] initWithObjectsAndKeys:(__bridge id)font, (NSString *)kCTFontAttributeName, [[NSNumber alloc] initWithFloat:0.0f], (NSString *)kCTKernAttributeName, nil];
    
    NSMutableAttributedString *string = [[NSMutableAttributedString alloc] initWithString:text attributes:attributes];
    
    CFAttributedStringSetAttribute((CFMutableAttributedStringRef)string, CFRangeMake(0, string.length), kCTForegroundColorAttributeName, textColor.CGColor);
    
    if (additionalAttributes != nil)
    {
        int count = additionalAttributes.count;
        for (int i = 0; i < count; i += 2)
        {
            NSRange range = NSMakeRange(0, 0);
            [(NSValue *)[additionalAttributes objectAtIndex:i] getValue:&range];
            NSArray *attributes = [additionalAttributes objectAtIndex:i + 1];
            
            CFAttributedStringSetAttribute((CFMutableAttributedStringRef)string, CFRangeMake(range.location, range.length), (CFStringRef)[attributes objectAtIndex:1], (CFTypeRef)[attributes objectAtIndex:0]);
        }
    }
    
    static CGColorRef defaultLinkColor = nil;
    if (defaultLinkColor == nil)
        defaultLinkColor = (CGColorRef)CFRetain(UIColorRGB(0x004bad).CGColor);
    
    CGColorRef linkColor = defaultLinkColor;
    
    NSRange *pLinkRanges = NULL;
    int linkRangesCount = 0;
    
    if (textCheckingResults != nil && textCheckingResults.count != 0)
    {
        NSNumber *underlineStyle = [[NSNumber alloc] initWithInt:kCTUnderlineStyleSingle];
        
        int index = -1;
        for (NSTextCheckingResult *match in textCheckingResults)
        {
            index++;
            
            NSRange linkRange = [match range];
            
            if (pLinkRanges == NULL)
            {
                linkRangesCount = textCheckingResults.count;
                pLinkRanges = new NSRange[linkRangesCount];
            }
            
            pLinkRanges[index] = linkRange;
            
            NSString *url = match.resultType == NSTextCheckingTypePhoneNumber ? [[NSString alloc] initWithFormat:@"tel:%@", match.phoneNumber] : [match.URL absoluteString];
            layout.links->push_back(TGLinkData(linkRange, url));
            
            if (flags & TGReusableLabelLayoutHighlightLinks)
            {
                CFAttributedStringSetAttribute((CFMutableAttributedStringRef)string, CFRangeMake(linkRange.location, linkRange.length), kCTForegroundColorAttributeName, linkColor);
                CFAttributedStringSetAttribute((CFMutableAttributedStringRef)string, CFRangeMake(linkRange.location, linkRange.length), kCTUnderlineStyleAttributeName, (CFNumberRef)underlineStyle);
            }
        }
    }
    
    CGRect rect = CGRectZero;
    rect.origin = frame.origin;
    
    std::vector<TGLinePosition> *pLineOrigins = layout.lineOrigins;
    pLineOrigins->erase(pLineOrigins->begin(), pLineOrigins->end());
    
    NSMutableArray *textLines = [[NSMutableArray alloc] init];
    
    bool hadRTL = false;
    
    if (flags & TGReusableLabelLayoutMultiline)
    {
        CTTypesetterRef typesetter = CTTypesetterCreateWithAttributedString((__bridge CFAttributedStringRef)string);
        
        CFIndex lastIndex = 0;
        float currentLineOffset = 0;
        
        while (true)
        {
            CFIndex lineCharacterCount = CTTypesetterSuggestLineBreak(typesetter, lastIndex, maxWidth);
            
            if (pLinkRanges != NULL && flags & TGReusableLabelLayoutHighlightLinks)
            {
                CFIndex endIndex = lastIndex + lineCharacterCount;
                
                for (int i = 0; i < linkRangesCount; i++)
                {
                    if (pLinkRanges[i].location < endIndex && pLinkRanges[i].location + pLinkRanges[i].length >= endIndex)
                    {
                        lineCharacterCount = MAX(lineCharacterCount, CTTypesetterSuggestClusterBreak(typesetter, lastIndex, maxWidth));
                        
                        if (pLinkRanges[i].location > lastIndex && lineCharacterCount < pLinkRanges[i].location + pLinkRanges[i].length - lastIndex)
                            lineCharacterCount = pLinkRanges[i].location - lastIndex;
                        
                        break;
                    }
                }
            }
            
            if (lineCharacterCount > 0)
            {
                CTLineRef line = CTTypesetterCreateLineWithOffset(typesetter, CFRangeMake(lastIndex, lineCharacterCount), 100.0);
                [textLines addObject:(__bridge id)line];
                
                bool rightAligned = false;
                
                CFArrayRef glyphRuns = CTLineGetGlyphRuns(line);
                if (CFArrayGetCount(glyphRuns) != 0)
                {
                    if (CTRunGetStatus((CTRunRef)CFArrayGetValueAtIndex(glyphRuns, 0)) & kCTRunStatusRightToLeft)
                        rightAligned = true;
                }
                
                hadRTL |= rightAligned;
                
                TGLinePosition linePosition = {.offset = currentLineOffset + fontLineHeight, .alignment = (textAlignment == UITextAlignmentCenter ? 1 : (rightAligned ? 2 : 0))};
                pLineOrigins->push_back(linePosition);
                
                currentLineOffset += fontLineSpacing;
                rect.size.height += fontLineSpacing;
                rect.size.width = MAX(rect.size.width, (float)CTLineGetTypographicBounds(line, NULL, NULL, NULL) - (float)CTLineGetTrailingWhitespaceWidth(line));
                
                CFRelease(line);
                
                lastIndex += lineCharacterCount;
            }
            else
                break;
        }
        
        layout.size = CGSizeMake(floorf(rect.size.width), floorf(rect.size.height + fontLineHeight * 0.1f));
        layout.drawingSize = rect.size;
        
        layout.textLines = textLines;
        
        if (typesetter != NULL)
            CFRelease(typesetter);
    }
    else
    {
        NSMutableDictionary *truncationTokenAttributes = [[NSMutableDictionary alloc] initWithObjectsAndKeys:(__bridge id)font, (NSString *)kCTFontAttributeName, (__bridge id)textColor.CGColor, (NSString *)kCTForegroundColorAttributeName, nil];
        
        static NSString *tokenString = nil;
        if (tokenString == nil)
        {
            unichar tokenChar = 0x2026;
            tokenString = [[NSString alloc] initWithCharacters:&tokenChar length:1];
        }
        
        NSAttributedString *truncationTokenString = [[NSAttributedString alloc] initWithString:tokenString attributes:truncationTokenAttributes];
        CTLineRef truncationToken = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)truncationTokenString);
        
        CTLineRef originalLine = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)string);
        CTLineRef line = CTLineCreateTruncatedLine(originalLine, maxWidth, kCTLineTruncationEnd, truncationToken);
        CFRelease(originalLine);
        
        TGLinePosition linePosition = {.offset = 0.0f + fontLineHeight, .alignment = 0};
        pLineOrigins->push_back(linePosition);
        
        layout.size = CGSizeMake((float)CTLineGetTypographicBounds(line, NULL, NULL, NULL) - (float)CTLineGetTrailingWhitespaceWidth(line), fontLineSpacing);
        layout.drawingSize = layout.size;
        
        [textLines addObject:(__bridge id)line];
        layout.textLines = textLines;
        
        CFRelease(line);
    }
    
    if (!layout.links->empty())
    {
        std::vector<TGLinkData>::iterator linksBegin = layout.links->begin();
        std::vector<TGLinkData>::iterator linksEnd = layout.links->end();
        
        CGSize layoutSize = layout.size;
        layoutSize.height -= 1;
        
        int numberOfLines = textLines.count;
        for (int iLine = 0; iLine < numberOfLines; iLine++)
        {
            CTLineRef line = (__bridge CTLineRef)[textLines objectAtIndex:iLine];
            CFRange lineRange = CTLineGetStringRange(line);
            
            TGLinePosition const &linePosition = pLineOrigins->at(iLine);
            CGPoint lineOrigin = CGPointMake(linePosition.alignment == 0 ? 0.0f : ((float)CTLineGetPenOffsetForFlush(line, linePosition.alignment == 1 ? 0.5f : 1.0f, rect.size.width)), linePosition.offset);
            
            for (std::vector<TGLinkData>::iterator it = linksBegin; it != linksEnd; it++)
            {
                NSRange intersectionRange = NSIntersectionRange(it->range, NSMakeRange(lineRange.location, lineRange.length));
                if (intersectionRange.length != 0)
                {
                    float startX = 0.0f;
                    float endX = 0.0f;
                 
                    if (hadRTL)
                    {
                        bool appliedAnyPosition = false;
                        
                        CFArrayRef glyphRuns = CTLineGetGlyphRuns(line);
                        int glyphRunCount = CFArrayGetCount(glyphRuns);
                        for (int iRun = 0; iRun < glyphRunCount; iRun++)
                        {
                            CTRunRef run = (CTRunRef)CFArrayGetValueAtIndex(glyphRuns, iRun);
                            CFIndex glyphCount = CTRunGetGlyphCount(run);
                            if (glyphCount > 0)
                            {
                                CFIndex startIndex = 0;
                                CFIndex endIndex = 0;
                                
                                CTRunGetStringIndices(run, CFRangeMake(0, 1), &startIndex);
                                CTRunGetStringIndices(run, CFRangeMake(glyphCount - 1, 1), &endIndex);
                                
                                if (startIndex >= it->range.location && endIndex < it->range.location + it->range.length)
                                {
                                    CGPoint leftPosition = CGPointZero;
                                    CGPoint rightPosition = CGPointZero;
                                    
                                    CTRunGetPositions(run, CFRangeMake(0, 1), &leftPosition);
                                    float runWidth = (float)CTRunGetTypographicBounds(run, CFRangeMake(0, glyphCount), NULL, NULL, NULL);
                                    rightPosition.x = leftPosition.x + runWidth;
                                    
                                    if (!appliedAnyPosition)
                                    {
                                        appliedAnyPosition = true;
                                        
                                        startX = leftPosition.x;
                                        endX = rightPosition.x;
                                    }
                                    else
                                    {
                                        if (leftPosition.x < startX)
                                            startX = leftPosition.x;
                                        if (rightPosition.x > endX)
                                            endX = rightPosition.x;
                                    }
                                }
                            }
                        }
                        
                        startX = floorf(startX + lineOrigin.x);
                        endX = ceilf(endX + lineOrigin.x);
                    }
                    else
                    {
                        startX = ceilf(CTLineGetOffsetForStringIndex(line, intersectionRange.location, NULL) + lineOrigin.x);
                        endX = ceilf(CTLineGetOffsetForStringIndex(line, intersectionRange.location + intersectionRange.length, NULL) + lineOrigin.x);
                    }
                    
                    if (startX > endX)
                    {
                        float tmp = startX;
                        startX = endX;
                        endX = tmp;
                    }
                    
                    bool tillEndOfLine = false;
                    if (intersectionRange.location + intersectionRange.length >= lineRange.location + lineRange.length && ABS(endX - layoutSize.width) < 16)
                    {
                        tillEndOfLine = true;
                        endX = layoutSize.width + lineOrigin.x;
                    }
                    CGRect region = CGRectMake(ceilf(startX - 3), ceilf(lineOrigin.y - fontLineHeight + fontLineHeight * 0.1f), ceilf(endX - startX + 6), ceilf(fontLineSpacing));
                    
                    if (it->topRegion.size.height == 0)
                        it->topRegion = region;
                    else
                    {
                        if (it->middleRegion.size.height == 0)
                            it->middleRegion = region;
                        else if (intersectionRange.location == lineRange.location && intersectionRange.length == lineRange.length && tillEndOfLine)
                            it->middleRegion.size.height += region.size.height;
                        else
                            it->bottomRegion = region;
                    }
                }
            }
        }
    }
    
    if (pLinkRanges != NULL)
        delete pLinkRanges;
    
    return layout;
}

/*+ (TGReusableLabelLayoutData *)calculateLayout_:(NSString *)text additionalAttributes:(NSArray *)additionalAttributes textCheckingResults:(NSArray *)textCheckingResults font:(CTFontRef)font textColor:(UIColor *)textColor frame:(CGRect)frame orMaxWidth:(float)maxWidth flags:(int)flags textAlignment:(UITextAlignment)textAlignment
{
    if (font == NULL || text == nil)
        return nil;
    
    bool multiline = flags & TGReusableLabelLayoutMultiline;
    
    static bool needToOffsetEmoji = false;
    static bool needToOffsetMultilineEmoji = false;
    static bool needToOffsetEmojiInitialized = false;
    if (!needToOffsetEmojiInitialized)
    {
        needToOffsetEmoji = [[[UIDevice currentDevice] systemVersion] intValue] < 6;
        needToOffsetMultilineEmoji = needToOffsetEmoji && cpuCoreCount() > 1;
        needToOffsetEmojiInitialized = true;
    }
    
    TGReusableLabelLayoutData *layout = [[TGReusableLabelLayoutData alloc] init];
    
    CGFloat fontAscent = CTFontGetAscent(font);
    CGFloat fontDescent = CTFontGetDescent(font);
    float fontPointSize = fontAscent + fontDescent;
    CGFloat lineHeight = 0;
    
    NSMutableDictionary *mutableAttributes = [[NSMutableDictionary alloc] init];
    [mutableAttributes setObject:(__bridge id)font forKey:(NSString *)kCTFontAttributeName];
    [mutableAttributes setObject:[NSNumber numberWithFloat:0.0f] forKey:(NSString *)kCTKernAttributeName];
    
    CTTextAlignment alignment = CTTextAlignmentFromUITextAlignment(textAlignment);
    CGFloat lineSpacingAdjustment = (float)(lineHeight - fontAscent + fontDescent);
    CGFloat lineSpacing = 0.0f;
    CGFloat lineHeightMultiple = 0.0f;
    
    CTLineBreakMode lineBreakMode;
    if (!multiline)
        lineBreakMode = CTLineBreakModeFromUILineBreakMode(UILineBreakModeTailTruncation);
    else
        lineBreakMode = CTLineBreakModeFromUILineBreakMode(UILineBreakModeWordWrap);
    
    CTParagraphStyleSetting paragraphStyles[6] = {
        {.spec = kCTParagraphStyleSpecifierAlignment, .valueSize = sizeof(CTTextAlignment), .value = (const void *)&alignment},
        {.spec = kCTParagraphStyleSpecifierLineBreakMode, .valueSize = sizeof(CTLineBreakMode), .value = (const void *)&lineBreakMode},
        {.spec = kCTParagraphStyleSpecifierLineSpacing, .valueSize = sizeof(CGFloat), .value = (const void *)&lineSpacing},
        {.spec = kCTParagraphStyleSpecifierLineSpacingAdjustment, .valueSize = sizeof(CGFloat), .value = (const void *)&lineSpacingAdjustment},
        {.spec = kCTParagraphStyleSpecifierLineHeightMultiple, .valueSize = sizeof(CGFloat), .value = (const void *)&lineHeightMultiple},
    };
    
    CTParagraphStyleRef paragraphStyle = CTParagraphStyleCreate(paragraphStyles, 6);
    [mutableAttributes setObject:(__bridge id)paragraphStyle forKey:(NSString *)kCTParagraphStyleAttributeName];
    CFRelease(paragraphStyle);
    
    NSMutableAttributedString *string = [[NSMutableAttributedString alloc] initWithString:text attributes:mutableAttributes];
    
    CFAttributedStringSetAttribute((CFMutableAttributedStringRef)string, CFRangeMake(0, string.length), kCTForegroundColorAttributeName, textColor.CGColor);
    
    if (additionalAttributes != nil)
    {
        int count = additionalAttributes.count;
        for (int i = 0; i < count; i += 2)
        {
            NSRange range = NSMakeRange(0, 0);
            [(NSValue *)[additionalAttributes objectAtIndex:i] getValue:&range];
            NSArray *attributes = [additionalAttributes objectAtIndex:i + 1];
            
            CFAttributedStringSetAttribute((CFMutableAttributedStringRef)string, CFRangeMake(range.location, range.length), (CFStringRef)[attributes objectAtIndex:1], (CFTypeRef)[attributes objectAtIndex:0]);
        }
    }
    
    static CGColorRef defaultLinkColor = nil;
    if (defaultLinkColor == nil)
        defaultLinkColor = (CGColorRef)CFRetain(UIColorRGB(0x004bad).CGColor);
    
    CGColorRef linkColor = defaultLinkColor;
    
    if (textCheckingResults != nil && textCheckingResults.count != 0)
    {
        CTLineBreakMode linkLineBreaking = CTLineBreakModeFromUILineBreakMode(UILineBreakModeCharacterWrap);
        
        CTParagraphStyleSetting paragraphStyles[1] = {
            {.spec = kCTParagraphStyleSpecifierLineBreakMode, .valueSize = sizeof(CTLineBreakMode), .value = (const void *)&linkLineBreaking}
        };
        
        CTParagraphStyleRef linkParagraphStyle = CTParagraphStyleCreate(paragraphStyles, 1);
        
        NSNumber *underlineStyle = [[NSNumber alloc] initWithInt:kCTUnderlineStyleSingle];
        for (NSTextCheckingResult *match in textCheckingResults)
        {
            NSRange linkRange = [match range];
            NSString *url = match.resultType == NSTextCheckingTypePhoneNumber ? [[NSString alloc] initWithFormat:@"tel:%@", match.phoneNumber] : [match.URL absoluteString];
            layout.links->push_back(TGLinkData(linkRange, url));
            
            if (flags & TGReusableLabelLayoutHighlightLinks)
            {
                CFAttributedStringSetAttribute((CFMutableAttributedStringRef)string, CFRangeMake(linkRange.location, linkRange.length), kCTForegroundColorAttributeName, linkColor);
                CFAttributedStringSetAttribute((CFMutableAttributedStringRef)string, CFRangeMake(linkRange.location, linkRange.length), kCTUnderlineStyleAttributeName, (CFNumberRef)underlineStyle);
                CFAttributedStringSetAttribute((CFMutableAttributedStringRef)string, CFRangeMake(linkRange.location, linkRange.length), kCTParagraphStyleAttributeName, linkParagraphStyle);
            }
        }
        
        CFRelease(linkParagraphStyle);
    }
    
    CGMutablePathRef path = CGPathCreateMutable();
    CGRect rect = frame;
    
    CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)string);
    
    if (rect.size.height == 0.0f)
    {
        CFRange fitRange = CFRangeMake(0, 0);
        rect.size = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRangeMake(0, 0), NULL, CGSizeMake(maxWidth, 100000), &fitRange);
    }
    
    rect.origin = CGPointZero;
    CGPathAddRect(path, NULL, rect);
    CTFrameRef textFrame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, NULL);
    
    CFArrayRef lines = CTFrameGetLines(textFrame);
    NSInteger numberOfLines = CFArrayGetCount(lines);
    
    rect.size.width = ceilf(rect.size.width);
    rect.size.height = ceilf(rect.size.height);

    layout.drawingSize = rect.size;
    
    CGPoint lineOrigins[numberOfLines];
    CTFrameGetLineOrigins(textFrame, CFRangeMake(0, numberOfLines), lineOrigins);
    
    std::vector<TGLinePosition> *pLineOrigins = layout.lineOrigins;
    pLineOrigins->resize(numberOfLines);
    
    for (int i = 0; i < numberOfLines; i++)
    {
        TGLinePosition linePosition = {.offset = lineOrigins[i].y, .alignment = 0};
        (*pLineOrigins)[i] = linePosition;
    }
    
    if (numberOfLines == 1 && (int)rect.size.height == 26)
    {   
        std::tr1::unordered_map<int, std::tr1::unordered_map<int, int> > *lineOffsetsMap = layout.lineOffsets;
        
        for (int iLine = 0; iLine < numberOfLines; iLine++)
        {
            bool insertedMapForCurrentLine = false;
            
            layout.size = CGSizeMake(rect.size.width, 20);
            layout.drawingOffset = CGPointMake(0, -4);
            
            if (needToOffsetEmoji)
            {
                CTLineRef line = (CTLineRef)CFArrayGetValueAtIndex(lines, iLine);
                
                CFArrayRef glyphRuns = CTLineGetGlyphRuns(line);
                int glyphRunsCount = CFArrayGetCount(glyphRuns);
                for (int i = 0; i < glyphRunsCount; i++)
                {
                    CTRunRef run = (CTRunRef)CFArrayGetValueAtIndex(glyphRuns, i);
                    
                    int glyphCount = CTRunGetGlyphCount(run);
                    if (glyphCount != 0)
                    {
                        double width = CTRunGetTypographicBounds(run, CFRangeMake(0, 1), NULL, NULL, NULL);
                        if (width == 20)
                        {
                            if (!insertedMapForCurrentLine)
                            {
                                insertedMapForCurrentLine = true;
                                lineOffsetsMap->insert(std::pair<int, std::tr1::unordered_map<int, int> >(iLine, std::tr1::unordered_map<int, int>()));
                            }
                            lineOffsetsMap->find(iLine)->second.insert(std::pair<int, int>(i, -2));
                        }
                    }
                }
            }
        }
    }
    else
    {
        CGSize size = rect.size;
        size.height += 1;
        
        if (numberOfLines > 1)
        {
            CGFloat ascent, descent, leading;
        
            CTLineGetTypographicBounds((CTLineRef) CFArrayGetValueAtIndex(lines, 0), &ascent,  &descent, &leading);
            CGFloat firstLineHeight = ascent + descent + leading;
            
            CTLineGetTypographicBounds((CTLineRef) CFArrayGetValueAtIndex(lines, numberOfLines - 1), &ascent,  &descent, &leading);
            CGFloat lastLineHeight  = ascent + descent + leading;
            
            CGPoint firstLineOrigin = lineOrigins[0];
            CGPoint lastLineOrigin = lineOrigins[numberOfLines - 1];
            
            CGFloat textHeight = ABS(firstLineOrigin.y - lastLineOrigin.y) + firstLineHeight + lastLineHeight - 10;
            
            CGPoint drawingOffset = CGPointMake(0, size.height - textHeight + 1);
            
            size.height = textHeight - 2;
            
            float implicitOffset = 0.0f;
            
            float heightOffset = 0.0f;
            
            for (int iLine = 0; iLine < numberOfLines; iLine++)
            {
                CGFloat ascent, descent, leading;
                CTLineGetTypographicBounds((CTLineRef)CFArrayGetValueAtIndex(lines, iLine), &ascent,  &descent, &leading);
                CGFloat lineHeight = ascent + descent + leading;
                float currentOffset = implicitOffset;
                if (lineHeight > 18)
                {
                    float lineOffset = (lineHeight - 16) - 5;
                    currentOffset += lineOffset;
                    implicitOffset += lineOffset + 1;
                    currentOffset -= 2;
                    if (iLine == 0)
                        heightOffset += 5;
                    if (iLine == numberOfLines - 1)
                        heightOffset += 7;
                }
                
                if (currentOffset != 0)
                {
                    pLineOrigins->at(iLine).offset += ((int)(currentOffset * 2.0f)) / 2.0f;
                }
                
                if (lineHeight > 16 && needToOffsetMultilineEmoji)
                {
                    bool insertedMapForCurrentLine = false;
                    std::tr1::unordered_map<int, std::tr1::unordered_map<int, int> > *lineOffsetsMap = layout.lineOffsets;
                    
                    CTLineRef line = (CTLineRef)CFArrayGetValueAtIndex(lines, iLine);
                    
                    CFArrayRef glyphRuns = CTLineGetGlyphRuns(line);
                    int glyphRunsCount = CFArrayGetCount(glyphRuns);
                    for (int i = 0; i < glyphRunsCount; i++)
                    {
                        CTRunRef run = (CTRunRef)CFArrayGetValueAtIndex(glyphRuns, i);
                        
                        int glyphCount = CTRunGetGlyphCount(run);
                        if (glyphCount != 0)
                        {
                            double width = CTRunGetTypographicBounds(run, CFRangeMake(0, 1), NULL, NULL, NULL);
                            if (width == 20)
                            {
                                if (!insertedMapForCurrentLine)
                                {
                                    insertedMapForCurrentLine = true;
                                    lineOffsetsMap->insert(std::pair<int, std::tr1::unordered_map<int, int> >(iLine, std::tr1::unordered_map<int, int>()));
                                }
                                lineOffsetsMap->find(iLine)->second.insert(std::pair<int, int>(i, -2));
                            }
                        }
                    }
                }
            }
            
            size.height -= implicitOffset + heightOffset;
            drawingOffset.y += implicitOffset + heightOffset;
            
            layout.drawingOffset = drawingOffset;
            layout.drawingSize = CGSizeMake((int)size.width, (int)size.height);
        }
        
        layout.size = CGSizeMake((int)size.width, (int)size.height);
    }
    
    if (!layout.links->empty())
    {
        std::vector<TGLinkData>::iterator linksBegin = layout.links->begin();
        std::vector<TGLinkData>::iterator linksEnd = layout.links->end();
        
        CGSize layoutSize = layout.size;
        CGPoint drawingOffset = layout.drawingOffset;
        layoutSize.height -= 1;
        
        for (int iLine = 0; iLine < numberOfLines; iLine++)
        {
            CTLineRef line = (CTLineRef)CFArrayGetValueAtIndex(lines, iLine);
            CFRange lineRange = CTLineGetStringRange(line);
            CGPoint lineOrigins[2];
            CTFrameGetLineOrigins(textFrame, CFRangeMake(iLine, (iLine == numberOfLines - 1) ? 1 : 2), lineOrigins);
            
            float lineHeight = iLine == 0 ? (layoutSize.height - lineOrigins[0].y) : (lineOrigins[0].y - lineOrigins[1].y);
            
            if (fontPointSize <= 13 + FLT_EPSILON)
            {
                if (lineHeight < 16)
                    lineHeight = 16;
            }
            else
            {
                if (lineHeight < 20)
                    lineHeight = 20;
            }
            lineOrigins[0].y = layoutSize.height - lineOrigins[0].y;
            lineOrigins[0].y -= lineHeight;
            
            for (std::vector<TGLinkData>::iterator it = linksBegin; it != linksEnd; it++)
            {
                NSRange intersectionRange = NSIntersectionRange(it->range, NSMakeRange(lineRange.location, lineRange.length));
                if (intersectionRange.length != 0)
                {
                    float lineOriginY = lineOrigins[0].y + 5 + drawingOffset.y;
                    
                    float startX = ceilf(CTLineGetOffsetForStringIndex(line, intersectionRange.location, NULL) + lineOrigins[0].x);
                    float endX = CTLineGetOffsetForStringIndex(line, intersectionRange.location + intersectionRange.length, NULL) + lineOrigins[0].x;
                    bool tillEndOfLine = false;
                    if (intersectionRange.location + intersectionRange.length >= lineRange.location + lineRange.length && ABS(endX - layoutSize.width) < 16)
                    {
                        tillEndOfLine = true;
                        endX = layoutSize.width + lineOrigins[0].x;
                    }
                    CGRect region = CGRectMake(ceilf(startX - 3), ceilf(lineOriginY), ceilf(endX - startX + 6), ceilf(lineHeight));
                    
                    if (it->topRegion.size.height == 0)
                        it->topRegion = region;
                    else
                    {
                        if (it->middleRegion.size.height == 0)
                            it->middleRegion = region;
                        else if (intersectionRange.location == lineRange.location && intersectionRange.length == lineRange.length && tillEndOfLine)
                            it->middleRegion.size.height += region.size.height;
                        else
                            it->bottomRegion = region;
                    }
                }
            }
        }
    }

#if TG_USE_MANUAL_LAYOUT
    layout.textLines = (__bridge NSArray *)lines;
#else
    layout.textFrame = textFrame;
#endif
    if (textFrame != NULL)
        CFRelease(textFrame);
    CFRelease(path);
    CFRelease(framesetter);
    
    return layout;
}*/

- (void)drawRect:(CGRect)__unused rect
{
    if (_richText)
        [TGReusableLabel drawRichTextInRect:self.bounds precalculatedLayout:_precalculatedLayout linesRange:NSMakeRange(0, 0) shadowColor:_shadowColor shadowOffset:_shadowOffset];
    else
        [TGReusableLabel drawTextInRect:self.bounds text:_text richText:_richText font:_font highlighted:_highlighted textColor:_textColor highlightedColor:_highlightedTextColor shadowColor:_shadowColor shadowOffset:_shadowOffset numberOfLines:_numberOfLines];
}

+ (void)drawTextInRect:(CGRect)rect text:(NSString *)text richText:(bool)richText font:(UIFont *)font highlighted:(bool)highlighted textColor:(UIColor *)textColor highlightedColor:(UIColor *)highlightedColor shadowColor:(UIColor *)shadowColor shadowOffset:(CGSize)shadowOffset numberOfLines:(int)numberOfLines
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (!richText)
    {
        CGContextSetFillColorWithColor(context, ((highlighted && highlightedColor != nil) ? highlightedColor : textColor).CGColor);
        
        UIColor *shadow = highlighted ? nil : shadowColor;
        if (shadowColor != nil)
            CGContextSetShadowWithColor(context, shadowOffset, 0, shadow.CGColor);
        
        CGRect textRect = rect;
        [text drawInRect:textRect withFont:font lineBreakMode:(numberOfLines == 0 ? UILineBreakModeWordWrap : UILineBreakModeTailTruncation)];
    }
}

+ (void)drawRichTextInRect:(CGRect)rect precalculatedLayout:(TGReusableLabelLayoutData *)precalculatedLayout linesRange:(NSRange)linesRange shadowColor:(UIColor *)shadowColor shadowOffset:(CGSize)shadowOffset
{    
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);
    
    if (shadowColor != nil)
        CGContextSetShadowWithColor(context, shadowOffset, 0, shadowColor.CGColor);
    
#if TG_USE_MANUAL_LAYOUT
    
    CGContextSetTextMatrix(context, CGAffineTransformMakeScale(1.0f, -1.0f));
    CGContextTranslateCTM(context, rect.origin.x, rect.origin.y);
    
    CFArrayRef lines = (__bridge CFArrayRef)precalculatedLayout.textLines;
    if (lines == nil)
    {
        CGContextRestoreGState(context);
        
        #if TARGET_IPHONE_SIMULATOR
        TGLog(@"%s:%d: warning: lines is nil", __PRETTY_FUNCTION__, __LINE__);
        #endif
        
        return;
    }
    
    NSInteger numberOfLines = CFArrayGetCount(lines);
    
    if (linesRange.length == 0)
        linesRange = NSMakeRange(0, numberOfLines);
    
    const std::vector<TGLinePosition> *pLineOrigins = precalculatedLayout.lineOrigins;
    
    for (CFIndex lineIndex = linesRange.location; lineIndex < linesRange.location + linesRange.length; lineIndex++)
    {
        CTLineRef line = (CTLineRef)CFArrayGetValueAtIndex(lines, lineIndex);
        
        TGLinePosition const &linePosition = pLineOrigins->at(lineIndex);
        
        CGPoint lineOrigin = CGPointMake(linePosition.alignment == 0 ? 0.0f : ((float)CTLineGetPenOffsetForFlush(line, linePosition.alignment == 1 ? 0.5f : 1.0f, rect.size.width)), linePosition.offset);
        CGContextSetTextPosition(context, lineOrigin.x, lineOrigin.y);
        
        CTLineDraw(line, context);
    }
    
#else
    
    CGContextSetTextMatrix(context, CGAffineTransformIdentity);
    float offset = precalculatedLayout.drawingOffset.y;
    CGContextTranslateCTM(context, rect.origin.x, rect.origin.y + rect.size.height + offset + precalculatedLayout.drawingSize.height - rect.size.height);
    CGContextScaleCTM(context, 1.0f, -1.0f);
    
    CTFrameRef textFrame = precalculatedLayout.textFrame;
    if (textFrame == nil)
    {
        CGContextRestoreGState(context);
        
        #if TARGET_IPHONE_SIMULATOR
        TGLog(@"%s:%d: warning: textFrame is nil", __PRETTY_FUNCTION__, __LINE__);
        #endif
        return;
    }
    
    CFArrayRef lines = CTFrameGetLines(textFrame);
    NSInteger numberOfLines = CFArrayGetCount(lines);
    
    if (linesRange.length == 0)
        linesRange = NSMakeRange(0, numberOfLines);
    
    CGPoint lineOrigins[numberOfLines];
    CTFrameGetLineOrigins(textFrame, CFRangeMake(linesRange.location, linesRange.length), lineOrigins);
    
    const std::tr1::unordered_map<int, std::tr1::unordered_map<int, int> > *lineOffsets = precalculatedLayout.lineOffsets;
    const std::vector<float> *pLineOrigins = precalculatedLayout.lineOrigins;
    
    if ((!lineOffsets->empty() || !pLineOrigins->empty()))
    {
        int iLineInRange = 0;
        for (CFIndex lineIndex = linesRange.location; lineIndex < linesRange.location + linesRange.length; iLineInRange++, lineIndex++)
        {
            CGPoint lineOrigin = lineOrigins[iLineInRange];
            lineOrigin.y = pLineOrigins->at(lineIndex);
            
            CTLineRef line = (CTLineRef)CFArrayGetValueAtIndex(lines, lineIndex);
            CGContextSetTextPosition(context, lineOrigin.x, lineOrigin.y);
            
            std::tr1::unordered_map<int, std::tr1::unordered_map<int, int> >::const_iterator lineIt = lineOffsets->find(lineIndex);
            if (lineIt == lineOffsets->end())
            {
                CTLineDraw(line, context);
            }
            else
            {
                CFArrayRef glyphRuns = CTLineGetGlyphRuns(line);
                int glyphRunsCount = CFArrayGetCount(glyphRuns);
                for (int i = 0; i < glyphRunsCount; i++)
                {
                    CTRunRef run = (CTRunRef)CFArrayGetValueAtIndex(glyphRuns, i);
                    
                    int offset = 0;
                    std::tr1::unordered_map<int, int>::const_iterator runOffsetIt = lineIt->second.find(i);
                    if (runOffsetIt != lineIt->second.end())
                    {
                        offset = runOffsetIt->second;
                        if (offset != 0)
                            CGContextTranslateCTM(context, 0, offset);
                    }
                    
                    int glyphCount = CTRunGetGlyphCount(run);
                    CTRunDraw(run, context, CFRangeMake(0, glyphCount));
                    
                    if (offset != 0)
                        CGContextTranslateCTM(context, 0, -offset);
                }
            }
        }
    }
    else
    {
        if (linesRange.location == 0 && linesRange.location + linesRange.length == numberOfLines)
            CTFrameDraw(textFrame, context);
        else
        {
            for (CFIndex lineIndex = linesRange.location; lineIndex < linesRange.location + linesRange.length; lineIndex++)
            {
                CGPoint lineOrigin = lineOrigins[lineIndex];
                CGContextSetTextPosition(context, lineOrigin.x, lineOrigin.y);
                CTLineRef line = (CTLineRef)CFArrayGetValueAtIndex(lines, lineIndex);
                
                CTLineDraw(line, context);
            }
        }
    }
    
#endif

    CGContextRestoreGState(context);
}

@end
