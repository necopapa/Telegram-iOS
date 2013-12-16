#import "TGLoginCodeController.h"

#import "TGToolbarButton.h"

#import "TGImageUtils.h"

#import "TGProfileController.h"

#import "TGHacks.h"

#import "TGStringUtils.h"

#import "TGImageUtils.h"

#import "TGLoginProfileController.h"

#import "TGAppDelegate.h"

#import "TGSignInRequestBuilder.h"
#import "TGSendCodeRequestBuilder.h"

#import "SGraphObjectNode.h"

#import "TGDatabase.h"

#import "TGLoginInactiveUserController.h"

#import "TGActivityIndicatorView.h"

@interface TGLoginCodeController () <UITextFieldDelegate, UIAlertViewDelegate>

@property (nonatomic, strong) NSString *phoneNumber;
@property (nonatomic, strong) NSString *phoneCodeHash;

@property (nonatomic, strong) TGToolbarButton *nextButton;

@property (nonatomic, strong) UILabel *noticeLabel;

@property (nonatomic, strong) UIImageView *inputBackgroundView;
@property (nonatomic, strong) UITextField *codeField;

@property (nonatomic) CGRect baseInputBackgroundViewFrame;
@property (nonatomic) CGRect baseCodeFieldFrame;

@property (nonatomic, strong) UILabel *timeoutLabel;
@property (nonatomic, strong) UILabel *requestingCallLabel;
@property (nonatomic, strong) UILabel *callSentLabel;

@property (nonatomic) bool inProgress;
@property (nonatomic) int currentActionIndex;

@property (nonatomic, strong) NSTimer *countdownTimer;
@property (nonatomic) NSTimeInterval countdownStart;

@property (nonatomic, strong) NSString *phoneCode;

@property (nonatomic, strong) TGActivityIndicatorView *buttonActivityIndicator;

@property (nonatomic, strong) UIAlertView *currentAlert;

@end

@implementation TGLoginCodeController

- (id)initWithShowKeyboard:(bool)__unused showKeyboard phoneNumber:(NSString *)phoneNumber phoneCodeHash:(NSString *)phoneCodeHash
{
    self = [super initWithNibName:nil bundle:nil];
    if (self)
    {
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:true];
        
        _phoneNumber = phoneNumber;
        _phoneCodeHash = phoneCodeHash;
        
        self.style = TGViewControllerStyleBlack;
        
        [ActionStageInstance() watchForPath:@"/tg/activation" watcher:self];
        [ActionStageInstance() watchForPath:@"/tg/contactListSynchronizationState" watcher:self];
    }
    return self;
}

- (void)dealloc
{
    [self doUnloadView];
    
    _codeField.delegate = nil;
    
    _currentAlert.delegate = nil;
    
    [_actionHandle reset];
    [ActionStageInstance() removeWatcher:self];
}

- (bool)shouldBeRemovedFromNavigationAfterHiding
{
    return true;
}

