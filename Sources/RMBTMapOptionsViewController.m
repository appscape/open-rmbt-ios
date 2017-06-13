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
#import "RMBTMapOptionsTypesViewController.h"
#import "RMBTMapOptionsOverlaysViewController.h"
#import "RMBTMapOptionsFilterViewController.h"

@interface RMBTMapOptionsViewController() {
    RMBTMapOptionsSubtype *_activeSubtypeAtStart;
    NSArray *_activeFiltersAtStart;
    RMBTMapOptionsOverlay *_activeOverlayAtStart;

    NSIndexPath *_lastSelection;
}
@end

@implementation RMBTMapOptionsViewController

- (NSArray*)activeFilters {
    return [self.mapOptions.activeSubtype.type.filters bk_map:^id(RMBTMapOptionsFilter *f) {
        return f.activeValue;
    }];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    NSParameterAssert(self.mapOptions);

    _activeSubtypeAtStart = self.mapOptions.activeSubtype;
    _activeFiltersAtStart = [self activeFilters];
    _activeOverlayAtStart = self.mapOptions.activeOverlay;

    [self.mapViewTypeSegmentedControl setSelectedSegmentIndex:self.mapOptions.mapViewType];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    if (_lastSelection) {
        // Note that reloading the cell at index path would clear the selection right away.
        // We want the cell content to change, but w/o interrupting the default (.clearsSelectionOnViewWillAppear=YES)
        // deselection fade animation:
        [self updateCell:[self.tableView cellForRowAtIndexPath:_lastSelection] atIndexPath:_lastSelection];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    BOOL change = (_activeOverlayAtStart != self.mapOptions.activeOverlay) ||
        (_activeSubtypeAtStart != self.mapOptions.activeSubtype) ||
        ![[self activeFilters] isEqualToArray:_activeFiltersAtStart];

    [self.delegate mapOptionsViewController:self willDisappearWithChange:change];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.mapOptions.activeSubtype.type.filters.count + 2; // type + overlay
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"map_options_cell" forIndexPath:indexPath];
    NSParameterAssert(cell);

    [self updateCell:cell atIndexPath:indexPath];

    return cell;
}

- (void)updateCell:(UITableViewCell*)cell atIndexPath:(NSIndexPath*)indexPath {
    if (indexPath.row == 0) {
        cell.textLabel.text = NSLocalizedString(@"Map type", @"Section title in the map options view");
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@, %@", self.mapOptions.activeSubtype.type.title, self.mapOptions.activeSubtype.title];
    } else if (indexPath.row == 1) {
        cell.textLabel.text = NSLocalizedString(@"Overlay", @"Section title in the map options view");
        cell.detailTextLabel.text = self.mapOptions.activeOverlay.localizedDescription;
    } else {
        RMBTMapOptionsFilter *f = [self filterAtRow:indexPath.row];
        cell.textLabel.text = f.title;
        cell.detailTextLabel.text = f.activeValue.title;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == 0) {
        [self performSegueWithIdentifier:@"show_types" sender:indexPath];
    } else if (indexPath.row == 1) {
        [self performSegueWithIdentifier:@"show_overlays" sender:indexPath];
    } else {
        _lastSelection = indexPath;
        [self performSegueWithIdentifier:@"show_filter" sender:indexPath];
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (IBAction)mapViewTypeSegmentedControlIndexDidChange:(id)sender {
    self.mapOptions.mapViewType = (RMBTMapOptionsMapViewType)self.mapViewTypeSegmentedControl.selectedSegmentIndex;
}

#pragma mark - Segues

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    NSIndexPath *indexPath = (NSIndexPath*)sender;
    _lastSelection = indexPath;

    if ([segue.identifier isEqualToString:@"show_filter"]) {
        RMBTMapOptionsFilterViewController *vc = segue.destinationViewController;
        RMBTMapOptionsFilter *filter = [self filterAtRow:indexPath.row];
        vc.filter = filter;
    } else if ([segue.identifier isEqualToString:@"show_types"]) {
        RMBTMapOptionsTypesViewController *vc = segue.destinationViewController;
        vc.mapOptions = self.mapOptions;
    } else if ([segue.identifier isEqualToString:@"show_overlays"]) {
        RMBTMapOptionsOverlaysViewController *vc = segue.destinationViewController;
        vc.mapOptions = self.mapOptions;
    } else {
        NSParameterAssert(false);
    }
}

- (RMBTMapOptionsFilter*)filterAtRow:(NSUInteger)index {
    return [self.mapOptions.activeSubtype.type.filters objectAtIndex:index-2];
}

@end
