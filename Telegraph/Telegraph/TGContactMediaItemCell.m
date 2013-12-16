#import "TGContactMediaItemCell.h"

#import "TGInterfaceAssets.h"

@interface TGContactMediaItemCell ()

@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *countLabel;
@property (nonatomic, strong) UIImageView *disclosureIndicator;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;

@property (nonatomic, strong) TGMediaListView *mediaListView;

@end

@implementation TGContactMediaItemCell

@synthesize titleLabel = _titleLabel;
@synthesize countLabel = _countLabel;
@synthesize disclosureIndicator = _disclosureIndicator;
@synthesize activityIndicator = _activityIndicator;

@synthesize mediaListView = _mediaListView;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier mediaListView:(TGMediaListView *)mediaListView
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self)
    {
        _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(11, self.contentView.frame.size.height - 32, self.contentView.frame.size.width - 30, 21)];
        _titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
        _titleLabel.font = [UIFont boldSystemFontOfSize:17];
        _titleLabel.backgroundColor = [UIColor whiteColor];
        _titleLabel.textColor = [UIColor blackColor];
        _titleLabel.highlightedTextColor = [UIColor whiteColor];
        [self.contentView addSubview:_titleLabel];
        
        _countLabel = [[UILabel alloc] initWithFrame:CGRectMake(self.contentView.frame.size.width - 200 - 11 - 14, 11, 200, 21)];
        _countLabel.textAlignment = UITextAlignmentRight;
        _countLabel.contentMode = UIViewContentModeRight;
        _countLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _countLabel.font = [UIFont systemFontOfSize:17];
        _countLabel.backgroundColor = [UIColor clearColor];
        _countLabel.textColor = UIColorRGB(0x415d7f);
        _countLabel.highlightedTextColor = [UIColor whiteColor];
        [self.contentView addSubview:_countLabel];
        
        _disclosureIndicator = [[UIImageView alloc] initWithImage:[TGInterfaceAssets groupedCellDisclosureArrow] highlightedImage:[TGInterfaceAssets groupedCellDisclosureArrowHighlighted]];
        _disclosureIndicator.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;
        _disclosureIndicator.frame = CGRectOffset(_disclosureIndicator.frame, self.contentView.frame.size.width - _disclosureIndicator.frame.size.width - 11, 15);
        [self.contentView addSubview:_disclosureIndicator];
        
        _activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        _activityIndicator.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;
        _activityIndicator.frame = CGRectOffset(_activityIndicator.frame, self.contentView.frame.size.width - _activityIndicator.frame.size.width - 8, 12);
        [self.contentView addSubview:_activityIndicator];
        
        _mediaListView = mediaListView;
        _mediaListView.frame = CGRectMake(6, 6, self.contentView.frame.size.width - 12, 194);
        [self.contentView addSubview:_mediaListView];
    }
    return self;
}

- (void)setTitle:(NSString *)title
{
    _titleLabel.text = title;
}

- (void)setCount:(int)count
{
    if (count <= 0)
        _countLabel.text = TGLocalized(@"ConversationProfile.NoMedia");
    else
        _countLabel.text = [[NSString alloc] initWithFormat:@"%d", count];
}

- (void)setIsLoading:(bool)isLoading
{
    if (isLoading)
    {
        _countLabel.hidden = true;
        _activityIndicator.hidden = false;
        if (!_activityIndicator.isAnimating)
            [_activityIndicator startAnimating];
        _disclosureIndicator.hidden = true;
    }
    else
    {
        _countLabel.hidden = false;
        _activityIndicator.hidden = true;
        if (_activityIndicator.isAnimating)
            [_activityIndicator stopAnimating];
        _disclosureIndicator.hidden = false;
    }
}

- (void)setIsExpanded:(bool)isExpanded animated:(bool)animated
{
    if (isExpanded != _mediaListView.alpha > FLT_EPSILON)
    {
        if (animated)
        {
            [UIView animateWithDuration:0.3 animations:^
            {
                _mediaListView.alpha = isExpanded ? 1.0f : 0.0f;
                _mediaListView.transform = isExpanded ? CGAffineTransformIdentity : CGAffineTransformMakeScale(1.0f, 0.1f);
            }];
        }
        else
        {
            _mediaListView.alpha = isExpanded ? 1.0f : 0.0f;
            _mediaListView.transform = isExpanded ? CGAffineTransformIdentity : CGAffineTransformMakeScale(1.0f, 0.1f);
        }
    }
}

@end
