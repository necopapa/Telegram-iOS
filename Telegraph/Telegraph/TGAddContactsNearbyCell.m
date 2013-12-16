#import "TGAddContactsNearbyCell.h"

#import "TGInterfaceAssets.h"
#import "TGImageUtils.h"

@interface TGAddContactsNearbyCell ()

@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;

@property (nonatomic, strong) UIImageView *arrowView;

@property (nonatomic, strong) UIImageView *badgeBackgroundView;
@property (nonatomic, strong) UILabel *badgeLabel;

@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;

@end

@implementation TGAddContactsNearbyCell

@synthesize badgeCount = _badgeCount;
@synthesize isLoading = _isLoading;

@synthesize iconView = _iconView;
@synthesize titleLabel = _titleLabel;
@synthesize subtitleLabel = _subtitleLabel;

@synthesize arrowView = _arrowView;

@synthesize badgeBackgroundView = _badgeBackgroundView;
@synthesize badgeLabel = _badgeLabel;

@synthesize activityIndicator = _activityIndicator;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self)
    {
        UIImage *selectedCellImage = nil;
        UIImage *rawImage = [UIImage imageNamed:@"CellHighlighted102.png"];
        if ([UIImage instancesRespondToSelector:@selector(resizableImageWithCapInsets:resizingMode:)])
            selectedCellImage = [rawImage resizableImageWithCapInsets:UIEdgeInsetsMake(1, 0, 2, 0) resizingMode:UIImageResizingModeStretch];
        else
            selectedCellImage = [rawImage stretchableImageWithLeftCapWidth:0 topCapHeight:(int)(rawImage.size.height - 2)];
        self.selectedBackgroundView = [[UIImageView alloc] initWithImage:selectedCellImage];
        
        rawImage = [UIImage imageNamed:@"Cell102.png"];
        UIImage *cellImage = [rawImage stretchableImageWithLeftCapWidth:0 topCapHeight:(int)(rawImage.size.height - 2)];
        self.backgroundView = [[UIImageView alloc] initWithImage:cellImage];
        
        CGSize size = self.contentView.bounds.size;
        
        _iconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"NearbyIcon.png"] highlightedImage:[UIImage imageNamed:@"NearbyIcon_Highlighted.png"]];
        _iconView.frame = CGRectOffset(_iconView.frame, 5, 10);
        [self.contentView addSubview:_iconView];
        
        _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(5 + _iconView.frame.size.width + 10, 12, size.width - (5 + _iconView.frame.size.width + 10) - 8, 20)];
        _titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _titleLabel.contentMode = UIViewContentModeLeft;
        _titleLabel.font = [UIFont boldSystemFontOfSize:17];
        _titleLabel.textColor = [UIColor blackColor];
        _titleLabel.highlightedTextColor = [UIColor whiteColor];
        [self.contentView addSubview:_titleLabel];
        
        _subtitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(5 + _iconView.frame.size.width + 10, 33, size.width - (5 + _iconView.frame.size.width + 10) - 8, 15)];
        _subtitleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _subtitleLabel.contentMode = UIViewContentModeLeft;
        _subtitleLabel.font = [UIFont systemFontOfSize:13];
        _subtitleLabel.textColor = UIColorRGB(0x999999);
        _subtitleLabel.highlightedTextColor = [UIColor whiteColor];
        [self.contentView addSubview:_subtitleLabel];
        
        _arrowView = [[UIImageView alloc] initWithImage:[TGInterfaceAssets groupedCellDisclosureArrow] highlightedImage:[TGInterfaceAssets groupedCellDisclosureArrowHighlighted]];
        _arrowView.frame = CGRectOffset(_arrowView.frame, size.width - _arrowView.frame.size.width - 10, 23);
        _arrowView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        [self.contentView addSubview:_arrowView];
        
        [self setTitleString:@"People Nearby"];
        _subtitleLabel.text = @"Find people around you";
        
        _activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        _activityIndicator.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        _activityIndicator.frame = CGRectOffset(_activityIndicator.frame, size.width - _activityIndicator.frame.size.width - 20, 20);
        _activityIndicator.hidden = true;
        [self addSubview:_activityIndicator];
        
        _badgeBackgroundView = [[UIImageView alloc] initWithImage:[[TGInterfaceAssets instance] dialogListUnreadCountBadge] highlightedImage:[[TGInterfaceAssets instance] dialogListUnreadCountBadgeHighlighted]];
        _badgeBackgroundView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        [self.contentView addSubview:_badgeBackgroundView];
        
        _badgeLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 50, 20)];
        _badgeLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        _badgeLabel.textColor = [UIColor whiteColor];
        _badgeLabel.highlightedTextColor = UIColorRGB(0x036ceb);
        _badgeLabel.font = [UIFont boldSystemFontOfSize:14];
        _badgeLabel.backgroundColor = [UIColor clearColor];
        [self.contentView addSubview:_badgeLabel];
        
        _badgeBackgroundView.hidden = true;
        _badgeLabel.hidden = true;
    }
    return self;
}

- (void)setTitleString:(NSString *)titleString
{   
    _titleLabel.text = titleString;
}

- (void)setBadgeCount:(int)badgeCount
{
    _badgeCount = badgeCount;
    
    if (badgeCount > 0)
    {
        _badgeLabel.hidden = false;
        _badgeBackgroundView.hidden = false;
        _badgeLabel.text = [[NSString alloc] initWithFormat:@"%d", badgeCount];
        
        int countTextWidth = (int)([_badgeLabel.text sizeWithFont:_badgeLabel.font].width);
        
        float backgroundWidth = MAX(19, countTextWidth + 6) - (TGIsRetina() ? 0.0f : 0.0f);
        CGRect unreadCountBackgroundFrame = CGRectMake(self.contentView.frame.size.width - 21 - backgroundWidth, 21, backgroundWidth, 19);
        _badgeBackgroundView.frame = unreadCountBackgroundFrame;
        CGRect unreadCountLabelFrame = _badgeLabel.frame;
        unreadCountLabelFrame.origin = CGPointMake(unreadCountBackgroundFrame.origin.x + (float)((unreadCountBackgroundFrame.size.width - countTextWidth) / 2) - (TGIsRetina() ? 0.0f : 0.0f), unreadCountBackgroundFrame.origin.y - (TGIsRetina() ? 0.5f : 0.0f));
        _badgeLabel.frame = unreadCountLabelFrame;
    }
    else
    {
        _badgeLabel.hidden = true;
        _badgeBackgroundView.hidden = true;
    }
}

- (void)setIsLoading:(bool)isLoading
{
    _isLoading = isLoading;
    
    if (isLoading)
    {
        _badgeLabel.hidden = true;
        _badgeBackgroundView.hidden = true;
        [_activityIndicator startAnimating];
    }
    else
    {
        _badgeLabel.hidden = _badgeCount <= 0;
        _badgeBackgroundView.hidden = _badgeLabel.hidden;
        [_activityIndicator stopAnimating];
    }
}

@end
