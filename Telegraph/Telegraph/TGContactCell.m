#import "TGContactCell.h"

#import "TGHighlightTriggerLabel.h"
#import "TGLabel.h"
#import "TGRemoteImageView.h"
#import "TGDateLabel.h"

#import "TGImageUtils.h"

#import "TGInterfaceAssets.h"

#import "TGActionTableView.h"

#import "TGContactCellContents.h"

#import <QuartzCore/QuartzCore.h>

#define TG_DELETE_BUTTON_EDGE_OFFSET 6

static UIImage *contactCellBackgroundImage()
{
    static UIImage *image = nil;
    if (image == nil)
        image = [UIImage imageNamed:@"ContactListCell.png"];
    return image;
}

static UIImage *contactCellCheckImage()
{
    static UIImage *image = nil;
    if (image == nil)
        image = [UIImage imageNamed:@"Contact_Check.png"];
    return image;
}

static UIImage *contactCellCheckedImage()
{
    static UIImage *image = nil;
    if (image == nil)
        image = [UIImage imageNamed:@"Contact_Checked.png"];
    return image;
}

static UIImage *addButtonImage()
{
    static UIImage *image = nil;
    if (image == nil)
    {
        UIImage *rawImage = [UIImage imageNamed:@"AddButton.png"];
        image = [rawImage stretchableImageWithLeftCapWidth:(int)((rawImage.size.width) / 2) topCapHeight:(int)((rawImage.size.height) / 2)];
    }
    return image;
}

static UIImage *addButtonHighlightedImage()
{
    static UIImage *image = nil;
    if (image == nil)
    {
        UIImage *rawImage = [UIImage imageNamed:@"AddButton_Pressed.png"];
        image = [rawImage stretchableImageWithLeftCapWidth:(int)((rawImage.size.width) / 2) topCapHeight:(int)((rawImage.size.height) / 2)];
    }
    return image;
}

static UIImage *messageBadgeImage()
{
    static UIImage *image = nil;
    if (image == nil)
    {
        UIImage *rawImage = [UIImage imageNamed:@"DialogListUnreadBadge.png"];
        image = [rawImage stretchableImageWithLeftCapWidth:(int)((rawImage.size.width) / 2) topCapHeight:(int)((rawImage.size.height) / 2)];
    }
    return image;
}

static UIImage *messageBadgeImageHighlighted()
{
    static UIImage *image = nil;
    if (image == nil)
    {
        UIImage *rawImage = [UIImage imageNamed:@"DialogListUnreadBadge_Highlighted.png"];
        image = [rawImage stretchableImageWithLeftCapWidth:(int)((rawImage.size.width) / 2) topCapHeight:(int)((rawImage.size.height) / 2)];
    }
    return image;
}

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

@interface TGContactCheckButton : UIButton

@property (nonatomic, strong) UIImageView *checkView;

- (void)setChecked:(bool)checked animated:(bool)animated;

@end

@implementation TGContactCheckButton

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        [self _commonInit];
    }
    return self;
}

- (id)init
{
    self = [super initWithFrame:CGRectMake(0, 0, 29, 29)];
    if (self != nil)
    {
        [self _commonInit];
    }
    return self;
}

- (void)_commonInit
{
    self.exclusiveTouch = true;
    
    _checkView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 29, 29)];
    [self addSubview:_checkView];
    
    _checkView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
}

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];
    
    if (highlighted)
        _checkView.transform = CGAffineTransformMakeScale(0.8f, 0.8f);
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    _checkView.transform = CGAffineTransformIdentity;
    
    [super touchesCancelled:touches withEvent:event];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    
    if (!CGRectContainsPoint(self.bounds, [touch locationInView:self]))
    {
        _checkView.transform = CGAffineTransformIdentity;
    }
    else
    {
        _checkView.transform = CGAffineTransformMakeScale(0.8f, 0.8f);
    }
    
    [super touchesEnded:touches withEvent:event];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    
    if (!CGRectContainsPoint(self.bounds, [touch locationInView:self]))
    {
        _checkView.transform = CGAffineTransformIdentity;
    }
    else
    {
        _checkView.transform = CGAffineTransformMakeScale(0.8f, 0.8f);
    }
    
    [super touchesMoved:touches withEvent:event];
}

