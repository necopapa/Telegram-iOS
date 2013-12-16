#import "TGConversationDateItemView.h"

#import "TGConversationController.h"

#import "TGImageUtils.h"

@interface TGConversationDateItemView ()

@property (nonatomic, strong) UILabel *dateLabel;
@property (nonatomic, strong) UIImageView *dateBackgroundView;

@property (nonatomic, strong) UIImageView *editingSeparatorViewBottom;

@end

@implementation TGConversationDateItemView

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
        _dateBackgroundView = [[UIImageView alloc] initWithImage:[TGGlobalAssetsSource systemMessageBackground]];
        [self.contentView addSubview:_dateBackgroundView];
        
        _dateLabel = [[UILabel alloc] init];
        _dateLabel.textColor = [TGGlobalAssetsSource messageActionTextColor];
        _dateLabel.shadowColor = [TGGlobalAssetsSource messageActionShadowColor];
        _dateLabel.shadowOffset = CGSizeMake(0, 1);
        _dateLabel.font = [UIFont boldSystemFontOfSize:13];
        _dateLabel.textAlignment = UITextAlignmentCenter;
        _dateLabel.backgroundColor = [UIColor clearColor];
        [self.contentView addSubview:_dateLabel];
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

- (void)setDateString:(NSString *)dateString
{
    if (![_dateString isEqualToString:dateString])
    {
        _dateLabel.text = dateString;
        _dateString = dateString;
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    if (_editingSeparatorViewBottom != nil)
        _editingSeparatorViewBottom.frame = CGRectMake(0, -2, self.frame.size.width, 2);
    
    [_dateLabel sizeToFit];
    CGRect dateFrame = _dateLabel.frame;
    dateFrame.origin = CGPointMake((int)((self.contentView.frame.size.width - dateFrame.size.width) / 2), (int)((self.contentView.frame.size.height - dateFrame.size.height) / 2) - 1);
    _dateLabel.frame = dateFrame;
    
    _dateBackgroundView.frame = CGRectMake(dateFrame.origin.x - 10, dateFrame.origin.y - 2, dateFrame.size.width + 20, _dateBackgroundView.frame.size.height);
}

@end
