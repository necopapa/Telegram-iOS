#import "TGPeopleNearbyController.h"

#import "SGraphObjectNode.h"

#import "TGUser.h"
#import "TGDatabase.h"

#import "TGAppDelegate.h"
#import "TGTelegraph.h"

#import "TGUserDataRequestBuilder.h"
#import "TGInterfaceManager.h"
#import "TGInterfaceAssets.h"

#import "TGContactCell.h"

#import "TGImageUtils.h"

#import "TGTimer.h"

#import "TGSwitchItemCell.h"

#import "TGCommentMenuItem.h"
#import "TGCommentMenuItemView.h"

#import "TGLiveNearbyActor.h"

#import "TGNearbyUserCell.h"

#import "TGStringUtils.h"

#import "TGActionTableView.h"

@interface TGPeopleNearbyController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) TGActionTableView *tableView;
@property (nonatomic) float tableWidth;

@property (nonatomic, strong) NSMutableArray *listModel;
@property (nonatomic) bool onceLoaded;

@property (nonatomic, strong) TGTimer *updateTimer;

@property (nonatomic, strong) UIView *placeholderContainer;

@property (nonatomic, strong) NSNumber *alwaysCheckItemId;
@property (nonatomic, strong) TGCommentMenuItem *alwaysCheckCommentItem;

@property (nonatomic, strong) UIView *locationDisabledContainer;

@property (nonatomic) NSTimeInterval appearAnimationStartTime;

@end

@implementation TGPeopleNearbyController

@synthesize actionHandle = _actionHandle;

@synthesize tableView = _tableView;
@synthesize tableWidth = _tableWidth;

@synthesize listModel = _listModel;
@synthesize onceLoaded = _onceLoaded;

@synthesize updateTimer = _updateTimer;

@synthesize placeholderContainer = _placeholderContainer;

@synthesize alwaysCheckItemId = _alwaysCheckItemId;
@synthesize alwaysCheckCommentItem = _alwaysCheckCommentItem;

@synthesize locationDisabledContainer = _locationDisabledContainer;

@synthesize appearAnimationStartTime = _appearAnimationStartTime;

- (id)init
{
    self = [super initWithNibName:nil bundle:nil];
    if (self)
    {
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:true];
        _actionHandle.delegate = self;
        
        _alwaysCheckItemId = [[NSNumber alloc] initWithInt:0];
        
        _alwaysCheckCommentItem = [[TGCommentMenuItem alloc] initWithComment:@"Always notify me when somebody is around"];
        
        _listModel = [[NSMutableArray alloc] init];
        
        [ActionStageInstance() dispatchOnStageQueue:^
        {
            [ActionStageInstance() watchForPath:@"/tg/liveNearbyResults" watcher:self];
            [ActionStageInstance() watchForPath:@"/tg/locationServicesState" watcher:self];
            [ActionStageInstance() requestActor:@"/tg/locationServicesState/(current)" options:nil watcher:self];
        }];
    }
    return self;
}

- (void)dealloc
{
    [self doUnloadView];
    
    [_actionHandle reset];
    [ActionStageInstance() removeWatcher:self];
}

- (void)loadView
{
    [super loadView];
    
    self.titleText = @"People Nearby";
    self.backAction = @selector(performClose);
    
    self.view.backgroundColor = [[TGInterfaceAssets instance] linesBackground];
    
    _tableWidth = self.view.bounds.size.width;
    
    _tableView = [[TGActionTableView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height) style:UITableViewStyleGrouped];
    [_tableView enableSwipeToLeftAction];
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.backgroundColor = [UIColor clearColor];
    _tableView.opaque = false;
    _tableView.backgroundView = nil;
    [self.view addSubview:_tableView];
    
    _tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    
    UIView *updateContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, _tableView.frame.size.width, 44)];
    updateContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    
    [self.view addSubview:self.locationDisabledContainer];
    _locationDisabledContainer.hidden = true;
    _locationDisabledContainer.alpha = 0.0f;
}

