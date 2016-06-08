/*
 * Copyright 2013 appscape gmbh
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */

#import "RMBTHistoryIndexViewController.h"
#import "RMBTHistoryResult.h"
#import "RMBTHistoryIndexCell.h"

#import "RMBTHistoryResultViewController.h"
#import "RMBTHistoryFilterViewController.h"

static NSUInteger const kBatchSize = 25; // Entries to fetch from server

static NSUInteger const kSyncSheetRequestCodeButtonIndex = 0;
static NSUInteger const kSyncSheetEnterCodeButtonIndex = 1;
static NSUInteger __attribute__((__unused__)) const kSyncSheetCancelButtonIndex = 2;

static NSString* const kIndexCellReuseIdentifier = @"RMBTHistoryIndexCell";

typedef NS_ENUM(NSUInteger, RMBTHistoryIndexViewControllerState) {
    RMBTHistoryIndexViewControllerStateLoading,
    RMBTHistoryIndexViewControllerStateEmpty,
    RMBTHistoryIndexViewControllerStateHasEntries
};

#define COLS 6
static CGFloat kColumnWidthsPre6[COLS]  = {40,50,80,50,50,50};
static CGFloat kColumnWidths6[COLS]     = {50,55,85,62,62,61};
static CGFloat kColumnWidths6Plus[COLS] = {50,76,90,66,66,66};

@interface RMBTHistoryIndexViewController ()<UIActionSheetDelegate, UIAlertViewDelegate> {
    UIAlertView *_enterCodeAlertView;
    UIView *_headerView;
    UIImage *_headerBackgroundImage;
    CGFloat _headerFilledWidth;
    
    NSMutableArray *_testResults;
    NSInteger _nextBatchIndex;
    
    NSDictionary *_allFilters;
    NSDictionary *_activeFilters;
    
    BOOL _loading;

    UITableViewController *_tableViewController;

    BOOL _firstAppearance;
    BOOL _showingLastTestResult;

    CGFloat *_columnWidths;
    BOOL _bigScreen;
}

@property (nonatomic, assign) RMBTHistoryIndexViewControllerState state;
@end

@implementation RMBTHistoryIndexViewController

- (void)awakeFromNib {
    [self.navigationController.tabBarItem setSelectedImage:[UIImage imageNamed:@"tab_history_selected"]];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    CGFloat screenWidth = [[UIScreen mainScreen] bounds].size.width;

    if (screenWidth == 375.0) {
        _bigScreen = YES;
        _columnWidths = kColumnWidths6;
    } else if (screenWidth == 414.0) {
        _bigScreen = YES;
        _columnWidths = kColumnWidths6Plus;
    } else {
        _bigScreen = NO;
        _columnWidths = kColumnWidthsPre6;
    }

    _firstAppearance = YES;
    
    _tableViewController = [[UITableViewController alloc]initWithStyle:UITableViewStylePlain];
    _tableViewController.tableView = self.tableView;
    _tableViewController.refreshControl = [[UIRefreshControl alloc] init];

    [_tableViewController didMoveToParentViewController:self];
    [_tableViewController.refreshControl addTarget:self action:@selector(refreshFromTableView) forControlEvents:UIControlEventValueChanged];

    CGFloat tabBarHeight = self.tabBarController.tabBar.frameHeight;

    // Add footer padding to compensate for tab bar
    UIView *footerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, self.tabBarController.tabBar.frameHeight)];
    footerView.backgroundColor = [UIColor clearColor];
	self.tableView.tableFooterView = footerView;
    [self.tableView registerNib:[UINib nibWithNibName:@"RMBTHistoryIndexCell" bundle:nil] forCellReuseIdentifier:kIndexCellReuseIdentifier];

    UIEdgeInsets e = self.tableView.scrollIndicatorInsets;
    e.bottom = tabBarHeight;
    self.tableView.scrollIndicatorInsets = e;

    [self addHeaderColumnWithWidth:_columnWidths[0] title:@"" identifier:@"network"];
    [self addHeaderColumnWithWidth:_columnWidths[1] title:NSLocalizedString(@"Date", @"History column") identifier:nil];
    [self addHeaderColumnWithWidth:_columnWidths[2] title:NSLocalizedString(@"Device", @"History column")identifier:@"device"];
    [self addHeaderColumnWithWidth:_columnWidths[3] title:@"Down" identifier:nil];
    [self addHeaderColumnWithWidth:_columnWidths[4] title:@"Up" identifier:nil];
    [self addHeaderColumnWithWidth:_columnWidths[5] title:@"Ping" identifier:nil];
}

