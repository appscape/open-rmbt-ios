/*
 * Copyright 2017 appscape gmbh
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

#import "RMBTLoopDetailsViewController.h"
#import "RMBTLoopDetailsCell.h"

@interface RMBTLoopDetailsViewController () {
    NSMutableDictionary<NSNumber*, NSString*> *_details;
}
@end

@implementation RMBTLoopDetailsViewController

- (void)setDetails:(NSString*)details forField:(RMBTLoopDetailsField)field {
    NSUInteger index = (NSUInteger)field;
    _details[@(index)] = details;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:index inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
    });
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.estimatedRowHeight = 31.0f;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    _details = [NSMutableDictionary dictionary];
}

- (NSString*)localizedNameForField:(RMBTLoopDetailsField)field {
    switch (field) {
        case RMBTLoopDetailsFieldNetworkType: return NSLocalizedString(@"Access", @"Loop mode details title");
        case RMBTLoopDetailsFieldNetworkName: return NSLocalizedString(@"Network", @"Loop mode details title");
        case RMBTLoopDetailsFieldTraffic: return NSLocalizedString(@"Data usage", @"Loop mode details title");
        case RMBTLoopDetailsFieldServer: return NSLocalizedString(@"Server", @"Loop mode details title");
        case RMBTLoopDetailsFieldLocation: return NSLocalizedString(@"Location", @"Loop mode details title");
        default:
            NSParameterAssert(false);
            return nil;
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return RMBTLoopDetailsFieldCount;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    RMBTLoopDetailsCell *cell = (RMBTLoopDetailsCell*)[tableView dequeueReusableCellWithIdentifier:@"loop_details_cell" forIndexPath:indexPath];
    NSUInteger field = (RMBTLoopDetailsField)indexPath.row;
    NSString *name = [self localizedNameForField:field];
    cell.fieldLabel.text = name;
    cell.detailsLabel.text = _details[@(field)] ?: @"-";
    [cell setCompact:self.compact];
    return cell;
}

@end
