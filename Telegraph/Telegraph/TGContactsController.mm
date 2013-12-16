#import "TGContactsController.h"

#import "TGTelegraph.h"
#import "TGUser.h"
#import "TGDatabase.h"

#import "TGInterfaceManager.h"
#import "TGInterfaceAssets.h"

#import "TGSynchronizeContactsActor.h"

#import "TGSearchDisplayMixin.h"

#import "TGSelectContactController.h"

#import "TGToolbarButton.h"
#import "TGNavigationBar.h"

#import "ActionStage.h"
#import "SGraphNode.h"
#import "SGraphListNode.h"
#import "SGraphObjectNode.h"

#import "TGMainTabsController.h"

#import "TGContactListRequestBuilder.h"

#import "TGTabControllerChild.h"

#import "TGContactCell.h"

#import "TGImageView.h"

#import "TGHacks.h"
#import "TGSearchBar.h"
#import "TGImageUtils.h"
#import "TGButtonGroupView.h"
#import "TGActionTableView.h"

#import "TGStringUtils.h"

#import "TGTimer.h"

#import "TGLabel.h"

#import "TGAppDelegate.h"

#import <MessageUI/MessageUI.h>
#import <MessageUI/MFMessageComposeViewController.h>

#import <QuartzCore/QuartzCore.h>

#import "TGActivityIndicatorView.h"

#import "TGFlatActionCell.h"

#import "TGAddContactsController.h"

#import "TGTokenFieldView.h"

#import "TGDateUtils.h"

#include <vector>
#include <map>
#include <algorithm>
#include <tr1/memory>
#include <set>

#pragma mark -

static UIImage *sectionBackground()
{
    static UIImage *image = nil;
    if (image == nil)
        image = [UIImage imageNamed:@"CategoryDivider.png"];
    return image;
}

static UIImage *searchBarBackgroundNormal()
{
    static UIImage *image = nil;
    if (image == nil)
        image = [UIImage imageNamed:@"SearchBarBackground.png"];
    return image;
}

static bool TGContactListItemSortByLastNameFunction(const TGUser *item1, const TGUser *item2)
{
    NSString *lastName1 = item1.lastName;
    if (lastName1 == nil || lastName1.length == 0)
        lastName1 = item1.firstName;
    
    NSString *lastName2 = item2.lastName;
    if (lastName2 == nil || lastName2.length == 0)
        lastName2 = item2.firstName;
    
    NSComparisonResult result = [lastName1 caseInsensitiveCompare:lastName2];
    if (result == NSOrderedSame)
    {
        NSString *firstName1 = item1.firstName;
        if (firstName1 == nil || firstName1.length == 0)
            return false;
        
        NSString *firstName2 = item2.firstName;
        if (firstName2 == nil || firstName2.length == 0)
            return false;
        
        result = [firstName1 caseInsensitiveCompare:firstName2];
    }
    
    return result == NSOrderedAscending;
}

static bool TGContactListItemSortByFirstNameFunction(const TGUser *item1, const TGUser *item2)
{
    NSString *firstName1 = item1.firstName;
    if (firstName1 == nil || firstName1.length == 0)
        firstName1 = item1.lastName;
    
    NSString *firstName2 = item2.firstName;
    if (firstName2 == nil || firstName2.length == 0)
        firstName2 = item2.lastName;
    
    NSComparisonResult result = [firstName1 caseInsensitiveCompare:firstName2];
    if (result == NSOrderedSame)
    {
        NSString *lastName1 = item1.lastName;
        if (lastName1 == nil || lastName1.length == 0)
            return false;
        
        NSString *lastName2 = item2.lastName;
        if (lastName2 == nil || lastName2.length == 0)
            return false;
        
        result = [lastName1 caseInsensitiveCompare:lastName2];
    }
    
    return result == NSOrderedAscending;
}

class TGContactListSection
{
public:
    NSString *letter;
    unichar sortLetter;
    
    std::vector<TGUser *> items;
    
public:
    TGContactListSection()
    {
        sortLetter = '#';
        letter = [[NSString alloc] initWithCharacters:&sortLetter length:1];
    }
    
    TGContactListSection & operator= (const TGContactListSection &other)
    {
        if (this != &other)
        {
            letter = other.letter;
            sortLetter = other.sortLetter;
            items = other.items;
        }
        return *this;
    }
    
    virtual ~TGContactListSection()
    {
        letter = nil;
    }
    
    void addItem(TGUser *user)
    {   
        items.push_back(user);
    }
    
    void setSortLetter(unichar _sortLetter)
    {
        if (_sortLetter != sortLetter)
        {
            sortLetter = _sortLetter;
            
            if (sortLetter == ' ')
                letter = @"#";
            else
                letter = [[[NSString alloc] initWithCharacters:&sortLetter length:1] capitalizedString];
            
            sortLetter = [letter characterAtIndex:0];
        }
    }
    
    void sortByFirstName()
    {
        std::sort(items.begin(), items.end(), TGContactListItemSortByFirstNameFunction);
    }
    
    void sortByLastName()
    {
        std::sort(items.begin(), items.end(), TGContactListItemSortByLastNameFunction);
    }
};

@interface TGContactListSectionListHolder : NSObject

@property (nonatomic) std::vector<std::tr1::shared_ptr<TGContactListSection> > sectionList;

@end

@implementation TGContactListSectionListHolder

@synthesize sectionList = _sectionList;

@end

static bool TGContactListSectionComparator(std::tr1::shared_ptr<TGContactListSection> section1, std::tr1::shared_ptr<TGContactListSection> section2)
{
    unichar letter1 = section1->sortLetter;
    unichar letter2 = section2->sortLetter;
    
    if ((letter1 >= '0' && letter1 <= '9') && !(letter2 >= '0' && letter2 <= '9'))
        return false;
    if (!(letter1 >= '0' && letter1 <= '9') && (letter2 >= '0' && letter2 <= '9'))
        return true;
    if (letter1 == '#' && letter2 != '#')
        return false;
    if (letter1 != '#' && letter2 == '#')
        return true;
    
    return letter1 < letter2;
}

#pragma mark -

#pragma mark -

@interface TGContactsController () <TGTabControllerChild, UITableViewDelegate, UITableViewDataSource, UISearchDisplayDelegate, MFMessageComposeViewControllerDelegate, TGTokenFieldViewDelegate, TGSearchDisplayMixinDelegate>
{
    std::vector<std::tr1::shared_ptr<TGContactListSection> > _sectionList;
    
    std::map<int, TGUser *> _selectedUsers;
    
    std::set<int> _disabledUserIds;
}

@property (nonatomic, strong) TGToolbarButton *inviteButton;
@property (nonatomic, strong) UIBarButtonItem *inviteButtonItem;
@property (nonatomic, strong) TGToolbarButton *doneButton;
@property (nonatomic, strong) UIBarButtonItem *doneButtonItem;
@property (nonatomic, strong) TGToolbarButton *addButton;
@property (nonatomic, strong) UIBarButtonItem *addButtonItem;

@property (nonatomic, strong) MFMessageComposeViewController *messageComposer;

@property (nonatomic, strong) TGSearchBar *searchBar;
@property (nonatomic, strong) TGSearchDisplayMixin *searchMixin;
@property (nonatomic, strong) UIButton *selectAllButton;

@property (nonatomic, strong) TGTokenFieldView *tokenFieldView;

@property (nonatomic, strong) NSString *searchString;
@property (nonatomic, strong) NSArray *searchResults;

@property (nonatomic, strong) UIView *searchTableViewBackground;
@property (nonatomic, strong) UITableView *searchTableView;

@property (nonatomic, strong) NSArray *reusableSectionHeaders;

@property (nonatomic, strong) NSArray *sectionIndices;

@property (nonatomic) bool reloadingList;

@property (nonatomic) bool onceLoaded;

@property (nonatomic) bool multipleSelectionEnabled;

@property (nonatomic) bool searchControllerWasActivated;

@property (nonatomic) int currentSortOrder;

@property (nonatomic, strong) NSArray *currentContactList;
@property (nonatomic, strong) NSArray *currentAddressBook;

@property (nonatomic) bool updateContactListSheduled;

@property (nonatomic, strong) NSString *currentSearchPath;

@property (nonatomic) bool appearAnimation;
@property (nonatomic) bool disappearAnimation;

@property (nonatomic) bool selectAllOnce;

@property (nonatomic, strong) UIView *phonebookAccessOverlay;

@end

@implementation TGContactsController

- (id)initWithContactsMode:(int)contactsMode
{
    self = [super initWithNibName:nil bundle:nil];
    if (self)
    {
        self.ignoreKeyboardWhenAdjustingScrollViewInsets = true;
        
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:true];
        
        _contactListVersion = -1;
        _phonebookVersion = -1;
        
        _contactsMode = contactsMode;
        
        _reusableSectionHeaders = [[NSArray alloc] initWithObjects:[[NSMutableArray alloc] init], [[NSMutableArray alloc] init], nil];
        
        [ActionStageInstance() watchForPath:@"/tg/phonebookAccessStatus" watcher:self];
        
        [ActionStageInstance() watchForPath:@"/as/updateRelativeTimestamps" watcher:self];
        
        [ActionStageInstance() watchForPath:@"/tg/userdatachanges" watcher:self];
        [ActionStageInstance() watchForPath:@"/tg/userpresencechanges" watcher:self];
        if ((_contactsMode & TGContactsModeRegistered))
            [ActionStageInstance() watchForPath:@"/tg/contactlist" watcher:self];
        if (_contactsMode & TGContactsModePhonebook)
            [ActionStageInstance() watchForPath:@"/tg/phonebook" watcher:self];
        
        if ((_contactsMode & TGContactsModeInvite) == TGContactsModeInvite)
            _selectAllOnce = true;
        
        if ((_contactsMode & TGContactsModeCompose) == TGContactsModeCompose)
            _multipleSelectionEnabled = true;
    }
    return self;
}

- (void)dealloc
{
    [_actionHandle reset];
    [ActionStageInstance() removeWatcher:self];
    
    _tokenFieldView.delegate = nil;
    
    [self doUnloadView];
}

- (void)setLoginStyle:(bool)loginStyle
{
    _loginStyle = loginStyle;
    self.style = loginStyle ? TGViewControllerStyleBlack : TGViewControllerStyleDefault;
}

- (NSString *)controllerTitle
{
    return _customTitle != nil ? _customTitle : NSLocalizedString(@"Contacts.Title", @"");
}

