#import "TGLoginProfileController.h"

#import "TGToolbarButton.h"

#import "TGImageUtils.h"

#import "TGProfileController.h"

#import "TGHacks.h"

#import "TGImageUtils.h"

#import "TGAppDelegate.h"

#import "TGSignUpRequestBuilder.h"

#import "TGTelegraph.h"
#import "SGraphObjectNode.h"
#import "TGDatabase.h"

#import "TGLoginInactiveUserController.h"

#import "TGHighlightableButton.h"

#import "TGRemoteImageView.h"

#import "TGActivityIndicatorView.h"

#import "TGApplication.h"

#define TG_USE_CUSTOM_CAMERA false

#if TG_USE_CUSTOM_CAMERA
#import "TGCameraWindow.h"
#endif

#define TGAvatarActionSheetTag ((int)0xF3AEE8CC)
#define TGImageSourceActionSheetTag ((int)0x34281CB0)

@interface TGLoginProfileController () <UITextFieldDelegate, UIActionSheetDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate>

@property (nonatomic) bool showKeyboard;

@property (nonatomic, strong) NSString *phoneNumber;
@property (nonatomic, strong) NSString *phoneCodeHash;
@property (nonatomic, strong) NSString *phoneCode;

@property (nonatomic, strong) TGToolbarButton *nextButton;

@property (nonatomic, strong) TGHighlightableButton *addPhotoButton;
@property (nonatomic, strong) UIImageView *avatarView;

@property (nonatomic, strong) UIImageView *inputFirstNameBackgroundView;
@property (nonatomic, strong) UIImageView *inputLastNameBackgroundView;
@property (nonatomic, strong) UITextField *firstNameField;
@property (nonatomic, strong) UITextField *lastNameField;

@property (nonatomic) CGRect baseFirstNameFieldBackgroundFrame;
@property (nonatomic) CGRect baseFirstNameFieldFrame;
@property (nonatomic) CGRect baseLastNameBackgroundFrame;
@property (nonatomic) CGRect baseLastNameFieldFrame;

@property (nonatomic) bool inProgress;
@property (nonatomic) int currentActionIndex;

@property (nonatomic, strong) UIAlertView *currentAlert;
@property (nonatomic, strong) UIActionSheet *currentActionSheet;

#if TG_USE_CUSTOM_CAMERA
@property (nonatomic, strong) TGCameraWindow *cameraWindow;
#endif

@property (nonatomic, strong) UIImage *imageForPhotoUpload;
@property (nonatomic, strong) NSData *dataForPhotoUpload;

@property (nonatomic, strong) TGActivityIndicatorView *buttonActivityIndicator;

@end

@implementation TGLoginProfileController

- (id)initWithShowKeyboard:(bool)showKeyboard phoneNumber:(NSString *)phoneNumber phoneCodeHash:(NSString *)phoneCodeHash phoneCode:(NSString *)phoneCode
{
    self = [super initWithNibName:nil bundle:nil];
    if (self)
    {
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:true];
        
        _showKeyboard = showKeyboard;
        _phoneNumber = phoneNumber;
        _phoneCodeHash = phoneCodeHash;
        _phoneCode = phoneCode;
        
        self.style = TGViewControllerStyleBlack;
        
        [ActionStageInstance() watchForPath:@"/tg/activation" watcher:self];
        [ActionStageInstance() watchForPath:@"/tg/contactListSynchronizationState" watcher:self];
    }
    return self;
}

