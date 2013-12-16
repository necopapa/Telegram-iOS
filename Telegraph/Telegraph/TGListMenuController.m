#import "TGListMenuController.h"

@interface TGListMenuController ()

@end

@implementation TGListMenuController

@synthesize tableView = _tableView;

- (id)init
{
    self = [super initWithNibName:nil bundle:nil];
    if (self)
    {
    }
    return self;
}

- (void)dealloc
{
    [self doUnloadView];
}

- (void)loadView
{
    [super loadView];
}

- (void)doUnloadView
{
    
}

- (void)viewDidUnload
{
    [self doUnloadView];
    
    [super viewDidUnload];
}

#pragma mark -

+ (UITableViewCell *)tableView:(UITableView *)__unused tableView cellForMenuItem:(TGMenuItem *)__unused item
{
    return nil;
}

@end
