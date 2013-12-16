#import "TGLoginCountryCell.h"

@interface TGLoginCountryCell ()

@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *codeLabel;

@end

@implementation TGLoginCountryCell

@synthesize titleLabel = _titleLabel;
@synthesize codeLabel = _codeLabel;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self)
    {
        _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _titleLabel.font = [UIFont boldSystemFontOfSize:17];
        _titleLabel.backgroundColor = [UIColor whiteColor];
        _titleLabel.textColor = [UIColor blackColor];
        _titleLabel.highlightedTextColor = [UIColor whiteColor];
        [self.contentView addSubview:_titleLabel];
        
        _codeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _codeLabel.textAlignment = UITextAlignmentRight;
        _codeLabel.contentMode = UIViewContentModeRight;
        _codeLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        _codeLabel.font = [UIFont boldSystemFontOfSize:17];
        _codeLabel.backgroundColor = [UIColor whiteColor];
        _codeLabel.textColor = UIColorRGB(0x516691);
        _codeLabel.highlightedTextColor = [UIColor whiteColor];
        [self addSubview:_codeLabel];
        
        [self setUseIndex:false];
    }
    return self;
}

- (void)setTitle:(NSString *)title
{
    _titleLabel.text = title;
}

- (void)setCode:(NSString *)code
{
    _codeLabel.text = code;
}

- (void)setUseIndex:(bool)useIndex
{
    _titleLabel.frame = useIndex ? CGRectMake(9, 12, self.contentView.frame.size.width - 54 - 5, 20) : CGRectMake(9, 12, self.contentView.frame.size.width - 54 - 15, 20);
    _codeLabel.frame = useIndex ? CGRectMake(self.frame.size.width - 49 - 32, 12, 50, 20) : CGRectMake(self.frame.size.width - 50 - 9, 12, 50, 20);
}

@end
