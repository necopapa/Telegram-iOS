//
//  HPTextView.m
//
//  Created by Hans Pinckaers on 29-06-10.
//
//	MIT License
//
//	Copyright (c) 2011 Hans Pinckaers
//
//	Permission is hereby granted, free of charge, to any person obtaining a copy
//	of this software and associated documentation files (the "Software"), to deal
//	in the Software without restriction, including without limitation the rights
//	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//	copies of the Software, and to permit persons to whom the Software is
//	furnished to do so, subject to the following conditions:
//
//	The above copyright notice and this permission notice shall be included in
//	all copies or substantial portions of the Software.
//
//	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//	THE SOFTWARE.

#import "HPGrowingTextView.h"
#import "HPTextViewInternal.h"

@interface HPGrowingTextView(private)
-(void)commonInitialiser;
-(void)resizeTextView:(NSInteger)newSizeH;
-(void)growDidStop;
@end

@implementation HPGrowingTextView
@synthesize internalTextView;
@synthesize delegate;

@synthesize font;
@synthesize textColor;
@synthesize textAlignment; 
@synthesize selectedRange;
@synthesize editable;
@synthesize dataDetectorTypes; 
@synthesize animateHeightChange;
@synthesize returnKeyType;

@synthesize oneTimeLongAnimation = _oneTimeLongAnimation;

// having initwithcoder allows us to use HPGrowingTextView in a Nib. -- aob, 9/2011
- (id)initWithCoder:(NSCoder *)aDecoder
{
    if ((self = [super initWithCoder:aDecoder])) {
        [self commonInitialiser];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        [self commonInitialiser];
    }
    return self;
}

-(void)commonInitialiser
{
    // Initialization code
    CGRect r = self.frame;
    r.origin.y = 0;
    r.origin.x = 0;
    internalTextView = [[HPTextViewInternal alloc] initWithFrame:r];
    internalTextView.handleEditActions = true;
    internalTextView.delegate = self;
    internalTextView.scrollEnabled = NO;
    internalTextView.font = [UIFont systemFontOfSize:13]; 
    internalTextView.contentInset = UIEdgeInsetsZero;		
    internalTextView.showsHorizontalScrollIndicator = NO;
    internalTextView.text = @"-";
    [self addSubview:internalTextView];
    
    UIView *internal = (UIView*)[[internalTextView subviews] objectAtIndex:0];
    minHeight = (int)internal.frame.size.height;
    minNumberOfLines = 1;
    
    animateHeightChange = YES;
    
    internalTextView.text = @"";
    
    [self setMaxNumberOfLines:3];
}

-(void)sizeToFit
{
	CGRect r = self.frame;
    
    // check if the text is available in text view or not, if it is available, no need to set it to minimum lenth, it could vary as per the text length
    // fix from Ankit Thakur
    if ([self.text length] > 0) {
        return;
    } else {
        r.size.height = minHeight;
        self.frame = r;
    }
}

-(void)setFrame:(CGRect)aframe
{
	CGRect r = aframe;
	r.origin.y = 0;
	r.origin.x = contentInset.left;
    r.size.width -= contentInset.left + contentInset.right;
    
	internalTextView.frame = r;
	
	[super setFrame:aframe];
}

-(void)setContentInset:(UIEdgeInsets)inset
{
    contentInset = inset;
    
    CGRect r = self.frame;
    r.origin.y = inset.top - inset.bottom;
    r.origin.x = inset.left;
    r.size.width -= inset.left + inset.right;
    
    internalTextView.frame = r;
    
    [self setMaxNumberOfLines:maxNumberOfLines];
    [self setMinNumberOfLines:minNumberOfLines];
}

-(UIEdgeInsets)contentInset
{
    return contentInset;
}

-(void)setMaxNumberOfLines:(int)n
{
    // Use internalTextView for height calculations, thanks to Gwynne <http://blog.darkrainfall.org/>
    NSString *saveText = internalTextView.text, *newText = @"-";
    
    internalTextView.delegate = nil;
    internalTextView.hidden = YES;
    
    for (int i = 1; i < n; ++i)
        newText = [newText stringByAppendingString:@"\n|W|"];
    
    internalTextView.text = newText;
    
    maxHeight = (int)internalTextView.contentSize.height;
    
    internalTextView.text = saveText;
    internalTextView.hidden = NO;
    internalTextView.delegate = self;
    
    [self sizeToFit];
    
    maxNumberOfLines = n;
}

-(int)maxNumberOfLines
{
    return maxNumberOfLines;
}

-(void)setMinNumberOfLines:(int)m
{
	// Use internalTextView for height calculations, thanks to Gwynne <http://blog.darkrainfall.org/>
    NSString *saveText = internalTextView.text, *newText = @"-";
    
    internalTextView.delegate = nil;
    internalTextView.hidden = YES;
    
    for (int i = 1; i < m; ++i)
        newText = [newText stringByAppendingString:@"\n|W|"];
    
    internalTextView.text = newText;
    
    minHeight = (int)internalTextView.contentSize.height;
    
    internalTextView.text = saveText;
    internalTextView.hidden = NO;
    internalTextView.delegate = self;
    
    [self sizeToFit];
    
    minNumberOfLines = m;
}