- (UIView *)locationDisabledContainer
{
    _locationDisabledContainer = [[UIView alloc] initWithFrame:self.view.bounds];
    _locationDisabledContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _locationDisabledContainer.backgroundColor = [[TGInterfaceAssets instance] linesBackground];
    
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(floorf((_locationDisabledContainer.frame.size.width - 40) / 2), floorf((_locationDisabledContainer.frame.size.height - 4) / 2), 40, 4)];
    container.tag = 100;
    container.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    container.clipsToBounds = false;
    [_locationDisabledContainer addSubview:container];
    
    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"LocationIcon.png"]];
    iconView.tag = 200;
    [container addSubview:iconView];
    
    UILabel *titleLabelView = [[UILabel alloc] init];
    titleLabelView.tag = 300;
    titleLabelView.backgroundColor = [UIColor clearColor];
    titleLabelView.font = [UIFont boldSystemFontOfSize:17];
    titleLabelView.textColor = UIColorRGB(0x697487);
    titleLabelView.shadowColor = UIColorRGBA(0xffffff, 0.3f);
    titleLabelView.shadowOffset = CGSizeMake(0, 1);
    titleLabelView.numberOfLines = 0;
    titleLabelView.text = @"Turn on Location Services";
    titleLabelView.textAlignment = UITextAlignmentCenter;
    [container addSubview:titleLabelView];
    
    UILabel *subtitleLabelView = [[UILabel alloc] init];
    subtitleLabelView.tag = 400;
    subtitleLabelView.backgroundColor = [UIColor clearColor];
    subtitleLabelView.font = [UIFont boldSystemFontOfSize:TGIsRetina() ? 14.5f : 15.0f];
    subtitleLabelView.textColor = UIColorRGB(0x697487);
    subtitleLabelView.shadowColor = UIColorRGBA(0xffffff, 0.3f);
    subtitleLabelView.shadowOffset = CGSizeMake(0, 1);
    subtitleLabelView.numberOfLines = 0;
    
    subtitleLabelView.textAlignment = UITextAlignmentCenter;
    [container addSubview:subtitleLabelView];
    
    [self.view addSubview:_locationDisabledContainer];
    
    [self updateDisabledContainerLayout:self.interfaceOrientation];
    
    return _locationDisabledContainer;
}

