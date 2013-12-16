#import "TGDialogListSearchCell.h"

#import "TGRemoteImageView.h"
#import "TGLabel.h"

#import "TGHighlightTriggerLabel.h"
#import "TGHighlightImageView.h"

@interface TGDialogListSearchCell ()

@property (nonatomic, strong) TGRemoteImageView *avatarView;

@property (nonatomic, strong) TGLabel *titleLabelFirst;
@property (nonatomic, strong) TGLabel *titleLabelSecond;
@property (nonatomic, strong) TGLabel *subtitleLabel;

@property (nonatomic, strong) UIImageView *groupChatIcon;

@end

@implementation TGDialogListSearchCell

@synthesize assetsSource = _assetsSource;

@synthesize conversationId = _conversationId;

@synthesize titleTextFirst = _titleTextFirst;
@synthesize titleTextSecond = _titleTextSecond;
@synthesize subtitleText = _subtitleText;

@synthesize avatarUrl = _avatarUrl;

@synthesize isChat = _isChat;

@synthesize avatarView = _avatarView;

@synthesize titleLabelFirst = _titleLabelFirst;
@synthesize titleLabelSecond = _titleLabelSecond;
@synthesize subtitleLabel = _subtitleLabel;

@synthesize groupChatIcon = _groupChatIcon;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier assetsSource:(id<TGDialogListCellAssetsSource>)assetsSource
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self)
    {
        static UIImage *cellImage = nil;
        if (cellImage == nil)
            cellImage = [UIImage imageNamed:@"Cell102.png"];
        
        static UIImage *selectedCellImage = nil;
        if (selectedCellImage == nil)
            selectedCellImage = [UIImage imageNamed:@"CellHighlighted102.png"];
        
        self.backgroundView = [[UIImageView alloc] initWithImage:cellImage];
        self.selectedBackgroundView = [[UIImageView alloc] initWithImage:selectedCellImage];
        
        _assetsSource = assetsSource;
        
        _titleLabelFirst = [[TGLabel alloc] init];
        _titleLabelFirst.contentMode = UIViewContentModeLeft;
        _titleLabelFirst.font = [UIFont systemFontOfSize:19];
        _titleLabelFirst.textColor = UIColorRGB(0x000000);
        _titleLabelFirst.highlightedTextColor = UIColorRGB(0xffffff);
        _titleLabelFirst.backgroundColor = [UIColor whiteColor];
        [self.contentView addSubview:_titleLabelFirst];
        
        _titleLabelSecond = [[TGLabel alloc] init];
        _titleLabelSecond.contentMode = UIViewContentModeLeft;
        _titleLabelSecond.font = [UIFont boldSystemFontOfSize:19];
        _titleLabelSecond.textColor = UIColorRGB(0x000000);
        _titleLabelSecond.highlightedTextColor = UIColorRGB(0xffffff);
        _titleLabelSecond.backgroundColor = [UIColor whiteColor];
        [self.contentView addSubview:_titleLabelSecond];
        
        _subtitleLabel = [[TGLabel alloc] init];
        _subtitleLabel.contentMode = UIViewContentModeLeft;
        _subtitleLabel.font = [UIFont systemFontOfSize:13];
        _subtitleLabel.textColor = UIColorRGB(0x808080);
        _subtitleLabel.highlightedTextColor = UIColorRGB(0xffffff);
        _subtitleLabel.backgroundColor = [UIColor whiteColor];
        [self.contentView addSubview:_subtitleLabel];
        
        _avatarView = [[TGRemoteImageView alloc] initWithFrame:CGRectMake(5, 5, 40, 40)];
        _avatarView.fadeTransition = true;
        [self.contentView addSubview:_avatarView];
        
        _groupChatIcon = [[UIImageView alloc] init];
        _groupChatIcon.image = [_assetsSource dialogListGroupChatIcon];
        _groupChatIcon.highlightedImage = [_assetsSource dialogListGroupChatIconHighlighted];
        [self.contentView addSubview:_groupChatIcon];
    }
    return self;
}

- (void)setBoldMode:(int)index
{
    if (index == 0)
    {
        _titleLabelFirst.font = [UIFont systemFontOfSize:19];
        _titleLabelSecond.font = [UIFont boldSystemFontOfSize:19];
    }
    else if (index == 1)
    {
        _titleLabelFirst.font = [UIFont boldSystemFontOfSize:19];
        _titleLabelSecond.font = [UIFont systemFontOfSize:19];
    }
    else
    {
        _titleLabelFirst.font = [UIFont systemFontOfSize:19];
        _titleLabelSecond.font = [UIFont systemFontOfSize:19];
    }
}

