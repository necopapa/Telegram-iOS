#import "TGConversationController.h"

#import "TGHacks.h"

#import "TGUser.h"

#import "TGStringUtils.h"
#import "TGDateUtils.h"

#import "TGDatabase.h"

#import "TGImageUtils.h"
#import "TGRemoteImageView.h"
#import "TGLabel.h"
#import "TGTableView.h"
#import "TGReusableLabel.h"
#import "TGPagerView.h"
#import "TGToolbarButton.h"
#import "TGImageView.h"

#import "HPGrowingTextView.h"
#import "TGTextInputView.h"

#import "TGMessagesCollectionView.h"

#import "TGConversationMessageItem.h"
#import "TGConversationDateItem.h"
#import "TGConversationUnreadItem.h"

#import "TGConversationMessageItemView.h"
#import "TGConversationDateItemView.h"
#import "TGConversationUnreadItemView.h"

#import "TGImageInputMediaAttachment.h"
#import "TGLocationInputMediaAttachment.h"

#import "TGMessageDateTooltipView.h"

#import "TGImageViewController.h"
#import "TGNavigationController.h"
#import "TGMapViewController.h"
#import "TGWebController.h"

#import "TGImageSearchController.h"

#import "TGDelegateProxy.h"

#import "TGConversationAсtionsPanel.h"

#import "TGActivityIndicatorView.h"

#import "TGImagePickerController.h"

#import "TGProgressWindow.h"

#import "TGSwipeGestureRecognizer.h"

#import "TGMenuView.h"

#import <QuartzCore/QuartzCore.h>

#import <MobileCoreServices/MobileCoreServices.h>

#import "TGObserverProxy.h"

#import "TGAlertDelegateProxy.h"
#import "TGProgressWindow.h"

#import <vector>
#import <set>

#import <AVFoundation/AVFoundation.h>
#import <CommonCrypto/CommonDigest.h>

__strong id<TGConversationMessageAssetsSource> TGGlobalAssetsSource = nil;

static TGViewRecycler *sharedViewRecycler = nil;

#ifdef DEBUG
static int aliveControllerCount = 0;
#endif

#define InputContainerBackgroundTag ((int)0xE07F44A9)
#define InputContainerShadowTag ((int)0xAFC27048)
#define InputContainerOverlayBackgroundTag ((int)0x8FC6AEC2)

#define TGMessageWarningAlertTag ((int)0x2FB9D541)
#define TGPasteImagesAlertTag ((int)0x1749FA1)

#define TGDotInterval 0.12
#define TGDotPeriod 0.45

#define TGInputFieldClass HPGrowingTextView
//#define TGInputFieldClass TGTextInputView
#define TGInputFieldClassIsHP true

static int64_t lastConversationIdForBackAction = 0;

static UIImage *buttonTextImage(NSString *text)
{
    UIFont *font = [UIFont boldSystemFontOfSize:12];
    CGSize size = [text sizeWithFont:font];
    size.width = (int)size.width + 2;
    UIGraphicsBeginImageContextWithOptions(size, false, 0.0f);
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetShadowWithColor(context, CGSizeMake(0, 1), 2.0f, UIColorRGBA(0x000000, 0.3f).CGColor);
    CGContextSetFillColorWithColor(context, UIColorRGBA(0xffffff, 1.0f).CGColor);
    
    [text drawInRect:CGRectMake(1, 0, size.width, size.height) withFont:font];
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

static NSString *encodeText(NSString *string, int key)
{
    NSMutableString *result = [[NSMutableString alloc] init];
    
    for (int i = 0; i < [string length]; i++)
    {
        unichar c = [string characterAtIndex:i];
        c += key;
        [result appendString:[NSString stringWithCharacters:&c length:1]];
    }
    
    return result;
}

static UIWindow *findKeyboardWindow()
{
    static NSString *str1 = nil;
    static NSString *str2 = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        str1 = encodeText(@"=VJQfsjqifsbmIptuWjfx", -1);
        str2 = encodeText(@"=VJLfzcpbse", -1);
    });
    
    static int lastKeyboardIndex = -1;
    static int64_t lastWindowPtr = 0;
    static int64_t lastKeyboardPtr = 0;
    Class UIWindowClass = [UIWindow class];
    
    for (UIWindow *window in [[UIApplication sharedApplication] windows])
    {
        if (lastWindowPtr == (int64_t)window)
        {
            //TGLog(@"very optimized get");
            return window;
        }
        
        if (![[window class] isEqual:UIWindowClass])
        {
            NSArray *subviews = window.subviews;
            if (lastKeyboardIndex >= 0 && lastKeyboardIndex < subviews.count)
            {
                UIView *possibleKeyboard = [subviews objectAtIndex:lastKeyboardIndex];
                if (lastKeyboardPtr == (int64_t)possibleKeyboard)
                {
                    //TGLog(@"optimized get");
                    return window;
                }
                
                if ([[possibleKeyboard description] hasPrefix:str1])
                {
                    for (UIView *subview in possibleKeyboard.subviews)
                    {
                        if ([[subview description] hasPrefix:str2])
                        {
                            //TGLog(@"less optimized get");
                            lastKeyboardPtr = (int64_t)possibleKeyboard;
                            lastWindowPtr = (int64_t)window;
                            return window;
                        }
                    }
                }
            }
            
            int index = -1;
            for (UIView *view in subviews)
            {
                index++;
                UIView *possibleKeyboard = view;
                
                if ([[possibleKeyboard description] hasPrefix:str1])
                {
                    for (UIView *subview in possibleKeyboard.subviews)
                    {
                        if ([[subview description] hasPrefix:str2])
                        {
                            lastKeyboardIndex = index;
                            lastKeyboardPtr = (int64_t)possibleKeyboard;
                            lastWindowPtr = (int64_t)window;
                            return window;
                        }
                    }
                }
            }
        }
    }
    
    return nil;
}

@interface TGConversationButtonContainer : UIView <TGBarItemSemantics>

@property (nonatomic) bool backSemantics;

@end

@implementation TGConversationButtonContainer

- (float)barButtonsOffset
{
    return (_backSemantics ? 0 : 4);
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    if (!CGRectContainsPoint(self.bounds, point))
    {
        if (!_backSemantics && point.x > -14)
        {
            for (UIView *subview in self.subviews)
            {
                CGRect frame = subview.frame;
                UIView *result = [subview hitTest:CGPointMake(point.x - frame.origin.x, point.y - frame.origin.y) withEvent:event];
                if (result != nil && result.alpha > FLT_EPSILON && !result.hidden)
                    return result;
            }
        }
        else if (_backSemantics)
        {
            for (UIView *subview in self.subviews)
            {
                CGRect frame = subview.frame;
                UIView *result = [subview hitTest:CGPointMake(point.x - frame.origin.x, point.y - frame.origin.y) withEvent:event];
                if (result != nil && result.alpha > FLT_EPSILON && !result.hidden)
                    return result;
            }
        }
        return nil;
    }

    return [super hitTest:point withEvent:event];
}

@end

@interface TGConversationInputContainerView : UIView

@property (nonatomic, strong) UIImageView *backgroundImageView;
@property (nonatomic) bool controlBackground;
@property (nonatomic, strong) UIView *hitView;

@end

@implementation TGConversationInputContainerView

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
 
    if (_backgroundImageView != nil && _controlBackground)
    {
        [_backgroundImageView.layer removeAnimationForKey:@"position.y"];
        UIView *view = self.superview;
        float fullHeight = self.frame.size.width > 400 ? 160 : 210;
        float superviewOffset = 20 + (view.frame.size.height > 400 ? 44 : 32);
        _backgroundImageView.frame = CGRectMake(0, superviewOffset - 20 + MIN(1.0f, ABS(((frame.origin.y + frame.size.height) - view.frame.size.height)) / fullHeight) * (-60.0f), view.frame.size.width, view.frame.size.height - 43 + 40 - superviewOffset);
    }
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    if (_hitView != nil && CGRectContainsPoint(_hitView.frame, point))
        return _hitView;
    
    return [super hitTest:point withEvent:event];
}

@end

@interface TGConversationBackgroundView : UIImageView

@end

@implementation TGConversationBackgroundView

/*- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    
    TGLog(@"%@", NSStringFromCGRect(frame));
}*/

@end

#pragma mark -

const int TGConversationControllerMessageDialogTag = 10001;
const int TGConversationControllerLinkOptionsDialogTag = 10002;
const int TGConversationControllerAttachmentDialogTag = 10003;
const int TGConversationControllerClearConvfirmationDialogTag = 10004;
const int TGConversationControllerPhoneNumberDialogTag = 10005;

@interface TGConversationController () <HPGrowingTextViewDelegate, ASWatcher, UIActionSheetDelegate, HPTextViewInternalDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIGestureRecognizerDelegate, TGNavigationControllerItem, TGImagePickerControllerDelegate, UIAlertViewDelegate,
#if TGUseCollectionView
UICollectionViewDelegateFlowLayout, UICollectionViewDataSource
#else
UITableViewDelegate, UITableViewDataSource
#endif
>
{
    std::set<int> _checkedMessages;
    
    std::tr1::shared_ptr<std::map<int, float> > _pMessageUploadProgress;
}

@property (nonatomic, strong) TGWeakDelegate *weakDelegate;

@property (nonatomic, strong) TGProgressWindow *progressWindow;

@property (nonatomic, strong) TGObserverProxy *proxyDidEnterBackground;
@property (nonatomic, strong) TGObserverProxy *proxyWillEnterForeground;
@property (nonatomic, strong) TGObserverProxy *proxyDidBecomeActive;

@property (nonatomic, strong) TGObserverProxy *proxyDidBecomeActiveSecure;
@property (nonatomic, strong) TGObserverProxy *proxyWillResignActiveSecure;

@property (nonatomic, strong) TGObserverProxy *proxyKeyboardWillShow;
@property (nonatomic, strong) TGObserverProxy *proxyKeyboardWillHide;
@property (nonatomic, strong) TGObserverProxy *proxyKeyboardDidShow;
@property (nonatomic, strong) TGObserverProxy *proxyKeyboardDidHide;

@property (nonatomic) bool appearingAnimation;
@property (nonatomic) NSTimeInterval appearingAnimationStart;
@property (nonatomic) bool onceLoadedMore;

@property (nonatomic) bool disappearingAnimation;

@property (nonatomic) bool onceShownMessageWarning;

@property (nonatomic, strong) NSMutableArray *preparedCellQueue;
@property (nonatomic, strong) NSString *initialMessageText;

@property (nonatomic, strong) UIView *titleContainer;
@property (nonatomic, strong) UIView *titleLabelsContainer;
@property (nonatomic, strong) UIImageView *titleLockIcon;
@property (nonatomic, strong) UIView *titleLifetimeContainer;
@property (nonatomic, strong) UILabel *titleLifetimeLabel;
@property (nonatomic, strong) TGLabel *titleTextLabel;
@property (nonatomic, strong) TGLabel *titleStatusLabelNormal;
@property (nonatomic, strong) TGLabel *titleStatusLabelTyping;
@property (nonatomic, strong) NSString *titleStatusLabelNormalText;
@property (nonatomic, strong) NSString *titleStatusLabelTypingText;
@property (nonatomic, strong) NSArray *typingDots;
@property (nonatomic, strong) NSTimer *typingDotsShortTimer;
@property (nonatomic, strong) NSTimer *typingDotsIntervalTimer;
@property (nonatomic) int currentTypingDot;

@property (nonatomic, strong) UIView *unreadCountContainer;
@property (nonatomic, strong) UIImageView *unreadCountBadge;
@property (nonatomic, strong) UILabel *unreadCountLabel;

@property (nonatomic) bool disableTitleArrow;
@property (nonatomic, strong) UIImageView *muteIconView;

@property (nonatomic, strong) TGRemoteImageView *avatarImageView;
@property (nonatomic, strong) UIImageView *avatarOverlayView;

@property (nonatomic, strong) TGConversationActionsPanel *actionsPanel;

@property (nonatomic, strong) UIImageView *backgroundImageView;
@property (nonatomic) bool ignoreBackgroundImageViewScroll;

@property (nonatomic, strong) UIButton *incomingMessagesButton;

@property (nonatomic) NSTimeInterval lastSwipeActionTime;
@property (nonatomic) NSTimeInterval lastMenuShowTime;
@property (nonatomic) NSTimeInterval lastMenuHideTime;

@property (nonatomic) int baseInputContainerHeight;

@property (nonatomic) int actionBarHeight;

@property (nonatomic, strong) TGConversationInputContainerView *inputContainer;
@property (nonatomic, strong) UIButton *attachButton;
@property (nonatomic, strong) UIImageView *attachButtonArrow;
@property (nonatomic, strong) UIButton *sendButton;
@property (nonatomic, strong) UIView *inputFieldWhiteBackground;
@property (nonatomic, strong) UIImageView *inputFieldBackground;
@property (nonatomic, strong) TGInputFieldClass *inputField;
@property (nonatomic, strong) UILabel *fakeInputFieldLabel;
@property (nonatomic, strong) UILabel *placeholderLabel;

@property (nonatomic, strong) TGToolbarButton *backButton;
@property (nonatomic, strong) TGToolbarButton *clearAllButton;
@property (nonatomic, strong) TGToolbarButton *doneButton;

@property (nonatomic, strong) UIView *editingContainer;

@property (nonatomic, strong) UIButton *editingDeleteButton;
@property (nonatomic, strong) UILabel *editingDeleteButtonLabel;
@property (nonatomic, strong) UIImageView *editingDeleteButtonIcon;

@property (nonatomic, strong) UIButton *editingForwardButton;
@property (nonatomic, strong) UILabel *editingForwardButtonLabel;
@property (nonatomic, strong) UIImageView *editingForwardButtonIcon;

@property (nonatomic, strong) UIView *editingRequestContainer;
@property (nonatomic, strong) UIImageView *editingRequestBackground;

@property (nonatomic, strong) UIButton *editingRequestButton;
@property (nonatomic, strong) UIButton *editingUnblockButton;
@property (nonatomic, strong) UIButton *editingBlockButton;
@property (nonatomic, strong) UIButton *editingAcceptButton;
@property (nonatomic, strong) UILabel *editingStateLabel;

@property (nonatomic) int messageMetrics;
@property (nonatomic, strong) TGViewRecycler *viewRecycler;

#if TGUseCollectionView
@property (nonatomic, strong) TGMessagesCollectionView *tableView;
@property (nonatomic, strong) UICollectionViewFlowLayout *flowLayout;
#else
@property (nonatomic, strong) TGTableView *tableView;
#endif

@property (nonatomic) int tableViewLastScrollPosition;
@property (nonatomic, strong) UIImageView *editingSeparatorBottom;

@property (nonatomic) bool swipeKeyboardOpen;

@property (nonatomic, strong) UIPanGestureRecognizer *viewPanRecognizer;
@property (nonatomic) bool dragKeyboardByInputContainer;
@property (nonatomic) bool dragKeyboardByTablePanning;
@property (nonatomic) int dragKeyboardByTablePanningStartPoint;
@property (nonatomic) int dragKeyboardByTablePanningStartOffset;
@property (nonatomic) int dragKeyboardByTablePanningPanPoint;

@property (nonatomic) bool disableMessageBackgroundDrawing;
@property (nonatomic) bool disableDownwardsHistoryLoading;

@property (nonatomic) bool isRotating;
@property (nonatomic) bool keyboardOpened;
@property (nonatomic) int knownKeyboardHeight;

@property (nonatomic) bool wantsKeyboardActive;

@property (nonatomic) bool tableNeedsReloading;
@property (nonatomic) bool shouldScrollDownOnNextUpdate;

@property (nonatomic) bool stopProcessingEverything;

@property (nonatomic, strong) NSMutableArray *listModel;
@property (nonatomic, strong) NSString *chatTitle;
@property (nonatomic, strong) NSString *chatSubtitle;
@property (nonatomic, strong) NSString *chatTypingSubtitle;
@property (nonatomic) bool isContact;
@property (nonatomic) TGConversationControllerSynchronizationState synchronizationStatus;
@property (nonatomic, strong) TGUser *chatSingleParticipant;
@property (nonatomic) bool canLoadMoreHistory;
@property (nonatomic) bool canLoadMoreHistoryProcessedAtLeastOnce;
@property (nonatomic) bool canLoadMoreHistoryDownwards;

@property (nonatomic) int messageDialogMid;
@property (nonatomic) bool messageDialogHasText;
@property (nonatomic, strong) NSString *messageDialogLink;
@property (nonatomic) int messageMenuMid;
@property (nonatomic) int messageMenuLocalMid;
@property (nonatomic) bool messageMenuIsAction;
@property (nonatomic) bool messageMenuHasText;

@property (nonatomic, strong) NSArray *actionSheetPhoneList;

@property (nonatomic) bool clearEditingOnDisappear;

@property (nonatomic, strong) NSTimer *delayTimer;
@property (nonatomic, strong) dispatch_block_t delayBlock;

@property (nonatomic) int conversationLink;

@property (nonatomic) int encryptionStatus;
@property (nonatomic) bool userBlocked;
@property (nonatomic) bool conversationMuted;

@property (nonatomic, strong) UIActionSheet *currentActionSheet;
@property (nonatomic, strong) NSDictionary *currentActionSheetMapping;

@property (nonatomic, strong) id assetsLibraryHolder;

@property (nonatomic) int unreadCount;

@property (nonatomic, strong) UIView *titleStatusContainer;
@property (nonatomic, strong) TGLabel *titleStatusLabel;
@property (nonatomic, strong) UIImageView *titleStatusIndicator;

@property (nonatomic, strong) UIScrollView *scrollToTopInterceptor;

@property (nonatomic, strong) NSMutableDictionary *mediaDownloadProgress;
@property (nonatomic, strong) NSMutableDictionary *mediaDownloadedStatuses;

@property (nonatomic) int hiddenMediaMid;

@property (nonatomic, strong) TGMenuContainerView *menuContainerView;
@property (nonatomic, strong) TGTooltipContainerView *dateTooltipContainerView;

@property (nonatomic, strong) UIView *emptyConversationContainer;

@property (nonatomic) float overlayDateAlpha;
@property (nonatomic) float overlayDateAlphaDay;
@property (nonatomic, strong) UIView *overlayDateContainer;
@property (nonatomic, strong) UILabel *overlayDateView;
@property (nonatomic) int overlayDateViewDate;
@property (nonatomic) int overlayDateViewUpdateOffset;
@property (nonatomic) int overlayDateToken;

@property (nonatomic) int currentlyHighlightedMid;

@property (nonatomic, strong) TGAlertDelegateProxy *alertProxy;
@property (nonatomic, strong) NSArray *preparedImages;

@property (nonatomic) int messageLifetime;

@property (nonatomic) bool systemHideState;

@end

@implementation TGConversationController

+ (void)setGlobalAssetsSource:(id<TGConversationMessageAssetsSource>)assetsSource
{
    TGGlobalAssetsSource = assetsSource;
}

+ (void)preloadGraphics
{
}

 + (int64_t)lastConversationIdForBackAction
{
    return lastConversationIdForBackAction;
}

+ (void)resetLastConversationIdForBackAction
{
    lastConversationIdForBackAction = 0;
}

+ (CGSize)preferredInlineThumbnailSize
{
    bool wide = [self isWidescreen];
    
    return wide ? CGSizeMake(220, 220) : CGSizeMake(180, 180);
}

+ (void)clearSharedCache
{
    [sharedViewRecycler removeAllViews];
}

- (id)initWithConversationControllerCompanion:(TGConversationControllerCompanion *)companion unreadCount:(int)unreadCount
{
    self = [super initWithNibName:nil bundle:nil];
    if (self)
    {
#ifdef DEBUG
        aliveControllerCount++;
#endif
        
        self.automaticallyManageScrollViewInsets = false;
        
        _unreadCount = unreadCount;
        
        self.style = TGViewControllerStyleDefault;
        
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:true];
        
        _conversationCompanion = companion;
        
        _listModel = [[NSMutableArray alloc] init];
        
        _mediaDownloadedStatuses = [[NSMutableDictionary alloc] init];
        
        _weakDelegate = [[TGWeakDelegate alloc] init];
        _weakDelegate.object = self;
        
        _chatTitle = companion.conversationTitle;
        _chatSubtitle = companion.conversationSubtitle;
        
        _proxyDidBecomeActiveSecure = [[TGObserverProxy alloc] initWithTarget:self targetSelector:@selector(systemActiveEvent:) name:UIApplicationDidBecomeActiveNotification];
        _proxyWillResignActiveSecure = [[TGObserverProxy alloc] initWithTarget:self targetSelector:@selector(systemResignEvent:) name:UIApplicationWillResignActiveNotification];
    }
    return self;
}

- (bool)shouldBeRemovedFromNavigationAfterHiding
{
    return false;
}

- (void)cleanupBeforeDestruction
{
    if ([self presentedViewController] != nil)
        [self dismissViewControllerAnimated:false completion:nil];
}

- (void)cleanupAfterDestruction
{
    for (UITableViewCell *cell in [_tableView visibleCells])
    {
        if ([cell.reuseIdentifier isEqualToString:@"LoadingCell"])
        {
            TGActivityIndicatorView *spinner = (TGActivityIndicatorView *)[cell viewWithTag:10001];
            if ([spinner isKindOfClass:[TGActivityIndicatorView class]])
            {
                [spinner stopAnimating];
                spinner.hidden = true;
            }
        }
    }
    
    [_conversationCompanion storeConversationState:_inputField.text];
    
    _stopProcessingEverything = true;
    _conversationCompanion.conversationController = nil;
    _conversationCompanion = nil;
    
    if (_typingDotsShortTimer != nil)
    {
        [_typingDotsShortTimer invalidate];
        _typingDotsShortTimer = nil;
    }
    
    if (_typingDotsIntervalTimer != nil)
    {
        [_typingDotsIntervalTimer invalidate];
        _typingDotsIntervalTimer = nil;
    }
}

- (void)contentControllerWillBeDismissed
{
    if (_hiddenMediaMid != 0)
    {
        [self actionStageActionRequested:@"hideImage" options:@{@"force": @(true), @"messageId": @(_hiddenMediaMid), @"hide": @(false)}];
        
        _hiddenMediaMid = 0;
    }
}

- (void)dealloc
{
    [self removeObservers];
    
#ifdef DEBUG
    aliveControllerCount--;
    TGLog(@"dealloc %@ (%d left)", _titleTextLabel.text, aliveControllerCount);
#endif
    
    NSTimer *typingDotsShortTimer = _typingDotsShortTimer;
    _typingDotsShortTimer = nil;
    
    NSTimer *typingDotsIntervalTimer = _typingDotsIntervalTimer;
    _typingDotsIntervalTimer = nil;
    
    UIActionSheet *currentActionSheet = _currentActionSheet;
    _currentActionSheet = nil;
    
    UIView *view = self.isViewLoaded ? self.view : nil;
    
    dispatch_block_t block = ^
    {
        if (typingDotsShortTimer != nil)
        {
            [typingDotsShortTimer invalidate];
        }
        
        if (typingDotsIntervalTimer != nil)
        {
            [typingDotsIntervalTimer invalidate];
        }
        
        currentActionSheet.delegate = nil;
        
        [view frame];
    };
    
    if ([NSThread isMainThread])
        block();
    else
    {
        TGLog(@"Deallocating controller on background thread");
        dispatch_async(dispatch_get_main_queue(), block);
    }
    
    _weakDelegate.object = nil;
    _weakDelegate = nil;
    
    [_actionHandle reset];
    [ActionStageInstance() removeWatcher:self];
    
    [self doUnloadView];
}

- (void)systemHideEvent:(NSNotification *)notification
{
    _systemHideState = [notification.userInfo[@"state"] boolValue];
    
    _tableView.hidden = _systemHideState || [UIApplication sharedApplication].applicationState != UIApplicationStateActive;
}

- (void)systemActiveEvent:(NSNotification *)__unused notification
{
    _tableView.hidden = _systemHideState;
}

- (void)systemResignEvent:(NSNotification *)__unused notification
{
    _tableView.hidden = true;
}

- (void)loadView
{
#define TG_MEASURE_CONTROLLER 0
    
#if TG_MEASURE_CONTROLLER
    TG_TIMESTAMP_DEFINE(loadView);
    TG_TIMESTAMP_DEFINE(loadViewEnd);
#endif
    
    [super loadView];
    
    _scrollToTopInterceptor = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 1)];
    _scrollToTopInterceptor.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _scrollToTopInterceptor.contentSize = CGSizeMake(1, 2);
    _scrollToTopInterceptor.contentOffset = CGPointMake(0, 1);
    _scrollToTopInterceptor.delegate = self;
    _scrollToTopInterceptor.scrollsToTop = true;
    [self.view addSubview:_scrollToTopInterceptor];
    
    if (_chatTitle.length == 0 || [_chatTitle isEqualToString:@" "])
        _chatTitle = _conversationCompanion.safeConversationTitle;
    if (_chatSubtitle.length == 0 || [_chatSubtitle isEqualToString:@" "])
        _chatSubtitle = _conversationCompanion.safeConversationSubtitle;
    
#if TG_MEASURE_CONTROLLER
    TG_TIMESTAMP_MEASURE(loadView);
#endif
    
    _titleContainer = [[UIView alloc] init];
    
    _titleLabelsContainer = [[UIView alloc] initWithFrame:_titleContainer.bounds];
    [_titleContainer addSubview:_titleLabelsContainer];
    _titleLabelsContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    _titleTextLabel = [[TGLabel alloc] init];
    _titleTextLabel.text = _chatTitle.length == 0 ? @" " : _chatTitle;
    _titleTextLabel.backgroundColor = [UIColor clearColor];
    _titleTextLabel.font = [TGViewController titleTitleFontForStyle:self.style landscape:UIDeviceOrientationIsLandscape(self.interfaceOrientation)];
    _titleTextLabel.portraitFont = [TGViewController titleTitleFontForStyle:self.style landscape:false];
    _titleTextLabel.landscapeFont = [TGViewController titleTitleFontForStyle:self.style landscape:true];
    _titleTextLabel.textColor = [TGViewController titleTextColorForStyle:self.style];
    _titleTextLabel.shadowColor = [TGViewController titleShadowColorForStyle:self.style];
    _titleTextLabel.shadowOffset = [TGViewController titleShadowOffsetForStyle:self.style];
    _titleTextLabel.textAlignment = UITextAlignmentLeft;
    _titleTextLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    _titleTextLabel.verticalAlignment = TGLabelVericalAlignmentCenter;
    [_titleLabelsContainer addSubview:_titleTextLabel];
    
    _titleStatusLabelNormal = [[TGLabel alloc] init];
    _titleStatusLabelNormal.text = _chatSubtitle.length == 0 ? @" " : _chatSubtitle;
    _titleStatusLabelNormalText = _titleStatusLabelNormal.text;
    _titleStatusLabelNormal.backgroundColor = [UIColor clearColor];
    _titleStatusLabelNormal.font = [UIFont boldSystemFontOfSize:12];
    _titleStatusLabelNormal.textColor = UIColorRGB(0xe0eefd);
    _titleStatusLabelNormal.shadowColor = UIColorRGB(0x3d5c81);
    _titleStatusLabelNormal.shadowOffset = [TGViewController titleShadowOffsetForStyle:self.style];
    _titleStatusLabelNormal.textAlignment = UITextAlignmentCenter;
    _titleStatusLabelNormal.verticalAlignment = TGLabelVericalAlignmentTop;
    [_titleLabelsContainer addSubview:_titleStatusLabelNormal];
    
    _titleStatusLabelTyping = [[TGLabel alloc] init];
    _titleStatusLabelTyping.text = _chatTypingSubtitle.length == 0 ? @" " : _chatTypingSubtitle;
    _titleStatusLabelTypingText = _titleStatusLabelTyping.text;
    _titleStatusLabelTyping.backgroundColor = [UIColor clearColor];
    _titleStatusLabelTyping.font = [UIFont boldSystemFontOfSize:12];
    _titleStatusLabelTyping.textColor = UIColorRGB(0xe0eefd);
    _titleStatusLabelTyping.shadowColor = UIColorRGB(0x3d5c81);
    _titleStatusLabelTyping.shadowOffset = [TGViewController titleShadowOffsetForStyle:self.style];
    _titleStatusLabelTyping.textAlignment = UITextAlignmentCenter;
    _titleStatusLabelTyping.verticalAlignment = TGLabelVericalAlignmentTop;
    _titleStatusLabelTyping.clipsToBounds = false;
    _titleStatusLabelTyping.lineBreakMode = NSLineBreakByTruncatingTail;
    _titleStatusLabelTyping.alpha = 0.0f;
    [_titleLabelsContainer addSubview:_titleStatusLabelTyping];
    
#if TG_MEASURE_CONTROLLER
    TG_TIMESTAMP_MEASURE(loadView);
#endif
    
    UIView *typingDotsContainer = [[UIView alloc] initWithFrame:CGRectMake(-24, 5, 21, 10)];
    UIImageView *typingBackground = [[UIImageView alloc] initWithFrame:typingDotsContainer.bounds];
    typingBackground.image = [[UIImage imageNamed:@"TypingHeader.png"] stretchableImageWithLeftCapWidth:6 topCapHeight:0];
    [typingDotsContainer addSubview:typingBackground];
    
    UIImage *dotImage = [UIImage imageNamed:@"TypingHeader_Dot.png"];
    UIImageView *typingDot1 = [[UIImageView alloc] initWithImage:dotImage];
    UIImageView *typingDot2 = [[UIImageView alloc] initWithImage:dotImage];
    UIImageView *typingDot3 = [[UIImageView alloc] initWithImage:dotImage];
    
    float retinaPixel = TGIsRetina() ? 0.5f : 0.0f;
    
    typingDot1.frame = CGRectOffset(typingDot1.frame, 4, 3);
    typingDot2.frame = CGRectOffset(typingDot2.frame, 4 + 4 + retinaPixel, 3);
    typingDot3.frame = CGRectOffset(typingDot3.frame, 4 + 4 + retinaPixel + 4 + retinaPixel, 3);
    
    [typingDotsContainer addSubview:typingDot1];
    [typingDotsContainer addSubview:typingDot2];
    [typingDotsContainer addSubview:typingDot3];
    
#if TG_MEASURE_CONTROLLER
    TG_TIMESTAMP_MEASURE(loadView);
#endif
    
    _typingDots = [[NSArray alloc] initWithObjects:typingDot1, typingDot2, typingDot3, nil];
    [_titleStatusLabelTyping addSubview:typingDotsContainer];
    
    self.navigationItem.titleView = _titleContainer;
    
    _backButton = [[TGToolbarButton alloc] initWithType:TGToolbarButtonTypeBack];
    _backButton.tag = ((int)0x263D9E33);
    _backButton.text = NSLocalizedString(@"Common.Back", @"");
    [_backButton sizeToFit];
    [_backButton addTarget:self action:@selector(performCloseConversation) forControlEvents:UIControlEventTouchUpInside];
    
    TGConversationButtonContainer *backContainer = [[TGConversationButtonContainer alloc] initWithFrame:_backButton.frame];
    backContainer.backSemantics = true;
    [backContainer addSubview:_backButton];
    
    UIBarButtonItem *backItem = [[UIBarButtonItem alloc] initWithCustomView:backContainer];
    [self.navigationItem setLeftBarButtonItem:backItem animated:false];
    
#if TG_MEASURE_CONTROLLER
    TG_TIMESTAMP_MEASURE(loadView);
#endif
    
    _unreadCountContainer = [[UIView alloc] initWithFrame:CGRectMake(_backButton.frame.size.width - 13, -7, 25, 6)];
    _unreadCountContainer.hidden = true;
    _unreadCountContainer.userInteractionEnabled = false;
    _unreadCountContainer.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [_backButton addSubview:_unreadCountContainer];
    
    _unreadCountBadge = [[UIImageView alloc] initWithImage:[_conversationCompanion unreadCountBadgeImage]];
    [_unreadCountContainer addSubview:_unreadCountBadge];
    
    _unreadCountLabel = [[UILabel alloc] initWithFrame:CGRectMake(9, 7 + retinaPixel, 28 + retinaPixel, 10)];
    _unreadCountLabel.backgroundColor = [UIColor clearColor];
    _unreadCountLabel.textColor = [UIColor whiteColor];
    _unreadCountLabel.font = [UIFont boldSystemFontOfSize:12];
    [_unreadCountContainer addSubview:_unreadCountLabel];
    if (_unreadCount != 0)
        [self updateUnreadCount];
    
#if TG_MEASURE_CONTROLLER
    TG_TIMESTAMP_MEASURE(loadView);
#endif
    
    CGSize avatarSize = [_conversationCompanion titleAvatarSize:UIDeviceOrientationPortrait];
    
    TGConversationButtonContainer *avatarContainer = [[TGConversationButtonContainer alloc] initWithFrame:CGRectMake(0, 0, 37, 38)];
    avatarContainer.exclusiveTouch = true;
    UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(titleAvatarTapped:)];
    [avatarContainer addGestureRecognizer:tapRecognizer];
    
    avatarContainer.clipsToBounds = false;
    _avatarImageView = [[TGRemoteImageView alloc] initWithFrame:CGRectMake(1, 1, avatarSize.width, avatarSize.height)];
    _avatarOverlayView = [[UIImageView alloc] initWithImage:[_conversationCompanion titleAvatarOverlay:self.interfaceOrientation]];
    _avatarOverlayView.frame = CGRectMake(-1.5f, -1, avatarSize.width + 3, avatarSize.height + 2);
    _avatarImageView.fadeTransition = true;
    _avatarImageView.exclusiveTouch = true;
    _avatarImageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [_avatarImageView addSubview:_avatarOverlayView];
    
    [avatarContainer addSubview:_avatarImageView];
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:avatarContainer];
    
#if TG_MEASURE_CONTROLLER
    TG_TIMESTAMP_MEASURE(loadView);
#endif
    
    _baseInputContainerHeight = 43;
    
    self.view.backgroundColor = [_conversationCompanion conversationBackground];
    UIImage *backgroundImage = [_conversationCompanion conversationBackgroundImage];
    if (backgroundImage != nil)
    {
        float superviewOffset = 20 + (self.view.frame.size.height > 400 ? 44 : 32);
        _backgroundImageView = [[TGConversationBackgroundView alloc] initWithFrame:CGRectMake(0, superviewOffset - 20, self.view.frame.size.width, self.view.frame.size.height - _baseInputContainerHeight + 40 - superviewOffset)];
        
        _backgroundImageView.image = backgroundImage;
        _backgroundImageView.contentMode = UIViewContentModeScaleAspectFill;
        _backgroundImageView.clipsToBounds = true;
        [self.view addSubview:_backgroundImageView];
    }
    else
    {
        UIImage *backgroundOverlay = [_conversationCompanion conversationBackgroundOverlay];
        if (backgroundOverlay != nil)
        {
            UIImageView *backgroundOverlayView = [[UIImageView alloc] initWithFrame:self.view.bounds];
            backgroundOverlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            backgroundOverlayView.image = backgroundOverlay;
            [self.view addSubview:backgroundOverlayView];
        }
    }
    
#if TG_MEASURE_CONTROLLER
    TG_TIMESTAMP_MEASURE(loadView);
#endif
    
    _actionBarHeight = 53;
    
    _tableView = [self createTableView:CGRectMake(0, 0, 320, [TGViewController screenSizeForInterfaceOrientation:UIInterfaceOrientationPortrait].height)];
    [self.view addSubview:_tableView];
    
#if TG_MEASURE_CONTROLLER
    TG_TIMESTAMP_MEASURE(loadView);
#endif
    
    [self updateMetrics];
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        sharedViewRecycler = [[TGViewRecycler alloc] init];
    });
    _viewRecycler = sharedViewRecycler;
    
#if TG_MEASURE_CONTROLLER
    TG_TIMESTAMP_MEASURE(loadView);
#endif
    
    _inputContainer = [[TGConversationInputContainerView alloc] initWithFrame:CGRectMake(0, self.view.frame.size.height - _baseInputContainerHeight, 320, _baseInputContainerHeight)];
    _inputContainer.controlBackground = true;
    _inputContainer.backgroundImageView = _backgroundImageView;
    _inputContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    _inputContainer.opaque = false;
    _inputContainer.clipsToBounds = false;
    [self.view addSubview:_inputContainer];
    
#if TG_MEASURE_CONTROLLER
    TG_TIMESTAMP_MEASURE(loadView);
#endif
    
    UIImageView *inputContainerShadow = [[UIImageView alloc] initWithImage:[_conversationCompanion inputContainerShadowImage]];
    inputContainerShadow.tag = InputContainerShadowTag;
    inputContainerShadow.frame = CGRectMake(0, -inputContainerShadow.frame.size.height, self.view.frame.size.width, inputContainerShadow.frame.size.height);
    inputContainerShadow.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
    inputContainerShadow.userInteractionEnabled = false;
    inputContainerShadow.backgroundColor = [UIColor clearColor];
    inputContainerShadow.opaque = false;
    [_inputContainer addSubview:inputContainerShadow];
    
#if TG_MEASURE_CONTROLLER
    TG_TIMESTAMP_MEASURE(loadView);
#endif
    
    _inputFieldWhiteBackground = [[UIView alloc] initWithFrame:CGRectMake(40, 4 - retinaPixel, self.view.frame.size.width - 106, 36)];
    _inputFieldWhiteBackground.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _inputFieldWhiteBackground.backgroundColor = [UIColor whiteColor];
    [_inputContainer addSubview:_inputFieldWhiteBackground];
    
    _fakeInputFieldLabel = [[UILabel alloc] initWithFrame:CGRectMake(40 + 9, 4 + 10 - retinaPixel, self.view.frame.size.width - 106 - 20, 200)];
    _fakeInputFieldLabel.font = [UIFont systemFontOfSize:16];
    _fakeInputFieldLabel.lineBreakMode = UILineBreakModeWordWrap;
    _fakeInputFieldLabel.numberOfLines = 0;
    [_inputContainer addSubview:_fakeInputFieldLabel];
    
    _placeholderLabel = [[UILabel alloc] initWithFrame:CGRectMake(49, 5 - retinaPixel, self.view.frame.size.width - 113, 34)];
    _placeholderLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
    _placeholderLabel.backgroundColor = [UIColor clearColor];
    _placeholderLabel.opaque = false;
    _placeholderLabel.font = [UIFont systemFontOfSize:16];
    _placeholderLabel.textColor = UIColorRGB(0x9da7b3);
    _placeholderLabel.text = NSLocalizedString(@"Conversation.InputTextPlaceholder", @"");
    _placeholderLabel.hidden = _fakeInputFieldLabel.text.length != 0;
