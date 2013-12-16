#import "TGMapViewController.h"

#import "TGToolbarButton.h"

#import <MapKit/MapKit.h>

#import "TGMapView.h"

#import "TGActivityIndicatorView.h"
#import "TGButtonGroupView.h"

#import "TGImageUtils.h"

#import "TGMapAnnotationView.h"
#import "TGCalloutView.h"

#import "TGContactMediaAttachment.h"

typedef enum {
    TGMapViewControllerModePick = 0,
    TGMapViewControllerModeMap = 1
} TGMapViewControllerMode;

static CLLocation *lastUserLocation = nil;

static int selectedMapMode = 0;
static bool selectedMapModeInitialized = false;

@protocol TGApplicationWithCustomURLHandling <NSObject>

- (BOOL)openURL:(NSURL *)url forceNative:(BOOL)forceNative;

@end

static int defaultMapMode()
{
    if (!selectedMapModeInitialized)
    {
        selectedMapModeInitialized = true;
        
        selectedMapMode = [[[NSUserDefaults standardUserDefaults] objectForKey:@"TGMapViewController.defaultMapMode"] intValue];
    }
    
    return selectedMapMode;
}

static void setDefaultMapMode(int mode)
{
    selectedMapModeInitialized = true;
    selectedMapMode = mode;
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:[[NSNumber alloc] initWithInt:mode] forKey:@"TGMapViewController.defaultMapMode"];
    [userDefaults synchronize];
}

@interface TGLocationAnnotation : NSObject <MKAnnotation>

@property (nonatomic, readonly) CLLocationCoordinate2D coordinate;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *subtitle;

- (id)initWithCoordinate:(CLLocationCoordinate2D)coordinate title:(NSString *)title;

@end

@implementation TGLocationAnnotation

@synthesize coordinate = _coordinate;
@synthesize title = _title;
@synthesize subtitle = _subtitle;

- (id)initWithCoordinate:(CLLocationCoordinate2D)coordinate title:(NSString *)title
{
    self = [super init];
    if (self != nil)
    {
        _coordinate = coordinate;
        self.title = title;
        self.subtitle = nil;
    }
    return self;
}

- (void)setCoordinate:(CLLocationCoordinate2D)newCoordinate
{
    _coordinate = newCoordinate;
}

@end

#pragma mark -

@interface TGMapViewController () <MKMapViewDelegate, TGButtonGroupViewDelegate, UIActionSheetDelegate>

@property (nonatomic) TGMapViewControllerMode mode;

@property (nonatomic, strong) TGToolbarButton *doneButton;

@property (nonatomic) bool locationServicesDisabled;

@property (nonatomic, strong) TGUser *user;

@property (nonatomic, strong) TGMapView *mapView;
@property (nonatomic) bool modifiedPinLocation;
@property (nonatomic) bool modifiedRegion;

@property (nonatomic, strong) TGLocationAnnotation *highlightedLocationAnnotation;
@property (nonatomic, strong) CLLocation *mapLocation;

@property (nonatomic, strong) UIButton *locationButton;

@property (nonatomic, strong) UIView *locationIconsContainer;
@property (nonatomic, strong) TGActivityIndicatorView *locationActivityIndicator;
@property (nonatomic, strong) UIImageView *locationNormalIcon;
@property (nonatomic, strong) UIImageView *locationActiveIcon;
@property (nonatomic, strong) UIImageView *locationActiveHeadingIcon;

@property (nonatomic, strong) TGButtonGroupView *buttonGroupView;

@property (nonatomic, strong) UIActionSheet *currentActionSheet;

@property (nonatomic) bool mapViewFinished;

@end

@implementation TGMapViewController

- (id)initInPickingMode
{
    self = [super initWithNibName:nil bundle:nil];
    if (self)
    {
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:true];
        
        _mode = TGMapViewControllerModePick;
    }
    return self;
}

- (id)initInMapModeWithLatitude:(double)latitude longitude:(double)longitude user:(TGUser *)user
{
    self = [super initWithNibName:nil bundle:nil];
    if (self)
    {
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:true];
        
        _mode = TGMapViewControllerModeMap;
        
        _user = user;
        _mapLocation = [[CLLocation alloc] initWithLatitude:latitude longitude:longitude];
        _highlightedLocationAnnotation = [[TGLocationAnnotation alloc] initWithCoordinate:CLLocationCoordinate2DMake(latitude, longitude) title:nil];
    }
    return self;
}

- (void)dealloc
{
    [_actionHandle reset];
    [ActionStageInstance() removeWatcher:self];
    
    [self doUnloadView];
}

