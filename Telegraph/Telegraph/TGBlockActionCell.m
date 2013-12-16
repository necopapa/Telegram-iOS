#import "TGBlockActionCell.h"

#import "TGInterfaceAssets.h"

@interface TGBlockActionCell ()

@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIImageView *disclosureIndicator;
@property (nonatomic, strong) UIImageView *iconView;

@property (nonatomic, strong) UIImageView *shadowView;
@property (nonatomic, strong) UIView *topLineView;

@property (nonatomic, strong) UIView *blankBackgroundView;
@property (nonatomic, strong) UIView *lineBackgroundView;

@end

@implementation TGBlockActionCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self)
    {
        self.backgroundColor = nil;
        self.opaque = false;
        
        static UIImage *cellImage = nil;
        if (cellImage == nil)
            cellImage = [UIImage imageNamed:@"Cell88.png"];
        
        static UIImage *selectedCellImage = nil;
        if (selectedCellImage == nil)
            selectedCellImage = [UIImage imageNamed:@"CellHighlighted88.png"];
        
        self.backgroundView = [[UIView alloc] initWithFrame:self.bounds];
        
        _blankBackgroundView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"Blank.png"]];
        CGRect blankFrame = self.backgroundView.bounds;
        blankFrame.size.height -= 1;
        _blankBackgroundView.frame = blankFrame;
        _blankBackgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.backgroundView addSubview:_blankBackgroundView];
        
        _lineBackgroundView = [[UIImageView alloc] initWithImage:cellImage];
        _lineBackgroundView.frame = self.backgroundView.bounds;
        _lineBackgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _lineBackgroundView.alpha = 0.0f;
        [self.backgroundView addSubview:_lineBackgroundView];
        
        self.selectedBackgroundView = [[UIImageView alloc] initWithImage:selectedCellImage];
        
        _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(54, 12, self.contentView.frame.size.width - 30, 20)];
        _titleLabel.contentMode = UIViewContentModeLeft;
        _titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _titleLabel.font = [UIFont boldSystemFontOfSize:16];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.textColor = UIColorRGB(0x0779d0);
        _titleLabel.highlightedTextColor = [UIColor whiteColor];
        _titleLabel.text = TGLocalized(@"BlockedUsers.BlockUser");
        [self.contentView addSubview:_titleLabel];
        
        _iconView = [[UIImageView alloc] init];
        [self.contentView addSubview:_iconView];
        
        _disclosureIndicator = [[UIImageView alloc] initWithImage:[TGInterfaceAssets groupedCellDisclosureArrow] highlightedImage:[TGInterfaceAssets groupedCellDisclosureArrowHighlighted]];
        _disclosureIndicator.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        _disclosureIndicator.frame = CGRectOffset(_disclosureIndicator.frame, self.contentView.frame.size.width - _disclosureIndicator.frame.size.width - 12, 14);
        [self.contentView addSubview:_disclosureIndicator];
        
        _iconView.image = [UIImage imageNamed:@"ListIconBlock.png"];
        _iconView.highlightedImage = [UIImage imageNamed:@"ListIconBlock_Highlighted.png"];
        [_iconView sizeToFit];
        
        CGRect iconFrame = _iconView.frame;
        iconFrame.origin = CGPointMake(10, 11);
        _iconView.frame = iconFrame;
        
        self.clipsToBounds = false;
        
        _topLineView = [[UIView alloc] initWithFrame:CGRectMake(0, -1, self.frame.size.width, 1)];
        _topLineView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _topLineView.backgroundColor = UIColorRGB(0xe5e5e5);
        [self addSubview:_topLineView];
        
        UIImage *shadowImage = [UIImage imageNamed:@"ListCellShadow.png"];
        _shadowView = [[UIImageView alloc] initWithFrame:CGRectMake(0, self.frame.size.height - 1, self.frame.size.width, shadowImage.size.height)];
        _shadowView.image = shadowImage;
        _shadowView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
        [self addSubview:_shadowView];
    }
    return self;
}

- (void)setEnableShadow:(bool)enableShadow animated:(bool)animated
{
    animated = false;
    
    if (animated)
    {
        if (enableShadow)
            _blankBackgroundView.alpha = 1.0f;
        else
            _lineBackgroundView.alpha = 1.0f;
        
        [UIView animateWithDuration:0.3 animations:^
        {
            _shadowView.alpha = enableShadow ? 1.0f : 0.0f;
            _topLineView.alpha = _shadowView.alpha;
            
            if (enableShadow)
                _lineBackgroundView.alpha = 0.0f;
            else
                _blankBackgroundView.alpha = 0.0f;
        } completion:^(BOOL finished)
        {
            if (finished)
            {

            }
        }];
    }
    else
    {
        _shadowView.alpha = enableShadow ? 1.0f : 0.0f;
        _topLineView.alpha = _shadowView.alpha;
        
        _blankBackgroundView.alpha = enableShadow ? 1.0f : 0.0f;
        _lineBackgroundView.alpha = enableShadow ? 0.0f : 1.0f;
    }
}

@end
