#import "TGLayoutTextItem.h"

@implementation TGLayoutTextItem

@synthesize text = _text;
@synthesize font = _font;
@synthesize textColor = _textColor;
@synthesize shadowColor = _shadowColor;
@synthesize highlightedTextColor = _highlightedTextColor;
@synthesize highlightedShadowColor = _highlightedShadowColor;
@synthesize shadowOffset = _shadowOffset;
@synthesize numberOfLines = _numberOfLines;
@synthesize textAlignment = _textAlignment;

@synthesize manualDrawing = _manualDrawing;

@synthesize flags = _flags;

@synthesize richText = _richText;
@synthesize coreTextFont = _coreTextFont;
@synthesize precalculatedLayout = _precalculatedLayout;

- (id)initWithText:(NSString *)text font:(UIFont *)font textColor:(UIColor *)textColor shadowColor:(UIColor *)shadowColor highlightedTextColor:(UIColor *)highlightedTextColor highlightedShadowColor:(UIColor *)highlightedShadowColor shadowOffset:(CGSize)shadowOffset richText:(bool)richText
{
    self = [super initWithType:TGLayoutItemTypeText];
    if (self != nil)
    {
        _text = text;
        _font = font;
        _textColor = textColor;
        _shadowColor = shadowColor;
        _highlightedTextColor = highlightedTextColor;
        _highlightedShadowColor = highlightedShadowColor;
        _shadowOffset = shadowOffset;
        
        _richText = richText;
    }
    return self;
}

- (id)initWithRichText:(NSString *)text font:(CTFontRef)font textColor:(UIColor *)textColor shadowColor:(UIColor *)shadowColor shadowOffset:(CGSize)shadowOffset
{
    self = [super initWithType:TGLayoutItemTypeText];
    if (self != nil)
    {
        _text = text;
        if (font != nil)
            _coreTextFont = CFRetain(font);
        _textColor = textColor;
        _shadowColor = shadowColor;
        _shadowOffset = shadowOffset;
        
        _richText = true;
    }
    return self;
}

- (void)dealloc
{
    if (_coreTextFont != nil)
        CFRelease(_coreTextFont);
}

@end