- (void)updateDisabledContainerLayout:(UIInterfaceOrientation)orientation
{
    UIView *container = [_locationDisabledContainer viewWithTag:100];
    UIView *iconView = [_locationDisabledContainer viewWithTag:200];
    UIView *titleLabelView = [_locationDisabledContainer viewWithTag:300];
    UILabel *subtitleLabelView = (UILabel *)[_locationDisabledContainer viewWithTag:400];
    
    bool isPortrait = UIInterfaceOrientationIsPortrait(orientation);
    
    float additionalOffset = isPortrait ? ([TGViewController isWidescreen] ? -30 : -26) : -4;
    
    iconView.frame = CGRectMake(floorf((container.frame.size.width - iconView.frame.size.width) / 2), -110 + additionalOffset, iconView.frame.size.width, iconView.frame.size.height);
    
    CGSize labelSize = [titleLabelView sizeThatFits:CGSizeMake(265, 1000)];
    titleLabelView.frame = CGRectMake(floorf((container.frame.size.width - labelSize.width) / 2), -7 + additionalOffset, labelSize.width, labelSize.height);
    
    NSString *model = @"iPhone";
    NSString *rawModel = [[[UIDevice currentDevice] model] lowercaseString];
    if ([rawModel rangeOfString:@"ipod"].location != NSNotFound)
        model = @"iPod";
    else if ([rawModel rangeOfString:@"ipad"].location != NSNotFound)
        model = @"iPad";
    
    NSString *rawText = isPortrait ? [[NSString alloc] initWithFormat:@"To show people nearby, Telegram needs access to your current location.\n\nPlease go to your %@\nSettings – Privacy – Location Services.\nThen select ON for Telegram.", model] : [[NSString alloc] initWithFormat:@"To show people nearby, Telegram needs access to your\ncurrent location.\n\nPlease go to your %@ Settings – Privacy – Location Services.\nThen select ON for Telegram.", model];
    
    if ([UILabel instancesRespondToSelector:@selector(setAttributedText:)])
    {
        UIColor *foregroundColor = UIColorRGB(0x697487);
        
        NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:[UIFont systemFontOfSize:TGIsRetina() ? 14.5f : 15.0f], NSFontAttributeName, foregroundColor, NSForegroundColorAttributeName, nil];
        NSDictionary *subAttrs = [NSDictionary dictionaryWithObjectsAndKeys:[UIFont boldSystemFontOfSize:TGIsRetina() ? 14.5f : 15.0f], NSFontAttributeName, nil];
        const NSRange range = [rawText rangeOfString:@"ON"];
        
        NSMutableAttributedString *attributedText = [[NSMutableAttributedString alloc] initWithString:rawText attributes:attrs];
        [attributedText setAttributes:subAttrs range:range];
        
        [subtitleLabelView setAttributedText:attributedText];
    }
    else
        subtitleLabelView.text = rawText;
    
    CGSize subtitleLabelSize = [subtitleLabelView sizeThatFits:CGSizeMake(isPortrait ? 300 : 440, 1000)];
    subtitleLabelView.frame = CGRectMake(floorf((container.frame.size.width - subtitleLabelSize.width) / 2), 25 + additionalOffset, subtitleLabelSize.width, subtitleLabelSize.height);
}

- (void)doUnloadView
{
    _tableView.delegate = nil;
    _tableView.dataSource = nil;
    _tableView = nil;
}

- (void)viewDidUnload
{
    [self doUnloadView];
}

- (void)viewWillAppear:(BOOL)animated
{
    _appearAnimationStartTime = CFAbsoluteTimeGetCurrent();
    
    if (!_onceLoaded)
    {
        _onceLoaded = true;

        [ActionStageInstance() requestActor:@"/tg/exclusiveLiveNearby/(discloseLocation)" options:nil watcher:self];
        [ActionStageInstance() requestActor:@"/tg/exclusiveLiveNearby/(holdTimeout)" options:nil watcher:self];
        [ActionStageInstance() requestActor:@"/tg/liveNearby" options:nil watcher:self];
        
        [ActionStageInstance() dispatchOnStageQueue:^
        {
            TGLiveNearbyActor *actor = (TGLiveNearbyActor *)[ActionStageInstance() executingActorWithPath:@"/tg/liveNearby"];
            if (actor != nil)
            {
                NSDictionary *currentResults = [actor currentResults];
                if (currentResults != nil)
                    [self actionStageResourceDispatched:@"/tg/liveNearbyResults" resource:[[SGraphObjectNode alloc] initWithObject:currentResults] arguments:nil];
            }
        }];
    }
    
    if (_tableView.indexPathForSelectedRow != nil)
        [_tableView deselectRowAtIndexPath:[_tableView indexPathForSelectedRow] animated:true];
    
    _tableWidth = _tableView.frame.size.width;
    
    [self updateDisabledContainerLayout:self.interfaceOrientation];
    
    [super viewWillAppear:animated];
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    _tableWidth = [TGViewController screenSizeForInterfaceOrientation:toInterfaceOrientation].width;
    
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [self updateDisabledContainerLayout:toInterfaceOrientation];
    
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return toInterfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
}

- (BOOL)shouldAutorotate
{
    return true;
}

#pragma mark -

