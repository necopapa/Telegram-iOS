#import "TGNearbyUserCell.h"

#import "TGRemoteImageView.h"
#import "TGLabel.h"

#import "TGInterfaceAssets.h"

@interface TGNearbyUserCell ()

@property (nonatomic, strong) TGRemoteImageView *avatarView;
@property (nonatomic, strong) TGLabel *titleLabel;
@property (nonatomic, strong) TGLabel *subtitleLabel;

@end

@implementation TGNearbyUserCell

@synthesize uid = _uid;

@synthesize avatarUrl = _avatarUrl;
@synthesize title = _title;
@synthesize subtitle = _subtitle;

@synthesize avatarView = _avatarView;
@synthesize titleLabel = _titleLabel;
@synthesize subtitleLabel = _subtitleLabel;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self)
    {
        _avatarView = [[TGRemoteImageView alloc] initWithFrame:CGRectMake(5, 5, 40, 40)];
        _avatarView.fadeTransition = true;
        [self.contentView addSubview:_avatarView];
        
        _titleLabel = [[TGLabel alloc] initWithFrame:CGRectZero];
        _titleLabel.contentMode = UIViewContentModeLeft;
        _titleLabel.font = [UIFont boldSystemFontOfSize:17];
        _titleLabel.textColor = UIColorRGB(0x000000);
        _titleLabel.highlightedTextColor = UIColorRGB(0xffffff);
        _titleLabel.backgroundColor = [UIColor whiteColor];
        [self.contentView addSubview:_titleLabel];
        
        _subtitleLabel = [[TGLabel alloc] initWithFrame:CGRectZero];
        _subtitleLabel.contentMode = UIViewContentModeLeft;
        _subtitleLabel.font = [UIFont systemFontOfSize:13];
        _subtitleLabel.textColor = UIColorRGB(0x999999);
        _subtitleLabel.highlightedTextColor = UIColorRGB(0xffffff);
        _subtitleLabel.backgroundColor = [UIColor whiteColor];
        [self.contentView addSubview:_subtitleLabel];
    }
    return self;
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated
{
    [super setEditing:editing animated:animated];
}

- (void)resetView:(bool)keepState
{
    _titleLabel.text = _title;
    _subtitleLabel.text = _subtitle;
    
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
        [_avatarView loadImage:[[TGInterfaceAssets instance] avatarPlaceholder:_uid]];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    _titleLabel.frame = CGRectMake(5 + 40 + 6, 3, self.frame.size.width - (5 + 40) - 6 - 26, 25);
    _subtitleLabel.frame = CGRectMake(5 + 40 + 6, 25, self.frame.size.width - (5 + 40) - 6 - 26, 20);
}

@end