- (UIBarButtonItem *)controllerRightBarButtonItem
{
    if ((_contactsMode & TGContactsModeMainContacts) == TGContactsModeMainContacts)
    {
        if (_addButtonItem == nil)
        {
            _addButton = [[TGToolbarButton alloc] initWithType:TGToolbarButtonTypeGeneric];
            _addButton.tag = ((int)0x0A214F56);
            _addButton.image = [UIImage imageNamed:@"AddIcon.png"];
            _addButton.imageLandscape = [UIImage imageNamed:@"AddIcon_Landscape.png"];
            _addButton.minWidth = 35;
            [_addButton sizeToFit];
            [_addButton addTarget:self action:@selector(addButtonPressed) forControlEvents:UIControlEventTouchUpInside];
            _addButtonItem = [[UIBarButtonItem alloc] initWithCustomView:_addButton];
            
            if (_phonebookAccessOverlay != nil)
                _addButton.hidden = true;
        }
        
        return _addButtonItem;
    }
    
    if ((_contactsMode & TGContactsModeModalInvite) != TGContactsModeModalInvite)
        return nil;
    
    if (_inviteButtonItem == nil)
    {
        _inviteButton = [[TGToolbarButton alloc] initWithType:TGToolbarButtonTypeDone];
        _inviteButton.text = NSLocalizedString(@"Contacts.Invite", @"");
        _inviteButton.minWidth = 60;
        _inviteButton.paddingLeft = 10;
        _inviteButton.paddingRight = 10;
        [_inviteButton sizeToFit];
        [_inviteButton addTarget:self action:@selector(inviteButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        
        _inviteButtonItem = [[UIBarButtonItem alloc] initWithCustomView:_inviteButton];
        
        dispatch_async(dispatch_get_main_queue(), ^
        {
            if ([self selectedContactsCount] == 0)
            {
                _inviteButton.alpha = 0.0f;
                _inviteButton.hidden = true;
            }
            else
            {
                _inviteButton.alpha = 1.0f;
                _inviteButton.hidden = false;
            }
        });
    }

    return _inviteButtonItem;
}

- (UIBarButtonItem *)controllerLeftBarButtonItem
{
    if ((_contactsMode & TGContactsModeMainContacts) == TGContactsModeMainContacts)
        return nil;
    
    if (((_contactsMode & TGContactsModeInvite) != TGContactsModeInvite && (_contactsMode & TGContactsModeSelectModal) != TGContactsModeSelectModal) || (_contactsMode & TGContactsModeModalInviteWithBack) == TGContactsModeModalInviteWithBack)
        return nil;
    
    if (_doneButtonItem == nil)
    {
        _doneButton = [[TGToolbarButton alloc] initWithType:TGToolbarButtonTypeGeneric];
        _doneButton.text = NSLocalizedString(@"Common.Cancel", @"");
        _doneButton.minWidth = 60;
        [_doneButton sizeToFit];
        [_doneButton addTarget:self action:@selector(doneButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        
        _doneButtonItem = [[UIBarButtonItem alloc] initWithCustomView:_doneButton];
        
        dispatch_async(dispatch_get_main_queue(), ^
        {
            if ([self selectedContactsCount] == 0 && ((_contactsMode & TGContactsModeModalInvite) != TGContactsModeModalInvite &&  (_contactsMode & TGContactsModeSelectModal) != TGContactsModeSelectModal))
            {
                _doneButton.alpha = 0.0f;
                _doneButton.hidden = true;
            }
            else
            {
                _doneButton.alpha = 1.0f;
                _doneButton.hidden = false;
            }
        });
    }

    return _doneButtonItem;
}

- (UIBarStyle)requiredNavigationBarStyle
{
    return UIBarStyleDefault;
}

- (void)scrollToTopRequested
{
    [_tableView setContentOffset:CGPointMake(0, -_tableView.contentInset.top) animated:true];
}

static inline UIImage *buttonStretchableImage(UIImage *image)
{
    return [image stretchableImageWithLeftCapWidth:(int)(image.size.width / 2) topCapHeight:0];
}

- (void)loadView
{
    [super loadView];
    
    CGSize viewSize = self.view.frame.size;
    
    if ((_contactsMode & TGContactsModeModalInvite) == TGContactsModeModalInvite || (_contactsMode & TGContactsModeSelectModal) == TGContactsModeSelectModal)
    {
        self.titleText = [self controllerTitle];
        if ((_contactsMode & TGContactsModeModalInviteWithBack) != TGContactsModeModalInviteWithBack)
            [self.navigationItem setLeftBarButtonItem:[self controllerLeftBarButtonItem] animated:false];
        [self.navigationItem setRightBarButtonItem:[self controllerRightBarButtonItem] animated:false];
    }
    
    if ((_contactsMode & TGContactsModeModalInviteWithBack) == TGContactsModeModalInviteWithBack)
    {
        if (_loginStyle)
        {
            UIImage *imageNormal = [[UIImage imageNamed:@"BackButton_Login.png"] stretchableImageWithLeftCapWidth:15 topCapHeight:0];
            UIImage *imageNormalHighlighted = [[UIImage imageNamed:@"BackButton_Login_Pressed.png"] stretchableImageWithLeftCapWidth:15 topCapHeight:0];
            UIImage *imageLandscape = [[UIImage imageNamed:@"BackButton_Login_Landscape.png"] stretchableImageWithLeftCapWidth:15 topCapHeight:0];
            UIImage *imageLandscapeHighlighted = [[UIImage imageNamed:@"BackButton_Login_Landscape_Pressed.png"] stretchableImageWithLeftCapWidth:15 topCapHeight:0];
            
            [self setBackAction:@selector(modalInviteBackButtonPressed) imageNormal:imageNormal imageNormalHighlighted:imageNormalHighlighted imageLadscape:imageLandscape imageLandscapeHighlighted:imageLandscapeHighlighted textColor:[UIColor whiteColor] shadowColor:UIColorRGBA(0x050608, 0.4f)];
        }
        else
            self.backAction = @selector(modalInviteBackButtonPressed);
    }
    
    if ((_contactsMode & TGContactsModeCompose) == TGContactsModeCompose)
    {
        _tableView = [[TGActionTableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    }
    else
        _tableView = [[TGActionTableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.opaque = true;
    _tableView.layer.backgroundColor = [UIColor whiteColor].CGColor;
    
    if (!(_contactsMode & TGContactsModeSearchDisabled) || (_contactsMode & TGContactsModeCompose) == TGContactsModeCompose)
    {
        UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, -500, _tableView.frame.size.width, 500)];
        headerView.layer.backgroundColor = UIColorRGB(0xe4e9f0).CGColor;
        headerView.opaque = true;
        headerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [_tableView addSubview:headerView];
    }
    
    _tableView.showsVerticalScrollIndicator = true;
    
    if (!(_contactsMode & TGContactsModeSearchDisabled))
    {
        _searchBar = [[TGSearchBar alloc] initWithFrame:CGRectMake(0, 0, viewSize.width, 44)];
        _searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        if ([_searchBar respondsToSelector:@selector(setBackgroundImage:)])
            [_searchBar setBackgroundImage:searchBarBackgroundNormal()];
        _searchBar.placeholder = TGLocalized(@"DialogList.SearchLabel");
        
        for (UIView *subview in [_searchBar subviews])
        {
            if ([subview conformsToProtocol:@protocol(UITextInputTraits)])
            {
                @try
                {
                    [(id<UITextInputTraits>)subview setReturnKeyType:UIReturnKeyDone];
                    [(id<UITextInputTraits>)subview setEnablesReturnKeyAutomatically:true];
                }
                @catch (__unused NSException *e)
                {
                }
            }
        }
        
        _searchMixin = [[TGSearchDisplayMixin alloc] init];
        _searchMixin.delegate = self;
        _searchMixin.searchBar = _searchBar;
        
        /*_searchController.delegate = self;
        _searchController.searchResultsDataSource = self;
        _searchController.searchResultsDelegate = self;*/
        
        if ((_contactsMode & TGContactsModeModalInvite) == TGContactsModeModalInvite)
        {
            UIView *headerContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, _tableView.frame.size.width, 44)];
            headerContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            headerContainer.layer.backgroundColor = UIColorRGB(0xdfe4eb).CGColor;
            
            UIImageView *searchBakground = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, headerContainer.frame.size.width, 44)];
            searchBakground.image = searchBarBackgroundNormal();
            searchBakground.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            [headerContainer addSubview:searchBakground];
            
            _searchBar.frame = CGRectMake(0, 0, headerContainer.frame.size.width, 44);
            _searchBar.searchContentInset = UIEdgeInsetsMake(0, 39, 0, 0);
            [headerContainer addSubview:_searchBar];
            
            _selectAllButton = [[UIButton alloc] initWithFrame:CGRectMake(7, 8, 28, 29)];
            _selectAllButton.exclusiveTouch = true;
            [_selectAllButton addTarget:self action:@selector(selectAllButtonPressed) forControlEvents:UIControlEventTouchUpInside];
            [headerContainer addSubview:_selectAllButton];
            
            _tableView.tableHeaderView = headerContainer;
            
            [self updateSelectionInterface];
            [self updateSelectionControls:false];
        }
        else
        {   
            if ((_contactsMode & TGContactsModeCompose) == TGContactsModeCompose)
                [self updateSelectionControls:false];
            else
                _tableView.tableHeaderView = _searchBar;
        }
    }
    
    _tableView.tableFooterView = [[UIView alloc] init];
    
    if (_searchBar != nil)
    {
        [self clearInputFieldBackground:_searchBar andSetIcon:[[TGInterfaceAssets instance] dialogListSearchIcon]];
        [self hideStripe:_searchBar];
    }
    
    [self.view addSubview:_tableView];
    
    if ((_contactsMode & TGContactsModeCompose) == TGContactsModeCompose)
    {
        _tokenFieldView = [[TGTokenFieldView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 44)];
        _tokenFieldView.frame = CGRectMake(0, [self tokenFieldOffset], self.view.frame.size.width, [_tokenFieldView preferredHeight]);
        _tokenFieldView.delegate = self;
        [self.view addSubview:_tokenFieldView];
        
        _searchTableView = [[UITableView alloc] initWithFrame:_tableView.frame style:UITableViewStylePlain];
        _searchTableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _searchTableView.delegate = self;
        _searchTableView.dataSource = self;
        _searchTableView.rowHeight = 51;
        _searchTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        _searchTableView.opaque = true;
        _searchTableView.layer.backgroundColor = [UIColor whiteColor].CGColor;
        
        _searchTableViewBackground = [[UIView alloc] initWithFrame:_searchTableView.frame];
        _searchTableViewBackground.backgroundColor = [UIColor whiteColor];
        _searchTableViewBackground.autoresizingMask = _searchTableView.autoresizingMask;
        
        self.scrollViewsForAutomaticInsetsAdjustment = [[NSArray alloc] initWithObjects:_searchTableView, nil];
        
        [self updateTableFrame:false collapseSearch:false];
    }
    
    [self updatePhonebookAccess];
    
    if (![self _updateControllerInset:false])
        [self controllerInsetUpdated:UIEdgeInsetsZero];
}

- (void)controllerInsetUpdated:(UIEdgeInsets)previousInset
{
    if (_tokenFieldView != nil)
    {
        CGRect tokenViewFrame = _tokenFieldView.frame;
        tokenViewFrame.origin.y = [self tokenFieldOffset];
        _tokenFieldView.frame = tokenViewFrame;
    }
    
    if (self.navigationBarShouldBeHidden)
    {
        [_tableView setContentOffset:CGPointMake(0, -_tableView.contentInset.top) animated:false];
    }
    
    if (_searchMixin != nil)
        [_searchMixin controllerInsetUpdated:self.controllerInset];
    
    if (_selectAllButton != nil)
    {
        CGRect selectAllFrame = _selectAllButton.frame;
        UIEdgeInsets contentInset = _searchBar.searchContentInset;
        
        if (self.navigationBarShouldBeHidden)
        {
            selectAllFrame.origin.x = -selectAllFrame.size.width - 7;
            contentInset.left = 5;
        }
        else
        {
            selectAllFrame.origin.x = 7;
            contentInset.left = 39;
        }
            
        _selectAllButton.frame = selectAllFrame;
        
        [_searchBar setSearchContentInset:contentInset];
        //[_searchBar layoutSubviews];
    }
    
    [super controllerInsetUpdated:previousInset];
}

- (void)updatePhonebookAccess
{
    if ([TGSynchronizeContactsManager instance].phonebookAccessStatus == TGPhonebookAccessStatusDisabled)
    {
        _phonebookAccessOverlay = [[UIView alloc] initWithFrame:self.view.bounds];
        _phonebookAccessOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _phonebookAccessOverlay.backgroundColor = [[TGInterfaceAssets instance] linesBackground];
        
        UIView *container = [[UIView alloc] initWithFrame:CGRectMake(floorf((_phonebookAccessOverlay.frame.size.width - 40) / 2), floorf((_phonebookAccessOverlay.frame.size.height - 4) / 2), 40, 4)];
        container.tag = 100;
        container.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
        container.clipsToBounds = false;
        [_phonebookAccessOverlay addSubview:container];
        
        UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"ContactsIcon.png"]];
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
        titleLabelView.text = TGLocalized(@"Contacts.AccessDeniedError");
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
        
        [self.view addSubview:_phonebookAccessOverlay];
        
        if ((_contactsMode & TGContactsModeMainContacts) == TGContactsModeMainContacts)
            _addButton.hidden = true;
        
        [self updatePhonebookAccessLayout:self.interfaceOrientation];
    }
}

- (void)updatePhonebookAccessLayout:(UIInterfaceOrientation)orientation
{
    if (_phonebookAccessOverlay != nil)
    {
        UIView *container = [_phonebookAccessOverlay viewWithTag:100];
        UIView *iconView = [_phonebookAccessOverlay viewWithTag:200];
        UIView *titleLabelView = [_phonebookAccessOverlay viewWithTag:300];
        UILabel *subtitleLabelView = (UILabel *)[_phonebookAccessOverlay viewWithTag:400];
        
        bool isPortrait = UIInterfaceOrientationIsPortrait(orientation);
        
        float additionalOffset = isPortrait ? ([TGViewController isWidescreen] ? -20 : -15) : 12;
        
        iconView.frame = CGRectMake(floorf((container.frame.size.width - iconView.frame.size.width) / 2), (isPortrait ? - 113 : -100) + additionalOffset, iconView.frame.size.width, iconView.frame.size.height);
        
        CGSize labelSize = [titleLabelView sizeThatFits:CGSizeMake(265, 1000)];
        titleLabelView.frame = CGRectMake(floorf((container.frame.size.width - labelSize.width) / 2), -10 + additionalOffset, labelSize.width, labelSize.height);
        
        NSString *model = @"iPhone";
        NSString *rawModel = [[[UIDevice currentDevice] model] lowercaseString];
        if ([rawModel rangeOfString:@"ipod"].location != NSNotFound)
            model = @"iPod";
        else if ([rawModel rangeOfString:@"ipad"].location != NSNotFound)
            model = @"iPad";
        
        NSString *rawText = UIInterfaceOrientationIsLandscape(orientation) ? [[NSString alloc] initWithFormat:TGLocalized(@"Contacts.AccessDeniedHelpLandscape"), model] : [[NSString alloc] initWithFormat:TGLocalized(@"Contacts.AccessDeniedHelpPortrait"), model];
        
        if ([UILabel instancesRespondToSelector:@selector(setAttributedText:)])
        {
            UIColor *foregroundColor = UIColorRGB(0x697487);
            
            NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:[UIFont systemFontOfSize:TGIsRetina() ? 14.5f : 15.0f], NSFontAttributeName, foregroundColor, NSForegroundColorAttributeName, nil];
            NSDictionary *subAttrs = [NSDictionary dictionaryWithObjectsAndKeys:[UIFont boldSystemFontOfSize:TGIsRetina() ? 14.5f : 15.0f], NSFontAttributeName, nil];
            const NSRange range = [rawText rangeOfString:TGLocalized(@"Contacts.AccessDeniedHelpON")];
            
            NSMutableAttributedString *attributedText = [[NSMutableAttributedString alloc] initWithString:rawText attributes:attrs];
            [attributedText setAttributes:subAttrs range:range];
            
            [subtitleLabelView setAttributedText:attributedText];
        }
        else
            subtitleLabelView.text = rawText;
        
        CGSize subtitleLabelSize = [subtitleLabelView sizeThatFits:CGSizeMake(isPortrait ? 210 : 480, 1000)];
        subtitleLabelView.frame = CGRectMake(floorf((container.frame.size.width - subtitleLabelSize.width) / 2), 41 + additionalOffset, subtitleLabelSize.width, subtitleLabelSize.height);
    }
}

