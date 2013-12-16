#import "HPTextViewInternal.h"

#import "HPGrowingTextView.h"

@implementation HPTextViewInternal

@synthesize freezeContentOffset = _freezeContentOffset;
@synthesize disableContentOffsetAnimation = _disableContentOffsetAnimation;

@synthesize handleEditActions = _handleEditActions;

@synthesize responderStateDelegate = _responderStateDelegate;

- (void)setContentOffset:(CGPoint)contentOffset animated:(BOOL)animated
{
    if (_freezeContentOffset)
        return;
    
    [super setContentOffset:contentOffset animated:_disableContentOffsetAnimation ? false : animated];
}

-(void)setContentOffset:(CGPoint)contentOffset
{
    if (_freezeContentOffset)
        return;
    
    if (self.tracking || self.decelerating)
    {
		//initiated by user...
        
        UIEdgeInsets insets = self.contentInset;
        insets.bottom = 0;
        insets.top = 0;
        self.contentInset = insets;
	}
    else
    {
		float bottomOffset = (self.contentSize.height - self.frame.size.height + self.contentInset.bottom);
		if (contentOffset.y < bottomOffset && self.scrollEnabled)
        {
            UIEdgeInsets insets = self.contentInset;
            insets.bottom = 8;
            insets.top = 0;
            self.contentInset = insets;
        }
	}
    
    [super setContentOffset:contentOffset];
}

-(void)setContentInset:(UIEdgeInsets)s
{
	UIEdgeInsets insets = s;
	
	if(s.bottom>8) insets.bottom = 0;
	insets.top = 0;

	[super setContentInset:insets];
}

-(void)setContentSize:(CGSize)contentSize
{
    // is this an iOS5 bug? Need testing!
    if(self.contentSize.height > contentSize.height)
    {
        UIEdgeInsets insets = self.contentInset;
        insets.bottom = 0;
        insets.top = 0;
        self.contentInset = insets;
    }
    
    [super setContentSize:contentSize];
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender
{
    if (!self.handleEditActions)
        return false;
    bool result = [super canPerformAction:action withSender:sender];
    if (action == @selector(paste:))
        result = true;
    return result;
}

- (BOOL)becomeFirstResponder
{
    BOOL result = [super becomeFirstResponder];
    if (result)
    {
        id delegate = [[_responderStateDelegate.object retain] autorelease];
        if (delegate != nil && [delegate conformsToProtocol:@protocol(HPTextViewInternalDelegate)])
        {
            [(id<HPTextViewInternalDelegate>)delegate hpTextViewChangedResponderState:true];
        }
    }
    return result;
}

- (BOOL)resignFirstResponder
{
    BOOL result = [super resignFirstResponder];
    if (result)
    {
        id delegate = [[_responderStateDelegate.object retain] autorelease];
        if (delegate != nil && [delegate conformsToProtocol:@protocol(HPTextViewInternalDelegate)])
        {
            [(id<HPTextViewInternalDelegate>)delegate hpTextViewChangedResponderState:false];
        }
    }
    return result;
}

- (void)dealloc
{
    if (_responderStateDelegate != nil)
    {
        [_responderStateDelegate release];
        _responderStateDelegate = nil;
    }
    [super dealloc];
}

- (void)paste:(id)sender
{
    UIPasteboard *pasteBoard = [UIPasteboard generalPasteboard];
    
    NSMutableArray *images = [NSMutableArray arrayWithCapacity:1];
    
    if (pasteBoard.images.count != 0)
    {
        for (id object in pasteBoard.images)
        {
            if ([object isKindOfClass:[UIImage class]])
                [images addObject:object];
        }
    }
    else if (pasteBoard.image != nil)
    {
        if ([pasteBoard.image isKindOfClass:[UIImage class]])
            [images addObject:pasteBoard.image];
    }
    
    if (images.count != 0)
    {
        id delegate = self.delegate;
        if ([delegate isKindOfClass:[HPGrowingTextView class]])
        {
            HPGrowingTextView *textView = delegate;
            NSObject<HPGrowingTextViewDelegate> *textViewDelegate = (NSObject<HPGrowingTextViewDelegate> *)textView.delegate;
            if ([textViewDelegate respondsToSelector:@selector(growingTextView:didPasteImages:)])
                [textViewDelegate growingTextView:textView didPasteImages:images];
        }
    }
    else
        [super paste:sender];
}

@end