#if TGInputFieldClassIsHP
    [_inputContainer addSubview:_placeholderLabel];
#endif
    
    _inputFieldBackground = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, _inputContainer.frame.size.width, _baseInputContainerHeight)];
    [_inputFieldBackground setImage:[_conversationCompanion inputFieldBackground]];
    _inputFieldBackground.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [_inputContainer addSubview:_inputFieldBackground];
    
    _attachButton = [[UIButton alloc] initWithFrame:CGRectMake(6, 7 + retinaPixel, 29, 30)];
    _attachButton.exclusiveTouch = true;
    [_attachButton setImage:[_conversationCompanion attachButtonImage] forState:UIControlStateNormal];
    [_attachButton setImage:[_conversationCompanion attachButtonImageHighlighted] forState:UIControlStateHighlighted];
    _attachButton.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin;
    [_attachButton addTarget:self action:@selector(attachButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    _attachButton.adjustsImageWhenDisabled = false;
    _attachButton.adjustsImageWhenHighlighted = false;
    
    [_inputContainer addSubview:_attachButton];
    
    _sendButton = [[UIButton alloc] initWithFrame:CGRectMake(self.view.frame.size.width - 62 - 5, 7 + retinaPixel, 62, 29)];
    _sendButton.exclusiveTouch = true;
    [_sendButton setBackgroundImage:[_conversationCompanion sendButtonImage] forState:UIControlStateNormal];
    [_sendButton setBackgroundImage:[_conversationCompanion sendButtonImageHighlighted] forState:UIControlStateHighlighted];
    _sendButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;
    [_sendButton setTitle:NSLocalizedString(@"Conversation.Send", @"") forState:UIControlStateNormal];
    [_sendButton setTitleShadowColor:UIColorRGBA(0x0cb8e3, 0.3f) forState:UIControlStateNormal];
    [_sendButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [_sendButton setTitleColor:[TGViewController isWidescreen] ? UIColorRGB(0xceffb0) : UIColorRGB(0xbbffb2) forState:UIControlStateDisabled];
    
    _sendButton.titleLabel.font = [UIFont boldSystemFontOfSize:14.5f];
    _sendButton.titleLabel.shadowOffset = CGSizeMake(0, -1);
    _sendButton.titleEdgeInsets = UIEdgeInsetsMake(1.5f, 0, 2, 0);
    _sendButton.adjustsImageWhenDisabled = false;
    _sendButton.adjustsImageWhenHighlighted = false;
    _sendButton.enabled = false;
    [_sendButton addTarget:self action:@selector(sendButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    [_inputContainer addSubview:_sendButton];
    
    _tableNeedsReloading = false;
    
#if TG_MEASURE_CONTROLLER
    TG_TIMESTAMP_MEASURE(loadView);
#endif
    
    _titleTextLabel.text = _chatTitle.length == 0 ? @" " : _chatTitle;
    _titleStatusLabelNormal.text = _chatSubtitle.length == 0 ? @" " : _chatSubtitle;
    _titleStatusLabelNormalText = _titleStatusLabelNormal.text;
    _titleStatusLabelTyping.text = _chatTypingSubtitle.length == 0 ? @" " : _chatTypingSubtitle;
    _titleStatusLabelTypingText = _titleStatusLabelTyping.text;
    
    _messageLifetime = _conversationCompanion.messageLifetime;
    
    if ((!_conversationCompanion.isMultichat && !_conversationCompanion.isBroadcast) || _conversationCompanion.isEncrypted)
    {
        if (_chatSingleParticipant != nil)
        {
            TGUser *user = _chatSingleParticipant;
            if (user.photoUrlSmall != nil)
            {
                [_avatarImageView loadImage:user.photoUrlSmall filter:@"titleAvatar" placeholder:[_conversationCompanion titleAvatarPlaceholderGeneric] forceFade:true];
            }
            else
                [_avatarImageView loadImage:[_conversationCompanion titleAvatarPlaceholder]];
        }
        else
        {
            [_avatarImageView loadImage:[_conversationCompanion titleAvatarPlaceholderGeneric]];
        }
    }
    
    if (_conversationCompanion.isBroadcast)
        avatarContainer.hidden = true;
    
    [self synchronizationStatusChanged:_synchronizationStatus];
    
    _viewPanRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(viewPanGestureRecognized:)];
    _viewPanRecognizer.cancelsTouchesInView = false;
    [self.view addGestureRecognizer:_viewPanRecognizer];
    
    UIView *blackView = [[UIView alloc] initWithFrame:CGRectMake(0, -64, self.view.frame.size.width, 64)];
    blackView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    blackView.backgroundColor = [UIColor blackColor];
    blackView.opaque = true;
    [self.view addSubview:blackView];
    
#if TG_MEASURE_CONTROLLER
    TG_TIMESTAMP_MEASURE(loadView);
#endif
    
    if (_conversationCompanion.isMultichat)
    {
        [self setConversationLink:_conversationLink animated:false];
    }
    
    if (![self _updateControllerInset:false])
        [self controllerInsetUpdated:UIEdgeInsetsZero];
    
#if TG_MEASURE_CONTROLLER
    TG_TIMESTAMP_MEASURE(loadView);
    TG_TIMESTAMP_MEASURE(loadViewEnd);
#endif
}

- (TGToolbarButton *)doneButton
{
    if (_doneButton == nil)
    {
        _doneButton = [[TGToolbarButton alloc] initWithType:TGToolbarButtonTypeGeneric];
        _doneButton.text = TGLocalized(@"Common.Cancel");
        _doneButton.minWidth = 51;
        _doneButton.paddingLeft = 10;
        _doneButton.paddingRight = 10;
        [_doneButton addTarget:self action:@selector(doneButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [_doneButton sizeToFit];
        
        [_doneButton setIsLandscape:_backButton.isLandscape];
        CGRect frame = _doneButton.frame;
        frame.origin.y = _backButton.frame.origin.y + 4 + (TGIsRetina() ? 0.5f : 0.0f);
        frame.origin.x = _avatarImageView.superview.frame.size.width - frame.size.width;
        _doneButton.frame = frame;
        
        [_avatarImageView.superview addSubview:_doneButton];
        
        _doneButton.alpha = 0.0f;
    }
    
    return _doneButton;
}

- (TGToolbarButton *)clearAllButton
{
    if (_clearAllButton == nil)
    {
        _clearAllButton = [[TGToolbarButton alloc] initWithType:TGToolbarButtonTypeGeneric];
        _clearAllButton.text = TGLocalized(@"Conversation.ClearAll");
        _clearAllButton.minWidth = 54;
        _clearAllButton.paddingLeft = 8;
        _clearAllButton.paddingRight = 8;
        [_clearAllButton addTarget:self action:@selector(clearAllButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [_clearAllButton sizeToFit];
        
        [_clearAllButton setIsLandscape:_backButton.isLandscape];
        CGRect frame = _clearAllButton.frame;
        frame.origin = _backButton.frame.origin;
        frame.origin.y += TGIsRetina() ? 0.5f : 0.0f;
        _clearAllButton.frame = frame;
        
        [_backButton.superview insertSubview:_clearAllButton belowSubview:_backButton];
        
        _clearAllButton.alpha = 0.0f;
    }
    
    return _clearAllButton;
}

#if TGUseCollectionView

- (TGMessagesCollectionView *)createTableView:(CGRect)tableFrame
{
    _flowLayout = [[UICollectionViewFlowLayout alloc] init];
    
    TGMessagesCollectionView *tableView = [[TGMessagesCollectionView alloc] initWithFrame:tableFrame collectionViewLayout:_flowLayout];
    tableView.transform = CGAffineTransformMakeRotation(M_PI);
    tableView.opaque = false;
    tableView.backgroundColor = [UIColor clearColor];
    tableView.delaysContentTouches = false;
    tableView.delegate = self;
    tableView.dataSource = self;
    tableView.scrollsToTop = false;
    tableView.contentMode = UIViewContentModeLeft;
    //tableView.scrollInsets = UIEdgeInsetsMake(0, 0, 0, 9);
    tableView.contentInset = UIEdgeInsetsMake(2, 0, 0, 0);
    
    [tableView registerClass:[TGConversationDateItemView class] forCellWithReuseIdentifier:@"D"];
    [tableView registerClass:[TGConversationMessageItemView class] forCellWithReuseIdentifier:@"M"];
    [tableView registerClass:[TGConversationUnreadItemView class] forCellWithReuseIdentifier:@"UNR"];
    
    UIPanGestureRecognizer *tablePanRecognizer = nil;
    if (![tableView respondsToSelector:@selector(panGestureRecognizer)])
    {
        tablePanRecognizer = [[UIPanGestureRecognizer alloc] init];
        [tableView addGestureRecognizer:tablePanRecognizer];
    }
    else
        tablePanRecognizer = tableView.panGestureRecognizer;
    [tablePanRecognizer addTarget:self action:@selector(tablePanRecognized:)];
    
    TGSwipeGestureRecognizer *leftSwipeRecognizer = [[TGSwipeGestureRecognizer alloc] initWithTarget:self action:@selector(tableViewSwiped:)];
    leftSwipeRecognizer.direction = TGSwipeGestureRecognizerDirectionLeft;
    leftSwipeRecognizer.horizontalThreshold = 36;
    leftSwipeRecognizer.verticalThreshold = 10;
    leftSwipeRecognizer.directionLockThreshold = 10;
    leftSwipeRecognizer.velocityThreshold = 200;
    [tableView addGestureRecognizer:leftSwipeRecognizer];
    leftSwipeRecognizer.delegate = self;
    
    TGSwipeGestureRecognizer *rightSwipeRecognizer = [[TGSwipeGestureRecognizer alloc] initWithTarget:self action:@selector(tableViewSwiped:)];
    rightSwipeRecognizer.direction = TGSwipeGestureRecognizerDirectionRight;
    rightSwipeRecognizer.horizontalThreshold = 36;
    rightSwipeRecognizer.verticalThreshold = 10;
    rightSwipeRecognizer.directionLockThreshold = 10;
    rightSwipeRecognizer.velocityThreshold = 200;
    [tableView addGestureRecognizer:rightSwipeRecognizer];
    rightSwipeRecognizer.delegate = self;
    
    tableView.showsVerticalScrollIndicator = true;
    
    [tableView reloadData];
    [self updateCellAnimations];
    
    return tableView;
}

#else

- (TGTableView *)createTableView:(CGRect)tableFrame
{
    TGTableView *tableView = [[TGTableView alloc] initWithFrame:tableFrame style:UITableViewStylePlain reversed:true];
    tableView.transform = CGAffineTransformMakeRotation(M_PI);
    tableView.opaque = false;
    tableView.backgroundColor = [UIColor clearColor];
    tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    tableView.delaysContentTouches = false;
    tableView.delegate = self;
    tableView.dataSource = self;
    tableView.scrollsToTop = false;
    tableView.contentMode = UIViewContentModeLeft;
    tableView.scrollInsets = UIEdgeInsetsMake(0, 0, 0, 9);
    tableView.contentInset = UIEdgeInsetsMake(2, 0, 0, 0);
    
    UIPanGestureRecognizer *tablePanRecognizer = nil;
    if (![tableView respondsToSelector:@selector(panGestureRecognizer)])
    {
        tablePanRecognizer = [[UIPanGestureRecognizer alloc] init];
        [tableView addGestureRecognizer:tablePanRecognizer];
    }
    else
        tablePanRecognizer = tableView.panGestureRecognizer;
    [tablePanRecognizer addTarget:self action:@selector(tablePanRecognized:)];
    
    TGSwipeGestureRecognizer *leftSwipeRecognizer = [[TGSwipeGestureRecognizer alloc] initWithTarget:self action:@selector(tableViewSwiped:)];
    leftSwipeRecognizer.direction = TGSwipeGestureRecognizerDirectionLeft;
    leftSwipeRecognizer.horizontalThreshold = 36;
    leftSwipeRecognizer.verticalThreshold = 10;
    leftSwipeRecognizer.directionLockThreshold = 10;
    leftSwipeRecognizer.velocityThreshold = 200;
    [tableView addGestureRecognizer:leftSwipeRecognizer];
    leftSwipeRecognizer.delegate = self;
    
    TGSwipeGestureRecognizer *rightSwipeRecognizer = [[TGSwipeGestureRecognizer alloc] initWithTarget:self action:@selector(tableViewSwiped:)];
    rightSwipeRecognizer.direction = TGSwipeGestureRecognizerDirectionRight;
    rightSwipeRecognizer.horizontalThreshold = 36;
    rightSwipeRecognizer.verticalThreshold = 10;
    rightSwipeRecognizer.directionLockThreshold = 10;
    rightSwipeRecognizer.velocityThreshold = 200;
    [tableView addGestureRecognizer:rightSwipeRecognizer];
    rightSwipeRecognizer.delegate = self;

    tableView.showsVerticalScrollIndicator = true;
    
    [tableView reloadData];
    [self updateCellAnimations];

    return tableView;
}
#endif

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)__unused gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)__unused otherGestureRecognizer
{
    return true;
}

- (void)doUnloadView
{
    _scrollToTopInterceptor.delegate = nil;
    _scrollToTopInterceptor = nil;
    
    _tableView.delegate = nil;
    _tableView.dataSource = nil;
    _tableView = nil;
    
    _inputField.delegate = nil;
    _inputField = nil;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)viewDidUnload
{
    [self doUnloadView];
    
    [super viewDidUnload];
}

- (void)removeObservers
{
    _proxyWillEnterForeground = nil;
    _proxyDidEnterBackground = nil;
    _proxyDidBecomeActive = nil;
    
    _proxyKeyboardWillShow = nil;
    _proxyKeyboardDidShow = nil;
    _proxyKeyboardWillHide = nil;
    _proxyKeyboardDidHide = nil;
}

- (void)addServiceObservers
{
    _proxyDidEnterBackground = [[TGObserverProxy alloc] initWithTarget:self targetSelector:@selector(didEnterBackground:) name:UIApplicationDidEnterBackgroundNotification];
    _proxyWillEnterForeground = [[TGObserverProxy alloc] initWithTarget:self targetSelector:@selector(willEnterForeground:) name:UIApplicationWillEnterForegroundNotification];
    _proxyDidBecomeActive = [[TGObserverProxy alloc] initWithTarget:self targetSelector:@selector(didBecomeActive:) name:UIApplicationDidBecomeActiveNotification];
}

- (void)addKeyboardObservers
{
    _proxyKeyboardWillShow = [[TGObserverProxy alloc] initWithTarget:self targetSelector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification];
    _proxyKeyboardWillHide = [[TGObserverProxy alloc] initWithTarget:self targetSelector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification];
    _proxyKeyboardDidShow = [[TGObserverProxy alloc] initWithTarget:self targetSelector:@selector(keyboardDidShow:) name:UIKeyboardDidShowNotification];
    _proxyKeyboardDidHide = [[TGObserverProxy alloc] initWithTarget:self targetSelector:@selector(keyboardDidHide:) name:UIKeyboardDidHideNotification];
}

- (UIView *)selectActiveInputView
{
    //if (_wantsKeyboardActive)
    //    return _inputField.internalTextView;
    
    return nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    //TG_TIMESTAMP_DEFINE(willAppear)
    //TG_TIMESTAMP_DEFINE(willAppearEnd)
    
    if (_openKeyboardAutomatically)
    {
        _openKeyboardAutomatically = false;
        
        _wantsKeyboardActive = true;
        
        [self createInputField];
        [self.inputField becomeFirstResponder];
        
        _keyboardOpened = true;
    }
    
    //TG_TIMESTAMP_MEASURE(willAppear)
    
    self.navigationBarShouldBeHidden = _wantsKeyboardActive && UIInterfaceOrientationIsLandscape(self.interfaceOrientation);
    [self setStatusBarBackgroundAlpha:self.navigationBarShouldBeHidden ? 0.0f : 1.0f];
    
    [super viewWillAppear:animated];
    
    [_actionsPanel hide:false];
    
    _stopProcessingEverything = false;
    
    _appearingAnimation = true;
    _appearingAnimationStart = CFAbsoluteTimeGetCurrent();
    
    dispatch_async(dispatch_get_main_queue(), ^
    {
        if (![_inputField isFirstResponder] && ![_conversationCompanion.applicationManager keyboardVisible])
        {
            [self changeInputAreaHeight:0 duration:0.0 orientationChange:false dragging:false completion:nil];
        }
        
        if ([_inputField isFirstResponder])
        {
            int keyboardHeight = (int)[_conversationCompanion.applicationManager keyboardHeight];
            if (_knownKeyboardHeight != keyboardHeight)
            {
                _knownKeyboardHeight = keyboardHeight;
                [self changeInputAreaHeight:_knownKeyboardHeight duration:0.0 orientationChange:false dragging:false completion:nil];
            }
        }
    });
    
    [self removeObservers];
    [self addServiceObservers];
    
    [self adjustToInterfaceOrientation:self.interfaceOrientation includingMessagesContainer:true];
    
    [self updateTitle:false];
    [self updateMetrics];
    
    //TG_TIMESTAMP_MEASURE(willAppear)
    
    if (_editingDeleteButton != nil)
        [self updateEditingControls];
    
    if (_tableNeedsReloading)
    {
        _tableNeedsReloading = false;
        
        [self applyDelayedBlock];
        [_tableView reloadData];
        [self updateCellAnimations];
    }
    else
    {
#if TGUseCollectionView
#else
        [UIView setAnimationsEnabled:false];
        [_tableView beginUpdates];
        [_tableView endUpdates];
        [UIView setAnimationsEnabled:true];
#endif
    }
    
    //TG_TIMESTAMP_MEASURE(willAppear)
    
    [_conversationCompanion updateUnreadCount];
    
    Class messageCellClass = [TGConversationMessageItemView class];
    Class remoteImageViewClass = [TGRemoteImageView class];
    for (UITableViewCell *cell in _tableView.visibleCells)
    {
        if ([cell isKindOfClass:messageCellClass])
        {
            TGConversationMessageItemView *messageView = (TGConversationMessageItemView *)cell;
            if (messageView.message.mediaAttachments.count != 0)
                [messageView viewForItemWithClass:remoteImageViewClass].hidden = false;
        }
    }
    
    //TG_TIMESTAMP_MEASURE(willAppear)
    //TG_TIMESTAMP_MEASURE(willAppearEnd)
}

- (void)createInputField
{
    CGRect frame = _inputFieldWhiteBackground.frame;
    frame.origin.x += 1;
    frame.size.width -= 6;
    frame.size.height -= 2;
    
    _inputField = [[TGInputFieldClass alloc] initWithFrame:frame];

#if TGInputFieldClassIsHP
    _inputField.internalTextView.scrollIndicatorInsets = UIEdgeInsetsMake(10, 0, 10, 0);
    _inputField.internalTextView.backgroundColor = _inputFieldWhiteBackground.backgroundColor;
    _inputField.internalTextView.opaque = true;
    _inputField.internalTextView.responderStateDelegate = _weakDelegate;
    _inputField.font = [UIFont systemFontOfSize:16];
    _inputField.maxNumberOfLines = UIInterfaceOrientationIsPortrait(self.interfaceOrientation) ? ([TGViewController isWidescreen] ? 7 : 5) : 3;
    _inputField.delegate = self;
    _inputField.internalTextView.showsVerticalScrollIndicator = false;
#endif
    [_inputContainer insertSubview:_inputField aboveSubview:_inputFieldWhiteBackground];
    
    _inputField.alpha = _sendButton.alpha;
    _inputField.hidden = _sendButton.hidden;
    
    [UIView setAnimationsEnabled:false];
    _inputField.text = _initialMessageText;
    [UIView setAnimationsEnabled:true];
    
    _initialMessageText = nil;
    
    [_fakeInputFieldLabel removeFromSuperview];
    _fakeInputFieldLabel = nil;
    
    dispatch_async(dispatch_get_main_queue(), ^
    {
#if TGInputFieldClassIsHP
        _inputField.internalTextView.showsVerticalScrollIndicator = true;
#endif
    });
}

- (void)viewDidAppear:(BOOL)animated
{
    _appearingAnimation = false;
    
    [self addKeyboardObservers];
    
    if (_inputField == nil)
    {
        [self createInputField];
    }
    
    [_conversationCompanion clearUnreadIfNeeded:true];
    
    _preparedCellQueue = nil;
    
    [self updateCellAnimations];
    
    [_conversationCompanion sendMessageIfAny];
    
    if (_currentlyHighlightedMid != 0)
    {
        [self _fadeOutCurrentlyHighlightedMessage];
    }
    
    [super viewDidAppear:animated];
}

- (void)_fadeOutCurrentlyHighlightedMessage
{
    _tableView.userInteractionEnabled = false;
    
    TGDispatchAfter(0.2, dispatch_get_main_queue(), ^
    {
        _tableView.userInteractionEnabled = true;
        
        for (id cell in _tableView.visibleCells)
        {
            if ([cell isKindOfClass:[TGConversationMessageItemView class]] && ((TGConversationMessageItemView *)cell).message.mid == _currentlyHighlightedMid)
            {
                TGConversationMessageItemView *messageView = cell;
                [messageView setIsContextSelected:false animated:true];
                
                break;
            }
        }
        
        _currentlyHighlightedMid = 0;
    });
}

- (float)tableViewY:(UIInterfaceOrientation)orientation
{
    if (UIInterfaceOrientationIsPortrait(orientation))
        return -44;
    else
    {
        static CGSize screenSize = CGSizeZero;
        if (CGSizeEqualToSize(screenSize, CGSizeZero))
            screenSize = [TGViewController screenSizeForInterfaceOrientation:UIInterfaceOrientationPortrait];
        
        return -44 - (screenSize.height - screenSize.width);
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    _disappearingAnimation = true;
    
    [self removeObservers];
    
    if (animated && cpuCoreCount() < 2)
    {
        [_tableView setContentOffset:_tableView.contentOffset animated:true];
    }
    
    [super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
    _disappearingAnimation = false;
    
    [self removeObservers];
    
    if (_clearEditingOnDisappear)
    {
        _clearEditingOnDisappear = false;
        
        [self setEditingMode:false animated:false];
    }
    
    [super viewDidDisappear:animated];
}

- (void)didEnterBackground:(NSNotification *)__unused notification
{
    [_conversationCompanion storeConversationState:_inputField.text];
}

- (void)didBecomeActive:(NSNotification *)__unused notification
{
    if (self.isViewLoaded && self.view.window != nil)
    {
        if (_tableNeedsReloading)
        {
            _tableNeedsReloading = false;
            
            [self applyDelayedBlock];
            [_tableView reloadData];
        }
        
        [_conversationCompanion clearUnreadIfNeeded:true];
        
        [self updateCellAnimations];
    }
}

- (void)willEnterForeground:(NSNotification *)__unused notification
{
    if (self.isViewLoaded && self.view.window != nil)
    {
        if (_tableNeedsReloading)
        {
            _tableNeedsReloading = false;
            
            [self applyDelayedBlock];
            [_tableView reloadData];
        }
        
        [_conversationCompanion clearUnreadIfNeeded:true];
        [_conversationCompanion storeConversationState:nil];
        
        [self updateCellAnimations];
    }
}

- (void)updateCellAnimations
{
    Class messageItemViewClass = [TGConversationMessageItemView class];
    for (UITableViewCell *cell in _tableView.visibleCells)
    {
        if ([cell isKindOfClass:messageItemViewClass])
        {
            TGConversationMessageItemView *messageView = (TGConversationMessageItemView *)cell;
            [messageView updateState:true];
        }
    }
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return [TGViewController autorotationAllowed] && !_tableView.tracking && !_dragKeyboardByInputContainer && !_dragKeyboardByTablePanning && interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
}

- (BOOL)shouldAutorotate
{
    return [self shouldAutorotateToInterfaceOrientation:UIInterfaceOrientationPortrait];
}

static NSTimeInterval dotInterval()
{
    return TGDotInterval;
}

- (bool)setStatusText:(NSString *)statusText typingStatusText:(NSString *)typingStatusText animated:(bool)animated
{
    if ([_titleStatusLabelNormalText isEqualToString:statusText] && [_titleStatusLabelTypingText isEqualToString:typingStatusText])
    {
        [self updateTitle:animated];
        return true;
    }
    
    static UIColor *onlineColor = nil;
    static UIColor *otherColor = nil;
    if (onlineColor == nil)
    {
        onlineColor = UIColorRGB(0xe0eefd);
        otherColor = UIColorRGB(0xc9dcf2);
    }
    _titleStatusLabelNormal.textColor = [statusText isEqualToString:TGLocalized(@"Presence.online")] ? onlineColor : otherColor;
    
    bool editable = ![statusText hasPrefix:@"you"];
    if (_inputContainer.userInteractionEnabled != editable)
    {
        _userBlocked = true;
        
        [self setConversationLink:_conversationLink animated:(CFAbsoluteTimeGetCurrent() - _appearingAnimationStart > 0.25) && _canLoadMoreHistoryProcessedAtLeastOnce];
    }
    else if (_userBlocked && editable)
    {
        TGLog(@"Unblocking group");
        
        _userBlocked = false;
        
        [self setConversationLink:_conversationLink animated:(CFAbsoluteTimeGetCurrent() - _appearingAnimationStart > 0.25) && _canLoadMoreHistoryProcessedAtLeastOnce];
    }
    
    _titleStatusLabelNormalText = statusText;
    _titleStatusLabelTypingText = typingStatusText;
    
    _titleStatusLabelNormal.text = _titleStatusLabelNormalText;
    
    if (!animated || (typingStatusText.length != 0 && ![typingStatusText isEqualToString:@" "]))
    {
        _titleStatusLabelTyping.text = _titleStatusLabelTypingText;
    }
    
    bool typingMode = (_titleStatusLabelTypingText.length != 0 && ![_titleStatusLabelTypingText isEqualToString:@" "]);
    
    if (animated)
    {
        UIView *titleStatusLabelNormal = _titleStatusLabelNormal;
        UIView *titleStatusLabelTyping = _titleStatusLabelTyping;
        
        [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^
        {
            titleStatusLabelNormal.alpha = typingMode ? 0.0f : 1.0f;
            titleStatusLabelTyping.alpha = !typingMode ? 0.0f : 1.0f;
        } completion:nil];
    }
    else
    {
        _titleStatusLabelNormal.alpha = typingMode ? 0.0f : 1.0f;
        _titleStatusLabelTyping.alpha = !typingMode ? 0.0f : 1.0f;
    }
    
    if (!typingMode)
    {
        if (_typingDotsShortTimer != nil)
        {
            [_typingDotsShortTimer invalidate];
            _typingDotsShortTimer = nil;
        }
        
        if (_typingDotsIntervalTimer != nil)
        {
            [_typingDotsIntervalTimer invalidate];
            _typingDotsIntervalTimer = nil;
        }
    }
    else if (_typingDotsIntervalTimer == nil)
    {
        _currentTypingDot = 0;
        [self typingDotsTimerEvent];
        
        _typingDotsShortTimer = [[NSTimer alloc] initWithFireDate:[[NSDate alloc] initWithTimeIntervalSinceNow:TGDotInterval] interval:TGDotInterval target:self selector:@selector(typingDotsTimerEvent) userInfo:nil repeats:true];
        [[NSRunLoop mainRunLoop] addTimer:_typingDotsShortTimer forMode:NSRunLoopCommonModes];
        
        _typingDotsIntervalTimer = [[NSTimer alloc] initWithFireDate:[[NSDate alloc] initWithTimeIntervalSinceNow:TGDotPeriod] interval:TGDotPeriod target:self selector:@selector(typingDotsIntervalTimerEvent) userInfo:nil repeats:true];
        [[NSRunLoop mainRunLoop] addTimer:_typingDotsIntervalTimer forMode:NSRunLoopCommonModes];
        
        for (UIView *dotView in _typingDots)
        {
            [dotView.layer removeAllAnimations];
            dotView.transform = CGAffineTransformIdentity;
        }
    }

    [self updateTitle:animated];
    return true;
}

- (void)typingDotsTimerEvent
{
    UIView *dotView = [_typingDots objectAtIndex:_currentTypingDot % 3];
    [UIView animateWithDuration:0.1 animations:^
    {
        dotView.transform = CGAffineTransformMakeScale(1.3f, 1.3f);
    } completion:^(BOOL finished)
    {
        if (finished)
        {
            [UIView animateWithDuration:0.1 animations:^
            {
                dotView.transform = CGAffineTransformIdentity;
            }];
        }
    }];
    
    _currentTypingDot++;
    
    if (_currentTypingDot >= 3)
    {
        if (_typingDotsShortTimer != nil)
        {
            [_typingDotsShortTimer invalidate];
            _typingDotsShortTimer = nil;
        }
    }
}

- (void)typingDotsIntervalTimerEvent
{
    if (_typingDotsShortTimer != nil)
    {
        [_typingDotsShortTimer invalidate];
        _typingDotsShortTimer = nil;
    }
    
    _currentTypingDot = 0;
    [self typingDotsTimerEvent];
    
    NSTimeInterval interval = dotInterval();
    _typingDotsShortTimer = [[NSTimer alloc] initWithFireDate:[[NSDate alloc] initWithTimeIntervalSinceNow:interval] interval:interval target:self selector:@selector(typingDotsTimerEvent) userInfo:nil repeats:true];
    [[NSRunLoop mainRunLoop] addTimer:_typingDotsShortTimer forMode:NSRunLoopCommonModes];
}

- (void)createActionPanel
{
    if (_actionsPanel != nil)
        return;
    
    _actionsPanel = [[TGConversationActionsPanel alloc] initWithFrame:CGRectMake(0, self.controllerInset.top, self.view.frame.size.width, self.view.frame.size.height) type:_conversationCompanion.isMultichat && !_conversationCompanion.isEncrypted ? TGConversationActionsPanelTypeMutichat : TGConversationActionsPanelTypeUser];
    _actionsPanel.watcherHandle = _actionHandle;
    _actionsPanel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_actionsPanel];
    
    if ((!_conversationCompanion.isMultichat && !_conversationCompanion.isBroadcast) || _conversationCompanion.isEncrypted)
    {
        if (_chatSingleParticipant != nil)
        {
            TGUser *user = _chatSingleParticipant;
            [_actionsPanel setIsCallingAllowed:(user.phoneNumber != nil && user.phoneNumber.length != 0)];
        }
        
        [_actionsPanel setIsBlockAllowed:!_isContact];
        [_actionsPanel setUserIsBlocked:_userBlocked];
    }
    else if (_conversationCompanion.isMultichat)
    {
        [_actionsPanel setIsMuted:_conversationMuted];
    }
    
    [_actionsPanel setIsEditingAllowed:_listModel.count != 0];
}

- (void)setActionsPanelOpened:(bool)opened animated:(bool)animated
{
    if ((opened && (_actionsPanel == nil || !_actionsPanel.isBeingShown)) || (!opened && _actionsPanel != nil && _actionsPanel.isBeingShown))
    {
        if (_actionsPanel == nil)
            [self createActionPanel];
        
        if (opened)
            [_actionsPanel show:animated];
        else
            [_actionsPanel hide:animated];
        
        [TGViewController disableAutorotationFor:0.3 + 0.05];
    }
}

- (void)updateUnreadCount
{
    if (_unreadCount <= 0)
        _unreadCountContainer.hidden = true;
    else
    {
        NSString *text = nil;
        if (_unreadCount < 1000)
            text = [[NSString alloc] initWithFormat:@"%d", _unreadCount];
        else if (_unreadCount < 1000000)
            text = [[NSString alloc] initWithFormat:@"%dK", _unreadCount / 1000];
        else
            text = [[NSString alloc] initWithFormat:@"%dM", _unreadCount / 1000000];
        
        _unreadCountLabel.text = text;
        _unreadCountContainer.hidden = false;
        
        CGRect frame = _unreadCountBadge.frame;
        int textWidth = (int)[text sizeWithFont:_unreadCountLabel.font constrainedToSize:_unreadCountLabel.bounds.size lineBreakMode:NSLineBreakByTruncatingTail].width;
        frame.size.width = MAX(25, textWidth + 18);
        frame.origin.x = _unreadCountBadge.superview.frame.size.width - frame.size.width;
        _unreadCountBadge.frame = frame;
        
        CGRect labelFrame = _unreadCountLabel.frame;
        labelFrame.origin.x = 9 + frame.origin.x;
        _unreadCountLabel.frame = labelFrame;
    }
}

- (void)updateTitle:(bool)animated
{
    [self updateTitle:self.interfaceOrientation animated:animated];
}

- (void)updateTitle:(UIInterfaceOrientation)orientation animated:(bool)animated
{
    bool isLandscape = UIDeviceOrientationIsLandscape(orientation);
    
    if (_synchronizationStatus == TGConversationControllerSynchronizationStateNone)
    {
        _titleLabelsContainer.hidden = false;
    }
    else
    {
        _titleLabelsContainer.hidden = true;
        
        CGRect titleStatusContainerFrame = _titleStatusContainer.frame;
        titleStatusContainerFrame.origin.y = isLandscape ? 3 : 5;
        _titleStatusContainer.frame = titleStatusContainerFrame;
    }
    
    [_titleTextLabel setLandscape:isLandscape];
    [_titleStatusLabelNormal setLandscape:isLandscape];
    [_titleStatusLabelTyping setLandscape:isLandscape];
    
    CGRect unreadContainerFrame = _unreadCountContainer.frame;
    if (unreadContainerFrame.origin.y != UIInterfaceOrientationIsPortrait(orientation) ? -7 : -5)
    {
        unreadContainerFrame.origin.y = UIInterfaceOrientationIsPortrait(orientation) ? -7 : -5;
        _unreadCountContainer.frame = unreadContainerFrame;
    }
    
    CGSize screenSize = [TGViewController screenSizeForInterfaceOrientation:orientation];
    
    int leftButtonWidth = (int)(self.navigationItem.leftBarButtonItem.customView.frame.size.width) + 13;
    int rightButtonWidth = (int)(self.navigationItem.rightBarButtonItem.customView.frame.size.width + 13);
    int titleMaxWidth = (int)(screenSize.width - leftButtonWidth - rightButtonWidth - 8);
    int subtitleMaxWidth = titleMaxWidth;
    
    bool isEncrypted = _conversationCompanion.isEncrypted;
    if (isEncrypted)
    {
        titleMaxWidth -= 10;
        
        if (_titleLockIcon == nil)
        {
            _titleLockIcon = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"HeaderEncryptedChatIcon.png"]];
            _titleLockIcon.frame = CGRectOffset(_titleLockIcon.frame, -15, 4);
            _titleTextLabel.clipsToBounds = false;
            [_titleTextLabel addSubview:_titleLockIcon];
        }
    }
    
    if (_messageLifetime != 0)
    {
        titleMaxWidth -= 40;
        if (_titleLifetimeContainer == nil)
        {
            _titleLifetimeContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 2, 2)];
            [_titleTextLabel addSubview:_titleLifetimeContainer];
            
            UIImageView *timerIcon = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"ConversationTimerIcon.png"]];
            [_titleLifetimeContainer addSubview:timerIcon];
            
            _titleLifetimeLabel = [[UILabel alloc] init];
            _titleLifetimeLabel.font = [UIFont boldSystemFontOfSize:10];
            _titleLifetimeLabel.backgroundColor = [UIColor clearColor];
            _titleLifetimeLabel.textColor = UIColorRGB(0xc9dcf2);
            _titleLifetimeLabel.shadowColor = UIColorRGB(0x587da3);
            _titleLifetimeLabel.shadowOffset = CGSizeMake(0, -1);
            [_titleLifetimeContainer addSubview:_titleLifetimeLabel];
        }
        
        NSString *lifetimeText = @"";
        
        if (_messageLifetime <= 2)
            lifetimeText = TGLocalized(@"Profile.MessageLifetime2s");
        else if (_messageLifetime <= 5)
            lifetimeText = TGLocalized(@"Profile.MessageLifetime5s");
        else if (_messageLifetime <= 1 * 60)
            lifetimeText = TGLocalized(@"Profile.MessageLifetime1m");
        else if (_messageLifetime <= 60 * 60)
            lifetimeText = TGLocalized(@"Profile.MessageLifetime1h");
        else if (_messageLifetime <= 24 * 60 * 60)
            lifetimeText = TGLocalized(@"Profile.MessageLifetime1d");
        else if (_messageLifetime <= 7 * 24 * 60 * 60)
            lifetimeText = TGLocalized(@"Profile.MessageLifetime1w");
        
        _titleLifetimeLabel.text = lifetimeText;
        [_titleLifetimeLabel sizeToFit];
        _titleLifetimeLabel.frame = CGRectMake(12, 0, _titleLifetimeLabel.frame.size.width, _titleLifetimeLabel.frame.size.height);
    }
    else if (_titleLifetimeContainer != nil)
    {
        _titleLifetimeContainer.hidden = true;
    }

    if (_appearingAnimation || !isLandscape)
        animated = false;
    
    float retinaPixel = (TGIsRetina() ? 0.5f : 0.0f);
    
    if (!isLandscape)
    {
        float titleOffset = -1;
        if (isEncrypted)
            titleOffset -= 5;
        if (_messageLifetime != 0)
            titleOffset += 4;
        
        float subtitleOffset = -1;
        float titleOffsetY = iosMajorVersion() >= 7 ? (2.0f - retinaPixel) : 0.0f;
        
        float titleTextMaxWidth = titleMaxWidth;
        
        if (_doneButton != nil && _doneButton.alpha > FLT_EPSILON)
            titleTextMaxWidth -= 30;
        
        _titleTextLabel.frame = CGRectMake(0, 0, titleTextMaxWidth, isLandscape ? 32 : 44);
        CGSize titleTextSize = [_titleTextLabel.text sizeWithFont:_titleTextLabel.font constrainedToSize:CGSizeMake(titleTextMaxWidth * 1000, 100) lineBreakMode:NSLineBreakByTruncatingTail];
        titleTextSize.width = MIN(titleTextSize.width, titleTextMaxWidth);
        [_titleTextLabel sizeToFit];
        _titleTextLabel.frame = CGRectMake(0, 0, titleTextSize.width, _titleTextLabel.frame.size.height);
        CGRect titleLabelFrame = _titleTextLabel.frame;
        if (titleLabelFrame.size.width > titleTextMaxWidth)
            titleLabelFrame.size.width = titleTextMaxWidth;
        if (((int)(titleLabelFrame.size.width)) % 2 != 0)
            titleLabelFrame.size.width += 1;
        
        _titleStatusLabelNormal.frame = CGRectMake(0, 0, subtitleMaxWidth, isLandscape ? 32 : 44);
        [_titleStatusLabelNormal sizeToFit];
        CGRect titleStatusLabelNormalFrame = _titleStatusLabelNormal.frame;
        if (((int)(titleStatusLabelNormalFrame.size.width)) % 2 != 0)
            titleStatusLabelNormalFrame.size.width += 1;
        
        _titleStatusLabelTyping.frame = CGRectMake(0, 0, subtitleMaxWidth - 26, isLandscape ? 32 : 44);
        [_titleStatusLabelTyping sizeToFit];
        _titleStatusLabelTyping.frame = CGRectMake(0, 0, [_titleStatusLabelTyping.text sizeWithFont:_titleStatusLabelTyping.font constrainedToSize:CGSizeMake(subtitleMaxWidth - 26, 100) lineBreakMode:_titleStatusLabelTyping.lineBreakMode].width, _titleStatusLabelTyping.frame.size.height);
        CGRect titleStatusLabelTypingFrame = _titleStatusLabelTyping.frame;
        if (((int)(titleStatusLabelTypingFrame.size.width)) % 2 != 0)
            titleStatusLabelTypingFrame.size.width += 1;
        
        CGRect currentTitleStatusFrame = _titleStatusLabelNormal.alpha > FLT_EPSILON ? _titleStatusLabelNormal.frame : (CGRectInset(_titleStatusLabelTyping.frame, _titleStatusLabelTyping.frame.size.width > 22 ? 10 : 0, 0));
        
        CGRect titleContainerFrame = CGRectMake(0, _titleContainer.frame.origin.y, MAX(titleLabelFrame.size.width, currentTitleStatusFrame.size.width), MIN(titleLabelFrame.size.height + currentTitleStatusFrame.size.height, isLandscape ? 32 : 44));
        if (((int)(titleContainerFrame.size.width)) % 2 != 0)
            titleContainerFrame.size.width += 1;
        
        titleContainerFrame.origin.x = floorf((screenSize.width - titleContainerFrame.size.width) / 2);
        if (titleContainerFrame.origin.x < leftButtonWidth)
            titleContainerFrame.origin.x = leftButtonWidth;
        
        titleLabelFrame.origin.y = -2 + titleOffsetY;
        titleLabelFrame.origin.x = floorf(((titleContainerFrame.size.width - titleLabelFrame.size.width) / 2.0f) - titleOffset);
        if (titleLabelFrame.size.width >= titleMaxWidth && _messageLifetime == 0)
            titleLabelFrame.origin.x += 12;
        titleStatusLabelNormalFrame.origin.x = floorf(((titleContainerFrame.size.width - titleStatusLabelNormalFrame.size.width) / 2.0f) - subtitleOffset);
        
        titleStatusLabelTypingFrame.origin.x = floorf(((titleContainerFrame.size.width - titleStatusLabelTypingFrame.size.width - 20) / 2.0f) - subtitleOffset + 20);
        
        titleStatusLabelNormalFrame.origin.y = titleContainerFrame.size.height - titleStatusLabelNormalFrame.size.height - 3 + retinaPixel + titleOffsetY;
        titleStatusLabelTypingFrame.origin.y = titleStatusLabelNormalFrame.origin.y;
        
        if (_muteIconView != nil && !_muteIconView.hidden)
        {
            titleLabelFrame.origin.x -= 3;
            
            CGRect muteFrame = _muteIconView.frame;
            muteFrame.origin.x = titleLabelFrame.origin.x + titleLabelFrame.size.width + 4;
            muteFrame.origin.y = titleLabelFrame.origin.y + 6;
            _muteIconView.frame = muteFrame;
        }

        _titleTextLabel.frame = CGRectIntegral(titleLabelFrame);
        _titleStatusLabelNormal.frame = CGRectIntegral(titleStatusLabelNormalFrame);
        _titleStatusLabelTyping.frame = CGRectIntegral(titleStatusLabelTypingFrame);
        
        if (_titleLifetimeContainer != nil)
            _titleLifetimeContainer.frame = CGRectMake(titleLabelFrame.size.width + 4 + (_muteIconView != nil && !_muteIconView.hidden ? 13 : 0), 5 - retinaPixel, 2, 2);
        
        dispatch_block_t block = ^
        {
            _titleContainer.frame = CGRectIntegral(titleContainerFrame);
        };
        if (animated)
            [UIView animateWithDuration:0.3 animations:block];
        else
            block();
    }
    else
    {
        float titleOffsetY = iosMajorVersion() >= 7 ? 1.0f : 0.0f;
        
        int titleSpacing = 6;
        subtitleMaxWidth = titleMaxWidth * 2 / 5;
        titleMaxWidth = titleMaxWidth - subtitleMaxWidth;
        
        subtitleMaxWidth -= titleSpacing / 2;
        titleMaxWidth -= titleSpacing / 2;
        
        _titleTextLabel.frame = CGRectMake(0, 0, titleMaxWidth, isLandscape ? 32 : 44);
        [_titleTextLabel sizeToFit];
        CGRect titleLabelFrame = _titleTextLabel.frame;
        if (titleLabelFrame.size.width > titleMaxWidth)
            titleLabelFrame.size.width = titleMaxWidth;
        if (((int)(titleLabelFrame.size.width)) % 2 != 0)
            titleLabelFrame.size.width += 1;
        
        _titleStatusLabelNormal.frame = CGRectMake(0, 0, subtitleMaxWidth, isLandscape ? 32 : 44);
        [_titleStatusLabelNormal sizeToFit];
        CGRect titleStatusLabelNormalFrame = _titleStatusLabelNormal.frame;
        if (((int)(titleStatusLabelNormalFrame.size.width)) % 2 != 0)
            titleStatusLabelNormalFrame.size.width += 1;
        
        _titleStatusLabelTyping.frame = CGRectMake(0, 0, subtitleMaxWidth - 20, isLandscape ? 32 : 44);
        [_titleStatusLabelTyping sizeToFit];
        CGRect titleStatusLabelTypingFrame = _titleStatusLabelTyping.frame;
        if (((int)(titleStatusLabelTypingFrame.size.width)) % 2 != 0)
            titleStatusLabelTypingFrame.size.width += 1;
        
        CGRect currentTitleStatusFrame = _titleStatusLabelNormal.alpha > FLT_EPSILON ? _titleStatusLabelNormal.frame : CGRectInset(_titleStatusLabelTyping.frame, -10, 0);
        
        CGRect titleContainerFrame = CGRectMake(0, _titleContainer.frame.origin.y, titleLabelFrame.size.width + titleSpacing + currentTitleStatusFrame.size.width, MIN(titleLabelFrame.size.height + currentTitleStatusFrame.size.height, isLandscape ? 32 : 44));
        
        titleContainerFrame.origin.x = (int)(screenSize.width - titleContainerFrame.size.width) / 2;
        if (titleContainerFrame.origin.x < leftButtonWidth)
            titleContainerFrame.origin.x = leftButtonWidth;
        
        titleLabelFrame.origin.x = 0;
        titleLabelFrame.origin.y = (int)((titleContainerFrame.size.height - titleLabelFrame.size.height) / 2) - 1 - (TGIsRetina() ? 0.5f : 0) + titleOffsetY;
        
        titleStatusLabelNormalFrame.origin.x = titleLabelFrame.size.width + titleSpacing;
        titleStatusLabelTypingFrame.origin.x = titleLabelFrame.size.width + titleSpacing + 20;
        
        titleStatusLabelNormalFrame.origin.y = (int)((titleContainerFrame.size.height - titleStatusLabelNormalFrame.size.height) / 2) - 1 + (TGIsRetina() ? 0.5f : 0);
        titleStatusLabelTypingFrame.origin.y = titleStatusLabelNormalFrame.origin.y;
        
        if (_messageLifetime != 0)
        {
            titleLabelFrame.origin.x -= 8;
            titleStatusLabelNormalFrame.origin.x += 19;
            titleStatusLabelTypingFrame.origin.x += 19;
        }
        
        if (_muteIconView != nil && !_muteIconView.hidden)
        {
            titleLabelFrame.origin.x -= 5;
            titleStatusLabelNormalFrame.origin.x += 5;
            titleStatusLabelTypingFrame.origin.x += 5;
            
            CGRect muteFrame = _muteIconView.frame;
            muteFrame.origin.x = titleLabelFrame.origin.x + titleLabelFrame.size.width + 2;
            muteFrame.origin.y = titleLabelFrame.origin.y + 6;
            _muteIconView.frame = muteFrame;
        }
        
        _titleTextLabel.frame = titleLabelFrame;
        
        _titleStatusLabelNormal.frame = titleStatusLabelNormalFrame;
        _titleStatusLabelTyping.frame = titleStatusLabelTypingFrame;
        
        if (_titleLifetimeContainer != nil)
            _titleLifetimeContainer.frame = CGRectMake(titleLabelFrame.size.width + 4 + (_muteIconView != nil && !_muteIconView.hidden ? 10 : 0), 4, 2, 2);
        
        dispatch_block_t block = ^
        {
            _titleContainer.frame = CGRectIntegral(titleContainerFrame);
        };
        if (animated)
            [UIView animateWithDuration:0.3 animations:block];
        else
            block();
    }
    
    CGSize avatarSize = [_conversationCompanion titleAvatarSize:(UIDeviceOrientation)orientation];
    _avatarOverlayView.image = [_conversationCompanion titleAvatarOverlay:orientation];
    
    _avatarImageView.frame = isLandscape ? CGRectMake(13, 6.5f, avatarSize.width, avatarSize.height) : CGRectMake(3, TGIsRetina() ? 1.5f : 1.0f, avatarSize.width, avatarSize.height);
    _avatarOverlayView.frame = isLandscape ? CGRectMake(-1, -0.5f, avatarSize.width + 2, avatarSize.height + 2) : CGRectMake(-2.0f, -1.5f, avatarSize.width + 4, avatarSize.height + 4);
}