-(int)minNumberOfLines
{
    return minNumberOfLines;
}


- (void)textViewDidChange:(UITextView *)__unused textView
{	
	//size of content, so we can set the frame of self
	NSInteger newSizeH = (int)internalTextView.contentSize.height;
	if(newSizeH < minHeight || !internalTextView.hasText) newSizeH = minHeight; //not smalles than minHeight
    
    if (newSizeH > 36 && newSizeH < 42)
        newSizeH = 36;
    
	if (internalTextView.frame.size.height != newSizeH)
	{
        // [fixed] Pasting too much text into the view failed to fire the height change, 
        // thanks to Gwynne <http://blog.darkrainfall.org/>
        
        if (newSizeH > maxHeight && internalTextView.frame.size.height <= maxHeight)
        {
            newSizeH = maxHeight;
        }
        
		if (newSizeH <= maxHeight && (int)newSizeH != (int)self.frame.size.height)
		{
            if(animateHeightChange)
            {    
                float animationDuration = 0.15f;

                if (_oneTimeLongAnimation)
                {
                    _oneTimeLongAnimation = false;
                    animationDuration = 0.3f * 0.7f;
                }
                

                [UIView animateWithDuration:animationDuration delay:0 options:(UIViewAnimationOptionAllowUserInteraction| UIViewAnimationOptionBeginFromCurrentState) animations:^
                {
                    [self resizeTextView:newSizeH];
                } completion:^(__unused BOOL finished)
                {
                    if ([delegate respondsToSelector:@selector(growingTextView:didChangeHeight:)])
                    {
                        [delegate growingTextView:self didChangeHeight:newSizeH];
                    }
                }];
            }
            else
            {
                [self resizeTextView:newSizeH];                
                // [fixed] The growingTextView:didChangeHeight: delegate method was not called at all when not animating height changes.
                // thanks to Gwynne <http://blog.darkrainfall.org/>
                
                if ([delegate respondsToSelector:@selector(growingTextView:didChangeHeight:)])
                {
                    [delegate growingTextView:self didChangeHeight:newSizeH];
                }	
            }
		}
		
        
        // if our new height is greater than the maxHeight
        // sets not set the height or move things
        // around and enable scrolling
		if (newSizeH >= maxHeight)
		{
			if(!internalTextView.scrollEnabled)
            {
				internalTextView.scrollEnabled = YES;
				[internalTextView flashScrollIndicators];

                if (internalTextView.isFirstResponder)
                {
                    [self scrollToCaret];
                }
			}
			
		} else
        {
			internalTextView.scrollEnabled = NO;
		}
	}
	
	
	if ([delegate respondsToSelector:@selector(growingTextViewDidChange:)])
    {
		[delegate growingTextViewDidChange:self];
	}
	
    _oneTimeLongAnimation = false;
}

- (void)softSetMaxNumberOfLines:(int)value
{
    maxNumberOfLines = value;
}

- (void)scrollToCaret
{
    if (internalTextView.selectedTextRange != nil)
    {
        UITextPosition *position = internalTextView.selectedTextRange.start;
        if (position != nil)
        {
            CGRect rect = [internalTextView caretRectForPosition:position];
            if (!CGRectIsInfinite(rect) && !CGRectIsNull(rect))
            {
                rect.origin.y -= 8;
                rect.size.height += 16;
                [internalTextView scrollRectToVisible:rect animated:false];
                
                if (internalTextView.contentOffset.y > internalTextView.contentSize.height - internalTextView.frame.size.height)
                    internalTextView.contentOffset = CGPointMake(0, internalTextView.contentSize.height - internalTextView.frame.size.height);
                if (internalTextView.contentOffset.y < 0)
                    internalTextView.contentOffset = CGPointZero;
            }
        }
    }
}

-(void)resizeTextView:(NSInteger)newSizeH
{
    if ([delegate respondsToSelector:@selector(growingTextView:willChangeHeight:)]) {
        [delegate growingTextView:self willChangeHeight:newSizeH];
    }
    
    CGRect internalTextViewFrame = self.frame;
    internalTextViewFrame.size.height = newSizeH; // + padding
    self.frame = internalTextViewFrame;
    
    internalTextViewFrame.origin.y = contentInset.top - contentInset.bottom;
    internalTextViewFrame.origin.x = contentInset.left;
    internalTextViewFrame.size.width = internalTextView.contentSize.width;
    
    internalTextView.frame = internalTextViewFrame;
}

-(void)growDidStop
{
	if ([delegate respondsToSelector:@selector(growingTextView:didChangeHeight:)]) {
		[delegate growingTextView:self didChangeHeight:self.frame.size.height];
	}
	
}

