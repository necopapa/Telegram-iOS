#import "TGLoginPhoneController.h"

#import "TGImageUtils.h"

#import "TGToolbarButton.h"

#import "TGNavigationBar.h"
#import "TGNavigationController.h"

#import "TGAppDelegate.h"

#import "TGHacks.h"

#import "TGStringUtils.h"

#import "TGLoginCodeController.h"
#import "TGLoginCountriesController.h"

#import "SGraphObjectNode.h"

#import "TGLoginProfileController.h"

#import <CoreTelephony/CTCarrier.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>

#import "TGProgressWindow.h"

#import "TGHighlightableButton.h"
#import "TGBackspaceTextField.h"

#import "TGActivityIndicatorView.h"

#import "TGSendCodeRequestBuilder.h"

@interface TGLoginPhoneController () <UITextFieldDelegate>

@property (nonatomic, strong) NSString *presetPhoneCountry;
@property (nonatomic, strong) NSString *presetPhoneNumber;

@property (nonatomic, strong) TGToolbarButton *nextButton;
@property (nonatomic, strong) TGProgressWindow *progressWindow;

@property (nonatomic, strong) UILabel *noticeLabel;
@property (nonatomic, strong) TGHighlightableButton *countryButton;
@property (nonatomic, strong) UIImageView *inputBackgroundView;

@property (nonatomic, strong) UITextField *countryCodeField;
@property (nonatomic, strong) TGBackspaceTextField *phoneField;

@property (nonatomic) CGRect basePhoneFieldFrame;
@property (nonatomic) CGRect baseInputBackgroundViewFrame;
@property (nonatomic) CGRect baseCountryCodeFieldFrame;

@property (nonatomic) bool inProgress;
@property (nonatomic) int currentActionIndex;

@property (nonatomic, strong) NSString *phoneNumber;

@property (nonatomic, strong) TGActivityIndicatorView *buttonActivityIndicator;

@property (nonatomic, strong) UIAlertView *currentAlert;

@property (nonatomic, strong) UIView *shadeView;

@end

@implementation TGLoginPhoneController

- (id)init
{
    self = [super initWithNibName:nil bundle:nil];
    if (self)
    {
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:true];
        
        self.style = TGViewControllerStyleBlack;
        
        self.navigationItem.hidesBackButton = true;
    }
    return self;
}

- (void)dealloc
{
    [self doUnloadView];
    
    _currentAlert.delegate = nil;
    
    [_actionHandle reset];
    [ActionStageInstance() removeWatcher:self];
}

- (void)setPhoneNumber:(NSString *)phoneNumber
{
    if ([phoneNumber rangeOfString:@"|"].location == NSNotFound)
        return;
    
    _presetPhoneCountry = [phoneNumber substringToIndex:[phoneNumber rangeOfString:@"|"].location];
    _presetPhoneNumber = [phoneNumber substringFromIndex:[phoneNumber rangeOfString:@"|"].location + 1];
    
    if (self.isViewLoaded)
        [self _applyPresetNumber];
}

- (void)_applyPresetNumber
{
    if (_presetPhoneNumber != nil && _presetPhoneCountry != nil)
    {
        _countryCodeField.text = _presetPhoneCountry;
        _phoneField.text = _presetPhoneNumber;
        
        _presetPhoneCountry = nil;
        _presetPhoneNumber = nil;
        
        [self updatePhoneTextForCountryFieldText:_countryCodeField.text];
        [self updateCountry];
        [self updateTitleText];
    }
}