- (void)loadView
{
    [super loadView];
    
    self.view.opaque = false;
    
    self.titleText = [TGStringUtils formatPhone:_phoneNumber forceInternational:true];
    
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
    
    _noticeLabel = [[UILabel alloc] init];
    _noticeLabel.font = [UIFont systemFontOfSize:14];
    _noticeLabel.textColor = UIColorRGB(0xc0c5cc);
    _noticeLabel.shadowColor = UIColorRGB(0x323c4a);
    _noticeLabel.shadowOffset = CGSizeMake(0, 1);
    _noticeLabel.textAlignment = UITextAlignmentCenter;
    _noticeLabel.contentMode = UIViewContentModeCenter;
    _noticeLabel.numberOfLines = 0;
    _noticeLabel.text = TGLocalized(@"Login.CodeHelp");
    _noticeLabel.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_noticeLabel];

    UIImage *rawInputImage = [UIImage imageNamed:@"LoginInput.png"];
    _inputBackgroundView = [[UIImageView alloc] initWithImage:[rawInputImage stretchableImageWithLeftCapWidth:(int)(rawInputImage.size.width / 2) topCapHeight:0]];
    [self.view addSubview:_inputBackgroundView];
    
    _inputBackgroundView.userInteractionEnabled = true;
    [_inputBackgroundView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(inputBackgroundTapped:)]];
    
    _codeField = [[UITextField alloc] init];
    _codeField.font = [UIFont boldSystemFontOfSize:18];
    [TGHacks setTextFieldPlaceholderFont:_codeField font:[UIFont systemFontOfSize:18]];
    _codeField.backgroundColor = UIColorRGB(0xf5f5f5);
    _codeField.textAlignment = UITextAlignmentCenter;
    _codeField.placeholder = TGLocalized(@"Login.Code");
    _codeField.keyboardType = UIKeyboardTypeNumberPad;
    _codeField.delegate = self;
    [TGHacks setTextFieldPlaceholderColor:_codeField color:UIColorRGB(0xadb0b6)];
    [self.view addSubview:_codeField];
    
    _timeoutLabel = [[UILabel alloc] init];
    _timeoutLabel.font = [UIFont systemFontOfSize:14];
    _timeoutLabel.textColor = UIColorRGB(0xc4c9d2);
    _timeoutLabel.shadowColor = UIColorRGB(0x25272b);
    _timeoutLabel.shadowOffset = CGSizeMake(0, 1);
    _timeoutLabel.textAlignment = UITextAlignmentCenter;
    _timeoutLabel.contentMode = UIViewContentModeCenter;
    _timeoutLabel.numberOfLines = 0;
    _timeoutLabel.text = [[NSString alloc] initWithFormat:TGLocalized(@"Login.CallRequestState1"), 1, 0];
    _timeoutLabel.backgroundColor = [UIColor clearColor];
    [_timeoutLabel sizeToFit];
    [self.view addSubview:_timeoutLabel];
    
    _requestingCallLabel = [[UILabel alloc] init];
    _requestingCallLabel.font = [UIFont systemFontOfSize:14];
    _requestingCallLabel.textColor = UIColorRGB(0xc4c9d2);
    _requestingCallLabel.shadowColor = UIColorRGB(0x25272b);
    _requestingCallLabel.shadowOffset = CGSizeMake(0, 1);
    _requestingCallLabel.textAlignment = UITextAlignmentCenter;
    _requestingCallLabel.contentMode = UIViewContentModeCenter;
    _requestingCallLabel.numberOfLines = 0;
    _requestingCallLabel.text = TGLocalized(@"Login.CallRequestState2");
    _requestingCallLabel.backgroundColor = [UIColor clearColor];
    _requestingCallLabel.alpha = 0.0f;
    [_requestingCallLabel sizeToFit];
    [self.view addSubview:_requestingCallLabel];
    
    _callSentLabel = [[UILabel alloc] init];
    _callSentLabel.font = [UIFont systemFontOfSize:14];
    _callSentLabel.textColor = UIColorRGB(0xc4c9d2);
    _callSentLabel.shadowColor = UIColorRGB(0x25272b);
    _callSentLabel.shadowOffset = CGSizeMake(0, 1);
    _callSentLabel.textAlignment = UITextAlignmentCenter;
    _callSentLabel.contentMode = UIViewContentModeCenter;
    _callSentLabel.numberOfLines = 0;
    _callSentLabel.text = TGLocalized(@"Login.CallRequestState3");
    _callSentLabel.backgroundColor = [UIColor clearColor];
    _callSentLabel.alpha = 0.0f;
    [_callSentLabel sizeToFit];
    [self.view addSubview:_callSentLabel];
    
    if (![self _updateControllerInset:false])
        [self updateInterface:UIInterfaceOrientationPortrait];
}

- (void)performClose
{
    [TGAppDelegateInstance resetLoginState];
    
    [self.navigationController popViewControllerAnimated:true];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
}

- (BOOL)shouldAutorotate
{
    return true;
}

- (void)doUnloadView
{
    _codeField.delegate = nil;
}

- (void)viewDidUnload
{
    [self doUnloadView];
    
    [super viewDidUnload];
}