- (void)setChecked:(bool)checked animated:(bool)animated
{
    _checkView.image = checked ? contactCellCheckedImage() : contactCellCheckImage();
    
    if (animated)
    {
        _checkView.transform = CGAffineTransformMakeScale(0.8f, 0.8f);
        if (checked)
        {
            [UIView animateWithDuration:0.12 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^
            {
                _checkView.transform = CGAffineTransformMakeScale(1.16, 1.16f);
            } completion:^(BOOL finished)
            {
                if (finished)
                {
                    [UIView animateWithDuration:0.08 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^
                    {
                        _checkView.transform = CGAffineTransformIdentity;
                    } completion:nil];
                }
            }];
        }
        else
        {
            [UIView animateWithDuration:0.16 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^
            {
                _checkView.transform = CGAffineTransformIdentity;
            } completion:nil];
        }
    }
    else
    {
        _checkView.transform = CGAffineTransformIdentity;
    }
}

@end

@interface TGContactCell () <TGActionTableViewCell>

@property (nonatomic, strong) TGHighlightTriggerLabel *highlightProxy;

@property (nonatomic) UIButton *editingButton;
@property (nonatomic, strong) TGRemoteImageView *avatarView;
@property (nonatomic, strong) TGDateLabel *subtitleLabel;

@property (nonatomic, strong) TGContactCheckButton *checkButton;

@property (nonatomic, strong) UIButton *switchButton;
@property (nonatomic, strong) UIImageView *editingButtonLabel;
@property (nonatomic, strong) UIImageView *switchButtonMinus;
@property (nonatomic) bool editingIsActive;

@property (nonatomic) bool editingEnabled;

@property (nonatomic, strong) UIView *highlightedBackgroundView;

@property (nonatomic, strong) UITapGestureRecognizer *tapRecognizer;

@property (nonatomic, strong) TGContactCellContents *contactContentsView;

@end