- (void)updateMetrics:(UIInterfaceOrientation)orientation
{
    int metrics = 0;
    if (UIInterfaceOrientationIsLandscape(orientation))
        metrics |= TGConversationMessageMetricsLandscape;
    else
        metrics |= TGConversationMessageMetricsPortrait;
    if (_conversationCompanion.isMultichat && !_conversationCompanion.isEncrypted)
        metrics |= TGConversationMessageMetricsShowAvatars;
    _messageMetrics = metrics;
}

- (void)updateMetrics
{
    [self updateMetrics:self.interfaceOrientation];
}

#pragma mark - Interface logic

- (void)performCloseConversation
{
    lastConversationIdForBackAction = _conversationCompanion.conversationId;
    
    [self.navigationController popViewControllerAnimated:true];
}

- (bool)navigationBarHasAction
{
    return !_conversationCompanion.isBroadcast && !_disableTitleArrow &&
#if TGUseCollectionView
    true;
#else
    !_tableView.isEditing;
#endif
}

- (void)navigationBarAction
{
    if (_conversationCompanion.isBroadcast)
        return;
    if (_disableTitleArrow)
        return;
    
#if TGUseCollectionView
#else
    if (_tableView.isEditing)
        return;
#endif
    
    bool isActionsPanelOpened = _actionsPanel != nil && _actionsPanel.isBeingShown;
    
    [self setActionsPanelOpened:!isActionsPanelOpened animated:true];
    
    [_menuContainerView hideMenu];
    [_dateTooltipContainerView hideTooltip];
}

- (void)navigationBarSwipeDownAction
{
    bool isActionsPanelOpened = _actionsPanel != nil && _actionsPanel.isBeingShown;
    
    if (!isActionsPanelOpened)
        [self navigationBarAction];
}

- (void)attachButtonPressed:(id)__unused sender
{
    _currentActionSheet.delegate = nil;
    
    NSMutableDictionary *mapping = [[NSMutableDictionary alloc] init];
    
    _currentActionSheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
    [mapping setObject:@"takePhotoOrVideo" forKey:[[NSNumber alloc] initWithInt:[_currentActionSheet addButtonWithTitle:TGLocalized(@"Common.TakePhotoOrVideo")]]];
    [mapping setObject:@"choosePhoto" forKey:[[NSNumber alloc] initWithInt:[_currentActionSheet addButtonWithTitle:TGLocalized(@"Common.ChoosePhoto")]]];
    [mapping setObject:@"searchWeb" forKey:[[NSNumber alloc] initWithInt:[_currentActionSheet addButtonWithTitle:TGLocalized(@"Conversation.SearchWebImages")]]];
    [mapping setObject:@"chooseVideo" forKey:[[NSNumber alloc] initWithInt:[_currentActionSheet addButtonWithTitle:TGLocalized(@"Common.ChooseVideo")]]];
    [mapping setObject:@"location" forKey:[[NSNumber alloc] initWithInt:[_currentActionSheet addButtonWithTitle:TGLocalized(@"Conversation.Location")]]];
    _currentActionSheet.cancelButtonIndex = [_currentActionSheet addButtonWithTitle:TGLocalized(@"Common.Cancel")];
    _currentActionSheet.tag = TGConversationControllerAttachmentDialogTag;
    
    _currentActionSheetMapping = mapping;
    
    [_currentActionSheet showInView:self.view];
    
    _assetsLibraryHolder = [TGImagePickerController preloadLibrary];
}

- (NSString *)clearTextFromWhitespace:(NSString *)string
{
    NSString *withoutWhitespace = [string stringByReplacingOccurrencesOfString:@" +" withString:@" "
                                                                       options:NSRegularExpressionSearch
                                                                         range:NSMakeRange(0, string.length)];
    withoutWhitespace = [withoutWhitespace stringByReplacingOccurrencesOfString:@"\n\n+" withString:@"\n\n"
                                                                        options:NSRegularExpressionSearch
                                                                          range:NSMakeRange(0, withoutWhitespace.length)];
    return [withoutWhitespace stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (void)sendButtonPressed:(id)__unused sender
{
    if (!_sendButton.userInteractionEnabled)
        return;
    
    if ([_inputField isFirstResponder])
    {
        _isRotating = true;
        [_inputField resignFirstResponder];
        [_inputField becomeFirstResponder];
        _isRotating = false;
    }
    
    /*if ([self shouldShowPhoneNumberWarning])
    {   
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:nil message:[[NSString alloc] initWithFormat:@"Note that once you start messaging with %@, %@ will see your mobile number.", _chatSingleParticipant.displayName, _chatSingleParticipant.displayName] delegate:self cancelButtonTitle:TGLocalized(@"Common.Cancel") otherButtonTitles:@"It's OK", nil];
        alertView.tag = TGMessageWarningAlertTag;
        [alertView show];
        
        return;
    }*/
    
    NSString *text = [self clearTextFromWhitespace:_inputField.text];
    if (text.length != 0)
    {
        [_conversationCompanion sendMessage:text attachments:nil clearText:true];
    }
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (alertView.tag == TGMessageWarningAlertTag)
    {
        if (buttonIndex != alertView.cancelButtonIndex)
        {
            _onceShownMessageWarning = true;
            
            //[self sendButtonPressed:_sendButton];
        }
    }
    else if (alertView.tag == TGPasteImagesAlertTag)
    {
        if (buttonIndex != alertView.cancelButtonIndex)
        {
            NSMutableArray *attachments = [[NSMutableArray alloc] init];
            
            for (UIImage *image in _preparedImages)
            {
                @autoreleasepool
                {
                    TGImageInputMediaAttachment *attachment = [_conversationCompanion createImageAttachmentFromImage:image assetUrl:nil];
                    if (attachment != nil)
                    {
                        [attachments addObject:[[NSArray alloc] initWithObjects:attachment, nil]];
                    }
                }
            }
            
            _preparedImages = nil;
            
            if (attachments != nil)
            {
                [_conversationCompanion sendMediaMessages:attachments clearText:false];
            }
        }
    }
}

static UIImagePickerControllerCameraFlashMode defaultFlashMode = UIImagePickerControllerCameraFlashModeAuto;

- (void)attachCameraPressed
{
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera])
        return;
    
    [self closeKeyboard];
    
    [self prepareStatusBarForCamera];
    
    UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
    imagePicker.sourceType = UIImagePickerControllerSourceTypeCamera;
    imagePicker.mediaTypes = [[NSArray alloc] initWithObjects:(__bridge NSString *)kUTTypeImage, (__bridge NSString *)kUTTypeMovie, nil];
    imagePicker.cameraFlashMode = defaultFlashMode;
    imagePicker.delegate = self;
    [self presentViewController:imagePicker animated:true completion:nil];
}

- (void)attachGalleryPressed
{
    [self showImageGalleryPicker:false];
}

- (void)attachSearchWebPressed
{
    [self showImageGalleryPicker:true];
}

- (void)showImageGalleryPicker:(bool)openWebSearch
{
    [self closeKeyboard];
    
    NSMutableArray *controllerList = [[NSMutableArray alloc] init];
    
    TGImageSearchController *searchController = [[TGImageSearchController alloc] init];
    searchController.autoActivateSearch = openWebSearch;
    searchController.delegate = self;
    [controllerList addObject:searchController];
    
    if (!openWebSearch)
    {
        TGImagePickerController *imagePicker = [[TGImagePickerController alloc] initWithGroupUrl:nil groupTitle:nil avatarSelection:false];
        imagePicker.delegate = self;
        
        [controllerList addObject:imagePicker];
    }
    
    UIViewController *topViewController = [controllerList lastObject];
    
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackTranslucent animated:true];
    
    TGNavigationController *navigationController = [TGNavigationController navigationControllerWithControllers:controllerList];
    
    [topViewController view];
    
    [TGViewController disableUserInteractionFor:0.2];
    TGDispatchAfter([TGViewController isWidescreen] ? 0 : 0.2, dispatch_get_main_queue(), ^
    {
        if (iosMajorVersion() <= 5)
        {
            [TGViewController disableAutorotationFor:0.45];
            [topViewController view];
            [topViewController viewWillAppear:false];
            
            CGSize screenSize = [TGViewController screenSizeForInterfaceOrientation:self.interfaceOrientation];
            navigationController.view.frame = CGRectMake(0, screenSize.height, screenSize.width, screenSize.height);
            [self.navigationController.view addSubview:navigationController.view];
            
            [UIView animateWithDuration:0.45 animations:^
            {
                navigationController.view.frame = CGRectMake(0, 0, screenSize.width, screenSize.height);
            } completion:^(BOOL finished)
            {
                [navigationController.view removeFromSuperview];
                if (finished)
                {
                    [topViewController viewWillDisappear:false];
                    [topViewController viewDidDisappear:false];
                    [self presentViewController:navigationController animated:false completion:nil];
                }
            }];
        }
        else
        {
            [self presentViewController:navigationController animated:true completion:nil];
        }
    });
}

- (void)growingTextView:(HPGrowingTextView *)__unused growingTextView didPasteImages:(NSArray *)images
{
    _alertProxy = [[TGAlertDelegateProxy alloc] initWithTarget:self];
    
#warning localize
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:nil message:[[NSString alloc] initWithFormat:@"Send %d image%s?", images.count, images.count == 1 ? "" : "s"] delegate:_alertProxy cancelButtonTitle:TGLocalized(@"Common.Cancel") otherButtonTitles:TGLocalized(@"Common.OK"), nil];
    alertView.tag = TGPasteImagesAlertTag;
    [alertView show];
    
    _preparedImages = images;
}

- (NSString *)_dictionaryString:(NSDictionary *)dict
{
    NSMutableString *string = [[NSMutableString alloc] init];
    
    [dict enumerateKeysAndObjectsUsingBlock:^(id key, id value, __unused BOOL *stop)
    {
        if ([key isKindOfClass:[NSString class]])
            [string appendString:key];
        else if ([key isKindOfClass:[NSNumber class]])
            [string appendString:[key description]];
        [string appendString:@":"];
        
        if ([value isKindOfClass:[NSString class]])
            [string appendString:value];
        else if ([value isKindOfClass:[NSNumber class]])
            [string appendString:[value description]];
        else if ([value isKindOfClass:[NSDictionary class]])
        {
            [string appendString:@"{"];
            [string appendString:[self _dictionaryString:value]];
            [string appendString:@"}"];
        }
        
        [string appendString:@";"];
    }];
    
    return string;
}

- (void)imagePickerController:(TGImagePickerController *)imagePicker didFinishPickingWithAssets:(NSArray *)assets
{    
    if (assets.count != 0)
    {
        TGProgressWindow *progressWindow = [[TGProgressWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
        [progressWindow show:true];
        
        [ActionStageInstance() dispatchOnStageQueue:^
        {
            NSMutableArray *attachments = [[NSMutableArray alloc] init];
            for (id object in assets)
            {
                if ([object isKindOfClass:[TGImagePickerAsset class]])
                {
                    @autoreleasepool
                    {
                        TGImagePickerAsset *asset = object;
                        
                        CC_MD5_CTX md5;
                        CC_MD5_Init(&md5);
                        
                        NSData *metadataData = [[self _dictionaryString:asset.asset.defaultRepresentation.metadata] dataUsingEncoding:NSUTF8StringEncoding];
                        CC_MD5_Update(&md5, [metadataData bytes], metadataData.length);
                        
                        NSData *uriData = [asset.assetUrl dataUsingEncoding:NSUTF8StringEncoding];
                        CC_MD5_Update(&md5, [uriData bytes], uriData.length);
                        
                        int64_t size = asset.asset.defaultRepresentation.size;
                        const int64_t batchSize = 4 * 1024;
                        
                        uint8_t *buf = (uint8_t *)malloc(batchSize);
                        NSError *error = nil;
                        for (int64_t offset = 0; offset < batchSize; offset += batchSize)
                        {
                            NSUInteger length = [asset.asset.defaultRepresentation getBytes:buf fromOffset:offset length:((NSUInteger)(MIN(batchSize, size - offset))) error:&error];
                            CC_MD5_Update(&md5, buf, length);
                        }
                        free(buf);
                        
                        unsigned char md5Buffer[16];
                        CC_MD5_Final(md5Buffer, &md5);
                        NSString *hash = [[NSString alloc] initWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x", md5Buffer[0], md5Buffer[1], md5Buffer[2], md5Buffer[3], md5Buffer[4], md5Buffer[5], md5Buffer[6], md5Buffer[7], md5Buffer[8], md5Buffer[9], md5Buffer[10], md5Buffer[11], md5Buffer[12], md5Buffer[13], md5Buffer[14], md5Buffer[15]];
                        
                        TGImageInputMediaAttachment *attachment = [_conversationCompanion createImageAttachmentFromImage:[[UIImage alloc] initWithCGImage:asset.asset.defaultRepresentation.fullScreenImage] assetUrl:hash];
                        if (attachment != nil)
                        {
                            [attachments addObject:[[NSArray alloc] initWithObjects:attachment, nil]];
                        }
                    }
                }
                else if ([object isKindOfClass:[UIImage class]])
                {
                    @autoreleasepool
                    {
                        TGImageInputMediaAttachment *attachment = [_conversationCompanion createImageAttachmentFromImage:object assetUrl:nil];
                        if (attachment != nil)
                        {
                            [attachments addObject:[[NSArray alloc] initWithObjects:attachment, nil]];
                        }
                    }
                }
                else if ([object isKindOfClass:[NSString class]])
                {
                    @autoreleasepool
                    {
                        UIImage *image = [[TGRemoteImageView sharedCache] cachedImage:object availability:TGCacheDisk];
                        
                        if (image != nil)
                        {
                            TGImageInputMediaAttachment *attachment = [_conversationCompanion createImageAttachmentFromImage:image assetUrl:nil];
                            if (attachment != nil)
                            {
                                [attachments addObject:[[NSArray alloc] initWithObjects:attachment, nil]];
                            }
                        }
                        else
                        {
                            TGLog(@"Image not ready");
                        }
                    }
                }
            }
            
            if (attachments != nil)
            {   
                [_conversationCompanion sendMediaMessages:attachments clearText:false];
            }
            
            dispatch_async(dispatch_get_main_queue(), ^
            {
                [progressWindow dismiss:true];
                
                [self dismissViewControllerAnimated:true completion:nil];
                
                [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackOpaque animated:true];
                
                // keep reference
                [imagePicker description];
            });
        }];
    }
    else
    {
        [self dismissViewControllerAnimated:true completion:nil];
        
        [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackOpaque animated:true];
    }
}

static dispatch_queue_t videoProcessingQueue()
{
    static dispatch_queue_t queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        queue = dispatch_queue_create("com.conversationkit.videoencoding", 0);
    });
    return queue;
}

- (void)prepareStatusBarForCamera
{
    if ([[UIApplication sharedApplication] conformsToProtocol:@protocol(TGApplicationImpl)])
        [(id<TGApplicationImpl>)[UIApplication sharedApplication] setProcessStatusBarHiddenRequests:true];
}

- (void)resetStatusBarAfterCameraCompleted
{
    if ([[UIApplication sharedApplication] isStatusBarHidden])
        [[UIApplication sharedApplication] setStatusBarHidden:false withAnimation:UIStatusBarAnimationSlide];
    
    if ([[UIApplication sharedApplication] conformsToProtocol:@protocol(TGApplicationImpl)])
        [(id<TGApplicationImpl>)[UIApplication sharedApplication] setProcessStatusBarHiddenRequests:false];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    NSString *mediaType = [info objectForKey:UIImagePickerControllerMediaType];
    NSURL *assetUrl = [info valueForKey:UIImagePickerControllerReferenceURL];
    
    if ([mediaType isEqualToString:(__bridge NSString *)kUTTypeImage])
    {
        if (picker.sourceType == UIImagePickerControllerSourceTypeCamera)
            defaultFlashMode = picker.cameraFlashMode;
        
        UIImage *fullImage = [info objectForKey:UIImagePickerControllerOriginalImage];
        TGImageInputMediaAttachment *attachment = [_conversationCompanion createImageAttachmentFromImage:fullImage assetUrl:[assetUrl absoluteString]];
        if (attachment.imageData != nil)
            [TGImagePickerController storeImageAsset:attachment.imageData];
        else if (attachment.image != nil && !_conversationCompanion.isEncrypted)
            UIImageWriteToSavedPhotosAlbum(attachment.image, nil, nil, NULL);
        
        [_conversationCompanion sendMessage:nil attachments:[NSArray arrayWithObject:attachment] clearText:false];
        
        [self dismissViewControllerAnimated:true completion:nil];
        
        [self resetStatusBarAfterCameraCompleted];
    }
    else if ([mediaType isEqualToString:(__bridge NSString *)kUTTypeMovie])
    {
        NSURL *mediaUrl = [info objectForKey:UIImagePickerControllerMediaURL];
        TGLog(@"%@", mediaUrl);
        
        NSString *assetHash = nil;
        
        if ([assetUrl absoluteString].length != 0)
        {
            NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[mediaUrl path] error:nil];
            int64_t size = [[attributes objectForKey:NSFileSize] intValue];
            
            if (size != 0)
            {
                CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
                NSInputStream *is = [[NSInputStream alloc] initWithFileAtPath:mediaUrl.path];
                [is open];
                if ([is streamStatus] == NSStreamStatusOpen)
                {
                    const int64_t batchSize = 200 * 1024;
                    
                    CC_MD5_CTX md5;
                    CC_MD5_Init(&md5);
                    uint8_t *buf = (uint8_t *)malloc(batchSize);
                    bool useForHash = true;
                    for (int64_t offset = 0; offset < size; offset += batchSize)
                    {
                        int length = [is read:buf maxLength:((NSUInteger)MIN(batchSize, size - offset))];
                        if (useForHash || length < batchSize)
                            CC_MD5_Update(&md5, buf, length);
                        
                        useForHash = !useForHash;
                    }
                    free(buf);
                    
                    [is close];
                    
                    unsigned char md5Buffer[16];
                    CC_MD5_Final(md5Buffer, &md5);
                    assetHash = [[NSString alloc] initWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x", md5Buffer[0], md5Buffer[1], md5Buffer[2], md5Buffer[3], md5Buffer[4], md5Buffer[5], md5Buffer[6], md5Buffer[7], md5Buffer[8], md5Buffer[9], md5Buffer[10], md5Buffer[11], md5Buffer[12], md5Buffer[13], md5Buffer[14], md5Buffer[15]];
                }
                TGLog(@"Hash time: %f ms (%@)", (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0, assetHash);
            }
        }
        
        bool deleteFile = true;
        
        if (picker.sourceType == UIImagePickerControllerSourceTypeCamera && !_conversationCompanion.isEncrypted)
        {
            UISaveVideoAtPathToSavedPhotosAlbum(mediaUrl.path, [self class], @selector(video:didFinishSavingWithError:contextInfo:), NULL);
            deleteFile = false;
        }
        
        NSString *videosPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true) objectAtIndex:0] stringByAppendingPathComponent:@"video"];
        static NSFileManager *fileManager = [[NSFileManager alloc] init];
        NSError *error = nil;
        [fileManager createDirectoryAtPath:videosPath withIntermediateDirectories:true attributes:nil error:&error];
        
        NSString *tmpPath = NSTemporaryDirectory();
        
        long fileId = 0;
        arc4random_buf(&fileId, sizeof(fileId));
        
        NSString *videoMp4FilePath = [tmpPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%lx.mp4", fileId]];
        
        TGProgressWindow *progressWindow = [[TGProgressWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
        [progressWindow show:true];
        
        [ActionStageInstance() dispatchOnStageQueue:^
        {
            if ([_conversationCompanion isAssetUrlOnServer:assetHash])
            {
                NSMutableArray *attachments = [[NSMutableArray alloc] init];
                TGVideoInputMediaAttachment *attachment = [_conversationCompanion createVideoAttachmentFromVideo:nil thumbnailImage:nil duration:0 dimensions:CGSizeZero assetUrl:assetHash];
                if (attachment != nil)
                    [attachments addObject:[[NSArray alloc] initWithObjects:attachment, nil]];
                
                if (attachments.count != 0)
                    [_conversationCompanion sendMediaMessages:attachments clearText:false];
                
                dispatch_async(dispatch_get_main_queue(), ^
                {
                    [progressWindow dismiss:true];
                    
                    [self dismissViewControllerAnimated:true completion:nil];
                    
                    [self resetStatusBarAfterCameraCompleted];
                });
            }
            else
            {
                void (^compressionCompletedBlock)(bool) = ^(bool success)
                {
                    [ActionStageInstance() dispatchOnStageQueue:^
                    {
                        if (success)
                        {
                            AVAsset *mp4Asset = [AVAsset assetWithURL:[NSURL fileURLWithPath:videoMp4FilePath]];
                            
                            AVAssetImageGenerator *imageGenerator = [[AVAssetImageGenerator alloc] initWithAsset:mp4Asset];
                            imageGenerator.maximumSize = CGSizeMake(800, 800);
                            imageGenerator.appliesPreferredTrackTransform = true;
                            NSError *imageError = nil;
                            CGImageRef imageRef = [imageGenerator copyCGImageAtTime:CMTimeMake(0, mp4Asset.duration.timescale) actualTime:NULL error:&imageError];
                            
                            if (error == nil)
                            {
                                if ([[mp4Asset tracksWithMediaType:AVMediaTypeVideo] count] > 0)
                                {
                                    AVAssetTrack *track = [[mp4Asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
                                    UIImage *previewImage = [[UIImage alloc] initWithCGImage:imageRef];
                                    UIImage *thumbnailImage = TGScaleImageToPixelSize(previewImage, TGFitSize(previewImage.size, CGSizeMake(200, 200)));
                                    
                                    CGSize naturalSize = track.naturalSize;
                                    naturalSize = CGRectApplyAffineTransform(CGRectMake(0, 0, naturalSize.width, naturalSize.height), track.preferredTransform).size;
                                    NSMutableArray *attachments = [[NSMutableArray alloc] init];
                                    TGVideoInputMediaAttachment *attachment = [_conversationCompanion createVideoAttachmentFromVideo:videoMp4FilePath thumbnailImage:thumbnailImage duration:(int)CMTimeGetSeconds(mp4Asset.duration) dimensions:naturalSize assetUrl:[assetUrl absoluteString]];
                                    attachment.previewData = UIImageJPEGRepresentation(previewImage, 0.87);
                                    if (attachment != nil)
                                        [attachments addObject:[[NSArray alloc] initWithObjects:attachment, nil]];
                                    
                                    
                                    if (attachments.count != 0)
                                        [_conversationCompanion sendMediaMessages:attachments clearText:false];
                                }
                            }
                            
                            if (imageRef != NULL)
                                CGImageRelease(imageRef);
                        }
                        
                        dispatch_async(dispatch_get_main_queue(), ^
                        {
                            [progressWindow dismiss:true];
                            
                            [self dismissViewControllerAnimated:true completion:nil];
                            
                            [self resetStatusBarAfterCameraCompleted];
                        });
                    }];
                };
                
                void (^movStoreCompletedBlock)(NSURL *) = ^(NSURL *movFileUrl)
                {
                    AVAsset *avAsset = [[AVURLAsset alloc] initWithURL:movFileUrl options:nil];
                    
                    AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:avAsset presetName:AVAssetExportPresetPassthrough];
                    
                    exportSession.outputURL = [NSURL fileURLWithPath:videoMp4FilePath];
                    exportSession.outputFileType = AVFileTypeMPEG4;
                    
                    [exportSession exportAsynchronouslyWithCompletionHandler:^
                    {
                        bool endProcessing = false;
                        bool success = false;
                        
                        switch ([exportSession status])
                        {
                            case AVAssetExportSessionStatusFailed:
                                NSLog(@"Export failed: %@", [[exportSession error] localizedDescription]);
                                endProcessing = true;
                                break;
                            case AVAssetExportSessionStatusCancelled:
                                endProcessing = true;
                                NSLog(@"Export canceled");
                                break;
                            case AVAssetExportSessionStatusCompleted:
                            {
                                TGLog(@"Export mp4 completed");
                                endProcessing = true;
                                success = true;
                                
                                break;
                            }
                            default:
                                break;
                        }
                        
                        if (endProcessing)
                        {
                            if (deleteFile)
                                [fileManager removeItemAtURL:movFileUrl error:nil];
                            
                            compressionCompletedBlock(success);
                        }
                    }];
                };
                
                movStoreCompletedBlock(mediaUrl);
            }
        }];
    }
}

+ (void)video:(NSString *)videoPath didFinishSavingWithError:(NSError *)error contextInfo:(void *)__unused contextInfo
{
    [[NSFileManager defaultManager] removeItemAtPath:videoPath error:nil];
    if (error != nil)
        TGLog(@"Video saving error: %@", error);
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)__unused picker
{
    if (picker.sourceType == UIImagePickerControllerSourceTypeCamera)
        defaultFlashMode = picker.cameraFlashMode;
    
    [self dismissViewControllerAnimated:true completion:nil];
    
    [self resetStatusBarAfterCameraCompleted];
}

- (void)attachLocationPressed
{
    [self closeKeyboard];
    
    TGMapViewController *mapViewController = [[TGMapViewController alloc] initInPickingMode];
    mapViewController.watcher = _actionHandle;
    TGNavigationController *mapNavigationController = [TGNavigationController navigationControllerWithRootController:mapViewController];
    [self presentViewController:mapNavigationController animated:true completion:nil];
}

- (void)attachVideoPressed
{
    [self closeKeyboard];
    
    [self prepareStatusBarForCamera];
    
    UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
    imagePicker.sourceType = UIImagePickerControllerSourceTypeCamera;
    imagePicker.mediaTypes = [[NSArray alloc] initWithObjects:(__bridge NSString *)kUTTypeMovie, nil];
    imagePicker.delegate = self;
    [imagePicker setVideoQuality:UIImagePickerControllerQualityType640x480];
    [self presentViewController:imagePicker animated:true completion:nil];
}

- (void)attachVideoGalleryPressed
{
    [self closeKeyboard];
    
    UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
    imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    imagePicker.mediaTypes = [[NSArray alloc] initWithObjects:(__bridge NSString *)kUTTypeMovie, nil];
    imagePicker.delegate = self;
    [imagePicker setVideoQuality:UIImagePickerControllerQualityType640x480];
    [self presentViewController:imagePicker animated:true completion:nil];
    
#if TARGET_IPHONE_SIMULATOR
    TGDispatchAfter(1.0, dispatch_get_main_queue(), ^
    {   
        NSString *tmpFile = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSString alloc] initWithFormat:@"%x.mov", arc4random()]];
        [[NSFileManager defaultManager] copyItemAtPath:[[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true) objectAtIndex:0] stringByAppendingPathComponent:@"example.mov"] toPath:tmpFile error:nil];
        
        [self imagePickerController:imagePicker didFinishPickingMediaWithInfo:[[NSDictionary alloc] initWithObjectsAndKeys:[NSURL fileURLWithPath:tmpFile], UIImagePickerControllerMediaURL, (__bridge NSString *)kUTTypeMovie, UIImagePickerControllerMediaType, nil]];
    });