- (void)viewWillAppear:(BOOL)animated
{
    [_codeField becomeFirstResponder];
    
    if (_countdownTimer == nil)
    {
        _countdownStart = CFAbsoluteTimeGetCurrent();
        _countdownTimer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:1.0] interval:1.0 target:self selector:@selector(updateCountdown) userInfo:nil repeats:false];
        [[NSRunLoop mainRunLoop] addTimer:_countdownTimer forMode:NSRunLoopCommonModes];
    }
    
    [super viewWillAppear:animated];
}

- (void)updateCountdown
{
    _countdownTimer = nil;
    
    const int timeout = 1 * 60;
    
    NSTimeInterval currentTime = CFAbsoluteTimeGetCurrent();
    NSTimeInterval remainingTime = (_countdownStart + timeout) - currentTime;
    
    if (remainingTime < 0)
        remainingTime = 0;
    
    _timeoutLabel.text = [NSString stringWithFormat:TGLocalized(@"Login.CallRequestState1"), ((int)remainingTime) / 60, ((int)remainingTime) % 60];
    
    if (remainingTime <= 0)
    {
        [UIView animateWithDuration:0.2 animations:^
        {
            _timeoutLabel.alpha = 0.0f;
        }];
        
        [UIView animateWithDuration:0.2 delay:0.1 options:0 animations:^
        {
            _requestingCallLabel.alpha = 1.0f;
        } completion:nil];
        
        static int actionId = 0;
        [ActionStageInstance() requestActor:[[NSString alloc] initWithFormat:@"/tg/service/auth/sendCode/(call%d)", actionId++] options:[[NSDictionary alloc] initWithObjectsAndKeys:_phoneNumber, @"phoneNumber", _phoneCodeHash, @"phoneHash", [[NSNumber alloc] initWithBool:true], @"requestCall", nil] watcher:self];
    }
    else
    {
        NSTimeInterval delay = 1.0;
        _countdownTimer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:delay] interval:delay target:self selector:@selector(updateCountdown) userInfo:nil repeats:false];
        [[NSRunLoop mainRunLoop] addTimer:_countdownTimer forMode:NSRunLoopCommonModes];
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [_countdownTimer invalidate];
    _countdownTimer = nil;
    
    [super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
}

- (void)controllerInsetUpdated:(UIEdgeInsets)previousInset
{
    [super controllerInsetUpdated:previousInset];
    
    [self updateInterface:UIInterfaceOrientationPortrait];
}