- (void)loadView
{
    [super loadView];
    
    _mapView = [[TGMapView alloc] initWithFrame:self.view.bounds];
    _mapView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _mapView.zoomEnabled = true;
    _mapView.scrollEnabled = true;
    _mapView.delegate = self;
    _mapView.userInteractionEnabled = true;
    
    _mapView.showsUserLocation = true;
    
    _mapView.mapType = defaultMapMode();

    if (iosMajorVersion() >= 6)
    {
        for (UIView *subview in _mapView.subviews)
        {
            if ([subview isKindOfClass:[UILabel class]])
            {
                subview.autoresizingMask = 0;
                CGRect frame = subview.frame;
                frame.origin.y = 5;
                frame.origin.x = 5;
                subview.frame = frame;
                
                break;
            }
        }
    }
    
    if (_mode == TGMapViewControllerModePick)
    {
        self.titleText = TGLocalized(@"Map.ChooseLocationTitle");
        
        TGToolbarButton *cancelButton = [[TGToolbarButton alloc] initWithType:TGToolbarButtonTypeGeneric];
        cancelButton.text = TGLocalized(@"Common.Cancel");
        cancelButton.minWidth = 59;
        [cancelButton sizeToFit];
        [cancelButton addTarget:self action:@selector(cancelButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:cancelButton];
        
        _doneButton = [[TGToolbarButton alloc] initWithType:TGToolbarButtonTypeDone];
        _doneButton.text = TGLocalized(@"Map.Send");
        _doneButton.minWidth = 52;
        [_doneButton sizeToFit];
        [_doneButton addTarget:self action:@selector(doneButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:_doneButton];
        _doneButton.enabled = false;
        
        UILongPressGestureRecognizer *longPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(mapLongPressed:)];
        [_mapView addGestureRecognizer:longPressRecognizer];
        
        if (lastUserLocation != nil)
        {
            MKCoordinateRegion mapRegion;
            mapRegion.center = lastUserLocation.coordinate;
            mapRegion.span.latitudeDelta = 0.008;
            mapRegion.span.longitudeDelta = 0.008;
            
            @try
            {
                [_mapView setRegion:mapRegion animated:false];
            }
            @catch (NSException *exception) { TGLog(@"%@", exception); }
        }
    }
    else if (_mode == TGMapViewControllerModeMap)
    {   
        self.titleText = NSLocalizedString(@"Map.MapTitle", nil);
        
        self.backAction = @selector(performCloseMap);
        
        TGToolbarButton *actionsButton = [[TGToolbarButton alloc] initWithType:TGToolbarButtonTypeGeneric];
        actionsButton.image = [UIImage imageNamed:@"HeaderActions.png"];
        //_addButton.imageLandscape = [UIImage imageNamed:@"AddIcon_Landscape.png"];
        actionsButton.minWidth = 37;
        [actionsButton sizeToFit];
        [actionsButton addTarget:self action:@selector(actionsButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        UIBarButtonItem *actionsButtonItem = [[UIBarButtonItem alloc] initWithCustomView:actionsButton];
        self.navigationItem.rightBarButtonItem = actionsButtonItem;
        
        MKCoordinateRegion mapRegion;
        mapRegion.center = _highlightedLocationAnnotation.coordinate;
        mapRegion.span.latitudeDelta = 0.008;
        mapRegion.span.longitudeDelta = 0.008;
        
        @try
        {
            [_mapView setRegion:mapRegion animated:false];
        }
        @catch (NSException *exception)
        {
            TGLog(@"%@", exception);
        }
        
        [_mapView addAnnotation:_highlightedLocationAnnotation];
        [_mapView selectAnnotation:_highlightedLocationAnnotation animated:false];
    }
    
    [self.view addSubview:_mapView];
    
    UIImage *rawButtonImage = [UIImage imageNamed:@"MapSingleButton.png"];
    UIImage *rawButtonHighlightedImage = [UIImage imageNamed:@"MapSingleButton_Highlighted.png"];
    
    float retinaPixel = TGIsRetina() ? 0.5f : 0.0f;
    
    _locationButton = [[UIButton alloc] initWithFrame:CGRectMake(6, self.view.frame.size.height - 6 - rawButtonImage.size.height, 40, rawButtonImage.size.height)];
    [_locationButton addTarget:self action:@selector(locationButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    _locationButton.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
    [_locationButton setBackgroundImage:[rawButtonImage stretchableImageWithLeftCapWidth:(int)(rawButtonImage.size.width / 2) topCapHeight:0] forState:UIControlStateNormal];
    [_locationButton setBackgroundImage:[rawButtonHighlightedImage stretchableImageWithLeftCapWidth:(int)(rawButtonHighlightedImage.size.width / 2) topCapHeight:0] forState:UIControlStateHighlighted];
    [self.view addSubview:_locationButton];
    
    _locationIconsContainer = [[UIView alloc] initWithFrame:_locationButton.bounds];
    _locationIconsContainer.userInteractionEnabled = false;
    [_locationButton addSubview:_locationIconsContainer];
    
    _locationNormalIcon = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"MapLocationIcon.png"]];
    _locationNormalIcon.frame = CGRectOffset(_locationNormalIcon.frame, 9, 7);
    [_locationIconsContainer addSubview:_locationNormalIcon];
    
    _locationActiveIcon = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"MapLocationIcon_Active.png"]];
    _locationActiveIcon.frame = CGRectOffset(_locationActiveIcon.frame, 9, 7);
    _locationActiveIcon.alpha = 0.0f;
    [_locationIconsContainer addSubview:_locationActiveIcon];
    
    _locationActiveHeadingIcon = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"MapLocationIcon_ActiveHeading.png"]];
    _locationActiveHeadingIcon.frame = CGRectOffset(_locationActiveIcon.frame, 1, 0);
    _locationActiveHeadingIcon.alpha = 0.0f;
    [_locationIconsContainer addSubview:_locationActiveHeadingIcon];
    
    _locationActivityIndicator = [[TGActivityIndicatorView alloc] initWithStyle:TGActivityIndicatorViewStyleSmall];
    _locationActivityIndicator.userInteractionEnabled = false;
    _locationActivityIndicator.frame = CGRectOffset(_locationActivityIndicator.frame, floorf((_locationButton.frame.size.width - _locationActivityIndicator.frame.size.width) / 2.0f) + retinaPixel, floorf((_locationButton.frame.size.height - _locationActivityIndicator.frame.size.height) / 2.0f) + retinaPixel);
    _locationActivityIndicator.alpha = 0.0f;
    _locationActivityIndicator.transform = CGAffineTransformMakeScale(0.1f, 0.1f);
    [_locationButton addSubview:_locationActivityIndicator];

    UIImage *rawButtonLeft = [UIImage imageNamed:@"MapButtonGroupLeft.png"];
    UIImage *buttonLeft = [rawButtonLeft stretchableImageWithLeftCapWidth:(int)(rawButtonLeft.size.width - 1) topCapHeight:0];
    UIImage *rawButtonLeftHighlighted = [UIImage imageNamed:@"MapButtonGroupLeft_Highlighted.png"];
    UIImage *buttonLeftHighlighted = [rawButtonLeftHighlighted stretchableImageWithLeftCapWidth:(int)(rawButtonLeftHighlighted.size.width - 1) topCapHeight:0];
    
    UIImage *rawButtonRight = [UIImage imageNamed:@"MapButtonGroupRight.png"];
    UIImage *buttonRight = [rawButtonRight stretchableImageWithLeftCapWidth:1 topCapHeight:0];
    UIImage *rawButtonRightHighlighted = [UIImage imageNamed:@"MapButtonGroupRight_Highlighted.png"];
    UIImage *buttonRightHighlighted = [rawButtonRightHighlighted stretchableImageWithLeftCapWidth:1 topCapHeight:0];
    
    UIImage *rawButtonCenter = [UIImage imageNamed:@"MapButtonGroupCenter.png"];
    UIImage *buttonCenter = [rawButtonCenter stretchableImageWithLeftCapWidth:(int)(rawButtonCenter.size.width / 2) topCapHeight:0];
    UIImage *rawButtonCenterHighlighted = [UIImage imageNamed:@"MapButtonGroupCenter_Highlighted.png"];
    UIImage *buttonCenterHighlighted = [rawButtonCenterHighlighted stretchableImageWithLeftCapWidth:(int)(rawButtonCenterHighlighted.size.width / 2) topCapHeight:0];
    
    UIImage *buttonSeparator = [UIImage imageNamed:@"MapButtonGroupDivider.png"];
    UIImage *buttonSeparatorLeftHighlighted = [UIImage imageNamed:@"MapButtonGroupDivider_LeftHighlighted.png"];
    UIImage *buttonSeparatorRightHighlighted = [UIImage imageNamed:@"MapButtonGroupDivider_RightHighlighted.png"];
    
    _buttonGroupView = [[TGButtonGroupView alloc] initWithFrame:CGRectMake(self.view.frame.size.width - 219 - 6, self.view.frame.size.height - rawButtonLeft.size.height - 7, 219, rawButtonLeft.size.height) buttonLeftImage:buttonLeft buttonLeftHighlightedImage:buttonLeftHighlighted buttonCenterImage:buttonCenter buttonCenterHighlightedImage:buttonCenterHighlighted buttonRightImage:buttonRight buttonRightHighlightedImage:buttonRightHighlighted buttonSeparatorImage:buttonSeparator buttonSeparatorLeftHighlightedImage:buttonSeparatorLeftHighlighted buttonSeparatorRightHighlightedImage:buttonSeparatorRightHighlighted];
    _buttonGroupView.delegate = self;
    _buttonGroupView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;
    _buttonGroupView.selectedIndex = MIN(2, MAX(0, _mapView.mapType));
    _buttonGroupView.buttonTopTextInset = 1;
    _buttonGroupView.buttonSideTextInset = 3;
    _buttonGroupView.buttonTextColorHighlighted = UIColorRGB(0x046dd0);
    _buttonGroupView.buttonTextColor = UIColorRGB(0x595959);
    _buttonGroupView.buttonShadowColor = UIColorRGBA(0xffffff, 0.6f);
    _buttonGroupView.buttonShadowOffset = CGSizeMake(0, 1);
    _buttonGroupView.buttonFont = [UIFont boldSystemFontOfSize:12];
    _buttonGroupView.buttonsAreAlwaysDeselected = true;
    [_buttonGroupView addButton:TGLocalized(@"Map.Map")];
    [_buttonGroupView addButton:TGLocalized(@"Map.Satellite")];
    [_buttonGroupView addButton:TGLocalized(@"Map.Hybrid")];
    [self.view addSubview:_buttonGroupView];
}

