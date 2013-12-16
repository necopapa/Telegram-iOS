#import "TGSearchBar.h"

#import "TGHacks.h"

@interface TGSearchBar ()

@property (nonatomic, strong) UIButton *searchCancelButton;
@property (nonatomic) bool searchShowsCancelButton;

@end

@implementation TGSearchBar

- (void)didAddSubview:(UIView *)subview
{
    if ([subview isKindOfClass:[UISegmentedControl class]])
    {
        [(UISegmentedControl *)subview setContentPositionAdjustment:UIOffsetMake(0.0f, 1.0f) forSegmentType:UISegmentedControlSegmentAny barMetrics:UIBarMetricsDefault];
    }
    
    [super didAddSubview:subview];
}

- (UIButton *)searchCancelButton
{
    if (_searchCancelButton == nil)
    {
        UIImage *rawImage = [UIImage imageNamed:_useDarkStyle ? @"SearchDarkCancelButton.png" : @"SearchCancelButton.png"];
        UIImage *rawHighlightedImage = [UIImage imageNamed:_useDarkStyle ? @"SearchDarkCancelButton_Pressed.png" : @"SearchCancelButton_Pressed.png"];
        
        _searchCancelButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 7, 59, 30)];
        [_searchCancelButton setBackgroundImage:[rawImage stretchableImageWithLeftCapWidth:(int)(rawImage.size.width / 2) topCapHeight:0] forState:UIControlStateNormal];
        [_searchCancelButton setBackgroundImage:[rawHighlightedImage stretchableImageWithLeftCapWidth:(int)(rawHighlightedImage.size.width / 2) topCapHeight:0] forState:UIControlStateHighlighted];
        
        [_searchCancelButton setTitle:TGLocalized(@"Common.Cancel") forState:UIControlStateNormal];
        
        [_searchCancelButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [_searchCancelButton setTitleShadowColor:UIColorRGBA(0x112e5c, 0.2f) forState:UIControlStateNormal];
        
        _searchCancelButton.titleLabel.shadowOffset = CGSizeMake(0, -1);
        _searchCancelButton.titleLabel.font = [UIFont boldSystemFontOfSize:12];
        
        _searchCancelButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        
        [_searchCancelButton addTarget:self action:@selector(searchCancelButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    }
    
    return _searchCancelButton;
}

- (BOOL)showsCancelButton
{
    return _searchShowsCancelButton;
}

- (void)setShowsCancelButton:(BOOL)showsCancelButton
{
    [self setShowsCancelButton:showsCancelButton animated:false];
}

- (void)setShowsCancelButton:(BOOL)showsCancelButton animated:(BOOL)animated
{
    if (_searchShowsCancelButton != showsCancelButton)
    {
        _searchShowsCancelButton = showsCancelButton;
        
        [self addSubview:[self searchCancelButton]];
        
        if (showsCancelButton)
        {
            CGRect buttonFrame = _searchCancelButton.frame;
            buttonFrame.origin.x = self.frame.size.width - 6 - buttonFrame.size.width + 75;
            _searchCancelButton.frame = buttonFrame;
        }
        
        UIEdgeInsets contentInset = [self searchContentInset];
        if (showsCancelButton)
            contentInset.right = 75;
        else
            contentInset.right = 5;
        
        if (animated)
        {
            [UIView animateWithDuration:0.2 animations:^
            {
                [self setSearchContentInset:contentInset];
                [self layoutSubviews];
                
                CGRect buttonFrame = _searchCancelButton.frame;
                if (showsCancelButton)
                    buttonFrame.origin.x = self.frame.size.width - 6 - buttonFrame.size.width;
                else
                    buttonFrame.origin.x = buttonFrame.origin.x = self.frame.size.width - 6 - buttonFrame.size.width + 75;
                _searchCancelButton.frame = buttonFrame;
            } completion:^(BOOL finished)
            {
                if (finished)
                {
                    if (!showsCancelButton)
                        [_searchCancelButton removeFromSuperview];
                }
            }];
        }
        else
        {
            [self setSearchContentInset:contentInset];
            [self layoutSubviews];
            
            CGRect buttonFrame = _searchCancelButton.frame;
            if (showsCancelButton)
                buttonFrame.origin.x = self.frame.size.width - 6 - buttonFrame.size.width;
            else
                buttonFrame.origin.x = buttonFrame.origin.x = self.frame.size.width - 6 - buttonFrame.size.width + 75;
            _searchCancelButton.frame = buttonFrame;
            
            if (!showsCancelButton)
                [_searchCancelButton removeFromSuperview];
        }
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    //[self setSearchBarShouldShowScopeControl:_searchBarShouldShowScopeControl];
}

- (void)setSearchBarShouldShowScopeControl:(bool)searchBarShouldShowScopeControl
{
    _searchBarShouldShowScopeControl = searchBarShouldShowScopeControl;
    
    float requiredHeight = 0;
    
    if (_searchBarShouldShowScopeControl && self.frame.size.width < 400)
    {
        requiredHeight = 88;
    }
    else
    {
        requiredHeight = 44;
    }
    
    if (ABS(requiredHeight - self.frame.size.height) > FLT_EPSILON)
    {
        UIEdgeInsets inset = [self searchContentInset];
        inset.bottom = requiredHeight - 44;
        [self setSearchContentInset:inset];
        
        id<TGSearchBarDelegate> delegate = (id<TGSearchBarDelegate>)self.delegate;
        if ([delegate respondsToSelector:@selector(searchBar:willChangeHeight:)])
            [delegate searchBar:self willChangeHeight:requiredHeight];
    }
}

#pragma mark -

- (void)searchCancelButtonPressed
{
    id delegate = self.delegate;
    
    if ([delegate respondsToSelector:@selector(searchBarCancelButtonClicked:)])
        [delegate searchBarCancelButtonClicked:self];
}

- (UIEdgeInsets)searchContentInset
{
    return [(UIScrollView *)self contentInset];
}

- (void)setSearchContentInset:(UIEdgeInsets)searchContentInset
{
    [(UIScrollView *)self setContentInset:searchContentInset];
}

- (void)setSearchPlaceholderColor:(UIColor *)color
{
    [self _setSearchPlaceholderColor:color view:self];
}

- (void)_setSearchPlaceholderColor:(UIColor *)color view:(UIView *)view
{
    if ([view isKindOfClass:[UITextField class]])
    {
        [TGHacks setTextFieldPlaceholderColor:(UITextField *)view color:color];
    }
    else
    {
        for (UIView *subview in view.subviews)
            [self _setSearchPlaceholderColor:color view:subview];
    }
}

- (void)setSearchBarCombinesBars:(BOOL)searchBarCombinesBars
{
    SEL selector = NSSelectorFromString(TGEncodeText(@"tfuDpncjoftMboetdbqfCbst;", -1));
    
    NSMethodSignature *signature = [[self class] instanceMethodSignatureForSelector:selector];
    if (signature == nil)
    {
        TGLog(@"***** Method not found");
    }
    else
    {
        NSInvocation *inv = [NSInvocation invocationWithMethodSignature:signature];
        [inv setSelector:selector];
        [inv setTarget:self];
        [inv setArgument:&searchBarCombinesBars atIndex:2];
        [inv invoke];
    }
}

@end