- (void)updateInterface:(UIInterfaceOrientation)orientation
{
    float topOffset = self.controllerInset.top;
    
    float keyboardHeight = 216;
    
    topOffset = MIN(topOffset, 20 + 50);
    
    CGSize screenSize = [TGViewController screenSizeForInterfaceOrientation:orientation];
    CGSize viewSize = CGSizeMake(screenSize.width, screenSize.height - 20 - (UIInterfaceOrientationIsPortrait(orientation) ? 44 : 32));
    viewSize.height -= keyboardHeight;
    
    float width = 80;
    
    bool isLandscapeWithKeyboard = UIInterfaceOrientationIsLandscape(orientation) && keyboardHeight > FLT_EPSILON;
    
    _inputBackgroundView.frame = _baseInputBackgroundViewFrame = CGRectIntegral(CGRectMake((viewSize.width - width) / 2, topOffset + (viewSize.height - 26) / 2 - (isLandscapeWithKeyboard ? 30 : 0), width, 43));
    
    CGSize noticeSize = [_noticeLabel sizeThatFits:CGSizeMake(300, viewSize.height)];
    CGRect noticeFrame = CGRectMake(0, 0, noticeSize.width, noticeSize.height);
    _noticeLabel.frame = CGRectIntegral(CGRectOffset(noticeFrame, (viewSize.width - noticeFrame.size.width) / 2, _inputBackgroundView.frame.origin.y - noticeFrame.size.height - 14));
    
    _noticeLabel.alpha = _noticeLabel.frame.origin.y < 0 ? 0.0f : 1.0f;
    
    _codeField.frame = _baseCodeFieldFrame = CGRectMake(_inputBackgroundView.frame.origin.x + 9, _inputBackgroundView.frame.origin.y + 10, _inputBackgroundView.frame.size.width - 20, 22);
    
    //_codeButton.frame = CGRectMake((int)((viewSize.width - _codeButton.frame.size.width) / 2), _inputBackgroundView.frame.origin.y + _inputBackgroundView.frame.size.height + 14 - (isLandscapeWithKeyboard ? 6 : 0), _codeButton.frame.size.width, _codeButton.frame.size.height);
    _timeoutLabel.frame = CGRectMake((int)((viewSize.width - _timeoutLabel.frame.size.width) / 2), _inputBackgroundView.frame.origin.y + _inputBackgroundView.frame.size.height + 14 - (isLandscapeWithKeyboard ? 6 : 0), _timeoutLabel.frame.size.width, _timeoutLabel.frame.size.height);
    _requestingCallLabel.frame = CGRectMake((int)((viewSize.width - _requestingCallLabel.frame.size.width) / 2), _inputBackgroundView.frame.origin.y + _inputBackgroundView.frame.size.height + 14 - (isLandscapeWithKeyboard ? 6 : 0), _requestingCallLabel.frame.size.width, _requestingCallLabel.frame.size.height);
    _callSentLabel.frame = CGRectMake((int)((viewSize.width - _callSentLabel.frame.size.width) / 2), _inputBackgroundView.frame.origin.y + _inputBackgroundView.frame.size.height + 14 - (isLandscapeWithKeyboard ? 6 : 0), _callSentLabel.frame.size.width, _callSentLabel.frame.size.height);
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
        }
        else
        {
            _nextButton.enabled = true;
            _nextButton.text = TGLocalized(@"Common.Next");
            [_nextButton sizeToFit];
            [_buttonActivityIndicator stopAnimating];
            _buttonActivityIndicator.hidden = true;
        }
    }
}

#pragma mark -

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    if (_inProgress)
        return false;
    
    if (textField == _codeField)
    {
#if TARGET_IPHONE_SIMULATOR
        return true;
#endif
        NSString *replacementString = string;
        
        int length = replacementString.length;
        for (int i = 0; i < length; i++)
        {
            unichar c = [replacementString characterAtIndex:i];
            if (c < '0' || c > '9')
                return false;
        }
        
        NSString *newText = [textField.text stringByReplacingCharactersInRange:range withString:replacementString];
        if (newText.length > 5)
            return false;
        
        textField.text = newText;
        
        if (newText.length == 5)
            [self nextButtonPressed];
        
        return false;
    }
    
    return true;
}

#pragma mark -

- (void)backgroundTapped:(UITapGestureRecognizer *)recognizer
{
    return;
    
    if (recognizer.state == UIGestureRecognizerStateRecognized)
    {
        [_codeField resignFirstResponder];
    }
}

