#import "TGTextInputView.h"


@interface TGTextInputView ()

@property (nonatomic) UITextView *textView;

@end

@implementation TGTextInputView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        _textView = [[UITextView alloc] initWithFrame:self.bounds];
        [self addSubview:_textView];
    }
    return self;
}

@end
