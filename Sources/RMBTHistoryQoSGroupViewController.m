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

#import "RMBTHistoryQoSGroupViewController.h"
#import "RMBTHistoryQoSSingleResultCell.h"
#import "RMBTHistoryQoSSingleResultViewController.h"

@implementation RMBTHistoryQoSGroupViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    NSParameterAssert(self.result);
    self.title = self.result.name;
    self.tableView.estimatedRowHeight = 140.0;
    self.tableView.rowHeight = UITableViewAutomaticDimension;

    [self.tableView registerNib:[UINib nibWithNibName:@"RMBTHistoryQoSSingleResultCell" bundle:nil] forCellReuseIdentifier:@"qos_single_result_cell"];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        return 1;
    } else {
        return self.result.tests.count;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        UITableViewCell *descriptionCell = [tableView dequeueReusableCellWithIdentifier:@"qos_group_about_cell" forIndexPath:indexPath];
        descriptionCell.textLabel.text = self.result.about;
        return descriptionCell;
    } else if (indexPath.section == 1) {
        RMBTHistoryQoSSingleResultCell *cell = (RMBTHistoryQoSSingleResultCell*)[tableView dequeueReusableCellWithIdentifier:@"qos_single_result_cell" forIndexPath:indexPath];
        RMBTHistoryQoSSingleResult *r = [self.result.tests objectAtIndex:indexPath.row];
        [cell setResult:r sequenceNumber:indexPath.row+1];
        return cell;
    } else {
        NSParameterAssert(false);
        return nil;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 1) {
        [self performSegueWithIdentifier:@"show_qos_single_result" sender:[self.result.tests objectAtIndex:indexPath.row]];
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return NSLocalizedString(@"About", @"QoS Details section header");
    } else {
        return NSLocalizedString(@"Tests", "QoS Details section header");
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"show_qos_single_result"]) {
        RMBTHistoryQoSSingleResultViewController *vc = (RMBTHistoryQoSSingleResultViewController*)segue.destinationViewController;
        RMBTHistoryQoSSingleResult *r = (RMBTHistoryQoSSingleResult*)sender;
        vc.result = r;
        vc.seqNumber = [self.result.tests indexOfObject:r]+1;
    }
}
@end
