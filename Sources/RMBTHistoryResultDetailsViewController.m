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

#import "RMBTHistoryResultDetailsViewController.h"
#import "UITableViewCell+RMBTHeight.h"

@implementation RMBTHistoryResultDetailsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSParameterAssert(self.historyResult);

    [self.historyResult ensureFullDetails:^{
        [self.loadingIndicatorView stopAnimating];
        [self.tableView reloadData];
    }];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return (self.historyResult.dataState != RMBTHistoryResultDataStateFull) ? 0 : 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.historyResult.fullDetailsItems.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"history_result_detail";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellIdentifier];
    }
    
    RMBTHistoryResultItem *item = [self.historyResult.fullDetailsItems objectAtIndex:indexPath.row];
    cell.detailTextLabel.text = item.value;
    cell.textLabel.text = item.title;
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    RMBTHistoryResultItem *item = [self.historyResult.fullDetailsItems objectAtIndex:indexPath.row];
    return [UITableViewCell rmbtApproximateOptimalHeightForText:item.title detailText:item.value];
}

@end
