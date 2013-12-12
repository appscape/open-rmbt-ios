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

#import "RMBTMapOptionsViewController.h"

@interface RMBTMapOptionsViewController() {
    RMBTMapOptionsSubtype *_activeSubtypeAtStart;
}
@end

@implementation RMBTMapOptionsViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    NSParameterAssert(self.mapOptions);

    // Save reference to active subtype so we can detect if anything changed when going back
    _activeSubtypeAtStart = self.mapOptions.activeSubtype;

    [self.mapViewTypeSegmentedControl setSelectedSegmentIndex:self.mapOptions.mapViewType];
}

- (void)viewWillDisappear:(BOOL)animated {
    [self.delegate mapSubViewController:self willDisappearWithChange:_activeSubtypeAtStart != self.mapOptions.activeSubtype];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    RMBTMapOptionsType *type = [self.mapOptions.types objectAtIndex:section];
    return type.subtypes.count;
}

- (NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    RMBTMapOptionsType *type = [self.mapOptions.types objectAtIndex:section];
    return type.title;
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"map_subtype_cell";
    
    RMBTMapOptionsType *type = [self.mapOptions.types objectAtIndex:indexPath.section];
    RMBTMapOptionsSubtype *subtype = [type.subtypes objectAtIndex:indexPath.row];
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
    cell.textLabel.text = subtype.title;
    cell.detailTextLabel.text = subtype.summary;
    
    if (subtype == self.mapOptions.activeSubtype) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    RMBTMapOptionsType *type = [self.mapOptions.types objectAtIndex:indexPath.section];
    RMBTMapOptionsSubtype *subtype = [type.subtypes objectAtIndex:indexPath.row];

    if (subtype == self.mapOptions.activeSubtype) {
        // No change, do nothing
    } else {
        NSInteger previousSection = [self.mapOptions.types indexOfObject:self.mapOptions.activeSubtype.type];
        NSInteger previousRow = [self.mapOptions.activeSubtype.type.subtypes indexOfObject:self.mapOptions.activeSubtype];
        
        self.mapOptions.activeSubtype = subtype;
        
        [self.tableView reloadRowsAtIndexPaths:@[indexPath, [NSIndexPath indexPathForRow:previousRow inSection:previousSection]] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.mapOptions.types.count;
}

- (IBAction)mapViewTypeSegmentedControlIndexDidChange:(id)sender {
    self.mapOptions.mapViewType = (RMBTMapOptionsMapViewType)self.mapViewTypeSegmentedControl.selectedSegmentIndex;
}
@end