#endif
}

- (void)titleAvatarTapped:(UITapGestureRecognizer *)gesture
{
    if (gesture.state == UIGestureRecognizerStateEnded && !_tableView.isEditing)
    {
        [_conversationCompanion userAvatarPressed];
    }
}

- (void)adjustToInterfaceOrientation:(UIInterfaceOrientation)orientation includingMessagesContainer:(bool)includingMessagesContainer
{
    bool animationsWereEnabled = [UIView areAnimationsEnabled];
    [UIView setAnimationsEnabled:false];
    [TGHacks setAnimationDurationFactor:0.0f];
    [TGHacks setSecondaryAnimationDurationFactor:0.0f];
    
    CGSize screenSize = [TGViewController screenSizeForInterfaceOrientation:orientation];
    _inputField.frame = CGRectMake(_inputField.frame.origin.x, _inputField.frame.origin.y, screenSize.width - 112, 0);
    
    if (_inputField.text != nil)
    {
#if TGInputFieldClassIsHP
        NSRange range = _inputField.internalTextView.selectedRange;
        CGRect frame = _inputField.frame;
        frame.size.height = 0;
        _inputField.frame = frame;
        [_inputField setText:[[NSString alloc] initWithString:_inputField.text]];
        _inputField.internalTextView.selectedRange = range;
    
         if ([_inputField.internalTextView isFirstResponder])
             [_inputField scrollToCaret];
#endif
    }
    
    CGRect tableFrameAtFinish = _tableView.frame;
    tableFrameAtFinish.origin.y = _inputContainer.frame.origin.y - tableFrameAtFinish.size.height;
    tableFrameAtFinish.size.width = screenSize.width;
    
    UIEdgeInsets tableContentInsetAtFinish = _tableView.contentInset;
    UIEdgeInsets tableScrollIndicatorInsetAtFinish = _tableView.scrollInsets;
    tableContentInsetAtFinish.bottom = MAX(0, -tableFrameAtFinish.origin.y + self.controllerInset.top);
    tableScrollIndicatorInsetAtFinish.bottom = MAX(0, -tableFrameAtFinish.origin.y + self.controllerInset.top);
    
    [_tableView.layer removeAllAnimations];
    
    if (includingMessagesContainer && !CGRectEqualToRect(tableFrameAtFinish, _tableView.frame))
    {
        _tableView.contentInset = tableContentInsetAtFinish;
        _tableView.scrollInsets = tableScrollIndicatorInsetAtFinish;
        _tableView.frame = tableFrameAtFinish;
        [self tableFrameUpdated];
        
        UIEdgeInsets tableContentInsetAtFinish = _tableView.contentInset;
        UIEdgeInsets tableScrollIndicatorInsetAtFinish = _tableView.scrollInsets;
        
        tableContentInsetAtFinish.bottom = MAX(0, -tableFrameAtFinish.origin.y + self.controllerInset.top);
        tableScrollIndicatorInsetAtFinish.bottom = MAX(0, -tableFrameAtFinish.origin.y + self.controllerInset.top);
        _tableView.contentInset = tableContentInsetAtFinish;
        _tableView.scrollInsets = tableScrollIndicatorInsetAtFinish;
    }

    bool adjustedHeight = false;
    
    if (_keyboardOpened)
    {
        int keyboardHeight = _knownKeyboardHeight;
        if (UIInterfaceOrientationIsPortrait(orientation))
        {
            if (_knownKeyboardHeight == 162)
                keyboardHeight = 216;
            else if (_knownKeyboardHeight == 162 + 36)
                keyboardHeight = 216 + 36;
        }
        else
        {
            if (_knownKeyboardHeight == 216)
                keyboardHeight = 162;
            else if (_knownKeyboardHeight == 216 + 36)
                keyboardHeight = 162 + 36;
        }
        
        if (keyboardHeight != _knownKeyboardHeight && !adjustedHeight)
        {
            [self changeInputAreaHeight:keyboardHeight duration:0 orientationChange:true dragging:false completion:nil];
        }
    }
    
    [_tableView setNeedsLayout];
    [_tableView layoutIfNeeded];
    
    [TGHacks setAnimationDurationFactor:1.0f];
    [TGHacks setSecondaryAnimationDurationFactor:1.0f];
    [UIView setAnimationsEnabled:animationsWereEnabled];
}

- (void)tableFrameUpdated
{
    _menuContainerView.frame = CGRectMake(0, self.controllerInset.top, self.view.frame.size.width, _tableView.frame.origin.y + _tableView.frame.size.height - self.controllerInset.top);
}

- (void)controllerInsetUpdated:(UIEdgeInsets)previousInset
{
    [super controllerInsetUpdated:previousInset];
    
    if (!_isRotating)
    {
        //TGLog(@"Inset");
        
        UIEdgeInsets tableContentInsetAtFinish = _tableView.contentInset;
        UIEdgeInsets tableScrollIndicatorInsetAtFinish = _tableView.scrollInsets;
        tableContentInsetAtFinish.bottom = MAX(0, -_tableView.frame.origin.y + self.controllerInset.top);
        tableScrollIndicatorInsetAtFinish.bottom = MAX(0, -_tableView.frame.origin.y + self.controllerInset.top);
        
        _tableView.contentInset = tableContentInsetAtFinish;
        _tableView.scrollInsets = tableScrollIndicatorInsetAtFinish;
    }
    
    if (_actionsPanel != nil)
    {
        CGRect actionsPanelFrame = _actionsPanel.frame;
        actionsPanelFrame.origin.y = self.controllerInset.top;
        _actionsPanel.frame = actionsPanelFrame;
    }
    
    if (_menuContainerView != nil)
    {
        _menuContainerView.frame = CGRectMake(0, self.controllerInset.top, self.view.frame.size.width, _tableView.frame.origin.y + _tableView.frame.size.height - self.controllerInset.top);
    }
    
    if (_emptyConversationContainer != nil && !_disappearingAnimation)
    {
        [self updateEmptyConversationContainer];
    }
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
    
#if !TGUseCollectionView
    _isRotating = true;
    UIInterfaceOrientation currentInterfaceOrientation = self.interfaceOrientation;
    
    CGRect currentViewFrame = self.view.frame;
    
    UIImage *inputFieldImage = nil;
    UIImageView *temporaryImageView = nil;
    
#if TGInputFieldClassIsHP
    _inputField.internalTextView.disableContentOffsetAnimation = true;
    NSRange range = _inputField.internalTextView.selectedRange;
    
    if (_editingContainer.alpha < 1.0f - FLT_EPSILON)
    {
        UIGraphicsBeginImageContextWithOptions(_inputField.internalTextView.bounds.size, true, 0.0f);
        [_inputField.layer renderInContext:UIGraphicsGetCurrentContext()];
        inputFieldImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        temporaryImageView = [[UIImageView alloc] initWithImage:inputFieldImage];
        temporaryImageView.frame = _inputField.frame;
    }
#endif
    
    int lastInputPanelHeight = 0;
    if (_keyboardOpened)
        lastInputPanelHeight = _knownKeyboardHeight;
    
    [self updateKnownKeyboardHeightForOrientation:toInterfaceOrientation];
    
    int oldMetrics = _messageMetrics;
    CGSize oldScreenSize = [TGViewController screenSize:(UIDeviceOrientation)currentInterfaceOrientation];
    CGSize screenSize = [TGViewController screenSize:(UIDeviceOrientation)toInterfaceOrientation];
    
    int inputPanelHeight = 0;
    if (_keyboardOpened)
        inputPanelHeight = _knownKeyboardHeight;

#if TGInputFieldClassIsHP
    if ([_inputField isFirstResponder])
        _inputField.internalTextView.freezeContentOffset = true;
#endif
    
    CGRect inputFieldFrame = _inputField.frame;
    
    int lastInputContainerHeight = (int)(_inputContainer.frame.size.height);
    
    _inputField.frame = CGRectMake(_inputField.frame.origin.x, _inputField.frame.origin.y, screenSize.width - 112, 0);
    
    [UIView setAnimationsEnabled:false];
#if TGInputFieldClassIsHP
    [_inputField setMaxNumberOfLines:UIInterfaceOrientationIsPortrait(toInterfaceOrientation) ? ([TGViewController isWidescreen] ? 7 : 5) : 3];
#endif
    if (_inputField.text != nil)
        [_inputField setText:[[NSString alloc] initWithString:_inputField.text]];
    
    int inputContainerHeight = (int)(_inputContainer.frame.size.height);
    
    if (inputFieldFrame.size.height < _inputField.frame.size.height)
        inputFieldFrame.size.height = _inputField.frame.size.height;
    _inputField.frame = inputFieldFrame;
    
    [UIView setAnimationsEnabled:true];
    
    float tableNewHeight = MAX(screenSize.width, screenSize.height) - _baseInputContainerHeight;
    float cellsDeltaY = 0;
    
    NSIndexPath *savedIndexPath = nil;
    int savedOffset = 0;
    int savedCellHeight = 0;
    int contentOffsetY = (int)(_tableView.contentOffset.y);
    int offsetFromCell = 0;
    NSIndexPath *indexPath = [_tableView indexPathForRowAtPoint:CGPointMake(0, contentOffsetY + 1)];
    if (indexPath != nil)
    {
        CGRect rect = [_tableView rectForRowAtIndexPath:indexPath];
        offsetFromCell = (int)(rect.origin.y - contentOffsetY);
        
        savedIndexPath = indexPath;
        savedOffset = offsetFromCell;
        savedCellHeight = (int)(rect.size.height);
    }
    
    [self updateMetrics:toInterfaceOrientation];
    CGRect tableFrame = CGRectMake(0, [self tableViewY:toInterfaceOrientation], screenSize.width, tableNewHeight + 44);
    
    tableFrame.origin.y -= inputPanelHeight + (inputContainerHeight - _baseInputContainerHeight);
    
    if (screenSize.height < oldScreenSize.height)
    {
        //tableFrame.size.height += oldScreenSize.height - screenSize.height;
        //tableFrame.origin.y -= oldScreenSize.height - screenSize.height;
        
        //cellsDeltaY += -oldTableSize.height + tableNewHeight;
        
        cellsDeltaY += screenSize.height - oldScreenSize.height;
    }
    else if (screenSize.height > oldScreenSize.height)
    {
        cellsDeltaY += screenSize.height - oldScreenSize.height;
    }
    
    cellsDeltaY += lastInputPanelHeight - inputPanelHeight;
    cellsDeltaY += lastInputContainerHeight - inputContainerHeight;
    
    _tableView.frame = tableFrame;
    [self tableFrameUpdated];
    
    if (savedIndexPath != nil)
    {
        int fullHeight = 0;
        int offsetHeight = 0;
        int lastHeight = 0;
        int cellHeight = 0;
        for (int i = 0; i < [self tableView:_tableView numberOfRowsInSection:0]; i++)
        {
            NSIndexPath *cellIndexPath = [NSIndexPath indexPathForRow:i inSection:0];
            lastHeight = (int)([self tableView:_tableView heightForRowAtIndexPath:cellIndexPath]);
            if (i == indexPath.row)
            {
                offsetHeight = fullHeight;
                cellHeight = lastHeight;
            }
            
            fullHeight += lastHeight;
        }
        
        if (savedCellHeight == 0)
            savedCellHeight = 1;
        int newCellOffset = savedOffset * cellHeight / savedCellHeight;
        
        int newContentOffsetY = offsetHeight - newCellOffset;
        if (newContentOffsetY > _tableView.contentSize.height - tableNewHeight)
            newContentOffsetY = (int)(_tableView.contentSize.height - tableNewHeight);
        if (newContentOffsetY < 0)
            newContentOffsetY = 0;
        
        _tableView.contentOffset = CGPointMake(0, newContentOffsetY);
    }
    
    [_tableView layoutSubviews];
    
    NSMutableArray *cellFrames = [[NSMutableArray alloc] init];
    
    NSMutableArray *visibleCells = [[NSMutableArray alloc] initWithArray:_tableView.visibleCells];
    [visibleCells sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        return ((UITableViewCell *)obj1).frame.origin.y < ((UITableViewCell *)obj2).frame.origin.y ? NSOrderedAscending : NSOrderedDescending;
    }];
    
    int lastY = -1;
    
    id<TGConversationMessageAssetsSource> assetsSource = [_conversationCompanion messageAssetsSource];
    
    for (UITableViewCell *cell in visibleCells)
    {
        CGRect frame = cell.frame;
        [cellFrames addObject:[NSValue valueWithCGRect:frame]];
        
        frame.origin.y += cellsDeltaY;
        
        if ([cell isKindOfClass:[TGConversationMessageItemView class]])
        {
            TGConversationMessageItemView *messageView = (TGConversationMessageItemView *)cell;
            if (messageView.message.outgoing)
                frame.origin.x = -oldScreenSize.width + screenSize.width;
            else
                frame.origin.x = -oldScreenSize.width + screenSize.width;
            frame.size.width = oldScreenSize.width;
            
            int tempHeight = (int)(3 + [TGConversationMessageItemView layoutModelForMessage:messageView.messageItem withMetrics:oldMetrics assetsSource:assetsSource].size.height);
            frame.size.height = tempHeight;
            
            if (lastY == -1)
                lastY = (int)(frame.origin.y + tempHeight);
            else
            {
                frame.origin.y = lastY;
                cell.frame = frame;
                lastY += tempHeight;
            }
        }
        else
        {
            frame.origin.x = -oldScreenSize.width + screenSize.width;
            frame.size.width = oldScreenSize.width;
            
            if (lastY == -1)
                lastY = (int)(frame.origin.y + frame.size.height);
            else
            {
                frame.origin.y = lastY;
                lastY += frame.size.height;
            }
        }
        
        frame.origin.x += -cell.contentView.frame.origin.x;
        
        cell.frame = frame;
    }
    
    if (_tableView.tableHeaderView != nil)
    {
        CGRect frame = _tableView.tableHeaderView.frame;
        frame.origin.y += cellsDeltaY;
        frame.origin.x = -oldScreenSize.width + screenSize.width;
        frame.size.width = oldScreenSize.width;
        _tableView.tableHeaderView.frame = frame;
    }
    
    _tableView.showsVerticalScrollIndicator = false;
    
    [visibleCells removeAllObjects];
    
    [UIView beginAnimations:@"table_rotation" context:nil];
    [UIView setAnimationDuration:duration];
    
    _inputContainer.frame = CGRectMake(0, currentViewFrame.size.height - inputPanelHeight - inputContainerHeight, _inputContainer.frame.size.width, inputContainerHeight);
    
    if (_editingDeleteButton != nil)
        [self updateEditingControls:toInterfaceOrientation];
    
    if (cellFrames.count != 0)
    {
        int index = -1;
        for (UITableViewCell *cell in _tableView.visibleCells)
        {
            index++;
            
            CGRect frame = cell.frame;
            frame = [(NSValue *)[cellFrames objectAtIndex:index] CGRectValue];
            cell.frame = frame;
        }
    }
    
    if (_tableView.tableHeaderView != nil)
    {
        CGRect frame = _tableView.tableHeaderView.frame;
        frame.origin.y = 0;
        frame.origin.x = 0;
        frame.size.width = screenSize.width;
        _tableView.tableHeaderView.frame = frame;
    }
    
    [UIView commitAnimations];

    CGRect frame = _inputField.frame;
    frame.size.width = screenSize.width - 112;
    _inputField.frame = frame;
    
#if TGInputFieldClassIsHP
    if (_inputField.internalTextView.freezeContentOffset)
    {
        if (_inputField.text != nil)
        {
            CGRect frame = _inputField.frame;
            frame.size.height = 0;
            _inputField.frame = frame;
            [_inputField setText:[[NSString alloc] initWithString:_inputField.text]];
            _inputField.internalTextView.selectedRange = range;
            
            _inputField.internalTextView.freezeContentOffset = false;
            [_inputField scrollToCaret];
        }
        _inputField.internalTextView.freezeContentOffset = true;
    }
#endif
    
    _tableView.clipsToBounds = false;
    
    if (_editingContainer.alpha < 1.0f - FLT_EPSILON)
    {
#if TGInputFieldClassIsHP
        UIGraphicsBeginImageContextWithOptions(_inputField.internalTextView.bounds.size, true, 0.0);
        [_inputField.layer renderInContext:UIGraphicsGetCurrentContext()];
        UIImage *inputFieldFinalImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        [_inputField.superview insertSubview:temporaryImageView aboveSubview:_inputField];
        
        UIImageView *temporaryFinalImageView = [[UIImageView alloc] initWithImage:inputFieldFinalImage];
        temporaryFinalImageView.frame = _inputField.frame;
        [_inputField.superview insertSubview:temporaryFinalImageView belowSubview:temporaryImageView];
        
        _inputField.hidden = true;
        
        [UIView animateWithDuration:duration animations:^
        {
            temporaryImageView.alpha = 0.0f;
        } completion:^(__unused BOOL finished)
        {
            [temporaryImageView removeFromSuperview];
            [temporaryFinalImageView removeFromSuperview];
            _inputField.hidden = false;
        }];
#endif
    }
    //});
    
#endif
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
#if TGInputFieldClassIsHP
    _inputField.internalTextView.freezeContentOffset = false;
    _inputField.internalTextView.disableContentOffsetAnimation = false;
#endif
    
    _isRotating = false;
    
    _tableView.clipsToBounds = true;
    _tableView.showsVerticalScrollIndicator = true;
    
    int keyboardHeight = _knownKeyboardHeight;
    [self changeInputAreaHeight:keyboardHeight duration:0 orientationChange:true dragging:false completion:nil];
    
    [super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
}

- (void)adjustNavigationAppearanceAnimated:(UIInterfaceOrientation)orientation duration:(NSTimeInterval)duration
{
    float statusBarAlpha = 1.0f;
    bool navigationBarHidden = false;
    
    if (_wantsKeyboardActive)
    {
        if (UIInterfaceOrientationIsPortrait(orientation))
        {
            statusBarAlpha = 1.0f;
            navigationBarHidden = false;
        }
        else
        {
            statusBarAlpha = 0.0f;
            navigationBarHidden = true;
        }
    }
    else
    {
        statusBarAlpha = 1.0f;
        navigationBarHidden = false;
    }
    
    if (ABS([self statusBarBackgroundAlpha] - statusBarAlpha) > FLT_EPSILON)
    {
        [UIView animateWithDuration:duration animations:^
        {
            [self setStatusBarBackgroundAlpha:statusBarAlpha];
        }];
    }
    
    [self setNavigationBarHidden:navigationBarHidden withAnimation:TGViewControllerNavigationBarAnimationSlideFar duration:duration];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [self adjustNavigationAppearanceAnimated:toInterfaceOrientation duration:duration];
    
    [self updateTitle:toInterfaceOrientation animated:false];
    
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
}

#pragma mark - Table logic

#if !TGUseCollectionView
- (CGFloat)tableView:(UITableView *)__unused tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    int section = indexPath.section;
    int row = indexPath.row;
    if (section == 0)
    {
        if (row >= _listModel.count)
        {
            //return (_editTitleConversationItem == nil && _editPhotoConversationItem == nil && _userPhotoConversationItem == nil) ? 43 : 16;
            return 30;
        }
        
        TGConversationItem *item = [_listModel objectAtIndex:row];
        return [self heightForConversationItem:item metrics:_messageMetrics];
    }
    else if (section == 1)
    {
        return 44 + 12;
    }
    
    return 0;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)__unused tableView
{
    return 2;
}

- (NSInteger)tableView:(UITableView *)__unused tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0)
    {
        return _listModel.count + 1;
    }
    else if (section == 1)
    {
        return 0;
    }
    
    return 0;
}

- (BOOL)tableView:(UITableView *)__unused tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0)
    {
        return true;
    }
    
    return false;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)__unused tableView editingStyleForRowAtIndexPath:(NSIndexPath *)__unused indexPath
{
    return UITableViewCellEditingStyleNone;
}