- (void)doUnloadView
{
    _mapView.delegate = nil;
    _mapView = nil;
    
    _buttonGroupView.delegate = nil;
    
    _currentActionSheet.delegate = nil;
}

- (void)viewDidUnload
{
    [self doUnloadView];
    
    [super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    if ([self respondsToSelector:@selector(presentedViewController)])
    {
        if ([self presentedViewController] != nil)
            return false;
    }
    else
    {
        if ([self modalViewController] != nil)
            return false;
    }
    
    return toInterfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
}

- (BOOL)shouldAutorotate
{
    return [self shouldAutorotateToInterfaceOrientation:UIInterfaceOrientationPortrait];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [_mapView setCenterCoordinate:_mapView.region.center animated:NO];
    
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
}

#pragma mark -

- (void)mapView:(MKMapView *)__unused mapView didUpdateUserLocation:(MKUserLocation *)userLocation
{   
    if (userLocation.coordinate.latitude == 0.0 && userLocation.coordinate.longitude == 0.0)
        return;
    
    _locationServicesDisabled = false;
        
    lastUserLocation = userLocation.location;
    
    if (_mode == TGMapViewControllerModePick)
    {
        if (!_modifiedPinLocation)
        {
            if (!_modifiedRegion)
            {
                _modifiedRegion = true;
                
                MKCoordinateRegion mapRegion;
                mapRegion.center = userLocation.coordinate;
                mapRegion.span.latitudeDelta = 0.008;
                mapRegion.span.longitudeDelta = 0.008;
             
                @try
                {
                    [_mapView setRegion:mapRegion animated:true];
                }
                @catch (NSException *exception) { TGLog(@"%@", exception); }
            }
        
            if (_highlightedLocationAnnotation != nil)
            {
                [_highlightedLocationAnnotation setCoordinate:userLocation.coordinate];
            }
            else
            {
                _highlightedLocationAnnotation = [[TGLocationAnnotation alloc] initWithCoordinate:userLocation.coordinate title:nil];
                [_mapView addAnnotation:_highlightedLocationAnnotation];
            }
        }
    }
    
    if (_locationActivityIndicator.alpha > FLT_EPSILON)
    {
        [_mapView setUserTrackingMode:MKUserTrackingModeFollow animated:true];
        [self updateLocationIcons];
    }
    
    [self updateLocationAvailability];
    
    if (_mode == TGMapViewControllerModeMap)
    {
        //TGDispatchAfter(1.0, dispatch_get_main_queue(), ^{
            [self updateAnnotationView:(TGMapAnnotationView *)[_mapView viewForAnnotation:_highlightedLocationAnnotation]];
        //});
    }
    
    [self updateDoneButton];
}

- (void)mapView:(MKMapView *)__unused mapView annotationView:(MKAnnotationView *)__unused annotationView didChangeDragState:(MKAnnotationViewDragState)__unused newState fromOldState:(MKAnnotationViewDragState)__unused oldState
{
    if (!_modifiedPinLocation)
        _modifiedPinLocation = true;
    
    if (newState == MKAnnotationViewDragStateEnding)
        [self updateDoneButton];
}

- (void)mapView:(MKMapView *)__unused mapView didFailToLocateUserWithError:(NSError *)__unused error
{
    if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusDenied)
    {
        _locationServicesDisabled = true;
        
        [self updateLocationAvailability];
        
        if (_locationServicesDisabled && _mode == TGMapViewControllerModePick)
        {
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:nil message:TGLocalized(@"Map.AccessDeniedError") delegate:nil cancelButtonTitle:TGLocalized(@"Common.OK") otherButtonTitles:nil];
            [alertView show];
        }
    }
}

