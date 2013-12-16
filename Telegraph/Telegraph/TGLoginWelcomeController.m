#import "TGLoginWelcomeController.h"

#import "TGImageUtils.h"

#import "TGLoginPhoneController.h"

#import "TGHacks.h"

#import "TGSession.h"
#import "TGAppDelegate.h"

#import "TGHighlightableButton.h"

#import "TGPagerView.h"

@interface TGLoginWelcomeController () <UIScrollViewDelegate>

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) TGPagerView *pagerView;

@property (nonatomic, strong) NSArray *images;

@property (nonatomic, strong) UIView *imagesContainer;
@property (nonatomic, strong) UIImageView *topImageView;
@property (nonatomic) int currentTopImage;
@property (nonatomic, strong) UIImageView *bottomImageView;
@property (nonatomic) int currentBottomImage;

@property (nonatomic) bool firstAppear;

@property (nonatomic) int maxPage;

@end

@implementation TGLoginWelcomeController

- (id)init
{
    self = [super initWithNibName:nil bundle:nil];
    if (self != nil)
    {
        NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
        NSDateComponents *components = [calendar components:(NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit) fromDate:[NSDate date]];
        NSInteger day = [components day];
        NSInteger month = [components month];
        NSInteger year = [components year];
        
        if (year > 2013 || day >= 22 || month > 10)
            _maxPage = 6;
        else
            _maxPage = 5;
        
        self.wantsFullScreenLayout = true;
        
        self.automaticallyManageScrollViewInsets = false;
        self.autoManageStatusBarBackground = false;
        
        self.navigationBarShouldBeHidden = true;
    }
    return self;
}

- (void)dealloc
{
    _scrollView.delegate = nil;
}

- (void)loadView
{
    [super loadView];
    
    bool isWidescreen = [TGViewController isWidescreen];
    CGSize screenSize = [TGViewController screenSizeForInterfaceOrientation:UIInterfaceOrientationPortrait];

    _imagesContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, screenSize.width, screenSize.height)];
    _imagesContainer.clipsToBounds = true;
    [self.view addSubview:_imagesContainer];
    
    _bottomImageView = [[UIImageView alloc] initWithFrame:CGRectMake(-20, -20, screenSize.width + 40, screenSize.height + 40)];
    _bottomImageView.contentMode = UIViewContentModeScaleAspectFill;
    [_imagesContainer addSubview:_bottomImageView];
    
    _topImageView = [[UIImageView alloc] initWithFrame:CGRectMake(-20, -20, screenSize.width + 40, screenSize.height + 40)];
    _topImageView.contentMode = UIViewContentModeScaleAspectFill;
    [_imagesContainer addSubview:_topImageView];
    
    UIImage *rawShadowImage = [UIImage imageNamed:@"HomeShadow.png"];
    UIImageView *largeShadowView = [[UIImageView alloc] initWithFrame:CGRectMake(0, self.view.bounds.size.height - rawShadowImage.size.height + 1, self.view.bounds.size.width, rawShadowImage.size.height)];
    largeShadowView.tag = (int)0x7DD07B55;
    largeShadowView.image = rawShadowImage;
    largeShadowView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [self.view addSubview:largeShadowView];
    
    _currentTopImage = -1;
    _currentBottomImage = -1;
    
    NSString *basePath = [[NSBundle mainBundle] bundlePath];
    NSMutableArray *imagesArray = [[NSMutableArray alloc] init];
    for (int i = 0; i < 8; i++)
    {
        UIImage *image = [[UIImage alloc] initWithContentsOfFile:[basePath stringByAppendingPathComponent:[[NSString alloc] initWithFormat:@"Tour.bundle/Tour%d.jpg", i]]];
        if (image != nil)
            [imagesArray addObject:image];
        else
            [imagesArray addObject:[NSNull null]];
    }
    _images = imagesArray;
    
    _scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, screenSize.width, screenSize.height)];
    _scrollView.pagingEnabled = true;
    _scrollView.showsHorizontalScrollIndicator = false;
    _scrollView.showsVerticalScrollIndicator = false;
    _scrollView.contentSize = CGSizeMake(screenSize.width * (_maxPage + 1), screenSize.height);
    _scrollView.delaysContentTouches = false;
    _scrollView.delegate = self;
    [self.view addSubview:_scrollView];
    
    UIFont *normalTextFont = [UIFont fontWithName:@"MyriadPro-Regular" size:TGIsRetina() ? 15.5f : 15.0f];
    UIFont *boldTextFont = [UIFont fontWithName:@"MyriadPro-Bold" size:TGIsRetina() ? 15.5f : 15.0f];
    
    UIFont *firstTitleFont = [UIFont fontWithName:@"MyriadPro-Regular" size:18.0f];
    UIFont *firstTitleBoldFont = [UIFont fontWithName:@"MyriadPro-Bold" size:18.0f];
    
    UIFont *titleFont = [UIFont fontWithName:@"MyriadPro-Bold" size:30.0f];
    
    UIImage *rawBackgroundImage = [UIImage imageNamed:@"Tour.bundle/TourContentBackground.png"];
    UIImage *backgroundImage = [rawBackgroundImage stretchableImageWithLeftCapWidth:(int)(rawBackgroundImage.size.width / 2) topCapHeight:(int)(rawBackgroundImage.size.height / 2)];
    
    float currentContentOffset = 0.0f;
    {
        UIImageView *logoView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"Tour.bundle/TourLogo.png"]];
        logoView.frame = CGRectOffset(logoView.frame, currentContentOffset + floorf((screenSize.width - logoView.frame.size.width) / 2), (isWidescreen ? 37 : 24));
        [_scrollView addSubview:logoView];
        
