#import "TGFlatActionCell.h"

#import "TGInterfaceAssets.h"

@interface TGFlatActionCell ()

@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIImageView *disclosureIndicator;
@property (nonatomic, strong) UIImageView *iconView;

@property (nonatomic) TGFlatActionCellMode mode;

@end

@implementation TGFlatActionCell

@synthesize titleLabel = _titleLabel;
@synthesize disclosureIndicator = _disclosureIndicator;
@synthesize iconView = _iconView;

@synthesize mode = _mode;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self)
    {
        static UIImage *cellImage = nil;
        if (cellImage == nil)
            cellImage = [UIImage imageNamed:@"Cell88.png"];
        
        static UIImage *selectedCellImage = nil;
        if (selectedCellImage == nil)
            selectedCellImage = [UIImage imageNamed:@"CellHighlighted88.png"];
        
        self.backgroundView = [[UIImageView alloc] initWithImage:cellImage];
        self.selectedBackgroundView = [[UIImageView alloc] initWithImage:selectedCellImage];
        
        _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(53, 12, self.contentView.frame.size.width - 30, 20)];
        _titleLabel.contentMode = UIViewContentModeLeft;
        _titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _titleLabel.font = [UIFont boldSystemFontOfSize:16];
        _titleLabel.backgroundColor = [UIColor whiteColor];
        _titleLabel.textColor = UIColorRGB(0x0779d0);
        _titleLabel.highlightedTextColor = [UIColor whiteColor];
        [self.contentView addSubview:_titleLabel];
        
        _iconView = [[UIImageView alloc] init];
        [self.contentView addSubview:_iconView];
        
        _disclosureIndicator = [[UIImageView alloc] initWithImage:[TGInterfaceAssets groupedCellDisclosureArrow] highlightedImage:[TGInterfaceAssets groupedCellDisclosureArrowHighlighted]];
        _disclosureIndicator.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        _disclosureIndicator.frame = CGRectOffset(_disclosureIndicator.frame, self.contentView.frame.size.width - _disclosureIndicator.frame.size.width - 12, 14);
        [self.contentView addSubview:_disclosureIndicator];
    }
    return self;
}

- (void)setMode:(TGFlatActionCellMode)mode
{
    _mode = mode;
    
    if (mode == TGFlatActionCellModeInvite)
        _titleLabel.text = TGLocalized(@"Contacts.InviteFriends");
    else if (mode == TGFlatActionCellModeCreateGroup || mode == TGFlatActionCellModeCreateGroupContacts)
        _titleLabel.text = TGLocalized(@"Compose.NewGroup");
    else if (mode == TGFlatActionCellModeCreateEncrypted)
        _titleLabel.text = TGLocalized(@"Compose.NewEncryptedChat");

    static UIImage *inviteIcon = nil;
    static UIImage *inviteIconHighlighted = nil;
    
    static UIImage *friendsIcon = nil;
    static UIImage *friendsIconHighlighted = nil;
    
    static UIImage *encryptedIcon = nil;
    static UIImage *encryptedIconHighlighted = nil;
    
    if (inviteIcon == nil)
    {
        inviteIcon = [UIImage imageNamed:@"ListIconInvite.png"];
        inviteIconHighlighted = [UIImage imageNamed:@"ListIconInvite_Highlighted.png"];
        friendsIcon = [UIImage imageNamed:@"ListIconFriends.png"];
        friendsIconHighlighted = [UIImage imageNamed:@"ListIconFriends_Highlighted.png"];
        encryptedIcon = [UIImage imageNamed:@"ListIconEncrypted.png"];
        encryptedIconHighlighted = [UIImage imageNamed:@"ListIconEncrypted_Highlighted.png"];
    }
    
    if (mode == TGFlatActionCellModeInvite)
    {
        _iconView.image = inviteIcon;
        _iconView.highlightedImage = inviteIconHighlighted;
        [_iconView sizeToFit];
        
        CGRect iconFrame = _iconView.frame;
        iconFrame.origin = CGPointMake(13, 12);
        _iconView.frame = iconFrame;
        
        _disclosureIndicator.hidden = false;
    }
    else if (mode == TGFlatActionCellModeCreateGroup || mode == TGFlatActionCellModeCreateGroupContacts)
    {
        _iconView.image = friendsIcon;
        _iconView.highlightedImage = friendsIconHighlighted;
        [_iconView sizeToFit];
        
        CGRect iconFrame = _iconView.frame;
        iconFrame.origin = CGPointMake(10, 12);
        _iconView.frame = iconFrame;
        
        _disclosureIndicator.hidden = mode == TGFlatActionCellModeCreateGroup;
    }
    else if (mode == TGFlatActionCellModeCreateEncrypted)
    {
        _iconView.image = encryptedIcon;
        _iconView.highlightedImage = encryptedIconHighlighted;
        [_iconView sizeToFit];
        
        CGRect iconFrame = _iconView.frame;
        iconFrame.origin = CGPointMake(10, 9);
        _iconView.frame = iconFrame;
        
        _disclosureIndicator.hidden = true;
    }
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];
    
    if (selected)
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
    [super setHighlighted:highlighted animated:animated];
    
    if (highlighted)
    {
        CGRect frame = self.selectedBackgroundView.frame;
        frame.origin.y = true ? -1 : 0;
        frame.size.height = self.frame.size.height + 1;
        self.selectedBackgroundView.frame = frame;
        
        [self adjustOrdering];
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
            if ([view isKindOfClass:UITableViewCellClass] || [view isKindOfClass:UISearchBarClass])// || ((int)view.frame.size.height) == 25)
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

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGRect frame = self.selectedBackgroundView.frame;
    frame.origin.y = true ? -1 : 0;
    frame.size.height = self.frame.size.height + 1;
    self.selectedBackgroundView.frame = frame;
}

@end
