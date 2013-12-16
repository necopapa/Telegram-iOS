

#import <UIKit/UIKit.h>

#import "HPTextViewInternal.h"

@class HPGrowingTextView;
@class HPTextViewInternal;

@protocol HPGrowingTextViewDelegate

@optional

- (BOOL)growingTextViewShouldBeginEditing:(HPGrowingTextView *)growingTextView;
- (BOOL)growingTextViewShouldEndEditing:(HPGrowingTextView *)growingTextView;

- (void)growingTextViewDidBeginEditing:(HPGrowingTextView *)growingTextView;
- (void)growingTextViewDidEndEditing:(HPGrowingTextView *)growingTextView;

- (BOOL)growingTextView:(HPGrowingTextView *)growingTextView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text;
- (void)growingTextViewDidChange:(HPGrowingTextView *)growingTextView;

- (void)growingTextView:(HPGrowingTextView *)growingTextView willChangeHeight:(float)height;
- (void)growingTextView:(HPGrowingTextView *)growingTextView didChangeHeight:(float)height;

- (BOOL)growingTextViewShouldReturn:(HPGrowingTextView *)growingTextView;

- (void)growingTextView:(HPGrowingTextView *)growingTextView didPasteImages:(NSArray *)images;

@end

@interface HPGrowingTextView : UIView <UITextViewDelegate>
{
	HPTextViewInternal *internalTextView;	
	
	int minHeight;
	int maxHeight;
	
	//class properties
	int maxNumberOfLines;
	int minNumberOfLines;
	
	//uitextview properties
	NSObject <HPGrowingTextViewDelegate> *delegate;
	NSString *text;
	UIFont *font;
	UIColor *textColor;
	UITextAlignment textAlignment; 
	NSRange selectedRange;
	BOOL editable;
	UIDataDetectorTypes dataDetectorTypes;
	UIReturnKeyType returnKeyType;
    
    UIEdgeInsets contentInset;
}

//real class properties
@property (nonatomic) int maxNumberOfLines;
@property (nonatomic) int minNumberOfLines;
@property (nonatomic) BOOL animateHeightChange;
@property (nonatomic, retain) HPTextViewInternal *internalTextView;

@property (nonatomic) bool oneTimeLongAnimation;

//uitextview properties
@property(nonatomic, assign) NSObject<HPGrowingTextViewDelegate> *delegate;
@property(nonatomic,assign) NSString *text;
@property(nonatomic,assign) UIFont *font;
@property(nonatomic,assign) UIColor *textColor;
@property(nonatomic) UITextAlignment textAlignment;    // default is UITextAlignmentLeft
@property(nonatomic) NSRange selectedRange;            // only ranges of length 0 are supported
@property(nonatomic,getter=isEditable) BOOL editable;
@property(nonatomic) UIDataDetectorTypes dataDetectorTypes __OSX_AVAILABLE_STARTING(__MAC_NA, __IPHONE_3_0);
@property (nonatomic, assign) UIReturnKeyType returnKeyType;
@property (nonatomic, assign) UIEdgeInsets contentInset;

//uitextview methods
//need others? use .internalTextView
- (BOOL)becomeFirstResponder;
- (BOOL)resignFirstResponder;

- (BOOL)hasText;
- (void)scrollRangeToVisible:(NSRange)range;

- (void)scrollToCaret;
- (void)softSetMaxNumberOfLines:(int)maxNumberOfLines;

@end
