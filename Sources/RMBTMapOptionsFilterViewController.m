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

#import "RMBTMapOptionsFilterViewController.h"

@interface RMBTMapOptionsFilterViewController () {
    NSArray *_activeFiltersAtStart;
    RMBTMapOptionsOverlay *_activeOverlayAtStart;
}
@end

@implementation RMBTMapOptionsFilterViewController

- (NSArray*)activeFilters {
    return [self.mapOptions.activeSubtype.type.filters bk_map:^id(RMBTMapOptionsFilter *f) {
        return f.activeValue;
    }];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // Store reference to active filters at start so we can determine if anything changed
    _activeFiltersAtStart = [self activeFilters];
    _activeOverlayAtStart = self.mapOptions.activeOverlay;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    BOOL changed = (_activeOverlayAtStart != self.mapOptions.activeOverlay) || ![[self activeFilters] isEqualToArray:_activeFiltersAtStart];
    [self.delegate mapSubViewController:self willDisappearWithChange:changed];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.mapOptions.activeSubtype.type.filters.count + 1 /* overlays */;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        return self.mapOptions.overlays.count;
    } else {
        return [self filterForSection:section].possibleValues.count;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellIdentifier = @"map_filter_cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];

    if (indexPath.section == 0) {
        // Overlays
        RMBTMapOptionsOverlay *overlay = [self.mapOptions.overlays objectAtIndex:indexPath.row];
        cell.textLabel.text = overlay.localizedDescription;
        cell.detailTextLabel.text = nil;
        cell.accessoryType = (self.mapOptions.activeOverlay == overlay) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    } else {
        // Filters
        RMBTMapOptionsFilter *filter = [self filterForSection:indexPath.section];
        
        RMBTMapOptionsFilterValue *value = [filter.possibleValues objectAtIndex:indexPath.row];
        
        cell.textLabel.text = value.title;
        
        if ([value.summary isEqualToString:value.title]) {
            cell.detailTextLabel.text = nil;
        } else {
            cell.detailTextLabel.text = value.summary;
        }
        
        cell.accessoryType = (filter.activeValue == value) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    }

    return cell;
}

- (NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return NSLocalizedString(@"Overlay", @"Table section header title");
    } else {
        return [[self filterForSection:section].title capitalizedString];
    }
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        RMBTMapOptionsOverlay *overlay = [self.mapOptions.overlays objectAtIndex:indexPath.row];
        if (overlay == self.mapOptions.activeOverlay) {
            // Do nothing
        } else {
            NSInteger previousRow = [self.mapOptions.overlays indexOfObject:self.mapOptions.activeOverlay];
            self.mapOptions.activeOverlay = overlay;
            [self.tableView reloadRowsAtIndexPaths:@[indexPath, [NSIndexPath indexPathForRow:previousRow inSection:indexPath.section]] withRowAnimation:UITableViewRowAnimationAutomatic];
        }
    } else {
        RMBTMapOptionsFilter *filter = [self filterForSection:indexPath.section];
        RMBTMapOptionsFilterValue *value = [self filterValueForIndexPath:indexPath];
        
        if (value == filter.activeValue) {
            // Do nothing
        } else {
            NSInteger previousRow = [filter.possibleValues indexOfObject:filter.activeValue];
            filter.activeValue = value;
            [self.tableView reloadRowsAtIndexPaths:@[indexPath, [NSIndexPath indexPathForRow:previousRow inSection:indexPath.section]] withRowAnimation:UITableViewRowAnimationAutomatic];
        }
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - Filter accessor

- (RMBTMapOptionsFilter*)filterForSection:(NSInteger)section {
    return [self.mapOptions.activeSubtype.type.filters objectAtIndex:section-1];
}

- (RMBTMapOptionsFilterValue*)filterValueForIndexPath:(NSIndexPath*)indexPath {
    RMBTMapOptionsFilter *filter = [self filterForSection:indexPath.section];
    return [filter.possibleValues objectAtIndex:indexPath.row];
}


@end
