#import "TGMessagesCollectionLayout.h"

#if TGUseCollectionView

#include <vector>

@interface TGMessagesCollectionLayout ()

@property (nonatomic) CGSize contentSize;
@property (nonatomic) CGRect currentBounds;

@end

@implementation TGMessagesCollectionLayout
{
    std::vector<__strong UICollectionViewLayoutAttributes *> _itemsLayoutAttributes;
}

- (id)init
{
    self = [super init];
    if (self != nil)
    {
        
    }
    return self;
}

- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds
{
    if (!CGRectEqualToRect(newBounds, _currentBounds))
    {
        _currentBounds = newBounds;

        return true;
    }
    return false;
}

- (CGSize)collectionViewContentSize
{
    return _contentSize;
}

- (NSArray *)layoutAttributesForElementsInRect:(CGRect)rect
{
    NSMutableArray *array = [[NSMutableArray alloc] init];
    
    return array;
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSUInteger itemIndex = indexPath.item;
    if (itemIndex < _itemsLayoutAttributes.size())
        return _itemsLayoutAttributes[itemIndex];
    
    return nil;
}

- (void)invalidateLayout
{
    [self _invalidateLayout];
    
    [super invalidateLayout];
}

- (void)invalidateLayoutWithContext:(UICollectionViewLayoutInvalidationContext *)context
{
    [self _invalidateLayout];
    
    [super invalidateLayoutWithContext:context];
}

- (void)_invalidateLayout
{
    
}

@end

#endif