- (void)mapView:(MKMapView *)__unused mapView didAddAnnotationViews:(NSArray *)views
{
    if (_mode != TGMapViewControllerModePick)
        return;
    
    for (MKAnnotationView *annotationView in views)
    {
        if ([annotationView.annotation isKindOfClass:[MKUserLocation class]])
            continue;
        
        MKMapPoint point =  MKMapPointForCoordinate(annotationView.annotation.coordinate);
        if (!MKMapRectContainsPoint(self.mapView.visibleMapRect, point))
            continue;
        
        CGRect endFrame = annotationView.frame;
        
        annotationView.frame = CGRectMake(annotationView.frame.origin.x, annotationView.frame.origin.y - self.view.frame.size.height, annotationView.frame.size.width, annotationView.frame.size.height);
        
        id<MKAnnotation> annotation = annotationView.annotation;
        
        [UIView animateWithDuration:0.5 delay:(0.04 * [views indexOfObject:annotationView]) options:0 animations:^
        {
            annotationView.frame = endFrame;
        } completion:^(BOOL finished)
        {
            if (finished)
            {
                [UIView animateWithDuration:0.05 animations:^
                {
                    annotationView.transform = CGAffineTransformMakeScale(1.0, 0.8);
                } completion:^(BOOL finished)
                {
                    [mapView selectAnnotation:annotation animated:true];
                    if (finished)
                    {
                        [UIView animateWithDuration:0.1 animations:^
                        {
                            annotationView.transform = CGAffineTransformIdentity;
                        }];
                    }
                }];
            }
        }];
    }
}

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation
{
    if (annotation == mapView.userLocation)
        return nil;
    
    MKPinAnnotationView *annotationView = (MKPinAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:@"Pin"];
    if (annotationView == nil)
    {
        if (_mode == TGMapViewControllerModeMap)
        {
            annotationView = [[TGMapAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:@"Pin"];
            ((TGMapAnnotationView *)annotationView).watcherHandle = _actionHandle;
        }
        else
            annotationView = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:@"Pin"];
    }
    annotationView.canShowCallout = false;
    annotationView.animatesDrop = false;
    if (_mode == TGMapViewControllerModePick)
        annotationView.draggable = true;
    else
        [self updateAnnotationView:(TGMapAnnotationView *)annotationView];
    
    return annotationView;
}