- (void)setState:(RMBTHistoryIndexViewControllerState)state {
    self.loadingContainerView.hidden = YES;
    self.emptyLabel.hidden = YES;
    self.tableView.hidden = YES;
    self.filterButtonItem.enabled = NO;

    if (state == RMBTHistoryIndexViewControllerStateEmpty) {
        self.emptyLabel.hidden = NO;
    } else if (state == RMBTHistoryIndexViewControllerStateHasEntries) {
        self.tableView.hidden = NO;
        self.filterButtonItem.enabled = YES;
    } else if (state == RMBTHistoryIndexViewControllerStateLoading) {
        self.loadingContainerView.hidden = NO;
    }
}

- (void)refreshFilters {
    // Wait for UUID to be retrieved
    [[RMBTControlServer sharedControlServer] performWithUUID:^{
        [[RMBTControlServer sharedControlServer] getSettings:^{
            _allFilters = [RMBTControlServer sharedControlServer].historyFilters;
        } error:^(NSError *error, NSDictionary *info) {
            //TODO: handle error
        }];
    } error:^(NSError *error, NSDictionary *info) {
        // TODO: //handle error
    }];
}

- (void)refresh {
    [self setState:RMBTHistoryIndexViewControllerStateLoading];
    _testResults = [NSMutableArray array];
    _nextBatchIndex = 0;
    [self getNextBatch];
}

// Invoked by pull to refresh
- (void)refreshFromTableView {
    [_tableViewController.refreshControl beginRefreshing];
    _testResults = [NSMutableArray array];
    _nextBatchIndex = 0;
    [self getNextBatch];
}

- (void)getNextBatch {
    NSAssert(_nextBatchIndex != NSNotFound, @"Invalid batch");
    NSAssert(!_loading, @"getNextBatch Called twice");
    _loading = YES;
    BOOL firstBatch = (_nextBatchIndex == 0);
    NSUInteger offset = _nextBatchIndex * kBatchSize;
    [[RMBTControlServer sharedControlServer] getHistoryWithFilters:_activeFilters length:kBatchSize offset:offset success:^(NSArray* responses) {
        NSUInteger oldCount = _testResults.count;
        
        NSMutableArray *indexPaths = [NSMutableArray arrayWithCapacity:responses.count];
        NSMutableArray *results = [NSMutableArray arrayWithCapacity:responses.count];
        for (NSDictionary *r in responses) {
            [results addObject:[[RMBTHistoryResult alloc] initWithResponse:r]];
            [indexPaths addObject:[NSIndexPath indexPathForRow: oldCount-1 + results.count inSection:0]];
        }
        
        // We got less results than batch size, this means this was the last batch
        if (results.count < kBatchSize) {
            _nextBatchIndex = NSNotFound;
        } else {
            _nextBatchIndex += 1;
        }
        
        [_testResults addObjectsFromArray:results];
        
        if (firstBatch) {
            [self setState:(_testResults.count == 0) ? RMBTHistoryIndexViewControllerStateEmpty : RMBTHistoryIndexViewControllerStateHasEntries];
            [self.tableView reloadData];
        } else {
            [self.tableView beginUpdates];
            if (_nextBatchIndex == NSNotFound) {
                [self.tableView deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:oldCount inSection:0]] withRowAnimation:UITableViewRowAnimationFade];
            }
            if (indexPaths.count > 0) {
                [self.tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationFade];
            }
            [self.tableView endUpdates];
        }
        
        _loading = NO;

        [_tableViewController.refreshControl endRefreshing];
    } error:^(NSError *error, NSDictionary *info) {
        //TODO: handle loading error
    }];
}

- (void)tableView:(UITableView *)tableView
  willDisplayCell:(UITableViewCell *)cell
forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row >= (_testResults.count - 5)) {
        if (!_loading && _nextBatchIndex != NSNotFound) {
            [self getNextBatch];
        }
    }
}

- (void)addHeaderColumnWithWidth:(CGFloat)width
                           title:(NSString*)title
                      identifier:(NSString*)identifier
{
    if (!_headerView) _headerView = [[UIView alloc] initWithFrame:CGRectMake(0,0,self.view.frame.size.width, 36.0f)];
    if (!_headerBackgroundImage) {
        _headerBackgroundImage = [[UIImage imageNamed:@"table_column_header_ios7"] resizableImageWithCapInsets:UIEdgeInsetsMake(0, 0, 1, 1)];
    }
    
    UIButton* column = [UIButton buttonWithType:UIButtonTypeCustom];
    
    [column setBackgroundImage:_headerBackgroundImage forState:UIControlStateNormal];
    [column setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [column setTitle:title forState:UIControlStateNormal];
    column.titleLabel.font = [UIFont systemFontOfSize:14.0f];
    column.userInteractionEnabled = NO;
    column.frame = CGRectMake(_headerFilledWidth, 0, width, 36.0f);
    
    [_headerView addSubview:column];
    
    _headerFilledWidth += width;
}


- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    if (_firstAppearance) {
        _firstAppearance = NO;
        [self refresh];
        [self refreshFilters];
    } else {
        NSIndexPath *selectedIndexPath = self.tableView.indexPathForSelectedRow;
        if (selectedIndexPath) {
            [self.tableView deselectRowAtIndexPath:selectedIndexPath animated:YES];
        } else if (_showingLastTestResult) {
            // Note: This shouldn't be necessary once we have info required for index view in the
            // test result object. See -displayTestResult.
            _showingLastTestResult = NO;
            [self refresh];
            [self refreshFilters];
        }
    }
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    NSAssert(section == 0, @"Invalid section");
    return _headerView;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 36.0f;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSUInteger result = _testResults.count;
    if (_nextBatchIndex != NSNotFound) result += 1;
    return result;
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row >= _testResults.count) {
        // Loading cell
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"RMBTHistoryLoadingCell"];
        
        // We have to start animating manually, because after cell has been reused the activity indicator seems to stop
        [((UIActivityIndicatorView*)[cell viewWithTag:100]) startAnimating];
        
        return cell;
    } else {
        RMBTHistoryIndexCell *cell = [tableView dequeueReusableCellWithIdentifier:kIndexCellReuseIdentifier];
        NSParameterAssert(cell);

        [cell setColumnWidths:_columnWidths];
        
        RMBTHistoryResult *testResult = [_testResults objectAtIndex:indexPath.row];

        cell.networkTypeLabel.text = testResult.networkTypeServerDescription;
        cell.dateLabel.text = [testResult formattedTimestamp];
        if (_bigScreen) {
            cell.dateLabel.text = [cell.dateLabel.text stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
        }
        
        cell.deviceModelLabel.text = testResult.deviceModel;
        cell.downloadSpeedLabel.text = testResult.downloadSpeedMbpsString;
        cell.uploadSpeedLabel.text = testResult.uploadSpeedMbpsString;
        cell.pingLabel.text = testResult.shortestPingMillisString;

        return cell;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    RMBTHistoryResult *result = [_testResults objectAtIndex:indexPath.row];
    [self performSegueWithIdentifier:@"show_result" sender:result];
}

#pragma mark - Sync

- (void)sync:(id)sender {
    NSString * title = NSLocalizedString(@"To merge history from two different devices, request the sync code on one device and enter it on another device", @"Sync intro text");
    
    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:title
                                                             delegate:self
                                                    cancelButtonTitle:NSLocalizedString(@"Cancel", @"Sync dialog button")
                                               destructiveButtonTitle:nil
                                                     otherButtonTitles:NSLocalizedString(@"Request code", @"Sync dialog button"),
                                                                       NSLocalizedString(@"Enter code", @"Sync dialog button"), nil];
    [actionSheet showInView:self.view];
}

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (buttonIndex == kSyncSheetRequestCodeButtonIndex) {
        [[RMBTControlServer sharedControlServer] getSyncCode:^(NSString* code) {
            [UIAlertView bk_showAlertViewWithTitle:NSLocalizedString(@"Sync Code", @"Display code alert title")
                                        message:code
                              cancelButtonTitle:NSLocalizedString(@"OK", @"Display code alert button")
                              otherButtonTitles:@[NSLocalizedString(@"Copy code", @"Display code alert button")]
                                        handler:^(UIAlertView *alertView, NSInteger buttonIndex) {
                if (buttonIndex == 1) {
                    // Copy
                    [[UIPasteboard generalPasteboard] setString:code];
                } // else just dismiss
            }];
        } error:^(NSError *error, NSDictionary *info) {
            //TODO: handle error
        }];
    } else if (buttonIndex == kSyncSheetEnterCodeButtonIndex) {
        _enterCodeAlertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Enter sync code:", @"Sync alert title")
                                                         message:nil
                                                        delegate:self
                                               cancelButtonTitle:NSLocalizedString(@"Cancel", @"Sync alert button")
                                               otherButtonTitles:NSLocalizedString(@"Sync", @"Sync alert button"), nil];
        _enterCodeAlertView.alertViewStyle = UIAlertViewStylePlainTextInput;
        [_enterCodeAlertView show];
    } else {
        NSAssert(buttonIndex == kSyncSheetCancelButtonIndex, @"Action sheet dismissed with unknown button index");
    }
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (alertView == _enterCodeAlertView && buttonIndex == 1) {
        NSString* code = [[alertView textFieldAtIndex:0].text uppercaseString];

        [[RMBTControlServer sharedControlServer] syncWithCode:code success:^{
            [UIAlertView bk_showAlertViewWithTitle:NSLocalizedString(@"Success", @"Sync success alert title")
                                      message:NSLocalizedString(@"History synchronisation was successful.", @"Sync success alert msg")
                            cancelButtonTitle:NSLocalizedString(@"Reload", @"Sync success button")
                            otherButtonTitles:nil
                                        handler:^(UIAlertView *alertView, NSInteger buttonIndex) {
                                            [self refresh];
                                            [self refreshFilters];
                                        }];
        } error:^(NSError *error, NSDictionary *response) {
            NSString *title = error.userInfo[@"msg_title"];
            NSString *text = error.userInfo[@"msg_text"];
            [UIAlertView bk_showAlertViewWithTitle:title message:text cancelButtonTitle:NSLocalizedString(@"Dismiss",@"Alert view button") otherButtonTitles:@[] handler:^(UIAlertView *alertView, NSInteger buttonIndex) {
                
            }];
        }];
    }
}