- (void)dealloc
{
    [self doUnloadView];
    
    _currentAlert.delegate = nil;
    _currentActionSheet.delegate = nil;
    
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
    
    self.titleText = TGLocalized(@"Login.InfoTitle");
    
    UIImage *imageNormal = [[UIImage imageNamed:@"BackButton_Login.png"] stretchableImageWithLeftCapWidth:15 topCapHeight:0];
    UIImage *imageNormalHighlighted = [[UIImage imageNamed:@"BackButton_Login_Pressed.png"] stretchableImageWithLeftCapWidth:15 topCapHeight:0];
    UIImage *imageLandscape = [[UIImage imageNamed:@"BackButton_Login_Landscape.png"] stretchableImageWithLeftCapWidth:15 topCapHeight:0];
    UIImage *imageLandscapeHighlighted = [[UIImage imageNamed:@"BackButton_Login_Landscape_Pressed.png"] stretchableImageWithLeftCapWidth:15 topCapHeight:0];
    
    [self setBackAction:@selector(performClose) imageNormal:imageNormal imageNormalHighlighted:imageNormalHighlighted imageLadscape:imageLandscape imageLandscapeHighlighted:imageLandscapeHighlighted textColor:[UIColor whiteColor] shadowColor:UIColorRGBA(0x07080a, 0.35f)];
    
    _nextButton = [[TGToolbarButton alloc] initWithType:TGToolbarButtonTypeDoneBlack];
    _nextButton.text = NSLocalizedString(@"Common.Next", @"");
    _nextButton.minWidth = 51;
    [_nextButton sizeToFit];
    [_nextButton addTarget:self action:@selector(nextButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:_nextButton];
    
    _buttonActivityIndicator = [[TGActivityIndicatorView alloc] initWithStyle:TGActivityIndicatorViewStyleSmallWhite];
    _buttonActivityIndicator.frame = CGRectOffset(_buttonActivityIndicator.frame, floorf((_nextButton.frame.size.width - _buttonActivityIndicator.frame.size.width) / 2), floorf((_nextButton.frame.size.height - _buttonActivityIndicator.frame.size.height) / 2));
    _buttonActivityIndicator.hidden = true;
    [_nextButton addSubview:_buttonActivityIndicator];
    
    UIImage *buttonImage = [UIImage imageNamed:@"LoginAddPhoto.png"];
    _addPhotoButton = [[TGHighlightableButton alloc] initWithFrame:CGRectMake(0, 0, buttonImage.size.width, buttonImage.size.height)];
    _addPhotoButton.exclusiveTouch = true;
    [_addPhotoButton setBackgroundImage:buttonImage forState:UIControlStateNormal];
    [_addPhotoButton setBackgroundImage:[UIImage imageNamed:@"LoginAddPhoto_Highlighted.png"] forState:UIControlStateHighlighted];
    [_addPhotoButton addTarget:self action:@selector(addPhotoButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_addPhotoButton];
    
    _avatarView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 71, 71)];
    _avatarView.hidden = true;
    _avatarView.userInteractionEnabled = true;
    [_avatarView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(avatarTapped:)]];
    
    UILabel *editLabel = [[UILabel alloc] init];
    editLabel.userInteractionEnabled = false;
    editLabel.tag = 123;
    editLabel.text = TGLocalized(@"Login.InfoAvatarEdit");
    editLabel.textColor = [UIColor whiteColor];
    editLabel.backgroundColor = [UIColor clearColor];
    editLabel.font = [UIFont boldSystemFontOfSize:13];
    [editLabel sizeToFit];
    editLabel.frame = CGRectOffset(editLabel.frame, floorf((_avatarView.frame.size.width - editLabel.frame.size.width) / 2), _avatarView.frame.size.height - editLabel.frame.size.height - 3);
    [_avatarView addSubview:editLabel];
    
    [self.view addSubview:_avatarView];
    
    UILabel *addPhotoLabelFirst = [[UILabel alloc] init];
    addPhotoLabelFirst.text = TGLocalized(@"Login.InfoAvatarAdd");
    addPhotoLabelFirst.font = [UIFont boldSystemFontOfSize:15];
    addPhotoLabelFirst.backgroundColor = [UIColor clearColor];
    addPhotoLabelFirst.textColor = UIColorRGB(0x9fa4ac);
    addPhotoLabelFirst.shadowColor = UIColorRGB(0x22262c);
    addPhotoLabelFirst.shadowOffset = CGSizeMake(0, 1);
    [addPhotoLabelFirst sizeToFit];
    
    UILabel *addPhotoLabelSecond = [[UILabel alloc] init];
    addPhotoLabelSecond.text = TGLocalized(@"Login.InfoAvatarPhoto");
    addPhotoLabelSecond.font = [UIFont boldSystemFontOfSize:15];
    addPhotoLabelSecond.backgroundColor = [UIColor clearColor];
    addPhotoLabelSecond.textColor = UIColorRGB(0x9fa4ac);
    addPhotoLabelSecond.shadowColor = UIColorRGB(0x22262c);
    addPhotoLabelSecond.shadowOffset = CGSizeMake(0, 1);
    [addPhotoLabelSecond sizeToFit];
    
    addPhotoLabelFirst.frame = CGRectIntegral(CGRectMake((_addPhotoButton.frame.size.width - addPhotoLabelFirst.frame.size.width) / 2, 16, addPhotoLabelFirst.frame.size.width, addPhotoLabelFirst.frame.size.height));
    addPhotoLabelSecond.frame = CGRectIntegral(CGRectMake((_addPhotoButton.frame.size.width - addPhotoLabelSecond.frame.size.width) / 2, 32, addPhotoLabelSecond.frame.size.width, addPhotoLabelSecond.frame.size.height));
    
    [_addPhotoButton addSubview:addPhotoLabelFirst];
    [_addPhotoButton addSubview:addPhotoLabelSecond];
    
    UIImage *rawInputImageTop = [UIImage imageNamed:@"LoginInput_Top.png"];
    UIImage *rawInputImageBottom = [UIImage imageNamed:@"LoginInput_Bottom.png"];
    
    _inputFirstNameBackgroundView = [[UIImageView alloc] initWithImage:[rawInputImageTop stretchableImageWithLeftCapWidth:(int)(rawInputImageTop.size.width / 2) topCapHeight:0]];
    [self.view addSubview:_inputFirstNameBackgroundView];
    _inputFirstNameBackgroundView.userInteractionEnabled = true;
    [_inputFirstNameBackgroundView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(inputFirstNameBackgroundTapped:)]];
    
    _inputLastNameBackgroundView = [[UIImageView alloc] initWithImage:[rawInputImageBottom stretchableImageWithLeftCapWidth:(int)(rawInputImageBottom.size.width / 2) topCapHeight:0]];
    [self.view addSubview:_inputLastNameBackgroundView];
    _inputLastNameBackgroundView.userInteractionEnabled = true;
    [_inputLastNameBackgroundView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(inputLastNameBackgroundTapped:)]];
    
    _firstNameField = [[UITextField alloc] init];
    _firstNameField.font = [UIFont boldSystemFontOfSize:15.0f];
    _firstNameField.backgroundColor = [UIColor clearColor];
    _firstNameField.placeholder = TGLocalized(@"Login.InfoFirstNamePlaceholder");
    _firstNameField.keyboardType = UIKeyboardTypeDefault;
    _firstNameField.returnKeyType = UIReturnKeyNext;
    _firstNameField.delegate = self;
    [TGHacks setTextFieldPlaceholderColor:_firstNameField color:UIColorRGB(0x999da4)];
    [self.view addSubview:_firstNameField];
    
    _lastNameField = [[UITextField alloc] init];
    _lastNameField.font = [UIFont boldSystemFontOfSize:15.0f];
    _lastNameField.backgroundColor = [UIColor clearColor];
    _lastNameField.placeholder = TGLocalized(@"Login.InfoLastNamePlaceholder");
    _lastNameField.keyboardType = UIKeyboardTypeDefault;
    _lastNameField.returnKeyType = UIReturnKeyDone;
    _lastNameField.delegate = self;
    [TGHacks setTextFieldPlaceholderColor:_lastNameField color:UIColorRGB(0x999da4)];
    [self.view addSubview:_lastNameField];
    
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
    _firstNameField.delegate = nil;
    _lastNameField.delegate = nil;
}

