#import "TGEncryptionKeyViewController.h"

#import "TGInterfaceAssets.h"

#import "TGSecurity.h"
#import "TGImageUtils.h"

#import "TGDatabase.h"

@interface TGEncryptionKeyViewController ()

@property (nonatomic) int64_t encryptedConversationId;
@property (nonatomic) int userId;

@property (nonatomic, strong) UIImageView *keyBackgroundView;
@property (nonatomic, strong) UIImageView *keyImageView;

@property (nonatomic, strong) UILabel *descriptionLabel;
@property (nonatomic, strong) NSString *userName;

@property (nonatomic, strong) UILabel *pendingLabel;

@property (nonatomic, strong) UIButton *linkButton;

@end

@implementation TGEncryptionKeyViewController

- (id)initWithEncryptedConversationId:(int64_t)encryptedConversationId userId:(int)userId
{
    self = [super init];
    if (self)
    {
        _encryptedConversationId = encryptedConversationId;
        _userId = userId;
        
        _userName = [TGDatabaseInstance() loadUser:userId].displayFirstName;
    }
    return self;
}

- (void)loadView
{
    [super loadView];
    
    self.backAction = @selector(performClose);
    
    self.titleText = TGLocalized(@"EncryptionKey.Title");
    
    self.view.backgroundColor = [[TGInterfaceAssets instance] linesBackground];
    
    UIImage *rawImage = [UIImage imageNamed:@"EncryptionKeyBackground.png"];
    
    _keyBackgroundView = [[UIImageView alloc] initWithImage:[rawImage stretchableImageWithLeftCapWidth:(int)(rawImage.size.width / 2) topCapHeight:(int)(rawImage.size.height / 2)]];
    [self.view addSubview:_keyBackgroundView];
    
    _keyImageView = [[UIImageView alloc] init];
    [self.view addSubview:_keyImageView];
    
    _descriptionLabel = [[UILabel alloc] init];
    _descriptionLabel.textColor = UIColorRGB(0x4f627a);
    _descriptionLabel.backgroundColor = [UIColor clearColor];
    _descriptionLabel.font = [UIFont systemFontOfSize:14];
    _descriptionLabel.textAlignment = NSTextAlignmentCenter;
    _descriptionLabel.numberOfLines = 0;
    [self.view addSubview:_descriptionLabel];
    
    _linkButton = [[UIButton alloc] init];
    [_linkButton setBackgroundImage:[UIImage imageNamed:@"Transparent.png"] forState:UIControlStateNormal];
    UIImage *rawLinkImage = [UIImage imageNamed:@"LinkFull.png"];
    [_linkButton setBackgroundImage:[rawLinkImage stretchableImageWithLeftCapWidth:(int)(rawLinkImage.size.width / 2) topCapHeight:(int)(rawLinkImage.size.height / 2)] forState:UIControlStateHighlighted];
    [_linkButton addTarget:self action:@selector(linkButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_linkButton];
    
    NSString *textFormat = TGLocalized(@"EncryptionKey.Description");
    NSString *baseText = [[NSString alloc] initWithFormat:textFormat, _userName, _userName];
    
    if ([_descriptionLabel respondsToSelector:@selector(setAttributedText:)])
    {
        NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:_descriptionLabel.font, NSFontAttributeName, nil];
        NSDictionary *subAttrs = [NSDictionary dictionaryWithObjectsAndKeys:[UIFont boldSystemFontOfSize:_descriptionLabel.font.pointSize], NSFontAttributeName, nil];
        NSDictionary *linkAtts = @{NSForegroundColorAttributeName: UIColorRGB(0x146ab3)};
        
        NSMutableAttributedString *attributedText = [[NSMutableAttributedString alloc] initWithString:baseText attributes:attrs];
        
        [attributedText setAttributes:subAttrs range:NSMakeRange([textFormat rangeOfString:@"%1$@"].location, _userName.length)];
        [attributedText setAttributes:subAttrs range:NSMakeRange([textFormat rangeOfString:@"%2$@"].location + (_userName.length - @"%1$@".length), _userName.length)];
        [attributedText setAttributes:linkAtts range:[baseText rangeOfString:@"telegram.org"]];
        
        [_descriptionLabel setAttributedText:attributedText];
    }
    else
    {
        [_descriptionLabel setText:baseText];
    }
    
    _pendingLabel = [[UILabel alloc] init];
    _pendingLabel.font = [UIFont boldSystemFontOfSize:15];
    _pendingLabel.text = [TGDatabaseInstance() loadConversationWithId:[TGDatabaseInstance() peerIdForEncryptedConversationId:_encryptedConversationId]].encryptedData.handshakeState == 3 ? TGLocalized(@"EncryptionKey.EncryptionRejected") : TGLocalized(@"EncryptionKey.AwaitingEncryption");
    _pendingLabel.backgroundColor = [UIColor clearColor];
    _pendingLabel.font = [UIFont boldSystemFontOfSize:15];
    _pendingLabel.textColor = UIColorRGB(0x697487);
    _pendingLabel.shadowColor = UIColorRGBA(0xffffff, 0.7f);
    _pendingLabel.shadowOffset = CGSizeMake(0, 1);
    [_pendingLabel sizeToFit];
    [self.view addSubview:_pendingLabel];
    
    NSData *keyData = [TGDatabaseInstance() encryptionKeyForConversationId:[TGDatabaseInstance() peerIdForEncryptedConversationId:_encryptedConversationId] keyFingerprint:NULL];
    if (keyData != nil)
    {
        NSData *hashData = computeSHA1(keyData);
        if (hashData != nil)
        {
            UIImage *image = TGIdenticonImage(hashData, CGSizeMake(264, 264));
            _keyImageView.image = image;
        }
        
        _pendingLabel.hidden = true;
    }
    else
    {
        _keyImageView.hidden = true;
        _keyBackgroundView.hidden = true;
        _descriptionLabel.hidden = true;
        
        _pendingLabel.hidden = false;
    }
    
    UISwipeGestureRecognizer *swipeRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeRecognized:)];
    swipeRecognizer.direction = UISwipeGestureRecognizerDirectionRight;
    [self.view addGestureRecognizer:swipeRecognizer];
    
    if (![self _updateControllerInset:false])
        [self controllerInsetUpdated:UIEdgeInsetsZero];
}