- (void)mapView:(MKMapView *)__unused mapView didSelectAnnotationView:(MKAnnotationView *)view
{
    if (_highlightedLocationAnnotation != nil && view.annotation == _highlightedLocationAnnotation)
    {
        if (_mode == TGMapViewControllerModeMap)
        {
            
        }
    }
}

- (void)mapView:(MKMapView *)__unused mapView didDeselectAnnotationView:(MKAnnotationView *)view
{
    if (_highlightedLocationAnnotation != nil && view.annotation == _highlightedLocationAnnotation)
    {
        if (_mode == TGMapViewControllerModeMap)
        {
            
        }
    }
}

#pragma mark -

- (void)updateAnnotationView:(TGMapAnnotationView *)annotationView
{
    [annotationView.calloutView setTitleText:_user.displayName];
    
    if (_mapView.userLocation != nil && _mapView.userLocation.location != nil)
    {
        static bool metricUnits = true;
        
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^
        {
            NSLocale *locale = [NSLocale currentLocale];
            metricUnits = [[locale objectForKey:NSLocaleUsesMetricSystem] boolValue];
        });
        
        NSString *distanceString = nil;
        
        double distance = [_mapLocation distanceFromLocation:_mapView.userLocation.location];
        
        if (metricUnits)
        {
            if (distance >= 1000 * 1000)
                distanceString = [[NSString alloc] initWithFormat:@"%.1fK km away", distance / (1000.0 * 1000.0)];
            else if (distance > 1000)
                distanceString = [[NSString alloc] initWithFormat:@"%.1f km away", distance / 1000.0];
            else
                distanceString = [[NSString alloc] initWithFormat:@"%d m away", (int)distance];
        }
        else
        {
            double feetDistance = distance / 0.3048;
            
            if (feetDistance >= 5280)
            {
                char buf[32];
                snprintf(buf, 32, "%.1f", feetDistance / 5280.0);
                bool dot = false;
                for (int i = 0; i < 32; i++)
                {
                    char c = buf[i];
                    if (c == '\0')
                        break;
                    else if (c < '0' || c > '9')
                    {
                        dot = true;
                        break;
                    }
                }
                distanceString = [[NSString alloc] initWithFormat:@"%s mile%s away", buf, dot || feetDistance / 5280.0 > 1.0 ? "s" : ""];
            }
            else
            {
                distanceString = [[NSString alloc] initWithFormat:@"%d %s away", (int)feetDistance, (int)feetDistance != 1 ? "feet" : "foot"];
            }
        }
        
        [annotationView.calloutView setSubtitleText:distanceString];
    }
    else
        [annotationView.calloutView setSubtitleText:nil];
    
    [annotationView.calloutView sizeToFit];
    [annotationView setNeedsLayout];
    if (annotationView.calloutView.frame.origin.y < 0)
    {
        [UIView animateWithDuration:0.2 animations:^
        {
            [annotationView layoutIfNeeded];
        }];
    }
}