- (void)viewDidUnload
{
    [self doUnloadView];
    
    [super viewDidUnload];
}

- (void)viewWillAppear:(BOOL)animated
{
    [_firstNameField becomeFirstResponder];
    
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
    
    float keyboardHeight = 216;
    
    topOffset = MIN(topOffset, 20 + 50);
    
    CGSize screenSize = [TGViewController screenSizeForInterfaceOrientation:orientation];
    CGSize viewSize = CGSizeMake(320, screenSize.height - 20 - (UIInterfaceOrientationIsPortrait(orientation) ? 44 : 32));
    viewSize.height -= keyboardHeight;
    
    float offsetX = floorf((screenSize.width - viewSize.width) / 2);
    
    float width = 288;
    
    bool isLandscapeWithKeyboard = UIInterfaceOrientationIsLandscape(orientation) && keyboardHeight > FLT_EPSILON;
    
    _addPhotoButton.frame = CGRectMake(offsetX + (int)((viewSize.width - width) / 2) - 2, topOffset + (int)((viewSize.height - 68) / 2) - (isLandscapeWithKeyboard ? 12 : 0) - 7, _addPhotoButton.frame.size.width, _addPhotoButton.frame.size.height);
    _avatarView.frame = CGRectMake(offsetX + _addPhotoButton.frame.origin.x, _addPhotoButton.frame.origin.y, _avatarView.frame.size.width, _avatarView.frame.size.height);
    
    float fieldX = _addPhotoButton.frame.origin.x + _addPhotoButton.frame.size.width + 14;
    _inputFirstNameBackgroundView.frame = _baseFirstNameFieldBackgroundFrame = CGRectMake(fieldX, topOffset + (int)((viewSize.height - 68) / 2) - (isLandscapeWithKeyboard ? 12 : 0) - (UIInterfaceOrientationIsPortrait(orientation) ? 7 : 0), offsetX + width - fieldX + 17, 43);
    _inputLastNameBackgroundView.frame = _baseLastNameBackgroundFrame = CGRectIntegral(CGRectMake(_inputFirstNameBackgroundView.frame.origin.x, _inputFirstNameBackgroundView.frame.origin.y + _inputFirstNameBackgroundView.frame.size.height, _inputFirstNameBackgroundView.frame.size.width, 43));
    
    _firstNameField.frame =  _baseFirstNameFieldFrame = CGRectMake(_inputFirstNameBackgroundView.frame.origin.x + 15, _inputFirstNameBackgroundView.frame.origin.y + (TGIsRetina() ? 11.5f : 11.0f), _inputFirstNameBackgroundView.frame.size.width - 20, 22);
    _lastNameField.frame = _baseLastNameFieldFrame = CGRectMake(_inputLastNameBackgroundView.frame.origin.x + 15, _inputLastNameBackgroundView.frame.origin.y + (TGIsRetina() ? 10.5f : 10.0f), _inputLastNameBackgroundView.frame.size.width - 20, 22);
}