- (void)resetView:(bool)animated
{
    if (_titleTextSecond == nil || _titleTextSecond.length == 0)
    {
        _titleLabelFirst.text = nil;
        _titleLabelFirst.hidden = true;
        
        _titleLabelSecond.text = _titleTextFirst;
    }
    else
    {
        _titleLabelFirst.text = _titleTextFirst;
        _titleLabelFirst.hidden = false;
        
        _titleLabelSecond.text = _titleTextSecond;
    }
    
    static UIColor *titleColor = nil;
    static UIColor *encryptedTitleColor = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        titleColor = UIColorRGB(0x111111);
        encryptedTitleColor = UIColorRGB(0x229a0a);
    });
    
    _titleLabelFirst.textColor = _isEncrypted ? encryptedTitleColor : titleColor;
    _titleLabelSecond.textColor = _isEncrypted ? encryptedTitleColor : titleColor;
    
    _subtitleLabel.text = _subtitleText;
    _subtitleLabel.hidden = _subtitleText == nil || _subtitleText.length == 0;
    
    _avatarView.hidden = false;
    
    if (_avatarUrl != nil)
    {
        _avatarView.fadeTransitionDuration = animated ? 0.14 : 0.3;
        if (![_avatarUrl isEqualToString:_avatarView.currentUrl])
        {
            if (animated)
            {
                UIImage *currentImage = [_avatarView currentImage];
                [_avatarView loadImage:_avatarUrl filter:@"avatar40" placeholder:(currentImage != nil ? currentImage : (_isChat ? [_assetsSource smallGroupAvatarPlaceholderGeneric] : [_assetsSource smallAvatarPlaceholderGeneric])) forceFade:true];
            }
            else
                [_avatarView loadImage:_avatarUrl filter:@"avatar40" placeholder:(_isChat ? [_assetsSource smallGroupAvatarPlaceholderGeneric] : [_assetsSource smallAvatarPlaceholderGeneric])];
        }
    }
    else
    {
        [_avatarView loadImage:(_isChat ? [_assetsSource smallGroupAvatarPlaceholder:_conversationId] : [_assetsSource smallAvatarPlaceholder:_isEncrypted ? _encryptedUserId : (int)_conversationId])];
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGRect frame = self.selectedBackgroundView.frame;
    frame.origin.y = true ? -1 : 0;
    frame.size.height = self.frame.size.height + (true ? 1 : 0);
    self.selectedBackgroundView.frame = frame;
    
    CGSize viewSize = self.contentView.frame.size;
    
    const int leftPadding = 0;
    
    int avatarWidth = 5 + 40;
    
    CGSize titleSizeGeneric = CGSizeMake(viewSize.width - avatarWidth - 9 - 5 - leftPadding, _titleLabelFirst.font.lineHeight);
    
    CGSize subtitleSize = CGSizeMake(viewSize.width - avatarWidth - 9 - 5 - leftPadding, _subtitleLabel.font.lineHeight);
    
    CGRect avatarFrame = CGRectMake(leftPadding + 5, 5, 40, 40);
    if (!CGRectEqualToRect(_avatarView.frame, avatarFrame))
    {
        _avatarView.frame = avatarFrame;
    }
    int titleLabelsY = 0;
    
    if (_subtitleLabel.hidden)
    {
        titleLabelsY = (int)((int)((viewSize.height - titleSizeGeneric.height) / 2) - 1);
    }
    else
    {
        titleLabelsY = (int)((viewSize.height - titleSizeGeneric.height - subtitleSize.height - 1) / 2);
        
        _subtitleLabel.frame = CGRectMake(avatarWidth + 9 + leftPadding + 1, titleLabelsY + titleSizeGeneric.height, subtitleSize.width, subtitleSize.height);
    }
    
    if (!_titleLabelFirst.hidden)
    {
        _titleLabelFirst.frame = CGRectMake(avatarWidth + 9 + leftPadding, titleLabelsY, titleSizeGeneric.width, titleSizeGeneric.height);
        _titleLabelSecond.frame = CGRectMake(avatarWidth + 9 + leftPadding + 5 + (int)([_titleLabelFirst.text sizeWithFont:_titleLabelFirst.font].width), titleLabelsY, titleSizeGeneric.width, titleSizeGeneric.height);
    }
    else
    {
        _titleLabelSecond.frame = CGRectMake(avatarWidth + 9 + leftPadding, titleLabelsY, titleSizeGeneric.width, titleSizeGeneric.height);
    }
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];
    
    if (selected)
    {
        CGRect frame = self.selectedBackgroundView.frame;
        frame.origin.y = true ? -1 : 0;
        frame.size.height = self.frame.size.height + (true ? 1 : 0);
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
        frame.size.height = self.frame.size.height + (true ? 1 : 0);
        self.selectedBackgroundView.frame = frame;
        
        [self adjustOrdering];
    }
}

- (void)adjustOrdering
{
    if ([self.superview isKindOfClass:[UITableView class]])
    {
        Class UITableViewCellClass = [UITableViewCell class];
        int maxCellIndex = 0;
        int index = -1;
        int selfIndex = 0;
        for (UIView *view in self.superview.subviews)
        {
            index++;
            if ([view isKindOfClass:UITableViewCellClass])
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

@end