- (BOOL)tableView:(UITableView *)__unused tableView shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)__unused indexPath
{
    return false;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    [UIView setAnimationsEnabled:false];
    UITableViewCell *cell = nil;
    
    TGConversationItem *item = nil;
    if (indexPath.section == 0)
    {
        if (indexPath.row < _listModel.count)
            item = [_listModel objectAtIndex:indexPath.row];
    }
    
    if (item != nil && item.type == TGConversationItemTypeMessage)
    {
        TGConversationMessageItem *messageItem = (TGConversationMessageItem *)item;
        
        static NSString *messageItemIndentifierSingle = @"MS";
        static NSString *messageItemIndentifierMulti = @"MM";
        
        NSString *messageItemIndentifier = (_messageMetrics & TGConversationMessageMetricsShowAvatars) ? messageItemIndentifierMulti : messageItemIndentifierSingle;
        TGConversationMessageItemView *messageItemView = (TGConversationMessageItemView *)[tableView dequeueReusableCellWithIdentifier:messageItemIndentifier];
        if (messageItemView == nil)
        {
            if (_preparedCellQueue != nil && _preparedCellQueue.count != 0)
            {
                messageItemView = [_preparedCellQueue lastObject];
                [_preparedCellQueue removeLastObject];
                
#ifdef DEBUG
                //TGLog(@"Taking prepared cell");
#endif
            }
            if (messageItemView == nil)
            {
                messageItemView = [[TGConversationMessageItemView alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:messageItemIndentifier];
                messageItemView.viewRecycler = _viewRecycler;
                messageItemView.watcher = self.actionHandle;
                
#ifdef DEBUG
                if (_preparedCellQueue != nil)
                {
                    //TGLog(@"Out of prepared cells");
                }
#endif
            }
        }
        
        messageItemView.disableBackgroundDrawing = _disableMessageBackgroundDrawing;
        
        messageItemView.offsetFromGMT = [_conversationCompanion offsetFromGMT];
        messageItemView.message = messageItem.message;
        messageItemView.messageItem = messageItem;
        
        if (_tableView.isEditing)
        {
            [messageItemView setIsSelected:_checkedMessages.find(messageItem.message.mid) != _checkedMessages.end() || _checkedMessages.find(messageItem.message.localMid) != _checkedMessages.end()];
        }
        
        if ((_messageMetrics & TGConversationMessageMetricsShowAvatars) && messageItem.message.actionInfo == nil)
        {
            messageItemView.showAvatar = true;
            messageItemView.avatarUrl = messageItem.author == nil ? nil : messageItem.author.photoUrlSmall;
        }
        else
        {
            messageItemView.showAvatar = false;
        }
        
        if (messageItemView.messageItemHash == (int)messageItem)
        {
            //TGLog(@"Optimized cell 0x%.8x", (int)messageItem);
            [messageItemView updateState:false];
        }
        else
        {
            [messageItemView resetView:_messageMetrics];
            messageItemView.messageItemHash = (int)messageItem;
        }
        
        if (_currentlyHighlightedMid != 0 && messageItem.message.mid == _currentlyHighlightedMid)
            [messageItemView setIsContextSelected:true animated:false];
        
        bool hasProgress = false;
        float progress = 0.0f;
        if (_pMessageUploadProgress != NULL)
        {
            std::map<int, float>::iterator it = _pMessageUploadProgress->find(messageItem.message.mid);
            if (it != _pMessageUploadProgress->end())
            {
                hasProgress = true;
                progress = it->second;
            }
        }
        
        id mediaId = messageItem.progressMediaId;
        
        if (!hasProgress)
        {
            if (_mediaDownloadProgress != NULL)
            {
                if (mediaId != nil)
                {
                    NSNumber *nProgress = [_mediaDownloadProgress objectForKey:mediaId];
                    if (nProgress != nil)
                    {
                        hasProgress = true;
                        progress = [nProgress floatValue];
                    }
                }
            }
        }
        
        if (mediaId != nil)
        {
            NSNumber *nStatus = [_mediaDownloadedStatuses objectForKey:mediaId];
            [messageItemView setMediaNeedsDownload:nStatus == nil ? false : ![nStatus boolValue]];
        }
        
        [messageItemView setProgress:hasProgress progress:progress animated:false];
        
        if (_hiddenMediaMid != 0)
        {
            bool hide = false;
            
            if (messageItem.message.mid != _hiddenMediaMid && messageItem.message.localMid != _hiddenMediaMid)
            {
                hide = false;
            }
            else if (messageItem.message.mid == _hiddenMediaMid || messageItem.message.localMid == _hiddenMediaMid)
            {
                hide = true;
            }
            
            [messageItemView viewForItemWithClass:[TGRemoteImageView class]].hidden = hide;
            [messageItemView setAlphaToItemsWithAdditionalTag:1 alpha:hide ? 0.0f : 1.0f];
            [messageItemView setAlphaToItemsWithAdditionalTag:2 alpha:hide ? 0.0f : 1.0f];
            [messageItemView setAlphaToItemsWithAdditionalTag:3 alpha:hide ? 0.0f : 1.0f];
        }
        
        cell = messageItemView;
    }
    else if (item != nil && item.type == TGConversationItemTypeDate)
    {
        TGConversationDateItem *dateItem = (TGConversationDateItem *)item;
        
        static NSString *dateItemIndentifier = @"D";
        TGConversationDateItemView *dateItemView = (TGConversationDateItemView *)[tableView dequeueReusableCellWithIdentifier:dateItemIndentifier];
        if (dateItemView == nil)
        {
            dateItemView = [[TGConversationDateItemView alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:dateItemIndentifier];
        }
        
        dateItemView.dateString = dateItem.dateString;
        
        cell = dateItemView;
    }
    else if (item != nil && item.type == TGConversationItemTypeUnread)
    {
        TGConversationUnreadItem *unreadItem = (TGConversationUnreadItem *)item;
        
        static NSString *unreadItemIndentifier = @"UNR";
        TGConversationUnreadItemView *unreadItemView = (TGConversationUnreadItemView *)[tableView dequeueReusableCellWithIdentifier:unreadItemIndentifier];
        if (unreadItemView == nil)
        {
            unreadItemView = [[TGConversationUnreadItemView alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:unreadItemIndentifier];
        }
        
        unreadItemView.title = unreadItem.title;
        
        cell = unreadItemView;
    }

    if (cell == nil)
    {
        static NSString *PlaceholderCellIdentifier = @"LoadingCell";
        cell = [tableView dequeueReusableCellWithIdentifier:PlaceholderCellIdentifier];
        if (cell == nil)
        {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:PlaceholderCellIdentifier];
            [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
            cell.backgroundColor = nil;
            cell.opaque = false;
    
            UIImageView *indicatorBackgroundView = [[UIImageView alloc] initWithImage:[_conversationCompanion.messageAssetsSource systemMessageBackground]];
            indicatorBackgroundView.tag = 10000;
            indicatorBackgroundView.autoresizingMask = (UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin);
            indicatorBackgroundView.frame = CGRectMake(floorf((cell.frame.size.width - 21) / 2), 3, 21, indicatorBackgroundView.frame.size.height + (TGIsRetina() ? 0.5f : 0.0f));
            indicatorBackgroundView.transform = CGAffineTransformMakeRotation(M_PI);
            [cell.contentView addSubview:indicatorBackgroundView];
            
            TGActivityIndicatorView *spinner = [[TGActivityIndicatorView alloc] initWithStyle:TGActivityIndicatorViewStyleSmallWhite];
            spinner.tag = 10001;
            CGRect frame = spinner.frame;
            frame.origin = CGPointMake((int)((cell.frame.size.width - frame.size.width) / 2), 4 + 3);
            spinner.frame = frame;
            spinner.transform = CGAffineTransformMakeRotation(M_PI);
            spinner.autoresizingMask = (UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin);
            [cell.contentView addSubview:spinner];
        }
        
        UIView *indicatorBackgroundView = [cell.contentView viewWithTag:10000];
        indicatorBackgroundView.hidden = !_canLoadMoreHistory;
        TGActivityIndicatorView *spinner = (TGActivityIndicatorView *)[cell.contentView viewWithTag:10001];
        spinner.hidden = !_canLoadMoreHistory;
        if (spinner.hidden)
            [spinner stopAnimating];
        else
            [spinner startAnimating];
    }
    [UIView setAnimationsEnabled:true];
    
    return cell;
}
#endif

#pragma mark -

#if TGUseCollectionView
- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)__unused collectionView
{
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)__unused collectionView numberOfItemsInSection:(NSInteger)section
{
    return section == 0 ? _listModel.count : 1;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)__unused collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    float height = 0.0f;
    
    int section = indexPath.section;
    int row = indexPath.row;
    if (section == 0)
    {
        if (row >= _listModel.count)
            height = 30;
        
        TGConversationItem *item = [_listModel objectAtIndex:row];
        height = [self heightForConversationItem:item metrics:_messageMetrics];
    }
    else if (section == 1)
    {
        height = 44 + 12;
    }
    
    return CGSizeMake(collectionView.frame.size.width, height);
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewCell *cell = nil;
    
    TGConversationItem *item = nil;
    if (indexPath.section == 0)
    {
        if (indexPath.row < _listModel.count)
            item = [_listModel objectAtIndex:indexPath.row];
    }
    
    if (item != nil && item.type == TGConversationItemTypeMessage)
    {
        TGConversationMessageItem *messageItem = (TGConversationMessageItem *)item;
        
        static NSString *messageItemIndentifier = @"M";
        
        TGConversationMessageItemView *messageItemView = (TGConversationMessageItemView *)[collectionView dequeueReusableCellWithReuseIdentifier:messageItemIndentifier forIndexPath:indexPath];

        messageItemView.viewRecycler = _viewRecycler;
        messageItemView.watcher = _actionHandle;
        
        messageItemView.disableBackgroundDrawing = _disableMessageBackgroundDrawing;
        
        messageItemView.offsetFromGMT = [_conversationCompanion offsetFromGMT];
        messageItemView.message = messageItem.message;
        messageItemView.messageItem = messageItem;
        
        if (_tableView.isEditing)
        {
            [messageItemView setIsSelected:_checkedMessages.find(messageItem.message.mid) != _checkedMessages.end() || _checkedMessages.find(messageItem.message.localMid) != _checkedMessages.end()];
        }
        
        if (_messageMetrics & TGConversationMessageMetricsShowAvatars)
        {
            messageItemView.showAvatar = true;
            messageItemView.avatarUrl = messageItem.author == nil ? nil : messageItem.author.photoUrlSmall;
        }
        
        if (messageItemView.messageItemHash == (int)messageItem)
        {
            //TGLog(@"Optimized cell 0x%.8x", (int)messageItem);
            [messageItemView updateState:false];
        }
        else
        {
            [messageItemView resetView:_messageMetrics];
            messageItemView.messageItemHash = (int)messageItem;
        }
        
        if (_currentlyHighlightedMid != 0 && messageItem.message.mid == _currentlyHighlightedMid)
            [messageItemView setIsContextSelected:true animated:false];
        
        bool hasProgress = false;
        float progress = 0.0f;
        if (_pMessageUploadProgress != NULL)
        {
            std::map<int, float>::iterator it = _pMessageUploadProgress->find(messageItem.message.mid);
            if (it != _pMessageUploadProgress->end())
            {
                hasProgress = true;
                progress = it->second;
            }
        }
        
        id mediaId = messageItem.progressMediaId;
        
        if (!hasProgress)
        {
            if (_mediaDownloadProgress != NULL)
            {
                if (mediaId != nil)
                {
                    NSNumber *nProgress = [_mediaDownloadProgress objectForKey:mediaId];
                    if (nProgress != nil)
                    {
                        hasProgress = true;
                        progress = [nProgress floatValue];
                    }
                }
            }
        }
        
        if (mediaId != nil)
        {
            NSNumber *nStatus = [_mediaDownloadedStatuses objectForKey:mediaId];
            [messageItemView setMediaNeedsDownload:nStatus == nil ? false : ![nStatus boolValue]];
        }
        
        [messageItemView setProgress:hasProgress progress:progress animated:false];
        
        if (_hiddenMediaMid != 0)
        {
            bool hide = false;
            
            if (messageItem.message.mid != _hiddenMediaMid && messageItem.message.localMid != _hiddenMediaMid)
            {
                hide = false;
            }
            else if (messageItem.message.mid == _hiddenMediaMid || messageItem.message.localMid == _hiddenMediaMid)
            {
                hide = true;
            }
            
            [messageItemView viewForItemWithClass:[TGRemoteImageView class]].hidden = hide;
            [messageItemView setAlphaToItemsWithAdditionalTag:1 alpha:hide ? 0.0f : 1.0f];
            [messageItemView setAlphaToItemsWithAdditionalTag:2 alpha:hide ? 0.0f : 1.0f];
            [messageItemView setAlphaToItemsWithAdditionalTag:3 alpha:hide ? 0.0f : 1.0f];
        }
        
        cell = messageItemView;
    }
    else if (item != nil && item.type == TGConversationItemTypeDate)
    {
        TGConversationDateItem *dateItem = (TGConversationDateItem *)item;
        
        static NSString *dateItemIndentifier = @"D";
        TGConversationDateItemView *dateItemView = (TGConversationDateItemView *)[collectionView dequeueReusableCellWithReuseIdentifier:dateItemIndentifier forIndexPath:indexPath];
        
        dateItemView.dateString = dateItem.dateString;
        
        cell = dateItemView;
    }
    else if (item != nil && item.type == TGConversationItemTypeUnread)
    {
        TGConversationUnreadItem *unreadItem = (TGConversationUnreadItem *)item;
        
        static NSString *unreadItemIndentifier = @"UNR";
        TGConversationUnreadItemView *unreadItemView = (TGConversationUnreadItemView *)[collectionView dequeueReusableCellWithReuseIdentifier:unreadItemIndentifier forIndexPath:indexPath];
        
        unreadItemView.title = unreadItem.title;
        
        cell = unreadItemView;
    }
    
    if (cell == nil)
    {
        //TODO: loading cell
    }
    
    return cell;
}
#endif

#pragma mark -

- (int)heightForConversationItem:(TGConversationItem *)item metrics:(int)metrics
{
    switch (item.type)
    {
        case TGConversationItemTypeMessage:
        {
            TGConversationMessageItem *messageItem = (TGConversationMessageItem *)item;
            return (int)(sizeForConversationMessage(messageItem, metrics, [_conversationCompanion messageAssetsSource]).height);
        }
        case TGConversationItemTypeDate:
        {
            return 27;
        }
        case TGConversationItemTypeUnread:
        {
            return 34;
        }
        default:
            break;
    }
    
    return 0;
}

#pragma mark - Presentation logic

- (void)closeKeyboard
{
    _wantsKeyboardActive = false;
    
    [self.view endEditing:true];
}

- (void)touchedTableBackground
{
    if (_menuContainerView.isShowingMenu)
        return;

    if (CFAbsoluteTimeGetCurrent() - _lastMenuHideTime < 0.32)
        return;
    
    if (!_inputField.isFirstResponder)
    {
        _overlayDateToken++;
        [self updateOverlayDateView:true];
        
        int token = _overlayDateToken;
        ASHandle *actionHandle = _actionHandle;
        TGDispatchAfter(1.0, dispatch_get_main_queue(), ^
        {
            [actionHandle requestAction:@"hideOverayDate" options:[[NSNumber alloc] initWithInt:token]];
        });
    }
    
    [self closeKeyboard];
    
    if (_messageMenuMid != 0)
    {
        _messageMenuMid = 0;
        _messageMenuLocalMid = 0;
#if TGInputFieldClassIsHP
        _inputField.internalTextView.handleEditActions = true;
#endif
        
        [self clearItemsSelection:true];
    }
}

- (void)updateKnownKeyboardHeightForOrientation:(UIInterfaceOrientation)orientation
{
    if (UIInterfaceOrientationIsPortrait(orientation))
    {
        if (_knownKeyboardHeight == 162)
            _knownKeyboardHeight = 216;
        else if (_knownKeyboardHeight == 162 + 36)
            _knownKeyboardHeight = 216 + 36;
    }
    else
    {
        if (_knownKeyboardHeight == 216)
            _knownKeyboardHeight = 162;
        else if (_knownKeyboardHeight == 216 + 36)
            _knownKeyboardHeight = 162 + 36;
    }
}

- (void)keyboardWillShow:(NSNotification*)notification
{
    _wantsKeyboardActive = true;
    
    _ignoreBackgroundImageViewScroll = true;
    
    CGRect keyboardFrame = [[[notification userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    keyboardFrame = [self.view convertRect:keyboardFrame fromView:nil];
    float newKeyboardHeight = keyboardFrame.size.height;
    _knownKeyboardHeight = (int)newKeyboardHeight;
    
    double duration = ([[[notification userInfo] objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue]);
    
    if (_stopProcessingEverything || _isRotating)
        return;
    
    [TGViewController disableAutorotationFor:duration + 0.1 + 0.05];
    [TGViewController disableUserInteractionFor:duration + 0.05];
    
    _keyboardOpened = true;
    
    CGRect inputContainerFrameAtFinish = _inputContainer.frame;
    inputContainerFrameAtFinish.origin.y = _inputContainer.superview.frame.size.height - newKeyboardHeight - _inputContainer.frame.size.height;
    
    [self changeInputAreaHeight:(int)newKeyboardHeight duration:duration orientationChange:false dragging:false completion:nil];
    [self setAttachmentArrowState:false duration:duration];
    
    [self adjustNavigationAppearanceAnimated:self.interfaceOrientation duration:duration];
}

- (void)keyboardWillHide:(NSNotification *)notification
{
    _ignoreBackgroundImageViewScroll = true;
    
    if (_isRotating || _stopProcessingEverything)
        return;
    
    _keyboardOpened = false;
    
    _knownKeyboardHeight = 0;
    double duration = [[[notification userInfo] objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    
    [TGViewController disableAutorotationFor:duration + 0.05];
    [TGViewController disableUserInteractionFor:duration + 0.05];
    
    [_backgroundImageView.layer removeAllAnimations];
    
    [self changeInputAreaHeight:0 duration:duration orientationChange:false dragging:false completion:nil];
    
    [self adjustNavigationAppearanceAnimated:self.interfaceOrientation duration:duration];
}

- (void)keyboardDidHide:(NSNotification *)__unused notification
{
    _ignoreBackgroundImageViewScroll = false;
    
    if (_isRotating || _stopProcessingEverything)
        return;
}

- (void)keyboardDidShow:(NSNotification *)__unused notification
{
    _ignoreBackgroundImageViewScroll = false;
}

- (void)clearItemsSelection:(bool)__unused animated
{
    _messageMenuMid = 0;
    _messageMenuLocalMid = 0;
    
#if TGInputFieldClassIsHP
    _inputField.internalTextView.handleEditActions = true;
#endif
    
    for (UITableViewCell *cell in _tableView.visibleCells)
    {
        if ([cell isKindOfClass:[TGConversationMessageItemView class]])
        {
            TGConversationMessageItemView *messageView = (TGConversationMessageItemView *)cell;
            [messageView setIsContextSelected:false animated:true];
        }
    }
}

- (BOOL)canBecomeFirstResponder
{
    return true;
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)__unused sender
{
    if (_messageMenuMid == 0 && _messageMenuLocalMid == 0)
        return false;
    
    for (TGConversationItem *item in _listModel)
    {
        if (item.type == TGConversationItemTypeMessage)
        {
            TGConversationMessageItem *messageItem = (TGConversationMessageItem *)item;
            if (messageItem.message.mid == _messageMenuMid || (_messageMenuLocalMid != 0 && messageItem.message.localMid == _messageMenuLocalMid))
            {
                if ((!_messageMenuIsAction && _messageMenuHasText && action == @selector(copy:)) || action == @selector(delete:) || (!_messageMenuIsAction && action == @selector(forward:)) || (!_messageMenuIsAction && action == @selector(beginSelection:)))
                {
                    return true;
                }
                break;
            }
        }
    }
    
    return false;
}

- (void)setAttachmentArrowState:(bool)opened duration:(NSTimeInterval)duration
{
    if (opened)
    {
        CGAffineTransform newTransform = CGAffineTransformMakeRotation((float)(-M_PI - 0.0001));
        if (!CGAffineTransformEqualToTransform(_attachButtonArrow.transform, newTransform))
        {
            _attachButtonArrow.image = [_conversationCompanion attachButtonArrowImageDown];
            _attachButtonArrow.transform = CGAffineTransformMakeTranslation(0, 0.5);
            [UIView animateWithDuration:duration animations:^
            {
                _attachButtonArrow.transform = newTransform;
            }];
        }
    }
    else
    {
        if (!CGAffineTransformEqualToTransform(_attachButtonArrow.transform, CGAffineTransformIdentity))
        {
            _attachButtonArrow.image = [_conversationCompanion attachButtonArrowImageUp];
            _attachButtonArrow.transform = CGAffineTransformTranslate(CGAffineTransformMakeRotation(-M_PI - 0.0001), 0, -0.5);
            [UIView animateWithDuration:duration animations:^
            {
                _attachButtonArrow.transform = CGAffineTransformIdentity;
            }];
        }
    }
}

- (void)insertTextAtCaret:(NSString *)text
{
#if TGInputFieldClassIsHP
    NSRange range = _inputField.selectedRange;
    NSString * firstHalfString = [_inputField.text substringToIndex:range.location];
    NSString * secondHalfString = [_inputField.text substringFromIndex: range.location];
    _inputField.internalTextView.scrollEnabled = NO;  // turn off scrolling
    
    NSString * insertingString = text;
    
    _inputField.text = [NSString stringWithFormat: @"%@%@%@",
                       firstHalfString,
                       insertingString,
                       secondHalfString];
    range.location += [insertingString length];
    _inputField.selectedRange = range;
    _inputField.internalTextView.scrollEnabled = YES;  // turn scrolling back on.
#endif
}

- (void)emojiTapRecognized:(UITapGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateEnded)
    {
        TGLabel *label = (TGLabel *)recognizer.view;
        if ([label isKindOfClass:[TGLabel class]])
        {
            [self insertTextAtCaret:label.text];
        }
    }
}

- (void)changeInputAreaHeight:(int)height duration:(NSTimeInterval)duration orientationChange:(bool)orientationChange dragging:(bool)dragging completion:(void (^)(BOOL finished))completion
{   
    CGRect inputContainerFrameAtFinish = _inputContainer.frame;
    float inputContainerDeltaHeight = inputContainerFrameAtFinish.origin.y;
    inputContainerFrameAtFinish.origin.y = _inputContainer.superview.frame.size.height - height - _inputContainer.frame.size.height;
    inputContainerDeltaHeight = inputContainerFrameAtFinish.origin.y - inputContainerDeltaHeight;

    CGRect tableFrameAtFinish = _tableView.frame;
    tableFrameAtFinish.origin.y = inputContainerFrameAtFinish.origin.y - tableFrameAtFinish.size.height;
    
    UIEdgeInsets tableContentInsetAtFinish = _tableView.contentInset;
    UIEdgeInsets tableScrollIndicatorInsetAtFinish = _tableView.scrollInsets;
    if (!dragging)
    {
        tableContentInsetAtFinish.bottom = MAX(0, -tableFrameAtFinish.origin.y + self.controllerInset.top);
    }
    tableScrollIndicatorInsetAtFinish.bottom = MAX(0, -tableFrameAtFinish.origin.y + self.controllerInset.top);

    [_tableView.layer removeAllAnimations];

    if (orientationChange)
    {
        _tableView.frame = tableFrameAtFinish;
        [self tableFrameUpdated];
    }

    if (duration > DBL_EPSILON)
    {
        [UIView animateWithDuration:duration delay:0.0 options:(UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionTransitionNone) animations:^
        {
            if (!CGRectEqualToRect(_inputContainer.frame, inputContainerFrameAtFinish))
                _inputContainer.frame = inputContainerFrameAtFinish;

            if (!orientationChange)
            {
                _tableView.frame = tableFrameAtFinish;
                [self tableFrameUpdated];
            }
            
            _tableView.contentInset = tableContentInsetAtFinish;
            _tableView.scrollInsets = tableScrollIndicatorInsetAtFinish;
        } 
        completion:^(BOOL finished)
        {
            if (finished)
            {
                _tableView.frame = tableFrameAtFinish;
                [self tableFrameUpdated];
            }
            if (completion)
                completion(finished);
        }];
    }
    else
    {
        if (!CGRectEqualToRect(_inputContainer.frame, inputContainerFrameAtFinish))
            _inputContainer.frame = inputContainerFrameAtFinish;
        
        _tableView.frame = tableFrameAtFinish;
        [self tableFrameUpdated];
        _tableView.contentInset = tableContentInsetAtFinish;
        _tableView.scrollInsets = tableScrollIndicatorInsetAtFinish;
    }
}

- (void)growingTextView:(HPGrowingTextView *)growingTextView willChangeHeight:(float)height
{
    [self growingTextView:growingTextView willChangeHeight:height animated:true];
}

- (void)updateInputContainerFrame:(bool)animated
{
    bool expandBackground = false;
    
    CGRect frame = _inputContainer.frame;
    if (_editingContainer.alpha > FLT_EPSILON)
    {
        frame.size.height = _baseInputContainerHeight;
        
        if (_editingAcceptButton.alpha > FLT_EPSILON || _editingRequestButton.alpha > FLT_EPSILON)
            expandBackground = true;       
    }
    else
    {
        CGRect inputFieldFrame = _inputField.frame;
        if (_inputField == nil)
        {
            inputFieldFrame = _inputFieldWhiteBackground.frame;
            inputFieldFrame.origin.x += 1;
            inputFieldFrame.size.width -= 6;
            inputFieldFrame.size.height -= 2;
        }
        frame.size.height = _baseInputContainerHeight;
    }
    
    //if (!CGRectEqualToRect(frame, _inputContainer.frame))
    {
        int currentKeyboardHeight = _knownKeyboardHeight;
        if (![_conversationCompanion applicationManager].keyboardVisible)
            currentKeyboardHeight = 0;

        frame.origin.y = _inputContainer.superview.frame.size.height - currentKeyboardHeight - frame.size.height;
        //if ((_editingContainer.alpha > FLT_EPSILON) && currentKeyboardHeight != 0)
        //    frame.origin.y -= 44;
        
        if (!_isRotating)
        {
            CGRect newFrameFinish = _tableView.frame;
            newFrameFinish.origin.y = frame.origin.y - newFrameFinish.size.height;
            
            UIEdgeInsets tableContentInsetAtFinish = _tableView.contentInset;
            UIEdgeInsets tableScrollIndicatorInsetAtFinish = _tableView.scrollInsets;
            tableContentInsetAtFinish.bottom = MAX(0, -newFrameFinish.origin.y + self.controllerInset.top);
            tableScrollIndicatorInsetAtFinish.bottom = MAX(0, -newFrameFinish.origin.y + self.controllerInset.top);
            
            if (animated)
            {
                [UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState animations:^
                {
                    _inputContainer.frame = frame;
                    _tableView.frame = newFrameFinish;
                    [self tableFrameUpdated];
                    _tableView.contentInset = tableContentInsetAtFinish;
                    _tableView.scrollInsets = tableScrollIndicatorInsetAtFinish;
                } completion:nil];
            }
            else
            {
                _inputContainer.frame = frame;
                _tableView.frame = newFrameFinish;
                [self tableFrameUpdated];
                _tableView.contentInset = tableContentInsetAtFinish;
                _tableView.scrollInsets = tableScrollIndicatorInsetAtFinish;
                [_tableView setNeedsLayout];
            }
        }
        else
        {
            _inputContainer.frame = frame;
        }
    }
}

- (void)growingTextView:(HPGrowingTextView *)__unused growingTextView willChangeHeight:(float)height animated:(bool)animated
{
    if (_editingContainer.alpha > FLT_EPSILON)
        return;
    
    CGRect inputContainerFrame = _inputContainer.frame;
    int newHeight = (int)(_baseInputContainerHeight - 36 + height);
    if (inputContainerFrame.size.height != newHeight)
    {
        int currentKeyboardHeight = _knownKeyboardHeight;
        if (![_conversationCompanion applicationManager].keyboardVisible)
            currentKeyboardHeight = 0;
        inputContainerFrame.size.height = newHeight;
        inputContainerFrame.origin.y = _inputContainer.superview.frame.size.height - currentKeyboardHeight - inputContainerFrame.size.height;
        
        if (!_isRotating)
        {
            CGRect newFrameFinish = _tableView.frame;
            newFrameFinish.origin.y = inputContainerFrame.origin.y - newFrameFinish.size.height;
            
            UIEdgeInsets tableContentInsetAtFinish = _tableView.contentInset;
            UIEdgeInsets tableScrollIndicatorInsetAtFinish = _tableView.scrollInsets;
            tableContentInsetAtFinish.bottom = MAX(0, -newFrameFinish.origin.y + self.controllerInset.top);
            tableScrollIndicatorInsetAtFinish.bottom = MAX(0, -newFrameFinish.origin.y + self.controllerInset.top);
            
            if (animated && [UIView areAnimationsEnabled])
            {
                [UIView animateWithDuration:0.3 animations:^
                {
                    _inputContainer.frame = inputContainerFrame;
                    _tableView.frame = newFrameFinish;
                    [self tableFrameUpdated];
                    _tableView.contentInset = tableContentInsetAtFinish;
                    _tableView.scrollInsets = tableScrollIndicatorInsetAtFinish;
                } completion:nil];
            }
            else
            {
                _inputContainer.frame = inputContainerFrame;
                _tableView.frame = newFrameFinish;
                [self tableFrameUpdated];
                _tableView.contentInset = tableContentInsetAtFinish;
                _tableView.scrollInsets = tableScrollIndicatorInsetAtFinish;
                [_tableView setNeedsLayout];
            }
        }
        else
        {
            _inputContainer.frame = inputContainerFrame;
        }
    }
}

- (void)updatePlaceholderVisibility:(bool)firstResponder
{
    _placeholderLabel.hidden = firstResponder || _inputField.text.length != 0;
}

- (void)hpTextViewChangedResponderState:(bool)firstResponder
{
    [self updatePlaceholderVisibility:firstResponder];
}

- (void)growingTextViewDidChange:(HPGrowingTextView *)growingTextView
{
    if (growingTextView.text.length != 0)
    {
        int textLength = growingTextView.text.length;
        NSString *text = growingTextView.text;
        bool hasNonWhitespace = false;
        for (int i = 0; i < textLength; i++)
        {
            unichar c = [text characterAtIndex:i];
            if (c != ' ' && c != '\n')
            {
                hasNonWhitespace = true;
                break;
            }
        }
        _sendButton.enabled = hasNonWhitespace;
        
        if (_initialMessageText == nil && !_isRotating)
            [_conversationCompanion messageTypingActivity];
    }
    else
        _sendButton.enabled = false;
    
    [self updatePlaceholderVisibility:[growingTextView.internalTextView isFirstResponder]];
}

#pragma mark -

- (UIView *)overlayDateView
{
    if (_overlayDateContainer == nil)
    {
        UIImage *rawImage = [UIImage imageNamed:@"ConversationDateOverlay.png"];
        
        _overlayDateContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, rawImage.size.width, rawImage.size.height)];
        _overlayDateContainer.alpha = 0.0f;
        _overlayDateContainer.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        [self.view insertSubview:_overlayDateContainer aboveSubview:_tableView];
        
        UIImageView *backgroundView = [[UIImageView alloc] initWithImage:[rawImage stretchableImageWithLeftCapWidth:(int)(rawImage.size.width / 2) topCapHeight:0]];
        backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        backgroundView.alpha = 0.85f;
        [_overlayDateContainer addSubview:backgroundView];
        
        _overlayDateView = [[UILabel alloc] init];
        _overlayDateView.frame = CGRectMake(12, 4, 0, 0);
        _overlayDateView.font = [UIFont boldSystemFontOfSize:12];
        _overlayDateView.textColor = [UIColor whiteColor];
        _overlayDateView.shadowColor = UIColorRGBA(0x000000, 0.3f);
        _overlayDateView.shadowOffset = CGSizeMake(0, -1);
        _overlayDateView.backgroundColor = [UIColor clearColor];
        [_overlayDateContainer addSubview:_overlayDateView];
    }
    
    return _overlayDateView;
}

- (void)updateOverlayDateView:(bool)force
{
    return;
    
    int date = 0;
    
    static Class MessageCellClass = [TGConversationMessageItemView class];
    
    CGRect frame = _tableView.frame;
    float contentOffset = _tableView.contentOffset.y;
    float positionThreshold = frame.size.height + frame.origin.y + contentOffset;
    
    NSArray *array = [_tableView visibleCells];
    for (int i = array.count - 1; i >= 0; i--)
    {
        UITableViewCell *cell = [array objectAtIndex:i];
        CGRect cellFrame = cell.frame;
        
        if (cellFrame.origin.y < positionThreshold && [cell isKindOfClass:MessageCellClass])
        {
            date = (int)[(TGConversationMessageItemView *)cell message].date;
            break;
        }
    }
    
    if (date != 0 && (_overlayDateViewDate != date || force))
    {
        _overlayDateViewDate = date;
        NSString *newText = [TGDateUtils stringForDialogTime:date];
        if (![self.overlayDateView.text isEqualToString:newText])
        {
            self.overlayDateView.text = newText;
            [_overlayDateView sizeToFit];
            float containerWidth = _overlayDateView.frame.size.width + 12 * 2;
            _overlayDateContainer.frame = CGRectMake(floorf((self.view.frame.size.width - containerWidth) / 2), 10, containerWidth, 25);
        }
        
        time_t t = date;
        struct tm timeinfo;
        localtime_r(&t, &timeinfo);
        
        time_t t_now;
        time(&t_now);
        struct tm timeinfo_now;
        localtime_r(&t_now, &timeinfo_now);
        
        _overlayDateAlphaDay = 1.0f;
        _overlayDateAlpha = 1.0f;//timeinfo.tm_yday != timeinfo_now.tm_yday ? 1.0f : 0.0f;
        
        float alpha = _overlayDateAlpha * _overlayDateAlphaDay;
        
        if (ABS(_overlayDateContainer.alpha - alpha) > FLT_EPSILON)
        {
            [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^
            {
                _overlayDateContainer.alpha = alpha;
            } completion:nil];
        }
    }
}

- (BOOL)scrollViewShouldScrollToTop:(UIScrollView *)scrollView
{
    if (scrollView == _scrollToTopInterceptor)
    {
        [_tableView scrollRectToVisible:CGRectMake(0, _tableView.contentSize.height - 28, 1, 1) animated:true];
    }
    return false;
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    if (scrollView == _tableView)
    {
        _tableViewLastScrollPosition = (int)scrollView.contentOffset.y;
        
        _dragKeyboardByTablePanningStartOffset = (int)scrollView.contentOffset.y;
        
        for (UIGestureRecognizer *recognizer in scrollView.gestureRecognizers)
        {
            if ([recognizer isKindOfClass:[TGSwipeGestureRecognizer class]])
            {
                [(TGSwipeGestureRecognizer *)recognizer failGesture];
            }
        }
        
        /*_overlayDateAlphaDay = 1.0f;
        
        [self updateOverlayDateView];
        
        float alpha = _overlayDateAlphaDay * _overlayDateAlpha;
        
        [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^
        {
            _overlayDateContainer.alpha = alpha;
        } completion:nil];*/
    }
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if (scrollView == _tableView)
    {
        if (!decelerate)
        {
            if (scrollView.contentOffset.y < 100)
                [_conversationCompanion unloadOldItemsIfNeeded];
            
            /*_overlayDateAlphaDay = 0.0f;
            
            [UIView animateWithDuration:0.3 delay:0.25 options:UIViewAnimationOptionBeginFromCurrentState animations:^
            {
                _overlayDateContainer.alpha = _overlayDateAlphaDay * _overlayDateAlpha;
            } completion:nil];*/
        }
    }
    
    if (!decelerate)
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            [TGViewController attemptAutorotation];
        });
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (scrollView == _tableView)
    {
        _tableViewLastScrollPosition = (int)scrollView.contentOffset.y;
        
        if (!_ignoreBackgroundImageViewScroll)
        {
            float superviewOffset = 20 + (self.view.frame.size.height > 400 ? 44 : 32);
            
            CGRect inputContainerFrame = _inputContainer.frame;
            float backgroundBaseY = superviewOffset + (self.view.frame.size.height - (inputContainerFrame.origin.y + inputContainerFrame.size.height) > FLT_EPSILON ? -80 : -20);
            
            CGRect frame = _backgroundImageView.frame;
            CGRect newFrame = frame;
            CGPoint contentOffset = scrollView.contentOffset;
            float maxContentOffsetY = scrollView.contentSize.height - scrollView.frame.size.height;
            
            if (contentOffset.y < 0)
            {
                newFrame.origin.y = backgroundBaseY + floorf((MAX(contentOffset.y, -250) * 0.08f * 2.0f)) / 2.0f;
            }
            else if (contentOffset.y > maxContentOffsetY)
            {
                newFrame.origin.y = backgroundBaseY + floorf((MIN(contentOffset.y - MAX(0, maxContentOffsetY), 250) * 0.08f * 2.0f)) / 2.0f;
            }
            else
            {
                if (ABS(frame.origin.y - backgroundBaseY) > FLT_EPSILON)
                {
                    newFrame.origin.y = backgroundBaseY;
                }
            }
            
            if (ABS(frame.origin.y - newFrame.origin.y) > FLT_EPSILON)
            {
                _backgroundImageView.frame = newFrame;
            }
        }
        
        if (_overlayDateContainer.alpha > FLT_EPSILON && ABS(_tableView.contentOffset.y - _overlayDateViewUpdateOffset) > 5)
        {
            _overlayDateViewUpdateOffset = (int)_tableView.contentOffset.y;
            [self updateOverlayDateView:false];
        }
        
        if (_tableViewLastScrollPosition <= 0 && !_canLoadMoreHistoryDownwards)
        {
            if (_incomingMessagesButton != nil && _incomingMessagesButton.superview != nil && _incomingMessagesButton.alpha > FLT_EPSILON)
            {
                [UIView animateWithDuration:0.2 animations:^
                {
                    _incomingMessagesButton.alpha = 0.0f;
                } completion:^(BOOL finished)
                {
                    if (finished)
                    {
                        [_incomingMessagesButton removeFromSuperview];
                    }
                }];
            }
        }
    }
}

- (void)displayNewMessagesTooltip
{
    if (_incomingMessagesButton != nil && _incomingMessagesButton.superview != nil && _incomingMessagesButton.alpha > 1.0f - FLT_EPSILON)
        return;
    
    if (_incomingMessagesButton == nil)
    {
        _incomingMessagesButton = [[UIButton alloc] initWithFrame:CGRectMake(_inputContainer.frame.size.width - 36 - 7, -36 - 7, 36, 36)];
        _incomingMessagesButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        [_incomingMessagesButton addTarget:self action:@selector(incomingMessagesButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        
        [_incomingMessagesButton setBackgroundImage:[UIImage imageNamed:@"ConversationScrollDown.png"] forState:UIControlStateNormal];
        [_incomingMessagesButton setBackgroundImage:[UIImage imageNamed:@"ConversationScrollDown_Highlighted.png"] forState:UIControlStateHighlighted];
        
        _inputContainer.hitView = _incomingMessagesButton;
        
        _incomingMessagesButton.alpha = 0.0f;
    }
    
    [_inputContainer addSubview:_incomingMessagesButton];
    _incomingMessagesButton.frame = CGRectMake(_inputContainer.frame.size.width - 36 - 7, -36 - 7, 36, 36);
    
    [UIView animateWithDuration:0.3 animations:^
    {
        _incomingMessagesButton.alpha = 1.0f;
    }];
}

- (void)tableView:(UITableView *)__unused tableView willDisplayCell:(UITableViewCell *)__unused cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0)
    {
        if (!_disableDownwardsHistoryLoading && indexPath.row <= 5 && _canLoadMoreHistoryDownwards && !_conversationCompanion.isLoadingDownwards)
        {
            [_conversationCompanion loadMoreHistoryDownwards];
        }
        
        if (indexPath.row >= (int)_listModel.count - 10 && _canLoadMoreHistory && !_conversationCompanion.isLoading)
        {
            [_conversationCompanion loadMoreHistory];
        }
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    if (scrollView == _tableView)
    {
        if (scrollView.contentOffset.y < 100)
            [_conversationCompanion unloadOldItemsIfNeeded];
        
        if (!_ignoreBackgroundImageViewScroll)
        {
            float superviewOffset = 20 + (self.view.frame.size.height > 400 ? 44 : 32);
            
            CGRect inputContainerFrame = _inputContainer.frame;
            float backgroundBaseY = superviewOffset + (self.view.frame.size.height - (inputContainerFrame.origin.y + inputContainerFrame.size.height) > FLT_EPSILON ? -80 : -20);
            
            CGRect frame = _backgroundImageView.frame;
            CGRect newFrame = frame;
            CGPoint contentOffset = scrollView.contentOffset;
            float maxContentOffsetY = scrollView.contentSize.height - scrollView.frame.size.height;
            
            if (contentOffset.y < 0)
            {
                newFrame.origin.y = backgroundBaseY + floorf((MAX(contentOffset.y, -250) * 0.08f * 2.0f)) / 2.0f;
            }
            else if (contentOffset.y > maxContentOffsetY)
            {
                newFrame.origin.y = backgroundBaseY + floorf((MIN(contentOffset.y - MAX(0, maxContentOffsetY), 250) * 0.08f * 2.0f)) / 2.0f;
            }
            else
            {
                if (ABS(frame.origin.y - backgroundBaseY) > FLT_EPSILON)
                {
                    newFrame.origin.y = backgroundBaseY;
                }
            }
            
            if (ABS(frame.origin.y - newFrame.origin.y) > FLT_EPSILON)
            {
                _backgroundImageView.frame = newFrame;
            }
        }
        
        /*[UIView animateWithDuration:0.3 delay:0.25 options:UIViewAnimationOptionBeginFromCurrentState animations:^
        {
            _overlayDateContainer.alpha = 0.0f;
        } completion:nil];*/
    }
    
    dispatch_async(dispatch_get_main_queue(), ^
    {
        [TGViewController attemptAutorotation];
    });
}

- (void)scrollViewDidScrollToTop:(UIScrollView *)scrollView
{
    if (scrollView == _tableView)
    {
        if (scrollView.contentOffset.y < 100)
            [_conversationCompanion unloadOldItemsIfNeeded];
    }
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView
{
    if (scrollView == _tableView)
    {
        if (scrollView.contentOffset.y < 100)
            [_conversationCompanion unloadOldItemsIfNeeded];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^
    {
        [TGViewController attemptAutorotation];
    });
}

- (void)tableViewSwiped:(TGSwipeGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateRecognized)
    {   
        NSTimeInterval currentTime = CFAbsoluteTimeGetCurrent();
        if (currentTime - _lastSwipeActionTime < 0.4)
            return;
        _lastSwipeActionTime = currentTime;
        
        if (_tableView.isEditing || [[UIMenuController sharedMenuController] isMenuVisible])
            return;
        
        if (recognizer.direction == TGSwipeGestureRecognizerDirectionLeft)
            [self performCloseConversation];
        else
        {
            [_conversationCompanion userAvatarPressed];
        }
    }
}

- (void)setEditingMode:(bool)editing
{
    [self setEditingMode:editing animated:true];
}

- (void)setEditingMode:(bool)editing animated:(bool)animated
{
    if (editing != _tableView.isEditing)
    {
        if (editing)
        {
            [self clearAllButton];
            [self doneButton];
            
            [_actionsPanel hide:animated];
        }
        else
            _checkedMessages.clear();
        
        for (UIGestureRecognizer *recognizer in _avatarImageView.superview.gestureRecognizers)
        {
            if ([recognizer isKindOfClass:[UITapGestureRecognizer class]])
                recognizer.enabled = !editing;
        }
        
        dispatch_block_t animationBlock = ^
        {
            if (editing)
                _clearAllButton.alpha = 1.0f;
            else
                _backButton.alpha = 1.0f;
            
            _avatarImageView.alpha = editing ? 0.0f : 1.0f;
            _doneButton.alpha = editing ? 1.0f : 0.0f;
        };
        
        dispatch_block_t animationDelayedBlock = ^
        {
            if (editing)
                _backButton.alpha = 0.0f;
            else
                _clearAllButton.alpha = 0.0f;
        };
        
        if (animated)
        {
            [UIView animateWithDuration:0.3 animations:animationBlock];
            [UIView animateWithDuration:0.2 delay:0.1 options:0 animations:animationDelayedBlock completion:nil];
        }
        else
        {
            animationBlock();
            animationDelayedBlock();
        }
        
        if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation) && _titleContainer.frame.size.width >= 160)
        {
            [UIView transitionWithView:_titleContainer duration:0.3 options:UIViewAnimationOptionTransitionCrossDissolve animations:^
            {
                [UIView setAnimationsEnabled:false];
                [self updateTitle:false];
                [UIView setAnimationsEnabled:true];
            } completion:nil];
        }
        else
            [self updateTitle:false];
        
        [_tableView setEditing:editing animated:animated];
        
        if (_editingSeparatorBottom == nil && editing)
        {
            _editingSeparatorBottom = [[UIImageView alloc] initWithImage:[[_conversationCompanion messageAssetsSource] messageEditingSeparator]];
            _editingSeparatorBottom.alpha = 0.0f;
            _editingSeparatorBottom.hidden = true;
            
            _editingSeparatorBottom.frame = CGRectMake(0, 1, _tableView.frame.size.width, 2);
            _editingSeparatorBottom.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            
            [_tableView addSubview:_editingSeparatorBottom];
        }
        
        if (animated)
        {
            if (editing)
                _editingSeparatorBottom.hidden = false;
            [UIView animateWithDuration:0.25 animations:^
            {
                _editingSeparatorBottom.alpha = editing ? 1.0f : 0.0f;
            } completion:^(BOOL finished)
            {
                if (finished)
                {
                    _editingSeparatorBottom.hidden = !editing;
                }
            }];
        }
        else
        {
            _editingSeparatorBottom.alpha = editing ? 1.0f : 0.0f;
            _editingSeparatorBottom.hidden = !editing;
        }
        
        if (editing)
        {
            if (_userBlocked && animated)
            {
                [UIView animateWithDuration:0.3 animations:^
                {
                    _editingRequestContainer.alpha = 0.0f;
                    _editingForwardButton.alpha = 1.0f;
                    _editingDeleteButton.alpha = 1.0f;
                }];
            }
            else
            {
                _editingRequestContainer.alpha = 0.0f;
                _editingForwardButton.alpha = 1.0f;
                _editingDeleteButton.alpha = 1.0f;
            }
        }
        else if (_userBlocked)
        {
            if (animated)
            {
                [UIView animateWithDuration:0.25 animations:^
                {
                    _editingRequestContainer.alpha = 1.0f;
                    _editingForwardButton.alpha = 0.0f;
                    _editingDeleteButton.alpha = 0.0f;
                }];
            }
            else
            {
                _editingRequestContainer.alpha = 1.0f;
                _editingForwardButton.alpha = 0.0f;
                _editingDeleteButton.alpha = 0.0f;
            }
        }
        else
        {
            _editingForwardButton.alpha = 1.0f;
            _editingDeleteButton.alpha = 1.0f;
        }

        [self setEditingContainerVisible:editing || _userBlocked editingMode:true animated:animated];
    }
}

- (void)setEditingContainerVisible:(bool)visible editingMode:(bool)editingMode animated:(bool)animated
{
    if (visible)
        [self loadEditingControls:editingMode];
    [self updateEditingControls];
    
    if (visible)
    {
        CGRect containerFrame = _editingRequestContainer.frame;
        _editingRequestContainer.frame = containerFrame;
    }
    
    /*if (animated)
    {
        [UIView animateWithDuration:(visible ? 0.15 : 0.3) animations:^
        {
            if (visible)
            {
                _inputField.alpha = 0.0f;
                _inputFieldWhiteBackground.alpha = 0.0f;
                _fakeInputFieldLabel.alpha = 0.0f;
            }
            else
            {
                _inputField.alpha = 1.0f;
                _inputFieldWhiteBackground.alpha = 1.0f;
                _fakeInputFieldLabel.alpha = 1.0f;
            }
        }];
    }
    else
    {
        if (visible)
        {
            _inputField.alpha = 0.0f;
            _inputFieldWhiteBackground.alpha = 0.0f;
            _fakeInputFieldLabel.alpha = 0.0f;
        }
        else
        {
            _inputField.alpha = 1.0f;
            _inputFieldWhiteBackground.alpha = 1.0f;
            _fakeInputFieldLabel.alpha = 1.0f;
        }
    }*/
    
    if (visible)
        _editingContainer.hidden = false;
    
    if (animated)
    {
        [UIView animateWithDuration:0.25 animations:^
        {
            if (visible)
            {
                /*_inputFieldBackground.alpha = 0.0f;
                _placeholderLabel.alpha = 0.0f;
                _sendButton.alpha = 0.0f;
                _attachButton.alpha = 0.0f;*/
                
                _editingContainer.alpha = 1.0f;
            }
            else
            {
                /*_inputFieldBackground.alpha = 1.0f;
                _placeholderLabel.alpha = 1.0f;
                _sendButton.alpha = 1.0f;
                _attachButton.alpha = 1.0f;*/
                
                _editingContainer.alpha = 0.0f;
            }
        } completion:^(BOOL finished)
        {
            if (finished)
            {
                if (!visible)
                {
                    _editingContainer.hidden = true;
                }
            }
        }];
    }
    else
    {
        if (visible)
        {
            /*_inputFieldBackground.alpha = 0.0f;
            _placeholderLabel.alpha = 0.0f;
            _sendButton.alpha = 0.0f;
            _attachButton.alpha = 0.0f;*/
            
            _editingContainer.alpha = 1.0f;
        }
        else
        {
            /*_inputFieldBackground.alpha = 1.0f;
            _placeholderLabel.alpha = 1.0f;
            _sendButton.alpha = 1.0f;
            _attachButton.alpha = 1.0f;*/
            
            _editingContainer.alpha = 0.0f;
        }
        
        if (!visible)
            _editingContainer.hidden = true;
    }
    
    [self updateInputContainerFrame:animated];
    
    if (visible)
    {
#if TGInputFieldClassIsHP
        if (_inputField.internalTextView.isFirstResponder)
            [_inputField.internalTextView resignFirstResponder];
#endif
    }
}

- (void)loadEditingControls:(bool)editingMode
{
    bool updateControls = false;
    
    if (_editingContainer == nil)
    {
        updateControls = true;
        
        _editingContainer = [[UIView alloc] initWithFrame:_inputContainer.bounds];
        _editingContainer.alpha = 0.0f;
        _editingContainer.hidden = true;
        _editingContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [_inputContainer addSubview:_editingContainer];
        
        _editingRequestBackground = [[UIImageView alloc] initWithImage:[_conversationCompanion inputContainerRawBackground]];
        _editingRequestBackground.frame = _editingContainer.bounds;
        _editingRequestBackground.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [_editingContainer addSubview:_editingRequestBackground];
        
        {
            UIImage *deleteButtonImage = [_conversationCompanion editingDeleteButtonBackground];
            _editingDeleteButton = [[UIButton alloc] initWithFrame:CGRectMake(8, _inputContainer.frame.size.height - _baseInputContainerHeight + (int)((_baseInputContainerHeight - deleteButtonImage.size.height) / 2) + 1, (int)(_inputContainer.frame.size.width / 2) - 8 - 4, deleteButtonImage.size.height)];
            _editingDeleteButton.exclusiveTouch = true;
            _editingDeleteButton.alpha = editingMode ? 1.0f : 0.0f;
            _editingDeleteButton.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
            [_editingDeleteButton setBackgroundImage:deleteButtonImage forState:UIControlStateNormal];
            [_editingDeleteButton setBackgroundImage:[_conversationCompanion editingDeleteButtonBackgroundHighlighted] forState:UIControlStateHighlighted];
            _editingDeleteButton.adjustsImageWhenDisabled = false;
            _editingDeleteButton.adjustsImageWhenHighlighted = false;
            [_editingDeleteButton addTarget:self action:@selector(editingDeleteButtonPressed) forControlEvents:UIControlEventTouchUpInside];
            
            _editingDeleteButtonLabel = [[UILabel alloc] init];
            _editingDeleteButtonLabel.backgroundColor = [UIColor clearColor];
            _editingDeleteButtonLabel.textColor = UIColorRGB(0xffffff);
            _editingDeleteButtonLabel.shadowColor = UIColorRGBA(0x9e0a01, 0.3f);
            _editingDeleteButtonLabel.shadowOffset = CGSizeMake(0, -1);
            _editingDeleteButtonLabel.font = [UIFont boldSystemFontOfSize:13];
            [_editingDeleteButton addSubview:_editingDeleteButtonLabel];
            
            _editingDeleteButtonIcon = [[UIImageView alloc] initWithImage:[_conversationCompanion editingDeleteButtonIcon]];
            [_editingDeleteButton addSubview:_editingDeleteButtonIcon];
            
            [_editingContainer addSubview:_editingDeleteButton];
        }
        
        
        UIImage *forwardButtonImage = [_conversationCompanion editingForwardButtonBackground];
        _editingForwardButton = [[UIButton alloc] initWithFrame:CGRectMake(_inputContainer.frame.size.width - ((int)(_inputContainer.frame.size.width / 2) - 8 - 4) - 8, _inputContainer.frame.size.height - _baseInputContainerHeight + (int)((_baseInputContainerHeight - forwardButtonImage.size.height) / 2) + 1, (int)(_inputContainer.frame.size.width / 2) - 8 - 4, forwardButtonImage.size.height)];
        _editingForwardButton.alpha = editingMode ? 1.0f : 0.0f;
        _editingForwardButton.exclusiveTouch = true;
        _editingForwardButton.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
        [_editingForwardButton setBackgroundImage:forwardButtonImage forState:UIControlStateNormal];
        [_editingForwardButton setBackgroundImage:[_conversationCompanion editingForwardButtonBackgroundHighlighted] forState:UIControlStateHighlighted];
        _editingForwardButton.adjustsImageWhenDisabled = false;
        _editingForwardButton.adjustsImageWhenHighlighted = false;
        [_editingForwardButton addTarget:self action:@selector(editingForwardButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        
        _editingForwardButtonLabel = [[UILabel alloc] init];
        _editingForwardButtonLabel.backgroundColor = [UIColor clearColor];
        _editingForwardButtonLabel.textColor = UIColorRGB(0xffffff);
        _editingForwardButtonLabel.shadowColor = UIColorRGBA(0x3c6696, 0.5f);
        _editingForwardButtonLabel.shadowOffset = CGSizeMake(0, -1);
        _editingForwardButtonLabel.font = [UIFont boldSystemFontOfSize:13];
        [_editingForwardButton addSubview:_editingForwardButtonLabel];
        
        _editingForwardButtonIcon = [[UIImageView alloc] initWithImage:[_conversationCompanion editingForwardButtonIcon]];
        [_editingForwardButton addSubview:_editingForwardButtonIcon];
        
        [_editingContainer addSubview:_editingForwardButton];
        
        CGRect containerFrame = _editingContainer.bounds;
        _editingRequestContainer = [[UIView alloc] initWithFrame:containerFrame];
        _editingRequestContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _editingRequestContainer.alpha = editingMode ? 0.0f : 1.0f;
        [_editingContainer addSubview:_editingRequestContainer];
        
        UIImage *shadowImage = [_conversationCompanion inputContainerShadowImage];
        UIImageView *shadowView = [[UIImageView alloc] initWithFrame:CGRectMake(0, -shadowImage.size.height, _editingRequestContainer.frame.size.width, shadowImage.size.height)];
        shadowView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        shadowView.image = shadowImage;
        [_editingRequestContainer addSubview:shadowView];
        
        _editingBlockButton = [self createRequestButton:false];
        [_editingBlockButton addTarget:self action:@selector(blockButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [_editingBlockButton setTitle:TGLocalized(@"Conversation.BlockUser") forState:UIControlStateNormal];
        [_editingRequestContainer addSubview:_editingBlockButton];
        
        _editingAcceptButton = [self createRequestButton:true];
        [_editingAcceptButton addTarget:self action:@selector(acceptRequestButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [_editingAcceptButton setTitle:@"Share Number" forState:UIControlStateNormal];
        [_editingRequestContainer addSubview:_editingAcceptButton];
        
        _editingRequestButton = [self createRequestButton:true];
        [_editingRequestButton addTarget:self action:@selector(sendRequestButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [_editingRequestButton setTitle:@"Send Contact Request" forState:UIControlStateNormal];
        [_editingRequestContainer addSubview:_editingRequestButton];
        
        _editingUnblockButton = [self createRequestButton:false];
        [_editingUnblockButton addTarget:self action:@selector(unblockButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [_editingUnblockButton setTitle:_conversationCompanion.isMultichat && !_conversationCompanion.isEncrypted ? TGLocalized(@"Conversation.DeleteGroup") : TGLocalized(@"Conversation.UnblockUser") forState:UIControlStateNormal];
        [_editingRequestContainer addSubview:_editingUnblockButton];
        
        _editingStateLabel = [[UILabel alloc] init];
        _editingStateLabel.font = [UIFont systemFontOfSize:14];
        _editingStateLabel.textAlignment = NSTextAlignmentCenter;
        _editingStateLabel.backgroundColor = [UIColor clearColor];
        _editingStateLabel.textColor = UIColorRGB(0x576d85);
        [_editingRequestContainer addSubview:_editingStateLabel];
    }
    
    if (updateControls)
        [self updateEditingControls];
}

- (UIButton *)createRequestButton:(bool)isGreen
{
    UIImage *rawButtonImage = [UIImage imageNamed:isGreen ? @"RequestGreenButton.png" : @"RequestRedButton.png"];
    UIImage *buttonImage = [rawButtonImage stretchableImageWithLeftCapWidth:(int)((rawButtonImage.size.width) / 2) topCapHeight:(int)((rawButtonImage.size.height) / 2)];
    UIImage *rawButtonImageHighlighted = [UIImage imageNamed:isGreen ? @"RequestGreenButton_Highlighted.png" : @"RequestRedButton_Highlighted.png"];
    UIImage *buttonImageHighlighted = [rawButtonImageHighlighted stretchableImageWithLeftCapWidth:(int)((rawButtonImageHighlighted.size.width) / 2) topCapHeight:(int)((rawButtonImageHighlighted.size.height) / 2)];
    
    UIButton *button = [[UIButton alloc] init];
    button.exclusiveTouch = true;
    [button setBackgroundImage:buttonImage forState:UIControlStateNormal];
    [button setBackgroundImage:buttonImageHighlighted forState:UIControlStateHighlighted];
    [button setTitleColor:UIColorRGB(0xffffff) forState:UIControlStateNormal];
    [button setTitleShadowColor:(isGreen ? UIColorRGB(0x479415) : UIColorRGB(0xcf2f29)) forState:UIControlStateNormal];
    [button setTitleShadowColor:(isGreen ? UIColorRGB(0x458413) : UIColorRGB(0xb91510)) forState:UIControlStateHighlighted];
    button.titleLabel.shadowOffset = CGSizeMake(0, -1);
    button.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    
    return button;
}

- (void)updateEditingControls
{
    [self updateEditingControls:self.interfaceOrientation];
}

- (void)updateEditingControls:(UIInterfaceOrientation)orientation
{
    if (_checkedMessages.empty())
    {
        _editingDeleteButtonLabel.text = NSLocalizedString(@"Conversation.EditDelete", nil);
        _editingForwardButtonLabel.text = NSLocalizedString(@"Conversation.EditForward", nil);
    }
    else
    {
        _editingDeleteButtonLabel.text = [NSString stringWithFormat:@"%@ (%d)", NSLocalizedString(@"Conversation.EditDelete", nil), (int)_checkedMessages.size()];
        if (_conversationCompanion.isEncrypted)
            _editingForwardButtonLabel.text = NSLocalizedString(@"Conversation.EditForward", nil);
        else
            _editingForwardButtonLabel.text = [NSString stringWithFormat:@"%@ (%d)", NSLocalizedString(@"Conversation.EditForward", nil), (int)_checkedMessages.size()];
    }
    
    float screenWidth = [TGViewController screenSizeForInterfaceOrientation:orientation].width;
    float retinaPixel = TGIsRetina() ? 0.5f : 0.0f;
    
    const float iconSpacing = 8;
    
    {
        UIImage *deleteButtonImage = [_conversationCompanion editingDeleteButtonBackground];
        _editingDeleteButton.frame = CGRectMake(9, _inputContainer.frame.size.height - _baseInputContainerHeight + (int)((_baseInputContainerHeight - deleteButtonImage.size.height) / 2) + 1 + retinaPixel, (int)(screenWidth / 2) - 9 - 4, deleteButtonImage.size.height);
        
        CGRect iconFrame = _editingDeleteButtonIcon.frame;
        
        CGRect labelFrame = CGRectMake(0, 0, 0, 0);
        labelFrame.size = [_editingDeleteButtonLabel.text sizeWithFont:_editingDeleteButtonLabel.font];
        
        iconFrame.origin = CGPointMake((int)((_editingDeleteButtonLabel.superview.frame.size.width - labelFrame.size.width - iconFrame.size.width - iconSpacing) / 2), 4 + retinaPixel);
        
        labelFrame.origin = CGPointMake(iconFrame.origin.x + iconFrame.size.width + iconSpacing, (int)((_editingDeleteButtonLabel.superview.frame.size.height - labelFrame.size.height) / 2) - 1 + (TGIsRetina() ? 0.5f : 0.0f));
        
        _editingDeleteButtonIcon.frame = iconFrame;
        _editingDeleteButtonLabel.frame = labelFrame;
    }
    {
        UIImage *forwardButtonImage = [_conversationCompanion editingForwardButtonBackground];
        _editingForwardButton.frame = CGRectMake(screenWidth - ((int)(screenWidth / 2) - 9 - 4) - 9, _inputContainer.frame.size.height - _baseInputContainerHeight + (int)((_baseInputContainerHeight - forwardButtonImage.size.height) / 2) + 1 + retinaPixel, (int)(screenWidth / 2) - 9 - 4, forwardButtonImage.size.height);
        CGRect iconFrame = _editingForwardButtonIcon.frame;
        
        CGRect labelFrame = CGRectMake(0, 0, 0, 0);
        labelFrame.size = [_editingForwardButtonLabel.text sizeWithFont:_editingForwardButtonLabel.font];
        
        iconFrame.origin = CGPointMake((int)((_editingForwardButtonLabel.superview.frame.size.width - labelFrame.size.width - iconFrame.size.width - iconSpacing) / 2), 3 + retinaPixel);
        
        labelFrame.origin = CGPointMake(iconFrame.origin.x + iconFrame.size.width + iconSpacing, (int)((_editingForwardButtonLabel.superview.frame.size.height - labelFrame.size.height) / 2) - 1 + (TGIsRetina() ? 0.5f : 0.0f));
        
        _editingForwardButtonIcon.frame = iconFrame;
        _editingForwardButtonLabel.frame = labelFrame;
    }
    
    _editingDeleteButton.enabled = !_checkedMessages.empty();
    _editingForwardButton.enabled = !_checkedMessages.empty();
    
    float iconAlpha = !_checkedMessages.empty() ? 1.0f : 0.7f;
    
    _editingDeleteButtonIcon.alpha = iconAlpha;
    _editingDeleteButtonLabel.alpha = iconAlpha;
    
    _editingBlockButton.frame = CGRectMake(7 + (screenWidth - 14 - 150 * 2 - 6) / 2,  5, 150, 35);
    _editingAcceptButton.frame = CGRectMake(7 + (screenWidth - 14 - 150 * 2 - 6) / 2 + 150 + 6, 5, 150, 35);
    _editingRequestButton.frame = CGRectMake(floorf((screenWidth - 200) / 2), 5, 200, 35);
    _editingUnblockButton.frame = CGRectMake(floorf((screenWidth - 160) / 2), 5, 160, 35);
    
    _editingStateLabel.frame = CGRectMake(4, 7, screenWidth - 8, 27);
}

- (void)viewPanGestureRecognized:(UIPanGestureRecognizer *)recognizer
{   
    if (recognizer.state == UIGestureRecognizerStateBegan)
    {
        CGPoint point = [recognizer locationInView:self.view];
        CGPoint translation = [recognizer translationInView:self.view];
        point.x -= translation.x;
        point.y -= translation.y;
        if (CGRectContainsPoint(_inputContainer.frame, point))
        {
            if (_keyboardOpened)
            {
                //TGLog(@"Begin keyboard dragging");
                _dragKeyboardByInputContainer = true;
            }
            else
            {
                _swipeKeyboardOpen = _inputContainer.userInteractionEnabled;
            }
        }
    }
    else if (recognizer.state == UIGestureRecognizerStateChanged)
    {
        if (_dragKeyboardByInputContainer)
        {   
            [self dragKeyboard:(int)[recognizer translationInView:self.view].y];
        }
        else if (_swipeKeyboardOpen)
        {
            if ([recognizer translationInView:self.view].y < -3.0f)
            {
                if (_editingContainer.alpha < 1.0f - FLT_EPSILON)
                {
                    [_inputField becomeFirstResponder];
                }
                _swipeKeyboardOpen = false;
            }
        }
    }
    else
    {
        if (_dragKeyboardByInputContainer)
        {
            [self maybeHideKeyboard:[recognizer velocityInView:self.view].y scrollToBottom:false];
            _dragKeyboardByInputContainer = false;
        }
        
        _swipeKeyboardOpen = false;
        
        dispatch_async(dispatch_get_main_queue(), ^
        {
            [TGViewController attemptAutorotation];
        });
    }
}

- (void)tablePanRecognized:(UIPanGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateBegan)
    {
        _dragKeyboardByTablePanningStartPoint = (int)_tableView.contentOffset.y;
        _dragKeyboardByTablePanningPanPoint = (int)(_tableView.frame.origin.y + _tableView.frame.size.height);
        _dragKeyboardByTablePanning = _keyboardOpened;
    }
    else if (recognizer.state == UIGestureRecognizerStateChanged)
    {
        if (_dragKeyboardByTablePanning)
        {
            CGPoint point = [recognizer locationInView:self.view];
            
            int dragOffset = (int)(point.y - _dragKeyboardByTablePanningPanPoint);
            
            if ([self dragKeyboard:dragOffset])
            {
                _ignoreBackgroundImageViewScroll = true;
                _tableView.contentOffset = CGPointMake(0, _dragKeyboardByTablePanningStartPoint);
            }
            else
            {
                _ignoreBackgroundImageViewScroll = false;
                _dragKeyboardByTablePanningStartPoint = (int)_tableView.contentOffset.y;
            }
        }
    }
    else
    {
        if (_dragKeyboardByTablePanning)
        {
            CGPoint point = [recognizer locationInView:self.view];
            
            int dragOffset = (int)(point.y - _dragKeyboardByTablePanningPanPoint);
            if (dragOffset > 0)
                [self maybeHideKeyboard:[recognizer velocityInView:self.view].y scrollToBottom:_dragKeyboardByTablePanningStartOffset < 16];
            _dragKeyboardByTablePanning = false;
        }
        
        _swipeKeyboardOpen = false;
    }
}

- (bool)dragKeyboard:(int)offset
{
    int keyboardHeight = _knownKeyboardHeight;
    int newHeight = keyboardHeight - offset;
    if (newHeight < 0)
        newHeight = 0;
    if (newHeight > keyboardHeight)
        newHeight = keyboardHeight;

    [self changeInputAreaHeight:newHeight duration:0 orientationChange:true dragging:true completion:nil];
    
    UIWindow *keyboardWindow = findKeyboardWindow();
    if (keyboardWindow != nil)
    {
        CGRect frame = keyboardWindow.frame;
        
        switch (self.interfaceOrientation)
        {
            case UIInterfaceOrientationPortrait:
                frame.origin.y = keyboardHeight - newHeight;
                break;
            case UIInterfaceOrientationLandscapeLeft:
                frame.origin.x = keyboardHeight - newHeight;
                break;
            case UIInterfaceOrientationLandscapeRight:
                frame.origin.x = - (keyboardHeight - newHeight);
                break;
            default:
                break;
        }
        
        keyboardWindow.frame = frame;
    }
    
    if (newHeight != keyboardHeight)
        return true;
    return false;
}

- (void)maybeHideKeyboard:(float)swipeVelocity scrollToBottom:(bool)scrollToBottom
{
    [TGViewController disableAutorotationFor:0.3];
    
    UIWindow *keyboardWindow = findKeyboardWindow();
    if (keyboardWindow != nil && (keyboardWindow.frame.origin.y != 0 || keyboardWindow.frame.origin.x != 0))
    {
        CGRect frame = keyboardWindow.frame;
        frame.origin = CGPointZero;
        [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^
        {
            keyboardWindow.frame = frame;
        } completion:nil];
    }
    
    if (swipeVelocity < 0.0f)
    {
        int keyboardHeight = _knownKeyboardHeight;
        
        [self changeInputAreaHeight:keyboardHeight duration:0.25 orientationChange:false dragging:false completion:nil];
        
        UIEdgeInsets tableInset = _tableView.contentInset;
        if (scrollToBottom && ABS(swipeVelocity) < 260 && _tableView.contentSize.height > _tableView.frame.size.height - tableInset.bottom - tableInset.top)
        {
            [UIView animateWithDuration:0.25 animations:^
            {
                [_tableView setContentOffset:CGPointMake(0, -_tableView.contentInset.top)];
            }];
        }
    }
    else
    {
        [self closeKeyboard];
        
        UIEdgeInsets tableInset = _tableView.contentInset;
        if (scrollToBottom && ABS(swipeVelocity) < 260 && _tableView.contentSize.height > _tableView.frame.size.height - tableInset.bottom - tableInset.top)
        {
            [UIView animateWithDuration:0.25 animations:^
            {
                [_tableView setContentOffset:CGPointMake(0, -_tableView.contentInset.top)];
            }];
        }
    }
}

- (void)timeToLoadMoreHistory
{
    if (_appearingAnimation || !self.isViewLoaded || self.view.window == nil)
        return;
    
    if (((_tableView.contentOffset.y > _tableView.contentSize.height - _tableView.frame.size.height * 2) || !_onceLoadedMore) && _canLoadMoreHistory && !_conversationCompanion.isLoading)
    {
        _onceLoadedMore = true;
        [_conversationCompanion loadMoreHistory];
    }
}

- (bool)shouldReadHistory
{
    return self.isViewLoaded && self.view.window != nil && [[UIApplication sharedApplication] applicationState] == UIApplicationStateActive && !_appearingAnimation;
}

- (void)setMessageText:(NSString *)text
{
    _initialMessageText = text;
    if (_inputField != nil)
    {
        _inputField.text = text;
    }
    else if (_fakeInputFieldLabel != nil)
    {
        CGRect initialFrame = CGRectMake(40 + 9, 4 + (TGIsRetina() ? 8.5f : 8), self.view.frame.size.width - 106 - 22, 200);
        CGRect frame = initialFrame;
        
        _fakeInputFieldLabel.frame = frame;
        
        if ([text characterAtIndex:text.length - 1] == '\n')
            _fakeInputFieldLabel.text = [text stringByAppendingString:@" "];
        else
            _fakeInputFieldLabel.text = text;
        [_fakeInputFieldLabel sizeToFit];

        frame = _fakeInputFieldLabel.frame;
        frame.size.width = initialFrame.size.width;
        
        _fakeInputFieldLabel.frame = frame;
        
        [self growingTextView:nil willChangeHeight:MAX(36, MIN(frame.size.height + 10 + 10 - 4, UIInterfaceOrientationIsPortrait(self.interfaceOrientation) ? ([TGViewController isWidescreen] ? 156 : 116) : 76)) animated:false];
        
        if (text.length != 0)
            _placeholderLabel.hidden = true;
    }
}

- (void)disableSendButton:(bool)disable
{
    if ([NSThread isMainThread])
        _sendButton.userInteractionEnabled = !disable;
    else
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            _sendButton.userInteractionEnabled = !disable;
        });
    }
}

- (void)conversationSignleParticipantChanged:(TGUser *)singleParticipant
{
    bool singleParticipantAvatarUpdateNeeded = _chatSingleParticipant == nil;
    
    _chatSingleParticipant = singleParticipant;
    
    if (!self.isViewLoaded)
        return;
    
    if (!_conversationCompanion.isMultichat || _conversationCompanion.isEncrypted)
    {
        TGUser *user = singleParticipant;
        
        if ((_avatarImageView.currentUrl != nil) != (user.photoUrlSmall != nil) || (_avatarImageView.currentUrl != nil && ![_avatarImageView.currentUrl isEqualToString:user.photoUrlSmall]) || singleParticipantAvatarUpdateNeeded)
        {
            _avatarImageView.fadeTransitionDuration = 0.14;
            if (user.photoUrlSmall != nil)
            {
                [_avatarImageView loadImage:user.photoUrlSmall filter:@"titleAvatar" placeholder:[_conversationCompanion titleAvatarPlaceholderGeneric] forceFade:true];
            }
            else
                [_avatarImageView loadImage:[_conversationCompanion titleAvatarPlaceholder]];
        }
    }
    
    if (_conversationCompanion.isEncrypted && _encryptionStatus == 1)
    {
        NSString *formatText = TGLocalized(@"Conversation.EncryptionWaiting");
        NSString *baseText = [[NSString alloc] initWithFormat:formatText, _chatSingleParticipant.displayFirstName];
        if ([_editingStateLabel respondsToSelector:@selector(setAttributedText:)])
        {
            NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:_editingStateLabel.font, NSFontAttributeName, nil];
            NSDictionary *subAttrs = [NSDictionary dictionaryWithObjectsAndKeys:[UIFont boldSystemFontOfSize:_editingStateLabel.font.pointSize], NSFontAttributeName, nil];
            int location = [formatText rangeOfString:@"%@"].location;
            int length = baseText.length - (formatText.length - 2);
            NSRange range = NSMakeRange(location, length);
            
            NSMutableAttributedString *attributedText = [[NSMutableAttributedString alloc] initWithString:baseText attributes:attrs];
            [attributedText setAttributes:subAttrs range:range];
            
            [_editingStateLabel setAttributedText:attributedText];
        }
        else
            _editingStateLabel.text = baseText;
    }
    
    [self updateTitle:true];
}

- (void)conversationParticipantDataChanged:(TGUser *)user
{
    if (!_conversationCompanion.isMultichat || _conversationCompanion.isEncrypted)
    {
        if ((_avatarImageView.currentUrl != nil) != (user.photoUrlSmall != nil) || (_avatarImageView.currentUrl != nil && ![_avatarImageView.currentUrl isEqualToString:user.photoUrlSmall]))
        {
            _avatarImageView.fadeTransitionDuration = 0.3;
            UIImage *placeholder = [_avatarImageView currentImage];
            [_avatarImageView loadImage:user.photoUrlSmall filter:@"titleAvatar" placeholder:(placeholder != nil ? placeholder : [_conversationCompanion titleAvatarPlaceholderGeneric]) forceFade:true];
        }
        
        [_actionsPanel setIsCallingAllowed:(user.phoneNumber != nil && user.phoneNumber.length != 0)];
    }
    else
    {   
        int uid = user.uid;
        
        Class messageCellClass = [TGConversationMessageItemView class];
        for (UITableViewCell *cell in [_tableView visibleCells])
        {
            if ([cell isKindOfClass:messageCellClass])
            {
                TGConversationMessageItemView *messageView = (TGConversationMessageItemView *)cell;
                if (messageView.message.fromUid == uid)
                {
                    [messageView changeAvatarAnimated:user.photoUrlSmall];
                }
            }
        }
    }
}

- (void)conversationAvatarChanged:(NSString *)url
{
    if (!_conversationCompanion.isEncrypted)
    {
        if (url != nil && url.length != 0)
        {
            if ((_avatarImageView.currentUrl != nil) != (url != nil) || (_avatarImageView.currentUrl != nil && ![_avatarImageView.currentUrl isEqualToString:url]))
            {
                UIImage *placeholder = [_avatarImageView currentImage];
                _avatarImageView.fadeTransitionDuration = 0.3;
                [_avatarImageView loadImage:url filter:@"titleAvatar" placeholder:(placeholder != nil ? placeholder : [_conversationCompanion titleAvatarPlaceholderGeneric]) forceFade:true];
            }
        }
        else
        {
            [_avatarImageView loadImage:[_conversationCompanion titleAvatarPlaceholder]];
        }
    }
}

- (void)conversationParticipantPresenceChanged:(int)__unused uid presence:(TGUserPresence)__unused presence
{
}

- (void)conversationTitleChanged:(NSString *)title subtitle:(NSString *)subtitle typingSubtitle:(NSString *)typingSubtitle isContact:(bool)isContact
{
    _chatTitle = title;
    _chatSubtitle = subtitle;
    _chatTypingSubtitle = typingSubtitle;
    
    _isContact = isContact;
    
    if (_actionsPanel != nil && !_conversationCompanion.isMultichat && !_conversationCompanion.isBroadcast)
        [_actionsPanel setIsBlockAllowed:!isContact];
    
    if (!self.isViewLoaded)
        return;
    
    _titleTextLabel.text = title;
    if (![self setStatusText:subtitle typingStatusText:typingSubtitle animated:(CFAbsoluteTimeGetCurrent() - _appearingAnimationStart > 0.25)])
        [self updateTitle:(CFAbsoluteTimeGetCurrent() - _appearingAnimationStart > 0.25)];
}

- (void)messageLifetimeChanged:(int)messageLifetime
{
    if (_messageLifetime != messageLifetime)
    {
        _messageLifetime = messageLifetime;
        
        [self updateTitle:false];
    }
}

- (UIView *)titleStatusContainer
{
    if (_titleStatusContainer == nil)
    {
        _titleStatusContainer = [[UIView alloc] initWithFrame:CGRectMake(floorf((_titleContainer.frame.size.width - 40) / 2), 0, 40, 30)];
        _titleStatusContainer.clipsToBounds = false;
        
        _titleStatusLabel = [[TGLabel alloc] initWithFrame:CGRectZero];
        _titleStatusLabel.clipsToBounds = false;
        _titleStatusLabel.backgroundColor = [UIColor clearColor];
        _titleStatusLabel.textColor = [UIColor whiteColor];
        _titleStatusLabel.shadowColor = UIColorRGB(0x415a7e);
        _titleStatusLabel.shadowOffset = CGSizeMake(0, -1);
        _titleStatusLabel.font = [UIFont boldSystemFontOfSize:15];
        _titleStatusLabel.verticalAlignment = TGLabelVericalAlignmentTop;
        [_titleStatusContainer addSubview:_titleStatusLabel];
        
        _titleStatusIndicator = [[TGActivityIndicatorView alloc] initWithStyle:TGActivityIndicatorViewStyleSmallWhite];
        [_titleStatusContainer addSubview:_titleStatusIndicator];
        
        _titleStatusContainer.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        [_titleContainer addSubview:_titleStatusContainer];
    }
    
    return _titleStatusContainer;
}

- (void)synchronizationStatusChanged:(TGConversationControllerSynchronizationState)state
{
    _synchronizationStatus = state;
    
    switch (_synchronizationStatus)
    {
        case TGConversationControllerSynchronizationStateNone:
        {
            if (_titleStatusContainer != nil)
            {
                _titleStatusContainer.hidden = true;
                [_titleStatusIndicator stopAnimating];
            }
            
            break;
        }
        case TGConversationControllerSynchronizationStateConnecting:
        case TGConversationControllerSynchronizationStateUpdating:
        case TGConversationControllerSynchronizationStateWaitingForNetwork:
        {
            self.titleStatusContainer.hidden = false;
            if (_synchronizationStatus == TGConversationControllerSynchronizationStateWaitingForNetwork)
                _titleStatusLabel.text = TGLocalized(@"State.WaitingForNetwork");
            else if (_synchronizationStatus == TGConversationControllerSynchronizationStateConnecting)
                _titleStatusLabel.text = TGLocalized(@"State.Connecting");
            else
                _titleStatusLabel.text = TGLocalized(@"State.Updating");
            [_titleStatusIndicator startAnimating];
            
            [_titleStatusLabel sizeToFit];
            _titleStatusLabel.frame = CGRectIntegral(CGRectMake((_titleStatusLabel.superview.frame.size.width - _titleStatusLabel.frame.size.width + _titleStatusIndicator.frame.size.width + 5) / 2, (_titleStatusLabel.superview.frame.size.height - _titleStatusLabel.frame.size.height) / 2 - 3, _titleStatusLabel.frame.size.width, _titleStatusLabel.frame.size.height));
            _titleStatusIndicator.frame = CGRectMake(_titleStatusLabel.frame.origin.x - _titleStatusIndicator.frame.size.width - 5, _titleStatusLabel.frame.origin.y + 3, _titleStatusIndicator.frame.size.width, _titleStatusIndicator.frame.size.height);
            
            break;
        }
        default:
            break;
    }
    
    [self updateTitle:false];
}

- (void)conversationLinkChanged:(int)__unused link
{
    return;
    
    /*if (link != _conversationLink)
    {
        [self setConversationLink:link animated:(CFAbsoluteTimeGetCurrent() - _appearingAnimationStart > 0.25) && _canLoadMoreHistoryProcessedAtLeastOnce];
    }*/
}

- (void)setUserBlocked:(bool)userBlocked
{
    _userBlocked = userBlocked;
    
    if (_actionsPanel != nil)
        [_actionsPanel setUserIsBlocked:_userBlocked];
    
    [self setConversationLink:_conversationLink animated:(CFAbsoluteTimeGetCurrent() - _appearingAnimationStart > 0.25) && _canLoadMoreHistoryProcessedAtLeastOnce];
}

- (void)setConversationMuted:(bool)conversationMuted
{
    if (_conversationMuted != conversationMuted)
    {
        _conversationMuted = conversationMuted;
        
        if (_conversationCompanion.isMultichat && _actionsPanel != nil)
            [_actionsPanel setIsMuted:conversationMuted];
        
        if (conversationMuted && _muteIconView == nil)
        {
            _muteIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"ConversationMuted.png"]];
            [_titleLabelsContainer addSubview:_muteIconView];
        }
        
        _muteIconView.hidden = !conversationMuted;
        [self updateTitle:false];
    }
}

- (void)setEncryptionStatus:(int)status
{
    _encryptionStatus = status;
    
    if (status == 0)
    {
        _editingStateLabel.text = @"";
    }
    else if (status == 1)
    {
        NSString *formatText = TGLocalized(@"Conversation.EncryptionWaiting");
        NSString *baseText = [[NSString alloc] initWithFormat:formatText, _chatSingleParticipant.displayFirstName];
        if ([_editingStateLabel respondsToSelector:@selector(setAttributedText:)])
        {
            NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:_editingStateLabel.font, NSFontAttributeName, nil];
            NSDictionary *subAttrs = [NSDictionary dictionaryWithObjectsAndKeys:[UIFont boldSystemFontOfSize:_editingStateLabel.font.pointSize], NSFontAttributeName, nil];
            int location = [formatText rangeOfString:@"%@"].location;
            int length = baseText.length - (formatText.length - 2);
            NSRange range = NSMakeRange(location, length);
            
            NSMutableAttributedString *attributedText = [[NSMutableAttributedString alloc] initWithString:baseText attributes:attrs];
            [attributedText setAttributes:subAttrs range:range];
            
            [_editingStateLabel setAttributedText:attributedText];
        }
        else
            _editingStateLabel.text = baseText;
    }
    else if (status == 2)
    {
        _editingStateLabel.text = TGLocalized(@"Conversation.EncryptionProcessing");
    }
    else if (status == 3 || status == 4)
    {
        _editingStateLabel.text = @"";
    }
    
    [self setConversationLink:_conversationLink animated:(CFAbsoluteTimeGetCurrent() - _appearingAnimationStart > 0.25)];
}

- (void)setConversationLink:(int)link animated:(bool)animated
{
    _conversationLink = link;
    
    if (_conversationCompanion.isEncrypted && (_encryptionStatus == 1 || _encryptionStatus == 0 || _encryptionStatus == 2 || _encryptionStatus == 3))
    {
        if (_editingContainer.alpha < 1.0f - FLT_EPSILON)
        {
            [self setEditingContainerVisible:true editingMode:false animated:animated];
            
            _editingForwardButton.alpha = 0.0f;
            _editingDeleteButton.alpha = 0.0f;
            
            _editingRequestContainer.alpha = 1.0f;
        }
        else
        {
            if (animated)
            {
                [UIView animateWithDuration:0.3 animations:^
                 {
                     _editingForwardButton.alpha = 0.0f;
                     _editingDeleteButton.alpha = 0.0f;
                     
                     _editingRequestContainer.alpha = 1.0f;
                 }];
            }
            else
            {
                _editingForwardButton.alpha = 0.0f;
                _editingDeleteButton.alpha = 0.0f;
                
                _editingRequestContainer.alpha = 1.0f;
            }
        }
        
        _editingUnblockButton.alpha = 0.0f;
        
        _editingRequestButton.alpha = 0.0f;
        _editingBlockButton.alpha = 0.0f;
        _editingAcceptButton.alpha = 0.0f;
        
        if (_encryptionStatus == 3)
        {
            _editingUnblockButton.alpha = 1.0f;
            [_editingUnblockButton setTitle:TGLocalized(@"Conversation.DeleteChat") forState:UIControlStateNormal];
        }
        
        _editingStateLabel.alpha = 1.0f;
    }
    else if (_userBlocked)
    {
        [_editingUnblockButton setTitle:_conversationCompanion.isMultichat && !_conversationCompanion.isEncrypted ? TGLocalized(@"Conversation.DeleteGroup") : TGLocalized(@"Conversation.UnblockUser") forState:UIControlStateNormal];
        
        if (_editingContainer.alpha < 1.0f - FLT_EPSILON)
        {
            [self setEditingContainerVisible:true editingMode:false animated:animated];
            
            _editingForwardButton.alpha = 0.0f;
            _editingDeleteButton.alpha = 0.0f;
            
            _editingRequestContainer.alpha = 1.0f;
        }
        else
        {
            if (animated)
            {
                [UIView animateWithDuration:0.3 animations:^
                {
                    _editingForwardButton.alpha = 0.0f;
                    _editingDeleteButton.alpha = 0.0f;
                    
                    _editingRequestContainer.alpha = 1.0f;
                }];
            }
            else
            {
                _editingForwardButton.alpha = 0.0f;
                _editingDeleteButton.alpha = 0.0f;
                
                _editingRequestContainer.alpha = 1.0f;
            }
        }
        
        _editingUnblockButton.alpha = 1.0f;
        
        _editingRequestButton.alpha = 0.0f;
        _editingBlockButton.alpha = 0.0f;
        _editingAcceptButton.alpha = 0.0f;
        
        _editingStateLabel.alpha = 0.0f;
    }
    else
    {
        if (_editingContainer.alpha > FLT_EPSILON)
        {
            [self setEditingContainerVisible:false editingMode:false animated:animated];
            
            if (animated)
            {
                TGDispatchAfter(0.25, dispatch_get_main_queue(), ^
                {
                    _editingForwardButton.alpha = 1.0f;
                    _editingDeleteButton.alpha = 1.0f;
                    
                    _editingRequestContainer.alpha = 0.0f;
                });
            }
            else
            {
                _editingForwardButton.alpha = 1.0f;
                _editingDeleteButton.alpha = 1.0f;
                
                _editingRequestContainer.alpha = 0.0f;
            }
        }
    }
}

- (void)freezeConversation:(bool)freeze
{
    _tableView.scrollEnabled = !freeze;
}

- (void)conversationHistoryFullyReloaded:(NSArray *)items
{
    [self conversationHistoryFullyReloaded:items scrollToMid:0 scrollFlags:0];
}

- (void)conversationHistoryFullyReloaded:(NSArray *)items scrollToMid:(int)scrollToMid scrollFlags:(int)scrollFlags
{
    [self applyDelayedBlock];
    
    bool fadeOut = items.count != 0 && _listModel.count == 0;
    bool reportTime = _listModel.count == 0;
    
    _disableDownwardsHistoryLoading = true;
    
    int previousCount = _listModel.count;
    
    if (scrollFlags & TGConversationControllerUpdateFlagsScrollDown)
    {
        for (id object in items.reverseObjectEnumerator)
        {
            [_listModel insertObject:object atIndex:0];
        }
    }
    else
    {
        [_listModel removeAllObjects];
        [_listModel addObjectsFromArray:items];
    }
    
    if (_actionsPanel != nil)
        [_actionsPanel setIsEditingAllowed:_listModel.count != 0];
    
    [self updateEmptyState:true];
    
    if (!self.isViewLoaded || self.view.window == nil || ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground && CFAbsoluteTimeGetCurrent() - [_conversationCompanion applicationManager].enteredBackgroundTime > 2 * 60))
    {
        _disableDownwardsHistoryLoading = false;
        _disableMessageBackgroundDrawing = false;
        _tableNeedsReloading = true;
        return;
    }
    
    if (!fadeOut || scrollToMid || (scrollFlags & TGConversationControllerUpdateFlagsScrollKeep))
        _disableMessageBackgroundDrawing = true;
    
    float savedContentOffset = 0;
    if ((scrollFlags & TGConversationControllerUpdateFlagsScrollKeep) || (scrollFlags & TGConversationControllerUpdateFlagsScrollDown))
    {
        savedContentOffset = _tableView.contentSize.height - _tableView.contentOffset.y;
    }
    
    [_tableView reloadData];
    [_tableView layoutSubviews];
    
    if (fadeOut)
    {
        _tableView.alpha = 0.0f;
        [UIView animateWithDuration:0.16 animations:^
        {
            _tableView.alpha = 1.0f;
        }];
    }
    
    if (scrollFlags & TGConversationControllerUpdateFlagsScrollToUnread)
    {
        int index = -1;
        for (TGConversationItem *item in _listModel)
        {
            index++;
            
            if (item.type == TGConversationItemTypeUnread)
            {
#if TGUseCollectionView
                CGRect rect = [_tableView layoutAttributesForItemAtIndexPath:[NSIndexPath indexPathForItem:index inSection:0]].frame;
#else
                CGRect rect = [_tableView rectForRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]];
#endif
                if (rect.origin.y > FLT_EPSILON)
                {
                    rect.origin.y += -3;
                    [_tableView scrollRectToVisible:rect animated:false];
                }
                break;
            }
        }
    }
    else if (scrollToMid)
    {
        int index = -1;
        for (TGConversationItem *item in _listModel)
        {
            index++;
            
            if (item.type == TGConversationItemTypeMessage && ((TGConversationMessageItem *)item).message.mid == scrollToMid)
            {
#if TGUseCollectionView
                CGRect rect = [_tableView layoutAttributesForItemAtIndexPath:[NSIndexPath indexPathForItem:index inSection:0]].frame;
#else
                CGRect rect = [_tableView rectForRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]];
#endif
                if (rect.origin.y > FLT_EPSILON)
                {
                    rect.origin.y += -2;

                    float contentOffset = rect.origin.y - ((_tableView.frame.size.height - _tableView.contentInset.top - _tableView.contentInset.bottom) - rect.size.height) / 2;
                    /*
                    float screenPosition = rect.origin.y + rect.size.height - contentOffset;
                    float tableArea = _tableView.frame.size.height - _tableView.contentInset.top;
                    if (screenPosition > tableArea)
                    {
                        contentOffset = (rect.origin.y + rect.size.height) - (_tableView.frame.size.height - _tableView.contentInset.top);
                    }*/
                    [_tableView setContentOffset:CGPointMake(0, MAX(0, MIN(_tableView.contentSize.height - _tableView.frame.size.height, contentOffset))) animated:false];
                }
                
#if TGUseCollectionView
                TGConversationMessageItemView *messageView = (TGConversationMessageItemView *)[_tableView cellForItemAtIndexPath:[NSIndexPath indexPathForItem:index inSection:0]];
#else
                TGConversationMessageItemView *messageView = (TGConversationMessageItemView *)[_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]];
#endif
                if ([messageView isKindOfClass:[TGConversationMessageItemView class]])
                {
                    _currentlyHighlightedMid = scrollToMid;
                    
                    [messageView setIsContextSelected:true animated:false];
                    
                    if (!_appearingAnimation)
                        [self _fadeOutCurrentlyHighlightedMessage];
                }
                
                break;
            }
        }
    }
    else if (scrollFlags & TGConversationControllerUpdateFlagsScrollKeep)
    {
        //[_tableView setContentOffset:CGPointMake(0, MAX(0, _tableView.contentSize.height - savedContentOffset)) animated:false];
        _tableView.contentOffset = CGPointMake(0, MAX(0, _tableView.contentSize.height - savedContentOffset));
    }
    else if (scrollFlags & TGConversationControllerUpdateFlagsScrollDown)
    {
        _tableView.contentOffset = CGPointMake(0, MAX(0, _tableView.contentSize.height - savedContentOffset));
        
        [_tableView setContentOffset:CGPointMake(0, -_tableView.contentInset.top) animated:true];
        
        _tableView.userInteractionEnabled = false;
        TGDispatchAfter(0.3, dispatch_get_main_queue(), ^
        {
            _tableView.userInteractionEnabled = true;
            
            if (_listModel.count >= previousCount)
            {
                [_listModel removeObjectsInRange:NSMakeRange(_listModel.count - previousCount, previousCount)];
                
                _disableMessageBackgroundDrawing = true;
                [_tableView reloadData];
                _disableMessageBackgroundDrawing = false;
            }
            else
            {
                [self conversationHistoryFullyReloaded:items scrollToMid:0 scrollFlags:0];
            }
        });
    }
    
    [self updateCellAnimations];
    
    _disableMessageBackgroundDrawing = false;
    _disableDownwardsHistoryLoading = false;
    
    if (reportTime)
    {
        TGLog(@"First items appeared: %f ms", (CFAbsoluteTimeGetCurrent() - _appearingAnimationStart) * 1000.0);
    }
}

