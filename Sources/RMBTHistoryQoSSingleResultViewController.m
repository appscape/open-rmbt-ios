//
//  RMBTHistoryQoSSingleResultViewController.m
//  RMBT
//
//  Created by Esad Hajdarevic on 20/12/16.
//  Copyright © 2016 appscape gmbh. All rights reserved.
//

#import "RMBTHistoryQoSSingleResultViewController.h"

@interface RMBTHistoryQoSSingleResultViewController ()

@end

@implementation RMBTHistoryQoSSingleResultViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    NSParameterAssert(self.result);
    self.title = [NSString stringWithFormat:@"Test #%ld", (unsigned long)self.seqNumber];
    self.tableView.estimatedRowHeight = 140.0;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.statusIconImageView.image = self.result.statusIcon;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        return 1;
    } else if (section == 1) {
        return 1;
    } else {
        NSAssert1(false, @"Unexpected section index %ld", section);
        return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"details_cell" forIndexPath:indexPath];
    if (indexPath.section == 0) {
        cell.textLabel.text = self.result.statusDetails;
    } else {
        cell.textLabel.text = self.result.details;
    }
    return cell;
}

- (nullable NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        if(self.result.successful) {
            return NSLocalizedString(@"Test Succeeded", @"Section header for successful test");
        } else {
            return NSLocalizedString(@"Test Failed", @"Section header for successful test");
        }
    } else if (section == 1) {
        return NSLocalizedString(@"Details", @"Section header");
    } else {
        NSAssert1(false, @"Unexpected section index %ld", section);
        return nil;
    }
}

@end