- (void)updateTableFrame:(bool)animated collapseSearch:(bool)collapseSearch
{
    float tableY = 0;
    UIEdgeInsets tableInset = UIEdgeInsetsZero;

    tableY = 0;
    tableInset = UIEdgeInsetsMake(_tokenFieldView.frame.size.height, 0, 0, 0);
    
    CGRect tableFrame = CGRectMake(0, tableY, self.view.frame.size.width, self.view.frame.size.height);
    
    CGRect searchTableFrame = tableFrame;
    
    if (collapseSearch)
    {
        searchTableFrame.size.height = tableInset.top;
    }
    
    dispatch_block_t block = ^
    {
        UIEdgeInsets controllerCleanInset = self.controllerCleanInset;
        
        UIEdgeInsets compareTableInset = UIEdgeInsetsMake(tableInset.top + controllerCleanInset.top, tableInset.left + controllerCleanInset.left, tableInset.bottom + controllerCleanInset.bottom, tableInset.right + controllerCleanInset.right);
        
        if (!UIEdgeInsetsEqualToEdgeInsets(compareTableInset, _tableView.contentInset))
        {
            [self setExplicitTableInset:tableInset scrollIndicatorInset:tableInset];
        }
        
        if (!CGRectEqualToRect(tableFrame, _tableView.frame))
        {
            _tableView.frame = tableFrame;
        }
        
        if (!CGRectEqualToRect(searchTableFrame, _searchTableView.frame))
        {
            _searchTableView.frame = searchTableFrame;
            _searchTableViewBackground.frame = searchTableFrame;
        }
    };
    
    if (animated)
    {
        [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^
        {
            block();
        } completion:nil];
    }
    else
    {
        block();
    }
}

- (void)doUnloadView
{
    _tableView.dataSource = nil;
    _tableView.delegate = nil;
    _tableView = nil;
    
    _searchMixin.delegate = nil;
    [_searchMixin unload];
    _searchMixin = nil;
    
    _inviteButtonItem = nil;
    _inviteButton = nil;
    _doneButtonItem = nil;
    _doneButton = nil;
}

- (void)clearData
{
    [TGContactListRequestBuilder clearCache];
    
    _sectionList.clear();
    //_sectionHeaders = nil;
    [_tableView reloadData];
    
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        _contactListVersion = -1;
    }];
}

- (void)clearInputFieldBackground:(UIView *)view andSetIcon:(UIImage *)icon
{
    if ([view isKindOfClass:[UITextField class]])
    {
        UITextField *textField = (UITextField *)view;
        [textField setBackground:nil];
        textField.clipsToBounds = false;
        
        [TGHacks setTextFieldPlaceholderColor:textField color:UIColorRGB(0x8d9298)];
        if (TGIsRetina())
            [TGHacks setTextFieldClearOffset:textField offset:0.5f];
        
        SEL clearButtonSelector = NSSelectorFromString([[NSString alloc] initWithFormat:@"%sBu%s", "clear", "tton"]);
        if ([textField respondsToSelector:clearButtonSelector])
        {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            UIButton *clearButton = [textField performSelector:clearButtonSelector];
#pragma clang diagnostic pop
            [clearButton setImage:[UIImage imageNamed:@"ClearInput.png"] forState:UIControlStateNormal];
            [clearButton setImage:[UIImage imageNamed:@"ClearInput_Pressed.png"] forState:UIControlStateHighlighted];
        }
        
        UIImage *inputImage = [UIImage imageNamed:@"SearchInputField.png"];
        inputImage = [inputImage stretchableImageWithLeftCapWidth:(int)(inputImage.size.width / 2) topCapHeight:0];
        UIImageView *inputImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, TGIsRetina() ? 0.5 : 0, textField.frame.size.width, inputImage.size.height)];
        inputImageView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        inputImageView.image = inputImage;
        [textField addSubview:inputImageView];
        
        UIImageView *iconView = (UIImageView *)[textField leftView];
        if ([iconView isKindOfClass:[UIImageView class]] && icon != nil)
        {
            iconView.image = icon;
            [iconView sizeToFit];
        }
    }
    for (UIView *child in view.subviews)
        [self clearInputFieldBackground:child andSetIcon:icon];
}

- (void)hideStripe:(UIView *)view
{
    if ([view isKindOfClass:[UIImageView class]] && view.frame.size.height == 1)
        view.hidden = true;
    for (UIView *child in view.subviews)
        [self hideStripe:child];
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

- (void)viewWillAppear:(BOOL)animated
{
    _appearAnimation = true;
    
    if (!_onceLoaded)
    {
        NSDictionary *cachedContacts = nil;
        NSDictionary *cachedPhonebook = nil;

        if (_contactsMode & TGContactsModeRegistered)
        {
            cachedContacts = [TGContactListRequestBuilder synchronousContactList];
            cachedPhonebook = [TGContactListRequestBuilder cachedPhonebook];
        }
        else if (_contactsMode & TGContactsModePhonebook)
            cachedPhonebook = [TGContactListRequestBuilder cachedPhonebook];

        if (((_contactsMode & TGContactsModeRegistered) || (_contactsMode & TGContactsModePhonebook)) && cachedContacts != nil && cachedPhonebook != nil)
        {   
            _contactListVersion = [[cachedContacts objectForKey:@"version"] intValue];
            _currentContactList = [cachedContacts objectForKey:@"contacts"];
            
            _phonebookVersion = [[cachedPhonebook objectForKey:@"version"] intValue];
            _currentAddressBook = [cachedPhonebook objectForKey:@"phonebook"];
            
            [self updateContactList];
        }
        else if ((_contactsMode & TGContactsModeInvite) == TGContactsModeInvite && cachedPhonebook != nil)
        {
            _phonebookVersion = [[cachedPhonebook objectForKey:@"version"] intValue];
            _currentAddressBook = [cachedPhonebook objectForKey:@"phonebook"];
            
            [self updateContactList];
        }
        else
        {
            if (_contactsMode & TGContactsModeRegistered)
            {
                if (cachedContacts == nil)
                    [ActionStageInstance() requestActor:@"/tg/contactlist/(contacts)" options:nil watcher:self];
                else
                    [self actorCompleted:ASStatusSuccess path:@"/tg/contactlist/(contacts)" result:[[SGraphObjectNode alloc] initWithObject:cachedContacts]];
            }
            
            if (_contactsMode & TGContactsModePhonebook)
                [ActionStageInstance() requestActor:@"/tg/contactlist/(phonebook)" options:nil watcher:self];
        }
        
        _onceLoaded = true;
    }
    
    if ([_tableView indexPathForSelectedRow] != nil)
    {
        if (cpuCoreCount() > 2)
        {
            [_tableView deselectRowAtIndexPath:[_tableView indexPathForSelectedRow] animated:true];
        }
        else if (cpuCoreCount() > 1)
        {
            double delayInSeconds = 0.05;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void)
            {
                [_tableView deselectRowAtIndexPath:[_tableView indexPathForSelectedRow] animated:true];
            });
        }
        else
        {
            double delayInSeconds = 0.1;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void)
            {
                [_tableView deselectRowAtIndexPath:[_tableView indexPathForSelectedRow] animated:true];
            });
        }
    }
    
    if (_searchMixin.isActive)
    {
        UITableView *searchTableView = _searchMixin.searchResultsTableView;
        
        if ([searchTableView indexPathForSelectedRow] != nil)
        {
            if (cpuCoreCount() > 2)
            {
                [searchTableView deselectRowAtIndexPath:[searchTableView indexPathForSelectedRow] animated:true];
            }
            else if (cpuCoreCount() > 1)
            {
                double delayInSeconds = 0.05;
                dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
                dispatch_after(popTime, dispatch_get_main_queue(), ^
                {
                    [searchTableView deselectRowAtIndexPath:[searchTableView indexPathForSelectedRow] animated:true];
                });
            }
            else
            {
                double delayInSeconds = 0.1;
                dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
                dispatch_after(popTime, dispatch_get_main_queue(), ^
                {
                    [searchTableView deselectRowAtIndexPath:[searchTableView indexPathForSelectedRow] animated:true];
                });
            }
        }
    }
    
    if ((_contactsMode & TGContactsModeCompose) == TGContactsModeCompose)
    {   
        _tokenFieldView.frame = CGRectMake(0, [self tokenFieldOffset], self.view.frame.size.width, [_tokenFieldView preferredHeight]);
        [_tokenFieldView layoutSubviews];
        _tokenFieldView.frame = CGRectMake(0, [self tokenFieldOffset] + ([_tokenFieldView searchIsActive] ? (44 - [_tokenFieldView preferredHeight]) : 0), self.view.frame.size.width, [_tokenFieldView preferredHeight]);
        [self updateTableFrame:false collapseSearch:false];
    }
    
    [super viewWillAppear:animated];
    
    [self updatePhonebookAccessLayout:self.interfaceOrientation];
}

- (void)viewWillDisappear:(BOOL)animated
{
    _disappearAnimation = true;
    
    [super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
    _disappearAnimation = false;
    
    [super viewDidDisappear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    _appearAnimation = false;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        TGDispatchAfter(0.5, dispatch_get_main_queue(), ^
        {
            [TGDatabaseInstance() buildTransliterationCache];
        });
    });
    
    [super viewDidAppear:animated];
}

- (void)tokenFieldView:(TGTokenFieldView *)tokenFieldView didChangeHeight:(float)height
{
    if (tokenFieldView == _tokenFieldView)
    {
        bool animated = true;
        
        CGRect tokenFieldFrame = CGRectMake(0, [self tokenFieldOffset], _tokenFieldView.frame.size.width, height);
        
        if (animated)
        {
            [UIView animateWithDuration:0.2 animations:^
            {
                _tokenFieldView.frame = tokenFieldFrame;
                [_tokenFieldView scrollToTextField:false];
            }];
        }
        else
        {
            _tokenFieldView.frame = tokenFieldFrame;
            [_tokenFieldView scrollToTextField:false];
        }
        
        [self updateTableFrame:animated collapseSearch:false];
    }
}

- (void)tokenFieldView:(TGTokenFieldView *)tokenFieldView didChangeText:(NSString *)text
{
    if (tokenFieldView == _tokenFieldView)
    {
        [self beginSearch:text];
    }
}

- (void)tokenFieldView:(TGTokenFieldView *)tokenFieldView didChangeSearchStatus:(bool)searchIsActive byClearingTextField:(bool)byClearingTextField
{
    if (tokenFieldView == _tokenFieldView)
    {
        CGRect tokenFieldFrame = _tokenFieldView.frame;
        
        bool animated = true;
        
        bool collapseSearchTable = false;
        
        if (!searchIsActive)
        {
            if (!byClearingTextField)
            {
                [UIView animateWithDuration:0.1 animations:^
                {
                    _searchTableView.alpha = 0.0f;
                } completion:^(BOOL finished)
                {
                    if (finished)
                    {
                        [UIView animateWithDuration:0.1 animations:^
                        {
                            _searchTableViewBackground.alpha = 0.0f;
                        } completion:^(BOOL finished)
                        {
                            if (finished)
                            {
                                [_searchTableView removeFromSuperview];
                                [_searchTableViewBackground removeFromSuperview];
                                _searchResults = nil;
                                [_searchTableView reloadData];
                            }
                        }];
                    }
                }];
            }
            else
            {
                _searchTableView.alpha = 0.0f;
                _searchTableViewBackground.alpha = 0.0f;
                [_searchTableView removeFromSuperview];
                [_searchTableViewBackground removeFromSuperview];
            }
            
            _tokenFieldView.scrollView.scrollEnabled = true;
            tokenFieldFrame.origin.y = [self tokenFieldOffset];
        }
        else
        {
            if (_searchTableView.superview == nil)
                [self.view insertSubview:_searchTableView aboveSubview:_tableView];
            if (_searchTableViewBackground.superview == nil)
                [self.view insertSubview:_searchTableViewBackground belowSubview:_searchTableView];
            
            _searchTableView.frame = _tableView.frame;
            _searchTableViewBackground.frame = _tableView.frame;
            
            _searchTableView.alpha = 1.0f;
            _searchTableViewBackground.alpha = 1.0f;
            
            _tokenFieldView.scrollView.scrollEnabled = false;
            tokenFieldFrame.origin.y = [self tokenFieldOffset] + 44 - tokenFieldFrame.size.height;
        }
        
        if (!CGRectEqualToRect(tokenFieldFrame, _tokenFieldView.frame))
        {
            if (animated)
            {
                [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^
                {
                    _tokenFieldView.frame = tokenFieldFrame;
                } completion:nil];
            }
            else
                _tokenFieldView.frame = tokenFieldFrame;
        }
        
        [self updateTableFrame:animated collapseSearch:collapseSearchTable];
    }
}

- (void)tokenFieldView:(TGTokenFieldView *)tokenFieldView didDeleteTokenWithId:(id)tokenId
{
    if (tokenFieldView == _tokenFieldView)
    {
        if ([tokenId isKindOfClass:[NSNumber class]])
        {
            std::map<int, TGUser *>::iterator it = _selectedUsers.find([tokenId intValue]);
            if (it != _selectedUsers.end())
            {
                [self setUsersSelected:[[NSArray alloc] initWithObjects:it->second, nil] selected:[[NSArray alloc] initWithObjects:[[NSNumber alloc] initWithBool:false], nil] callback:true];
            }
        }
    }
}