- (void)mapView:(MKMapView *)__unused mapView regionDidChangeAnimated:(BOOL)__unused animated
{
    //TGLog(@"region change");
}

- (void)mapView:(MKMapView *)__unused mapView didChangeUserTrackingMode:(MKUserTrackingMode)__unused mode animated:(BOOL)__unused animated
{
    [self updateLocationIcons];
}

- (void)updateDoneButton
{
    if (_mode == TGMapViewControllerModePick)
    {
        _doneButton.enabled = ABS(_highlightedLocationAnnotation.coordinate.latitude) > DBL_EPSILON || ABS(_highlightedLocationAnnotation.coordinate.longitude) > DBL_EPSILON;
    }
}

- (void)mapViewWillStartLoadingMap:(MKMapView *)__unused mapView
{
    _mapViewFinished = false;
}

- (void)mapViewDidFinishLoadingMap:(MKMapView *)__unused mapView
{
    _mapViewFinished = true;
}

#pragma mark - Actions

- (void)mapLongPressed:(UILongPressGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateBegan)
    {
        _modifiedPinLocation = true;

        if (_highlightedLocationAnnotation != nil)
        {
            [_mapView removeAnnotation:_highlightedLocationAnnotation];
            _highlightedLocationAnnotation = nil;
        }
        
        CGPoint touchPoint = [recognizer locationInView:_mapView];
        CLLocationCoordinate2D touchMapCoordinate = [_mapView convertPoint:touchPoint toCoordinateFromView:_mapView];
        _highlightedLocationAnnotation = [[TGLocationAnnotation alloc] initWithCoordinate:touchMapCoordinate title:nil];
        [_mapView addAnnotation:_highlightedLocationAnnotation];
        
        [self updateDoneButton];
    }
}

- (void)performCloseMap
{
    [self.navigationController popViewControllerAnimated:true];
}

- (void)cancelButtonPressed
{
    id<ASWatcher> watcherDelegate = _watcher == nil ? nil : _watcher.delegate;
    if (watcherDelegate != nil && [watcherDelegate respondsToSelector:@selector(actionStageActionRequested:options:)])
    {
        [watcherDelegate actionStageActionRequested:@"mapViewFinished" options:nil];
    }
}