-(void)touchesEnded:(NSSet *)__unused touches withEvent:(UIEvent *)__unused event
{
    [internalTextView becomeFirstResponder];
}

- (BOOL)isFirstResponder
{
    return [internalTextView isFirstResponder];
}

- (BOOL)becomeFirstResponder
{
    return [internalTextView becomeFirstResponder];
}

-(BOOL)resignFirstResponder
{
	return [internalTextView resignFirstResponder];
}

- (void)dealloc {
	[internalTextView release];
    [super dealloc];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark UITextView properties
///////////////////////////////////////////////////////////////////////////////////////////////////

-(void)setText:(NSString *)newText
{
    internalTextView.text = newText;
    
    // include this line to analyze the height of the textview.
    // fix from Ankit Thakur
    [self performSelector:@selector(textViewDidChange:) withObject:internalTextView];
}

-(NSString*) text
{
    return internalTextView.text;
}

///////////////////////////////////////////////////////////////////////////////////////////////////

-(void)setFont:(UIFont *)afont
{
	internalTextView.font= afont;
	
	[self setMaxNumberOfLines:maxNumberOfLines];
	[self setMinNumberOfLines:minNumberOfLines];
}

-(UIFont *)font
{
	return internalTextView.font;
}

///////////////////////////////////////////////////////////////////////////////////////////////////

-(void)setTextColor:(UIColor *)color
{
	internalTextView.textColor = color;
}

-(UIColor*)textColor{
	return internalTextView.textColor;
}

///////////////////////////////////////////////////////////////////////////////////////////////////

-(void)setTextAlignment:(UITextAlignment)aligment
{
	internalTextView.textAlignment = aligment;
}

-(UITextAlignment)textAlignment
{
	return (UITextAlignment)internalTextView.textAlignment;
}

///////////////////////////////////////////////////////////////////////////////////////////////////

-(void)setSelectedRange:(NSRange)range
{
	internalTextView.selectedRange = range;
}

-(NSRange)selectedRange
{
	return internalTextView.selectedRange;
}

///////////////////////////////////////////////////////////////////////////////////////////////////

-(void)setEditable:(BOOL)beditable
{
	internalTextView.editable = beditable;
}

-(BOOL)isEditable
{
	return internalTextView.editable;
}

///////////////////////////////////////////////////////////////////////////////////////////////////

-(void)setReturnKeyType:(UIReturnKeyType)keyType
{
	internalTextView.returnKeyType = keyType;
}

-(UIReturnKeyType)returnKeyType
{
	return internalTextView.returnKeyType;
}

///////////////////////////////////////////////////////////////////////////////////////////////////

-(void)setDataDetectorTypes:(UIDataDetectorTypes)datadetector
{
	internalTextView.dataDetectorTypes = datadetector;
}

-(UIDataDetectorTypes)dataDetectorTypes
{
	return internalTextView.dataDetectorTypes;
}

///////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)hasText{
	return [internalTextView hasText];
}

- (void)scrollRangeToVisible:(NSRange)range
{
	[internalTextView scrollRangeToVisible:range];
}

/////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark UITextViewDelegate


///////////////////////////////////////////////////////////////////////////////////////////////////
- (BOOL)textViewShouldBeginEditing:(UITextView *)__unused textView {
	if ([delegate respondsToSelector:@selector(growingTextViewShouldBeginEditing:)]) {
		return [delegate growingTextViewShouldBeginEditing:self];
		
	} else {
		return YES;
	}
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (BOOL)textViewShouldEndEditing:(UITextView *)__unused textView {
	if ([delegate respondsToSelector:@selector(growingTextViewShouldEndEditing:)]) {
		return [delegate growingTextViewShouldEndEditing:self];
		
	} else {
		return YES;
	}
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)textViewDidBeginEditing:(UITextView *)__unused textView {
	if ([delegate respondsToSelector:@selector(growingTextViewDidBeginEditing:)]) {
		[delegate growingTextViewDidBeginEditing:self];
	}
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)textViewDidEndEditing:(UITextView *)__unused textView {
	if ([delegate respondsToSelector:@selector(growingTextViewDidEndEditing:)]) {
		[delegate growingTextViewDidEndEditing:self];
	}
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)__unused range
 replacementText:(NSString *)atext {
	
	//weird 1 pixel bug when clicking backspace when textView is empty
	if(![textView hasText] && [atext isEqualToString:@""]) return NO;
	
	if ([atext isEqualToString:@"\n"]) {
		if ([delegate respondsToSelector:@selector(growingTextViewShouldReturn:)])
        {   
			if (![delegate growingTextViewShouldReturn:self])
            {
				return YES;
			} else {
				[textView resignFirstResponder];
				return NO;
			}
		}
	}
	
	return YES;
	
    
}

- (void)textViewDidChangeSelection:(UITextView *)__unused textView
{
}

@end
