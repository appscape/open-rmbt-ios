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

#import "RMBTHistoryFilterViewController.h"

@interface RMBTHistoryFilterViewController () {
    NSArray *_keys;
    
    NSMutableSet *_activeIndexPaths;
    NSMutableSet *_allIndexPaths;
}
@end

@implementation RMBTHistoryFilterViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // Add long tap gesture recognizer to table view. On long tap, select tapped filter, while deselecting
    // all other filters from that group.
    
    UILongPressGestureRecognizer *longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc]
                                          initWithTarget:self action:@selector(tableViewDidReceiveLongPress:)];
    longPressGestureRecognizer.minimumPressDuration = 0.8; // seconds
    [self.tableView addGestureRecognizer:longPressGestureRecognizer];
    
    NSParameterAssert(self.allFilters);
    
    _keys = [self.allFilters allKeys];
    
    _activeIndexPaths = [NSMutableSet set];
    _allIndexPaths = [NSMutableSet set];
    
    for (NSUInteger i = 0; i<_keys.count; i++) {
        NSString *key = [_keys objectAtIndex:i];
        NSArray *values = [self.allFilters objectForKey:key];
        for (NSUInteger j = 0; j<values.count; j++) {
            NSIndexPath *ip = [NSIndexPath indexPathForRow:j inSection:i];
            [_allIndexPaths addObject:ip];

            if (!self.activeFilters) {
                [_activeIndexPaths addObject:ip];
            } else {
                NSArray *activeKeyValues = [self.activeFilters objectForKey:key];
                if (activeKeyValues && [activeKeyValues indexOfObject:[values objectAtIndex:j]] != NSNotFound) {
                    [_activeIndexPaths addObject:ip];
                }
            }
        }
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    if ([self.navigationController.viewControllers indexOfObject:self] == NSNotFound) {
        if ([_activeIndexPaths isEqualToSet:_allIndexPaths] || _activeIndexPaths.count == 0) {
            // Everything/nothing was selected, set nil
            _activeFilters = nil;
        } else {
            // Re-calculate active filters
            NSMutableDictionary *result = [NSMutableDictionary dictionary];
            
            for (NSIndexPath *ip in _activeIndexPaths) {
                NSString *key = [_keys objectAtIndex:ip.section];
                NSString *value = [[self.allFilters objectForKey:key] objectAtIndex:ip.row];
                
                NSMutableArray *entries = [result objectForKey:key];
                if (!entries) {
                    entries = [NSMutableArray arrayWithObject:value];
                    [result setObject:entries forKey:key];
                } else {
                    [entries addObject:value];
                }
            }
            
            _activeFilters = result;
        }
        [self performSegueWithIdentifier:@"pop" sender:self];
    }
    [super viewWillDisappear:animated];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return _keys.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSString *key = [_keys objectAtIndex:section];
    return ((NSArray*)[self.allFilters objectForKey:key]).count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"filter_cell" forIndexPath:indexPath];
    
    NSString *key = [_keys objectAtIndex:indexPath.section];
    NSArray *filters = [self.allFilters objectForKey:key];
    NSString *filter = [filters objectAtIndex:indexPath.row];
    
    cell.textLabel.text = filter;
    
    BOOL active = [_activeIndexPaths containsObject:indexPath];
    cell.accessoryType = active ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    
    return cell;
}

- (NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSString *key = [_keys objectAtIndex:section];
    if ([key isEqualToString:@"networks"]) {
        return NSLocalizedString(@"Network Type", @"Filter section title");
    } else if ([key isEqualToString:@"devices"]) {
        return NSLocalizedString(@"Device", @"Filter section title");
    } else {
        return key;
    }
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([_activeIndexPaths containsObject:indexPath]) {
        // Turn off
        
        // ..but check if this is the only active index in this section. If yes, then do nothing.
        BOOL lastActiveInSection = YES;
        for (NSIndexPath *i in _activeIndexPaths) {
            if (i.section == indexPath.section && i.row != indexPath.row) {
                lastActiveInSection = NO;
                break;
            }
        }
        
        if (lastActiveInSection) {
            [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
            return;
        }
        
        [_activeIndexPaths removeObject:indexPath];
    } else {
        // Turn on
        [_activeIndexPaths addObject:indexPath];
    }
    [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
}

#pragma mark - Long press handler

- (void)tableViewDidReceiveLongPress:(UILongPressGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
        CGPoint p = [gestureRecognizer locationInView:self.tableView];

        NSIndexPath *tappedIndexPath = [self.tableView indexPathForRowAtPoint:p];
        if (!tappedIndexPath) return;

        // Deactivate all entries in this section, exception long-tapped row
        for (NSIndexPath *i in _allIndexPaths) {
            if (i.section == tappedIndexPath.section) {
                [_activeIndexPaths removeObject:i];
            }
        }
        [_activeIndexPaths addObject:tappedIndexPath];
        
        [self.tableView reloadData];
    }
}

#pragma mark - IBActions

- (IBAction)clear:(id)sender {
    [_activeIndexPaths setSet:_allIndexPaths];
    [self.tableView reloadData];
}


@end
