#import "TGConversationUnreadItemView.h"

#import "TGImageUtils.h"

#import "TGConversationController.h"

@interface TGConversationUnreadItemView ()

@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIImageView *titleBackgroundView;
@property (nonatomic, strong) UIImageView *arrowView;

@property (nonatomic, strong) UIImageView *editingSeparatorViewBottom;

@end

@implementation TGConversationUnreadItemView

#if TGUseCollectionView
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
#else
- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
#endif
    if (self != nil)
    {
        _titleBackgroundView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"ConversationNewMessagesDivider.png"]];
        _titleBackgroundView.frame = CGRectMake(0, 0, 320, _titleBackgroundView.frame.size.height);
        [self.contentView addSubview:_titleBackgroundView];
        
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.textColor = UIColorRGB(0x506e8d);
        _titleLabel.shadowColor = UIColorRGBA(0xffffff, 0.6f);
        _titleLabel.shadowOffset = CGSizeMake(0, 1);
        _titleLabel.font = [UIFont boldSystemFontOfSize:13];
        _titleLabel.textAlignment = UITextAlignmentCenter;
        _titleLabel.backgroundColor = [UIColor clearColor];
        [self.contentView addSubview:_titleLabel];
        
        _arrowView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"ConversationNewMessagesDividerArrow.png"]];
        [self.contentView addSubview:_arrowView];
    }
    return self;
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated
{
    if (_editingSeparatorViewBottom == nil && editing)
    {
        _editingSeparatorViewBottom = [[UIImageView alloc] initWithImage:[TGGlobalAssetsSource messageEditingSeparator]];
        _editingSeparatorViewBottom.alpha = 0.0f;
        _editingSeparatorViewBottom.hidden = true;
        
        [self addSubview:_editingSeparatorViewBottom];
    }
    
    if (animated)
    {
        if (editing)
        {
            _editingSeparatorViewBottom.hidden = false;
        }
        
        [UIView animateWithDuration:0.25 animations:^
        {
            _editingSeparatorViewBottom.alpha = editing ? 1.0f : 0.0f;
        } completion:^(BOOL finished)
        {
            if (finished)
            {
                _editingSeparatorViewBottom.hidden = !editing;
            }
        }];
    }
    else
    {
        _editingSeparatorViewBottom.alpha = editing ? 1.0f : 0.0f;
        _editingSeparatorViewBottom.hidden = !editing;
    }
    
    [super setEditing:editing animated:animated];
}

- (void)setTitle:(NSString *)title
{
    if (![_title isEqualToString:title])
    {
        _titleLabel.text = title;
        _title = title;
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    if (_editingSeparatorViewBottom != nil)
        _editingSeparatorViewBottom.frame = CGRectMake(0, -2, self.frame.size.width, 2);
    
    [_titleLabel sizeToFit];
    CGRect dateFrame = _titleLabel.frame;
    dateFrame.origin = CGPointMake((int)((self.contentView.frame.size.width - dateFrame.size.width) / 2), (int)((self.contentView.frame.size.height - dateFrame.size.height) / 2) - 1);
    _titleLabel.frame = dateFrame;
    
    _titleBackgroundView.frame = CGRectMake(0, 3, self.frame.size.width, _titleBackgroundView.frame.size.height);
    
    CGRect arrowFrame = _arrowView.frame;
    arrowFrame.origin = CGPointMake(self.frame.size.width - arrowFrame.size.width - 7, 13 + (TGIsRetina() ? 0.5f : 0.0f));
    _arrowView.frame = arrowFrame;
}

@end
