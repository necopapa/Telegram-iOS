#import "TGPhoneItemCell.h"

#import "TGLabel.h"

#import "TGImageUtils.h"
#import "TGStringUtils.h"

#import "TGHighlightTriggerLabel.h"
#import "TGTextField.h"

#import "TGActionTableView.h"

#define TG_DELETE_BUTTON_EDGE_OFFSET 16

static UIImage *normalMinusImage()
{
    static UIImage *image = nil;
    if (image == nil)
    {
        image = [UIImage imageNamed:@"ListEditingSwitchMinus.png"];
    }
    return image;
}

static UIImage *activeMinusImage()
{
    static UIImage *image = nil;
    if (image == nil)
    {
        image = [UIImage imageNamed:@"ListEditingSwitchMinus_Active.png"];
    }
    return image;
}

static UIImage *deleteButtonImage()
{
    static UIImage *image = nil;
    if (image == nil)
    {
        UIImage *rawImage = [UIImage imageNamed:@"ListDeleteButton.png"];
        image = [rawImage stretchableImageWithLeftCapWidth:(int)(rawImage.size.width / 2) topCapHeight:0];
    }
    return image;
}

static UIImage *deleteButtonHighlightedImage()
{
    static UIImage *image = nil;
    if (image == nil)
    {
        UIImage *rawImage = [UIImage imageNamed:@"ListDeleteButton_Highlighted.png"];
        image = [rawImage stretchableImageWithLeftCapWidth:(int)(rawImage.size.width / 2) topCapHeight:0];
    }
    return image;
}


@interface TGPhoneItemCell () <TGActionTableViewCell, UITextFieldDelegate>

@property (nonatomic) bool isMainPhone;

@property (nonatomic, strong) TGLabel *labelView;
@property (nonatomic, strong) TGLabel *phoneView;
@property (nonatomic, strong) UIImageView *editingLineView;

@property (nonatomic, strong) TGTextField *textField;

@property (nonatomic) bool editingIsActive;
@property (nonatomic, strong) UIButton *switchButton;
@property (nonatomic, strong) UIImageView *switchButtonMinus;
@property (nonatomic, strong) UIButton *editingButton;
@property (nonatomic, strong) UIImageView *editingButtonLabel;

@property (nonatomic, strong) TGHighlightTriggerLabel *highlightTrigger;

@end

@implementation TGPhoneItemCell

@synthesize watcherHandle = _watcherHandle;

@synthesize label = _label;
@synthesize phone = _phone;

@synthesize isMainPhone = _isMainPhone;

@synthesize labelView = _labelView;
@synthesize phoneView = _phoneView;
@synthesize editingLineView = _editingLineView;

@synthesize textField = _textField;

@synthesize editingIsActive = _editingIsActive;
@synthesize switchButton = _switchButton;
@synthesize switchButtonMinus = _switchButtonMinus;
@synthesize editingButton = _editingButton;
@synthesize editingButtonLabel = _editingButtonLabel;