#pragma mark -

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (textField == _firstNameField)
    {
        [_lastNameField becomeFirstResponder];
    }
    else if (textField == _lastNameField)
    {
        [self nextButtonPressed];
    }
    
    return false;
}

#pragma mark -

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    if (_inProgress)
        return false;
    
    if (textField == _firstNameField || textField == _lastNameField)
    {
        NSString *newText = [textField.text stringByReplacingCharactersInRange:range withString:string];
        if (newText.length > 30)
            return false;
        return true;
    }
    
    return true;
}

#pragma mark -

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
            _nextButton.text = TGLocalized(@"Common.Done");
            [_nextButton sizeToFit];
            [_buttonActivityIndicator stopAnimating];
            _buttonActivityIndicator.hidden = true;
        }
    }
}

- (void)backgroundTapped:(UITapGestureRecognizer *)recognizer
{
    return;
    
    if (recognizer.state == UIGestureRecognizerStateRecognized)
    {
        [_firstNameField resignFirstResponder];
        [_lastNameField resignFirstResponder];
    }
}

- (void)inputFirstNameBackgroundTapped:(UITapGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateRecognized)
    {
        [_firstNameField becomeFirstResponder];
    }
}

- (void)inputLastNameBackgroundTapped:(UITapGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateRecognized)
    {
        [_lastNameField becomeFirstResponder];
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

- (NSString *)cleanString:(NSString *)string
{
    NSString *withoutWhitespace = [string stringByReplacingOccurrencesOfString:@" +" withString:@" "
                                                                       options:NSRegularExpressionSearch
                                                                         range:NSMakeRange(0, string.length)];
    withoutWhitespace = [withoutWhitespace stringByReplacingOccurrencesOfString:@"\n\n+" withString:@"\n\n"
                                                                        options:NSRegularExpressionSearch
                                                                          range:NSMakeRange(0, withoutWhitespace.length)];
    return [withoutWhitespace stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (void)nextButtonPressed
{
    if (_inProgress)
        return;
    
    NSString *firstNameText = [self cleanString:_firstNameField.text];
    NSString *lastNameText = [self cleanString:_lastNameField.text];
    
    if (firstNameText.length == 0)
    {
        [self shakeView:_firstNameField originalX:_baseFirstNameFieldFrame.origin.x];
        [self shakeView:_inputFirstNameBackgroundView originalX:_baseFirstNameFieldBackgroundFrame.origin.x];
    }
    else if (lastNameText.length == 0)
    {
        [self shakeView:_lastNameField originalX:_baseLastNameFieldFrame.origin.x];
        [self shakeView:_inputLastNameBackgroundView originalX:_baseLastNameBackgroundFrame.origin.x];
    }
    else
    {
        self.inProgress = true;
        
        static int actionIndex = 0;
        _currentActionIndex = actionIndex++;
        [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/service/auth/signUp/(%d)", _currentActionIndex] options:[NSDictionary dictionaryWithObjectsAndKeys:_phoneNumber, @"phoneNumber", _phoneCode, @"phoneCode", _phoneCodeHash, @"phoneCodeHash", firstNameText, @"firstName", lastNameText, @"lastName", nil] watcher:self];
    }
}

- (void)addPhotoButtonPressed
{
#if TG_USE_CUSTOM_CAMERA
    _cameraWindow = [[TGCameraWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    _cameraWindow.watcherHandle = _actionHandle;
    [_cameraWindow show];
#else
    if (_currentActionSheet != nil)
        _currentActionSheet.delegate = nil;
    
    _currentActionSheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
    _currentActionSheet.tag = TGImageSourceActionSheetTag;
    [_currentActionSheet addButtonWithTitle:TGLocalized(@"Common.TakePhoto")];
    [_currentActionSheet addButtonWithTitle:TGLocalized(@"Common.ChoosePhoto")];
    _currentActionSheet.cancelButtonIndex = [_currentActionSheet addButtonWithTitle:NSLocalizedString(@"Common.Cancel", nil)];
    [_currentActionSheet showInView:self.view];
#endif
}

- (void)avatarTapped:(UITapGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateRecognized)
    {
        if (_currentActionSheet != nil)
            _currentActionSheet.delegate = nil;
        
        _currentActionSheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
        _currentActionSheet.tag = TGAvatarActionSheetTag;
        [_currentActionSheet addButtonWithTitle:TGLocalized(@"Login.InfoUpdatePhoto")];
        _currentActionSheet.destructiveButtonIndex = [_currentActionSheet addButtonWithTitle:TGLocalized(@"Login.InfoDeletePhoto")];
        _currentActionSheet.cancelButtonIndex = [_currentActionSheet addButtonWithTitle:NSLocalizedString(@"Common.Cancel", nil)];
        [_currentActionSheet showInView:self.view];
    }
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    _currentActionSheet.delegate = nil;
    _currentActionSheet = nil;
    
    if (actionSheet.tag == TGAvatarActionSheetTag)
    {
        if (buttonIndex == actionSheet.destructiveButtonIndex)
        {
            _addPhotoButton.alpha = 1.0f;
            _addPhotoButton.hidden = false;
            _avatarView.image = nil;
            _avatarView.alpha = 0.0f;
            _avatarView.hidden = true;
            _dataForPhotoUpload = nil;
            _imageForPhotoUpload = nil;
        }
        else if (buttonIndex != actionSheet.cancelButtonIndex)
        {
            [self addPhotoButtonPressed];
        }
    }
    else if (actionSheet.tag == TGImageSourceActionSheetTag)
    {
        if (buttonIndex == 0 || buttonIndex == 1)
        {
            if (buttonIndex == 0 && ![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera])
                return;
            
            [self.view endEditing:true];
            
            [(TGApplication *)[UIApplication sharedApplication] setProcessStatusBarHiddenRequests:true];
            
            UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
            imagePicker.sourceType = buttonIndex == 0 ? UIImagePickerControllerSourceTypeCamera : UIImagePickerControllerSourceTypePhotoLibrary;
            imagePicker.allowsEditing = true;
            imagePicker.delegate = self;
            
            [self presentViewController:imagePicker animated:true completion:nil];
        }
    }
}

- (void)imagePickerController:(UIImagePickerController *)__unused picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    [self dismissViewControllerAnimated:true completion:nil];
    
    [(TGApplication *)[UIApplication sharedApplication] setProcessStatusBarHiddenRequests:false];
    
    CGRect cropRect = [[info objectForKey:UIImagePickerControllerCropRect] CGRectValue];
    if (ABS(cropRect.size.width - cropRect.size.height) > FLT_EPSILON)
    {
        if (cropRect.size.width < cropRect.size.height)
        {
            cropRect.origin.x -= (cropRect.size.height - cropRect.size.width) / 2;
            cropRect.size.width = cropRect.size.height;
        }
        else
        {
            cropRect.origin.y -= (cropRect.size.width - cropRect.size.height) / 2;
            cropRect.size.height = cropRect.size.width;
        }
    }
    
    UIImage *image = TGFixOrientationAndCrop([info objectForKey:UIImagePickerControllerOriginalImage], cropRect, CGSizeMake(600, 600));
    
    NSData *imageData = UIImageJPEGRepresentation(image, 0.5f);
    if (imageData == nil)
        return;
    
    TGImageProcessor filter = [TGRemoteImageView imageProcessorForName:@"signupProfileAvatar"];
    UIImage *toImage = filter(image);
    
    _avatarView.hidden = false;
    _avatarView.alpha = 1.0f;
    _addPhotoButton.hidden = true;
    _addPhotoButton.alpha = 0.0f;
    _avatarView.image = toImage;
    
    _dataForPhotoUpload = imageData;
    _imageForPhotoUpload = ([TGRemoteImageView imageProcessorForName:@"profileAvatar"])(image);
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)__unused picker
{
    [self dismissViewControllerAnimated:true completion:nil];
    
    [(TGApplication *)[UIApplication sharedApplication] setProcessStatusBarHiddenRequests:true];
}

#pragma mark -

- (void)actorCompleted:(int)resultCode path:(NSString *)path result:(id)__unused result
{
    if ([path isEqualToString:[NSString stringWithFormat:@"/tg/service/auth/signUp/(%d)", _currentActionIndex]])
    {
        if (resultCode == ASStatusSuccess && _dataForPhotoUpload != nil)
        {
            NSMutableDictionary *options = [[NSMutableDictionary alloc] init];
            
            uint8_t fileId[32];
            arc4random_buf(&fileId, 32);
            
            NSMutableString *filePath = [[NSMutableString alloc] init];
            for (int i = 0; i < 32; i++)
            {
                [filePath appendFormat:@"%02x", fileId[i]];
            }
            
            NSString *tmpImagesPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true) objectAtIndex:0] stringByAppendingPathComponent:@"upload"];
            static NSFileManager *fileManager = nil;
            if (fileManager == nil)
                fileManager = [[NSFileManager alloc] init];
            NSError *error = nil;
            [fileManager createDirectoryAtPath:tmpImagesPath withIntermediateDirectories:true attributes:nil error:&error];
            NSString *absoluteFilePath = [tmpImagesPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.bin", filePath]];
            [_dataForPhotoUpload writeToFile:absoluteFilePath atomically:false];
            
            [options setObject:filePath forKey:@"originalFileUrl"];
            [options setObject:_imageForPhotoUpload forKey:@"currentPhoto"];
            
            NSString *action = [[NSString alloc] initWithFormat:@"/tg/timeline/(%d)/uploadPhoto/(%@)", TGTelegraphInstance.clientUserId, filePath];
            [ActionStageInstance() requestActor:action options:options watcher:TGTelegraphInstance];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^
        {
            if (resultCode == ASStatusSuccess)
            {
                if ([[((SGraphObjectNode *)result).object objectForKey:@"activated"] boolValue])
                {
                    self.inProgress = false;
                    
                    [TGAppDelegateInstance presentMainController];
                }
            }
            else
            {
                self.inProgress = false;
                
                NSString *errorText = @"Unknown error";
                if (resultCode == TGSignUpResultInvalidToken)
                    errorText = NSLocalizedString(@"Login.InvalidCodeError", @"");
                else if (resultCode == TGSignUpResultNetworkError)
                    errorText = NSLocalizedString(@"Login.NetworkError", @"");
                else if (resultCode == TGSignUpResultTokenExpired)
                    errorText = NSLocalizedString(@"Login.CodeExpiredError", @"");
                else if (resultCode == TGSignUpResultFloodWait)
                    errorText = NSLocalizedString(@"Login.CodeFloodError", @"");
                else if (resultCode == TGSignUpResultInvalidFirstName)
                    errorText = TGLocalized(@"Login.InvalidFirstNameError");
                else if (resultCode == TGSignUpResultInvalidLastName)
                    errorText = TGLocalized(@"Login.InvalidLastNameError");
                
                UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:nil message:errorText delegate:nil cancelButtonTitle:NSLocalizedString(@"Common.OK", nil) otherButtonTitles:nil];
                [alertView show];
            }
        });
    }
}

- (void)actionStageResourceDispatched:(NSString *)path resource:(id)resource arguments:(id)__unused arguments
{
    if ([path isEqualToString:@"/tg/activation"])
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
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
                if (activated)
                    [TGAppDelegateInstance presentMainController];
                else
                {
                    if (![[self.navigationController.viewControllers lastObject] isKindOfClass:[TGLoginInactiveUserController class]])
                    {
                        TGLoginInactiveUserController *inactiveUserController = [[TGLoginInactiveUserController alloc] init];
                        [self.navigationController pushViewController:inactiveUserController animated:true];
                    }
                    else
                        self.inProgress = false;
                }
            });
        }
    }
}

