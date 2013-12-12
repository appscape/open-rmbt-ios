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

#import <TUSafariActivity/TUSafariActivity.h>

#import "RMBTHistoryResultViewController.h"
#import "RMBTHistoryResultDetailsViewController.h"
#import "RMBTMapViewController.h"
#import "RMBTSettings.h"
#import "RMBTHistoryResultItemCell.h"

#import "UIViewController+ModalBrowser.h"

@implementation RMBTHistoryResultViewController

- (void)viewDidLoad {
    NSParameterAssert(_historyResult);

    [_historyResult ensureBasicDetails:^{
        NSAssert(_historyResult.dataState != RMBTHistoryResultDataStateIndex, @"Result not filled with basic data");
        
        if (CLLocationCoordinate2DIsValid(_historyResult.coordinate)) {
            self.mapButton.enabled = YES;
        }
        [self.tableView reloadData];
    }];

//    if (self.isModal) {
//        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone handler:^(id sender) {
//            [self dismissViewControllerAnimated:YES completion:^{}];
//        }];
//    }
}

- (void)trafficLightTapped:(NSNotification*)n {
    [self presentModalBrowserWithURLString:RMBT_HELP_RESULT_URL];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:NO];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(trafficLightTapped:) name:RMBTTrafficLightTappedNotification object:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return (_historyResult.dataState == RMBTHistoryResultDataStateIndex) ? 0 : 2;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString * const cellIdentifier = @"history_result";
    
    RMBTHistoryResultItem *item = [[self itemsForSection:indexPath.section] objectAtIndex:indexPath.row];
    
    RMBTHistoryResultItemCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[RMBTHistoryResultItemCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellIdentifier];
    }
    [cell setItem:item];
    return cell;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self itemsForSection:section].count;
}

- (NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case 0: return NSLocalizedString(@"Measurement", @"History result section title");
        case 1: return NSLocalizedString(@"Network", @"History result section title");
        default:
            NSAssert(false, @"Invalid section");
            return @"";
    }
}

- (NSArray*)itemsForSection:(NSUInteger)sectionIndex {
    NSAssert(sectionIndex <= 1, @"Invalid section");
    return (sectionIndex  == 0) ? _historyResult.measurementItems : _historyResult.netItems;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"show_result_details"]) {
        RMBTHistoryResultDetailsViewController *rdvc = segue.destinationViewController;
        rdvc.historyResult = self.historyResult;
    } else if ([segue.identifier isEqualToString:@"show_map"]) {
        NSAssert(CLLocationCoordinate2DIsValid(_historyResult.coordinate), @"Invalid coordinate but map button was enabled");
        if(CLLocationCoordinate2DIsValid(_historyResult.coordinate)) {
            // Set map options
            RMBTMapOptionsSelection* selection = [RMBTSettings sharedSettings].mapOptionsSelection;
            selection.activeFilters = nil;
            selection.overlayIdentifier = nil;
            selection.subtypeIdentifier = RMBTNetworkTypeIdentifier(_historyResult.networkType);

            RMBTMapViewController *mvc = segue.destinationViewController;
            mvc.hidesBottomBarWhenPushed = YES;
            mvc.initialLocation = [[CLLocation alloc] initWithLatitude:_historyResult.coordinate.latitude longitude:_historyResult.coordinate.longitude];
        }
    }
}

- (IBAction)share:(id)sender {
    NSMutableArray *activities = [NSMutableArray array];
    NSMutableArray *items = [NSMutableArray array];
    if (self.historyResult.shareText) [items addObject:self.historyResult.shareText];
    if (self.historyResult.shareURL) {
        [items addObject:self.historyResult.shareURL];
        [activities addObject:[[TUSafariActivity alloc] init]];
    }
    UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:items applicationActivities:activities];
    [activityViewController setValue:RMBTAppTitle() forKey:@"subject"];

    [self presentViewController:activityViewController animated:YES completion:nil];
}

@end
