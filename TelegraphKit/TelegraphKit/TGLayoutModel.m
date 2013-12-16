#import "TGLayoutModel.h"

#import "TGLayoutTextItem.h"
#import "TGLayoutImageItem.h"
#import "TGLayoutRemoteImageItem.h"
#import "TGLayoutSimpleLabelItem.h"
#import "TGLayoutButtonItem.h"

#import "TGRemoteImageView.h"
#import "TGReusableLabel.h"
#import "TGImageView.h"
#import "TGSimpleReusableLabel.h"
#import "TGReusableActivityIndicatorView.h"
#import "TGReusableButton.h"

@interface TGLayoutModel ()

@end

@implementation TGLayoutModel

- (id)init
{
    self = [super init];
    if (self != nil)
    {
        _items = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)addLayoutItem:(TGLayoutItem *)item
{
    [_items addObject:item];
}

- (void)inflateLayoutToView:(UIView *)view viewRecycler:(TGViewRecycler *)viewRecycler actionTarget:(id)actionTarget
{
    for (TGLayoutItem *item in _items)
    {
        int itemType = item.type;
        
        if (itemType == TGLayoutItemTypeText)
        {
            TGLayoutTextItem *textItem = (TGLayoutTextItem *)item;
            if (textItem.manualDrawing)
                continue;
            
            static NSString *reusableLabelIdentifier = @"RL";
            TGReusableLabel *label = (TGReusableLabel *)[viewRecycler dequeueReusableViewWithIdentifier:reusableLabelIdentifier];
            if (label == nil)
            {
                label = [[TGReusableLabel alloc] init];
                label.reuseIdentifier = reusableLabelIdentifier;
                label.backgroundColor = [UIColor clearColor];
                label.highlightedTextColor = [UIColor whiteColor];
            }
            label.hidden = false;
            label.richText = textItem.richText;
            if (textItem.richText)
                label.precalculatedLayout = textItem.precalculatedLayout;
            label.tag = item.tag;
            label.frame = textItem.frame;
            label.font = textItem.font;
            label.textColor = textItem.textColor;
            label.shadowColor = textItem.shadowColor;
            label.highlightedShadowColor = textItem.highlightedShadowColor;
            label.shadowOffset = textItem.shadowOffset;
            label.numberOfLines = textItem.numberOfLines;
            label.textAlignment = textItem.textAlignment;
            label.text = textItem.text;
            [view addSubview:label];
            [label setNeedsDisplay];
        }
        else if (itemType == TGLayoutItemTypeImage)
        {
            TGLayoutImageItem *imageItem = (TGLayoutImageItem *)item;
            if (imageItem.manualDrawing)
                continue;
            
            static NSString *localImageViewIdentifier = @"LIV";
            TGImageView *imageView = (TGImageView *)[viewRecycler dequeueReusableViewWithIdentifier:localImageViewIdentifier];
            if (imageView == nil)
            {
                imageView = [[TGImageView alloc] init];
                imageView.reuseIdentifier = localImageViewIdentifier;
            }
            
            imageView.tag = imageItem.tag;
            imageView.image = imageItem.image;
            imageView.hidden = false;
            imageView.alpha = 1.0f;
            imageView.frame = imageItem.frame;
            
            [view addSubview:imageView];
        }
        else if (itemType == TGLayoutItemTypeRemoteImage)
        {
            TGLayoutRemoteImageItem *remoteImageItem = (TGLayoutRemoteImageItem *)item;
            
            static NSString *remoteImageViewIdentifier = @"RIV";
            TGRemoteImageView *remoteImageView = (TGRemoteImageView *)[viewRecycler dequeueReusableViewWithIdentifier:remoteImageViewIdentifier];
            if (remoteImageView == nil)
            {
                remoteImageView = [[TGRemoteImageView alloc] initWithFrame:CGRectZero];
                remoteImageView.reuseIdentifier = remoteImageViewIdentifier;
                remoteImageView.fadeTransition = true;
                remoteImageView.fadeTransitionDuration = 0.2;
            }
            remoteImageView.hidden = false;
            remoteImageView.alpha = 1.0f;
            remoteImageView.tag = item.tag;
            remoteImageView.frame = remoteImageItem.frame;
            remoteImageView.allowThumbnailCache = remoteImageItem.filter == nil;
            
            if (remoteImageItem.placeholderOverlay != nil)
            {
                static NSString *localImageViewIdentifier = @"LIV";
                
                TGImageView *overlayImageView = (TGImageView *)[viewRecycler dequeueReusableViewWithIdentifier:localImageViewIdentifier];
                if (overlayImageView == nil)
                {
                    overlayImageView = [[TGImageView alloc] init];
                    overlayImageView.reuseIdentifier = localImageViewIdentifier;
                }
                
                overlayImageView.image = remoteImageItem.placeholderOverlay;
                remoteImageView.placeholderOverlay = overlayImageView;
                remoteImageView.placeholderOverlay.frame = remoteImageItem.placeholderOverlayFrame;
            }
            else if (remoteImageItem.placeholderOverlayIsProgress)
            {
                static NSString *activityViewIdentifier = @"ACTV";
                
                TGReusableActivityIndicatorView *activityIndicator = (TGReusableActivityIndicatorView *)[viewRecycler dequeueReusableViewWithIdentifier:activityViewIdentifier];
                if (activityIndicator == nil)
                {
                    activityIndicator = [[TGReusableActivityIndicatorView alloc] init];
                    activityIndicator.reuseIdentifier = activityViewIdentifier;
                }
                
                remoteImageView.placeholderOverlay = activityIndicator;
                activityIndicator.center = remoteImageItem.placeholderOverlayProgressCenter;
                
                [activityIndicator startAnimating];
            }
            
            if (remoteImageItem.url != nil)
                [remoteImageView loadImage:remoteImageItem.url filter:remoteImageItem.filter placeholder:remoteImageItem.placeholder];
            else
                [remoteImageView loadImage:remoteImageItem.placeholder];
            [view addSubview:remoteImageView];
        }
        else if (itemType == TGLayoutItemTypeSimpleLabel)
        {
            TGLayoutSimpleLabelItem *labelItem = (TGLayoutSimpleLabelItem *)item;
            
            static NSString *simpleLabelItemIdentifier = @"SLI";
            TGSimpleReusableLabel *labelView = (TGSimpleReusableLabel *)[viewRecycler dequeueReusableViewWithIdentifier:simpleLabelItemIdentifier];
            if (labelView == nil)
            {
                labelView = [[TGSimpleReusableLabel alloc] init];
                labelView.reuseIdentifier = simpleLabelItemIdentifier;
            }
            
            labelView.hidden = false;
            labelView.alpha = 1.0f;
            labelView.tag = labelItem.tag;
            labelView.frame = labelItem.frame;
            labelView.font = labelItem.font;
            labelView.textColor = labelItem.textColor;
            labelView.backgroundColor = labelItem.backgroundColor;
            labelView.textAlignment = labelItem.textAlignment;
            labelView.text = labelItem.text;
            
            [view addSubview:labelView];
        }
        else if (itemType == TGLayoutItemTypeButton)
        {
            TGLayoutButtonItem *buttonItem = (TGLayoutButtonItem *)item;
            
            static NSString *buttonItemIdentifier = @"LBI";
            TGReusableButton *buttonView = (TGReusableButton *)[viewRecycler dequeueReusableViewWithIdentifier:buttonItemIdentifier];
            if (buttonView == nil)
            {
                buttonView = [[TGReusableButton alloc] init];
                buttonView.reuseIdentifier = buttonItemIdentifier;
            }
            
            buttonView.hidden = false;
            buttonView.alpha = 1.0f;
            buttonView.tag = buttonItem.tag;
            buttonView.frame = buttonItem.frame;
            
            [buttonView setTitle:buttonItem.title forState:UIControlStateNormal];
            [buttonView setTitleColor:buttonItem.titleColor forState:UIControlStateNormal];
            [buttonView setTitleColor:buttonItem.titleHighlightedColor forState:UIControlStateHighlighted];
            [buttonView setTitleShadowColor:buttonItem.titleShadow forState:UIControlStateNormal];
            [buttonView setTitleShadowColor:buttonItem.titleHighlightedShadow forState:UIControlStateHighlighted];
            [buttonView setBackgroundImage:buttonItem.backgroundImage forState:UIControlStateNormal];
            [buttonView setBackgroundImage:buttonItem.backgroundHighlightedImage forState:UIControlStateHighlighted];
            buttonView.titleLabel.font = buttonItem.titleFont;
            buttonView.titleLabel.shadowOffset = buttonItem.titleShadowOffset;
            
            [buttonView removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
            [buttonView addTarget:actionTarget action:@selector(layoutButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
            
            [view addSubview:buttonView];
        }
    }
}

- (void)updateLayoutInView:(UIView *)view
{
    for (TGLayoutItem *item in _items)
    {
        if (item.tag == 0)
            continue;
        
        if (item.type == TGLayoutItemTypeText)
        {
            TGLayoutTextItem *textItem = (TGLayoutTextItem *)item;
            if (textItem.manualDrawing)
                continue;
            
            UIView *itemView = (UIView *)[view viewWithTag:textItem.tag];
            if (textItem.richText && [itemView isKindOfClass:[TGReusableLabel class]])
            {
                ((TGReusableLabel *)itemView).precalculatedLayout = textItem.precalculatedLayout;
            }
            itemView.frame = textItem.frame;
        }
        else if (item.type == TGLayoutItemTypeImage)
        {
            TGLayoutImageItem *imageItem = (TGLayoutImageItem *)item;
            if (imageItem.manualDrawing)
                continue;
            
            UIView *itemView = (UIView *)[view viewWithTag:imageItem.tag];
            itemView.frame = imageItem.frame;
        }
        else if (item.type == TGLayoutItemTypeRemoteImage)
        {
            TGLayoutRemoteImageItem *remoteImageItem = (TGLayoutRemoteImageItem *)item;
            UIView *itemView = (UIView *)[view viewWithTag:remoteImageItem.tag];
            itemView.frame = remoteImageItem.frame;
        }
        else if (item.type == TGLayoutItemTypeSimpleLabel)
        {
            UIView *itemView = (UIView *)[view viewWithTag:item.tag];
            itemView.frame = item.frame;
        }
        else if (item.type == TGLayoutItemTypeButton)
        {
            UIView *itemView = (UIView *)[view viewWithTag:item.tag];
            itemView.frame = item.frame;
        }
    }
}

- (void)drawLayout:(bool)highlighted
{
    for (TGLayoutItem *item in _items)
    {
        if (item.type == TGLayoutItemTypeText)
        {
            TGLayoutTextItem *textItem = (TGLayoutTextItem *)item;
            if (!textItem.manualDrawing)
                continue;
            
            if (textItem.richText)
            {
                [TGReusableLabel drawRichTextInRect:textItem.frame precalculatedLayout:textItem.precalculatedLayout linesRange:NSMakeRange(0, 0) shadowColor:textItem.shadowColor shadowOffset:textItem.shadowOffset];
            }
            else
            {
                [TGReusableLabel drawTextInRect:textItem.frame text:textItem.text richText:textItem.richText font:textItem.font highlighted:highlighted textColor:textItem.textColor highlightedColor:textItem.highlightedTextColor shadowColor:textItem.shadowColor shadowOffset:textItem.shadowOffset numberOfLines:textItem.numberOfLines];
            }
        }
        else if (item.type == TGLayoutItemTypeImage)
        {
            TGLayoutImageItem *imageItem = (TGLayoutImageItem *)item;
            if (!imageItem.manualDrawing)
                continue;
            
            [imageItem.image drawInRect:imageItem.frame blendMode:kCGBlendModeCopy alpha:1.0f];
        }
    }
}

- (NSString *)linkAtPoint:(CGPoint)point topRegion:(CGRect *)topRegion middleRegion:(CGRect *)middleRegion bottomRegion:(CGRect *)bottomRegion
{
    for (TGLayoutItem *item in _items)
    {
        if (item.type == TGLayoutItemTypeText)
        {
            TGLayoutTextItem *textItem = (TGLayoutTextItem *)item;
            if (CGRectContainsPoint(textItem.frame, point))
            {
                NSString *url = [textItem.precalculatedLayout linkAtPoint:CGPointMake(point.x - textItem.frame.origin.x, point.y - textItem.frame.origin.y) topRegion:topRegion middleRegion:middleRegion bottomRegion:bottomRegion];
                if (url != nil)
                    return url;
            }
        }
    }
    
    return nil;
}

- (TGLayoutItem *)itemAtPoint:(CGPoint)point
{
    for (TGLayoutItem *item in _items.reverseObjectEnumerator)
    {
        if (CGRectContainsPoint(item.frame, point) && item.userInteractionEnabled)
        {
            return item;
        }
    }
    
    return nil;
}

@end