- (void)actionStageActionRequested:(NSString *)action options:(NSDictionary *)__unused options
{
    if ([action isEqualToString:@"dismissCamera"])
    {
#if TG_USE_CUSTOM_CAMERA
        if (_cameraWindow != nil)
        {
            [_cameraWindow dismiss];
            _cameraWindow = nil;
        }
#endif
    }
    else if ([action isEqualToString:@"cameraCompleted"])
    {
#if TG_USE_CUSTOM_CAMERA
        if (_cameraWindow != nil)
        {
            NSData *imageData = [options objectForKey:@"imageData"];
            UIImage *image = [options objectForKey:@"image"];
            
            if (imageData == nil)
                return;
            
            TGImageProcessor filter = [TGRemoteImageView imageProcessorForName:@"signupProfileAvatar"];
            UIImage *toImage = filter(image);
            
            [_avatarView viewWithTag:123].alpha = 0.0f;
            
            [_cameraWindow dismissToRect:[_avatarView convertRect:_avatarView.bounds toView:self.view.window] fromImage:image toImage:toImage toView:self.view aboveView:_avatarView interfaceOrientation:self.interfaceOrientation];
            _cameraWindow = nil;
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((0.29 * TGAnimationSpeedFactor()) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^
            {
                _avatarView.hidden = false;
                _avatarView.alpha = 1.0f;
                _addPhotoButton.hidden = true;
                _addPhotoButton.alpha = 0.0f;
                _avatarView.image = toImage;
                
                _dataForPhotoUpload = imageData;
                _imageForPhotoUpload = ([TGRemoteImageView imageProcessorForName:@"profileAvatar"])(image);
                
                [UIView animateWithDuration:0.25 animations:^
                {
                    [_avatarView viewWithTag:123].alpha = 1.0f;
                }];
            });
        }
#endif
    }
}

@end