#ifdef INTERNAL_RELEASE
        logoView.userInteractionEnabled = true;
        UITapGestureRecognizer *recognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(viewDoubleTapped:)];
        recognizer.numberOfTapsRequired = 2;
        [logoView addGestureRecognizer:recognizer];
#endif
        
        UIImageView *backgroundView = [[UIImageView alloc] initWithFrame:CGRectMake(currentContentOffset + 27, (isWidescreen ? 206 : 174) + 24, screenSize.width - 27 * 2, 123)];
        backgroundView.image = backgroundImage;
        [_scrollView addSubview:backgroundView];
        
        UILabel *titleLabel = [[UILabel alloc] init];
        titleLabel.backgroundColor = [UIColor clearColor];
        titleLabel.textColor = [UIColor whiteColor];
        titleLabel.font = firstTitleFont;
        
        NSString *baseTitleText = TGLocalized(@"Tour.Title");
        
        if ([UILabel instancesRespondToSelector:@selector(setAttributedText:)])
        {
            NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:titleLabel.font, NSFontAttributeName, titleLabel.textColor, NSForegroundColorAttributeName, nil];
            NSDictionary *subAttrs = [NSDictionary dictionaryWithObjectsAndKeys:firstTitleBoldFont, NSFontAttributeName, nil];
            
            NSMutableAttributedString *attributedText = [[NSMutableAttributedString alloc] initWithString:baseTitleText attributes:attrs];
            
            NSArray *boldWords = @[TGLocalized(@"Tour.TitleTelegram")];
            for (NSString *string in boldWords)
            {
                NSRange range = [baseTitleText rangeOfString:string];
                [attributedText setAttributes:subAttrs range:range];
            }
            
            [titleLabel setAttributedText:attributedText];
        }
        else
        {
            titleLabel.text = baseTitleText;
        }

        [titleLabel sizeToFit];
        titleLabel.frame = CGRectOffset(titleLabel.frame, currentContentOffset + floorf((screenSize.width - titleLabel.frame.size.width) / 2), backgroundView.frame.origin.y + 22);
        [_scrollView addSubview:titleLabel];
        
        UILabel *subtitleLabel = [[UILabel alloc] init];
        subtitleLabel.backgroundColor = [UIColor clearColor];
        subtitleLabel.textAlignment = UITextAlignmentCenter;
        subtitleLabel.textColor = [UIColor whiteColor];
        subtitleLabel.numberOfLines = 0;
        subtitleLabel.font = normalTextFont;
        
        if ([UILabel instancesRespondToSelector:@selector(setAttributedText:)])
        {
            NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:subtitleLabel.font, NSFontAttributeName, subtitleLabel.textColor, NSForegroundColorAttributeName, nil];
            NSDictionary *subAttrs = [NSDictionary dictionaryWithObjectsAndKeys:boldTextFont, NSFontAttributeName, nil];
            
            NSMutableAttributedString *attributedText = [[NSMutableAttributedString alloc] initWithString:TGLocalized(@"Tour.Text1") attributes:attrs];
            
            NSMutableParagraphStyle *paragrahStyle = [[NSMutableParagraphStyle alloc] init];
            [paragrahStyle setLineSpacing:5];
            [paragrahStyle setAlignment:NSTextAlignmentCenter];
            [attributedText addAttribute:NSParagraphStyleAttributeName value:paragrahStyle range:NSMakeRange(0, [TGLocalized(@"Tour.Text1") length])];
            
            NSArray *boldWords = @[@"fastest", @"free", @"secure"];
            for (NSString *string in boldWords)
            {
                NSRange range = [TGLocalized(@"Tour.Text1") rangeOfString:string];
                [attributedText setAttributes:subAttrs range:range];
            }
            
            [subtitleLabel setAttributedText:attributedText];
        }
        else
        {
            subtitleLabel.text = TGLocalized(@"Tour.Text1");
        }
        
        CGSize textSize = [subtitleLabel sizeThatFits:CGSizeMake(240, 1000)];
        subtitleLabel.frame = CGRectMake(currentContentOffset + floorf((screenSize.width - textSize.width) / 2), titleLabel.frame.origin.y + titleLabel.frame.size.height + 26, textSize.width, textSize.height);
        [_scrollView addSubview:subtitleLabel];
    }
    
    currentContentOffset = screenSize.width * 1;
    {
        UIImageView *backgroundView = [[UIImageView alloc] initWithFrame:CGRectMake(currentContentOffset + 27, (isWidescreen ? 101 : 56) + 38, screenSize.width - 27 * 2, 214)];
        backgroundView.image = backgroundImage;
        [_scrollView addSubview:backgroundView];
        
        UIImageView *logoView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"Tour.bundle/TourIcon1.png"]];
        logoView.frame = CGRectOffset(logoView.frame, currentContentOffset + floorf((screenSize.width - logoView.frame.size.width) / 2), backgroundView.frame.origin.y + 12);
        [_scrollView addSubview:logoView];
        
        UILabel *titleLabel = [[UILabel alloc] init];
        titleLabel.backgroundColor = [UIColor clearColor];
        titleLabel.textColor = [UIColor whiteColor];
        titleLabel.font = titleFont;
        titleLabel.text = TGLocalized(@"Tour.Title2");
        [titleLabel sizeToFit];
        titleLabel.frame = CGRectOffset(titleLabel.frame, currentContentOffset + floorf((screenSize.width - titleLabel.frame.size.width) / 2), logoView.frame.origin.y + logoView.frame.size.height + 7);
        [_scrollView addSubview:titleLabel];
        
        UILabel *subtitleLabel1 = [[UILabel alloc] init];
        subtitleLabel1.backgroundColor = [UIColor clearColor];
        subtitleLabel1.textAlignment = UITextAlignmentCenter;
        subtitleLabel1.textColor = [UIColor whiteColor];
        subtitleLabel1.numberOfLines = 0;
        subtitleLabel1.font = normalTextFont;
        
        NSString *baseSubtitleText1 = TGLocalized(@"Tour.Text2");
        
        if ([UILabel instancesRespondToSelector:@selector(setAttributedText:)])
        {
            NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:subtitleLabel1.font, NSFontAttributeName, subtitleLabel1.textColor, NSForegroundColorAttributeName, nil];
            
            NSDictionary *subAttrs = [NSDictionary dictionaryWithObjectsAndKeys:boldTextFont, NSFontAttributeName, nil];
            NSRange range = [baseSubtitleText1 rangeOfString:@"Telegram"];
            
            NSMutableAttributedString *attributedText = [[NSMutableAttributedString alloc] initWithString:baseSubtitleText1 attributes:attrs];
            
            [attributedText setAttributes:subAttrs range:range];
            
            NSMutableParagraphStyle *paragrahStyle = [[NSMutableParagraphStyle alloc] init];
            [paragrahStyle setLineSpacing:5];
            [paragrahStyle setAlignment:NSTextAlignmentCenter];
            [attributedText addAttribute:NSParagraphStyleAttributeName value:paragrahStyle range:NSMakeRange(0, [baseSubtitleText1 length])];
            
            [subtitleLabel1 setAttributedText:attributedText];
        }
        else
        {
            subtitleLabel1.text = baseSubtitleText1;
        }
        
        CGSize subtitleSize1 = [subtitleLabel1 sizeThatFits:CGSizeMake(230, 1000)];
        subtitleLabel1.frame = CGRectMake(currentContentOffset + floorf((screenSize.width - subtitleSize1.width) / 2), titleLabel.frame.origin.y + titleLabel.frame.size.height + 5, subtitleSize1.width, subtitleSize1.height);
        [_scrollView addSubview:subtitleLabel1];
    }
    
    currentContentOffset = screenSize.width * 2;
    {
        UIImageView *backgroundView = [[UIImageView alloc] initWithFrame:CGRectMake(currentContentOffset + 27, (isWidescreen ? 101 : 56) + 33, screenSize.width - 27 * 2, 223)];
        backgroundView.image = backgroundImage;
        [_scrollView addSubview:backgroundView];
        
        UIImageView *logoView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"Tour.bundle/TourIcon2.png"]];
        logoView.frame = CGRectOffset(logoView.frame, currentContentOffset + floorf((screenSize.width - logoView.frame.size.width) / 2), backgroundView.frame.origin.y + 12);
        [_scrollView addSubview:logoView];
        
        UILabel *titleLabel = [[UILabel alloc] init];
        titleLabel.backgroundColor = [UIColor clearColor];
        titleLabel.textColor = [UIColor whiteColor];
        titleLabel.font = titleFont;
        titleLabel.text = TGLocalized(@"Tour.Title3");
        [titleLabel sizeToFit];
        titleLabel.frame = CGRectOffset(titleLabel.frame, currentContentOffset + floorf((screenSize.width - titleLabel.frame.size.width) / 2), logoView.frame.origin.y + logoView.frame.size.height + 7);
        [_scrollView addSubview:titleLabel];
        
        UILabel *subtitleLabel1 = [[UILabel alloc] init];
        subtitleLabel1.backgroundColor = [UIColor clearColor];
        subtitleLabel1.textAlignment = UITextAlignmentCenter;
        subtitleLabel1.textColor = [UIColor whiteColor];
        subtitleLabel1.numberOfLines = 0;
        subtitleLabel1.font = normalTextFont;
        
        NSString *baseSubtitleText1 = TGLocalized(@"Tour.Text3");
        
        if ([UILabel instancesRespondToSelector:@selector(setAttributedText:)])
        {
            NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:subtitleLabel1.font, NSFontAttributeName, subtitleLabel1.textColor, NSForegroundColorAttributeName, nil];
            
            NSDictionary *subAttrs = [NSDictionary dictionaryWithObjectsAndKeys:boldTextFont, NSFontAttributeName, nil];
            NSRange range = [baseSubtitleText1 rangeOfString:@"Telegram"];
            
            NSMutableAttributedString *attributedText = [[NSMutableAttributedString alloc] initWithString:baseSubtitleText1 attributes:attrs];
            
            [attributedText setAttributes:subAttrs range:range];
            
            NSMutableParagraphStyle *paragrahStyle = [[NSMutableParagraphStyle alloc] init];
            [paragrahStyle setLineSpacing:5];
            [paragrahStyle setAlignment:NSTextAlignmentCenter];
            [attributedText addAttribute:NSParagraphStyleAttributeName value:paragrahStyle range:NSMakeRange(0, [baseSubtitleText1 length])];
            
            [subtitleLabel1 setAttributedText:attributedText];
        }
        else
        {
            subtitleLabel1.text = baseSubtitleText1;
        }
        
        CGSize subtitleSize1 = [subtitleLabel1 sizeThatFits:CGSizeMake(230, 1000)];
        subtitleLabel1.frame = CGRectMake(currentContentOffset + floorf((screenSize.width - subtitleSize1.width) / 2), titleLabel.frame.origin.y + titleLabel.frame.size.height + 7, subtitleSize1.width, subtitleSize1.height);
        [_scrollView addSubview:subtitleLabel1];
    }
    
    currentContentOffset = screenSize.width * 3;
    {
        UIImageView *backgroundView = [[UIImageView alloc] initWithFrame:CGRectMake(currentContentOffset + 27, (isWidescreen ? 101 : 56) + 33, screenSize.width - 27 * 2, 223)];
        backgroundView.image = backgroundImage;
        [_scrollView addSubview:backgroundView];
        
        UIImageView *logoView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"Tour.bundle/TourIcon3.png"]];
        logoView.frame = CGRectOffset(logoView.frame, currentContentOffset + floorf((screenSize.width - logoView.frame.size.width) / 2), backgroundView.frame.origin.y + 12);
        [_scrollView addSubview:logoView];
        
        UILabel *titleLabel = [[UILabel alloc] init];
        titleLabel.backgroundColor = [UIColor clearColor];
        titleLabel.textColor = [UIColor whiteColor];
        titleLabel.font = titleFont;
        titleLabel.text = TGLocalized(@"Tour.Title4");
        [titleLabel sizeToFit];
        titleLabel.frame = CGRectOffset(titleLabel.frame, currentContentOffset + floorf((screenSize.width - titleLabel.frame.size.width) / 2), logoView.frame.origin.y + logoView.frame.size.height + 7);
        [_scrollView addSubview:titleLabel];
        
        UILabel *subtitleLabel1 = [[UILabel alloc] init];
        subtitleLabel1.backgroundColor = [UIColor clearColor];
        subtitleLabel1.textAlignment = UITextAlignmentCenter;
        subtitleLabel1.textColor = [UIColor whiteColor];
        subtitleLabel1.numberOfLines = 0;
        subtitleLabel1.font = normalTextFont;
        
        NSString *baseSubtitleText1 = TGLocalized(@"Tour.Text4");
        
        if ([UILabel instancesRespondToSelector:@selector(setAttributedText:)])
        {
            NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:subtitleLabel1.font, NSFontAttributeName, subtitleLabel1.textColor, NSForegroundColorAttributeName, nil];
            
            NSDictionary *subAttrs = [NSDictionary dictionaryWithObjectsAndKeys:boldTextFont, NSFontAttributeName, nil];
            NSRange range = [baseSubtitleText1 rangeOfString:@"Telegram"];
            
            NSMutableAttributedString *attributedText = [[NSMutableAttributedString alloc] initWithString:baseSubtitleText1 attributes:attrs];
            
            [attributedText setAttributes:subAttrs range:range];
            
            NSMutableParagraphStyle *paragrahStyle = [[NSMutableParagraphStyle alloc] init];
            [paragrahStyle setLineSpacing:5];
            [paragrahStyle setAlignment:NSTextAlignmentCenter];
            [attributedText addAttribute:NSParagraphStyleAttributeName value:paragrahStyle range:NSMakeRange(0, [baseSubtitleText1 length])];
            
            [subtitleLabel1 setAttributedText:attributedText];
        }
        else
        {
            subtitleLabel1.text = baseSubtitleText1;
        }
        
        CGSize subtitleSize1 = [subtitleLabel1 sizeThatFits:CGSizeMake(230, 1000)];
        subtitleLabel1.frame = CGRectMake(currentContentOffset + floorf((screenSize.width - subtitleSize1.width) / 2), titleLabel.frame.origin.y + titleLabel.frame.size.height + 7, subtitleSize1.width, subtitleSize1.height);
        [_scrollView addSubview:subtitleLabel1];
    }
    
    currentContentOffset = screenSize.width * 4;
    {
        UIImageView *backgroundView = [[UIImageView alloc] initWithFrame:CGRectMake(currentContentOffset + 27, (isWidescreen ? 101 : 56) + 33, screenSize.width - 27 * 2, 223)];
        backgroundView.image = backgroundImage;
        [_scrollView addSubview:backgroundView];
        
        UIImageView *logoView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"Tour.bundle/TourIcon4.png"]];
        logoView.frame = CGRectOffset(logoView.frame, currentContentOffset + floorf((screenSize.width - logoView.frame.size.width) / 2), backgroundView.frame.origin.y + 12);
        [_scrollView addSubview:logoView];
        
        UILabel *titleLabel = [[UILabel alloc] init];
        titleLabel.backgroundColor = [UIColor clearColor];
        titleLabel.textColor = [UIColor whiteColor];
        titleLabel.font = titleFont;
        titleLabel.text = TGLocalized(@"Tour.Title5");
        [titleLabel sizeToFit];
        titleLabel.frame = CGRectOffset(titleLabel.frame, currentContentOffset + floorf((screenSize.width - titleLabel.frame.size.width) / 2), logoView.frame.origin.y + logoView.frame.size.height + 7);
        [_scrollView addSubview:titleLabel];
        
        UILabel *subtitleLabel1 = [[UILabel alloc] init];
        subtitleLabel1.backgroundColor = [UIColor clearColor];
        subtitleLabel1.textAlignment = UITextAlignmentCenter;
        subtitleLabel1.textColor = [UIColor whiteColor];
        subtitleLabel1.numberOfLines = 0;
        subtitleLabel1.font = normalTextFont;
        
        NSString *baseSubtitleText1 = TGLocalized(@"Tour.Text5");
        
        if ([UILabel instancesRespondToSelector:@selector(setAttributedText:)])
        {
            NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:subtitleLabel1.font, NSFontAttributeName, subtitleLabel1.textColor, NSForegroundColorAttributeName, nil];
            
            NSDictionary *subAttrs = [NSDictionary dictionaryWithObjectsAndKeys:boldTextFont, NSFontAttributeName, nil];
            NSRange range = [baseSubtitleText1 rangeOfString:@"Telegram"];
            
            NSMutableAttributedString *attributedText = [[NSMutableAttributedString alloc] initWithString:baseSubtitleText1 attributes:attrs];
            
            [attributedText setAttributes:subAttrs range:range];
            
            NSMutableParagraphStyle *paragrahStyle = [[NSMutableParagraphStyle alloc] init];
            [paragrahStyle setLineSpacing:5];
            [paragrahStyle setAlignment:NSTextAlignmentCenter];
            [attributedText addAttribute:NSParagraphStyleAttributeName value:paragrahStyle range:NSMakeRange(0, [baseSubtitleText1 length])];
            
            [subtitleLabel1 setAttributedText:attributedText];
        }
        else
        {
            subtitleLabel1.text = baseSubtitleText1;
        }
        
        CGSize subtitleSize1 = [subtitleLabel1 sizeThatFits:CGSizeMake(230, 1000)];
        subtitleLabel1.frame = CGRectMake(currentContentOffset + floorf((screenSize.width - subtitleSize1.width) / 2), titleLabel.frame.origin.y + titleLabel.frame.size.height + 7, subtitleSize1.width, subtitleSize1.height);
        [_scrollView addSubview:subtitleLabel1];
    }
    
    currentContentOffset = screenSize.width * 5;
    {
        UIImageView *backgroundView = [[UIImageView alloc] initWithFrame:CGRectMake(currentContentOffset + 27, (isWidescreen ? 101 : 56) + 33, screenSize.width - 27 * 2, 223)];
        backgroundView.image = backgroundImage;
        [_scrollView addSubview:backgroundView];
        
        UIImageView *logoView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"Tour.bundle/TourIcon5.png"]];
        logoView.frame = CGRectOffset(logoView.frame, currentContentOffset + floorf((screenSize.width - logoView.frame.size.width) / 2), backgroundView.frame.origin.y + 12);
        [_scrollView addSubview:logoView];
        
        UILabel *titleLabel = [[UILabel alloc] init];
        titleLabel.backgroundColor = [UIColor clearColor];
        titleLabel.textColor = [UIColor whiteColor];
        titleLabel.font = titleFont;
        titleLabel.text = TGLocalized(@"Tour.Title6");
        [titleLabel sizeToFit];
        titleLabel.frame = CGRectOffset(titleLabel.frame, currentContentOffset + floorf((screenSize.width - titleLabel.frame.size.width) / 2), logoView.frame.origin.y + logoView.frame.size.height + 7);
        [_scrollView addSubview:titleLabel];
        
        UILabel *subtitleLabel1 = [[UILabel alloc] init];
        subtitleLabel1.backgroundColor = [UIColor clearColor];
        subtitleLabel1.textAlignment = UITextAlignmentCenter;
        subtitleLabel1.textColor = [UIColor whiteColor];
        subtitleLabel1.numberOfLines = 0;
        subtitleLabel1.font = normalTextFont;
        
        NSString *baseSubtitleText1 = TGLocalized(@"Tour.Text6");
        
        if ([UILabel instancesRespondToSelector:@selector(setAttributedText:)])
        {
            NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:subtitleLabel1.font, NSFontAttributeName, subtitleLabel1.textColor, NSForegroundColorAttributeName, nil];
            
            NSDictionary *subAttrs = [NSDictionary dictionaryWithObjectsAndKeys:boldTextFont, NSFontAttributeName, nil];
            NSRange range = [baseSubtitleText1 rangeOfString:@"Telegram"];
            
            NSMutableAttributedString *attributedText = [[NSMutableAttributedString alloc] initWithString:baseSubtitleText1 attributes:attrs];
            
            [attributedText setAttributes:subAttrs range:range];
            
            NSMutableParagraphStyle *paragrahStyle = [[NSMutableParagraphStyle alloc] init];
            [paragrahStyle setLineSpacing:5];
            [paragrahStyle setAlignment:NSTextAlignmentCenter];
            [attributedText addAttribute:NSParagraphStyleAttributeName value:paragrahStyle range:NSMakeRange(0, [baseSubtitleText1 length])];
            
            [subtitleLabel1 setAttributedText:attributedText];
        }
        else
        {
            subtitleLabel1.text = baseSubtitleText1;
        }
        
        CGSize subtitleSize1 = [subtitleLabel1 sizeThatFits:CGSizeMake(230, 1000)];
        subtitleLabel1.frame = CGRectMake(currentContentOffset + floorf((screenSize.width - subtitleSize1.width) / 2), titleLabel.frame.origin.y + titleLabel.frame.size.height + 7, subtitleSize1.width, subtitleSize1.height);
        [_scrollView addSubview:subtitleLabel1];
    }
    
    if (_maxPage >= 6)
    {
        currentContentOffset = screenSize.width * 6;
        {
            UIImageView *backgroundView = [[UIImageView alloc] initWithFrame:CGRectMake(currentContentOffset + 27, (isWidescreen ? 101 : 56) + 33, screenSize.width - 27 * 2, 223)];
            backgroundView.image = backgroundImage;
            [_scrollView addSubview:backgroundView];
            
            UIImageView *logoView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"Tour.bundle/TourIcon6.png"]];
            logoView.frame = CGRectOffset(logoView.frame, currentContentOffset + floorf((screenSize.width - logoView.frame.size.width) / 2), backgroundView.frame.origin.y + 12);
            [_scrollView addSubview:logoView];
            
            UILabel *titleLabel = [[UILabel alloc] init];
            titleLabel.backgroundColor = [UIColor clearColor];
            titleLabel.textColor = [UIColor whiteColor];
            titleLabel.font = titleFont;
            titleLabel.text = TGLocalized(@"Tour.Title7");
            [titleLabel sizeToFit];
            titleLabel.frame = CGRectOffset(titleLabel.frame, currentContentOffset + floorf((screenSize.width - titleLabel.frame.size.width) / 2), logoView.frame.origin.y + logoView.frame.size.height + 12);
            [_scrollView addSubview:titleLabel];
            
            UILabel *subtitleLabel1 = [[UILabel alloc] init];
            subtitleLabel1.backgroundColor = [UIColor clearColor];
            subtitleLabel1.textAlignment = UITextAlignmentCenter;
            subtitleLabel1.textColor = [UIColor whiteColor];
            subtitleLabel1.numberOfLines = 0;
            subtitleLabel1.font = normalTextFont;
            
            NSString *baseSubtitleText1 = TGLocalized(@"Tour.Text7");
            
            if ([UILabel instancesRespondToSelector:@selector(setAttributedText:)])
            {
                NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:subtitleLabel1.font, NSFontAttributeName, subtitleLabel1.textColor, NSForegroundColorAttributeName, nil];
                
                NSDictionary *subAttrs = [NSDictionary dictionaryWithObjectsAndKeys:boldTextFont, NSFontAttributeName, nil];
                NSRange range = [baseSubtitleText1 rangeOfString:@"Telegram"];
                
                NSMutableAttributedString *attributedText = [[NSMutableAttributedString alloc] initWithString:baseSubtitleText1 attributes:attrs];
                
                [attributedText setAttributes:subAttrs range:range];
                
                NSMutableParagraphStyle *paragrahStyle = [[NSMutableParagraphStyle alloc] init];
                [paragrahStyle setLineSpacing:5];
                [paragrahStyle setAlignment:NSTextAlignmentCenter];
                [attributedText addAttribute:NSParagraphStyleAttributeName value:paragrahStyle range:NSMakeRange(0, [baseSubtitleText1 length])];
                
                [subtitleLabel1 setAttributedText:attributedText];
            }
            else
            {
                subtitleLabel1.text = baseSubtitleText1;
            }
            
            CGSize subtitleSize1 = [subtitleLabel1 sizeThatFits:CGSizeMake(230, 1000)];
            subtitleLabel1.frame = CGRectMake(currentContentOffset + floorf((screenSize.width - subtitleSize1.width) / 2), titleLabel.frame.origin.y + titleLabel.frame.size.height + 7, subtitleSize1.width, subtitleSize1.height);
            [_scrollView addSubview:subtitleLabel1];
        }
    }
    
    UIImage *rawButtonImage = [UIImage imageNamed:[TGViewController isWidescreen] ? @"LoginGreenButton_Wide.png" : @"LoginGreenButton.png"];
    UIImage *rawButtonImageHighlighted = [UIImage imageNamed:[TGViewController isWidescreen] ? @"LoginGreenButton_Wide_Highlighted.png" : @"LoginGreenButton_Highlighted.png"];
    UIButton *nextButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 179, rawButtonImage.size.height)];
    nextButton.exclusiveTouch = true;
    [nextButton setBackgroundImage:[rawButtonImage stretchableImageWithLeftCapWidth:(int)(rawButtonImage.size.width / 2) topCapHeight:0] forState:UIControlStateNormal];
    [nextButton setBackgroundImage:[rawButtonImageHighlighted stretchableImageWithLeftCapWidth:(int)(rawButtonImageHighlighted.size.width / 2) topCapHeight:0] forState:UIControlStateHighlighted];
    nextButton.titleLabel.font = [UIFont boldSystemFontOfSize:TGIsRetina() ? 16.5f : 16.0f];
    [nextButton setTitle:TGLocalized(@"Tour.StartButton") forState:UIControlStateNormal];
    [nextButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [nextButton setTitleShadowColor:UIColorRGBA(0x1e6804, 0.4f) forState:UIControlStateNormal];
    [nextButton addTarget:self action:@selector(nextButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    nextButton.titleLabel.shadowOffset = CGSizeMake(0, -1);
    [self.view addSubview:nextButton];
    
    nextButton.frame = CGRectOffset(nextButton.frame, floorf((screenSize.width - nextButton.frame.size.width) / 2), screenSize.height - nextButton.frame.size.height - (isWidescreen ? 32 : 16));
    
    _pagerView = [[TGPagerView alloc] init];
    [_pagerView setDotImage:[UIImage imageNamed:@"Tour.bundle/TourDot.png"]];
    _pagerView.dotSpacing = 9;
    [_pagerView setPagesCount:_maxPage + 1];
    _pagerView.frame = CGRectMake(0, screenSize.height - (isWidescreen ? 110 : 88), screenSize.width, 20);
    [self.view addSubview:_pagerView];
    
    UIImage *topCornersImage = [UIImage imageNamed:@"NavigationBar_Corners.png"];
    UIView *cornersImageView = [[UIImageView alloc] initWithImage:[topCornersImage stretchableImageWithLeftCapWidth:(int)(topCornersImage.size.width / 2) topCapHeight:0]];
    cornersImageView.frame = CGRectMake(0, 0, 320, topCornersImage.size.height);
    cornersImageView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:cornersImageView];
    
    [self updateImages];
}

#ifdef INTERNAL_RELEASE
- (void)viewDoubleTapped:(UITapGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateRecognized)
    {
        [self.view removeGestureRecognizer:recognizer];
        
        UIImage *rawButtonImage = [UIImage imageNamed:[TGViewController isWidescreen] ? @"LoginGreenButton_Wide.png" : @"LoginGreenButton.png"];
        UIImage *rawButtonImageHighlighted = [UIImage imageNamed:[TGViewController isWidescreen] ? @"LoginGreenButton_Wide_Highlighted.png" : @"LoginGreenButton_Highlighted.png"];
        UIButton *nextButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 279, 50)];
        nextButton.exclusiveTouch = true;
        [nextButton setBackgroundImage:[rawButtonImage stretchableImageWithLeftCapWidth:(int)(rawButtonImage.size.width / 2) topCapHeight:0] forState:UIControlStateNormal];
        [nextButton setBackgroundImage:[rawButtonImageHighlighted stretchableImageWithLeftCapWidth:(int)(rawButtonImageHighlighted.size.width / 2) topCapHeight:0] forState:UIControlStateHighlighted];
        nextButton.titleLabel.font = [UIFont boldSystemFontOfSize:TGIsRetina() ? 16.5f : 16.0f];
        [nextButton setTitle:TGAppDelegateInstance.useDifferentBackend ? @"Switch to debug DC" : @"Switch to production DC" forState:UIControlStateNormal];
        [nextButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [nextButton setTitleShadowColor:[TGViewController isWidescreen] ? UIColorRGBA(0x1e6804, 0.5f) : UIColorRGB(0x3d7913) forState:UIControlStateNormal];
        [nextButton addTarget:self action:@selector(switchButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        nextButton.titleLabel.shadowOffset = CGSizeMake(0, -1);
        [self.view addSubview:nextButton];
        
        nextButton.frame = CGRectOffset(nextButton.frame, floorf((self.view.frame.size.width - nextButton.frame.size.width) / 2), self.view.frame.size.height - 70);
        
        nextButton.alpha = 0.0f;
        
        [UIView animateWithDuration:0.3 animations:^
        {
            nextButton.alpha = 1.0f;
        }];
    }
}

- (void)switchButtonPressed
{
    [[TGSession instance] switchBackends];
}
#endif

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
}