- (float)tokenFieldOffset
{
    float tokenFieldY = 0;
    tokenFieldY = self.controllerCleanInset.top;
    
    return tokenFieldY;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    
    CGSize screenSize = [TGViewController screenSizeForInterfaceOrientation:toInterfaceOrientation];
    
    if ((_contactsMode & TGContactsModeCompose) == TGContactsModeCompose)
    {    
        [_tokenFieldView beginTransition:duration];
        
        _tokenFieldView.frame = CGRectMake(0, [self tokenFieldOffset], screenSize.width, [_tokenFieldView preferredHeight]);
        [UIView setAnimationsEnabled:false];
        [_tokenFieldView layoutSubviews];
        [UIView setAnimationsEnabled:true];
        _tokenFieldView.frame = CGRectMake(0, [self tokenFieldOffset] + ([_tokenFieldView searchIsActive] ? (44 - [_tokenFieldView preferredHeight]) : 0), screenSize.width, [_tokenFieldView preferredHeight]);
        [self updateTableFrame:false collapseSearch:false];
    }
    
    [self updatePhonebookAccessLayout:toInterfaceOrientation];
}

- (void)updateSelectionInterface
{
    UIImage *selectAllButtonImage = nil;
    UIImage *selectAllButtonHighlightedImage = nil;
    
    int selectedCount = [self selectedContactsCount];
    if (selectedCount == 0)
    {
        selectAllButtonImage = [UIImage imageNamed:@"SelAll_None.png"];
        selectAllButtonHighlightedImage = [UIImage imageNamed:@"SelAll_None_Highlighted.png"];
    }
    else if (selectedCount == [self contactsCount])
    {
        selectAllButtonImage = [UIImage imageNamed:@"SelAll_All.png"];
        selectAllButtonHighlightedImage = [UIImage imageNamed:@"SelAll_All_Highlighted.png"];
    }
    else
    {
        selectAllButtonImage = [UIImage imageNamed:@"SelAll_Mid.png"];
        selectAllButtonHighlightedImage = [UIImage imageNamed:@"SelAll_Mid_Highlighted.png"];
    }
    
    [_selectAllButton setBackgroundImage:selectAllButtonImage forState:UIControlStateNormal];
    [_selectAllButton setBackgroundImage:selectAllButtonHighlightedImage forState:UIControlStateHighlighted];
}

- (void)updateSelectionControls:(bool)animated
{
    for (UITableViewCell *cell in _tableView.visibleCells)
    {
        if ([cell isKindOfClass:[TGContactCell class]])
        {
            adjustCellForSelectionEnabled((TGContactCell *)cell, _multipleSelectionEnabled, animated);
        }
    }
    
    if ([_tableView indexPathForSelectedRow] != nil)
        [_tableView deselectRowAtIndexPath:[_tableView indexPathForSelectedRow] animated:false];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if (tableView == _tableView)
    {
        return _sectionList.size();
    }
    else
        return 1;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    if (tableView == _tableView)
    {
        if (section >= 0 && section < (int)_sectionList.size() && _sectionList[section]->letter != nil)
        {
            return [self generateSectionHeader:_sectionList[section]->letter first:section == 0 && (!(_contactsMode & TGContactsModeSearchDisabled) || (_contactsMode & TGContactsModeCompose) == TGContactsModeCompose)];
        }
    }
    
    return nil;
}