- (void)doneButtonPressed
{
    id<ASWatcher> watcherDelegate = _watcher == nil ? nil : _watcher.delegate;
    if (watcherDelegate != nil && [watcherDelegate respondsToSelector:@selector(actionStageActionRequested:options:)])
    {
        NSMutableDictionary *options = [[NSMutableDictionary alloc] init];
        if (_highlightedLocationAnnotation != nil && (_highlightedLocationAnnotation.coordinate.latitude != 0.0 || _highlightedLocationAnnotation.coordinate.longitude != 0.0))
        {
            [options setObject:[NSNumber numberWithDouble:_highlightedLocationAnnotation.coordinate.latitude] forKey:@"latitude"];
            [options setObject:[NSNumber numberWithDouble:_highlightedLocationAnnotation.coordinate.longitude] forKey:@"longitude"];
        }
        else if (_mapView.userLocation != nil && (_mapView.userLocation.coordinate.latitude != 0.0 || _mapView.userLocation.coordinate.longitude != 0.0))
        {
            [options setObject:[NSNumber numberWithDouble:_mapView.userLocation.coordinate.latitude] forKey:@"latitude"];
            [options setObject:[NSNumber numberWithDouble:_mapView.userLocation.coordinate.longitude] forKey:@"longitude"];
        }
        
        if (_mapViewFinished)
        {
            
        }
        
        [watcherDelegate actionStageActionRequested:@"mapViewFinished" options:options];
    }
}

- (void)locationButtonPressed
{
    if (_mapView.userLocation != nil && _mapView.userLocation.location != nil)
    {
        if (_mapView.userTrackingMode == MKUserTrackingModeNone)
        {
            [_mapView setUserTrackingMode:MKUserTrackingModeFollow animated:true];
            [self updateLocationIcons];
        }
        else if (_mapView.userTrackingMode == MKUserTrackingModeFollow)
        {
            [_mapView setUserTrackingMode:MKUserTrackingModeFollowWithHeading animated:true];
            [self updateLocationIcons];
        }
        else
        {
            [_mapView setUserTrackingMode:MKUserTrackingModeNone animated:true];
            [self updateLocationIcons];
        }
    }
    else
    {
        if (_locationServicesDisabled)
        {
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:nil message:TGLocalized(@"Map.AccessDeniedError") delegate:nil cancelButtonTitle:TGLocalized(@"Common.OK") otherButtonTitles:nil];
            [alertView show];
        }
        [self updateLocationAvailability];
    }
}

- (void)buttonGroupViewButtonPressed:(TGButtonGroupView *)__unused buttonGroupView index:(int)index
{
    int mapMode = index < 0 || index > 2 ? 0 : index;
    setDefaultMapMode(mapMode);
    [_mapView setMapType:(MKMapType)mapMode];
}

- (void)actionsButtonPressed
{
    _currentActionSheet.delegate = nil;
    
    _currentActionSheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
    [_currentActionSheet addButtonWithTitle:@"Get Directions"];
    [_currentActionSheet addButtonWithTitle:@"Forward via Telegram"];
    
    if (iosMajorVersion() >= 6)
    {
        if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"comgooglemaps://"]])
            [_currentActionSheet addButtonWithTitle:@"Open in Google Maps"];
    }
    
    _currentActionSheet.cancelButtonIndex = [_currentActionSheet addButtonWithTitle:TGLocalized(@"Common.Cancel")];
    [_currentActionSheet showInView:self.view];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    _currentActionSheet.delegate = nil;
    
    if (buttonIndex != actionSheet.cancelButtonIndex)
    {
        if (buttonIndex == 0)
        {
            CLLocation *userLocation = _mapView.userLocation.location;
            NSURL *addressUrl = [[NSURL alloc] initWithString:[[NSString alloc] initWithFormat:@"http://maps.%@.com/?daddr=%f,%f%@", iosMajorVersion() < 6 ? @"google" : @"apple", _mapLocation.coordinate.latitude, _mapLocation.coordinate.longitude, userLocation == nil ? @"" : [[NSString alloc] initWithFormat:@"&saddr=%f,%f", userLocation.coordinate.latitude, userLocation.coordinate.longitude]]];
            
            if ([[UIApplication sharedApplication] respondsToSelector:@selector(openURL:forceNative:)])
                [(id<TGApplicationWithCustomURLHandling>)[UIApplication sharedApplication] openURL:addressUrl forceNative:true];
            else
                [[UIApplication sharedApplication] openURL:addressUrl];
        }
        else if (buttonIndex == 1)
        {
            if (_message != nil)
            {
                [_watcher requestAction:@"mapViewForward" options:@{
                    @"controller": self,
                    @"message": _message
                }];
            }
        }
        else if (buttonIndex == 2)
        {
            CLLocationCoordinate2D centerLocation = _mapView.centerCoordinate;
            CLLocation *userLocation = _mapView.userLocation.location;
            NSURL *addressUrl = [[NSURL alloc] initWithString:[[NSString alloc] initWithFormat:@"comgooglemaps://?center=%f,%f%@", centerLocation.latitude, centerLocation.longitude, (true || userLocation == nil) ? @"" : [[NSString alloc] initWithFormat:@"&saddr=%f,%f", userLocation.coordinate.latitude, userLocation.coordinate.longitude]]];
            
            if ([[UIApplication sharedApplication] respondsToSelector:@selector(openURL:forceNative:)])
                [(id<TGApplicationWithCustomURLHandling>)[UIApplication sharedApplication] openURL:addressUrl forceNative:true];
            else
                [[UIApplication sharedApplication] openURL:addressUrl];
        }
    }
}

