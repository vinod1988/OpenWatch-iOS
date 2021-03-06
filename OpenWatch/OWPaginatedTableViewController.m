//
//  OWPaginatedTableViewController.m
//  OpenWatch
//
//  Created by Christopher Ballinger on 1/22/13.
//  Copyright (c) 2013 OpenWatch FPC. All rights reserved.
//

#import "OWPaginatedTableViewController.h"
#import "OWMediaObjectTableViewCell.h"
#import "OWUtilities.h"
#import "OWLocalMediaController.h"
#import "OWPhoto.h"
#import "OWLocalRecording.h"
#import "OWInvestigation.h"
#import "OWAudio.h"
#import "OWFeedViewController.h"
#import "OWStrings.h"
#import "OWSocialController.h"
#import "OWMapAnnotation.h"
#import "OWMapViewController.h"
#import "OWAppDelegate.h"
#import "PKRevealController.h"
#import "OWAccountAPIClient.h"

#define kLoadingCellTag 31415

@interface OWPaginatedTableViewController ()

@end

@implementation OWPaginatedTableViewController
@synthesize refreshHeaderView = _refreshHeaderView;
@synthesize isReloading;
@synthesize currentPage;
@synthesize totalPages;
@synthesize objectIDs, selectedMediaObject;
@synthesize tableView;

- (id)init
{
    self = [super init];
    if (self) {
    }
    return self;
}

- (void) loadView {
    [super loadView];
    self.tableView = [[UITableView alloc] init];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    
    self.tableView.backgroundColor = [OWUtilities stoneBackgroundPattern];
    currentPage = 0;
    
    NSArray *objectTypes = @[[OWLocalMediaObject class], [OWLocalRecording class], [OWManagedRecording class], [OWPhoto class], [OWInvestigation class], [OWAudio class]];
    for (Class class in objectTypes) {
        [self.tableView registerClass:[class cellClass] forCellReuseIdentifier:[class cellIdentifier]];
    }
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.tableView.frame = self.view.bounds;
}


- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.view addSubview:tableView];
    self.tableView.frame = self.view.bounds;
	if (_refreshHeaderView == nil) {
        EGORefreshTableHeaderView *view = [[EGORefreshTableHeaderView alloc] initWithFrame:CGRectMake(0.0f, 0.0f - self.tableView.bounds.size.height, self.view.frame.size.width, self.tableView.bounds.size.height)];
		view.delegate = self;
        view.backgroundColor = [UIColor clearColor];
		[self.tableView addSubview:view];
		_refreshHeaderView = view;  
	}
	[_refreshHeaderView refreshLastUpdatedDate];
}

#pragma mark -
#pragma mark Data Source Loading / Reloading Methods

- (void)reloadTableViewDataSource {
	isReloading = YES;
}

- (void)doneLoadingTableViewData {
    isReloading = NO;
	[_refreshHeaderView egoRefreshScrollViewDataSourceDidFinishedLoading:self.tableView];
}


#pragma mark -
#pragma mark UIScrollViewDelegate Methods

- (void)scrollViewDidScroll:(UIScrollView *)scrollView{
	[_refreshHeaderView egoRefreshScrollViewDidScroll:scrollView];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate{
	[_refreshHeaderView egoRefreshScrollViewDidEndDragging:scrollView];
}


#pragma mark -
#pragma mark EGORefreshTableHeaderDelegate Methods

- (void)egoRefreshTableHeaderDidTriggerRefresh:(EGORefreshTableHeaderView*)view{
	
	[self reloadTableViewDataSource];	
}

- (BOOL)egoRefreshTableHeaderDataSourceIsLoading:(EGORefreshTableHeaderView*)view{
	return isReloading;
}

- (NSDate*)egoRefreshTableHeaderDataSourceLastUpdated:(EGORefreshTableHeaderView*)view{
	return [NSDate date];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (currentPage == 0) {
        return 0;
    }
    if (currentPage == 1 && self.objectIDs.count == 0) {
        return 1;
    }
    
    if (currentPage >= totalPages) {
        return self.objectIDs.count;
    }
    return self.objectIDs.count + 1;
}


- (OWMediaObjectTableViewCell*) mediaObjectCellForIndexPath:(NSIndexPath *)indexPath {
    NSManagedObjectID *objectID = [self.objectIDs objectAtIndex:indexPath.row];
    NSManagedObjectContext *context = [NSManagedObjectContext MR_contextForCurrentThread];
    OWMediaObject *mediaObject = (OWMediaObject*)[context existingObjectWithID:objectID error:nil];
    OWMediaObjectTableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:[[mediaObject class] cellIdentifier] forIndexPath:indexPath];
    cell.mediaObjectID = objectID;
    cell.delegate = self;
    if ([mediaObject isKindOfClass:[OWManagedRecording class]]) {
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    } else {
        cell.selectionStyle = UITableViewCellSelectionStyleGray;
    }
    return cell;
}