@implementation TGContactCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    return [self initWithStyle:style reuseIdentifier:reuseIdentifier selectionControls:false editingControls:false];
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier selectionControls:(bool)selectionControls editingControls:(bool)editingControls
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self)
    {
        float retinaPixel = TGIsRetina() ? 0.5f : 0.0f;
        
        _editingEnabled = editingControls;
        
        static UIImage *cellImage = nil;
        if (cellImage == nil)
            cellImage = [UIImage imageNamed:@"Cell102.png"];
        
        static UIImage *selectedCellImage = nil;
        if (selectedCellImage == nil)
            selectedCellImage = [UIImage imageNamed:@"CellHighlighted102.png"];
        
        self.backgroundView = [[UIImageView alloc] initWithImage:cellImage];
        self.selectedBackgroundView = [[UIImageView alloc] initWithImage:selectedCellImage];
        
        if (editingControls)
        {
            self.selectedBackgroundView.layer.zPosition = 1.0f;
            self.contentView.layer.zPosition = 2.0f;
        }
        
        if (selectionControls)
        {
            UIView *tapAreaView = [[UIView alloc] initWithFrame:self.contentView.bounds];
            tapAreaView.userInteractionEnabled = true;
            tapAreaView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [self.contentView addSubview:tapAreaView];
            
            _tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(viewTapped:)];
            _tapRecognizer.cancelsTouchesInView = false;
            [tapAreaView addGestureRecognizer:_tapRecognizer];
        }
        
        _avatarView = [[TGRemoteImageView alloc] initWithFrame:CGRectMake(5, 5, 40, 40)];
        _avatarView.fadeTransition = true;
        [self.contentView addSubview:_avatarView];
        
        _contactContentsView = [[TGContactCellContents alloc] initWithFrame:self.contentView.bounds];
        _contactContentsView.userInteractionEnabled = false;
        _contactContentsView.titleFont = [UIFont systemFontOfSize:19];
        _contactContentsView.titleBoldFont = [UIFont boldSystemFontOfSize:19];
        _contactContentsView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.contentView addSubview:_contactContentsView];
        
        _boldMode = 2;
        
        _subtitleLabel = [[TGDateLabel alloc] initWithFrame:CGRectZero];
        _subtitleLabel.contentMode = UIViewContentModeLeft;
        _subtitleLabel.dateFont = [UIFont systemFontOfSize:13 + retinaPixel];
        _subtitleLabel.dateTextFont = _subtitleLabel.dateFont;
        _subtitleLabel.dateLabelFont = [UIFont systemFontOfSize:11];
        _subtitleLabel.amWidth = 19;
        _subtitleLabel.pmWidth = 19;
        _subtitleLabel.dstOffset = 3;
        _subtitleLabel.textColor = UIColorRGB(0x888888);
        _subtitleLabel.highlightedTextColor = UIColorRGB(0xffffff);
        _subtitleLabel.backgroundColor = [UIColor clearColor];
        
        _contactContentsView.dateLabel = _subtitleLabel;
        
        if (selectionControls)
        {
            _checkButton = [[TGContactCheckButton alloc] init];
            _checkButton.userInteractionEnabled = true;
            [_checkButton addTarget:self action:@selector(checkButtonPressed) forControlEvents:UIControlEventTouchUpInside];
            [self.contentView addSubview:_checkButton];
        }
        
        if (editingControls)
        {
            UISwipeGestureRecognizer *swipeRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeGestureRecognized:)];
            swipeRecognizer.direction = UISwipeGestureRecognizerDirectionLeft | UISwipeGestureRecognizerDirectionRight;
            [self addGestureRecognizer:swipeRecognizer];
            
            static UIImage *switchButtonImage = nil;
            static UIImage *deleteTextImage = nil;
            
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^
            {
                switchButtonImage = [UIImage imageNamed:@"ListEditingSwitch.png"];
                
                UIFont *font = [UIFont boldSystemFontOfSize:13];
                CGSize size = [TGLocalizedStatic(@"Common.ListDelete") sizeWithFont:font];
                size.width = (int)size.width + 2;
                UIGraphicsBeginImageContextWithOptions(size, false, 0.0f);
                
                CGContextRef context = UIGraphicsGetCurrentContext();
                CGContextSetShadowWithColor(context, CGSizeMake(0, -1), 0.0f, UIColorRGBA(0xa30f0a, 0.2f).CGColor);
                CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
                
                [@"Delete" drawInRect:CGRectMake(1, 0, size.width, size.height) withFont:font];
                
                deleteTextImage = UIGraphicsGetImageFromCurrentImageContext();
                UIGraphicsEndImageContext();
            });
            
            _switchButton = [[UIButton alloc] initWithFrame:CGRectMake(-30 - 5, 10, 30, 30)];
            _switchButton.layer.zPosition = 4.0f;
            _switchButton.exclusiveTouch = true;
            _switchButton.hidden = true;
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
            
            _editingButton.frame = CGRectMake(self.frame.size.width - TG_DELETE_BUTTON_EDGE_OFFSET - 61, 10, 61, 31);
            _editingButton.hidden = true;
            _editingButton.clipsToBounds = true;
            _editingButton.alpha = 0.0f;
            
            UIImageView *deleteTextView = [[UIImageView alloc] initWithImage:deleteTextImage];
            deleteTextView.frame = CGRectOffset(deleteTextView.frame, floorf((_editingButton.frame.size.width - deleteTextView.frame.size.width) / 2), 7);
            deleteTextView.contentMode = UIViewContentModeLeft;
            deleteTextView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
            _editingButtonLabel = deleteTextView;
            [_editingButton addSubview:deleteTextView];
            
            _editingButton.frame = CGRectMake(self.frame.size.width - 4 - 2, _editingButton.frame.origin.y, 2, _editingButton.frame.size.height);
            
            _editingButton.layer.zPosition = 5.0f;
            [self addSubview:_editingButton];
        }
        
        _highlightProxy = [[TGHighlightTriggerLabel alloc] initWithFrame:CGRectZero];
        [self addSubview:_highlightProxy];
        [_highlightProxy setTargetViews:[[NSArray alloc] initWithObjects:_contactContentsView, nil]];
    }
    return self;
}