- (UIView *)generateSectionHeader:(NSString *)title first:(bool)first
{
    UIView *sectionContainer = nil;
    
    NSMutableArray *reusableList = [_reusableSectionHeaders objectAtIndex:first ? 0 : 1];
    
    for (UIView *view in reusableList)
    {
        if (view.superview == nil)
        {
            sectionContainer = view;
            break;
        }
    }
    
    if (sectionContainer == nil)
    {
        sectionContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
        
        sectionContainer.clipsToBounds = false;
        sectionContainer.opaque = false;
        
        UIImageView *sectionView = [[UIImageView alloc] initWithFrame:CGRectMake(0, -1, 10, 11)];
        sectionView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        sectionView.image = first ? [UIImage imageNamed:@"CategoryDividerFirst.png"] : sectionBackground();
        [sectionContainer addSubview:sectionView];
        
        UILabel *sectionLabel = [[UILabel alloc] init];
        sectionLabel.tag = 100;
        sectionLabel.font = [UIFont boldSystemFontOfSize:15];
        sectionLabel.backgroundColor = [UIColor clearColor];
        sectionLabel.textColor = [UIColor whiteColor];
        sectionLabel.shadowColor = UIColorRGB(0x88929c);
        sectionLabel.shadowOffset = CGSizeMake(0, -1);
        sectionLabel.numberOfLines = 1;
        
        sectionLabel.text = title;
        [sectionLabel sizeToFit];
        sectionLabel.frame = CGRectOffset(sectionLabel.frame, 10, 1);
        
        [sectionContainer addSubview:sectionLabel];
        
        [reusableList addObject:sectionContainer];
    }
    else
    {
        UILabel *sectionLabel = (UILabel *)[sectionContainer viewWithTag:100];
        sectionLabel.text = title;
        [sectionLabel sizeToFit];
    }
    
    return sectionContainer;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if (tableView == _tableView)
    {
        if (section >= 0 && section < (int)_sectionList.size() && _sectionList[section]->letter != nil)
        {
            return 25;
        }
    }
    
    return 0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (tableView == _tableView)
    {
        if ((((_contactsMode & TGContactsModeMainContacts) == TGContactsModeMainContacts) || ((_contactsMode & TGContactsModeCreateGroupOption) == TGContactsModeCreateGroupOption)) && indexPath.section == 0)
            return 44;
        
        if ((_contactsMode & TGContactsModeInvite) == TGContactsModeInvite)
            return 51;
        
        TGUser *user = _sectionList[indexPath.section]->items[indexPath.row];
        return user.uid > 0 ? 51 : 44;
    }
    return 51;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (tableView == _tableView)
    {
        if (section >= 0 && section < (int)_sectionList.size())
            return (int)(_sectionList[section]->items.size());
    }
    else
    {
        return _searchResults.count;
    }
    
    return 0;
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView
{
    if (_sectionIndices != nil && _sectionIndices.count != 0)
    {   
        if (tableView == _tableView)
            return _sectionIndices;
    }
    
    return nil;
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index
{
    if (tableView == _tableView)
    {
        if (index == 0)
        {
            [_tableView setContentOffset:CGPointMake(0, -_tableView.contentInset.top) animated:false];
            return -1;
        }
        else
        {
            int sectionIndex = [_sectionIndices indexOfObject:title];
            if (sectionIndex != NSNotFound)
            {
                return MAX(sectionIndex - ((_contactsMode & TGContactsModeSearchDisabled) == TGContactsModeSearchDisabled ? 0 : 1), 0);
            }
        }
    }
    
    return -1;
}

static void adjustCellForSelectionEnabled(TGContactCell *contactCell, bool selectionEnabled, bool animated)
{
    UITableViewCellSelectionStyle selectionStyle = selectionEnabled ? UITableViewCellSelectionStyleNone : UITableViewCellSelectionStyleBlue;
    if (contactCell.isDisabled)
        selectionStyle = UITableViewCellSelectionStyleNone;
    
    if (contactCell.selectionStyle != selectionStyle)
        contactCell.selectionStyle = selectionStyle;
    
    [contactCell setSelectionEnabled:selectionEnabled animated:animated];
}

static void adjustCellForUser(TGContactCell *contactCell, TGUser *user, int currentSortOrder, bool animated, std::map<int, TGUser *> const &selectedUsers, __unused bool showMessageBadge, bool isDisabled)
{
    contactCell.hideAvatar = user.uid <= 0;
    contactCell.itemId = user.uid;
    contactCell.user = user;
    
    contactCell.avatarUrl = user.photoUrlSmall;
    if (currentSortOrder & TGContactListSortOrderDisplayFirstFirst)
    {
        if (user.firstName.length == 0)
        {
            contactCell.titleTextFirst = user.lastName;
            contactCell.titleTextSecond = nil;
        }
        else
        {
            contactCell.titleTextFirst = user.firstName;
            contactCell.titleTextSecond = user.lastName;
        }
        
        if (currentSortOrder & TGContactListSortOrderFirst)
            [contactCell setBoldMode:1];
        else
            [contactCell setBoldMode:2];
    }
    else
    {
        if (user.lastName.length == 0)
        {
            contactCell.titleTextSecond = user.firstName;
            contactCell.titleTextSecond = nil;
        }
        else
        {
            contactCell.titleTextFirst = user.lastName;
            contactCell.titleTextSecond = user.firstName;
        }
        
        if (currentSortOrder & TGContactListSortOrderFirst)
            [contactCell setBoldMode:2];
        else
            [contactCell setBoldMode:1];
    }
    
    bool subtitleActive = false;
    contactCell.subtitleText = subtitleStringForUser(user, subtitleActive);
    contactCell.subtitleActive = subtitleActive;
    
    [contactCell updateFlags:selectedUsers.find(contactCell.itemId) != selectedUsers.end() animated:false force:true];
    contactCell.isDisabled = isDisabled;
    [contactCell resetView:animated];
}

static inline NSString *subtitleStringForUser(TGUser *user, bool &subtitleActive)
{
    NSString *subtitleText = @"";
    bool localSubtitleActive = false;
    
    if (user.uid > 0)
    {
        int lastSeen = user.presence.lastSeen;
        if (user.presence.online)
        {
            subtitleText = TGLocalizedStatic(@"Presence.online");
            localSubtitleActive = true;
        }
        else if (lastSeen == 0)
            subtitleText = TGLocalizedStatic(@"Presence.offline");
        else if (lastSeen < 0)
            subtitleText = TGLocalizedStatic(@"Presence.invisible");
        else
        {
            subtitleText = [[NSString alloc] initWithFormat:@"%@ %@", TGLocalizedStatic(@"Presence.lastSeen"), [TGDateUtils stringForRelativeLastSeen:lastSeen]];
        }
    }
    else
    {
        subtitleText = [user.customProperties objectForKey:@"label"];
    }
    
    subtitleActive = localSubtitleActive;
    
    return subtitleText;
}

- (void)updateRelativeTimestamps
{
    for (id cell in _tableView.visibleCells)
    {
        if ([cell isKindOfClass:[TGContactCell class]])
        {
            TGContactCell *contactCell = cell;
            
            bool subtitleActive = false;
            NSString *subtitleText = subtitleStringForUser(contactCell.user, subtitleActive);
            if (subtitleActive != contactCell.subtitleActive || ![contactCell.subtitleText isEqualToString:subtitleText])
            {
                contactCell.subtitleText = subtitleText;
                contactCell.subtitleActive = subtitleActive;
                
                [contactCell resetView:true];
            }
        }
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    //TGLog(@"Cell for row");
    
    TGUser *user = nil;
    
    if (tableView == _tableView)
    {
        if (indexPath.section >= 0 && indexPath.section < (int)_sectionList.size())
        {
            if (indexPath.row >= 0 && indexPath.row < (int)(_sectionList[indexPath.section]->items.size()))
            {
                user = _sectionList[indexPath.section]->items.at(indexPath.row);
            }
        }
    }
    else
    {
        if (indexPath.row < (int)_searchResults.count)
            user = [_searchResults objectAtIndex:indexPath.row];
    }
    
    if (user != nil && user.uid == INT_MAX)
    {
        static NSString *actionCellIdentifier = @"AC";
        TGFlatActionCell *actionCell = (TGFlatActionCell *)[_tableView dequeueReusableCellWithIdentifier:actionCellIdentifier];
        if (actionCell == nil)
        {
            actionCell = [[TGFlatActionCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:actionCellIdentifier];
        }

        [actionCell setMode:(_contactsMode & TGContactsModeCreateGroupOption) == TGContactsModeCreateGroupOption ? TGFlatActionCellModeCreateGroup : TGFlatActionCellModeInvite];
        
        return actionCell;
    }
    if (user != nil && user.uid == INT_MAX - 1)
    {
        static NSString *actionCellIdentifier = @"AC";
        TGFlatActionCell *actionCell = (TGFlatActionCell *)[_tableView dequeueReusableCellWithIdentifier:actionCellIdentifier];
        if (actionCell == nil)
        {
            actionCell = [[TGFlatActionCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:actionCellIdentifier];
        }
        
        if ((_contactsMode & TGContactsModeCreateGroupOption) == TGContactsModeCreateGroupOption)
            [actionCell setMode:TGFlatActionCellModeCreateEncrypted];
        else
            [actionCell setMode:TGFlatActionCellModeCreateGroupContacts];
        
        return actionCell;
    }
    else if (user != nil)
    {
        static NSString *contactCellIdentifier = @"ContactCell";
        TGContactCell *contactCell = [tableView dequeueReusableCellWithIdentifier:contactCellIdentifier];
        if (contactCell == nil)
        {
            contactCell = [[TGContactCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:contactCellIdentifier selectionControls:((_contactsMode & TGContactsModeCompose) == TGContactsModeCompose) || ((_contactsMode & TGContactsModeInvite) == TGContactsModeInvite) editingControls:false];
            
            contactCell.actionHandle = _actionHandle;
        }
        
        bool cellSelectionEnabled = _multipleSelectionEnabled;
        if (((_contactsMode & TGContactsModePhonebook) && user.uid < 0) || ((_contactsMode & TGContactsModeCompose) == TGContactsModeCompose))
        {
            if ((_contactsMode & TGContactsModeInvite) == TGContactsModeInvite)
                cellSelectionEnabled = true;
            
            std::map<int, TGUser *>::iterator it = _selectedUsers.find(user.uid);
            if (it != _selectedUsers.end())
                contactCell.contactSelected = true;
            else
                contactCell.contactSelected = false;
        }
        else
            contactCell.contactSelected = false;
        
        adjustCellForSelectionEnabled(contactCell, cellSelectionEnabled, false);
        
        adjustCellForUser(contactCell, user, _currentSortOrder, false, _selectedUsers, (_contactsMode & TGContactsModeMainContacts) == TGContactsModeMainContacts, _disabledUserIds.find(user.uid) != _disabledUserIds.end());
        
        //TGLog(@"Initializing cell");
        
        return contactCell;
    }
    
    static NSString *LoadingCellIdentifier = @"LoadingCell";
    UITableViewCell *loadingCell = [tableView dequeueReusableCellWithIdentifier:LoadingCellIdentifier];
    if (loadingCell == nil)
    {
        loadingCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:LoadingCellIdentifier];
        loadingCell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    return loadingCell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ((_contactsMode & TGContactsModeCompose) == TGContactsModeCompose && _multipleSelectionEnabled)
        return;
    
    TGUser *user = nil;

    if (tableView == _tableView)
    {
        if (indexPath.section >= 0 && indexPath.section < (int)_sectionList.size())
        {
            if (indexPath.row >= 0 && indexPath.row < (int)(_sectionList[indexPath.section]->items.size()))
            {
                user = _sectionList[indexPath.section]->items.at(indexPath.row);
            }
        }
    }
    else
    {
        if (indexPath.row < (int)_searchResults.count)
            user = [_searchResults objectAtIndex:indexPath.row];
    }
    
    if (user != nil && user.uid == INT_MAX)
    {
        if (indexPath.row == 0)
        {
            [self actionItemSelected];
        }
    }
    else if (user != nil && user.uid == INT_MAX - 1)
    {
        if (indexPath.row == 1)
        {
            [self encryptionItemSelected];
        }
    }
    else if (user != nil)
    {
        if (_disabledUserIds.find(user.uid) == _disabledUserIds.end())
        {
            if (user.uid > 0 || (_contactsMode & TGContactsModeSelectModal) == TGContactsModeSelectModal)
                [self singleUserSelected:user];
            else if ((_contactsMode & TGContactsModePhonebook) == TGContactsModePhonebook)
                [self singleUserSelected:user];
        }
        
        if ((_contactsMode & TGContactsModeClearSelectionImmediately) == TGContactsModeClearSelectionImmediately)
            [tableView deselectRowAtIndexPath:indexPath animated:true];
    }
    else
    {
        [tableView deselectRowAtIndexPath:indexPath animated:true];
    }
}

- (void)actionItemSelected
{
    [self inviteInlineButtonPressed];
}

- (void)encryptionItemSelected
{
    if ((_contactsMode & TGContactsModeCreateGroupOption) != TGContactsModeCreateGroupOption)
    {
        TGSelectContactController *createGroupController = [[TGSelectContactController alloc] initWithCreateGroup:true createEncrypted:false];
        [self.navigationController pushViewController:createGroupController animated:true];
    }
}

- (void)singleUserSelected:(TGUser *)user
{
    if (user.uid > 0)
    {
        [[TGInterfaceManager instance] navigateToConversationWithId:user.uid conversation:nil forwardMessages:nil atMessageId:0 clearStack:true openKeyboard:(_contactsMode & TGContactsModeCreateGroupOption) animated:true];
    }
    else
    {
        TGPhonebookContact *phonebookContact = [TGDatabaseInstance() phonebookContactByNativeId:-user.uid];
        if (phonebookContact != nil)
        {
            TGProfileController *profileController = [[TGProfileController alloc] initWithPhonebookContact:phonebookContact];
            [self.navigationController pushViewController:profileController animated:true];
        }
    }
}

- (void)contactActionButtonPressed:(TGUser *)__unused user
{
}

- (void)deleteUserFromList:(int)uid
{
    int sectionIndex = -1;
    for (std::vector<std::tr1::shared_ptr<TGContactListSection> >::iterator section = _sectionList.begin(); section != _sectionList.end(); section++)
    {
        sectionIndex++;
        
        int itemIndex = -1;
        for (std::vector<TGUser *>::iterator item = (*section)->items.begin(); item != (*section)->items.end(); item++)
        {
            itemIndex++;
            
            if ((*item).uid == uid)
            {
                (*section)->items.erase(item);
                bool deleteSection = (*section)->items.empty();
                if (deleteSection)
                    _sectionList.erase(section);
                
                [_tableView beginUpdates];
                if (deleteSection)
                    [_tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
                else
                    [_tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:itemIndex inSection:sectionIndex]] withRowAnimation:UITableViewRowAnimationFade];
                [_tableView endUpdates];
                
                return;
            }
        }
    }
}

#pragma mark -

- (UITableView *)createTableViewForSearchMixin:(TGSearchDisplayMixin *)__unused searchMixin
{
    UITableView *tableView = [[UITableView alloc] init];
    
    tableView.backgroundColor = [UIColor whiteColor];
    tableView.dataSource = self;
    tableView.delegate = self;

    tableView.tableFooterView = [[UIView alloc] init];
    
    tableView.rowHeight = 51;
    tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    
    return tableView;
}

- (UIView *)referenceViewForSearchResults
{
    return _tableView;
}

- (void)searchMixinWillActivate:(bool)animated
{
    _tableView.scrollEnabled = false;
    
    UIView *indexView = [_tableView valueForKey:TGEncodeText(@"`joefy", -1)];
    
    [UIView animateWithDuration:0.15f animations:^
    {
        indexView.alpha = 0.0f;
    }];
    
    [self setNavigationBarHidden:true animated:animated];
}

- (void)searchMixinWillDeactivate:(bool)animated
{
    _tableView.scrollEnabled = true;
    
    UIView *indexView = [_tableView valueForKey:TGEncodeText(@"`joefy", -1)];
    
    [UIView animateWithDuration:0.15f animations:^
    {
        indexView.alpha = 1.0f;
    }];
    
    [self setNavigationBarHidden:false animated:animated];
}

- (void)searchMixin:(TGSearchDisplayMixin *)__unused searchMixin hasChangedSearchQuery:(NSString *)searchQuery withScope:(int)__unused scope
{
    [self beginSearch:searchQuery];
}

- (void)beginSearch:(NSString *)queryString
{
    TGSearchDisplayMixin *searchMixin = _searchMixin;
    
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        if ((_contactsMode & TGContactsModeInvite) == TGContactsModeInvite)
        {
            self.searchString = [[queryString stringByReplacingOccurrencesOfString:@" +" withString:@" " options:NSRegularExpressionSearch range:NSMakeRange(0, queryString.length)] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (self.searchString.length == 0)
            {
                dispatch_async(dispatch_get_main_queue(), ^
                {
                    [searchMixin reloadSearchResults];
                    [searchMixin setSearchResultsTableViewHidden:true];
                });
            }
            else
            {
                NSArray *contactResults = [TGDatabaseInstance() searchPhonebookContacts:_searchString contacts:_currentAddressBook];
                
                std::set<int> remoteContactIds;
                
                for (TGUser *user in [TGDatabaseInstance() loadContactUsers])
                {
                    if (user.contactId)
                        remoteContactIds.insert(user.contactId);
                }
                
                NSMutableArray *searchResults = [[NSMutableArray alloc] initWithCapacity:contactResults.count];
                for (TGPhonebookContact *phonebookContact in contactResults)
                {
                    int phonesCount = phonebookContact.phoneNumbers.count;
                    for (TGPhoneNumber *phoneNumber in phonebookContact.phoneNumbers)
                    {
                        if (remoteContactIds.find(phoneNumber.phoneId) != remoteContactIds.end())
                            continue;
                        
                        TGUser *phonebookUser = [[TGUser alloc] init];
                        phonebookUser.firstName = phonebookContact.firstName;
                        phonebookUser.lastName = phonebookContact.lastName;
                        phonebookUser.uid = -ABS(phoneNumber.phoneId);
                        phonebookUser.phoneNumber = phoneNumber.number;
                        if (phonesCount != 0)
                        {
                            phonebookUser.customProperties = [[NSDictionary alloc] initWithObjectsAndKeys:[[NSString alloc] initWithFormat:@"%@  %@", phoneNumber.label, phoneNumber.number], @"label", nil];
                        }
                        [searchResults addObject:phonebookUser];
                    }
                }
                
                dispatch_async(dispatch_get_main_queue(), ^
                {
                    self.searchResults = searchResults;
                    [searchMixin reloadSearchResults];
                    [searchMixin setSearchResultsTableViewHidden:false];
                });
            }
        }
        else
        {
            if (self.currentSearchPath != nil)
            {
                [ActionStageInstance() removeWatcher:self fromPath:self.currentSearchPath];
                self.currentSearchPath = nil;
            }
            
            self.searchString = [[queryString stringByReplacingOccurrencesOfString:@" +" withString:@" " options:NSRegularExpressionSearch range:NSMakeRange(0, queryString.length)] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (self.searchString.length == 0)
            {
                dispatch_async(dispatch_get_main_queue(), ^
                {
                    self.searchResults = nil;
                    if ((self.contactsMode & TGContactsModeCompose) == TGContactsModeCompose)
                        [self.searchTableView reloadData];
                    else
                    {
                        [searchMixin reloadSearchResults];
                        [searchMixin setSearchResultsTableViewHidden:true];
                    }
                });
            }
            else
            {
                self.currentSearchPath = [NSString stringWithFormat:@"/tg/contacts/search/(%d)", [self.searchString hash]];
                [ActionStageInstance() requestActor:self.currentSearchPath options:[NSDictionary dictionaryWithObjectsAndKeys:queryString, @"query", [[NSNumber alloc] initWithInt:TGTelegraphInstance.clientUserId], @"ignoreUid", [[NSNumber alloc] initWithBool:(self.contactsMode & TGContactsModePhonebook) == TGContactsModePhonebook], @"searchPhonebook", nil] watcher:self];
            }
        }
    }];
}

- (void)searchDisplayController:(UISearchDisplayController *)__unused controller didShowSearchResultsTableView:(UITableView *)tableView
{
    for (UIView *view in tableView.subviews)
    {
        if ((int)view.frame.size.height == 3 && view.tag != ((int)0x80D11F4B))
        {
            view.alpha = 0.5f;
            view.frame = CGRectMake(0, 0, tableView.frame.size.width, 2);
            break;
        }
    }
}

static UIView *findControl(UIView *view)
{
    if ([view isMemberOfClass:[UIControl class]])
    {
        return view;
    }
    
    for (UIView *subview in view.subviews)
    {
        UIView *result = findControl(subview);
        if (result != nil)
            return result;
    }

    return nil;
}

- (TGUser *)findUser:(int)uid
{
    for (std::vector<std::tr1::shared_ptr<TGContactListSection> >::iterator sectionIt = _sectionList.begin(); sectionIt != _sectionList.end(); sectionIt++)
    {
        std::vector<TGUser *>::iterator itemsEnd = sectionIt->get()->items.end();
        for (std::vector<TGUser *>::iterator itemIt = sectionIt->get()->items.begin(); itemIt != itemsEnd; itemIt++)
        {
            if((*itemIt).uid == uid)
            {
                return *itemIt;
            }
        }
    }
    
    return nil;
}

- (void)clearUsersSelection
{
    std::vector<TGUser *> deselectList;
    for (std::map<int, TGUser *>::iterator it = _selectedUsers.begin(); it != _selectedUsers.end(); it++)
    {
        deselectList.push_back(it->second);
    }
    
    if (!deselectList.empty())
    {
        NSArray *deselectedArray = [NSArray arrayWithObject:[NSNumber numberWithBool:false]];
        for (std::vector<TGUser *>::iterator it = deselectList.begin(); it != deselectList.end(); it++)
        {
            [self setUsersSelected:[NSArray arrayWithObject:*it] selected:deselectedArray callback:false];
        }
        
        [self contactDeselected:nil];
    }
}

- (void)setDisabledUsers:(NSArray *)disabledUsers
{
    _disabledUserIds.clear();
    for (NSNumber *nUid in disabledUsers)
    {
        _disabledUserIds.insert([nUid intValue]);
    }
    
    for (id cell in _tableView.visibleCells)
    {
        if ([cell isKindOfClass:[TGContactCell class]])
        {
            TGContactCell *contactCell = cell;
            bool isDisabled = (_disabledUserIds.find(contactCell.user.uid) != _disabledUserIds.end());
            if (contactCell.isDisabled != isDisabled)
                contactCell.isDisabled = isDisabled;
        }
    }
    
    for (id cell in _searchTableView.visibleCells)
    {
        if ([cell isKindOfClass:[TGContactCell class]])
        {
            TGContactCell *contactCell = cell;
            bool isDisabled = (_disabledUserIds.find(contactCell.user.uid) != _disabledUserIds.end());
            if (contactCell.isDisabled != isDisabled)
                contactCell.isDisabled = isDisabled;
        }
    }
}

- (void)setUsersSelected:(NSArray *)users selected:(NSArray *)selected callback:(bool)callback
{
    [self setUsersSelected:users selected:selected callback:callback updateSearchTable:true];
}

- (void)setUsersSelected:(NSArray *)users selected:(NSArray *)selected callback:(bool)callback updateSearchTable:(bool)updateSearchTable
{
    bool updateView = self.isViewLoaded;
    std::map<int, bool> updateViewItems;
    std::vector<int> deselectedUids;
    std::vector<int> selectedUids;
    
    int index = -1;
    for (TGUser *user in users)
    {
        index++;
        int uid = user.uid;
        
        bool wasSelected = false;
        bool becameSelected = selected == nil ? false : [[selected objectAtIndex:index] boolValue];
        
        std::map<int, TGUser *>::iterator it = _selectedUsers.find(uid);
        if (it == _selectedUsers.end())
        {
            if (becameSelected && selected != nil)
                _selectedUsers.insert(std::pair<int, TGUser *>(uid, user));
        }
        else
        {
            wasSelected = true;
            
            if (selected != nil)
            {
                if (!becameSelected)
                    _selectedUsers.erase(it);
            }
        }
        
        if (selected != nil)
        {
            if (wasSelected && !becameSelected)
                deselectedUids.push_back(uid);
            else if (!wasSelected && becameSelected)
                selectedUids.push_back(uid);
        }
        
        if (wasSelected != becameSelected && updateView)
            updateViewItems.insert(std::pair<int, bool>(uid, true));
    }
    
    if (updateView)
    {
        Class contactCellClass = [TGContactCell class];
        
        std::map<int, bool> *pUpdateViewItems = &updateViewItems;
        
        void (^updateBlock)(id, NSUInteger, BOOL *) = ^(UITableViewCell *cell, __unused NSUInteger idx, __unused BOOL *stop)
        {
            if ([cell isKindOfClass:contactCellClass])
            {
                TGContactCell *contactCell = (TGContactCell *)cell;
                std::map<int, bool>::iterator it = pUpdateViewItems->find(contactCell.itemId);
                if (it != updateViewItems.end())
                {
                    std::map<int, TGUser *>::iterator itemIt = _selectedUsers.find(contactCell.itemId);
                    if (itemIt == _selectedUsers.end())
                        [contactCell updateFlags:false];
                    else
                        [contactCell updateFlags:true];
                }
            }
        };
        
        [[_tableView visibleCells] enumerateObjectsUsingBlock:updateBlock];
        
        if (updateSearchTable)
        {
            if ((_contactsMode & TGContactsModeCompose) == TGContactsModeCompose)
                [[_searchTableView visibleCells] enumerateObjectsUsingBlock:updateBlock];
            else
            {
                if (_searchMixin.isActive)
                    [_searchMixin.searchResultsTableView.visibleCells enumerateObjectsUsingBlock:updateBlock];
            }
        }
    }
    
    if (callback)
    {
        for (std::vector<int>::iterator it = deselectedUids.begin(); it != deselectedUids.end(); it++)
        {
            TGUser *user = [self findUser:*it];
            if (user != nil)
                [self contactDeselected:user];
        }
        
        for (std::vector<int>::iterator it = selectedUids.begin(); it != selectedUids.end(); it++)
        {
            TGUser *user = [self findUser:*it];
            if (user != nil)
                [self contactSelected:user];
        }
    }

    if ((_contactsMode & TGContactsModeCompose) == TGContactsModeCompose)
    {
        [self updateTokenField];
    }
}

- (void)updateTokenField
{
    std::set<int> existingUids;
    
    NSMutableIndexSet *removeIndexes = [[NSMutableIndexSet alloc] init];
    
    int index = -1;
    for (id tokenId in [_tokenFieldView tokenIds])
    {
        index++;
        
        if ([tokenId isKindOfClass:[NSNumber class]])
        {
            int uid = [tokenId intValue];
            if (_selectedUsers.find(uid) == _selectedUsers.end())
                [removeIndexes addIndex:index];
            else
                existingUids.insert(uid);
        }
    }
    
    [_tokenFieldView removeTokensAtIndexes:removeIndexes];
    
    for (std::map<int, TGUser *>::iterator it = _selectedUsers.begin(); it != _selectedUsers.end(); it++)
    {
        if (existingUids.find(it->first) != existingUids.end())
            continue;
        
        [_tokenFieldView addToken:it->second.displayName tokenId:[[NSNumber alloc] initWithInt:it->second.uid] animated:true];
    }
}

- (void)deselectRow
{
    if ([_tableView indexPathForSelectedRow] != nil)
        [_tableView deselectRowAtIndexPath:[_tableView indexPathForSelectedRow] animated:true];
}

- (int)selectedContactsCount
{
    return _selectedUsers.size();
}
             
- (int)contactsCount
{
    int count = 0;
    for (std::vector<std::tr1::shared_ptr<TGContactListSection> >::iterator sectionIt = _sectionList.begin(); sectionIt != _sectionList.end(); sectionIt++)
    {
        count += (*sectionIt)->items.size();
    }
    
    return count;
}

- (NSArray *)selectedComposeUsers
{
    NSMutableArray *users = [[NSMutableArray alloc] init];
    
    for (id tokenId in [_tokenFieldView tokenIds])
    {
        if ([tokenId isKindOfClass:[NSNumber class]])
        {
            TGUser *user = [TGDatabaseInstance() loadUser:[tokenId intValue]];
            if (user != nil)
                [users addObject:user];
        }
    }
    
    return users;
}

- (NSArray *)selectedContactsList
{
    NSMutableArray *array = [[NSMutableArray alloc] init];
    
    for (std::map<int, TGUser *>::iterator it = _selectedUsers.begin(); it != _selectedUsers.end(); it++)
    {
        bool found = false;
        
        int uid = it->first;
        for (std::vector<std::tr1::shared_ptr<TGContactListSection> >::iterator sectionIt = _sectionList.begin(); sectionIt != _sectionList.end(); sectionIt++)
        {
            std::vector<TGUser *>::iterator itemsEnd = sectionIt->get()->items.end();
            for (std::vector<TGUser *>::iterator itemIt = sectionIt->get()->items.begin(); itemIt != itemsEnd; itemIt++)
            {
                if((*itemIt).uid == uid)
                {
                    [array addObject:(*itemIt)];
                    
                    found = true;
                    break;
                }
            }
            
            if (found)
                break;
        }
        
        if (!found)
            [array addObject:it->second];
    }
    
    return array;
}

- (void)updateSelectedContacts:(int)count incremented:(bool)__unused incremented
{
    if ((_contactsMode & TGContactsModeInvite) == TGContactsModeInvite)
    {
        if (count != 0)
        {
            _inviteButton.text = count == 0 ? TGLocalized(@"Contacts.InviteTitleEmpty") : [[NSString alloc] initWithFormat:TGLocalized(@"Contacts.InviteTitle"), count];
            float oldWidth = _inviteButton.frame.size.width;
            [_inviteButton sizeToFit];
            if (_appearAnimation)
                _inviteButton.frame = CGRectOffset(_inviteButton.frame, oldWidth - _inviteButton.frame.size.width, 0);
        }
        
        if (count == 0)
        {
            if (!_inviteButton.hidden || _inviteButton.alpha != 0.0)
            {
                _inviteButton.alpha = 1.0f;
                if ((_contactsMode & TGContactsModeModalInvite) != TGContactsModeModalInvite)
                    _doneButton.alpha = 1.0f;
                [UIView animateWithDuration:0.3 animations:^
                {
                    _inviteButton.alpha = 0.0f;
                    if ((_contactsMode & TGContactsModeModalInvite) != TGContactsModeModalInvite)
                        _doneButton.alpha = 0.0f;
                } completion:^(BOOL finished)
                {
                    if (finished)
                    {
                        _inviteButton.hidden = true;
                        if ((_contactsMode & TGContactsModeModalInvite) != TGContactsModeModalInvite)
                            _doneButton.hidden = true;
                    }
                }];
            }
            
            if ([self.parentViewController isKindOfClass:[TGMainTabsController class]])
            {
                TGMainTabsController *tabController = (TGMainTabsController *)self.parentViewController;
                [tabController updateTitleForController:self switchingTabs:false animateText:false];
            }
            else if (!_disappearAnimation)
            {
                if (self.navigationItem.rightBarButtonItem != [self controllerRightBarButtonItem])
                    [self.navigationItem setRightBarButtonItem:[self controllerRightBarButtonItem] animated:true];
                self.titleText = [self controllerTitle];
            }
        }
        else
        {
            if (_inviteButton.hidden || _inviteButton.alpha != 1.0)
            {
                _inviteButton.hidden = false;
                if ((_contactsMode & TGContactsModeModalInvite) != TGContactsModeModalInvite)
                    _doneButton.hidden = false;
                _inviteButton.alpha = 0.0f;
                if ((_contactsMode & TGContactsModeModalInvite) != TGContactsModeModalInvite)
                    _doneButton.alpha = 0.0f;
                [UIView animateWithDuration:0.3 animations:^
                {
                    _inviteButton.alpha = 1.0f;
                    if ((_contactsMode & TGContactsModeModalInvite) != TGContactsModeModalInvite)
                        _doneButton.alpha = 1.0f;
                }];
            }
            
            if ([self.parentViewController isKindOfClass:[TGMainTabsController class]])
            {
                TGMainTabsController *tabController = (TGMainTabsController *)self.parentViewController;
                [tabController updateTitleForController:self switchingTabs:false animateText:false];
            }
            else if (!_disappearAnimation)
            {
                if (self.navigationItem.rightBarButtonItem != [self controllerRightBarButtonItem])
                    [self.navigationItem setRightBarButtonItem:[self controllerRightBarButtonItem] animated:true];
                self.titleText = [self controllerTitle];
            }
        }
    }
    
    if (_selectAllButton != nil)
        [self updateSelectionInterface];
}

- (void)contactSelected:(TGUser *)__unused user
{
    if ((_contactsMode & TGContactsModeInvite) == TGContactsModeInvite || (_contactsMode & TGContactsModeCompose) == TGContactsModeCompose)
    {
        int selectedCount = [self selectedContactsCount];
        [self updateSelectedContacts:selectedCount incremented:true];
    }
}

- (void)contactDeselected:(TGUser *)__unused user
{
    if ((_contactsMode & TGContactsModeInvite) == TGContactsModeInvite || (_contactsMode & TGContactsModeCompose) == TGContactsModeCompose)
    {
        int selectedCount = [self selectedContactsCount];
        [self updateSelectedContacts:selectedCount incremented:false];
    }
}

- (void)selectAllButtonPressed
{
    int selectedCount = [self selectedContactsCount];
    if (selectedCount == [self contactsCount])
    {
        NSMutableArray *users = [[NSMutableArray alloc] init];
        NSMutableArray *selectedArray = [[NSMutableArray alloc] init];
        
        for (TGUser *user in [self selectedContactsList])
        {
            [users addObject:user];
            [selectedArray addObject:[[NSNumber alloc] initWithBool:false]];
        }
        
        [self setUsersSelected:users selected:selectedArray callback:true];
    }
    else
    {
        NSMutableArray *users = [[NSMutableArray alloc] init];
        NSMutableArray *selectedArray = [[NSMutableArray alloc] init];
        
        for (std::vector<std::tr1::shared_ptr<TGContactListSection> >::iterator sectionIt = _sectionList.begin(); sectionIt != _sectionList.end(); sectionIt++)
        {
            for (std::vector<TGUser *>::iterator it = (*sectionIt)->items.begin(); it != (*sectionIt)->items.end(); it++)
            {
                [users addObject:(*it)];
                [selectedArray addObject:[[NSNumber alloc] initWithBool:true]];
            }
        }
        
        [self setUsersSelected:users selected:selectedArray callback:true];
    }
}

- (void)addButtonPressed
{
    TGProfileController *profileController = [[TGProfileController alloc] initWithCreateNewContact:nil watcherHandle:_actionHandle];
    
    TGNavigationController *navigationController = [TGNavigationController navigationControllerWithRootController:profileController blackCorners:false];
    
    [self presentViewController:navigationController animated:true completion:nil];
}

- (void)inviteInlineButtonPressed
{
    TGContactsController *contactsController = [[TGContactsController alloc] initWithContactsMode:TGContactsModeInvite | TGContactsModeModalInvite | TGContactsModeModalInviteWithBack];
    contactsController.loginStyle = false;
    contactsController.customTitle = TGLocalized(@"Contacts.InviteFriends");
    contactsController.watcherHandle = _actionHandle;
    [self.navigationController pushViewController:contactsController animated:true];
}

- (void)mainInviteButtonPressed
{
    TGContactsController *contactsController = [[TGContactsController alloc] initWithContactsMode:TGContactsModeInvite | TGContactsModeModalInvite];
    contactsController.customTitle = TGLocalized(@"Contacts.InviteFriends");
    contactsController.watcherHandle = _actionHandle;
    
    TGNavigationController *navigationController = [TGNavigationController navigationControllerWithRootController:contactsController blackCorners:false];
    
    if (iosMajorVersion() <= 5)
    {
        [TGViewController disableAutorotationFor:0.45];
        [contactsController view];
        [contactsController viewWillAppear:false];
        
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
                [contactsController viewWillDisappear:false];
                [contactsController viewDidDisappear:false];
                [self presentViewController:navigationController animated:false completion:nil];
            }
        }];
    }
    else
    {
        [self presentViewController:navigationController animated:true completion:nil];
    }
}

- (void)inviteButtonPressed
{
    if ((_contactsMode & TGContactsModeInvite) == TGContactsModeInvite)
    {
        NSMutableArray *recipients = [[NSMutableArray alloc] init];
        for (TGUser *user in [self selectedContactsList])
        {
            if (user.phoneNumber != nil)
                [recipients addObject:[TGStringUtils formatPhoneUrl:user.phoneNumber]];
        }
        
        if (recipients.count == 0)
            return;
        
        if ([MFMessageComposeViewController canSendText])
        {
            _messageComposer = [[MFMessageComposeViewController alloc] init];
            
            if (_messageComposer != nil)
            {
                _messageComposer.recipients = recipients;
                _messageComposer.messageComposeDelegate = self;
                
                NSString *body = TGLocalized(@"Contacts.InvitationText");
                
                NSArray *preferredLanguages = [NSLocale preferredLanguages];
                if (preferredLanguages.count != 0)
                {
                    NSString *language = [preferredLanguages[0] lowercaseString];
                    
                    if ([language isEqualToString:@"ru"])
                    {
                        body = TGLocalized(@"Contacts.InvitationText_RU");
                    }
                    else if ([language isEqualToString:@"uk"])
                    {
                        body = TGLocalized(@"Contacts.InvitationText_RU");
                    }
                }
                
                _messageComposer.body = body;
                
                [self presentViewController:_messageComposer animated:true completion:nil];
                [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackOpaque];
            }
        }
    }
}

- (void)messageComposeViewController:(MFMessageComposeViewController *)__unused controller didFinishWithResult:(MessageComposeResult)result
{
    _messageComposer = nil;
    
    bool dismiss = result == MessageComposeResultSent && (_contactsMode & TGContactsModeModalInvite) == TGContactsModeModalInvite && (_contactsMode & TGContactsModeModalInviteWithBack) != TGContactsModeModalInviteWithBack;
    
    if (!dismiss)
        [self dismissModalViewControllerAnimated:true];
    
    if (result == MessageComposeResultFailed)
    {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:nil message:NSLocalizedString(@"Contacts.FailedToSendInvitesMessage", nil) delegate:nil cancelButtonTitle:NSLocalizedString(@"Common.OK", nil) otherButtonTitles: nil];
        [alertView show];
    }
    else if (result == MessageComposeResultSent)
    {
        @try
        {
            static int inviteAction = 0;
            [ActionStageInstance() requestActor:[[NSString alloc] initWithFormat:@"/tg/auth/sendinvites/(%d)", inviteAction] options:[[NSDictionary alloc] initWithObjectsAndKeys:controller.body, @"text", controller.recipients, @"phones", nil] watcher:TGTelegraphInstance];
        }
        @catch (NSException *exception)
        {
        }
        
        if ((_contactsMode & TGContactsModeModalInviteWithBack) == TGContactsModeModalInviteWithBack)
        {
            [self.navigationController popViewControllerAnimated:false];
        }
        else if ((_contactsMode & TGContactsModeModalInvite) == TGContactsModeModalInvite)
        {
            [self doneButtonPressed];
        }
        else
        {
            [self clearUsersSelection];       
        }
    }
}

- (void)doneButtonPressed
{
    if ((_contactsMode & TGContactsModeModalInvite) == TGContactsModeModalInvite || (_contactsMode & TGContactsModeSelectModal) == TGContactsModeSelectModal)
    {
        id<ASWatcher> watcher = _watcherHandle.delegate;
        if (watcher != nil && [watcher respondsToSelector:@selector(actionStageActionRequested:options:)])
            [watcher actionStageActionRequested:@"dismissModalContacts" options:nil];
    }
    else
    {
        [UIView setAnimationsEnabled:false];
        [self clearUsersSelection];
        [UIView setAnimationsEnabled:true];
    }
}

- (void)modalInviteBackButtonPressed
{
    [self.navigationController popViewControllerAnimated:true];
}

#pragma mark - Data logic

- (NSArray *)generateIndices:(const std::vector<std::tr1::shared_ptr<TGContactListSection> > &)sections
{
    NSMutableArray *result = [[NSMutableArray alloc] initWithCapacity:sections.size()];
    
    if ((_contactsMode & TGContactsModeSearchDisabled) != TGContactsModeSearchDisabled)
        [result addObject:UITableViewIndexSearch];
    
    for (std::vector<std::tr1::shared_ptr<TGContactListSection> >::const_iterator it = sections.begin(); it != sections.end(); it++)
    {
        if (it->get()->letter != nil)
            [result addObject:it->get()->letter];
    }
    
    return [NSArray arrayWithArray:result];
}

- (void)actionStageActionRequested:(NSString *)action options:(NSDictionary *)options
{
    if ([action isEqualToString:@"/contactlist/toggleItem"])
    {
        int itemId = [[options objectForKey:@"itemId"] intValue];
        bool selected = [[options objectForKey:@"selected"] boolValue];
        
        if (_usersSelectedLimit > 0 && !selected && [self selectedContactsCount] >= _usersSelectedLimit)
        {
            [(TGContactCell *)options[@"cell"] updateFlags:selected force:true];
            
            return;
        }
        
        TGUser *user = [self findUser:itemId];
        if (user != nil)
        {
            [self setUsersSelected:[NSArray arrayWithObject:user] selected:[NSArray arrayWithObject:[NSNumber numberWithBool:!selected]] callback:true updateSearchTable:true];
            
            if (!selected && (_contactsMode & TGContactsModeCompose) == TGContactsModeCompose)
            {
                [_tokenFieldView clearText];
            }
        }
        
        if (!selected && _searchMixin != nil && _searchMixin.isActive)
            [_searchMixin setIsActive:false animated:true];
    }
    else if ([action isEqualToString:@"contactCellAction"])
    {
        int itemId = [[options objectForKey:@"itemId"] intValue];
        
        for (std::vector<std::tr1::shared_ptr<TGContactListSection> >::iterator section = _sectionList.begin(); section != _sectionList.end(); section++)
        {
            for (std::vector<TGUser *>::iterator item = (*section)->items.begin(); item != (*section)->items.end(); item++)
            {
                if ((*item).uid == itemId)
                {
                    [self contactActionButtonPressed:(*item)];
                    break;
                }
            }
        }
    }
    else if ([action isEqualToString:@"dismissModalContacts"])
    {
        [self dismissViewControllerAnimated:true completion:nil];
    }
    else if ([action isEqualToString:@"createContactCompleted"])
    {
        [self dismissViewControllerAnimated:true completion:nil];
    }
}

- (void)actionStageResourceDispatched:(NSString *)path resource:(id)resource arguments:(id)__unused arguments
{
    if ([path isEqualToString:@"/tg/phonebookAccessStatus"])
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            [self updatePhonebookAccess];
        });
    }
    else if ([path isEqualToString:@"/tg/contactlist"])
    {
        [self actorCompleted:ASStatusSuccess path:@"/tg/contactlist/(contacts)" result:resource];
    }
    else if ([path isEqualToString:@"/tg/phonebook"])
    {
        [self actorCompleted:ASStatusSuccess path:@"/tg/contactlist/(phonebook)" result:resource];
    }
    else if ([path isEqualToString:@"/as/updateRelativeTimestamps"])
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            [self updateRelativeTimestamps];
        });
    }
    else if ([path isEqualToString:@"/tg/userdatachanges"] || [path isEqualToString:@"/tg/userpresencechanges"])
    {
        NSArray *users = ((SGraphObjectNode *)resource).object;
        std::tr1::shared_ptr<std::map<int, int> > changedUidToIndex(new std::map<int, int>());
        int index = -1;
        for (TGUser *user in users)
        {
            index++;
            changedUidToIndex->insert(std::pair<int, int>(user.uid, index));
        }
        
        NSMutableArray *newContactList = nil;
        index = -1;
        for (TGUser *user in _currentContactList)
        {
            index++;
            
            std::map<int, int>::iterator it = changedUidToIndex->find(user.uid);
            if (it != changedUidToIndex->end())
            {
                if (newContactList == nil)
                    newContactList = [[NSMutableArray alloc] initWithArray:_currentContactList];
                
                [newContactList replaceObjectAtIndex:index withObject:[users objectAtIndex:it->second]];
            }
        }
        if (newContactList != nil)
            _currentContactList = newContactList;
        
        dispatch_async(dispatch_get_main_queue(), ^
        {   
            int sectionIndex = -1;
            for (std::vector<std::tr1::shared_ptr<TGContactListSection> >::iterator section = _sectionList.begin(); section != _sectionList.end(); section++)
            {
                sectionIndex++;
                
                int itemIndex = -1;
                for (std::vector<TGUser *>::iterator item = (*section)->items.begin(); item != (*section)->items.end(); item++)
                {
                    itemIndex++;
                    
                    std::map<int, int>::iterator it = changedUidToIndex->find((*item).uid);
                    if (it != changedUidToIndex->end())
                    {
                        TGUser *user = [users objectAtIndex:it->second];
                        *item = user;
                        
                        UITableViewCell *cell = [_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:itemIndex inSection:sectionIndex]];
                        if (cell != nil && [cell isKindOfClass:[TGContactCell class]])
                        {
                            TGContactCell *contactCell = (TGContactCell *)cell;
                            
                            adjustCellForUser(contactCell, user, _currentSortOrder, true, _selectedUsers, (_contactsMode & TGContactsModeMainContacts) == TGContactsModeMainContacts, _disabledUserIds.find(user.uid) != _disabledUserIds.end());
                        }
                    }
                }
            }
            
            if (_searchResults.count != 0)
            {
                NSMutableArray *newSearchResults = nil;
                
                int count = _searchResults.count;
                for (int i = 0; i < count; i++)
                {
                    TGUser *user = [_searchResults objectAtIndex:i];
                    if (user.uid < 0)
                        continue;
                    
                    std::map<int, int>::iterator it = changedUidToIndex->find(user.uid);
                    if (it != changedUidToIndex->end())
                    {
                        if (newSearchResults == nil)
                            newSearchResults = [[NSMutableArray alloc] initWithArray:_searchResults];
                        
                        TGUser *newUser = [users objectAtIndex:it->second];
                        [newSearchResults replaceObjectAtIndex:i withObject:newUser];
                        id cell = [_searchMixin.searchResultsTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0]];
                        if ([cell isKindOfClass:[TGContactCell class]])
                        {
                            adjustCellForUser(cell, newUser, _currentSortOrder, true, _selectedUsers, false, _disabledUserIds.find(user.uid) != _disabledUserIds.end());
                        }
                    }
                }
                
                if (newSearchResults != nil)
                   _searchResults = newSearchResults;
            }
        });
    }
}