- (void)inputBackgroundTapped:(UITapGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateRecognized)
    {
        [_codeField becomeFirstResponder];
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

- (void)applyCode:(NSString *)code
{
    _codeField.text = code;
    [self nextButtonPressed];
}

- (void)nextButtonPressed
{
    if (_inProgress)
        return;
    
    if (_codeField.text.length == 0)
    {
        [self shakeView:_codeField originalX:_baseCodeFieldFrame.origin.x];
        [self shakeView:_inputBackgroundView originalX:_baseInputBackgroundViewFrame.origin.x];
    }
    else
    {
        self.inProgress = true;
        
        static int actionIndex = 0;
        _currentActionIndex = actionIndex++;
        _phoneCode = _codeField.text;
        [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/service/auth/signIn/(%d)", _currentActionIndex] options:[NSDictionary dictionaryWithObjectsAndKeys:_phoneNumber, @"phoneNumber", _codeField.text, @"phoneCode", _phoneCodeHash, @"phoneCodeHash", nil] watcher:self];
    }
}

#pragma mark -

- (void)actionStageResourceDispatched:(NSString *)path resource:(id)resource arguments:(id)__unused arguments
{
    if ([path isEqualToString:@"/tg/activation"])
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            self.inProgress = false;
            
            if ([((SGraphObjectNode *)resource).object boolValue])
                [TGAppDelegateInstance presentMainController];
            else
            {
                if (![[self.navigationController.viewControllers lastObject] isKindOfClass:[TGLoginInactiveUserController class]])
                {
                    TGLoginInactiveUserController *inactiveUserController = [[TGLoginInactiveUserController alloc] init];
                    [self.navigationController pushViewController:inactiveUserController animated:true];
                }
            }
        });
    }
    else if ([path isEqualToString:@"/tg/contactListSynchronizationState"])
    {
        if (![((SGraphObjectNode *)resource).object boolValue])
        {
            bool activated = [TGDatabaseInstance() haveRemoteContactUids];
            
            dispatch_async(dispatch_get_main_queue(), ^
            {
                self.inProgress = false;
                
                if (activated)
                    [TGAppDelegateInstance presentMainController];
                else
                {
                    if (![[self.navigationController.viewControllers lastObject] isKindOfClass:[TGLoginInactiveUserController class]])
                    {
                        TGLoginInactiveUserController *inactiveUserController = [[TGLoginInactiveUserController alloc] init];
                        [self.navigationController pushViewController:inactiveUserController animated:true];
                    }
                }
            });
        }
    }
}

- (void)actorCompleted:(int)resultCode path:(NSString *)path result:(id)result
{
    if ([path isEqualToString:[NSString stringWithFormat:@"/tg/service/auth/signIn/(%d)", _currentActionIndex]])
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {   
            if (resultCode == ASStatusSuccess)
            {
                if ([[((SGraphObjectNode *)result).object objectForKey:@"activated"] boolValue])
                    [TGAppDelegateInstance presentMainController];
            }
            else
            {
                self.inProgress = false;
                
                NSString *errorText = TGLocalized(@"Login.UnknownError");
                bool setDelegate = false;
                
                if (resultCode == TGSignInResultNotRegistered)
                {
                    int stateDate = [[TGAppDelegateInstance loadLoginState][@"date"] intValue];
                    [TGAppDelegateInstance saveLoginStateWithDate:stateDate phoneNumber:_phoneNumber phoneCode:_phoneCode phoneCodeHash:_phoneCodeHash firstName:nil lastName:nil photo:nil];
                    
                    errorText = nil;
                    [self.navigationController pushViewController:[[TGLoginProfileController alloc] initWithShowKeyboard:_codeField.isFirstResponder phoneNumber:_phoneNumber phoneCodeHash:_phoneCodeHash phoneCode:_phoneCode] animated:true];
                }
                else if (resultCode == TGSignInResultTokenExpired)
                {
                    errorText = TGLocalized(@"Login.CodeExpiredError");
                    setDelegate = true;
                }
                else if (resultCode == TGSignInResultFloodWait)
                {
                    errorText = TGLocalized(@"Login.CodeFloodError");
                }
                else if (resultCode == TGSignInResultInvalidToken)
                {
                    errorText = TGLocalized(@"Login.InvalidCodeError");
                }
                
                if (errorText != nil)
                {
                    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:nil message:errorText delegate:setDelegate ? self : nil cancelButtonTitle:NSLocalizedString(@"Common.OK", nil) otherButtonTitles:nil];
                    [alertView show];
                }
            }
        });
    }
    else if ([path hasPrefix:@"/tg/service/auth/sendCode/"])
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            if (resultCode == ASStatusSuccess)
            {
                [UIView animateWithDuration:0.2 animations:^
                {
                    _requestingCallLabel.alpha = 0.0f;
                }];
                
                [UIView animateWithDuration:0.2 delay:0.1 options:0 animations:^
                {
                    _callSentLabel.alpha = 1.0f;
                } completion:nil];
            }
            else
            {
                NSString *errorText = TGLocalized(@"Login.NetworkError");
                
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

- (void)alertView:(UIAlertView *)__unused alertView clickedButtonAtIndex:(NSInteger)__unused buttonIndex
{
    [self.navigationController popViewControllerAnimated:true];
}

@end