- (void)loadView
{
    [super loadView];
    
    self.view.opaque = false;
    
    self.titleText = TGLocalized(@"Login.PhoneTitle");
    
    UIImage *imageNormal = [[UIImage imageNamed:@"BackButton_Login.png"] stretchableImageWithLeftCapWidth:15 topCapHeight:0];
    UIImage *imageNormalHighlighted = [[UIImage imageNamed:@"BackButton_Login_Pressed.png"] stretchableImageWithLeftCapWidth:15 topCapHeight:0];
    UIImage *imageLandscape = [[UIImage imageNamed:@"BackButton_Login_Landscape.png"] stretchableImageWithLeftCapWidth:15 topCapHeight:0];
    UIImage *imageLandscapeHighlighted = [[UIImage imageNamed:@"BackButton_Login_Landscape_Pressed.png"] stretchableImageWithLeftCapWidth:15 topCapHeight:0];
    
    [self setBackAction:@selector(performClose) imageNormal:imageNormal imageNormalHighlighted:imageNormalHighlighted imageLadscape:imageLandscape imageLandscapeHighlighted:imageLandscapeHighlighted textColor:[UIColor whiteColor] shadowColor:UIColorRGBA(0x050608, 0.4f)];
    
    _nextButton = [[TGToolbarButton alloc] initWithType:TGToolbarButtonTypeDoneBlack];
    _nextButton.text = NSLocalizedString(@"Common.Next", @"");
    _nextButton.minWidth = 52;
    [_nextButton sizeToFit];
    [_nextButton addTarget:self action:@selector(nextButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:_nextButton];
    
    _buttonActivityIndicator = [[TGActivityIndicatorView alloc] initWithStyle:TGActivityIndicatorViewStyleSmallWhite];
    _buttonActivityIndicator.frame = CGRectOffset(_buttonActivityIndicator.frame, floorf((_nextButton.frame.size.width - _buttonActivityIndicator.frame.size.width) / 2), floorf((_nextButton.frame.size.height - _buttonActivityIndicator.frame.size.height) / 2));
    _buttonActivityIndicator.hidden = true;
    [_nextButton addSubview:_buttonActivityIndicator];
    
    UIImage *rawCountryImage = [UIImage imageNamed:@"LoginCountry.png"];
    UIImage *rawCountryImageHighlighted = [UIImage imageNamed:@"LoginCountry_Highlighted.png"];
    
    _noticeLabel = [[UILabel alloc] init];
    _noticeLabel.font = [UIFont systemFontOfSize:14];
    _noticeLabel.textColor = UIColorRGB(0xc0c5cc);
    _noticeLabel.shadowColor = UIColorRGB(0x323c4a);
    _noticeLabel.shadowOffset = CGSizeMake(0, 1);
    _noticeLabel.text = TGLocalized(@"Login.PhoneAndCountryHelp");
    _noticeLabel.backgroundColor = [UIColor clearColor];
    _noticeLabel.lineBreakMode = UILineBreakModeWordWrap;
    _noticeLabel.textAlignment = UITextAlignmentCenter;
    _noticeLabel.contentMode = UIViewContentModeCenter;
    _noticeLabel.numberOfLines = 0;
    [self.view addSubview:_noticeLabel];
    
    _countryButton = [[TGHighlightableButton alloc] initWithFrame:CGRectMake(0, 0, 100, rawCountryImage.size.height)];
    _countryButton.exclusiveTouch = true;
    [_countryButton setBackgroundImage:[rawCountryImage stretchableImageWithLeftCapWidth:(int)(rawCountryImage.size.width - 16) topCapHeight:0] forState:UIControlStateNormal];
    [_countryButton setBackgroundImage:[rawCountryImageHighlighted stretchableImageWithLeftCapWidth:(int)(rawCountryImageHighlighted.size.width - 16) topCapHeight:0] forState:UIControlStateHighlighted];
    _countryButton.titleLabel.font = [UIFont boldSystemFontOfSize:TGIsRetina() ? 16.5f : 16];
    _countryButton.titleLabel.textAlignment = UITextAlignmentLeft;
    _countryButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    [_countryButton setTitleColor:UIColorRGB(0xf0f0f0) forState:UIControlStateNormal];
    [_countryButton setTitleShadowColor:UIColorRGB(0x17191d) forState:UIControlStateNormal];
    [_countryButton setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
    [_countryButton setTitleShadowColor:[UIColor clearColor] forState:UIControlStateHighlighted];
    _countryButton.titleLabel.shadowOffset = CGSizeMake(0, 1);
    _countryButton.titleEdgeInsets = UIEdgeInsetsMake(0, 14, 9, 14);
    [_countryButton addTarget:self action:@selector(countryButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    UIImageView *arrowView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"LoginCountryArrow.png"] highlightedImage:[UIImage imageNamed:@"LoginCountryArrow_Highlighted.png"]];
    arrowView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    arrowView.frame = CGRectOffset(arrowView.frame, _countryButton.frame.size.width - arrowView.frame.size.width - 15, 16);
    [_countryButton addSubview:arrowView];
    [self.view addSubview:_countryButton];
    
    UIImage *rawInputImage = [UIImage imageNamed:@"LoginInput.png"];
    _inputBackgroundView = [[UIImageView alloc] initWithImage:[rawInputImage stretchableImageWithLeftCapWidth:(int)(rawInputImage.size.width / 2) topCapHeight:(int)(rawInputImage.size.height / 2)]];
    [self.view addSubview:_inputBackgroundView];
    
    UIImageView *inputDivider = [[UIImageView alloc] initWithImage:[[UIImage imageNamed:@"LoginInputDivider.png"] stretchableImageWithLeftCapWidth:0 topCapHeight:4]];
    inputDivider.frame = CGRectMake(60, 1, 1, _inputBackgroundView.frame.size.height + 1);
    [_inputBackgroundView addSubview:inputDivider];
    
    _inputBackgroundView.userInteractionEnabled = true;
    [_inputBackgroundView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(inputBackgroundTapped:)]];
    
    _countryCodeField = [[UITextField alloc] init];
    _countryCodeField.font = [UIFont boldSystemFontOfSize:18];
    _countryCodeField.backgroundColor = UIColorRGB(0xf5f5f5);
    _countryCodeField.text = @"+";
    _countryCodeField.textAlignment = UITextAlignmentCenter;
    _countryCodeField.keyboardType = UIKeyboardTypeNumberPad;
    _countryCodeField.delegate = self;
    [self.view addSubview:_countryCodeField];
    
    _phoneField = [[TGBackspaceTextField alloc] init];
    _phoneField.delegate = self;
    _phoneField.font = [UIFont boldSystemFontOfSize:18];
    [TGHacks setTextFieldPlaceholderFont:_phoneField font:[UIFont systemFontOfSize:17]];
    _phoneField.backgroundColor = UIColorRGB(0xf5f5f5);
    _phoneField.placeholder = TGLocalized(@"Login.PhonePlaceholder");
    _phoneField.keyboardType = UIKeyboardTypeNumberPad;
    _phoneField.delegate = self;
    [TGHacks setTextFieldPlaceholderColor:_phoneField color:UIColorRGB(0x999999)];
    [self.view addSubview:_phoneField];
    
    if (![self _updateControllerInset:false])
        [self updateInterface:UIInterfaceOrientationPortrait];
    
    NSString *countryId = nil;
    
    CTTelephonyNetworkInfo *networkInfo = [[CTTelephonyNetworkInfo alloc] init];
    CTCarrier *carrier = [networkInfo subscriberCellularProvider];
    if (carrier != nil)
    {
        NSString *mcc = [carrier isoCountryCode];
        if (mcc != nil)
            countryId = mcc;
    }
    if (countryId == nil)
    {
        NSLocale *locale = [NSLocale currentLocale];
        countryId = [locale objectForKey:NSLocaleCountryCode];
    }
    
    int code = 0;
    __unused NSString *countryName = [TGLoginCountriesController countryNameByCountryId:countryId code:&code];
    
    if (code == 0)
        code = 1;
    
    _countryCodeField.text = [NSString stringWithFormat:@"+%d", code];
    
    _shadeView = [[UIView alloc] initWithFrame:self.view.bounds];
    _shadeView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _shadeView.hidden = true;
    [self.view addSubview:_shadeView];
    
    [self updatePhoneTextForCountryFieldText:_countryCodeField.text];
    
    [self updateCountry];
    
    [self updateTitleText];
    
    [self _applyPresetNumber];
}

- (void)performClose
{
    [ActionStageInstance() removeWatcher:self];
    [self setInProgress:false];
    
    [self.navigationController popViewControllerAnimated:true];
}

- (void)doUnloadView
{
    _countryCodeField.delegate = nil;
    _phoneField.delegate = nil;
}

- (void)viewDidUnload
{
    [self doUnloadView];
    
    [super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
}

- (BOOL)shouldAutorotate
{
    return true;
}

- (void)viewWillAppear:(BOOL)animated
{
    [_phoneField becomeFirstResponder];
    
    [super viewWillAppear:animated];
}

- (void)controllerInsetUpdated:(UIEdgeInsets)previousInset
{
    [super controllerInsetUpdated:previousInset];
    
    [self updateInterface:UIInterfaceOrientationPortrait];
}

- (void)updateInterface:(UIInterfaceOrientation)orientation
{
    float topOffset = self.controllerInset.top;
    
    topOffset = MIN(topOffset, 20 + 50);
    
    CGSize screenSize = [TGViewController screenSizeForInterfaceOrientation:orientation];
    CGSize viewSize = CGSizeMake(screenSize.width, screenSize.height - 20 - (UIInterfaceOrientationIsPortrait(orientation) ? 44 : 32));
    viewSize.height -= 216;
    
    float width = UIInterfaceOrientationIsPortrait(orientation) ? 290 : 320;
    
    _countryButton.frame = CGRectMake((int)((viewSize.width - width) / 2), topOffset + (int)((viewSize.height - 68) / 2) + (UIInterfaceOrientationIsLandscape(orientation) ? (-16) : (4 + (TGIsRetina() ? 0.5f : 0.0f))), width, _countryButton.frame.size.height);
    _inputBackgroundView.frame = _baseInputBackgroundViewFrame = CGRectIntegral(CGRectMake((viewSize.width - width) / 2, _countryButton.frame.origin.y + _countryButton.frame.size.height + (UIInterfaceOrientationIsLandscape(orientation) ? 0 : (TGIsRetina() ? 7.5f : 7.0f)), width, 47));
    
    CGSize noticeSize = [_noticeLabel sizeThatFits:CGSizeMake(270, 1024)];
    CGRect noticeFrame = CGRectMake(0, 0, noticeSize.width, noticeSize.height);
    _noticeLabel.frame = CGRectIntegral(CGRectOffset(noticeFrame, (viewSize.width - noticeFrame.size.width) / 2, _countryButton.frame.origin.y - 16 - noticeFrame.size.height));
    
    _noticeLabel.alpha = _noticeLabel.frame.origin.y < 0 ? 0.0f : 1.0f;
    
    _countryCodeField.frame = _baseCountryCodeFieldFrame = CGRectMake(_inputBackgroundView.frame.origin.x + 4, _inputBackgroundView.frame.origin.y + 12, 54, 22);
    _phoneField.frame = _basePhoneFieldFrame = CGRectMake(_inputBackgroundView.frame.origin.x + 74, _inputBackgroundView.frame.origin.y + 2, _inputBackgroundView.frame.size.width - 74 - 14, 32);
}

- (void)setInProgress:(bool)inProgress
{
    if (_inProgress != inProgress)
    {
        _inProgress = inProgress;
        
        if (inProgress)
        {
            _nextButton.enabled = false;
            _nextButton.text = @"";
            _buttonActivityIndicator.hidden = false;
            [_buttonActivityIndicator startAnimating];
            
            _shadeView.hidden = false;
        }
        else
        {
            _nextButton.enabled = true;
            _nextButton.text = TGLocalized(@"Common.Next");
            [_nextButton sizeToFit];
            [_buttonActivityIndicator stopAnimating];
            _buttonActivityIndicator.hidden = true;
            
            _shadeView.hidden = true;
        }
    }
}

#pragma mark -

- (void)textFieldDidHitLastBackspace
{
    [_countryCodeField becomeFirstResponder];
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    if (_inProgress)
        return false;
    
    if (textField == _countryCodeField)
    {
        int length = string.length;
        unichar replacementCharacters[length];
        int filteredLength = 0;
        
        for (int i = 0; i < length; i++)
        {
            unichar c = [string characterAtIndex:i];
            if (c >= '0' && c <= '9')
                replacementCharacters[filteredLength++] = c;
        }
        
        if (filteredLength == 0 && (range.length == 0 || range.location == 0))
            return false;
        
        if (range.location == 0)
            range.location++;
        
        NSString *replacementString = [[NSString alloc] initWithCharacters:replacementCharacters length:filteredLength];
        
        NSString *newText = [textField.text stringByReplacingCharactersInRange:range withString:replacementString];
        if (newText.length > 5)
        {
            for (int i = 0; i < (int)newText.length - 1; i++)
            {
                int countryCode = [[newText substringWithRange:NSMakeRange(1, newText.length - 1 - i)] intValue];
                NSString *countryName = [TGLoginCountriesController countryNameByCode:countryCode];
                if (countryName != nil)
                {
                    _phoneField.text = [self filterPhoneText:[[NSString alloc] initWithFormat:@"%@%@", [newText substringFromIndex:newText.length - i], _phoneField.text]];
                    newText = [newText substringToIndex:newText.length - i];
                    [_phoneField becomeFirstResponder];
                }
            }
            
            if (newText.length > 5)
                newText = [newText substringToIndex:5];
        }
        
        textField.text = newText;
        
        [self updatePhoneTextForCountryFieldText:newText];
        
        [self updateCountry];
        
        [self updateTitleText];
        
        return false;
    }
    else if (textField == _phoneField)
    {
        if (true)
        {
            int stringLength = string.length;
            unichar replacementCharacters[stringLength];
            int filteredLength = 0;
            
            for (int i = 0; i < stringLength; i++)
            {
                unichar c = [string characterAtIndex:i];
                if (c >= '0' && c <= '9')
                    replacementCharacters[filteredLength++] = c;
            }
            
            NSString *replacementString = [[NSString alloc] initWithCharacters:replacementCharacters length:filteredLength];
            
            unichar rawNewString[replacementString.length];
            int rawNewStringLength = 0;
            
            int replacementLength = replacementString.length;
            for (int i = 0; i < replacementLength; i++)
            {
                unichar c = [replacementString characterAtIndex:i];
                if ((c >= '0' && c <= '9'))
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
                if ((c >= '0' && c <= '9'))
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
                int caretPosition = range.location + string.length;
                
                [rawText replaceCharactersInRange:range withString:string];
                
                NSString *countryCodeText = _countryCodeField.text.length > 1 ? _countryCodeField.text : @"";
                
                NSString *formattedText = [TGStringUtils formatPhone:[[NSString alloc] initWithFormat:@"%@%@", countryCodeText, rawText] forceInternational:false];
                if (countryCodeText.length > 1)
                {
                    int i = 0;
                    int j = 0;
                    while (i < (int)formattedText.length && j < (int)countryCodeText.length)
                    {
                        unichar c1 = [formattedText characterAtIndex:i];
                        unichar c2 = [countryCodeText characterAtIndex:j];
                        if (c1 == c2)
                            j++;
                        i++;
                    }
                    
                    formattedText = [formattedText substringFromIndex:i];
                    
                    i = 0;
                    while (i < (int)formattedText.length)
                    {
                        unichar c = [formattedText characterAtIndex:i];
                        if (c == '(' || c == ')' || (c >= '0' && c <= '9'))
                            break;
                        
                        i++;
                    }
                    
                    formattedText = [self filterPhoneText:[formattedText substringFromIndex:i]];
                }
                
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
                
                textField.text = formattedText;
                
                [self updateTitleText];
                
                if (caretPosition >= (int)textField.text.length)
                    caretPosition = textField.text.length;
                
                UITextPosition *startPosition = [textField positionFromPosition:textField.beginningOfDocument offset:newCaretPosition];
                UITextPosition *endPosition = [textField positionFromPosition:textField.beginningOfDocument offset:newCaretPosition];
                UITextRange *selection = [textField textRangeFromPosition:startPosition toPosition:endPosition];
                textField.selectedTextRange = selection;
            }
            @catch (NSException *e)
            {
                TGLog(@"%@", e);
            }
            
            return false;
        }
        else
        {
            int length = string.length;
            unichar replacementCharacters[length];
            int filteredLength = 0;
            
            for (int i = 0; i < length; i++)
            {
                unichar c = [string characterAtIndex:i];
                if (c >= '0' && c <= '9')
                    replacementCharacters[filteredLength++] = c;
            }
            
            NSString *replacementString = [[NSString alloc] initWithCharacters:replacementCharacters length:filteredLength];
            
            NSString *newText = [textField.text stringByReplacingCharactersInRange:range withString:replacementString];
            if (newText.length > 19)
                newText = [newText substringToIndex:19];
            
            if (newText.length == 0 || _countryCodeField.text.length <= 1)
                self.titleText = TGLocalized(@"Login.PhoneTitle");
            else
                self.titleText = [TGStringUtils formatPhone:[[NSString alloc] initWithFormat:@"%@%@", _countryCodeField.text, newText] forceInternational:false];
            
            textField.text = newText;
            
            return false;
        }
    }
    
    return true;
}

- (NSString *)filterPhoneText:(NSString *)text
{
    int i = 0;
    while (i < (int)text.length)
    {
        unichar c = [text characterAtIndex:i];
        if ((c >= '0' && c <= '9'))
            return text;
        
        i++;
    }
    
    return @"";
}

- (void)updatePhoneTextForCountryFieldText:(NSString *)countryCodeText
{
    NSString *rawText = _phoneField.text;
    
    NSString *formattedText = [TGStringUtils formatPhone:[[NSString alloc] initWithFormat:@"%@%@", countryCodeText, rawText] forceInternational:false];
    if (countryCodeText.length > 1)
    {
        int i = 0;
        int j = 0;
        while (i < (int)formattedText.length && j < (int)countryCodeText.length)
        {
            unichar c1 = [formattedText characterAtIndex:i];
            unichar c2 = [countryCodeText characterAtIndex:j];
            if (c1 == c2)
                j++;
            i++;
        }
        
        formattedText = [formattedText substringFromIndex:i];
        
        i = 0;
        while (i < (int)formattedText.length)
        {
            unichar c = [formattedText characterAtIndex:i];
            if (c == '(' || c == ')' || (c >= '0' && c <= '9'))
                break;
            
            i++;
        }
        
        formattedText = [formattedText substringFromIndex:i];
        _phoneField.text = [self filterPhoneText:formattedText];
    }
    else
        _phoneField.text = [self filterPhoneText:[TGStringUtils formatPhone:[[NSString alloc] initWithFormat:@"%@", _phoneField.text] forceInternational:false]];
}

- (void)updateTitleText
{
    NSString *rawString = [[NSString alloc] initWithFormat:@"%@%@", _countryCodeField.text, _phoneField.text];
    
    NSMutableString *string = [[NSMutableString alloc] init];
    for (int i = 0; i < (int)rawString.length; i++)
    {
        unichar c = [rawString characterAtIndex:i];
        if (c >= '0' && c <= '9')
            [string appendString:[[NSString alloc] initWithCharacters:&c length:1]];
    }
    
    if (string.length == 0 || _phoneField.text.length == 0 || _countryCodeField.text.length <= 1)
        self.titleText = TGLocalized(@"Login.PhoneTitle");
    else
        self.titleText = [TGStringUtils formatPhone:string forceInternational:true];
}

- (void)updateCountry
{
    int countryCode = [[_countryCodeField.text substringFromIndex:1] intValue];
    NSString *countryName = [TGLoginCountriesController countryNameByCode:countryCode];
    
    if (countryName != nil)
    {
        [_countryButton setTitleColor:UIColorRGB(0xf0f0f0) forState:UIControlStateNormal];
        [_countryButton setTitle:countryName forState:UIControlStateNormal];
    }
    else
    {
        [_countryButton setTitleColor:UIColorRGBA(0xf0f0f0, 0.7f) forState:UIControlStateNormal];
        [_countryButton setTitle:_countryCodeField.text.length <= 1 ? TGLocalized(@"Login.CountryCode") : TGLocalized(@"Login.InvalidCountryCode") forState:UIControlStateNormal];
    }
}

#pragma mark -

- (void)backgroundTapped:(UITapGestureRecognizer *)recognizer
{
    return;
    
    if (recognizer.state == UIGestureRecognizerStateRecognized)
    {
        [_countryCodeField resignFirstResponder];
        [_phoneField resignFirstResponder];
    }
}

- (void)inputBackgroundTapped:(UITapGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateRecognized)
    {
        if ([recognizer locationInView:_inputBackgroundView].x < _countryCodeField.frame.origin.x + _countryCodeField.frame.size.width)
            [_countryCodeField becomeFirstResponder];
        else
            [_phoneField becomeFirstResponder];
    }
}

- (void)shakeView:(UIView *)v originalX:(float)originalX
{
    CGRect r = v.frame;
    r.origin.x = originalX;
    CGRect originalFrame = r;
    CGRect rFirst = r;
    rFirst.origin.x = r.origin.x + 4;
    r.origin.x = r.origin.x - 4;
    
    v.frame = v.frame;
    
    [UIView animateWithDuration:0.05 delay:0.0 options:UIViewAnimationOptionAutoreverse animations:^
    {
        v.frame = rFirst;
    } completion:^(BOOL finished)
    {
        if (finished)
        {
            [UIView animateWithDuration:0.05 delay:0.0 options:(UIViewAnimationOptionRepeat | UIViewAnimationOptionAutoreverse) animations:^
            {
                [UIView setAnimationRepeatCount:3];
                v.frame = r;
            } completion:^(__unused BOOL finished)
            {
                v.frame = originalFrame;
            }];
        }
        else
            v.frame = originalFrame;
    }];
}

- (void)nextButtonPressed
{
    if (_inProgress)
        return;
    
    if (_phoneField.text.length == 0 || _countryCodeField.text.length < 2)
    {
        [self shakeView:_phoneField originalX:_basePhoneFieldFrame.origin.x];
        [self shakeView:_inputBackgroundView originalX:_baseInputBackgroundViewFrame.origin.x];
        [self shakeView:_countryCodeField originalX:_baseCountryCodeFieldFrame.origin.x];
        
        if (_countryCodeField.text.length < 2)
            [_countryCodeField becomeFirstResponder];
        else if (_phoneField.text.length == 0)
            [_phoneField becomeFirstResponder];
    }
    else
    {
        self.inProgress = true;
        
        static int actionIndex = 0;
        _currentActionIndex = actionIndex++;
        _phoneNumber = [NSString stringWithFormat:@"%@%@", [_countryCodeField.text substringFromIndex:1], _phoneField.text];
        [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/service/auth/sendCode/(%d)", _currentActionIndex] options:[NSDictionary dictionaryWithObjectsAndKeys:_phoneNumber, @"phoneNumber", nil] watcher:self];
    }
}

- (void)countryButtonPressed:(id)__unused sender
{
    TGLoginCountriesController *countriesController = [[TGLoginCountriesController alloc] init];
    countriesController.watcherHandle = _actionHandle;
    
    TGNavigationController *navigationController = [TGNavigationController navigationControllerWithRootController:countriesController blackCorners:false];
    TGNavigationBar *navigationBar = (TGNavigationBar *)navigationController.navigationBar;
    
    navigationBar.defaultPortraitImage = ((TGNavigationBar *)self.navigationController.navigationBar).defaultPortraitImage;
    navigationBar.defaultLandscapeImage = ((TGNavigationBar *)self.navigationController.navigationBar).defaultLandscapeImage;
    [navigationBar updateBackground];
    
    [navigationBar setShadowMode:true];
    
    [self presentViewController:navigationController animated:true completion:nil];
}

#pragma mark -

- (void)actorCompleted:(int)resultCode path:(NSString *)path result:(id)result
{
    if ([path isEqualToString:[NSString stringWithFormat:@"/tg/service/auth/sendCode/(%d)", _currentActionIndex]])
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            self.inProgress = false;
            
            if (resultCode == ASStatusSuccess)
            {
                NSString *phoneCodeHash = [((SGraphObjectNode *)result).object objectForKey:@"phoneCodeHash"];
                
                [TGAppDelegateInstance saveLoginStateWithDate:(int)CFAbsoluteTimeGetCurrent() phoneNumber:[[NSString alloc] initWithFormat:@"%@|%@", _countryCodeField.text, _phoneField.text] phoneCode:nil phoneCodeHash:phoneCodeHash firstName:nil lastName:nil photo:nil];
                
                [self.navigationController pushViewController:[[TGLoginCodeController alloc] initWithShowKeyboard:(_countryCodeField.isFirstResponder || _phoneField.isFirstResponder) phoneNumber:_phoneNumber phoneCodeHash:phoneCodeHash] animated:true];
            }
            else
            {
                NSString *errorText = TGLocalized(@"Login.UnknownError");
                
                if (resultCode == TGSendCodeErrorInvalidPhone)
                    errorText = TGLocalized(@"Login.InvalidPhoneError");
                else if (resultCode == TGSendCodeErrorFloodWait)
                    errorText = TGLocalized(@"Login.CodeFloodError");
                else if (resultCode == TGSendCodeErrorNetwork)
                    errorText = TGLocalized(@"Login.NetworkError");
                
                UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:nil message:errorText delegate:nil cancelButtonTitle:NSLocalizedString(@"Common.OK", nil) otherButtonTitles:nil];
                [alertView show];
            }
        });
    }
}

- (void)actionStageActionRequested:(NSString *)action options:(NSDictionary *)options
{
    if ([action isEqualToString:@"countryCodeSelected"])
    {
        [self dismissViewControllerAnimated:true completion:nil];
        
        if ([options objectForKey:@"code"] != nil)
        {
            [_countryButton setTitleColor:UIColorRGB(0xf0f0f0) forState:UIControlStateNormal];
            [_countryButton setTitle:[options objectForKey:@"name"] forState:UIControlStateNormal];
            _countryCodeField.text = [NSString stringWithFormat:@"+%d", [[options objectForKey:@"code"] intValue]];
            
            [self updatePhoneTextForCountryFieldText:_countryCodeField.text];
            
            [self updateTitleText];
        }
    }
}

@end