- (void)precalculateItemMetrics:(TGConversationItem *)item
{
    [self heightForConversationItem:item metrics:_messageMetrics];
}

- (void)clearInputText
{
#if TGInputFieldClassIsHP
    _inputField.oneTimeLongAnimation = true;
#endif
    _inputField.text = @"";
}

- (void)scrollDownOnNextUpdate:(bool)andClearText
{
    if (!self.isViewLoaded)
        return;
    
    _shouldScrollDownOnNextUpdate = true;
    if (andClearText)
    {
#if TGInputFieldClassIsHP
        _inputField.oneTimeLongAnimation = true;
#endif
        _inputField.text = @"";
    }
}

- (void)conversationMessagesCleared
{
    [UIView animateWithDuration:0.3f animations:^
    {
        _tableView.alpha = 0.0f;
    } completion:^(__unused BOOL finished)
    {
        [self setEditingMode:false];
        [self conversationHistoryFullyReloaded:[NSArray array]];
        
        [UIView animateWithDuration:0.3f animations:^
        {
            _tableView.alpha = 1.0f;
        }];
    }];
}

- (void)conversationMessageUploadProgressChanged:(std::tr1::shared_ptr<std::map<int, float> >)pMessageUploadProgress
{
    bool wasEmpty = _pMessageUploadProgress == NULL || _pMessageUploadProgress->empty();
    bool updateCells = false;
    
    _pMessageUploadProgress = pMessageUploadProgress;
    
    if (_pMessageUploadProgress != NULL)
        updateCells = true;
    else if (!wasEmpty)
        updateCells = true;
    
    if (updateCells)
        [self updateCellsProgress];
}

