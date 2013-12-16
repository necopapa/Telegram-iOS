#import "TGMessagesCollectionView.h"

@implementation TGMessagesCollectionView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
    }
    return self;
}

- (void)setScrollInsets:(UIEdgeInsets)scrollInsets
{
    [super setScrollIndicatorInsets:scrollInsets];
}

- (UIEdgeInsets)scrollInsets
{
    return [super scrollIndicatorInsets];
}

- (void)setEditing:(bool)editing animated:(BOOL)__unused animated
{
    _isEditing = editing;
}

@end
