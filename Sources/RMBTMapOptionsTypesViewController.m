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

#import "RMBTMapOptionsTypesViewController.h"

@implementation RMBTMapOptionsTypesViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.title = NSLocalizedString(@"Map type", @"Title of the map options subview");
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.mapOptions.types.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [[self.mapOptions.types objectAtIndex:section] subtypes].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    RMBTMapOptionsSubtype *s = [self subTypeAtIndexPath:indexPath];

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"map_type_cell" forIndexPath:indexPath];
    cell.textLabel.text = s.title;
    cell.detailTextLabel.text = s.summary;
    cell.accessoryType = [self.mapOptions.activeSubtype.identifier isEqualToString:s.identifier] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;

    return cell;
}

- (NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return [self.mapOptions.types objectAtIndex:section].title;
}

- (RMBTMapOptionsSubtype*)subTypeAtIndexPath:(NSIndexPath*)indexPath {
    return [[[self.mapOptions.types objectAtIndex:indexPath.section] subtypes] objectAtIndex:indexPath.row];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    self.mapOptions.activeSubtype = [self subTypeAtIndexPath:indexPath];
    [self.tableView reloadData];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [self.navigationController popViewControllerAnimated:YES];
    });
}

@end