- (void)viewTapped:(UITapGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateEnded)
    {
        [self checkButtonPressed];
    }
}

- (void)checkButtonPressed
{
    [_actionHandle requestAction:@"/contactlist/toggleItem" options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:_itemId], @"itemId", [NSNumber numberWithBool:_contactSelected], @"selected", self, @"cell", nil]];
}

- (void)actionButtonPressed
{
    [_actionHandle requestAction:@"contactCellAction" options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:_itemId], @"itemId", nil]];
}

- (void)setBoldMode:(int)index
{
    if (_boldMode != index)
    {
        _boldMode = index;
        
        /*if (index & 1)
            _titleLabelFirst.font = [UIFont boldSystemFontOfSize:_titleLabelFirst.font.pointSize];
        else
            _titleLabelFirst.font = [UIFont systemFontOfSize:_titleLabelFirst.font.pointSize];
        
        if (index & 2)
            _titleLabelSecond.font = [UIFont boldSystemFontOfSize:_titleLabelFirst.font.pointSize];
        else
            _titleLabelSecond.font = [UIFont systemFontOfSize:_titleLabelFirst.font.pointSize];*/
    }
}

- (void)setIsDisabled:(bool)isDisabled
{
    if (_isDisabled != isDisabled)
    {
        _isDisabled = isDisabled;
        
        _subtitleLabel.isDisabled = isDisabled;
        
        [self setSelectionStyle:isDisabled ? UITableViewCellSelectionStyleNone : UITableViewCellSelectionStyleBlue];
        _contactContentsView.isDisabled = isDisabled;
        [_contactContentsView setNeedsDisplay];
    }
}

- (void)resetView:(bool)animateState
{
    if (_titleTextSecond == nil || _titleTextSecond.length == 0)
    {
        _contactContentsView.titleBoldMode = 1;
        _contactContentsView.titleFirst = _titleTextFirst;
        _contactContentsView.titleSecond = nil;
    }
    else
    {
        _contactContentsView.titleBoldMode = _boldMode;
        _contactContentsView.titleFirst = _titleTextFirst;
        _contactContentsView.titleSecond = _titleTextSecond;
    }
    _subtitleLabel.dateText = _subtitleText;
    [_subtitleLabel measureTextSize];
    
    _subtitleLabel.hidden = _subtitleText == nil || _subtitleText.length == 0;
    
    if (_hideAvatar)
    {
        _avatarView.hidden = true;
    }
    else
    {
        _avatarView.hidden = false;
        
        if (_avatarUrl != nil)
        {
            _avatarView.fadeTransitionDuration = animateState ? 0.14 : 0.3;
            if (![_avatarUrl isEqualToString:_avatarView.currentUrl])
            {
                if (animateState)
                {
                    UIImage *currentImage = [_avatarView currentImage];
                    [_avatarView loadImage:_avatarUrl filter:@"avatar40" placeholder:(currentImage != nil ? currentImage : [[TGInterfaceAssets instance] smallAvatarPlaceholderGeneric]) forceFade:true];
                }
                else
                    [_avatarView loadImage:_avatarUrl filter:@"avatar40" placeholder:[[TGInterfaceAssets instance] smallAvatarPlaceholderGeneric]];
            }
        }
        else
        {
            [_avatarView loadImage:[[TGInterfaceAssets instance] smallAvatarPlaceholder:_itemId]];
        }
    }
    
    if (_checkButton != nil)
        [self updateFlags:_contactSelected];
    
    if (!_subtitleLabel.hidden)
    {
        static UIColor *normalColor = nil;
        static UIColor *activeColor = nil;
        if (normalColor == nil)
        {
            normalColor = UIColorRGBA(0, 0.53f);
            activeColor = UIColorRGB(0x0779d0);
        }
        _subtitleLabel.textColor = _subtitleActive ? activeColor : normalColor;
        [_contactContentsView setNeedsDisplay];
    }
    
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
    
    [self setNeedsLayout];
    [_contactContentsView setNeedsDisplay];
}