- (BOOL)shouldAutorotate
{
    return true;
}

- (bool)shouldBeRemovedFromNavigationAfterHiding
{
    return false;
}

- (void)viewWillAppear:(BOOL)animated
{
    if (animated)
    {
        [UIView animateWithDuration:0.2 animations:^
        {
            if (_firstAppear)
                self.navigationController.navigationBar.alpha = 0.0f;
            [TGHacks setApplicationStatusBarAlpha:0.0f];
        }];
        
        if (!_firstAppear)
            self.navigationController.navigationBar.alpha = 0.0f;
    }
    else
    {
        self.navigationController.navigationBar.alpha = 0.0f;
        [TGHacks setApplicationStatusBarAlpha:0.0f];
    }
    
    _firstAppear = true;
    
    [super viewWillAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    if (animated)
    {
        [UIView animateWithDuration:0.35 animations:^
        {
            self.navigationController.navigationBar.alpha = 1.0f;
            
            [TGHacks setApplicationStatusBarAlpha:1.0f];
        } completion:nil];
    }
    else
    {
        self.navigationController.navigationBar.alpha = 1.0f;
        
        [TGHacks setApplicationStatusBarAlpha:1.0f];
    }
    
    [super viewWillDisappear:animated];
}

#pragma mark -

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (scrollView == _scrollView)
    {
        [self updateImages];
    }
}