- (void)setLocationEnabledState:(bool)enabled animated:(bool)animated
{
    if (enabled != _locationDisabledContainer.alpha < FLT_EPSILON)
    {
        if (!enabled)
            _locationDisabledContainer.hidden = false;
        
        if (animated)
        {
            [UIView animateWithDuration:0.3 animations:^
            {
                if (enabled)
                {
                    _tableView.alpha = 1.0f;
                    _locationDisabledContainer.alpha = 0.0f;
                }
                else
                {
                    _tableView.alpha = 0.0f;
                    _locationDisabledContainer.alpha = 1.0f;
                }
            } completion:^(BOOL finished)
            {
                if (finished)
                {
                    if (enabled)
                        _locationDisabledContainer.hidden = true;
                }
            }];
        }
        else
        {
            if (enabled)
            {
                _tableView.alpha = 1.0f;
                _locationDisabledContainer.alpha = 0.0f;
            }
            else
            {
                _tableView.alpha = 0.0f;
                _locationDisabledContainer.alpha = 1.0f;
            }
            
            if (enabled)
                _locationDisabledContainer.hidden = true;
        }
    }
}

#pragma mark -

- (CGFloat)tableView:(UITableView *)__unused tableView heightForHeaderInSection:(NSInteger)section
{
    if (section == 0)
        return 10;
    else if (section == 1)
        return 10;
    
    return 0;
}

-(CGFloat)tableView:(UITableView*)__unused tableView heightForFooterInSection:(NSInteger)__unused section
{
    return 1;
}

- (CGFloat)tableView:(UITableView *)__unused tableView heightForRowAtIndexPath:(NSIndexPath *)__unused indexPath
{
    if (indexPath.section == 0)
        return _listModel.count == 0 ? 44 : 51;
    else if (indexPath.section == 1)
    {
        if (indexPath.row == 0)
            return 44;
        else if (indexPath.row == 1)
            return [_alwaysCheckCommentItem heightForWidth:_tableWidth];
    }
    return 0;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)__unused tableView
{
    return 2;
}