- (void)actorCompleted:(int)resultCode path:(NSString *)path result:(id)result
{
    if ([path isEqualToString:@"/tg/contactlist/(contacts)"])
    {
        if (resultCode == 0)
        {
            NSDictionary *resultDict = ((SGraphObjectNode *)result).object;
            int version = [[resultDict objectForKey:@"version"] intValue];
            if (version <= _contactListVersion)
                return;
            
            _contactListVersion = version;
            _currentContactList = [resultDict objectForKey:@"contacts"];
            
            if (!_updateContactListSheduled)
            {
                _updateContactListSheduled = true;
                dispatch_async([ActionStageInstance() globalStageDispatchQueue], ^
                {
                    _updateContactListSheduled = false;
                    
                    [self updateContactList];
                });
            }
        }
    }
    else if ([path isEqualToString:@"/tg/contactlist/(phonebook)"])
    {
        if (resultCode == 0)
        {
            NSDictionary *resultDict = ((SGraphObjectNode *)result).object;
            int version = [[resultDict objectForKey:@"version"] intValue];
            if (version <= _phonebookVersion)
                return;
            
            _phonebookVersion = version;
            _currentAddressBook = [resultDict objectForKey:@"phonebook"];
            
            if (!_updateContactListSheduled)
            {
                _updateContactListSheduled = true;
                dispatch_async([ActionStageInstance() globalStageDispatchQueue], ^
                {
                    _updateContactListSheduled = false;
                    
                    [self updateContactList];
                });
            }
        }
    }
    else if ([path isEqualToString:_currentSearchPath])
    {
        _currentSearchPath = nil;
        
        if (resultCode == ASStatusSuccess)
        {
            NSDictionary *dict = ((SGraphObjectNode *)result).object;
            NSArray *users = [dict objectForKey:@"users"];
            
            dispatch_async(dispatch_get_main_queue(), ^
            {
                _searchResults = users;
                
                if ((_contactsMode & TGContactsModeCompose) == TGContactsModeCompose)
                {
                    [_searchTableView reloadData];
                }
                else
                {
                    [_searchMixin reloadSearchResults];
                    [_searchMixin setSearchResultsTableViewHidden:false];
                }
            });
        }
    }
}