- (void)conversationMediaDownloadProgressChanged:(NSMutableDictionary *)mediaDownloadProgress
{
    bool wasEmpty = _mediaDownloadProgress == nil || _mediaDownloadProgress.count == 0;
    bool updateCells = false;
    
    if (mediaDownloadProgress != NULL)
        updateCells = true;
    else if (!wasEmpty)
        updateCells = true;
    
    _mediaDownloadProgress = mediaDownloadProgress;
    
    if (updateCells)
        [self updateCellsProgress];
}

- (void)updateCellsProgress
{
    Class messageCellClass = [TGConversationMessageItemView class];
    for (UITableViewCell *cell in _tableView.visibleCells)
    {
        if ([cell isKindOfClass:messageCellClass])
        {
            TGConversationMessageItemView *messageCell = (TGConversationMessageItemView *)cell;
            
            bool hasProgress = false;
            float progress = 0.0f;
            
            if (_pMessageUploadProgress != NULL)
            {
                std::map<int, float>::iterator it = _pMessageUploadProgress->find(messageCell.message.mid);
                if (it != _pMessageUploadProgress->end())
                {
                    hasProgress = true;
                    progress = it->second;
                }
            }
            
            if (!hasProgress)
            {
                if (_mediaDownloadProgress != NULL)
                {
                    id mediaId = messageCell.messageItem.progressMediaId;
                    if (mediaId != nil)
                    {
                        NSNumber *nProgress = [_mediaDownloadProgress objectForKey:mediaId];
                        if (nProgress != nil)
                        {
                            hasProgress = true;
                            progress = [nProgress floatValue];
                        }
                    }
                }
            }
            
            [messageCell setProgress:hasProgress progress:progress animated:true];
        }
    }
}

- (void)addProcessedMediaDownloadedStatuses:(NSDictionary *)dict
{
    [_mediaDownloadedStatuses addEntriesFromDictionary:dict];
    
    Class messageCellClass = [TGConversationMessageItemView class];
    for (UITableViewCell *cell in _tableView.visibleCells)
    {
        if ([cell isKindOfClass:messageCellClass])
        {
            TGConversationMessageItemView *messageCell = (TGConversationMessageItemView *)cell;
            
            id mediaId = messageCell.messageItem.progressMediaId;
            if (mediaId != nil)
            {
                NSNumber *nStatus = [_mediaDownloadedStatuses objectForKey:mediaId];
                [messageCell setMediaNeedsDownload:![nStatus boolValue]];
            }
        }
    }
}

- (void)reloadImageThumbnailsWithUrl:(NSString *)url
{
    Class messageCellClass = [TGConversationMessageItemView class];
    for (UITableViewCell *cell in _tableView.visibleCells)
    {
        if ([cell isKindOfClass:messageCellClass])
        {
            TGConversationMessageItemView *messageCell = (TGConversationMessageItemView *)cell;
            [messageCell reloadImageThumbnailWithUrl:url];
        }
    }
}

- (void)messageIdsChanged:(NSArray *)mapping
{
    if (_hiddenMediaMid != 0)
    {
        int count = mapping.count;
        for (int i = 0; i < count; i += 2)
        {
            if ([mapping[i] intValue] == _hiddenMediaMid)
            {
                _hiddenMediaMid = ((TGMessage *)mapping[i + 1]).mid;
                break;
            }
        }
    }
}

- (void)updateEmptyState:(bool)empty
{
    if (empty && _listModel.count == 0)
    {
        if (_emptyConversationContainer == nil)
        {
            CGSize containerSize = _conversationCompanion.isEncrypted ? CGSizeMake(229, 185) : CGSizeMake(122, 116);
            
            _emptyConversationContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, containerSize.width, containerSize.height)];
            _emptyConversationContainer.userInteractionEnabled = false;
            
            UIImageView *backgroundView = [[UIImageView alloc] initWithImage:[_conversationCompanion.messageAssetsSource systemMessageBackground]];
            backgroundView.tag = 101;
            backgroundView.frame = _emptyConversationContainer.bounds;
            backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            
            [_emptyConversationContainer addSubview:backgroundView];
            
            if (_conversationCompanion.isEncrypted)
            {
                bool incoming = _conversationCompanion.encryptionIsIncoming;
                
                UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 12, containerSize.width - 20 * 2, 42)];
                titleLabel.textAlignment = NSTextAlignmentCenter;
                titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
                titleLabel.numberOfLines = 2;
                titleLabel.textColor = [UIColor whiteColor];
                titleLabel.backgroundColor = [UIColor clearColor];
                titleLabel.font = [UIFont boldSystemFontOfSize:13];
                
                NSString *firstName = _chatSingleParticipant.displayFirstName;
                
                if (firstName.length > 16)
                    firstName = [[NSString alloc] initWithFormat:@"%@...", [firstName substringToIndex:16]];
                
                titleLabel.text = [[NSString alloc] initWithFormat:incoming ? TGLocalized(@"Conversation.EncryptedPlaceholderTitleIncoming") : TGLocalized(@"Conversation.EncryptedPlaceholderTitleOutgoing"), firstName];
                
                [_emptyConversationContainer addSubview:titleLabel];
                
                UILabel *descriptionTitle = [[UILabel alloc] init];
                descriptionTitle.textColor = [UIColor whiteColor];
                descriptionTitle.backgroundColor = [UIColor clearColor];
                descriptionTitle.font = [UIFont boldSystemFontOfSize:13];
                descriptionTitle.text = TGLocalized(@"Conversation.EncryptedDescriptionTitle");
                [descriptionTitle sizeToFit];
                descriptionTitle.frame = CGRectOffset(descriptionTitle.frame, 16, 66);
                [_emptyConversationContainer addSubview:descriptionTitle];
                
                UIImage *lockImage = [UIImage imageNamed:@"SmallLockIcon.png"];
                
                CGPoint descriptionLabelOrigin = CGPointMake(16, 92);
                for (int i = 0; i < 4; i++)
                {
                    UIImageView *iconView = [[UIImageView alloc] initWithImage:lockImage];
                    iconView.frame = CGRectOffset(iconView.frame, descriptionLabelOrigin.x, descriptionLabelOrigin.y);
                    [_emptyConversationContainer addSubview:iconView];
                    
                    UILabel *descriptionLabel = [[UILabel alloc] init];
                    descriptionLabel.textColor = [UIColor whiteColor];
                    descriptionLabel.backgroundColor = [UIColor clearColor];
                    descriptionLabel.font = [UIFont systemFontOfSize:13];
                    descriptionLabel.text = TGLocalized(([[NSString alloc] initWithFormat:@"Conversation.EncryptedDescription%d", (i + 1)]));
                    [descriptionLabel sizeToFit];
                    descriptionLabel.frame = CGRectOffset(descriptionLabel.frame, descriptionLabelOrigin.x + 17, descriptionLabelOrigin.y - 2);
                    [_emptyConversationContainer addSubview:descriptionLabel];
                    
                    descriptionLabelOrigin.y += 22;
                }
            }
            else
            {
                UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"ConversationIconPlain.png"]];
                iconView.frame = CGRectMake(floorf((_emptyConversationContainer.frame.size.width - iconView.frame.size.width) / 2), 23, iconView.frame.size.width, iconView.frame.size.height);
                [_emptyConversationContainer addSubview:iconView];
                
                UILabel *label = [[UILabel alloc] init];
                label.tag = 100;
                label.textColor = [_conversationCompanion.messageAssetsSource messageActionTextColor];
                label.font = [UIFont boldSystemFontOfSize:13];
                label.textAlignment = UITextAlignmentCenter;
                label.backgroundColor = [UIColor clearColor];
                label.numberOfLines = 0;
                label.lineBreakMode = NSLineBreakByWordWrapping;
                if (_conversationCompanion.conversationId == 333000)
                    label.text = TGLocalized(@"Conversation.SupportPlaceholder");
                else
                    label.text = TGLocalized(@"Conversation.EmptyPlaceholder");
                CGSize labelSize = [label sizeThatFits:CGSizeMake(110, 1000)];
                label.frame = CGRectMake(floorf((_emptyConversationContainer.frame.size.width - labelSize.width) / 2), _emptyConversationContainer.frame.size.height - labelSize.height - 8, labelSize.width, labelSize.height);

                [_emptyConversationContainer addSubview:label];
            }
            
            [self.view insertSubview:_emptyConversationContainer aboveSubview:_tableView];
            
            [self updateEmptyConversationContainer];
            
            if (CFAbsoluteTimeGetCurrent() > _appearingAnimationStart + 0.15f)
            {
                _emptyConversationContainer.alpha = 0.0f;
                
                UIView *view = _emptyConversationContainer;
                [UIView animateWithDuration:0.3 animations:^
                {
                    view.alpha = 1.0f;
                }];
            }
        }
    }
    else if (_emptyConversationContainer != nil && _listModel.count != 0)
    {
        if (CFAbsoluteTimeGetCurrent() > _appearingAnimationStart + 0.15f)
        {
            UIView *view = _emptyConversationContainer;
            _emptyConversationContainer = nil;
            
            [UIView animateWithDuration:0.3 animations:^
            {
                view.alpha = 0.0f;
            } completion:^(__unused BOOL finished)
            {
                [view removeFromSuperview];
            }];
        }
        else
        {
            [_emptyConversationContainer removeFromSuperview];
            _emptyConversationContainer = nil;
        }
    }
}

- (void)updateEmptyConversationContainer
{
    float viewHeight = self.view.frame.size.height - self.controllerInset.top - self.controllerInset.bottom;
    float viewInsetOffset = self.view.frame.size.height > 400 ? (self.controllerInset.top - (20 + 44)) : (-14);
    
    _emptyConversationContainer.frame = CGRectMake(floorf((self.view.frame.size.width - _emptyConversationContainer.frame.size.width) / 2), viewInsetOffset + floorf((viewHeight - _emptyConversationContainer.frame.size.height) / 2) + (viewHeight > 140 ? 43 : 0), _emptyConversationContainer.frame.size.width, _emptyConversationContainer.frame.size.height);
}

- (void)conversationMessagesChanged:(NSArray *)insertedIndices insertedItems:(NSArray *)insertedItems removedAtIndices:(NSArray *)inputRemovedIndices updatedAtIndices:(NSArray *)updatedIndices updatedItems:(NSArray *)updatedItems delay:(bool)delay scrollDownFlags:(int)scrollDownFlags
{
#if TGUseCollectionView
#else
    dispatch_block_t block = ^
    {
        if (scrollDownFlags & 1)
            [self scrollDownOnNextUpdate:scrollDownFlags & 2];
        
        int heightChange = 0;
        
        NSMutableArray *removedIndexPaths = nil;
        if (inputRemovedIndices != nil)
        {
            NSArray *removedIndices = [inputRemovedIndices sortedArrayUsingSelector:@selector(compare:)];
            
            removedIndexPaths = [[NSMutableArray alloc] initWithCapacity:removedIndices.count];
            for (int i = removedIndices.count - 1; i >= 0; i--)
            {
                NSNumber *index = [removedIndices objectAtIndex:i];
                [removedIndexPaths addObject:[NSIndexPath indexPathForRow:[index intValue] inSection:0]];
                
                TGConversationItem *item = [_listModel objectAtIndex:[index intValue]];
                heightChange -= [self heightForConversationItem:item metrics:_messageMetrics];
                [_listModel removeObjectAtIndex:[index intValue]];
            }
        }
        
        NSMutableArray *insertedIndexPaths = nil;
        if (insertedIndices != nil)
        {
            insertedIndexPaths = [[NSMutableArray alloc] initWithCapacity:insertedIndices.count];
            int i = -1;
            for (NSNumber *index in insertedIndices)
            {
                i++;
                [insertedIndexPaths addObject:[NSIndexPath indexPathForRow:[index intValue] inSection:0]];
                
                TGConversationItem *item = [insertedItems objectAtIndex:i];
                heightChange += [self heightForConversationItem:item metrics:_messageMetrics];
                [_listModel insertObject:item atIndex:[index intValue]];
            }
        }
        
        NSMutableArray *updatedIndexPaths = nil;
        if (updatedIndices != nil)
        {
            updatedIndexPaths = [[NSMutableArray alloc] initWithCapacity:updatedIndices.count];
            int i = -1;
            for (NSNumber *index in updatedIndices)
            {
                i++;
                
                TGConversationItem *item = [updatedItems objectAtIndex:i];
                
                if (!_checkedMessages.empty())
                {
                    if (item.type == TGConversationItemTypeMessage)
                    {
                        TGConversationItem *listItem = [_listModel objectAtIndex:[index intValue]];
                        if (listItem.type == TGConversationItemTypeMessage)
                        {
                            TGMessage *originalMessage = ((TGConversationMessageItem *)listItem).message;
                            TGMessage *newMessage = ((TGConversationMessageItem *)item).message;
                            
                            if (_checkedMessages.find(originalMessage.mid) != _checkedMessages.end())
                            {
                                _checkedMessages.erase(originalMessage.mid);
                                _checkedMessages.insert(newMessage.mid);
                            }
                        }
                    }
                }
                
                [updatedIndexPaths addObject:[NSIndexPath indexPathForRow:[index intValue] inSection:0]];
                
                heightChange -= [self heightForConversationItem:[_listModel objectAtIndex:[index intValue]] metrics:_messageMetrics];
                heightChange += [self heightForConversationItem:item metrics:_messageMetrics];
                [_listModel replaceObjectAtIndex:[index intValue] withObject:item];
            }
        }
        
        if (_actionsPanel != nil)
            [_actionsPanel setIsEditingAllowed:_listModel.count != 0];
        
        [self updateEmptyState:true];
        
        if (!self.isViewLoaded || ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground && CFAbsoluteTimeGetCurrent() - [_conversationCompanion applicationManager].enteredBackgroundTime > 2 * 60))
        {
            _tableNeedsReloading = true;
            return;
        }
        
        if (removedIndexPaths.count + insertedIndexPaths.count > 60)
        {
            [_tableView reloadData];
            [self updateCellAnimations];
            return;
        }
        
        if (updatedIndexPaths != nil && updatedIndexPaths.count != 0)
        {
            for (int i = 0; i < updatedIndexPaths.count; i++)
            {
                NSIndexPath *indexPath = [updatedIndexPaths objectAtIndex:i];
                
                TGConversationItem *item = [_listModel objectAtIndex:indexPath.row];
                
                id cell = [_tableView cellForRowAtIndexPath:indexPath];
                
                if (cell != nil && item.type == TGConversationItemTypeMessage && [cell isKindOfClass:[TGConversationMessageItemView class]])
                {
                    TGMessage *message = ((TGConversationMessageItem *)item).message;
                    
                    TGConversationMessageItemView *messageItemView = (TGConversationMessageItemView *)cell;
                    if (messageItemView.message.mid == message.mid || messageItemView.message.mid == message.localMid)
                    {
                        [messageItemView animateState:message];
                        
                        [updatedIndexPaths removeObjectAtIndex:i];
                        i--;
                    }
                }
            }
        }
        
        bool enableAnimations = false;
        if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground || ![self.view.window isKeyWindow])
        {
            [UIView setAnimationsEnabled:false];
            enableAnimations = true;
        }
        
        bool isSeven = iosMajorVersion() >= 7;
        float animationFactor = 1.0f;
        
        animationFactor = iosMajorVersion() >= 7 ? 1.0f : 0.7f;
        float secondaryFactor = iosMajorVersion() >= 7 ? 0.7f : 1.0f;
        
        if (enableAnimations)
        {
            animationFactor = 0.05f;
            secondaryFactor = 0.05f;
        }
        
        if (!_shouldScrollDownOnNextUpdate)
        {
            if ((_tableView.contentOffset.y > 2 || (scrollDownFlags & 4)) && heightChange > 0)
            {
                animationFactor = 0.0f;
            }
        }
        
        [TGHacks setAnimationDurationFactor:animationFactor];
        [TGHacks setSecondaryAnimationDurationFactor:secondaryFactor];
        
        @try
        {
            dispatch_block_t animationsBlock = ^
            {
                [_tableView beginUpdates];
                
                if (removedIndexPaths != nil && removedIndexPaths.count != 0)
                {
                    [_tableView deleteRowsAtIndexPaths:removedIndexPaths withRowAnimation:UITableViewRowAnimationFade];
                }
                
                if (insertedIndexPaths != nil && insertedIndexPaths.count != 0)
                {
                    [_tableView insertRowsAtIndexPaths:insertedIndexPaths withRowAnimation:UITableViewRowAnimationFade];
                }
                
                if (updatedIndexPaths != nil && updatedIndexPaths.count != 0)
                {
                    [_tableView reloadRowsAtIndexPaths:updatedIndexPaths withRowAnimation:UITableViewRowAnimationFade];
                }
                
                if (_shouldScrollDownOnNextUpdate)
                {
                    [UIView animateWithDuration:(0.3 * animationFactor) animations:^
                    {
                        [_tableView setContentOffset:CGPointMake(0, -_tableView.contentInset.top) animated:false];
                    }];
                }
                else if ((_tableView.contentOffset.y > 2 || (scrollDownFlags & 4)) && heightChange > 0)
                {
                    if (scrollDownFlags & 4)
                    {
                    }
                    else
                    {
                        [UIView animateWithDuration:(0.3 * animationFactor) animations:^
                        {
                            [_tableView setContentOffset:CGPointMake(0, _tableView.contentOffset.y + heightChange)];
                        }];
                    }
                }
                
                [_tableView endUpdates];
            };
            
            if (iosMajorVersion() < 7 || animationFactor > FLT_EPSILON)
                animationsBlock();
            else
            {
                static SEL performWithoutAnimationSelector = NULL;
                if (performWithoutAnimationSelector == NULL)
                    performWithoutAnimationSelector = NSSelectorFromString(TGEncodeText(@"qfsgpsnXjuipvuBojnbujpo;", -1));

                if ([[UIView class] respondsToSelector:performWithoutAnimationSelector])
                {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                    [[UIView class] performSelector:performWithoutAnimationSelector withObject:[animationsBlock copy]];
#pragma clang diagnostic pop
                }
                else
                    animationsBlock();
                
                /*[UIView performWithoutAnimation:^
                {
                    animationsBlock();
                }];*/
            }
            
            if (insertedIndexPaths != nil && insertedIndexPaths.count != 0)// && (removedIndices == nil || removedIndices.count == 0))
            {   
                NSMutableArray *cellsToResetTransform = [[NSMutableArray alloc] init];
                int i = -1;
                for (NSIndexPath *indexPath in insertedIndexPaths)
                {
                    i++;
                    
                    UITableViewCell *cell = [_tableView cellForRowAtIndexPath:indexPath];
                    if (cell != nil)
                    {
                        
                        CGAffineTransform cellTransform = CGAffineTransformMakeRotation((float)M_PI);
                        //cellTransform = CGAffineTransformScale(cellTransform, 0.1f, 0.1f);
                        cellTransform = CGAffineTransformTranslate(cellTransform, 0, cell.frame.size.height);
                        cell.transform = cellTransform;
                        
                        /*if ([cell isKindOfClass:[TGConversationMessageItemView class]])
                        {
                            CATransform3D transform = CATransform3DIdentity;
                            //transform.m34 = 1.0f / -20.0f;
                            //transform = CATransform3DRotate(transform, (float)M_PI, 0, 0, 1.0f);
                            //transform = CATransform3DTranslate(transform, 0.0f, cell.frame.size.height / 2, 0.0f);
                            //transform = CATransform3DRotate(transform, (float)(-M_PI_2 + 0.1f), 1.0f, 0.0f, 0.0f);
                            transform = CATransform3DScale(transform, 0.1f, 0.1f, 1.0f);
                            ((TGConversationMessageItemView *)cell).currentContentView.layer.transform = transform;
                            ((TGConversationMessageItemView *)cell).currentBackgroundView.layer.transform = transform;
                        }*/
                        
                        [cellsToResetTransform addObject:cell];
                    }
                }
                if (cellsToResetTransform.count != 0)
                {
                    [UIView animateWithDuration:((isSeven ? (0.3 * 0.7f) : 0.3) * animationFactor) animations:^
                    {
                        for (UITableViewCell *cell in cellsToResetTransform)
                        {
                            cell.transform = CGAffineTransformMakeRotation(M_PI);
                            /*if ([cell isKindOfClass:[TGConversationMessageItemView class]])
                            {
                                ((TGConversationMessageItemView *)cell).currentContentView.layer.transform = CATransform3DIdentity;
                                ((TGConversationMessageItemView *)cell).currentBackgroundView.layer.transform = transform;
                            }*/
                        }
                    }];
                }
            }
            
            if (scrollDownFlags & 4)
            {
                int index = -1;
                for (TGConversationItem *item in _listModel)
                {
                    index++;
                    
                    if (item.type == TGConversationItemTypeUnread)
                    {
                        CGRect rect = [_tableView rectForRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]];
                        if (rect.origin.y > FLT_EPSILON)
                        {
                            rect.origin.y += -2;
                            [_tableView scrollRectToVisible:rect animated:false];
                        }
                        break;
                    }
                }
            }
            
            if (_tableView.contentOffset.y > 10 && insertedItems != nil)
            {
                for (TGConversationItem *item in insertedItems)
                {
                    if (item.type == TGConversationItemTypeMessage)
                    {
                        TGMessage *message = ((TGConversationMessageItem *)item).message;
                        if (!message.outgoing && message.unread)
                        {
                            [self displayNewMessagesTooltip];
                            
                            break;
                        }
                    }
                }
            }
        }
        @catch (NSException *exception)
        {
            TGLog(@"%@", exception);
            __strong UIView *currentTableView = _tableView;
            _tableView.delegate = nil;
            _tableView.dataSource = nil;
            _tableView = [self createTableView:currentTableView.frame];
            [self.view insertSubview:_tableView aboveSubview:currentTableView];
            [currentTableView removeFromSuperview];
        }
        
        [TGHacks setAnimationDurationFactor:1.0f];
        [TGHacks setSecondaryAnimationDurationFactor:1.0f];
        
        if (enableAnimations)
            [UIView setAnimationsEnabled:true];
        
        _shouldScrollDownOnNextUpdate = false;
        
        if (_menuContainerView.isShowingMenu)
        {
            CGRect contentFrame = CGRectZero;
            
            for (id cell in _tableView.visibleCells)
            {
                if ([cell isKindOfClass:[TGConversationMessageItemView class]])
                {
                    TGConversationMessageItemView *messageView = cell;
                    if (messageView.message.mid == _messageMenuMid || messageView.message.mid == _messageMenuLocalMid)
                    {
                        contentFrame = [messageView contentFrameInView:self.view];
                        
                        if (contentFrame.size.height == 0)
                            break;
                        
                        contentFrame = CGRectIntersection(contentFrame, CGRectMake(0, 0, self.view.frame.size.width, _inputContainer.frame.origin.y));
                        if (contentFrame.size.height == 0)
                            break;

                        contentFrame = [_menuContainerView convertRect:contentFrame fromView:self.view];
                    }
                }
            }
        
            if (contentFrame.size.width < FLT_EPSILON || contentFrame.size.height < FLT_EPSILON || !CGRectEqualToRect(contentFrame, _menuContainerView.showingMenuFromRect))
            {
                [_menuContainerView hideMenu];
                [_dateTooltipContainerView hideTooltip];
            }
        }
    };
    
    [self applyDelayedBlock];
    
    if (!delay)
    {
        block();
    }
    else
    {
        _delayBlock = block;
        _delayTimer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:0.07] interval:0.07 target:self selector:@selector(delayTimerEvent) userInfo:nil repeats:false];
        [[NSRunLoop mainRunLoop] addTimer:_delayTimer forMode:NSRunLoopCommonModes];
    }
#endif
}

- (void)applyDelayedBlock
{
    if (_delayTimer != nil)
    {
        [_delayTimer invalidate];
        _delayTimer = nil;
        
        if (_delayBlock != nil)
        {
            _delayBlock();
            _delayBlock = nil;
        }
    }
}

- (void)delayTimerEvent
{
    _delayTimer = nil;
    
    if (_delayBlock != nil)
    {
        _delayBlock();
        _delayBlock = nil;
    }
}

- (void)changeModelItems:(NSArray *)indices items:(NSArray *)items
{
    int i = -1;
    for (NSNumber *nIndex in indices)
    {
        i++;
        [_listModel replaceObjectAtIndex:[nIndex intValue] withObject:[items objectAtIndex:i]];
    }
}