- (NSInteger)tableView:(UITableView *)__unused tableView numberOfRowsInSection:(NSInteger)__unused section
{
    if (section == 0)
        return MAX(1, (int)_listModel.count);
    else if (section == 1)
        return 2;
    
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = nil;
    bool clearBackground = false;
    bool firstInSection = false;
    bool lastInSection = false;
    
    if (indexPath.section == 0)
    {
        if (_listModel.count == 0)
        {
            static NSString *textCellIdentifier = @"TC";
            TGGroupedCell *textCell = (TGGroupedCell *)[tableView dequeueReusableCellWithIdentifier:textCellIdentifier];
            if (textCell == nil)
            {
                textCell = [[TGGroupedCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:textCellIdentifier];
                
                textCell.selectionStyle = UITableViewCellSelectionStyleNone;
                
                UIImageView *backgroundView = [[UIImageView alloc] init];
                textCell.backgroundView = backgroundView;
                UIImageView *selectedBackgroundView = [[UIImageView alloc] init];
                textCell.selectedBackgroundView = selectedBackgroundView;
                
                textCell.textLabel.text = @"No People Nearby";
                textCell.textLabel.font = [UIFont boldSystemFontOfSize:17];
                textCell.textLabel.textAlignment = UITextAlignmentCenter;
                textCell.textLabel.contentMode = UIViewContentModeCenter;
                textCell.textLabel.textColor = UIColorRGB(0x83888f);
                textCell.textLabel.backgroundColor = [UIColor clearColor];
            }
            
            firstInSection = true;
            lastInSection = true;
            
            cell = textCell;
        }
        else
        {
            TGUser *user = nil;
            if (indexPath.row < (int)_listModel.count)
                user = [_listModel objectAtIndex:indexPath.row];
            
            firstInSection = indexPath.row == 0;
            lastInSection = indexPath.row == (int)_listModel.count - 1;
            
            if (user != nil)
            {
                static NSString *userCellIdentifier = @"UI";
                TGNearbyUserCell *userCell = (TGNearbyUserCell *)[tableView dequeueReusableCellWithIdentifier:userCellIdentifier];
                if (userCell == nil)
                {
                    userCell = [[TGNearbyUserCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:userCellIdentifier];
                    
                    UIImageView *backgroundView = [[UIImageView alloc] init];
                    userCell.backgroundView = backgroundView;
                    UIImageView *selectedBackgroundView = [[UIImageView alloc] init];
                    userCell.selectedBackgroundView = selectedBackgroundView;
                }
                
                userCell.avatarUrl = user.photoUrlSmall;
                userCell.title = user.displayName;
                
                NSNumber *nDistance = [user.customProperties objectForKey:@"distance"];
                
                if (user.phoneNumber.length != 0)
                {
                    userCell.subtitle = [TGStringUtils formatPhone:user.phoneNumber forceInternational:true];
                }
                else if (nDistance != nil)
                {
                    int distance = [nDistance intValue];
                    distance /= 10;
                    distance *= 10;
                    if (distance <= 0)
                        distance = 1;
                    userCell.subtitle = [[NSString alloc] initWithFormat:@"%d m", distance];
                }
                else
                    userCell.subtitle = nil;
                
                [userCell resetView:false];
                
                cell = userCell;
            }
        }
    }
    else if (indexPath.section == 1)
    {
        if (indexPath.row == 0)
        {
            static NSString *switchItemCellIdentifier = @"SI";
            TGSwitchItemCell *switchItemCell = (TGSwitchItemCell *)[tableView dequeueReusableCellWithIdentifier:switchItemCellIdentifier];
            if (switchItemCell == nil)
            {
                switchItemCell = [[TGSwitchItemCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:switchItemCellIdentifier];
                switchItemCell.selectionStyle = UITableViewCellSelectionStyleNone;
                switchItemCell.watcherHandle = _actionHandle;
                
                UIImageView *backgroundView = [[UIImageView alloc] init];
                switchItemCell.backgroundView = backgroundView;
                UIImageView *selectedBackgroundView = [[UIImageView alloc] init];
                switchItemCell.selectedBackgroundView = selectedBackgroundView;
                
                switchItemCell.selectionStyle = UITableViewCellSelectionStyleNone;
            }
        
            [switchItemCell setTitle:@"Always notify me"];
            [switchItemCell setIsOn:TGAppDelegateInstance.locationTranslationEnabled];
            switchItemCell.itemId = _alwaysCheckItemId;
            
            firstInSection = true;
            lastInSection = true;
            
            cell = switchItemCell;
        }
        else if (indexPath.row == 1)
        {
            static NSString *commentItemCellIdentifier = @"CI";
            TGCommentMenuItemView *commentItemCell = (TGCommentMenuItemView *)[tableView dequeueReusableCellWithIdentifier:commentItemCellIdentifier];
            if (commentItemCell == nil)
            {
                commentItemCell = [[TGCommentMenuItemView alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:commentItemCellIdentifier];
                
                commentItemCell.selectionStyle = UITableViewCellSelectionStyleNone;
                commentItemCell.backgroundView = [[UIView alloc] init];
                commentItemCell.selectedBackgroundView = [[UIView alloc] init];
            }
            
            commentItemCell.label = _alwaysCheckCommentItem.comment;
            
            clearBackground = true;
            cell = commentItemCell;
        }
    }
    
    if (cell != nil)
    {
        if (!clearBackground)
        {
            if (firstInSection && lastInSection)
            {
                [(TGGroupedCell *)cell setGroupedCellPosition:TGGroupedCellPositionFirst | TGGroupedCellPositionLast];
                [(TGGroupedCell *)cell setExtendSelectedBackground:false];
                
                ((UIImageView *)cell.backgroundView).image = [TGInterfaceAssets groupedCellSingle];
                ((UIImageView *)cell.selectedBackgroundView).image = [TGInterfaceAssets groupedCellSingleHighlighted];
            }
            else if (firstInSection)
            {
                [(TGGroupedCell *)cell setGroupedCellPosition:TGGroupedCellPositionFirst];
                [(TGGroupedCell *)cell setExtendSelectedBackground:true];
                
                ((UIImageView *)cell.backgroundView).image = [TGInterfaceAssets groupedCellTop];
                ((UIImageView *)cell.selectedBackgroundView).image = [TGInterfaceAssets groupedCellTopHighlighted];
            }
            else if (lastInSection)
            {
                [(TGGroupedCell *)cell setGroupedCellPosition:TGGroupedCellPositionLast];
                [(TGGroupedCell *)cell setExtendSelectedBackground:true];
                
                ((UIImageView *)cell.backgroundView).image = [TGInterfaceAssets groupedCellBottom];
                ((UIImageView *)cell.selectedBackgroundView).image = [TGInterfaceAssets groupedCellBottomHighlighted];
            }
            else
            {
                [(TGGroupedCell *)cell setGroupedCellPosition:0];
                [(TGGroupedCell *)cell setExtendSelectedBackground:true];
                
                ((UIImageView *)cell.backgroundView).image = [TGInterfaceAssets groupedCellMiddle];
                ((UIImageView *)cell.selectedBackgroundView).image = [TGInterfaceAssets groupedCellMiddleHighlighted];
            }
        }
        
        return cell;
    }
    
    static NSString *errorCellIdentifier = @"EC";
    UITableViewCell *errorCell = [tableView dequeueReusableCellWithIdentifier:errorCellIdentifier];
    if (errorCell == nil)
    {
        errorCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:errorCellIdentifier];
        errorCell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    return errorCell;
}

- (void)tableView:(UITableView *)__unused tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section != 0)
        return;
    
    TGUser *user = nil;
    if (indexPath.row < (int)_listModel.count)
        user = [_listModel objectAtIndex:indexPath.row];
    if (user != nil)
    {
        if([TGDatabaseInstance() loadUser:user.uid] == nil)
            [TGUserDataRequestBuilder executeUserObjectsUpdate:[NSArray arrayWithObject:user]];
        [[TGInterfaceManager instance] navigateToProfileOfUser:user.uid];
    }
}

#pragma mark -

- (void)performClose
{
    [self.navigationController popViewControllerAnimated:true];
}

- (void)performSwipeToLeftAction
{
    [self performClose];
}

#pragma mark -

- (void)actionStageResourceDispatched:(NSString *)path resource:(id)resource arguments:(id)__unused arguments
{
    if ([path isEqualToString:@"/tg/liveNearbyResults"])
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            NSDictionary *resultDict = ((SGraphObjectNode *)resource).object;
            NSArray *usersLocated = [resultDict objectForKey:@"usersLocated"];
            
            [_listModel removeAllObjects];
            [_listModel addObjectsFromArray:usersLocated];
            [_tableView reloadData];
        });
    }
    else if ([path hasPrefix:@"/tg/locationServicesState"])
    {
        [self actorCompleted:ASStatusSuccess path:path result:resource];
    }
}

- (void)actorCompleted:(int)resultCode path:(NSString *)path result:(id)result
{
    if ([path hasPrefix:@"/tg/locationServicesState"])
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            if (resultCode == ASStatusSuccess)
            {
                bool enabled = [((SGraphObjectNode *)result).object boolValue];
                [self setLocationEnabledState:enabled animated:(CFAbsoluteTimeGetCurrent() - _appearAnimationStartTime > 0.15)];
            }
        });
    }
}

#pragma mark -

- (void)actionStageActionRequested:(NSString *)action options:(NSDictionary *)options
{
    if ([action isEqualToString:@"toggleSwitchItem"])
    {
        int itemId = [[options objectForKey:@"itemId"] intValue];
        bool value = [[options objectForKey:@"value"] boolValue];
        
        if (itemId == 0)
        {
            TGAppDelegateInstance.locationTranslationEnabled = value;
            [TGAppDelegateInstance saveSettings];
            [TGTelegraphInstance locationTranslationSettingsUpdated];
        }
    }
}

@end
