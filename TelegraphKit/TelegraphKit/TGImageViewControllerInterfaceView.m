#import "TGImageViewControllerInterfaceView.h"

#import "TGHacks.h"
#import "TGDateUtils.h"
#import "TGImageUtils.h"

#import "TGImagePagingScrollView.h"
#import "TGImageViewPage.h"

#import "TGClockProgressView.h"

#import "TGObserverProxy.h"

@interface TGImageViewControllerInterfaceView ()

@property (nonatomic, strong) UIButton *playButton;
@property (nonatomic, strong) UIButton *pauseButton;

@property (nonatomic, strong) UIView *controlsContainer;
@property (nonatomic, strong) UIView *progressContainer;

@property (nonatomic, strong) TGClockProgressView *clockProgressView;
@property (nonatomic, strong) UILabel *progressLabel;

@property (nonatomic, strong) TGObserverProxy *statusBarWillChangeFrameProxy;

@end

@implementation TGImageViewControllerInterfaceView

- (id)initWithFrame:(CGRect)frame
{
    return [self initWithFrame:frame enableEditing:false disableActions:false];
}

- (id)initWithFrame:(CGRect)frame enableEditing:(bool)enableEditing disableActions:(bool)disableActions
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:true];
        
        _currentIndex = -1;
        
        UIImage *topPanelImage = [UIImage imageNamed:@"GalleryTopPanel.png"];
        _topPanelView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 20, frame.size.width, topPanelImage.size.height)];
        _topPanelView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _topPanelView.image = topPanelImage;
        _topPanelView.userInteractionEnabled = true;
        [self addSubview:_topPanelView];
        
        UIImage *topCornersImage = [UIImage imageNamed:@"NavigationBar_Corners.png"];
        UIView *cornersImageView = [[UIImageView alloc] initWithImage:[topCornersImage stretchableImageWithLeftCapWidth:(int)(topCornersImage.size.width / 2) topCapHeight:0]];
        cornersImageView.frame = CGRectMake(0, -20, _topPanelView.frame.size.width, topCornersImage.size.height);
        cornersImageView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [_topPanelView addSubview:cornersImageView];
        
        _enableEditing = enableEditing;
        
        _doneButton = [[TGToolbarButton alloc] initWithCustomImages:[[UIImage imageNamed:@"GalleryDoneButton.png"] stretchableImageWithLeftCapWidth:11 topCapHeight:0] imageNormalHighlighted:[[UIImage imageNamed:@"GalleryDoneButton_Highlighted.png"] stretchableImageWithLeftCapWidth:11 topCapHeight:0] imageLandscape:nil imageLandscapeHighlighted:nil textColor:[UIColor whiteColor] shadowColor:UIColorRGBA(0x000000, 0.5f)];
        _doneButton.text = TGLocalized(@"Common.Close");
        _doneButton.minWidth = 55;
        _doneButton.touchInset = CGSizeMake(16, 16);
        [_doneButton sizeToFit];
        _doneButton.frame = CGRectOffset(_doneButton.frame, 5, 7);
        [_doneButton addTarget:self action:@selector(doneButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [_topPanelView addSubview:_doneButton];
        
        if (_enableEditing)
        {
            _editButton = [[TGToolbarButton alloc] initWithCustomImages:[[UIImage imageNamed:@"GalleryCloseButton.png"] stretchableImageWithLeftCapWidth:11 topCapHeight:0] imageNormalHighlighted:[[UIImage imageNamed:@"GalleryCloseButton_Highlighted.png"] stretchableImageWithLeftCapWidth:11 topCapHeight:0] imageLandscape:nil imageLandscapeHighlighted:nil textColor:[UIColor whiteColor] shadowColor:UIColorRGBA(0x16478a, 0.5f)];
            _editButton.text = TGLocalized(@"Common.Edit");
            _editButton.minWidth = 51;
            _editButton.touchInset = CGSizeMake(16, 16);
            [_editButton sizeToFit];
            _editButton.frame = CGRectOffset(_editButton.frame, _topPanelView.frame.size.width - _editButton.frame.size.width - 5, 7);
            _editButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
            [_editButton addTarget:self action:@selector(editButtonPressed) forControlEvents:UIControlEventTouchUpInside];
            [_topPanelView addSubview:_editButton];
        }
        
        _counterLabel = [[UILabel alloc] initWithFrame:CGRectMake(floorf((frame.size.width - 140) / 2), 11, 140, 20)];
        _counterLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        _counterLabel.textAlignment = UITextAlignmentCenter;
        _counterLabel.font = [UIFont boldSystemFontOfSize:20];
        _counterLabel.textColor = [UIColor whiteColor];
        _counterLabel.shadowColor = UIColorRGBA(0x000000, 0.5f);
        _counterLabel.shadowOffset = CGSizeMake(0, -1);
        _counterLabel.backgroundColor = [UIColor clearColor];
        [_topPanelView addSubview:_counterLabel];
        
        UIImage *bottomPanelImage = [UIImage imageNamed:@"GalleryBottomPanel.png"];
        _bottomPanelView = [[UIImageView alloc] initWithFrame:CGRectMake(0, frame.size.height - bottomPanelImage.size.height, frame.size.width, bottomPanelImage.size.height)];
        _bottomPanelView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
        _bottomPanelView.image = [bottomPanelImage stretchableImageWithLeftCapWidth:(int)(bottomPanelImage.size.width / 2) topCapHeight:0];
        _bottomPanelView.userInteractionEnabled = true;
        [self addSubview:_bottomPanelView];
        
        _controlsContainer = [[UIView alloc] initWithFrame:_bottomPanelView.bounds];
        _controlsContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [_bottomPanelView addSubview:_controlsContainer];
        
        _authorLabel = [[UILabel alloc] initWithFrame:CGRectMake(floorf((frame.size.width - 220) / 2), 4, 220, 20)];
        _authorLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        _authorLabel.textAlignment = UITextAlignmentCenter;
        _authorLabel.font = [UIFont boldSystemFontOfSize:14];
        _authorLabel.textColor = [UIColor whiteColor];
        _authorLabel.shadowColor = UIColorRGBA(0x000000, 0.5f);
        _authorLabel.shadowOffset = CGSizeMake(0, -1);
        _authorLabel.backgroundColor = [UIColor clearColor];
        [_controlsContainer addSubview:_authorLabel];
        
        _dateLabel = [[TGDateLabel alloc] initWithFrame:CGRectMake(floorf((frame.size.width - 140) / 2), 23, 140, 20)];
        _dateLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        _dateLabel.textAlignment = UITextAlignmentCenter;
        _dateLabel.dateFont = [UIFont systemFontOfSize:13];
        _dateLabel.dateTextFont = _dateLabel.dateFont;
        _dateLabel.dateLabelFont = [UIFont systemFontOfSize:11];
        _dateLabel.textAlignment = UITextAlignmentCenter;
        _dateLabel.amWidth = 18;
        _dateLabel.pmWidth = 18;
        _dateLabel.dstOffset = 2;
        _dateLabel.textColor = [UIColor whiteColor];
        _dateLabel.shadowColor = UIColorRGBA(0x000000, 0.5f);
        _dateLabel.shadowOffset = CGSizeMake(0, -1);
        _dateLabel.backgroundColor = [UIColor clearColor];
        [_controlsContainer addSubview:_dateLabel];
        
        UIImage *playImage = [UIImage imageNamed:@"VideoPanelPlay.png"];
        UIImage *pauseImage = [UIImage imageNamed:@"VideoPanelPause.png"];
        
        _playButton = [[UIButton alloc] initWithFrame:CGRectMake(floorf((_bottomPanelView.frame.size.width - playImage.size.width) / 2), floorf((_bottomPanelView.frame.size.height - playImage.size.height) / 2), playImage.size.width, playImage.size.height)];
        [_playButton setBackgroundImage:playImage forState:UIControlStateNormal];
        _playButton.exclusiveTouch = true;
        _playButton.showsTouchWhenHighlighted = true;
        _playButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        [_playButton addTarget:self action:@selector(playButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [_controlsContainer addSubview:_playButton];
        
        _pauseButton = [[UIButton alloc] initWithFrame:CGRectMake(floorf((_bottomPanelView.frame.size.width - pauseImage.size.width) / 2), floorf((_bottomPanelView.frame.size.height - pauseImage.size.height) / 2), playImage.size.width, pauseImage.size.height)];
        [_pauseButton setBackgroundImage:pauseImage forState:UIControlStateNormal];
        _pauseButton.exclusiveTouch = true;
        _pauseButton.showsTouchWhenHighlighted = true;
        _pauseButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        [_pauseButton addTarget:self action:@selector(pauseButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [_controlsContainer addSubview:_pauseButton];
        
        _progressContainer = [[UIView alloc] initWithFrame:_controlsContainer.bounds];
        _progressContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _progressContainer.alpha = 0.0f;
        [_bottomPanelView addSubview:_progressContainer];
        
        _progressAuthorLabel = [[UILabel alloc] initWithFrame:CGRectMake(floorf((frame.size.width - 220) / 2), 4, 220, 20)];
        _progressAuthorLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        _progressAuthorLabel.textAlignment = UITextAlignmentCenter;
        _progressAuthorLabel.font = [UIFont boldSystemFontOfSize:14];
        _progressAuthorLabel.textColor = [UIColor whiteColor];
        _progressAuthorLabel.shadowColor = UIColorRGBA(0x000000, 0.5f);
        _progressAuthorLabel.shadowOffset = CGSizeMake(0, -1);
        _progressAuthorLabel.backgroundColor = [UIColor clearColor];
        [_progressContainer addSubview:_progressAuthorLabel];
        
        _progressLabel = [[UILabel alloc] init];
        _progressLabel.clipsToBounds = false;
        _progressLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        _progressLabel.textAlignment = UITextAlignmentCenter;
        _progressLabel.font = [UIFont systemFontOfSize:13];
        _progressLabel.textColor = [UIColor whiteColor];
        _progressLabel.shadowColor = UIColorRGBA(0x000000, 0.5f);
        _progressLabel.shadowOffset = CGSizeMake(0, -1);
        _progressLabel.backgroundColor = [UIColor clearColor];
        [_progressContainer addSubview:_progressLabel];
        
        float retinaPixel = TGIsRetina() ? 0.5f : 0.0f;
        
        _clockProgressView = [[TGClockProgressView alloc] initWithWhite];
        _clockProgressView.frame = CGRectMake(-19, 1 + retinaPixel, 15, 15);
        [_progressLabel addSubview:_clockProgressView];
        
        if (!disableActions)
        {
            _actionButton = [[UIButton alloc] initWithFrame:CGRectMake(6, 2, 40, 40)];
            _actionButton.exclusiveTouch = true;
            [_actionButton setBackgroundImage:[UIImage imageNamed:@"GalleryActionIcon.png"] forState:UIControlStateNormal];
            _actionButton.showsTouchWhenHighlighted = true;
            _actionButton.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
            [_actionButton addTarget:self action:@selector(actionButtonPressed) forControlEvents:UIControlEventTouchUpInside];
            [_bottomPanelView addSubview:_actionButton];
        }
        
        _deleteButton = [[UIButton alloc] initWithFrame:CGRectMake(_bottomPanelView.frame.size.width - 40 - 6, 2, 40, 40)];
        _deleteButton.exclusiveTouch = true;
        [_deleteButton setBackgroundImage:[UIImage imageNamed:@"GalleryTrashIcon.png"] forState:UIControlStateNormal];
        _deleteButton.showsTouchWhenHighlighted = true;
        _deleteButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        [_deleteButton addTarget:self action:@selector(deleteButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [_bottomPanelView addSubview:_deleteButton];
        
        _topPanelView.alpha = 0.0f;
        _bottomPanelView.alpha = 0.0f;
        
        _statusBarWillChangeFrameProxy = [[TGObserverProxy alloc] initWithTarget:self targetSelector:@selector(statusBarWillChangeFrame:) name:UIApplicationWillChangeStatusBarFrameNotification];
        
        [self updateStatusBarFrame:[[UIApplication sharedApplication] statusBarFrame]];
    }
    return self;
}

- (void)dealloc
{
    [_actionHandle reset];
}

- (void)statusBarWillChangeFrame:(NSNotification *)notification
{
     CGRect statusBarFrame = [[[notification userInfo] objectForKey:UIApplicationStatusBarFrameUserInfoKey] CGRectValue];
    
    [UIView animateWithDuration:0.35 animations:^
    {
        [self controlsAlphaUpdated];
        [self updateStatusBarFrame:statusBarFrame];
    }];
}

- (void)updateStatusBarFrame:(CGRect)statusBarFrame
{
    _topPanelView.frame = CGRectMake(0, MIN(statusBarFrame.size.width, statusBarFrame.size.height), self.frame.size.width, _topPanelView.frame.size.height);
}

- (void)toggleShowHide
{
    bool show = _bottomPanelView.alpha < FLT_EPSILON;
    [self setActive:show duration:show ? 0.15 : 0.3];
}

- (float)controlsAlpha
{
    return _bottomPanelView.alpha;
}

- (void)controlsAlphaUpdated
{
    id<ASWatcher> watcher = _watcherHandle.delegate;
    if (watcher != nil && [watcher respondsToSelector:@selector(actionStageActionRequested:options:)])
        [watcher actionStageActionRequested:@"controlsAlphaChanged" options:[[NSDictionary alloc] initWithObjectsAndKeys:[[NSNumber alloc] initWithFloat:[self controlsAlpha]], @"alpha", nil]];
}

- (void)setActive:(bool)active duration:(NSTimeInterval)duration
{
    [self setActive:active duration:duration statusBar:true];
}

- (void)setActive:(bool)active duration:(NSTimeInterval)duration statusBar:(bool)statusBar
{
    if (active)
    {
        if (statusBar)
        {
            [UIView animateWithDuration:duration animations:^
            {
                [TGHacks setApplicationStatusBarAlpha:1.0f];
            }];
        }
        
        _bottomPanelView.hidden = false;
        _topPanelView.hidden = false;
        
        [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^
        {
            _bottomPanelView.alpha = 1.0f;
            _topPanelView.alpha = 1.0f;
            
            [self controlsAlphaUpdated];
        } completion:nil];
    }
    else
    {
        if (statusBar)
        {
            [UIView animateWithDuration:duration animations:^
            {
                [TGHacks setApplicationStatusBarAlpha:0.0f];
            }];
        }
        
        [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^
        {
            _bottomPanelView.alpha = 0.0f;
            _topPanelView.alpha = 0.0f;
            
            [self controlsAlphaUpdated];
        } completion:^(BOOL finished)
        {
            if (finished)
            {
                _bottomPanelView.hidden = true;
                _topPanelView.hidden = true;
            }
        }];
    }
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    UIView *result = [super hitTest:point withEvent:event];
    if ([result isKindOfClass:[UIButton class]])
        return result;
    
    return nil;
}

- (void)doneButtonPressed
{
    id<ASWatcher> watcher = _watcherHandle.delegate;
    if (watcher != nil && [watcher respondsToSelector:@selector(actionStageActionRequested:options:)])
        [watcher actionStageActionRequested:@"animateDisappear" options:nil];
}

- (void)editButtonPressed
{
    [_watcherHandle requestAction:@"activateEditing" options:nil];
}

- (void)deleteButtonPressed
{
    id<ASWatcher> watcher = _watcherHandle.delegate;
    if (watcher != nil && [watcher respondsToSelector:@selector(actionStageActionRequested:options:)])
        [watcher actionStageActionRequested:@"deletePage" options:nil];
}

- (void)actionButtonPressed
{
    id<ASWatcher> watcher = _watcherHandle.delegate;
    if (watcher != nil && [watcher respondsToSelector:@selector(actionStageActionRequested:options:)])
        [watcher actionStageActionRequested:@"showActions" options:nil];
}

- (void)updateLabels
{
    NSString *counterText = nil;
    if (_customTitle != nil)
        counterText = _customTitle;
    else
    {
        if (_totalCount != 0 && _currentIndex >= 0)
            counterText = [[NSString alloc] initWithFormat:@"%d %@ %d", _reversed ? (_currentIndex + 1 + (_loadedCount != 0 ? (_totalCount - _loadedCount) : 0)) : (_totalCount - _currentIndex), TGLocalized(@"Common.of"), _totalCount];
        else
            counterText = @"";
    }
    
    if (![_counterLabel.text isEqualToString:counterText])
    {
        if (_counterLabel.text.length == 0 && counterText.length != 0)
        {
            _counterLabel.alpha = 0.0f;
            [UIView animateWithDuration:0.2 animations:^
             {
                 _counterLabel.alpha = 1.0f;
             }];
        }
        
        _counterLabel.text = counterText;
    }
    
    NSString *authorText = _author == nil ? @"" : _author.displayName;
    if (![_authorLabel.text isEqualToString:authorText])
    {
        _authorLabel.text = authorText;
        _progressAuthorLabel.text = authorText;
    }
    
    NSString *dateText = _date == 0 ? @"" : [TGDateUtils stringForLastSeen:_date];
    if (![dateText isEqualToString:_dateLabel.rawDateText])
    {
        _dateLabel.dateText = dateText;
        [_dateLabel measureTextSize];
    }
    
    if (authorText.length > 0)
        _progressLabel.frame = CGRectMake(_progressLabel.frame.origin.x, 23, _progressLabel.frame.size.width, _progressLabel.frame.size.height);
    else
        _progressLabel.frame = CGRectMake(_progressLabel.frame.origin.x, 14, _progressLabel.frame.size.width, _progressLabel.frame.size.height);
}

- (void)setTotalCount:(int)totalCount loadedCount:(int)loadedCount
{
    _totalCount = totalCount;
    _loadedCount = loadedCount;
    
    [self updateLabels];
}

- (void)setCurrentIndex:(int)currentIndex author:(TGUser *)author date:(int)date
{
    bool updated = false;
    if (_currentIndex != currentIndex)
    {
        _currentIndex = currentIndex;
        updated = true;
    }
    
    if (_author != author)
    {
        _author = author;
        updated = true;
    }
    
    if (_date != date)
    {
        _date = date;
        updated = true;
    }
    
    if (updated)
        [self updateLabels];
}

- (void)setCurrentIndex:(int)currentIndex totalCount:(int)totalCount loadedCount:(int)loadedCount author:(TGUser *)author date:(int)date
{
    _currentIndex = currentIndex;
    _totalCount = totalCount;
    _loadedCount = loadedCount;
    _author = author;
    _date = date;
    
    [self updateLabels];
}

- (void)setPageHandle:(ASHandle *)pageHandle
{
    if (_pageHandle != nil)
        [_pageHandle requestAction:@"bindInterfaceView" options:nil];
    
    _pageHandle = pageHandle;
    
    if (_pageHandle != nil)
    {
        [_pageHandle requestAction:@"bindInterfaceView" options:_actionHandle];
    }
}

- (void)setPlayerControlsVisible:(bool)visible paused:(bool)paused
{
    _playButton.alpha = visible ? 1.0f : 0.0f;
    _pauseButton.alpha = _playButton.alpha;
    _authorLabel.alpha = visible ? 0.0f : 1.0f;
    _dateLabel.alpha = visible ? 0.0f : 1.0f;
    
    _playButton.hidden = !paused;
    _pauseButton.hidden = !_playButton.hidden;
}

- (void)setDownloadControlsVisible:(bool)visible
{
    _controlsContainer.alpha = visible ? 0.0f : 1.0f;
    _progressContainer.alpha = visible ? 1.0f : 0.0f;
    
    if (visible)
    {
        NSString *progressText = (_playButton.alpha > FLT_EPSILON) ? TGLocalized(@"Preview.LoadingVideo") : TGLocalized(@"Preview.LoadingImage");
        if (![progressText isEqualToString:_progressLabel.text])
        {
            _progressLabel.text = progressText;
            [_progressLabel sizeToFit];
            
            _progressLabel.frame = CGRectMake(floorf((_bottomPanelView.frame.size.width - _progressLabel.frame.size.width) / 2) + 10, _progressLabel.frame.origin.y, _progressLabel.frame.size.width, _progressLabel.frame.size.height);
        }
    }
    
    if (_clockProgressView.isAnimating != visible)
    {
        if (visible)
            [_clockProgressView startAnimating];
        else
            [_clockProgressView stopAnimating];
    }
}

- (void)playButtonPressed
{
    [_pageHandle requestAction:@"playMedia" options:nil];
}

- (void)pauseButtonPressed
{
    [_pageHandle requestAction:@"pauseMedia" options:nil];    
}

- (void)setCustomTitle:(NSString *)customTitle
{
    if ((_customTitle != nil) != (customTitle != nil) || (_customTitle != nil && ![_customTitle isEqualToString:customTitle]))
    {
        _customTitle = customTitle;
        
        [self updateLabels];
    }
}

- (void)actionStageActionRequested:(NSString *)action options:(id)options
{
    if ([action isEqualToString:@"bindPage"])
    {
        [self setPageHandle:options];
    }
    else if ([action isEqualToString:@"mediaPlaybackState"])
    {
        [self setPlayerControlsVisible:[[options objectForKey:@"mediaIsPlayable"] boolValue] paused:![[options objectForKey:@"isPlaying"] boolValue]];
    }
    else if ([action isEqualToString:@"mediaDownloadState"])
    {
        [self setDownloadControlsVisible:[[options objectForKey:@"downloadProgressVisible"] boolValue]];
    }
}

@end