- (void)performClose
{
    [self.navigationController popViewControllerAnimated:true];
}

- (void)swipeRecognized:(UISwipeGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateRecognized)
    {
        [self performClose];
    }
}

- (void)controllerInsetUpdated:(UIEdgeInsets)previousInset
{
    [super controllerInsetUpdated:previousInset];
    
    [self updateLayout:self.interfaceOrientation];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [self updateLayout:toInterfaceOrientation];
    
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
}

- (void)updateLayout:(UIInterfaceOrientation)orientation
{
    CGSize screenSize = [TGViewController screenSizeForInterfaceOrientation:orientation];
    
    if (screenSize.width < 400)
    {
        CGSize labelSize = [_descriptionLabel sizeThatFits:CGSizeMake(screenSize.width - 20, 1000)];
     
        float keySize = [TGViewController isWidescreen] ? 264 : 220;
        
        _keyImageView.frame = CGRectMake(floorf((self.view.frame.size.width - keySize) / 2), self.controllerInset.top + 28, keySize, keySize);
        
        _descriptionLabel.frame = CGRectMake(floorf((screenSize.width - labelSize.width) / 2), _keyImageView.frame.origin.y + _keyImageView.frame.size.height + 24, labelSize.width, labelSize.height);
        
        NSString *lineText = @"Learn more at telegram.org";
        float lastWidth = [lineText sizeWithFont:_descriptionLabel.font].width;
        float prefixWidth = [@"Learn more at " sizeWithFont:_descriptionLabel.font].width;
        float suffixWidth = [@"telegram.org" sizeWithFont:_descriptionLabel.font].width;
        
        _linkButton.frame = CGRectMake(_descriptionLabel.frame.origin.x + floorf((_descriptionLabel.frame.size.width - lastWidth) / 2) + prefixWidth - 3, _descriptionLabel.frame.origin.y + _descriptionLabel.frame.size.height - 18, suffixWidth + 4, 19);
    }
    else
    {
        _keyImageView.frame = CGRectMake(10, self.controllerInset.top + 10, 248, 248);
        
        CGSize labelSize = [_descriptionLabel sizeThatFits:CGSizeMake(200, 1000)];
        
        _descriptionLabel.frame = CGRectMake(_keyImageView.frame.origin.x + _keyImageView.frame.size.width + floorf((screenSize.width - (_keyImageView.frame.origin.x + _keyImageView.frame.size.width) - labelSize.width) / 2), self.controllerInset.top + floorf(((screenSize.height - self.controllerInset.top) - labelSize.height) / 2), labelSize.width, labelSize.height);
        
        NSString *lineText = @"Learn more at telegram.org";
        float lastWidth = [lineText sizeWithFont:_descriptionLabel.font].width;
        float prefixWidth = [@"Learn more at " sizeWithFont:_descriptionLabel.font].width;
        float suffixWidth = [@"telegram.org" sizeWithFont:_descriptionLabel.font].width;
        
        _linkButton.frame = CGRectMake(_descriptionLabel.frame.origin.x + floorf((_descriptionLabel.frame.size.width - lastWidth) / 2) + prefixWidth - 3, _descriptionLabel.frame.origin.y + _descriptionLabel.frame.size.height - 18, suffixWidth + 4, 19);
    }
    
    _keyBackgroundView.frame = CGRectMake(_keyImageView.frame.origin.x - 2, _keyImageView.frame.origin.y - 2, _keyImageView.frame.size.width + 4, _keyImageView.frame.size.height + 5);
    
    _pendingLabel.frame = CGRectMake(floorf((screenSize.width - _pendingLabel.frame.size.width) / 2), self.controllerInset.top + floorf(((screenSize.height - self.controllerInset.top) - _pendingLabel.frame.size.height) / 2), _pendingLabel.frame.size.width, _pendingLabel.frame.size.height);
}

- (void)linkButtonPressed
{
    [[UIApplication sharedApplication] openURL:[[NSURL alloc] initWithString:@"http://telegram.org"]];
}

@end