@synthesize highlightTrigger = _highlightTrigger;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self)
    {
        static UIImage *lineImage = nil;
        static UIImage *lineHighlightedImage = nil;
        static dispatch_once_t onceToken1;
        dispatch_once(&onceToken1, ^
        {
            lineImage = [UIImage imageNamed:@"GroupedCellVerticalSeparator.png"];
            lineHighlightedImage = [UIImage imageNamed:@"GroupedCellVerticalSeparator_Highlighted.png"];
        });
        
        _editingLineView = [[UIImageView alloc] initWithImage:lineImage highlightedImage:lineHighlightedImage];
        _editingLineView.frame = CGRectMake(72, 0, 1, 1);
        _editingLineView.hidden = true;
        _editingLineView.alpha = 0.0f;
        _editingLineView.autoresizingMask = UIViewAutoresizingFlexibleHeight;
        [self.contentView addSubview:_editingLineView];
        
        _labelView = [[TGLabel alloc] initWithFrame:CGRectMake(4, 13, 62, 16)];
        _labelView.textAlignment = UITextAlignmentRight;
        _labelView.font = [UIFont boldSystemFontOfSize:13];
        _labelView.backgroundColor = [UIColor whiteColor];
        _labelView.textColor = UIColorRGB(0x5d708f);
        _labelView.highlightedTextColor = [UIColor whiteColor];
        [self.contentView addSubview:_labelView];
        
        _phoneView = [[TGLabel alloc] initWithFrame:CGRectMake(78, 11, self.contentView.frame.size.width - 80, 20)];
        _phoneView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _phoneView.font = [UIFont boldSystemFontOfSize:15];
        _phoneView.backgroundColor = [UIColor whiteColor];
        _phoneView.textColor = [UIColor blackColor];
        _phoneView.highlightedTextColor = [UIColor whiteColor];
        _phoneView.userInteractionEnabled = false;
        [self.contentView addSubview:_phoneView];
        
        _textField = [[TGTextField alloc] initWithFrame:CGRectMake(78, 11, self.contentView.frame.size.width - 80, 20)];
        _textField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _textField.font = _phoneView.font;
        _textField.textColor = _phoneView.textColor;
        _textField.normalTextColor = _phoneView.textColor;
        _textField.highlightedTextColor = [UIColor whiteColor];
        _textField.normalPlaceholderColor = UIColorRGB(0xb3b3b3);
        _textField.placeholderFont = _phoneView.font;
        _textField.placeholderColor = _textField.normalPlaceholderColor;
        _textField.highlightedTextColor = [UIColor whiteColor];
        _textField.highlightedPlaceholderColor = _textField.highlightedTextColor;
        _textField.clearButtonMode = UITextFieldViewModeWhileEditing;
        _textField.keyboardType = UIKeyboardTypePhonePad;
        _textField.hidden = true;
        _textField.placeholder = TGLocalized(@"Profile.InputPhonePlaceholder");
        _textField.delegate = self;
        [self.contentView addSubview:_textField];
        
        _highlightTrigger = [[TGHighlightTriggerLabel alloc] init];
        _highlightTrigger.advanced = true;
        _highlightTrigger.targetViews = [[NSArray alloc] initWithObjects:_textField, nil];
        [self.contentView addSubview:_highlightTrigger];
        
        static UIImage *switchButtonImage = nil;
        static UIImage *deleteTextImage = nil;
        
        static dispatch_once_t onceToken2;
        dispatch_once(&onceToken2, ^
        {
            switchButtonImage = [UIImage imageNamed:@"ListEditingSwitch.png"];
            
            UIFont *font = [UIFont boldSystemFontOfSize:13];
            CGSize size = [TGLocalized(@"Common.ListDelete") sizeWithFont:font];
            size.width = (int)size.width + 2;
            UIGraphicsBeginImageContextWithOptions(size, false, 0.0f);
            
            CGContextRef context = UIGraphicsGetCurrentContext();
            CGContextSetShadowWithColor(context, CGSizeMake(0, -1), 0.0f, UIColorRGBA(0xa30f0a, 0.2f).CGColor);
            CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
            
            [TGLocalized(@"Common.ListDelete") drawInRect:CGRectMake(1, 0, size.width, size.height) withFont:font];
            
            deleteTextImage = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
        });
        
        _switchButton = [[UIButton alloc] initWithFrame:CGRectMake(-23, 6, 30, 30)];
        _switchButton.exclusiveTouch = true;
        _switchButton.hidden = true;
        _switchButton.alpha = 0.0f;
        _switchButton.adjustsImageWhenHighlighted = false;
        _switchButton.adjustsImageWhenDisabled = false;
        [_switchButton setBackgroundImage:switchButtonImage forState:UIControlStateNormal];
        [_switchButton addTarget:self action:@selector(switchButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_switchButton];
        
        _switchButtonMinus = [[UIImageView alloc] initWithImage:normalMinusImage()];
        _switchButtonMinus.center = CGPointMake(15, 14);
        [_switchButton addSubview:_switchButtonMinus];
        
        _editingButton = [[UIButton alloc] init];
        _editingButton.exclusiveTouch = true;
        _editingButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        [_editingButton setBackgroundImage:deleteButtonImage() forState:UIControlStateNormal];
        [_editingButton setBackgroundImage:deleteButtonHighlightedImage() forState:UIControlStateHighlighted];
        
        [_editingButton addTarget:self action:@selector(deleteButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        
        _editingButton.frame = CGRectMake(self.frame.size.width - TG_DELETE_BUTTON_EDGE_OFFSET - 61, 7 - (TGIsRetina() ? 0.5f : 0.0f), 61, 31);
        _editingButton.hidden = true;
        _editingButton.clipsToBounds = true;
        _editingButton.alpha = 0.0f;
        
        UIImageView *deleteTextView = [[UIImageView alloc] initWithImage:deleteTextImage];
        deleteTextView.frame = CGRectOffset(deleteTextView.frame, floorf((_editingButton.frame.size.width - deleteTextView.frame.size.width) / 2), 7);
        deleteTextView.contentMode = UIViewContentModeLeft;
        deleteTextView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        _editingButtonLabel = deleteTextView;
        [_editingButton addSubview:deleteTextView];
        
        _editingButton.frame = CGRectMake(self.frame.size.width - TG_DELETE_BUTTON_EDGE_OFFSET - 2, _editingButton.frame.origin.y, 2, _editingButton.frame.size.height);
        
        [self addSubview:_editingButton];
    }
    return self;
}

- (void)dealloc
{
    _textField.delegate = nil;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    if (self.editing && !_editingIsActive)
    {
        if (CGRectContainsPoint(self.bounds, point))
        {
            CGRect contentFrame = self.contentView.frame;
            
            if (point.x - contentFrame.origin.x < _textField.frame.origin.x)
                return [super hitTest:point withEvent:event];
            
            CGRect textFieldFrame = _textField.frame;
            UIView *fieldResult = [_textField hitTest:CGPointMake(point.x - contentFrame.origin.x - textFieldFrame.origin.x, point.y - contentFrame.origin.y - textFieldFrame.origin.y) withEvent:event];
            if (fieldResult != nil)
                return fieldResult;
        }
        
        return nil;
    }

    return [super hitTest:point withEvent:event];
}

- (void)setLabel:(NSString *)label
{
    _label = label;
    _labelView.text = label;
}

- (void)setPhone:(NSString *)phone
{
    _phone = phone;
    _phoneView.text = phone;
    if (_textField != nil)
        _textField.text = phone;
}

- (void)setIsMainPhone:(bool)isMainPhone
{
    _isMainPhone = isMainPhone;
    
    if (isMainPhone)
    {
        _phoneView.textColor = UIColorRGB(0x347fd4);
        _textField.textColor = UIColorRGB(0x347fd4);
    }
    else
    {
        _phoneView.textColor = [UIColor blackColor];
        _textField.textColor = [UIColor blackColor];
    }
}

- (void)setDisabled:(bool)disabled
{
    if (disabled)
    {
        _phoneView.textColor = UIColorRGB(0xaaaaaa);
        _textField.textColor = UIColorRGB(0xaaaaaa);
        _phoneView.text = TGLocalized(@"Profile.PhoneHidden");
    }
    
    self.userInteractionEnabled = !disabled;
}

#pragma mark -

- (void)setGroupedCellPosition:(int)groupedCellPosition
{
    float lineStartY = 0;
    float lineEndY = self.contentView.frame.size.height;
    if (groupedCellPosition & TGGroupedCellPositionFirst)
        lineStartY += 0.0f;
    if (groupedCellPosition & TGGroupedCellPositionLast)
        lineEndY -= 1.0f;
    
    CGRect frame = _editingLineView.frame;
    frame.origin.y = lineStartY;
    frame.size.height = lineEndY - lineStartY;
    _editingLineView.frame = frame;
    
    [super setGroupedCellPosition:groupedCellPosition];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated
{
    [super setEditing:editing animated:animated];
    
    if (editing)
    {
        _textField.hidden = false;
        _phoneView.hidden = true;
        
        _switchButton.hidden = false;
        _editingLineView.hidden = false;
        
        CGRect frame = _switchButton.frame;
        frame.origin.x = 7;
        
        if (animated)
        {
            [UIView animateWithDuration:0.3 delay:0 options:0 animations:^
            {
                _switchButton.frame = frame;
                _switchButton.alpha = _textField.text.length == 0 ? 0.0f : 1.0f;
                _editingLineView.alpha = 1.0f;
            } completion:nil];
        }
        else
        {
            _switchButton.frame = frame;
            _switchButton.alpha = _textField.text.length == 0 ? 0.0f : 1.0f;
            _editingLineView.alpha = 1.0f;
        }
    }
    else
    {
        if ([_textField isFirstResponder])
        {
            if ([self textFieldShouldEndEditing:_textField])
                [_textField resignFirstResponder];
        }
        
        CGRect frame = _switchButton.frame;
        frame.origin.x = -23;
        
        float textAlpha = 1.0f;
        
        if (animated)
        {
            [UIView animateWithDuration:0.3 delay:0 options:0 animations:^
            {
                if (ABS(_textField.alpha - textAlpha) > FLT_EPSILON)
                    _textField.alpha = textAlpha;
                
                if (ABS(_labelView.alpha - textAlpha) > FLT_EPSILON)
                    _labelView.alpha = textAlpha;
                
                _switchButton.alpha = 0.0f;
                _switchButton.frame = frame;
                
                _editingLineView.alpha = 0.0f;
            } completion:^(BOOL finished)
            {
                if (finished)
                {
                    _textField.hidden = true;
                    _phoneView.hidden = false;
                    
                    _switchButton.hidden = true;
                    
                    _editingLineView.hidden = true;
                    
                    if (_editingIsActive)
                    {
                        _editingIsActive = false;
                        _switchButtonMinus.transform = CGAffineTransformIdentity;
                        _switchButtonMinus.center = CGPointMake(15, 14);
                        _switchButtonMinus.image = normalMinusImage();
                    }
                }
            }];
        }
        else
        {
            if (ABS(_textField.alpha - textAlpha) > FLT_EPSILON)
                _textField.alpha = textAlpha;
            
            if (ABS(_labelView.alpha - textAlpha) > FLT_EPSILON)
                _labelView.alpha = textAlpha;
            
            _textField.hidden = true;
            _phoneView.hidden = false;
            
            _switchButton.alpha = 0.0f;
            _switchButton.frame = frame;
            _switchButton.hidden = true;
            
            _editingLineView.alpha = 0.0f;
            _editingLineView.hidden = true;
            
            if (_editingIsActive)
            {
                _editingIsActive = false;
                _switchButtonMinus.transform = CGAffineTransformIdentity;
                _switchButtonMinus.center = CGPointMake(15, 14);
                _switchButtonMinus.image = normalMinusImage();
            }
        }
    }
}

- (void)resetView
{
    if (_editingIsActive)
    {
        _editingIsActive = false;
        _switchButtonMinus.transform = CGAffineTransformIdentity;
        _switchButtonMinus.center = CGPointMake(15, 14);
        _switchButtonMinus.image = normalMinusImage();
    }
    
    if (_editingButton.alpha > FLT_EPSILON)
    {
        _editingButton.alpha = 0.0f;
        _editingButton.hidden = true;
        _editingButton.frame = CGRectMake(self.frame.size.width - TG_DELETE_BUTTON_EDGE_OFFSET - 2, _editingButton.frame.origin.y, 2, _editingButton.frame.size.height);
    }
}

- (bool)hasFocus
{
    return _textField.isFirstResponder;
}

- (void)requestFocus
{
    [_textField becomeFirstResponder];
}

- (void)deleteButtonPressed
{
    if ([self.superview isKindOfClass:[TGActionTableView class]] && [(TGActionTableView *)self.superview actionCell] == self)
        [(TGActionTableView *)self.superview setActionCell:nil];
    
    UITableView *tableView = (UITableView *)self.superview;
    if ([tableView isKindOfClass:[UITableView class]])
    {
        id<UITableViewDelegate> delegate = tableView.delegate;
        if (delegate != nil && [delegate conformsToProtocol:@protocol(TGActionTableViewDelegate)])
        {
            [(id<TGActionTableViewDelegate>)delegate commitAction:self];
        }
    }
}

- (void)switchButtonPressed
{
    bool editingWasActive = _editingIsActive;
    _editingIsActive = !editingWasActive;
    
    [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^
     {
         if (editingWasActive)
         {
             _switchButtonMinus.image = normalMinusImage();
             _switchButtonMinus.transform = CGAffineTransformIdentity;
             _switchButtonMinus.center = CGPointMake(15, 14);
         }
         else
         {
             _switchButtonMinus.image = activeMinusImage();
             _switchButtonMinus.transform = CGAffineTransformMakeRotation((float)(-M_PI_2));
             _switchButtonMinus.center = CGPointMake(14.5f, 14.5f);
         }
     } completion:nil];
    
    if (editingWasActive)
    {
        [self animateDeleteButton:false];
        
        if ([self.superview isKindOfClass:[TGActionTableView class]] && [(TGActionTableView *)self.superview actionCell] == self)
            [(TGActionTableView *)self.superview setActionCell:nil];
    }
    else
        [self animateDeleteButton:true];
}

- (void)animateDeleteButton:(bool)show
{
    const float edgeDistance = TG_DELETE_BUTTON_EDGE_OFFSET;
    
    if (show && _editingButton.alpha < 1.0f - FLT_EPSILON)
    {
        _editingButton.hidden = false;
        _editingButton.frame = CGRectMake(self.frame.size.width - edgeDistance - 2, _editingButton.frame.origin.y, 2, _editingButton.frame.size.height);
        _editingButtonLabel.alpha = 0.0f;
        
        [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^
         {
             _editingButton.alpha = 1.0f;
             _editingButton.frame = CGRectMake(self.frame.size.width - edgeDistance - 61, _editingButton.frame.origin.y, 61, _editingButton.frame.size.height);
             _editingButtonLabel.alpha = 1.0f;
         } completion:nil];
        
        if ([self.superview isKindOfClass:[TGActionTableView class]])
            [(TGActionTableView *)self.superview setActionCell:self];
    }
    else if (!show && _editingButton.alpha > FLT_EPSILON)
    {
        [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^
         {
             _editingButton.alpha = 0.0f;
             _editingButton.frame = CGRectMake(self.frame.size.width - edgeDistance - 2, _editingButton.frame.origin.y, 2, _editingButton.frame.size.height);
             _editingButtonLabel.alpha = 0.0f;
         } completion:^(BOOL finished)
         {
             if (finished)
             {
                 _editingButton.hidden = true;
             }
         }];
    }
}

- (void)dismissEditingControls:(bool)animated
{
    if (animated)
    {
        if (_editingButton.alpha > FLT_EPSILON)
        {
            [UIView animateWithDuration:0.3 animations:^
            {
                _editingButton.alpha = 0.0f;
            } completion:^(BOOL finished)
            {
                if (finished)
                {
                    _editingButton.hidden = true;
                    _editingButton.frame = CGRectMake(self.frame.size.width - TG_DELETE_BUTTON_EDGE_OFFSET - 2, _editingButton.frame.origin.y, 2, _editingButton.frame.size.height);
                }
            }];
        }
        
        if (_editingIsActive)
        {
            _editingIsActive = false;
            _switchButtonMinus.image = normalMinusImage();
            
            [UIView animateWithDuration:0.3 animations:^
            {
                _switchButtonMinus.transform = CGAffineTransformIdentity;
                _switchButtonMinus.center = CGPointMake(15, 14);
            }];
        }
    }
    else
    {
        if (_editingButton.alpha > FLT_EPSILON)
        {
            _editingButton.alpha = 0.0f;
            _editingButton.hidden = true;
            _editingButton.frame = CGRectMake(self.frame.size.width - TG_DELETE_BUTTON_EDGE_OFFSET - 2, _editingButton.frame.origin.y, 2, _editingButton.frame.size.height);
        }
        
        if (_editingIsActive)
        {
            _editingIsActive = false;
            _switchButtonMinus.transform = CGAffineTransformIdentity;
            _switchButtonMinus.center = CGPointMake(15, 14);
            _switchButtonMinus.image = normalMinusImage();
        }
    }
}

- (void)fadeOutEditingControls
{
    [UIView animateWithDuration:0.3 animations:^
    {
        _switchButton.alpha = 0.0f;
    }];
}

- (void)focusOnTextField:(UITapGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateRecognized && self.editing && !_textField.isFirstResponder)
    {
        [_textField becomeFirstResponder];
    }
}

- (BOOL)textFieldShouldBeginEditing:(UITextField *)__unused textField
{
    dispatch_async(dispatch_get_main_queue(), ^
    {
        id<ASWatcher> watcher = _watcherHandle.delegate;
        if (watcher != nil && [watcher respondsToSelector:@selector(actionStageActionRequested:options:)])
            [watcher actionStageActionRequested:@"phoneItemReceivedFocus" options:[[NSDictionary alloc] initWithObjectsAndKeys:self, @"cell", nil]];
    });
    
    return true;
}

- (BOOL)textFieldShouldEndEditing:(UITextField *)__unused textField
{
    return true;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)replacementString
{
    unichar rawNewString[replacementString.length];
    int rawNewStringLength = 0;
    
    int replacementLength = replacementString.length;
    for (int i = 0; i < replacementLength; i++)
    {
        unichar c = [replacementString characterAtIndex:i];
        if (c == '+' || (c >= '0' && c <= '9'))
            rawNewString[rawNewStringLength++] = c;
    }
    
    NSString *string = [[NSString alloc] initWithCharacters:rawNewString length:rawNewStringLength];
    
    NSMutableString *rawText = [[NSMutableString alloc] initWithCapacity:16];
    NSString *currentText = textField.text;
    int length = currentText.length;
    
    int originalLocation = range.location;
    int originalEndLocation = range.location + range.length;
    int endLocation = originalEndLocation;
    
    for (int i = 0; i < length; i++)
    {
        unichar c = [currentText characterAtIndex:i];
        if (c == '+' || (c >= '0' && c <= '9'))
            [rawText appendString:[[NSString alloc] initWithCharacters:&c length:1]];
        else
        {
            if (originalLocation > i)
            {
                if (range.location > 0)
                    range.location--;
            }
            
            if (originalEndLocation > i)
                endLocation--;
        }
    }
    
    int newLength = endLocation - range.location;
    if (newLength == 0 && range.length == 1 && range.location > 0)
    {
        range.location--;
        newLength = 1;
    }
    if (newLength < 0)
        return false;
    
    range.length = newLength;
    
    @try
    {
        //caretPosition += string.length;
        int caretPosition = range.location + string.length;
        
        [rawText replaceCharactersInRange:range withString:string];
        
        NSString *formattedText = [TGStringUtils formatPhone:rawText forceInternational:false];
        int formattedTextLength = formattedText.length;
        int rawTextLength = rawText.length;
        
        int newCaretPosition = caretPosition;
        
        for (int j = 0, k = 0; j < formattedTextLength && k < rawTextLength; )
        {
            unichar c1 = [formattedText characterAtIndex:j];
            unichar c2 = [rawText characterAtIndex:k];
            if (c1 != c2)
                newCaretPosition++;
            else
                k++;
            
            if (k == caretPosition)
            {
                break;
            }
            
            j++;
        }
        
        textField.text = [TGStringUtils formatPhone:rawText forceInternational:false];
        self.phone = textField.text;
        
        if (caretPosition >= (int)textField.text.length)
            caretPosition = textField.text.length;
        
        UITextPosition *startPosition = [textField positionFromPosition:textField.beginningOfDocument offset:newCaretPosition];
        UITextPosition *endPosition = [textField positionFromPosition:textField.beginningOfDocument offset:newCaretPosition];
        UITextRange *selection = [textField textRangeFromPosition:startPosition toPosition:endPosition];
        textField.selectedTextRange = selection;
        
        [self updateEditingState];
        
        id<ASWatcher> watcher = _watcherHandle.delegate;
        if (watcher != nil && [watcher respondsToSelector:@selector(actionStageActionRequested:options:)])
            [watcher actionStageActionRequested:@"phoneItemChanged" options:[[NSDictionary alloc] initWithObjectsAndKeys:self, @"cell", nil]];
    }
    @catch (NSException *e)
    {
        TGLog(@"%@", e);
    }
    
    [self updateEditingState];
    
    return false;
}

- (BOOL)textFieldShouldClear:(UITextField *)__unused textField
{
    _phone = @"";
    _textField.text = @"";
    
    [self updateEditingState];
    
    id<ASWatcher> watcher = _watcherHandle.delegate;
    if (watcher != nil && [watcher respondsToSelector:@selector(actionStageActionRequested:options:)])
        [watcher actionStageActionRequested:@"phoneItemChanged" options:[[NSDictionary alloc] initWithObjectsAndKeys:self, @"cell", nil]];
    
    return false;
}

- (void)updateEditingState
{
    if (self.editing)
        _switchButton.alpha = _textField.text.length != 0 ? 1.0f : 0.0f;
    else
        _switchButton.alpha = 0.0f;
}

@end
