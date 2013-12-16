#import "TGImageSearchQueryCell.h"

@interface TGImageSearchQueryCell ()

@property (nonatomic, strong) UILabel *label;

@end

@implementation TGImageSearchQueryCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self)
    {
        static UIImage *cellImage = nil;
        if (cellImage == nil)
            cellImage = [[UIImage imageNamed:@"Cell96_Light.png"] stretchableImageWithLeftCapWidth:0 topCapHeight:1];
        
        static UIImage *selectedCellImage = nil;
        if (selectedCellImage == nil)
            selectedCellImage = [UIImage imageNamed:@"CellHighlighted96.png"];
        
        self.backgroundView = [[UIImageView alloc] initWithImage:cellImage];
        self.selectedBackgroundView = [[UIImageView alloc] initWithImage:selectedCellImage];
        
        _label = [[UILabel alloc] initWithFrame:CGRectMake(8, 10, self.contentView.frame.size.width - 16, 22)];
        _label.contentMode = UIViewContentModeLeft;
        _label.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _label.font = [UIFont boldSystemFontOfSize:18];
        _label.backgroundColor = [UIColor clearColor];
        _label.textColor = [UIColor blackColor];
        _label.highlightedTextColor = [UIColor whiteColor];
        [self.contentView addSubview:_label];
    }
    return self;
}

- (void)setQueryText:(NSString *)queryText
{
    _label.text = queryText;
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
            if ([view isKindOfClass:UITableViewCellClass] || [view isKindOfClass:UISearchBarClass] || view.tag == 0x33FC2014)
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