- (void)updateFlags:(bool)contactSelected
{
    [self updateFlags:contactSelected force:false];
}

- (void)updateFlags:(bool)contactSelected force:(bool)force
{
    [self updateFlags:contactSelected animated:true force:force];
}

- (void)updateFlags:(bool)contactSelected animated:(bool)animated force:(bool)force
{
    if (_contactSelected != contactSelected || force)
    {
        _contactSelected = contactSelected;
        [_checkButton setChecked:_contactSelected animated:animated];
    }
}

- (void)setSelectionEnabled:(bool)selectionEnabled animated:(bool)animated
{
    if (_selectionEnabled != selectionEnabled)
    {
        _selectionEnabled = selectionEnabled;
        
        if (_selectionEnabled)
        {
            _checkButton.hidden = false;
            
            [_checkButton setChecked:_contactSelected animated:false];
            
            if (animated)
            {
                [UIView animateWithDuration:0.3 animations:^
                {
                    _checkButton.alpha = 1.0f;
                    [self layoutSubviews];
                }];
            }
            else
            {
                _checkButton.alpha = 1.0f;
                [self layoutSubviews];
            }
        }
        else if (_checkButton != nil)
        {
            if (animated)
            {
                [UIView animateWithDuration:0.3 animations:^
                {
                    _checkButton.alpha = 0.0f;
                    [self layoutSubviews];
                } completion:^(BOOL finished)
                {
                    if (finished)
                    {
                        _checkButton.hidden = true;
                    }
                }];
            }
            else
            {
                _checkButton.alpha = 0.0f;
                _checkButton.hidden = true;
                [self layoutSubviews];
            }
        }
        
        if (animated)
            [self layoutSubviews];
        else
            [self setNeedsLayout];
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    float retinaPixel = TGIsRetina() ? 0.5f : 0.0f;
    
    CGRect frame = self.selectedBackgroundView.frame;
    frame.origin.y = true ? -1 : 0;
    frame.size.height = self.frame.size.height + 1;
    self.selectedBackgroundView.frame = frame;
    
    CGSize viewSize = self.contentView.frame.size;
    
    int leftPadding = _selectionEnabled ? (_hideAvatar ? 34 : 40) : 0;
    if (self.editing)
        leftPadding += 2;
    
    int avatarWidth = _hideAvatar ? 0 : (5 + 40);
    
    CGSize titleSizeGeneric = CGSizeMake(viewSize.width - avatarWidth - 9 - 5 - leftPadding, _contactContentsView.titleFont.lineHeight);
    
    CGSize subtitleSize = CGSizeMake(viewSize.width - avatarWidth - 9 - 5 - leftPadding, _subtitleLabel.font.lineHeight);
    
    CGRect avatarFrame = CGRectMake(leftPadding + 5, 5, 40, 40);
    if (!CGRectEqualToRect(_avatarView.frame, avatarFrame))
    {
        _avatarView.frame = avatarFrame;
    }
    
    if (_checkButton != nil)
    {
        _checkButton.frame = CGRectMake(_selectionEnabled ? 7 : -7 - _checkButton.frame.size.width, 10, 29, 29);
    }
    
    int titleLabelsY = 0;
    
    if (_subtitleLabel.hidden)
    {
        titleLabelsY = (int)((int)((viewSize.height - titleSizeGeneric.height) / 2) - (_hideAvatar ? 0 : 1));
    }
    else
    {
        titleLabelsY = (int)((viewSize.height - titleSizeGeneric.height - subtitleSize.height - 1) / 2);
        
        [_subtitleLabel measureTextSize];
        _subtitleLabel.frame = CGRectMake(avatarWidth + 9 + leftPadding + 1, titleLabelsY + titleSizeGeneric.height + retinaPixel, subtitleSize.width, subtitleSize.height);
    }
    
    /*if (!_titleLabelFirst.hidden)
    {
        _titleLabelFirst.frame = CGRectMake(avatarWidth + 9 + leftPadding, titleLabelsY, titleSizeGeneric.width, titleSizeGeneric.height);
        _titleLabelSecond.frame = CGRectMake(avatarWidth + 9 + leftPadding, titleLabelsY, titleSizeGeneric.width, titleSizeGeneric.height);
        
        _titleLabelSecond.customDrawingOffset = CGPointMake(5 + [_titleLabelFirst.text sizeWithFont:_titleLabelFirst.font].width, 0);
        _titleLabelSecond.customDrawingSize = CGSizeMake(titleSizeGeneric.width - _titleLabelSecond.customDrawingOffset.x, titleSizeGeneric.height);
    }
    else
    {
        _titleLabelSecond.frame = CGRectMake(avatarWidth + 9 + leftPadding, titleLabelsY, titleSizeGeneric.width, titleSizeGeneric.height);
        _titleLabelSecond.customDrawingOffset = CGPointZero;
        _titleLabelSecond.customDrawingSize = CGSizeZero;
    }*/
    
    _contactContentsView.titleOffset = CGPointMake(avatarWidth + 9 + leftPadding, titleLabelsY);
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    bool wasSelected = self.selected;
    [super setSelected:selected animated:animated];
    
    if (selected || wasSelected)
    {
        CGRect frame = self.selectedBackgroundView.frame;
        frame.origin.y = true ? -1 : 0;
        frame.size.height = self.frame.size.height + 1;
        self.selectedBackgroundView.frame = frame;
        
        [self adjustOrdering];
    }
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
    bool wasHighlighted = self.highlighted;
    [super setHighlighted:highlighted animated:animated];
    
    if (highlighted || wasHighlighted)
    {
        CGRect frame = self.selectedBackgroundView.frame;
        frame.origin.y = true ? -1 : 0;
        frame.size.height = self.frame.size.height + 1;
        self.selectedBackgroundView.frame = frame;
        
        [self adjustOrdering];
    }
    
    if (_selectionEnabled)
    {
        if (highlighted)
        {
            if (_highlightedBackgroundView == nil)
            {
                _highlightedBackgroundView = [[UIView alloc] initWithFrame:CGRectMake(0, -1, self.frame.size.width, self.contentView.frame.size.height + 1)];
                _highlightedBackgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                _highlightedBackgroundView.backgroundColor = UIColorRGB(0xe9eff5);
                
                UIView *topStripe = [[UIView alloc] initWithFrame:CGRectMake(0, 0, _highlightedBackgroundView.frame.size.width, 1)];
                topStripe.backgroundColor = UIColorRGB(0xd5dee5);
                [_highlightedBackgroundView addSubview:topStripe];
                
                UIView *bottomStripe = [[UIView alloc] initWithFrame:CGRectMake(0, _highlightedBackgroundView.frame.size.height - 1, _highlightedBackgroundView.frame.size.width, 1)];
                bottomStripe.backgroundColor = UIColorRGB(0xd5dee5);
                [_highlightedBackgroundView addSubview:bottomStripe];
                
                [self.contentView insertSubview:_highlightedBackgroundView atIndex:0];
            }
            
            /*if (_highlightedBackgroundView.hidden)
            {
                _subtitleLabel.textColor = UIColorRGB(0x778698);
                [_subtitleLabel setNeedsDisplay];
            }*/
            
            _highlightedBackgroundView.hidden = false;
        }
        else
        {
            if (_highlightedBackgroundView != nil)
            {
                /*if (!_highlightedBackgroundView.hidden)
                {
                    _subtitleLabel.textColor = UIColorRGB(0x888888);
                    [_subtitleLabel setNeedsDisplay];
                }*/
                
                _highlightedBackgroundView.hidden = true;
            }
        }
    }
}

- (void)adjustOrdering
{
    if ([self.superview isKindOfClass:[UITableView class]])
    {
        Class UITableViewCellClass = [UITableViewCell class];
        Class UISearchBarClass = [UISearchBar class];
        int maxCellIndex = 0;
        int index = -1;
        int selfIndex = 0;
        for (UIView *view in self.superview.subviews)
        {
            index++;
            if ([view isKindOfClass:UITableViewCellClass] || [view isKindOfClass:UISearchBarClass])
            {
                maxCellIndex = index;
                
                if (view == self)
                    selfIndex = index;
            }
        }
        
        if (selfIndex < maxCellIndex)
        {
            [self.superview insertSubview:self atIndex:maxCellIndex];
        }
    }
}

#pragma mark -

- (void)setEditing:(BOOL)editing animated:(BOOL)animated
{
    [super setEditing:editing animated:animated];
    
    if (animated)
    {
        if (editing)
        {
            _switchButton.hidden = false;
            [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^
            {
                _switchButton.alpha = editing ? 1.0f : 0.0f;
                CGRect frame = _switchButton.frame;
                frame.origin.x = editing ? 4 : (-30 - 5);
                _switchButton.frame = frame;
                
                [self layoutSubviews];
            } completion:nil];
        }
        else
        {
            [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^
            {
                _switchButton.alpha = editing ? 1.0f : 0.0f;
                CGRect frame = _switchButton.frame;
                frame.origin.x = editing ? 4 : (-30 - 5);
                _switchButton.frame = frame;
                
                [self layoutSubviews];
            } completion:^(BOOL finished)
            {
                if (finished)
                {
                    _switchButton.hidden = true;
                    
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
    }
    else
    {
        _switchButton.hidden = !editing;
        _switchButton.alpha = editing ? 1.0f : 0.0f;
        CGRect frame = _switchButton.frame;
        frame.origin.x = editing ? 4 : (-30 - 5);
        _switchButton.frame = frame;
        
        if (_editingIsActive)
        {
            _editingIsActive = false;
            _switchButtonMinus.transform = CGAffineTransformIdentity;
            _switchButtonMinus.center = CGPointMake(15, 14);
            _switchButtonMinus.image = normalMinusImage();
        }
        
        [self layoutSubviews];
    }
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
    if (show && _editingButton.alpha < 1.0f - FLT_EPSILON)
    {
        _editingButton.hidden = false;
        _editingButton.frame = CGRectMake(self.frame.size.width - TG_DELETE_BUTTON_EDGE_OFFSET - 2, _editingButton.frame.origin.y, 2, _editingButton.frame.size.height);
        _editingButtonLabel.alpha = 0.0f;
        
        [UIView animateWithDuration:0.25 delay:0 options:0 animations:^
        {
            _editingButton.alpha = 1.0f;
            _editingButton.frame = CGRectMake(self.frame.size.width - TG_DELETE_BUTTON_EDGE_OFFSET - 61, _editingButton.frame.origin.y, 61, _editingButton.frame.size.height);
            _editingButtonLabel.alpha = 1.0f;
        } completion:nil];
        
        if ([self.superview isKindOfClass:[TGActionTableView class]])
            [(TGActionTableView *)self.superview setActionCell:self];
    }
    else if (!show && _editingButton.alpha > FLT_EPSILON)
    {
        [UIView animateWithDuration:0.25 delay:0 options:0 animations:^
        {
            _editingButton.alpha = 0.0f;
            _editingButton.frame = CGRectMake(self.frame.size.width - TG_DELETE_BUTTON_EDGE_OFFSET - 2, _editingButton.frame.origin.y, 2, _editingButton.frame.size.height);
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

- (void)swipeGestureRecognized:(UISwipeGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateRecognized && !self.editing)
    {   
        [self setSelected:false];
        [self setHighlighted:false];
        
        [self animateDeleteButton:true];
    }
}

@end