- (void)conversationHistoryLoadingCompleted
{
    if (_canLoadMoreHistory != _conversationCompanion.canLoadMoreHistory || !_canLoadMoreHistoryProcessedAtLeastOnce)
    {
        _canLoadMoreHistoryProcessedAtLeastOnce = true;
        _canLoadMoreHistory = _conversationCompanion.canLoadMoreHistory;
#if TGUseCollectionView
#else
        @try
        {
            if (_listModel.count < [_tableView numberOfRowsInSection:0])
            {
                [_tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:_listModel.count inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
                [_tableView layoutSubviews];
            }
        }
        @catch (NSException *exception)
        {
            TGLog(@"%@", exception);
            __strong UIView *currentTableView = _tableView;
            _tableView.delegate = nil;
            _tableView.dataSource = nil;
            _tableView = [self createTableView:currentTableView.frame];
            [self.view insertSubview:_tableView aboveSubview:currentTableView];
            [currentTableView removeFromSuperview];
        }
#endif
    }
    
    if (_canLoadMoreHistoryDownwards != _conversationCompanion.canLoadMoreHistoryDownwards)
    {
        _canLoadMoreHistoryDownwards = _conversationCompanion.canLoadMoreHistoryDownwards;
    }
    
    [self updateEmptyState:true];
}

- (void)conversationDownwardsHistoryLoadingCompleted
{
    if (_canLoadMoreHistoryDownwards != _conversationCompanion.canLoadMoreHistoryDownwards)
    {
        _canLoadMoreHistoryDownwards = _conversationCompanion.canLoadMoreHistoryDownwards;
    }
}

- (void)actionStageActionRequested:(NSString *)action options:(NSDictionary *)options
{
    if ([action hasPrefix:@"/tg/conversation/showMessageResendMenu/("])
    {
        int mid = [[action substringWithRange:NSMakeRange(40, action.length - 40 - 1)] intValue];
        
        int undeliveredCount = 0;
        
        for (TGConversationItem *item in _listModel)
        {
            if (item.type == TGConversationItemTypeMessage)
            {
                TGMessage *message = ((TGConversationMessageItem *)item).message;
                if (message.deliveryState == TGMessageDeliveryStateFailed)
                    undeliveredCount++;
            }
        }
        
        for (TGConversationItem *item in _listModel)
        {
            if (item.type == TGConversationItemTypeMessage)
            {
                TGMessage *message = ((TGConversationMessageItem *)item).message;
                if (message.mid == mid)
                {
                    if (message.local)
                    {
                        _currentActionSheet.delegate = nil;
                        
                        _currentActionSheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Conversation.MessageDeliveryFailed", @"") delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
                        _currentActionSheet.actionSheetStyle = UIActionSheetStyleDefault;
                        _currentActionSheet.tag = TGConversationControllerMessageDialogTag;
                        
                        _messageDialogMid = message.mid;
                        _messageDialogHasText = message.text.length != 0;
                        
                        if (_messageDialogHasText)
                            [_currentActionSheet addButtonWithTitle:NSLocalizedString(@"Conversation.MessageDialogEdit", @"")];
                        [_currentActionSheet addButtonWithTitle:NSLocalizedString(@"Conversation.MessageDialogRetry", @"")];
                        if (undeliveredCount > 1)
                            [_currentActionSheet addButtonWithTitle:[[NSString alloc] initWithFormat:TGLocalized(@"Conversation.MessageDialogRetryAll"), undeliveredCount]];
                        int deleteIndex = [_currentActionSheet addButtonWithTitle:NSLocalizedString(@"Conversation.MessageDialogDelete", @"")];
                        int cancelIndex = [_currentActionSheet addButtonWithTitle:NSLocalizedString(@"Common.Cancel", @"")];
                        _currentActionSheet.destructiveButtonIndex = deleteIndex;
                        _currentActionSheet.cancelButtonIndex = cancelIndex;
                        [_currentActionSheet showInView:self.view];
                    }
                    break;
                }
            }
        }
    }
    else if ([action isEqualToString:@"cancelMessageProgress"])
    {
        int mid = [[options objectForKey:@"mid"] intValue];
        
        int index = -1;
        for (TGConversationItem *item in _listModel)
        {
            index++;
            if (item.type == TGConversationItemTypeMessage)
            {
                TGConversationMessageItem *messageItem = (TGConversationMessageItem *)item;
                TGMessage *message = messageItem.message;
                if (message.mid == mid)
                {
                    if (_pMessageUploadProgress != NULL && _pMessageUploadProgress->find(message.mid) != _pMessageUploadProgress->end())
                    {
                        if (_pMessageUploadProgress != NULL)
                            _pMessageUploadProgress->erase(mid);
                        
                        [_conversationCompanion cancelMessageProgress:mid];
                    }
                    else
                    {
                        id mediaId = messageItem.progressMediaId;
                        if (mediaId != nil)
                        {
                            [_mediaDownloadProgress removeObjectForKey:mediaId];
                            
                            for (UITableViewCell *cell in _tableView.visibleCells)
                            {
                                if ([cell isKindOfClass:[TGConversationMessageItemView class]])
                                {
                                    TGConversationMessageItemView *messageView = (TGConversationMessageItemView *)cell;
                                    id messageMediaId = messageView.messageItem.progressMediaId;
                                    if (messageMediaId != nil && [messageMediaId isEqual:mediaId])
                                    {
                                        [messageView setProgress:false progress:0.0f animated:false];
                                    }
                                }
                            }
                            
                            [_conversationCompanion cancelMediaProgress:mediaId];
                        }
                    }
                    
                    break;
                }
            }
        }
    }
    else if ([action isEqualToString:@"downloadMedia"])
    {
        id mediaId = options;
        
        int index = -1;
        for (TGConversationItem *item in _listModel)
        {
            index++;
            if (item.type == TGConversationItemTypeMessage)
            {
                TGConversationMessageItem *messageItem = (TGConversationMessageItem *)item;
                if (messageItem.progressMediaId != nil && [mediaId isEqual:messageItem.progressMediaId])
                {
                    for (TGMediaAttachment *attachment in messageItem.message.mediaAttachments)
                    {
                        if (attachment.type == TGImageMediaAttachmentType || attachment.type == TGVideoMediaAttachmentType)
                        {
                            [_conversationCompanion downloadMedia:messageItem.message changePriority:true];
                            
                            break;
                        }
                    }
                    
                    break;
                }
            }
        }
    }
    else if ([action isEqualToString:@"/tg/conversation/avatarTapped"])
    {
        int uid = [[options objectForKey:@"uid"] intValue];
        [_conversationCompanion conversationMemberSelected:uid];
    }
    else if ([action isEqualToString:@"messageBackgroundTapped"])
    {
        [self touchedTableBackground];
    }
    else if ([action isEqualToString:@"conversation/temporaryTitleChange"])
    {
        NSString *title = [options objectForKey:@"title"];
        if (title.length == 0)
            title = @" ";
        _titleTextLabel.text = title;
        [self updateTitle:true];
    }
    else if ([action isEqualToString:@"conversation/confirmTitleChange"])
    {
        NSString *title = [options objectForKey:@"title"];
        if (title.length == 0)
            title = @" ";
        _titleTextLabel.text = title;
        _chatTitle = title;
        [self updateTitle:true];
        
        [_conversationCompanion changeConversationTitle:title];
    }
    else if ([action isEqualToString:@"/conversation/members/selected"])
    {
        NSNumber *nUid = [options objectForKey:@"userId"];
        [_conversationCompanion conversationMemberSelected:[nUid intValue]];
    }
    else if ([action isEqualToString:@"/conversation/members/add"])
    {
        [_conversationCompanion showConversationProfile:false activateTitleChange:false];
    }
    else if ([action isEqualToString:@"openImage"])
    {
        TGConversationMessageItemView *messageView = [options objectForKey:@"cell"];
        UIView *imageView = [options objectForKey:@"imageView"];
        NSNumber *messageId = [options objectForKey:@"messageId"];
        NSNumber *attachmentTag = [options objectForKey:@"attachmentTag"];
        TGImageInfo *imageInfo = [options objectForKey:@"imageInfo"];
        TGVideoMediaAttachment *videoAttachment = [options objectForKey:@"videoAttachment"];
        UIImage *image = [options objectForKey:@"thumbnail"];
        NSString *thumbnailUrl = [options objectForKey:@"thumbnailUrl"];
        CGRect windowSpaceFrame = [[options objectForKey:@"windowSpaceFrame"] CGRectValue];
        
        id<TGMediaItem> mediaItem = nil;
        
        int mid = [messageId intValue];
        bool found = false;
        bool isAction = false;
        for (TGConversationItem *item in _listModel)
        {
            if (item.type == TGConversationItemTypeMessage)
            {
                TGConversationMessageItem *messageItem = (TGConversationMessageItem *)item;
                if (messageItem.message.mid == mid)
                {
                    found = true;
                    isAction = messageItem.message.actionInfo != nil;
                    if (videoAttachment != nil)
                        mediaItem = [_conversationCompanion createMediaItemFromMessage:messageItem.message author:messageItem.author videoAttachment:videoAttachment];
                    else
                    {
                        if (!isAction || (_conversationCompanion.isMultichat && !_conversationCompanion.isEncrypted))
                        {
                            TGUser *authorUser = messageItem.author == nil ? [TGDatabaseInstance() loadUser:(int)messageItem.message.fromUid] : messageItem.author;
                            mediaItem = [_conversationCompanion createMediaItemFromMessage:messageItem.message author:isAction ? nil : authorUser imageInfo:imageInfo];
                        }
                        else
                        {
                            mediaItem = [_conversationCompanion createMediaItemFromAvatarMessage:messageItem.message];
                        }
                    }
                    break;
                }
            }
        }
        
        if (!found)
            return;
        
        UIImage *cleanImage = [[TGRemoteImageView sharedCache] cachedImage:thumbnailUrl availability:TGCacheDisk];
        if (cleanImage == nil)
            cleanImage = image;
        
        TGImageViewController *imageViewController = [[TGImageViewController alloc] initWithImageItem:mediaItem placeholder:cleanImage];
        imageViewController.autoplay = videoAttachment != nil;
        imageViewController.reverseOrder = true;
        imageViewController.keepAspect = false;
        imageViewController.saveToGallery = [_conversationCompanion shouldAutosavePhotos];
        imageViewController.ignoreSaveToGalleryUid = [_conversationCompanion ignoreSaveToGalleryUid];
        imageViewController.groupIdForDownloadingItems = _conversationCompanion.conversationId;
        
        id<TGImageViewControllerCompanion> companion = nil;
        
        if (!_conversationCompanion.isBroadcast && !isAction)
        {
            companion = [_conversationCompanion createImageViewControllerCompanion:[messageId intValue] reverseOrder:true];
            imageViewController.imageViewCompanion = companion;
            companion.imageViewController = imageViewController;
            companion.reverseOrder = true;
        }
        else
        {
            imageViewController.hideDates = true;
            imageViewController.saveToGallery = false;
            
            if (_conversationCompanion.isMultichat && !_conversationCompanion.isEncrypted)
            {
                companion = [_conversationCompanion createGroupPhotoImageViewControllerCompanion:mediaItem];
                imageViewController.imageViewCompanion = companion;
                imageViewController.currentItemId = [[NSNumber alloc] initWithInt:mid];
                companion.imageViewController = imageViewController;
            }
            else
            {
                companion = [_conversationCompanion createUserPhotoImageViewControllerCompanion:mediaItem];
                imageViewController.imageViewCompanion = companion;
                companion.imageViewController = imageViewController;
            }
        }
        
        _hiddenMediaMid = mid;
        
        [imageViewController animateAppear:self.view anchorForImage:_tableView fromRect:windowSpaceFrame fromImage:image start:^
        {
            imageView.hidden = true;
            [messageView setAlphaToItemsWithAdditionalTag:1 alpha:0.0f];
            [messageView setAlphaToItemsWithAdditionalTag:2 alpha:0.0f];
            [messageView setAlphaToItemsWithAdditionalTag:3 alpha:0.0f];
        }];
        imageViewController.tags = [[NSMutableDictionary alloc] initWithObjectsAndKeys:messageId, @"messageId", attachmentTag, @"attachmentTag", nil];
        imageViewController.watcherHandle = _actionHandle;
        
        [[_conversationCompanion applicationManager] presentContentController:imageViewController];
    }
    else if ([action isEqualToString:@"hideImage"])
    {
        int messageId = [[options objectForKey:@"messageId"] intValue];
        bool requestedHide = [[options objectForKey:@"hide"] boolValue];
        
        if (messageId != 0 && (requestedHide || [options[@"force"] boolValue]))
        {
            int lastHiddenMediaId = _hiddenMediaMid;
            _hiddenMediaMid = messageId;
            
            for (UITableViewCell *cell in [_tableView visibleCells])
            {
                if ([cell isKindOfClass:[TGConversationMessageItemView class]])
                {
                    TGConversationMessageItemView *messageView = (TGConversationMessageItemView *)cell;
                    
                    if (lastHiddenMediaId != 0 && (messageView.message.mid == lastHiddenMediaId || messageView.message.localMid == lastHiddenMediaId))
                    {
                        bool hide = false;
                        
                        [messageView viewForItemWithClass:[TGRemoteImageView class]].hidden = hide;
                        [messageView setAlphaToItemsWithAdditionalTag:1 alpha:hide ? 0.0f : 1.0f];
                        [messageView setAlphaToItemsWithAdditionalTag:2 alpha:hide ? 0.0f : 1.0f];
                        [messageView setAlphaToItemsWithAdditionalTag:3 alpha:hide ? 0.0f : 1.0f];
                    }
                    
                    if (messageView.message.mid == messageId || messageView.message.localMid == messageId)
                    {
                        bool hide = requestedHide;
                        
                        [messageView viewForItemWithClass:[TGRemoteImageView class]].hidden = hide;
                        [messageView setAlphaToItemsWithAdditionalTag:1 alpha:hide ? 0.0f : 1.0f];
                        [messageView setAlphaToItemsWithAdditionalTag:2 alpha:hide ? 0.0f : 1.0f];
                        [messageView setAlphaToItemsWithAdditionalTag:3 alpha:hide ? 0.0f : 1.0f];
                    }
                }
            }
        }
    }
    else if ([action isEqualToString:@"closeImage"])
    {
        TGImageViewController *imageViewController = [options objectForKey:@"sender"];
        
        int messageId = [[imageViewController currentItemId] intValue];
        
        if (messageId == 0)
            messageId = [imageViewController.tags[@"messageId"] intValue];
        
        CGRect targetRect = CGRectZero;
        
        UIView *showView = nil;
        TGConversationMessageItemView *currentMessageView = nil;
        
        UIImage *currentImage = nil;
        
        if (messageId != 0)
        {
            for (UITableViewCell *cell in [_tableView visibleCells])
            {
                if ([cell isKindOfClass:[TGConversationMessageItemView class]])
                {
                    TGConversationMessageItemView *messageView = (TGConversationMessageItemView *)cell;
                    
                    if (_hiddenMediaMid == 0 || _hiddenMediaMid == messageId)
                    {
                        if (messageView.message.mid == messageId || messageView.message.localMid == messageId)
                        {
                            CGRect rect = [messageView rectForItemWithClass:[TGRemoteImageView class]];
                            if (!CGRectIsNull(rect))
                            {
                                currentMessageView = messageView;
                                
                                targetRect = [self.view.window convertRect:rect fromView:messageView];
                                showView = [messageView viewForItemWithClass:[TGRemoteImageView class]];
                                showView.hidden = true;
                                
                                [currentMessageView setAlphaToItemsWithAdditionalTag:1 alpha:0.0f];
                                [currentMessageView setAlphaToItemsWithAdditionalTag:2 alpha:0.0f];
                                [currentMessageView setAlphaToItemsWithAdditionalTag:3 alpha:0.0f];
                                
                                currentImage = ((TGRemoteImageView *)showView).currentImage;
                            }
                            
                            break;
                        }
                    }
                    else
                    {
                        if (messageView.message.mid == _hiddenMediaMid || messageView.message.localMid == _hiddenMediaMid)
                        {
                            bool hide = false;
                            
                            [messageView viewForItemWithClass:[TGRemoteImageView class]].hidden = hide;
                            [messageView setAlphaToItemsWithAdditionalTag:1 alpha:hide ? 0.0f : 1.0f];
                            [messageView setAlphaToItemsWithAdditionalTag:2 alpha:hide ? 0.0f : 1.0f];
                            [messageView setAlphaToItemsWithAdditionalTag:3 alpha:hide ? 0.0f : 1.0f];
                            
                            break;
                        }
                    }
                }
            }
        }
        
        _hiddenMediaMid = 0;
        
        if (currentImage == nil)
            targetRect = CGRectZero;

        id<TGAppManager> appManager = [_conversationCompanion applicationManager];
        
        [imageViewController animateDisappear:self.view anchorForImage:_tableView toRect:targetRect toImage:currentImage swipeVelocity:0.0f completion:^
        {
            [appManager dismissContentController];
            showView.hidden = false;
            
            [UIView animateWithDuration:0.25 animations:^
            {
                [currentMessageView setAlphaToItemsWithAdditionalTag:1 alpha:1.0f];
                [currentMessageView setAlphaToItemsWithAdditionalTag:2 alpha:1.0f];
                [currentMessageView setAlphaToItemsWithAdditionalTag:3 alpha:1.0f];
            }];
        }];
        
        [((TGNavigationController *)self.navigationController) updateControllerLayout:false];
    }
    else if ([action isEqualToString:@"openVideo"])
    {
        UIView *imageView = [options objectForKey:@"imageView"];
        UIView *playButton = [options objectForKey:@"playButton"];
        NSNumber *messageId = [options objectForKey:@"messageId"];
        NSNumber *attachmentTag = [options objectForKey:@"attachmentTag"];
        TGVideoMediaAttachment *videoAttachment = [options objectForKey:@"videoAttachment"];
        UIImage *image = [options objectForKey:@"thumbnail"];
        NSString *thumbnailUrl = [options objectForKey:@"thumbnailUrl"];
        CGRect windowSpaceFrame = [[options objectForKey:@"windowSpaceFrame"] CGRectValue];
        
        id<TGMediaItem> mediaItem = nil;
        
        int mid = [messageId intValue];
        bool found = false;
        bool isAction = false;
        for (TGConversationItem *item in _listModel)
        {
            if (item.type == TGConversationItemTypeMessage)
            {
                TGConversationMessageItem *messageItem = (TGConversationMessageItem *)item;
                if (messageItem.message.mid == mid)
                {
                    found = true;
                    isAction = messageItem.message.actionInfo != nil;
                    mediaItem = [_conversationCompanion createMediaItemFromMessage:messageItem.message author:messageItem.author == nil ? [TGDatabaseInstance() loadUser:(int)messageItem.message.fromUid] : messageItem.author videoAttachment:videoAttachment];
                    break;
                }
            }
        }
        
        if (!found)
            return;
        
        UIImage *cleanImage = [[TGRemoteImageView sharedCache] cachedImage:thumbnailUrl availability:TGCacheDisk];
        if (cleanImage == nil)
            cleanImage = image;
        
        TGImageViewController *imageViewController = [[TGImageViewController alloc] initWithImageItem:mediaItem placeholder:cleanImage];
        imageViewController.autoplay = true;
        imageViewController.reverseOrder = true;
        imageViewController.keepAspect = false;
        imageViewController.saveToGallery = [_conversationCompanion shouldAutosavePhotos];
        imageViewController.ignoreSaveToGalleryUid = [_conversationCompanion ignoreSaveToGalleryUid];
        imageViewController.groupIdForDownloadingItems = _conversationCompanion.conversationId;
        
        id<TGImageViewControllerCompanion> companion = nil;
        
        if (!_conversationCompanion.isBroadcast && !isAction)
        {
            companion = [_conversationCompanion createImageViewControllerCompanion:[messageId intValue] reverseOrder:true];
            imageViewController.imageViewCompanion = companion;
            companion.imageViewController = imageViewController;
            companion.reverseOrder = true;
        }
        else
        {
            imageViewController.currentItemId = [[NSNumber alloc] initWithInt:mid];
            imageViewController.disableActions = true;
        }
        
        [imageViewController animateAppear:self.view anchorForImage:_tableView fromRect:windowSpaceFrame fromImage:image start:^
        {
            imageView.hidden = true;
            playButton.hidden = true;
        }];
        imageViewController.tags = [[NSMutableDictionary alloc] initWithObjectsAndKeys:messageId, @"messageId", attachmentTag, @"attachmentTag", nil];
        imageViewController.watcherHandle = _actionHandle;
        
        [[_conversationCompanion applicationManager] presentContentController:imageViewController];
    }
    else if ([action isEqualToString:@"closeVideo"])
    {
        id<TGAppManager> appManager = [_conversationCompanion applicationManager];
        
        [appManager dismissContentController];
    }
    else if ([action isEqualToString:@"openMap"])
    {
        NSNumber *nLatitude = options[@"locationInfo"][@"latitude"];
        NSNumber *nLongitude = options[@"locationInfo"][@"longitude"];
        TGMessage *message = options[@"message"];
        if (nLatitude != nil && nLongitude != nil)
        {
            TGMapViewController *mapViewController = [[TGMapViewController alloc] initInMapModeWithLatitude:[nLatitude doubleValue] longitude:[nLongitude doubleValue] user:[TGDatabaseInstance() loadUser:[[options[@"locationInfo"] objectForKey:@"authorUid"] intValue]]];
            mapViewController.message = message;
            mapViewController.watcher = _actionHandle;
            
            [self.navigationController pushViewController:mapViewController animated:true];
        }
    }
    else if ([action isEqualToString:@"mapViewForward"])
    {
        TGMessage *message = options[@"message"];
        if (message != nil)
            [_conversationCompanion forwardMessages:@[@(message.mid)]];
    }
    else if ([action isEqualToString:@"mapViewFinished"])
    {
        [self dismissViewControllerAnimated:true completion:nil];
        
        NSNumber *nLatitude = [options objectForKey:@"latitude"];
        NSNumber *nLongitude = [options objectForKey:@"longitude"];
        if (nLatitude != nil && nLongitude != nil)
        {
            TGLocationInputMediaAttachment *locationAttachment = [[TGLocationInputMediaAttachment alloc] init];
            locationAttachment.latitude = [nLatitude doubleValue];
            locationAttachment.longitude = [nLongitude doubleValue];
            
            [_conversationCompanion sendMessage:nil attachments:[NSArray arrayWithObject:locationAttachment] clearText:false];
        }
    }
    else if ([action isEqualToString:@"searchImagesCompleted"])
    {
        [self dismissViewControllerAnimated:true completion:nil];
    }
    else if ([action isEqualToString:@"openContact"])
    {
        TGContactMediaAttachment *contactAttachment = [options objectForKey:@"contactAttachment"];
        if (contactAttachment != nil)
            [_conversationCompanion openContact:contactAttachment];
    }
    else if ([action isEqualToString:@"toggleMessageChecked"])
    {
        int mid = [[options objectForKey:@"mid"] intValue];
        int localMid = [[options objectForKey:@"localMid"] intValue];
       
        bool isChecked = false;
        
        if (_checkedMessages.find(mid) != _checkedMessages.end())
        {
            _checkedMessages.erase(mid);
            isChecked = false;
        }
        else if (_checkedMessages.find(localMid) != _checkedMessages.end())
        {
            _checkedMessages.erase(localMid);
            isChecked = false;
        }
        else
        {
            _checkedMessages.insert(mid);
            isChecked = true;
        }
        
        for (UITableViewCell *cell in _tableView.visibleCells)
        {
            if ([cell isKindOfClass:[TGConversationMessageItemView class]])
            {
                TGConversationMessageItemView *messageView = (TGConversationMessageItemView *)cell;
                if (messageView.message.mid == mid || (messageView.message.localMid != 0 && messageView.message.localMid == mid))
                {
                    [messageView setIsSelected:isChecked];
                }
            }
        }
        
        [self updateEditingControls];
    }
    else if ([action isEqualToString:@"openLink"])
    {
        NSString *url = [options objectForKey:@"url"];
        if (url != nil)
        {
            if ([url hasPrefix:@"tel:"])
                url = [[NSString alloc] initWithFormat:@"tel:%@", [TGStringUtils formatPhoneUrl:[url substringFromIndex:4]]];
            
            if ([url hasPrefix:@"user:"])
            {
                TGContactMediaAttachment *contactAttachment = [[TGContactMediaAttachment alloc] init];
                contactAttachment.uid = [[url substringFromIndex:7] intValue];
                [_conversationCompanion openContact:contactAttachment];
            }
            else
                [[UIApplication sharedApplication] openURL:[[NSURL alloc] initWithString:url]];
        }
    }
    else if ([action isEqualToString:@"showLinkOptions"])
    {
        NSString *url = [options objectForKey:@"url"];
        if (url == nil)
            return;
        
        if ([url hasPrefix:@"user:"])
        {
            //[self actionStageActionRequested:@"openLink" options:options];
            return;
        }
        
        NSString *displayUrl = url;
        if ([url hasPrefix:@"mailto:"])
            displayUrl = [url substringFromIndex:7];
        else if ([url hasPrefix:@"tel:"])
            displayUrl = [url substringFromIndex:4];
        
        if (displayUrl.length > 120)
            displayUrl = [[url substringToIndex:120] stringByAppendingString:@"..."];
        
        _currentActionSheet.delegate = nil;
        
        _currentActionSheet = [[UIActionSheet alloc] initWithTitle:displayUrl delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
        _currentActionSheet.actionSheetStyle = UIBarStyleDefault;
        _currentActionSheet.tag = TGConversationControllerLinkOptionsDialogTag;
        
        _messageDialogLink = url;
        
        if ([url hasPrefix:@"tel:"])
            [_currentActionSheet addButtonWithTitle:@"Call"];
        else
            [_currentActionSheet addButtonWithTitle:NSLocalizedString(@"Conversation.LinkDialogOpen", @"")];
        
        [_currentActionSheet addButtonWithTitle:NSLocalizedString(@"Conversation.LinkDialogCopy", @"")];
        int cancelIndex = [_currentActionSheet addButtonWithTitle:NSLocalizedString(@"Common.Cancel", @"")];
        _currentActionSheet.cancelButtonIndex = cancelIndex;
        [_currentActionSheet showInView:self.view];
    }
    else if ([action isEqualToString:@"showMessageContextMenu"])
    {
        if (CFAbsoluteTimeGetCurrent() < _lastMenuHideTime + 0.4)
            return;
        
        _lastMenuShowTime = CFAbsoluteTimeGetCurrent();
        
        int mid = [[options objectForKey:@"mid"] intValue];
        int localMid = [[options objectForKey:@"localMid"] intValue];
        if (mid == 0 && localMid == 0)
            return;
        
        for (UITableViewCell *cell in _tableView.visibleCells)
        {
            if ([cell isKindOfClass:[TGConversationMessageItemView class]])
            {
                TGConversationMessageItemView *messageView = (TGConversationMessageItemView *)cell;
                if (messageView.message.mid == mid)
                {
                    CGRect contentFrame = [messageView contentFrameInView:self.view];
                    if (contentFrame.size.height == 0)
                        break;
                    
                    contentFrame = CGRectIntersection(contentFrame, CGRectMake(0, 0, self.view.frame.size.width, _inputContainer.frame.origin.y));
                    if (contentFrame.size.height == 0)
                        break;
                    
                    _messageMenuMid = mid;
                    _messageMenuLocalMid = localMid;
                    _messageMenuIsAction = messageView.message.actionInfo != nil;
                    _messageMenuHasText = messageView.message.text != nil && messageView.message.text.length != 0;
                    [messageView setIsContextSelected:true animated:false];
                    
                    //_inputField.internalTextView.handleEditActions = false;
                    
                    if (_menuContainerView == nil)
                        _menuContainerView = [[TGMenuContainerView alloc] init];
                    
                    if (_menuContainerView.superview != self.view)
                        [self.view addSubview:_menuContainerView];
                    
                    _menuContainerView.frame = CGRectMake(0, self.controllerInset.top, self.view.frame.size.width, _tableView.frame.origin.y + _tableView.frame.size.height - self.controllerInset.top);
                    
                    NSMutableArray *actions = [[NSMutableArray alloc] init];
                    if (_messageMenuHasText)
                        [actions addObject:[[NSDictionary alloc] initWithObjectsAndKeys:@"Copy", @"title", @"copy", @"action", nil]];
                    else if (!_messageMenuIsAction && !_conversationCompanion.isEncrypted)
                        [actions addObject:[[NSDictionary alloc] initWithObjectsAndKeys:@"Forward", @"title", @"forward", @"action", nil]];
                    
                    [actions addObject:[[NSDictionary alloc] initWithObjectsAndKeys:@"Delete", @"title", @"delete", @"action", nil]];
                    if (!_messageMenuIsAction)
                        [actions addObject:[[NSDictionary alloc] initWithObjectsAndKeys:@"Select", @"title", @"select", @"action", nil]];
                    [_menuContainerView.menuView setButtonsAndActions:actions watcherHandle:_actionHandle];
                    [_menuContainerView.menuView sizeToFit];
                    [_menuContainerView showMenuFromRect:[_menuContainerView convertRect:contentFrame fromView:self.view]];
                    
                    /*UIMenuController *menuController = [UIMenuController sharedMenuController];
                    if (!_messageMenuIsAction)
                        [menuController setMenuItems: [[UIMenuItem alloc] initWithTitle:@"Select" action:@selector(beginSelection:)], nil]];
                    
                    if ([menuController isMenuVisible])
                        [menuController setMenuVisible:false animated:false];
                    
                    dispatch_async(dispatch_get_main_queue(), ^
                    {
                        if (iosMajorVersion() < 5)
                            [self becomeFirstResponder];
                        [menuController setTargetRect:contentFrame inView:self.view];
                        [menuController setMenuVisible:true animated:true];
                    });*/
                }
                else
                    [messageView setIsContextSelected:false animated:false];
            }
        }
    }
    else if ([action isEqualToString:@"showMessageDateTooltip"])
    {
        [self clearItemsSelection:false];
        [_dateTooltipContainerView hideTooltip];
        
        if (CFAbsoluteTimeGetCurrent() < _lastMenuHideTime + 0.4)
            return;
        
        _lastMenuShowTime = CFAbsoluteTimeGetCurrent();
        
        int mid = [[options objectForKey:@"mid"] intValue];
        
        CGRect dateFrame = [[options objectForKey:@"frame"] CGRectValue];
        UIView *cellView = [options objectForKey:@"cell"];
        
        dateFrame = [cellView convertRect:dateFrame toView:self.view];
        
        int index = -1;
        for (TGConversationItem *item in _listModel)
        {
            index++;
            if (item.type == TGConversationItemTypeMessage)
            {
                TGConversationMessageItem *messageItem = (TGConversationMessageItem *)item;
                TGMessage *message = messageItem.message;
                if (message.mid == mid)
                {
                    if (_dateTooltipContainerView == nil)
                    {
                        _dateTooltipContainerView = [[TGTooltipContainerView alloc] init];
                        _dateTooltipContainerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                        _dateTooltipContainerView.tooltipView = [[TGMessageDateTooltipView alloc] init];
                        _dateTooltipContainerView.tooltipView.watcherHandle = _actionHandle;
                        [_dateTooltipContainerView addSubview:_dateTooltipContainerView.tooltipView];
                    }
                    
                    if (_dateTooltipContainerView.superview != self.view)
                        [self.view addSubview:_dateTooltipContainerView];
                    
                    [(TGMessageDateTooltipView *)_dateTooltipContainerView.tooltipView setDate:(int)message.date];
                    
                    _dateTooltipContainerView.frame = CGRectMake(0, 0, self.view.frame.size.width, _tableView.frame.origin.y + _tableView.frame.size.height);
                    [_dateTooltipContainerView showTooltipFromRect:dateFrame];
                    
                    break;
                }
            }
        }
    }
    else if ([action isEqualToString:@"menuWillHide"])
    {
        _lastMenuHideTime = CFAbsoluteTimeGetCurrent();
        
        _messageMenuMid = 0;
        _messageMenuLocalMid = 0;
        
        [self clearItemsSelection:true];
    }
    else if ([action isEqualToString:@"menuAction"])
    {
        NSString *menuAction = (NSString *)options;
        if ([menuAction isEqualToString:@"copy"])
            [self copy:nil];
        else if ([menuAction isEqualToString:@"delete"])
            [self delete:nil];
        else if ([menuAction isEqualToString:@"select"])
            [self beginSelection:nil];
        else if ([menuAction isEqualToString:@"forward"])
            [self forward:nil];
    }
    else if ([action isEqualToString:@"conversationAction"])
    {
        NSString *conversationAction = [options objectForKey:@"action"];
        if ([conversationAction isEqualToString:@"call"])
        {
            if (!_conversationCompanion.isMultichat || _conversationCompanion.isEncrypted)
            {
                if (_conversationCompanion.singleParticipant != nil)
                {
                    TGUser *user = _conversationCompanion.singleParticipant;
                    
                    NSMutableArray *phoneNumbers = [[NSMutableArray alloc] init];
                    
                    if (user.phoneNumber != nil && user.phoneNumber.length != 0)
                    {
                        [phoneNumbers addObject:[NSArray arrayWithObjects:@"mobile", user.phoneNumber, [TGStringUtils formatPhone:user.phoneNumber forceInternational:true], nil]];
                    }
                    
                    if (phoneNumbers.count == 1)
                    {
                        NSString *telephoneScheme = @"tel:";
                        if (![[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"tel://"]])
                            telephoneScheme = @"facetime:";
                        
                        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@%@", telephoneScheme, [TGStringUtils formatPhoneUrl:[[phoneNumbers objectAtIndex:0] objectAtIndex:1]]]]];
                    }
                    else if (phoneNumbers.count > 1)
                    {
                        _currentActionSheet.delegate = nil;
                        
                        _currentActionSheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
                        _currentActionSheet.tag = TGConversationControllerPhoneNumberDialogTag;
                        
                        _actionSheetPhoneList = phoneNumbers;
                        
                        for (NSArray *desc in phoneNumbers)
                        {
                            [_currentActionSheet addButtonWithTitle:[NSString stringWithFormat:@"%@: %@", [desc objectAtIndex:0], [desc objectAtIndex:2]]];
                        }
                        
                        _currentActionSheet.cancelButtonIndex = [_currentActionSheet addButtonWithTitle:NSLocalizedString(@"Common.Cancel", nil)];
                        [_currentActionSheet showInView:self.view];
                    }
                }
            }
        }
        else if ([conversationAction isEqualToString:@"edit"])
        {
            NSTimeInterval currentTime = CFAbsoluteTimeGetCurrent();
            if (currentTime - _lastSwipeActionTime < 0.4)
                return;
            _lastSwipeActionTime = currentTime;
            
            [self setEditingMode:true];
        }
        else if ([conversationAction isEqualToString:@"info"])
        {
            [_conversationCompanion userAvatarPressed];
        }
        else if ([conversationAction isEqualToString:@"block"])
        {
            [self blockButtonPressed];
        }
        else if ([conversationAction isEqualToString:@"unblock"])
        {
            [self unblockButtonPressed];
        }
        else if ([conversationAction isEqualToString:@"mute"])
        {
            [self muteButtonPressed];
        }
        else if ([conversationAction isEqualToString:@"unmute"])
        {
            [self unmuteButtonPressed];
        }
    }
    else if ([action isEqualToString:@"temporaryChangeTitle"])
    {
        NSString *title = [options objectForKey:@"text"];
        
        _titleTextLabel.text = title.length == 0 ? @" " : title;
        [self updateTitle:false];
    }
    else if ([action isEqualToString:@"revertTemporaryTitle"])
    {
        _titleTextLabel.text = _chatTitle;
        [self updateTitle:false];
    }
    else if ([action isEqualToString:@"hideOverayDate"])
    {
        if ([(NSNumber *)options intValue] == _overlayDateToken)
        {
            [UIView animateWithDuration:0.4 animations:^
            {
                _overlayDateContainer.alpha = 0.0f;
            }];
        }
    }
    else if ([action isEqualToString:@"acceptEncryption"])
    {
        [_conversationCompanion acceptEncryptionRequest];
    }
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    _currentActionSheet.delegate = nil;
    _currentActionSheet = nil;
    
    if (actionSheet.tag == TGConversationControllerMessageDialogTag)
    {
        if (buttonIndex == actionSheet.destructiveButtonIndex)
        {   
            [_conversationCompanion deleteMessages:[[NSArray alloc] initWithObjects:[NSNumber numberWithInt:_messageDialogMid], nil]];
        }
        else if (buttonIndex != actionSheet.cancelButtonIndex)
        {
            if (_messageDialogHasText)
            {
                if (buttonIndex == 0)
                {
                    for (TGConversationItem *item in _listModel)
                    {
                        if (item.type == TGConversationItemTypeMessage)
                        {
                            TGMessage *message = ((TGConversationMessageItem *)item).message;
                            if (message.mid == _messageDialogMid || (message.localMid != 0 && message.localMid == _messageDialogMid))
                            {
                                if (message.text != nil)
                                    [_inputField setText:message.text];
                                [_conversationCompanion deleteMessages:[NSArray arrayWithObject:[NSNumber numberWithInt:message.mid]]];
                            }
                        }
                    }
                }
                else if (buttonIndex == 1)
                {
                    [_conversationCompanion retryMessage:_messageDialogMid];
                }
                else if (buttonIndex == 2)
                {
                    [_conversationCompanion retryAllMessages];
                }
            }
            else
            {
                if (buttonIndex == 0)
                    [_conversationCompanion retryMessage:_messageDialogMid];
                else
                    [_conversationCompanion retryAllMessages];
            }
        }
        
        _messageDialogMid = INT_MAX;
    }
    else if (actionSheet.tag == TGConversationControllerLinkOptionsDialogTag)
    {
        if (buttonIndex == 0)
        {
            if (_messageDialogLink != nil)
            {
                NSString *url = _messageDialogLink;
                
                if ([url hasPrefix:@"tel:"])
                    url = [[NSString alloc] initWithFormat:@"tel:%@", [TGStringUtils formatPhoneUrl:[url substringFromIndex:4]]];
                
                [[UIApplication sharedApplication] openURL:[[NSURL alloc] initWithString:url]];
            }
        }
        else if (buttonIndex == 1)
        {
            UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
            if (pasteboard != nil && _messageDialogLink != nil)
            {
                NSString *copyString = _messageDialogLink;
                if ([_messageDialogLink hasPrefix:@"mailto:"])
                    copyString = [_messageDialogLink substringFromIndex:7];
                else if ([_messageDialogLink hasPrefix:@"tel:"])
                    copyString = [_messageDialogLink substringFromIndex:4];
                [pasteboard setString:copyString];
            }
        }
        
        _messageDialogLink = nil;
    }
    else if (actionSheet.tag == TGConversationControllerAttachmentDialogTag)
    {
        NSString *action = [_currentActionSheetMapping objectForKey:[[NSNumber alloc] initWithInt:buttonIndex]];
        
        if ([action isEqualToString:@"takePhotoOrVideo"])
        {
            [self attachCameraPressed];
        }
        else if ([action isEqualToString:@"choosePhoto"])
        {
            [self attachGalleryPressed];
        }
        else if ([action isEqualToString:@"searchWeb"])
        {
            [self attachSearchWebPressed];
        }
        else if ([action isEqualToString:@"chooseVideo"])
        {
            [self attachVideoGalleryPressed];
        }
        else if ([action isEqualToString:@"location"])
        {
            [self attachLocationPressed];
        }
        
        _assetsLibraryHolder = nil;
    }
    else if (actionSheet.tag == TGConversationControllerClearConvfirmationDialogTag)
    {
        if (buttonIndex == actionSheet.destructiveButtonIndex)
        {
            [_conversationCompanion clearAllMessages];
            
            /*dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.27 * NSEC_PER_SEC));
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void)
            {
                [self setEditingMode:false];
            });*/
        }
    }
    else if (actionSheet.tag == TGConversationControllerPhoneNumberDialogTag)
    {
        if (buttonIndex != actionSheet.cancelButtonIndex)
        {
            NSArray *phoneDesc = buttonIndex >= 0 && buttonIndex < _actionSheetPhoneList.count ? [_actionSheetPhoneList objectAtIndex:buttonIndex] : nil;
            if (phoneDesc != nil)
            {
                NSString *telephoneScheme = @"tel:";
                if (![[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"tel://"]])
                    telephoneScheme = @"facetime:";
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@%@", telephoneScheme, [TGStringUtils formatPhoneUrl:[phoneDesc objectAtIndex:1]]]]];
            }
        }
    }
}

- (void)copy:(id)__unused sender
{
    if (_messageMenuMid == 0 && _messageMenuLocalMid == 0)
        return;
    
    for (TGConversationItem *item in _listModel)
    {
        if (item.type == TGConversationItemTypeMessage)
        {
            TGConversationMessageItem *messageItem = (TGConversationMessageItem *)item;
            if (messageItem.message.mid == _messageMenuMid || (_messageMenuLocalMid != 0 && messageItem.message.localMid == _messageMenuLocalMid))
            {
                UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
                if (pasteboard != nil && messageItem.message.text != nil)
                    [pasteboard setString:messageItem.message.text];
                
                _messageMenuMid = 0;
                _messageMenuLocalMid = 0;
                
                break;
            }
        }
    }
}

- (void)delete:(id)__unused sender
{
    if (_messageMenuMid == 0 && _messageMenuLocalMid == 0)
        return;
    
    for (TGConversationItem *item in _listModel)
    {
        if (item.type == TGConversationItemTypeMessage)
        {
            TGConversationMessageItem *messageItem = (TGConversationMessageItem *)item;
            if (messageItem.message.mid == _messageMenuMid || (_messageMenuLocalMid != 0 && messageItem.message.localMid == _messageMenuLocalMid))
            {
                [_conversationCompanion deleteMessages:[NSArray arrayWithObject:[NSNumber numberWithInt:_messageMenuMid]]];
                
                _messageMenuMid = 0;
                _messageMenuLocalMid = 0;
                
                break;
            }
        }
    }
}

- (void)forward:(id)__unused sender
{
    if (_messageMenuMid == 0 && _messageMenuLocalMid == 0)
        return;
    
    int messageMenuMid = _messageMenuMid;
    int messageMenuLocalMid = _messageMenuLocalMid;
    
    _messageMenuMid = 0;
    _messageMenuLocalMid = 0;
    
    [self.view endEditing:true];
    _wantsKeyboardActive = false;
    
    for (TGConversationItem *item in _listModel)
    {
        if (item.type == TGConversationItemTypeMessage)
        {
            TGConversationMessageItem *messageItem = (TGConversationMessageItem *)item;
            if (messageItem.message.mid == messageMenuMid || (messageMenuLocalMid != 0 && messageItem.message.localMid == messageMenuLocalMid))
            {
                [_conversationCompanion forwardMessages:[NSArray arrayWithObject:[NSNumber numberWithInt:messageMenuMid]]];
                
                break;
            }
        }
    }
}

- (void)beginSelection:(id)__unused sender
{
    if (_messageMenuMid == 0 && _messageMenuLocalMid == 0)
        return;
    
    for (TGConversationItem *item in _listModel)
    {
        if (item.type == TGConversationItemTypeMessage)
        {
            TGConversationMessageItem *messageItem = (TGConversationMessageItem *)item;
            if (messageItem.message.mid == _messageMenuMid || (_messageMenuLocalMid != 0 && messageItem.message.localMid == _messageMenuLocalMid))
            {
                for (UITableViewCell *cell in _tableView.visibleCells)
                {
                    if ([cell isKindOfClass:[TGConversationMessageItemView class]])
                    {
                        TGConversationMessageItemView *messageView = (TGConversationMessageItemView *)cell;
                        if (messageView.message.mid == _messageMenuMid || (_messageMenuLocalMid != 0 && messageView.message.localMid == _messageMenuLocalMid))
                        {
                            [messageView setIsSelected:true];
                            break;
                        }
                    }
                }
                
                [self actionStageActionRequested:@"toggleMessageChecked" options:[[NSDictionary alloc] initWithObjectsAndKeys:[[NSNumber alloc] initWithInt:_messageMenuMid], @"mid", [[NSNumber alloc] initWithInt:_messageMenuLocalMid], @"localMid", nil]];
                [self setEditingMode:true animated:true];
                
                _messageMenuMid = 0;
                _messageMenuLocalMid = 0;
                
                break;
            }
        }
    }
}

- (void)editingDeleteButtonPressed
{
    [TGViewController disableUserInteractionFor:0.27];
    
    NSMutableArray *messagesToDelete = [[NSMutableArray alloc] init];
    for (std::set<int>::iterator it = _checkedMessages.begin(); it != _checkedMessages.end(); it++)
    {
        [messagesToDelete addObject:[[NSNumber alloc] initWithInt:*it]];
    }
    
    [_conversationCompanion deleteMessages:messagesToDelete];
    
    [_tableView setContentOffset:_tableView.contentOffset animated:true];
    
    //dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.27 * NSEC_PER_SEC));
    //dispatch_after(popTime, dispatch_get_main_queue(), ^(void)
    //{
        [self setEditingMode:false];
    //});
}

- (void)editingForwardButtonPressed
{
    if (_conversationCompanion.isEncrypted)
    {
        [[[UIAlertView alloc] initWithTitle:nil message:TGLocalized(@"Conversation.EncryptedForwardingAlert") delegate:nil cancelButtonTitle:TGLocalized(@"Common.OK") otherButtonTitles:nil] show];
    }
    else
    {
        NSMutableArray *messagesToForward = [[NSMutableArray alloc] init];
        
        for (std::set<int>::iterator it = _checkedMessages.begin(); it != _checkedMessages.end(); it++)
        {
            [messagesToForward addObject:[[NSNumber alloc] initWithInt:*it]];
        }
        
        _clearEditingOnDisappear = true;
        
        [_conversationCompanion forwardMessages:messagesToForward];
    }
}

- (void)sendRequestButtonPressed
{
    if (!(_conversationLink & TGUserLinkMyRequested))
    {
        [self linkActionInProgress:0 inProgress:true];
        
        [_conversationCompanion sendContactRequest];
    }
}

- (void)acceptRequestButtonPressed
{
    if (!(_conversationLink & TGUserLinkMyRequested))
    {
        [self linkActionInProgress:1 inProgress:true];
        
        [_conversationCompanion acceptContactRequest];
    }
}

- (void)ignoreRequestButtonPressed
{
    [_conversationCompanion ignoreContactRequest];
    
    [self performCloseConversation];
}

- (void)blockButtonPressed
{
    [self setUserBlocked:true];
    
    [_conversationCompanion blockUser];
}

- (void)unblockButtonPressed
{
    if (_conversationCompanion.isMultichat && !_conversationCompanion.isEncrypted)
    {
        [_conversationCompanion leaveGroup];
    }
    else
    {
        if (_conversationCompanion.isEncrypted && _encryptionStatus == 3)
        {
            [_conversationCompanion leaveGroup];
        }
        else
        {
            [self setUserBlocked:false];
            [_conversationCompanion unblockUser];
        }
    }
}

- (void)muteButtonPressed
{
    [self setConversationMuted:true];
    
    [_conversationCompanion muteConversation:true];
}

- (void)unmuteButtonPressed
{
    [self setConversationMuted:false];
    
    [_conversationCompanion muteConversation:false];
}

- (void)linkActionInProgress:(int)__unused action inProgress:(bool)inProgress
{
    //if (action == 0)
    {
        _editingRequestButton.enabled = !inProgress;
    }
    //else if (action == 1)
    {
        _editingAcceptButton.enabled = !inProgress;
        _editingBlockButton.enabled = !inProgress;
    }
}

- (void)unreadCountChanged:(int)unreadCount
{
    if (unreadCount != _unreadCount)
    {
        _unreadCount = unreadCount;
        
        [self updateUnreadCount];
    }
}

- (void)doneButtonPressed
{
    NSTimeInterval currentTime = CFAbsoluteTimeGetCurrent();
    if (currentTime - _lastSwipeActionTime < 0.4)
        return;
    _lastSwipeActionTime = currentTime;
    
    [self setEditingMode:false];
}

- (void)clearAllButtonPressed
{
    _currentActionSheet.delegate = nil;
    
    _currentActionSheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:NSLocalizedString(@"Common.Cancel", nil) destructiveButtonTitle:TGLocalized(@"Conversation.ClearAllConfirmation") otherButtonTitles: nil];
    _currentActionSheet.tag = TGConversationControllerClearConvfirmationDialogTag;
    [_currentActionSheet showInView:self.view];
}

- (void)incomingMessagesButtonPressed
{
    if (_canLoadMoreHistoryDownwards)
        [_conversationCompanion reloadHistoryShortcut];
    else
        [_tableView setContentOffset:CGPointMake(0, -_tableView.contentInset.top) animated:true];
}

- (void)showProgressWindow:(bool)show
{
    if (show)
    {
        if (_progressWindow == nil)
        {
            _progressWindow = [[TGProgressWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
            [_progressWindow show:true];
        }
    }
    else if (_progressWindow != nil)
    {
        [_progressWindow dismiss:true];
        _progressWindow = nil;
    }
}

@end
