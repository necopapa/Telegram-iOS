#import "TGAddContactsController.h"

/*#import <QuartzCore/QuartzCore.h>

#import "TGTabControllerChild.h"

#import "TGSearchBar.h"

#import "TGAddContactsNearbyCell.h"
#import "TGContactCell.h"
#import "TGContactsController.h"
#import "TGPeopleNearbyController.h"

#import "TGContactListRequestBuilder.h"

#import "TGDatabase.h"

#import "SGraphObjectNode.h"

#import "TGUserDataRequestBuilder.h"

#import "TGInterfaceManager.h"
#import "TGInterfaceAssets.h"

#import "TGViewController.h"
#import "TGActionTableView.h"

#import "TGHacks.h"
#import "TGImageUtils.h"
#import "TGTimer.h"

#import <AddressBook/AddressBook.h>

#include <set>

@interface TGAddContactsController () <TGViewControllerNavigationBarAppearance, TGTabControllerChild, UITableViewDataSource, UITableViewDelegate, UISearchDisplayDelegate>
{
    std::set<int> _remoteContactUids;
}

@property (nonatomic, strong) TGSearchBar *searchBar;
@property (nonatomic, strong) UISearchDisplayController *searchController;

@property (nonatomic, strong) TGActionTableView *tableView;

@property (nonatomic, strong) NSMutableArray *sectionsList;
@property (nonatomic, strong) NSMutableArray *unfilteredSuggestionsList;

@property (nonatomic) bool onceLoaded;

@property (nonatomic) bool contactListOnceLoaded;
@property (nonatomic) int contactListVersion;

@property (nonatomic, strong) NSMutableArray *searchListModel;
@property (nonatomic, strong) NSString *currentSearchString;
@property (nonatomic) bool searching;

@property (nonatomic) bool loadingContacts;

@property (nonatomic, strong) UIView *suggestionsHeader;

@end

@implementation TGAddContactsController

@synthesize actionHandle = _actionHandle;

@synthesize searchBar = _searchBar;
@synthesize searchController = _searchController;

@synthesize tableView = _tableView;

@synthesize sectionsList = _sectionsList;
@synthesize unfilteredSuggestionsList = _unfilteredSuggestionsList;

@synthesize onceLoaded = _onceLoaded;

@synthesize contactListOnceLoaded = _contactListOnceLoaded;
@synthesize contactListVersion = _contactListVersion;

@synthesize searchListModel = _searchListModel;
@synthesize currentSearchString = _currentSearchString;
@synthesize searching = _searching;

@synthesize loadingContacts = _loadingContacts;

@synthesize suggestionsHeader = _suggestionsHeader;

- (id)init
{
    self = [super initWithNibName:nil bundle:nil];
    if (self)
    {
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:true];
        
        _sectionsList = [[NSMutableArray alloc] init];
        _contactListVersion = -1;
        _searchListModel = [[NSMutableArray alloc] init];
        
        [ActionStageInstance() watchForPath:@"/tg/contactlist" watcher:self];
        [ActionStageInstance() watchForPath:@"/tg/userdatachanges" watcher:self];
        [ActionStageInstance() watchForPath:@"/tg/suggestedContacts" watcher:self];
    }
    return self;
}

- (void)dealloc
{
    [self doUnloadView];
    
    [_actionHandle reset];
    [ActionStageInstance() removeWatcher:self];
}

- (NSString *)controllerTitle
{
    return @"Add Contacts";
}

- (bool)navigationBarShouldBeHidden
{
    return _searchController.isActive;
}

- (UIBarStyle)requiredNavigationBarStyle
{
    return UIBarStyleDefault;
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

- (void)clearData
{
    _onceLoaded = false;
    
    [_sectionsList removeAllObjects];
    _contactListOnceLoaded = false;
    _contactListVersion = -1;
    
    _loadingContacts = false;
    
    [_tableView reloadData];
}

- (void)loadView
{
    [super loadView];
    
    self.view.layer.backgroundColor = [UIColor whiteColor].CGColor;
    
    self.titleText = @"Add Contacts";
    self.backAction = @selector(performClose);
    
    _searchBar = [[TGSearchBar alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 44)];
    _searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    
    _searchController = [[UISearchDisplayController alloc] initWithSearchBar:_searchBar contentsController:self];
    _searchController.delegate = self;
    _searchController.searchResultsDataSource = self;
    _searchController.searchResultsDelegate = self;
    
    _tableView = [[TGActionTableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [_tableView enableSwipeToLeftAction];
    [self.view addSubview:_tableView];
    
    [self clearInputFieldBackground:_searchBar andSetIcon:[[TGInterfaceAssets instance] dialogListSearchIcon]];
    [self hideStripe:_searchBar];
    
    if ([_searchBar respondsToSelector:@selector(setBackgroundImage:)])
        [_searchBar setBackgroundImage:[UIImage imageNamed:@"SearchBarBackground.png"]];
    
    _tableView.tableHeaderView = _searchBar;
    
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, -320, _tableView.frame.size.width, 320)];
    headerView.layer.backgroundColor = UIColorRGB(0xe4e9f0).CGColor;
    headerView.opaque = true;
    headerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [_tableView addSubview:headerView];
    
    _tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    
    {
        UIView *sectionContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
        sectionContainer.clipsToBounds = false;
        sectionContainer.opaque = false;
        
        UIImageView *sectionView = [[UIImageView alloc] initWithFrame:CGRectMake(0, -1, 10, 11)];
        sectionView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        sectionView.image = [UIImage imageNamed:@"CategoryDivider.png"];
        [sectionContainer addSubview:sectionView];
        
        UILabel *sectionLabel = [[UILabel alloc] init];
        sectionLabel.font = [UIFont boldSystemFontOfSize:15];
        sectionLabel.backgroundColor = [UIColor clearColor];
        sectionLabel.textColor = [UIColor whiteColor];
        sectionLabel.shadowColor = UIColorRGB(0x88929c);
        sectionLabel.shadowOffset = CGSizeMake(0, -1);
        sectionLabel.numberOfLines = 1;
        
        sectionLabel.text = @"Suggested contacts";
        [sectionLabel sizeToFit];
        sectionLabel.frame = CGRectOffset(sectionLabel.frame, 10, 1);
        
        [sectionContainer addSubview:sectionLabel];
        
        _suggestionsHeader = sectionContainer;
    }
}

- (void)performClose
{
    [self.navigationController popViewControllerAnimated:true];
}

- (void)performSwipeToLeftAction
{
    [self performClose];
}

- (void)doUnloadView
{
    _tableView.delegate = nil;
    _tableView = nil;
    _searchController.delegate = nil;
    _searchController = nil;
}
- (void)viewDidUnload
{
    [self doUnloadView];
    
    [super viewDidUnload];
}

- (void)viewWillAppear:(BOOL)animated
{
    if (!_onceLoaded)
    {
        _onceLoaded = true;
        [ActionStageInstance() requestActor:@"/tg/suggestedContacts/(cached)" options:nil watcher:self];
    }
    
    if (!_contactListOnceLoaded)
    {
        NSDictionary *cachedContactsResult = [TGContactListRequestBuilder synchronousContactList];
        if (cachedContactsResult == nil)
        {
            [ActionStageInstance() requestActor:@"/tg/contactlist/(contacts)" options:nil watcher:self];
        }
        else
        {
            [self actorCompleted:ASStatusSuccess path:@"/tg/contactlist/(contacts)" result:[[SGraphObjectNode alloc] initWithObject:cachedContactsResult]];
        }
    }
    
    if (_tableView.indexPathForSelectedRow != nil)
        [_tableView deselectRowAtIndexPath:[_tableView indexPathForSelectedRow] animated:true];
    
    if (_searchController.isActive && [_searchController.searchResultsTableView indexPathForSelectedRow] != nil)
        [_searchController.searchResultsTableView deselectRowAtIndexPath:[_searchController.searchResultsTableView indexPathForSelectedRow] animated:animated];
    
    [super viewWillAppear:animated];
}

#pragma mark -

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    if (tableView == _tableView)
    {
        if (section - 1 < (int)_sectionsList.count)
        {
            NSMutableArray *sectionDesc = [_sectionsList objectAtIndex:(section - 1)];
            int itemKind = [[sectionDesc objectAtIndex:0] intValue];
            if (itemKind == 2)
            {
                return _suggestionsHeader;
            }
        }
        
        return nil;
    }
    else
    {
        return nil;
    }
}

-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if (tableView == _tableView)
    {
        if (section > 0)
            return 25;
        
        return 0;
    }
    else
    {
        return 0;
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if (tableView == _tableView)
    {
        return 1 + _sectionsList.count;
    }
    else
    {
        return 1;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (tableView == _tableView)
    {
        if (section == 0)
            return 1;
        else if (section - 1 < (int)_sectionsList.count)
        {
            NSMutableArray *sectionDesc = [_sectionsList objectAtIndex:(section - 1)];
            return [[sectionDesc objectAtIndex:1] count];
        }
        
        return 0;
    }
    else
    {
        return MAX((int)_searchListModel.count, _searching ? 1 : 0);
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (tableView == _tableView)
    {
        if (indexPath.section == 0)
            return 60;
        return 51;
    }
    else
    {
        return 51;
    }
}

- (void)prepareContactCell:(TGContactCell *)contactCell user:(TGUser *)user itemKind:(int)itemKind animated:(bool)animated
{
    contactCell.itemId = user.uid;
    contactCell.itemKind = itemKind;
    
    contactCell.avatarUrl = user.photoUrlSmall;
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

    NSNumber *nMutualContactsCount = [user.customProperties objectForKey:@"mutualContactsCount"];
    int mutualCount = nMutualContactsCount == nil ? 0 : [nMutualContactsCount intValue];
    if (mutualCount == 0)
        contactCell.subtitleText = nil;
    else
        contactCell.subtitleText = [[NSString alloc] initWithFormat:@"%d mutual %s", [nMutualContactsCount intValue], mutualCount == 1 ? "contact" : "contacts"];
    
    [contactCell resetView:animated];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    bool useSearchResults = tableView != _tableView;
    
    if (!useSearchResults && indexPath.section == 0)
    {
        if (indexPath.row == 0)
        {
            static NSString *actionCellIdentifier = @"AC";
            TGAddContactsNearbyCell *nearbyCell = (TGAddContactsNearbyCell *)[tableView dequeueReusableCellWithIdentifier:actionCellIdentifier];
            if (nearbyCell == nil)
            {
                nearbyCell = [[TGAddContactsNearbyCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:actionCellIdentifier];
            }
            
            nearbyCell.badgeCount = 0;
            nearbyCell.isLoading = false;
            
            return nearbyCell;
        }
    }
    else if (useSearchResults || indexPath.section > 0)
    {
        TGUser *user = nil;
        int itemKind = 0;
        if (!useSearchResults)
        {
            if (indexPath.section - 1 < (int)_sectionsList.count)
            {
                NSMutableArray *sectionDesc = [_sectionsList objectAtIndex:(indexPath.section - 1)];
                itemKind = [[sectionDesc objectAtIndex:0] intValue];
                NSMutableArray *sectionItems = [sectionDesc objectAtIndex:1];
                if (indexPath.row < (int)sectionItems.count)
                    user = [sectionItems objectAtIndex:indexPath.row];
            }
        }
        else
        {
            if (indexPath.row < (int)_searchListModel.count)
                user = [_searchListModel objectAtIndex:indexPath.row];
            itemKind = 0;
        }
        
        if (user != nil)
        {
            static NSString *contactCellIdentifier = @"CC";
            TGContactCell *contactCell = (TGContactCell *)[tableView dequeueReusableCellWithIdentifier:contactCellIdentifier];
            if (contactCell == nil)
            {
                contactCell = [[TGContactCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:contactCellIdentifier];
                [contactCell setBoldMode:1 | 2];
                contactCell.actionHandle = _actionHandle;
            }
            
            [self prepareContactCell:contactCell user:user itemKind:itemKind animated:false];
            
            return contactCell;
        }
        else if (!useSearchResults)
        {
            static NSString *progressCellIdentifier = @"PC";
            UITableViewCell *progressCell = [tableView dequeueReusableCellWithIdentifier:progressCellIdentifier];
            if (progressCell == nil)
            {
                progressCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:progressCellIdentifier];
                UIActivityIndicatorView *activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
                progressCell.accessoryView = activityIndicator;
                progressCell.selectionStyle = UITableViewCellSelectionStyleNone;
                progressCell.textLabel.font = [UIFont systemFontOfSize:17];
                progressCell.textLabel.textColor = UIColorRGB(0x555555);
            }
            
            if (indexPath.section == 1)
            {
                progressCell.textLabel.text = _contactListOnceLoaded ? @"No Contacts" : @"Loading";
            }
            else if (indexPath.section == 1)
            {
                progressCell.textLabel.text = _onceLoaded ? @"No Suggestions" : @"Loading";
            }
            
            UIActivityIndicatorView *activityIndicator = (UIActivityIndicatorView *)progressCell.accessoryView;
            if (_onceLoaded)
            {
                activityIndicator.hidden = true;
                [activityIndicator stopAnimating];
            }
            else
            {
                activityIndicator.hidden = false;
                [activityIndicator startAnimating];
            }
            
            return progressCell;
        }
        else
        {
            static NSString *progressCellIdentifier = @"PC";
            UITableViewCell *progressCell = [tableView dequeueReusableCellWithIdentifier:progressCellIdentifier];
            if (progressCell == nil)
            {
                progressCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:progressCellIdentifier];
                UIActivityIndicatorView *activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
                progressCell.accessoryView = activityIndicator;
                progressCell.selectionStyle = UITableViewCellSelectionStyleNone;
                progressCell.textLabel.font = [UIFont systemFontOfSize:17];
                progressCell.textLabel.textColor = UIColorRGB(0x555555);
            }
            
            progressCell.textLabel.text = @"Loading";
            
            UIActivityIndicatorView *activityIndicator = (UIActivityIndicatorView *)progressCell.accessoryView;
            if (_searching)
            {
                activityIndicator.hidden = false;
                [activityIndicator startAnimating];
            }
            else
            {
                activityIndicator.hidden = true;
                [activityIndicator stopAnimating];
            }
            
            return progressCell;
        }
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

#pragma mark -

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (tableView == _tableView)
    {
        if (indexPath.section == 0)
        {
            if (indexPath.row == 0)
            {
                TGPeopleNearbyController *peopleNearbyController = [[TGPeopleNearbyController alloc] init];
                [self.navigationController pushViewController:peopleNearbyController animated:true];
            }
        }
        else
        {
            TGUser *user = nil;
            if (indexPath.section - 1 < (int)_sectionsList.count)
            {
                NSMutableArray *sectionDesc = [_sectionsList objectAtIndex:(indexPath.section - 1)];
                NSMutableArray *sectionItems = [sectionDesc objectAtIndex:1];
                if (indexPath.row < (int)sectionItems.count)
                    user = [sectionItems objectAtIndex:indexPath.row];
            }
            
            if (user != nil)
            {
                if([TGDatabaseInstance() loadUser:user.uid] == nil)
                    [TGUserDataRequestBuilder executeUserObjectsUpdate:[NSArray arrayWithObject:user]];
                
                [[TGInterfaceManager instance] navigateToProfileOfUser:user.uid];
                //[[TGInterfaceManager instance] navigateToConversationWithId:user.uid conversation:nil];
            }
        }
    }
    else
    {
        TGUser *user = nil;
        if (indexPath.row < (int)_searchListModel.count)
            user = [_searchListModel objectAtIndex:indexPath.row];
        if (user != nil)
        {
            [TGUserDataRequestBuilder executeUserObjectsUpdate:[NSArray arrayWithObject:user]];
            [[TGInterfaceManager instance] navigateToProfileOfUser:user.uid];
        }
    }
}

- (BOOL)searchDisplayController:(UISearchDisplayController *)__unused controller shouldReloadTableForSearchString:(NSString *)searchString
{
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        if (_currentSearchString != nil)
            [ActionStageInstance() removeWatcher:self fromPath:[NSString stringWithFormat:@"/tg/contacts/globalSearch/(%d)", [_currentSearchString hash]]];
        if (searchString.length == 0)
        {
            _currentSearchString = nil;
            
            dispatch_async(dispatch_get_main_queue(), ^
            {
                _searching = false;
                [_searchListModel removeAllObjects];
                if (_searchController.isActive)
                    [_searchController.searchResultsTableView reloadData];
            });
        }
        else
        {
            _currentSearchString = searchString;
            
            dispatch_async(dispatch_get_main_queue(), ^
            {
                _searching = true;
                if (_searchController.isActive)
                    [_searchController.searchResultsTableView reloadData];
            });
            
            [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/contacts/globalSearch/(%d)", [searchString hash]] options:[NSDictionary dictionaryWithObjectsAndKeys:searchString, @"query", nil] watcher:self];
        }
    }];
    
    return false;
}

- (void)searchDisplayController:(UISearchDisplayController *)__unused controller willShowSearchResultsTableView:(UITableView *)tableView
{
    tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
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

- (void)searchDisplayController:(UISearchDisplayController *)__unused controller willHideSearchResultsTableView:(UITableView *)__unused tableView
{
    [_searchListModel removeAllObjects];
}

- (void)searchDisplayControllerWillBeginSearch:(UISearchDisplayController *)__unused controller
{
    if (iosMajorVersion() >= 6)
    {
        [TGHacks setAnimationDurationFactor:1.25f];
        [self.navigationController setNavigationBarHidden:true animated:true];
        [TGHacks setAnimationDurationFactor:1.0f];
    }
}

- (void)searchDisplayControllerWillEndSearch:(UISearchDisplayController *)__unused controller
{
    if (iosMajorVersion() >= 6)
    {
        [TGHacks setAnimationDurationFactor:1.25f];
        [self.navigationController setNavigationBarHidden:false animated:true];
        [TGHacks setAnimationDurationFactor:1.0f];
    }
}

#pragma mark -

- (void)actionStageResourceDispatched:(NSString *)path resource:(id)resource arguments:(id)__unused arguments
{
    if ([path isEqualToString:@"/tg/contactlist"])
    {
        [self actorCompleted:ASStatusSuccess path:path result:resource];
    }
    else if ([path isEqualToString:@"/tg/userdatachanges"])
    {
        NSArray *users = ((SGraphObjectNode *)resource).object;
        
        dispatch_async(dispatch_get_main_queue(), ^
        {
            std::tr1::shared_ptr<std::map<int, int> > changedUidToIndex(new std::map<int, int>());
            int index = -1;
            for (TGUser *user in users)
            {
                index++;
                changedUidToIndex->insert(std::pair<int, int>(user.uid, index));
            }
            
            std::map<int, TGUser *> newUsers;
            
            int sectionIndex = -1;
            for (NSMutableArray *sectionDesc in _sectionsList)
            {
                sectionIndex++;
                NSMutableArray *items = [sectionDesc objectAtIndex:1];
                
                int count = items.count;
                for (int i = 0; i < count; i++)
                {
                    TGUser *user = [items objectAtIndex:i];
                    
                    std::map<int, int>::iterator it = changedUidToIndex->find(user.uid);
                    if (it != changedUidToIndex->end())
                    {
                        TGUser *newUser = [[users objectAtIndex:it->second] copy];
                        NSDictionary *customProperties = user.customProperties;
                        if (customProperties == nil)
                            customProperties = newUser.customProperties;
                        else if (newUser.customProperties != nil)
                        {
                            NSMutableDictionary *customProperties = [newUser.customProperties mutableCopy];
                            [customProperties addEntriesFromDictionary:newUser.customProperties];
                        }
                        newUser.customProperties = customProperties;
                        [items replaceObjectAtIndex:i withObject:newUser];
                        newUsers.insert(std::pair<int, TGUser *>(newUser.uid, newUser));
                    }
                }
            }
            
            for (UITableViewCell *cell in _tableView.visibleCells)
            {
                if ([cell isKindOfClass:[TGContactCell class]])
                {
                    TGContactCell *contactCell = (TGContactCell *)cell;
                    std::map<int, TGUser *>::iterator it = newUsers.find(contactCell.itemId);
                    if (it != newUsers.end())
                    {
                        [self prepareContactCell:contactCell user:it->second itemKind:contactCell.itemKind animated:true];
                    }
                }
            }
        });
    }
    else if ([path hasPrefix:@"/tg/suggestedContacts"])
    {
        [self actorCompleted:ASStatusSuccess path:path result:resource];
    }
}

- (void)replaceSection:(int)kind withArray:(NSArray *)array
{
    if (array.count == 0)
    {
        for (int i = 0; i < (int)_sectionsList.count; i++)
        {
            NSMutableArray *sectionDesc = [_sectionsList objectAtIndex:i];
            if ([[sectionDesc objectAtIndex:0] intValue] == kind)
            {
                [_sectionsList removeObjectAtIndex:i];
                [_tableView deleteSections:[NSIndexSet indexSetWithIndex:i + 1] withRowAnimation:UITableViewRowAnimationFade];
                [self hideStripe:_searchBar];
                break;
            }
        }
    }
    else
    {
        int foundIndex = -1;
        for (int i = 0; i < (int)_sectionsList.count; i++)
        {
            NSMutableArray *sectionDesc = [_sectionsList objectAtIndex:i];
            if ([[sectionDesc objectAtIndex:0] intValue] == kind)
            {
                foundIndex = i;
                break;
            }
        }
        if (foundIndex == -1)
        {
            if (kind == 2)
                foundIndex = _sectionsList.count;
            else if (kind == 1)
                foundIndex = 0;
            NSMutableArray *sectionDesc = [[NSMutableArray alloc] init];
            [sectionDesc addObject:[NSNumber numberWithInt:kind]];
            [sectionDesc addObject:[[NSMutableArray alloc] init]];
            [_sectionsList insertObject:sectionDesc atIndex:foundIndex];
            [_tableView insertSections:[NSIndexSet indexSetWithIndex:foundIndex + 1] withRowAnimation:UITableViewRowAnimationNone];
            [self hideStripe:_searchBar];
        }
        [[[_sectionsList objectAtIndex:foundIndex] objectAtIndex:1] removeAllObjects];
        [[[_sectionsList objectAtIndex:foundIndex] objectAtIndex:1] addObjectsFromArray:array];
        [_tableView reloadData];
    }
}

- (void)filterSuggestionsList
{
    if (_unfilteredSuggestionsList.count == 0)
        return;

    NSMutableArray *suggestionsList = [[NSMutableArray alloc] init];
    for (TGUser *user in _unfilteredSuggestionsList)
    {
        if (_remoteContactUids.find(user.uid) == _remoteContactUids.end())
        {
            [suggestionsList addObject:user];
        }
    }
    
    dispatch_async(dispatch_get_main_queue(), ^
    {
        [self replaceSection:2 withArray:suggestionsList];
    });
}

- (void)actorCompleted:(int)resultCode path:(NSString *)path result:(id)result
{
    if ([path hasPrefix:@"/tg/suggestedContacts"])
    {
        if (resultCode == ASStatusSuccess)
        {
            NSDictionary *resultDict = ((SGraphObjectNode *)result).object;
            _unfilteredSuggestionsList = [resultDict objectForKey:@"suggestedContacts"];
            
            _remoteContactUids.clear();
            std::vector<int> uids;
            [TGDatabaseInstance() loadRemoteContactUids:uids];
            for (std::vector<int>::iterator it = uids.begin(); it != uids.end(); it++)
                _remoteContactUids.insert(*it);
            
            [self filterSuggestionsList];
        }
    }
    else if ([path hasPrefix:@"/tg/contactlist"])
    {
        if (resultCode == ASStatusSuccess)
        {
            NSDictionary *resultDict = ((SGraphObjectNode *)result).object;
            int version = [[resultDict objectForKey:@"version"] intValue];
            if (version <= _contactListVersion)
                return;
            
            _contactListVersion = version;
            
            _remoteContactUids.clear();
            std::vector<int> uids;
            [TGDatabaseInstance() loadRemoteContactUids:uids];
            for (std::vector<int>::iterator it = uids.begin(); it != uids.end(); it++)
                _remoteContactUids.insert(*it);
            
            [self filterSuggestionsList];
        }
    }
    else if ([path isEqualToString:[NSString stringWithFormat:@"/tg/contacts/globalSearch/(%d)", [_currentSearchString hash]]])
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            if (resultCode == ASStatusSuccess)
            {
                NSDictionary *resultDict = ((SGraphObjectNode *)result).object;
                
                NSArray *usersFound = [resultDict objectForKey:@"foundUsers"];
                [_searchListModel removeAllObjects];
                if (usersFound != nil)
                    [_searchListModel addObjectsFromArray:usersFound];
            }
            
            _searching = false;
            if (_searchController.isActive)
                [_searchController.searchResultsTableView reloadData];
        });
    }
}

- (void)actionStageActionRequested:(NSString *)__unused action options:(NSDictionary *)__unused options
{
}

@end*/