- (void) tableCell:(OWMediaObjectTableViewCell *)cell didSelectHashtag:(NSString *)hashTag {
    OWFeedViewController *feed = [[OWFeedViewController alloc] init];
    [feed didSelectFeedWithName:hashTag displayName:hashTag type:kOWFeedTypeTag];
    [self.navigationController pushViewController:feed animated:YES];
}

- (void) moreButtonPressedForTableCell:(OWMediaObjectTableViewCell *)cell {
    NSManagedObjectContext *context = [NSManagedObjectContext MR_contextForCurrentThread];
    self.selectedMediaObject = (OWMediaObject*)[context existingObjectWithID:cell.mediaObjectID error:nil];
    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:nil destructiveButtonTitle:REPORT_STRING otherButtonTitles:SHARE_STRING, nil];
    NSUInteger cancelButtonIndex = 2;
    if ([selectedMediaObject isKindOfClass:[OWLocalMediaObject class]]) {
        OWLocalMediaObject *local = (OWLocalMediaObject*)selectedMediaObject;
        CLLocation *endLocation = [local endLocation];
        if (endLocation) {
            [actionSheet addButtonWithTitle:VIEW_ON_MAP_STRING];
            cancelButtonIndex++;
        }
    }
    [actionSheet addButtonWithTitle:CANCEL_STRING];
    actionSheet.cancelButtonIndex = cancelButtonIndex;
    
    [actionSheet showInView:self.view];
}

- (void) actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (buttonIndex == actionSheet.cancelButtonIndex) {
        return;
    }
    if (buttonIndex == actionSheet.destructiveButtonIndex) {
        OWMediaObject *media = (OWMediaObject*)selectedMediaObject;
        [[OWAccountAPIClient sharedClient] reportMediaObject:media];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:CONTENT_REPORTED_STRING message:REPORT_SUCCESS_STRING delegate:nil cancelButtonTitle:OK_STRING otherButtonTitles:nil];
        [alert show];
    }
    if (buttonIndex == 1) { // Share
        [OWSocialController shareMediaObject:self.selectedMediaObject fromViewController:self];
    } else if (buttonIndex == 2) { // View on Map
        OWLocalMediaObject *local = (OWLocalMediaObject*)selectedMediaObject;
        CLLocation *endLocation = [local endLocation];
        OWMapAnnotation *annotation = [[OWMapAnnotation alloc] initWithCoordinate:endLocation.coordinate title:local.titleOrHumanizedDateString subtitle:nil];
        OWMapViewController *mapView = [[OWMapViewController alloc] init];
        mapView.title = local.metroCode;
        mapView.annotation = annotation;
        [self.navigationController pushViewController:mapView animated:YES];
    }
}


- (UITableViewCell *)loadingCell {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                    reuseIdentifier:nil];
    
    UIActivityIndicatorView *activityIndicator = [[UIActivityIndicatorView alloc]
                                                  initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    activityIndicator.center = cell.center;
    [cell addSubview:activityIndicator];
    
    [activityIndicator startAnimating];
    
    cell.tag = kLoadingCellTag;
    
    return cell;
}

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row >= self.objectIDs.count) {
        return 45.0f;
    }
    NSManagedObjectID *objectID = [self.objectIDs objectAtIndex:indexPath.row];
    NSManagedObjectContext *context = [NSManagedObjectContext MR_contextForCurrentThread];
    OWMediaObject *mediaObject = (OWMediaObject*)[context existingObjectWithID:objectID error:nil];
    return [OWMediaObjectTableViewCell cellHeightForMediaObject:mediaObject];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row < self.objectIDs.count) {
        return [self mediaObjectCellForIndexPath:indexPath];
    } else {
        return [self loadingCell];
    }
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (cell.tag == kLoadingCellTag && currentPage <= totalPages) {
        currentPage++;
        [self fetchObjectsForPageNumber:currentPage];
    }
}

- (void) reloadFeed:(NSArray*)recordings replaceObjects:(BOOL)replaceObjects {
    if (replaceObjects) {
        self.objectIDs = [NSMutableArray arrayWithArray:recordings];
    } else {
        [self.objectIDs addObjectsFromArray:recordings];
    }
    [self.tableView reloadData];
    
	[self doneLoadingTableViewData];
}

- (void) failedToLoadFeed:(NSString*)reason {
    [self doneLoadingTableViewData];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    return (toInterfaceOrientation == UIInterfaceOrientationPortrait);
}

- (BOOL)shouldAutorotate {
    return NO;
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

- (void) fetchObjectsForPageNumber:(NSUInteger)pageNumber {}


@end