#pragma mark - Segues

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"show_result"]) {
        RMBTHistoryResultViewController* rvc = segue.destinationViewController;
        rvc.historyResult = sender;
    } else if ([segue.identifier isEqualToString:@"show_filter"]) {
        RMBTHistoryFilterViewController* filterVC = segue.destinationViewController;
        filterVC.allFilters = _allFilters;
        filterVC.activeFilters = _activeFilters;
    }
}

- (IBAction)updateFilters:(UIStoryboardSegue*)segue {
    RMBTHistoryFilterViewController *filterVC = segue.sourceViewController;
    _activeFilters = filterVC.activeFilters;
    [self refresh];
}

- (void)displayTestResult:(RMBTHistoryResult*)result {
    [self.navigationController popToRootViewControllerAnimated:NO];

// Currently simply adding a result to history after the test won't work as we have
// no details needed for the table after the test!

//    NSIndexPath *firstRow = [NSIndexPath indexPathForRow:0 inSection:0];
//
//    [_testResults insertObject:result atIndex:0];
//    [self.tableView beginUpdates];
//    [self.tableView insertRowsAtIndexPaths:@[firstRow] withRowAnimation:UITableViewRowAnimationNone];
//    [self.tableView endUpdates];
//
//    [self.tableView selectRowAtIndexPath:firstRow animated:NO scrollPosition:UITableViewScrollPositionNone];

    _showingLastTestResult = YES;

    RMBTHistoryResultViewController *resultVC = [self.storyboard instantiateViewControllerWithIdentifier:@"result_vc"];
    resultVC.historyResult = result;
    [self.navigationController pushViewController:resultVC animated:NO];
}
@end
