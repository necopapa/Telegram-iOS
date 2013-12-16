#import "TGConversationItemView.h"

@interface TGConversationItemView ()

@end

@implementation TGConversationItemView

#if TGUseCollectionView
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
#else
- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
#endif
    if (self)
    {
#if TGUseCollectionView

#else
        self.selectionStyle = UITableViewCellSelectionStyleNone;
#endif
        
        [self setTransform:CGAffineTransformMakeRotation((float)M_PI)];
        
        self.backgroundColor = nil;
        self.opaque = false;
    }
    return self;
}

#if TGUseCollectionView
- (void)setEditing:(BOOL)editing animated:(BOOL)__unused animated;
{
    _editing = editing;
}
#endif

@end
