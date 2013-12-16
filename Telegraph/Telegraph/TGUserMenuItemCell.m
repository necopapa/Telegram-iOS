#import "TGUserMenuItemCell.h"

#import "TGRemoteImageView.h"
#import "TGLabel.h"

#import "TGInterfaceAssets.h"

#import "TGImageUtils.h"

#import "TGDateLabel.h"

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

@interface TGUserMenuItemCell () <TGActionTableViewCell>

@property (nonatomic, strong) TGRemoteImageView *avatarView;
@property (nonatomic, strong) TGLabel *titleLabel;
@property (nonatomic, strong) TGDateLabel *subtitleLabel;

@property (nonatomic, strong) UIView *disabledOverlayView;

@property (nonatomic) bool editingIsActive;
@property (nonatomic, strong) UIButton *switchButton;
@property (nonatomic, strong) UIImageView *switchButtonMinus;
@property (nonatomic, strong) UIButton *editingButton;
@property (nonatomic, strong) UIImageView *editingButtonLabel;

@end

@implementation TGUserMenuItemCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self)
    {
        float retinaPixel = TGIsRetina() ? 0.5f : 0.0f;
        
        static UIImage *switchButtonImage = nil;
        static UIImage *deleteTextImage = nil;
        
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^
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
        
        _switchButton = [[UIButton alloc] initWithFrame:CGRectMake(16 + retinaPixel, 11, 30, 30)];
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
        
        _avatarView = [[TGRemoteImageView alloc] initWithFrame:CGRectMake(6, 6 + retinaPixel, 36, 36)];
        _avatarView.fadeTransition = true;
        [self.contentView addSubview:_avatarView];
        
        _titleLabel = [[TGLabel alloc] initWithFrame:CGRectZero];
        _titleLabel.contentMode = UIViewContentModeLeft;
        _titleLabel.font = [UIFont boldSystemFontOfSize:15 + retinaPixel];
        _titleLabel.textColor = [UIColor blackColor];
        _titleLabel.highlightedTextColor = UIColorRGB(0xffffff);
        _titleLabel.backgroundColor = [UIColor whiteColor];
        [self.contentView addSubview:_titleLabel];
        
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
        _subtitleLabel.backgroundColor = [UIColor whiteColor];
        [self.contentView addSubview:_subtitleLabel];
        
        _editingButton = [[UIButton alloc] init];
        _editingButton.exclusiveTouch = true;
        _editingButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        [_editingButton setBackgroundImage:deleteButtonImage() forState:UIControlStateNormal];
        [_editingButton setBackgroundImage:deleteButtonHighlightedImage() forState:UIControlStateHighlighted];
        
        [_editingButton addTarget:self action:@selector(deleteButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        
        _editingButton.frame = CGRectMake(self.frame.size.width - TG_DELETE_BUTTON_EDGE_OFFSET - 61, 9, 61, 31);
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
        
        _disabledOverlayView = [[UIView alloc] initWithFrame:CGRectInset(self.frame, 12, 6)];
        _disabledOverlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _disabledOverlayView.backgroundColor = [UIColor whiteColor];
        _disabledOverlayView.hidden = true;
        [self addSubview:_disabledOverlayView];
    }
    return self;
}

- (void)updateEditable
{
    [self updateEditable:false];
}

- (void)updateEditable:(bool)animated
{
    [self setEditing:self.editing animated:animated];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated
{
    [super setEditing:editing animated:animated];
    
    if (!_editable || _alwaysNonEditable)
    {
        [UIView animateWithDuration:0.3 animations:^
        {
            [self layoutSubviews];
        }];
        
        _switchButton.alpha = 0.0f;
        _switchButton.hidden = true;
        
        if (_editingIsActive)
        {
            _editingIsActive = false;
            _switchButtonMinus.transform = CGAffineTransformIdentity;
            _switchButtonMinus.center = CGPointMake(15, 14);
            _switchButtonMinus.image = normalMinusImage();
        }
    }
    else
    {
        if (editing)
        {
            _switchButton.hidden = false;
            
            if (animated)
            {
                [UIView animateWithDuration:0.2 delay:0.1 options:0 animations:^
                {
                    _switchButton.alpha = 1.0f;
                } completion:nil];

                [UIView animateWithDuration:0.3 animations:^
                {
                    [self layoutSubviews];
                }];
            }
            else
            {
                _switchButton.alpha = 1.0f;
            }
        }
        else
        {
            if (animated)
            {
                [UIView animateWithDuration:0.18 delay:0 options:0 animations:^
                {
                    _switchButton.alpha = 0.0f;
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
                
                [UIView animateWithDuration:0.3 animations:^
                {
                    [self layoutSubviews];
                } completion:nil];
            }
            else
            {
                _switchButton.alpha = 0.0f;
                _switchButton.hidden = true;
                
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
}

- (void)resetView:(bool)keepState
{
    _titleLabel.text = _title;
    _subtitleLabel.dateText = _subtitle;
    [_subtitleLabel measureTextSize];
    
    if (_subtitleActive)
    {
        _titleLabel.textColor = UIColorRGB(0x0779d0);
        _subtitleLabel.textColor = UIColorRGB(0x0779d0);
    }
    else
    {
        _titleLabel.textColor = [UIColor blackColor];
        _subtitleLabel.textColor = UIColorRGB(0x888888);
    }
    
    if (_avatarUrl != nil)
    {
        if (![_avatarView.currentUrl isEqualToString:_avatarUrl])
        {
            if (keepState)
            {
                [_avatarView loadImage:_avatarUrl filter:@"avatar40" placeholder:(_avatarView.currentImage != nil ? _avatarView.currentImage : [[TGInterfaceAssets instance] avatarPlaceholderGeneric]) forceFade:true];
            }
            else
            {
                [_avatarView loadImage:_avatarUrl filter:@"avatar40" placeholder:[[TGInterfaceAssets instance] avatarPlaceholderGeneric] forceFade:false];
            }
        }
    }
    else
        [_avatarView loadImage:[[TGInterfaceAssets instance] smallAvatarPlaceholder:_uid]];
    
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

- (void)setIsDisabled:(bool)isDisabled
{
    [self setIsDisabled:isDisabled animated:false];
}

- (void)setIsDisabled:(bool)isDisabled animated:(bool)animated
{
    _isDisabled = isDisabled;
    self.userInteractionEnabled = !isDisabled;
    
    if (animated)
    {
        if (isDisabled)
        {
            _disabledOverlayView.hidden = false;
            _disabledOverlayView.alpha = 0.0f;
        }
        
        [UIView animateWithDuration:0.3 animations:^
        {
            if (isDisabled)
                _disabledOverlayView.alpha = 0.6f;
            else
                _disabledOverlayView.alpha = 0.0f;
        } completion:^(BOOL finished)
        {
            if (finished)
            {
                if (!isDisabled)
                    _disabledOverlayView.hidden = true;
            }
        }];
    }
    else
    {
        if (_isDisabled)
        {
            _disabledOverlayView.hidden = false;
            _disabledOverlayView.alpha = 0.6f;
        }
        else
        {
            _disabledOverlayView.hidden = true;
        }
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    bool editing = self.editing && !_alwaysNonEditable;
    
    float paddingLeft = editing ? 37 : 0;
    
    float retinaPixel = TGIsRetina() ? 0.5f : 0.0f;
    
    _avatarView.frame = CGRectMake(paddingLeft + 6, 6, 36, 36);
    _titleLabel.frame = CGRectMake(paddingLeft + 6 + 44, 5, self.frame.size.width - 6 - 44 - 26 - paddingLeft, 22);
    _subtitleLabel.frame = CGRectMake(paddingLeft + 6 + 44, 24 + retinaPixel, self.frame.size.width - 6 - 44 - 26 - paddingLeft, 18);
}

#pragma mark -

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

@end