- (void)updateContactList
{
    //TGLog(@"Updating contact list view");
    
    int sortOrder = [[TGSynchronizeContactsManager instance] sortOrder];
    
    NSCharacterSet *characterSet = [NSCharacterSet alphanumericCharacterSet];
    NSCharacterSet *symbolCharacterSet = [NSCharacterSet symbolCharacterSet];
    
    NSArray *contactList = _currentContactList;
    NSArray *addressBook = _currentAddressBook;
    
    if (addressBook == nil)
        addressBook = [TGDatabaseInstance() loadPhonebookContacts];
    
    std::map<int, NSString *> phoneIdToLabel;
    
    for (TGPhonebookContact *phonebookContact in addressBook)
    {
        if (phonebookContact.phoneNumbers.count > 1)
        {
            for (TGPhoneNumber *phoneNumber in phonebookContact.phoneNumbers)
            {
                phoneIdToLabel.insert(std::pair<int, NSString *>(phoneNumber.phoneId, phoneNumber.label));
            }
        }
    }
    
    std::map<unichar, unichar> uppercaseMap;
    
    std::vector<std::tr1::shared_ptr<TGContactListSection> > newSectionListAll;
    std::vector<std::tr1::shared_ptr<TGContactListSection> > newSectionListTelegraph;
    
    int clientUserId = TGTelegraphInstance.clientUserId;
    
    std::set<int> remoteContactIds;
    
    if ((_contactsMode & TGContactsModeModalInvite) != TGContactsModeModalInvite)
    {
        for (TGUser *rawUser in contactList)
        {
            TGUser *user = nil;
            std::map<int, NSString *>::iterator it = phoneIdToLabel.find(rawUser.contactId);
            if (it != phoneIdToLabel.end())
            {
                user = [rawUser copy];
                NSString *label = it->second;
                NSString *key = @"label";
                if (label != nil)
                    user.customProperties = [[NSDictionary alloc] initWithObjects:&label forKeys:&key count:1];
            }
            else
                user = rawUser;
            
            int uid = user.uid;
            
            if (user.contactId)
                remoteContactIds.insert(user.contactId);
            
            if (uid == clientUserId)
                continue;
            
            if ((_contactsMode & TGContactsModeModalInvite) == TGContactsModeModalInvite && uid > 0)
                continue;
            
            unichar sectionLetter = '#';
            if (sortOrder & TGContactListSortOrderFirst)
            {
                if (user.firstName.length != 0)
                    sectionLetter = [user.firstName characterAtIndex:0];
                else if (user.lastName.length != 0)
                    sectionLetter = [user.lastName characterAtIndex:0];
                else
                    sectionLetter = '#';
            }
            else
            {
                if (user.lastName.length != 0)
                    sectionLetter = [user.lastName characterAtIndex:0];
                else if (user.firstName.length != 0)
                    sectionLetter = [user.firstName characterAtIndex:0];
                else
                    sectionLetter = '#';
            }
            
            if (sectionLetter != '#' && ((sectionLetter >= '0' && sectionLetter <= '9') || [symbolCharacterSet characterIsMember:sectionLetter] || ![characterSet characterIsMember:sectionLetter]))
                sectionLetter = '#';
            
            std::map<unichar, unichar>::iterator uppercaseIt = uppercaseMap.find(sectionLetter);
            if (uppercaseIt == uppercaseMap.end())
            {
                unichar uppercaseLetter = [[[[NSString alloc] initWithCharacters:&sectionLetter length:1] uppercaseString] characterAtIndex:0];
                uppercaseMap.insert(std::pair<unichar, unichar>(sectionLetter, uppercaseLetter));
                sectionLetter = uppercaseLetter;
            }
            else
                sectionLetter = uppercaseIt->second;
            
            bool found = false;
            for (std::vector<std::tr1::shared_ptr<TGContactListSection> >::iterator it = newSectionListTelegraph.begin(); it != newSectionListTelegraph.end(); it++)
            {
                if (!(_contactsMode & TGContactsModePhonebook))
                {
                    if (it->get()->sortLetter == sectionLetter)
                    {
                        it->get()->addItem(user);
                        
                        found = true;
                        break;
                    }
                }
                else
                {
                    it->get()->addItem(user);
                    
                    found = true;
                    break;
                }
            }
            
            if (!found)
            {
                std::tr1::shared_ptr<TGContactListSection> newSection(new TGContactListSection());
                newSection->addItem(user);
                newSection->setSortLetter(sectionLetter);
                newSectionListTelegraph.push_back(newSection);
            }
        }
    }

    if (_contactsMode & TGContactsModePhonebook)
    {
        bool modalInvite = false;
        
        if ((_contactsMode & TGContactsModeModalInvite) == TGContactsModeModalInvite)
        {
            modalInvite = true;
            for (TGUser *user in [TGDatabaseInstance() loadContactUsers])
            {
                int contactId = user.contactId;
                if (contactId != 0)
                    remoteContactIds.insert(contactId);
            }
        }
        
        if (modalInvite)
        {
            for (TGPhonebookContact *phonebookContact in addressBook)
            {
                int phonesCount = phonebookContact.phoneNumbers.count;
                for (TGPhoneNumber *phoneNumber in phonebookContact.phoneNumbers)
                {
                    if (remoteContactIds.find(phoneNumber.phoneId) != remoteContactIds.end())
                        continue;
                    
                    TGUser *phonebookUser = [[TGUser alloc] init];
                    phonebookUser.firstName = phonebookContact.firstName;
                    phonebookUser.lastName = phonebookContact.lastName;
                    phonebookUser.uid = -ABS(phoneNumber.phoneId);
                    remoteContactIds.insert(phoneNumber.phoneId);
                    phonebookUser.phoneNumber = phoneNumber.number;
                    if (phonesCount != 0 && phoneNumber.label != nil)
                    {
                        phonebookUser.customProperties = [[NSDictionary alloc] initWithObjectsAndKeys:[[NSString alloc] initWithFormat:@"%@  %@", phoneNumber.label, phoneNumber.number], @"label", nil];
                    }
                    
                    unichar sectionLetter = '#';
                    if (sortOrder & TGContactListSortOrderFirst)
                    {
                        if (phonebookContact.firstName.length != 0)
                            sectionLetter = [phonebookContact.firstName characterAtIndex:0];
                        else if (phonebookUser.lastName.length != 0)
                            sectionLetter = [phonebookContact.lastName characterAtIndex:0];
                        else
                            sectionLetter = '#';
                    }
                    else
                    {
                        if (phonebookContact.lastName.length != 0)
                            sectionLetter = [phonebookContact.lastName characterAtIndex:0];
                        else if (phonebookContact.firstName.length != 0)
                            sectionLetter = [phonebookContact.firstName characterAtIndex:0];
                        else
                            sectionLetter = '#';
                    }
                    
                    if (sectionLetter != '#' && ((sectionLetter >= '0' && sectionLetter <= '9') || [symbolCharacterSet characterIsMember:sectionLetter] || ![characterSet characterIsMember:sectionLetter]))
                        sectionLetter = '#';
                    
                    std::map<unichar, unichar>::iterator uppercaseIt = uppercaseMap.find(sectionLetter);
                    if (uppercaseIt == uppercaseMap.end())
                    {
                        unichar uppercaseLetter = [[[[NSString alloc] initWithCharacters:&sectionLetter length:1] uppercaseString] characterAtIndex:0];
                        uppercaseMap.insert(std::pair<unichar, unichar>(sectionLetter, uppercaseLetter));
                        sectionLetter = uppercaseLetter;
                    }
                    else
                        sectionLetter = uppercaseIt->second;
                    
                    bool found = false;
                    for (std::vector<std::tr1::shared_ptr<TGContactListSection> >::iterator it = newSectionListAll.begin(); it != newSectionListAll.end(); it++)
                    {
                        if (it->get()->sortLetter == sectionLetter)
                        {
                            it->get()->addItem(phonebookUser);
                            
                            found = true;
                            break;
                        }
                    }
                    
                    if (!found)
                    {
                        std::tr1::shared_ptr<TGContactListSection> newSection(new TGContactListSection());
                        newSection->addItem(phonebookUser);
                        newSection->setSortLetter(sectionLetter);
                        newSectionListAll.push_back(newSection);
                    }
                }
            }
        }
        else
        {
            for (TGPhonebookContact *phonebookContact in addressBook)
            {
                if (phonebookContact.phoneNumbers.count == 0)
                    continue;
                
                TGUser *phonebookUser = nil;

                bool foundInRemoteContacts = false;
                for (TGPhoneNumber *phoneNumber in phonebookContact.phoneNumbers)
                {
                    if (remoteContactIds.find(phoneNumber.phoneId) != remoteContactIds.end())
                    {
                        foundInRemoteContacts = true;
                        break;
                    }
                }
                
                if (foundInRemoteContacts)
                    continue;
                
                phonebookUser = [[TGUser alloc] init];
                phonebookUser.firstName = phonebookContact.firstName;
                phonebookUser.lastName = phonebookContact.lastName;
                phonebookUser.uid = -ABS(phonebookContact.nativeId);
                
                unichar sectionLetter = '#';
                if (sortOrder & TGContactListSortOrderFirst)
                {
                    if (phonebookContact.firstName.length != 0)
                        sectionLetter = [phonebookContact.firstName characterAtIndex:0];
                    else if (phonebookContact.lastName.length != 0)
                        sectionLetter = [phonebookContact.lastName characterAtIndex:0];
                    else
                        sectionLetter = '#';
                }
                else
                {
                    if (phonebookContact.lastName.length != 0)
                        sectionLetter = [phonebookContact.lastName characterAtIndex:0];
                    else if (phonebookContact.firstName.length != 0)
                        sectionLetter = [phonebookContact.firstName characterAtIndex:0];
                    else
                        sectionLetter = '#';
                }
                
                if (sectionLetter != '#' && ((sectionLetter >= '0' && sectionLetter <= '9') || [symbolCharacterSet characterIsMember:sectionLetter] || ![characterSet characterIsMember:sectionLetter]))
                    sectionLetter = '#';
                
                std::map<unichar, unichar>::iterator uppercaseIt = uppercaseMap.find(sectionLetter);
                if (uppercaseIt == uppercaseMap.end())
                {
                    unichar uppercaseLetter = [[[[NSString alloc] initWithCharacters:&sectionLetter length:1] uppercaseString] characterAtIndex:0];
                    uppercaseMap.insert(std::pair<unichar, unichar>(sectionLetter, uppercaseLetter));
                    sectionLetter = uppercaseLetter;
                }
                else
                    sectionLetter = uppercaseIt->second;
                
                bool found = false;
                for (std::vector<std::tr1::shared_ptr<TGContactListSection> >::iterator it = newSectionListAll.begin(); it != newSectionListAll.end(); it++)
                {
                    if (it->get()->sortLetter == sectionLetter)
                    {
                        it->get()->addItem(phonebookUser);
                        
                        found = true;
                        break;
                    }
                }
                
                if (!found)
                {
                    std::tr1::shared_ptr<TGContactListSection> newSection(new TGContactListSection());
                    newSection->addItem(phonebookUser);
                    newSection->setSortLetter(sectionLetter);
                    newSectionListAll.push_back(newSection);
                }
            }
        }
    }

    for (std::vector<std::tr1::shared_ptr<TGContactListSection> >::iterator it = newSectionListAll.begin(); it != newSectionListAll.end(); it++)
    {
        if (sortOrder & TGContactListSortOrderFirst)
            it->get()->sortByFirstName();
        else
            it->get()->sortByLastName();
    }
    
    for (std::vector<std::tr1::shared_ptr<TGContactListSection> >::iterator it = newSectionListTelegraph.begin(); it != newSectionListTelegraph.end(); it++)
    {
        if (sortOrder & TGContactListSortOrderFirst)
            it->get()->sortByFirstName();
        else
            it->get()->sortByLastName();
    }
    
    if (newSectionListTelegraph.size() == 1 || (_contactsMode & TGContactsModeMainContacts) == TGContactsModeMainContacts)
    {
        if (newSectionListTelegraph.size() > 0)
            newSectionListTelegraph[0]->letter = nil;
    }
    
    std::sort(newSectionListAll.begin(), newSectionListAll.end(), TGContactListSectionComparator);
    std::sort(newSectionListTelegraph.begin(), newSectionListTelegraph.end(), TGContactListSectionComparator);
    
    if ((_contactsMode & TGContactsModeMainContacts) == TGContactsModeMainContacts || ((_contactsMode & TGContactsModeCreateGroupOption) == TGContactsModeCreateGroupOption))
    {
        std::tr1::shared_ptr<TGContactListSection> serviceSection(new TGContactListSection());
        TGUser *serviceUser = [[TGUser alloc] init];
        serviceUser.uid = INT_MAX;
        serviceSection->addItem(serviceUser);
        serviceSection->letter = nil;
        newSectionListTelegraph.insert(newSectionListTelegraph.begin(), serviceSection);
        
        //if (((_contactsMode & TGContactsModeCreateGroupOption) == TGContactsModeCreateGroupOption))
        {
            serviceUser = [[TGUser alloc] init];
            serviceUser.uid = INT_MAX - 1;
            serviceSection->addItem(serviceUser);
            serviceSection->letter = nil;
        }
    }
    
    newSectionListTelegraph.insert(newSectionListTelegraph.end(), newSectionListAll.begin(), newSectionListAll.end());
    
    TGContactListSectionListHolder *holder = [[TGContactListSectionListHolder alloc] init];
    holder.sectionList = newSectionListTelegraph;
    
    NSArray *newIndices = ((_contactsMode & TGContactsModeCompose) == TGContactsModeCompose) || ((_contactsMode & TGContactsModeCreateGroupOption) == TGContactsModeCreateGroupOption) ? [self generateIndices:newSectionListTelegraph] : nil;
    
    dispatch_block_t mainThreadBlock =^
    {
        int selectedUid = 0;
        if (self.isViewLoaded)
        {
            if ([_tableView indexPathForSelectedRow] != nil)
            {
                NSIndexPath *indexPath = [_tableView indexPathForSelectedRow];
                if (indexPath.section < (int)_sectionList.size() && indexPath.row < (int)_sectionList[indexPath.section]->items.size())
                {
                    TGUser *user = _sectionList[indexPath.section]->items.at(indexPath.row);
                    selectedUid = user.uid;
                }
            }
        }
        
        _currentSortOrder = sortOrder;
        
        _sectionList = holder.sectionList;
        
        if (newIndices.count > 10)
            _sectionIndices = newIndices;
        else
            _sectionIndices = nil;
        
        if (self.isViewLoaded)
        {
            [_tableView reloadData];
            
            if (_selectAllOnce)
            {
                _selectAllOnce = false;
                [self selectAllButtonPressed];
            }
            
            [self updateSelectionInterface];
            
            if (selectedUid != 0)
            {
                int sectionIndex = -1;
                for (std::vector<std::tr1::shared_ptr<TGContactListSection> >::iterator it = _sectionList.begin(); it != _sectionList.end(); it++)
                {
                    sectionIndex++;
                    bool found = false;
                    
                    int itemIndex = -1;
                    for (std::vector<TGUser *>::iterator userIt = (*it)->items.begin(); userIt != (*it)->items.end(); userIt++)
                    {
                        itemIndex++;
                        
                        if ((*userIt).uid == selectedUid)
                        {
                            [_tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:itemIndex inSection:sectionIndex] animated:false scrollPosition:UITableViewScrollPositionNone];
                            
                            found = true;
                            break;
                        }
                    }
                    
                    if (found)
                        break;
                }
            }
            
            [_tableView layoutSubviews];
        }
        
        TGLog(@"Updated contact list");
    };
    
    if ([NSThread isMainThread])
        mainThreadBlock();
    else
        dispatch_async(dispatch_get_main_queue(), mainThreadBlock);
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)__unused scrollView
{
    [self clearFirstResponder:self.view];
}

- (void)clearFirstResponder:(UIView *)v
{
    if (v == nil)
        return;
    
    for (UIView *view in v.subviews)
    {
        if ([view isFirstResponder])
        {
            [view resignFirstResponder];
            return;
        }
        [self clearFirstResponder:view];
    }
}

@end