#pragma mark -

- (void)updateLocationIcons
{
    bool tracking = _mapView.userTrackingMode != MKUserTrackingModeNone;
    bool trackingHeading = _mapView.userTrackingMode == MKUserTrackingModeFollowWithHeading;
    
    float locationNormalAlpha = tracking ? 0.0f : 1.0f;
    float locationActiveAlpha = tracking && !trackingHeading ? 1.0f : 0.0f;
    float locationActiveHeadingAlpha = tracking && trackingHeading ? 1.0f : 0.0f;
    
    bool animateTransition = (locationActiveHeadingAlpha < FLT_EPSILON) != (_locationActiveHeadingIcon.alpha < FLT_EPSILON);
    
    if (!animateTransition)
    {
        _locationNormalIcon.alpha = locationNormalAlpha;
        _locationActiveIcon.alpha = locationActiveAlpha;
        _locationActiveHeadingIcon.alpha = locationActiveHeadingAlpha;
        
        if (locationActiveHeadingAlpha < FLT_EPSILON)
        {
            _locationNormalIcon.transform = CGAffineTransformIdentity;
            _locationActiveIcon.transform = CGAffineTransformIdentity;
            _locationActiveHeadingIcon.transform = CGAffineTransformMakeScale(0.1f, 0.1f);
        }
        else
        {
            _locationNormalIcon.transform = CGAffineTransformMakeScale(0.1f, 0.1f);
            _locationActiveIcon.transform = CGAffineTransformMakeScale(0.1f, 0.1f);
            _locationActiveHeadingIcon.transform = CGAffineTransformIdentity;
        }
    }
    else
    {
        [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^
        {
            _locationNormalIcon.alpha = locationNormalAlpha;
            _locationActiveIcon.alpha = locationActiveAlpha;
            _locationActiveHeadingIcon.alpha = locationActiveHeadingAlpha;
            
            if (locationActiveHeadingAlpha < FLT_EPSILON)
            {
                _locationNormalIcon.transform = CGAffineTransformIdentity;
                _locationActiveIcon.transform = CGAffineTransformIdentity;
                _locationActiveHeadingIcon.transform = CGAffineTransformMakeScale(0.1f, 0.1f);
            }
            else
            {
                _locationNormalIcon.transform = CGAffineTransformMakeScale(0.1f, 0.1f);
                _locationActiveIcon.transform = CGAffineTransformMakeScale(0.1f, 0.1f);
                _locationActiveHeadingIcon.transform = CGAffineTransformIdentity;
            }
        } completion:nil];
    }
}

- (void)updateLocationAvailability
{
    bool locationAvailable = (_mapView.userLocation != nil && _mapView.userLocation.location != nil) || _locationServicesDisabled;
    
    if (locationAvailable == _locationActivityIndicator.alpha < FLT_EPSILON)
        return;
    
    if (!locationAvailable)
        [_locationActivityIndicator startAnimating];
    
    [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^
    {
        _locationIconsContainer.alpha = locationAvailable ? 1.0f : 0.0f;
        _locationActivityIndicator.alpha = locationAvailable ? 0.0f : 1.0f;
        _locationIconsContainer.transform = locationAvailable ? CGAffineTransformIdentity : CGAffineTransformMakeScale(0.1f, 0.1f);
        _locationActivityIndicator.transform = locationAvailable ? CGAffineTransformMakeScale(0.1f, 0.1f) : CGAffineTransformIdentity;
    } completion:^(BOOL finished)
    {
        if (finished)
        {
            if (locationAvailable)
                [_locationActivityIndicator stopAnimating];
        }
    }];
}

#pragma mark -

- (void)actionStageActionRequested:(NSString *)action options:(id)__unused options
{
    if ([action isEqualToString:@"calloutPressed"])
    {
        TGContactMediaAttachment *contactAttachment = [[TGContactMediaAttachment alloc] init];
        contactAttachment.uid = _user.uid;
        [_watcher requestAction:@"openContact" options:[[NSDictionary alloc] initWithObjectsAndKeys:contactAttachment, @"contactAttachment", nil]];
    }
}

@end