#pragma mark -

- (void)learnMoreButtonPressed
{
    [_scrollView setContentOffset:CGPointMake(_scrollView.frame.size.width, 0) animated:true];
}

- (void)nextButtonPressed
{
    TGLoginPhoneController *phoneController = [[TGLoginPhoneController alloc] init];
    [self.navigationController pushViewController:phoneController animated:true];
}

- (void)updateImages
{
    int lastIndex = _maxPage;
    
    float contentOffsetX = MAX(-_scrollView.frame.size.width / 2, MIN(_scrollView.contentOffset.x, _scrollView.contentSize.width - _scrollView.frame.size.width / 2 - 1));
    
    CGSize frameSize = _scrollView.frame.size;
    int currentTopImage = (int)((contentOffsetX + frameSize.width / 2) / frameSize.width);
    currentTopImage = MAX(0, MIN(currentTopImage, lastIndex));
    
    int currentBottomImage = ((int)(contentOffsetX + frameSize.width / 2)) % ((int)frameSize.width) < frameSize.width / 2 ? currentTopImage - 1 : currentTopImage + 1;
    currentBottomImage = MAX(0, MIN(currentBottomImage, lastIndex));
    
    if (currentTopImage != _currentTopImage)
    {
        _currentTopImage = currentTopImage;
        _topImageView.image = [_images objectAtIndex:_currentTopImage];
    }
    
    if (currentBottomImage != _currentBottomImage)
    {
        _currentBottomImage = currentBottomImage;
        _bottomImageView.image = [_images objectAtIndex:_currentBottomImage];
    }
    
    float distance = fmodf(contentOffsetX + frameSize.width / 2, frameSize.width);
    
    if (distance > frameSize.width / 2)
        distance = frameSize.width - distance;
    distance += frameSize.width / 2;
    
    distance = MAX(-frameSize.width, MIN(frameSize.width, distance));
    
    float alpha = distance / (frameSize.width);
    alpha = MAX(0.0f, MIN(1.0f, alpha));
    
    if (_currentTopImage != _currentBottomImage)
        _topImageView.alpha = MAX(0.0f, MIN(1.0f, alpha));
    else
    {
        _topImageView.alpha = 1.0f;
        if (_currentBottomImage == lastIndex)
            alpha = -alpha + 2.0f;
    }
    
    [_pagerView setPage:MAX(0, MIN((contentOffsetX / frameSize.width), lastIndex))];
    
    CGRect topImageFrame = _topImageView.frame;
    topImageFrame.origin.x = -20 + (1.0f - alpha) * 20 * (_currentTopImage < _currentBottomImage ? -1 : 1);
    _topImageView.frame = topImageFrame;
    
    CGRect bottomImageFrame = _bottomImageView.frame;
    bottomImageFrame.origin.x = -20 + alpha * 20 * (_currentTopImage < _currentBottomImage ? 1 : -1);
    _bottomImageView.frame = bottomImageFrame;
    
    //TGLog(@"distance = %f, front = %d, back = %d", distance, _currentTopImage, _currentBottomImage);
}

@end
