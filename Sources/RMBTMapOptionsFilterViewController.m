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

#import "RMBTMapOptionsFilterViewController.h"

@interface RMBTMapOptionsFilterViewController ()

@end

@implementation RMBTMapOptionsFilterViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    NSParameterAssert(self.filter);

    self.navigationItem.title = self.filter.title;
}

#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.filter.possibleValues.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"map_options_filter_value_cell" forIndexPath:indexPath];
    RMBTMapOptionsFilterValue *value = [self.filter.possibleValues objectAtIndex:indexPath.row];

    cell.textLabel.text = value.title;
    cell.detailTextLabel.text = [value.summary isEqualToString:value.title] ? nil : value.summary;
    cell.accessoryType = (self.filter.activeValue == value) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    RMBTMapOptionsFilterValue *newValue = [self.filter.possibleValues objectAtIndex:indexPath.row];
    self.filter.activeValue = newValue;
    [self.tableView reloadData];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [self.navigationController popViewControllerAnimated:YES];
    });
}
@end
