//
//  RMBTQoSProgressViewController.m
//  RMBT
//
//  Created by Esad Hajdarevic on 12/12/16.
//  Copyright © 2016 appscape gmbh. All rights reserved.
//

#import "RMBTQoSProgressViewController.h"

@implementation RMBTQoSProgressCell

- (void)awakeFromNib {
    [super awakeFromNib];
    self.progressView.clipsToBounds = YES;
    self.progressView.layer.cornerRadius = 11.0f;
}

@end

@interface RMBTQoSProgressViewController () {
    NSMutableDictionary *_progressForGroupKey;
}
@end

@implementation RMBTQoSProgressViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)updateProgress:(float)progress forGroup:(RMBTQoSTestGroup*)group {
    NSParameterAssert(_progressForGroupKey);
    NSParameterAssert(self.testGroups);

    NSInteger index = [self.testGroups indexOfObject:group];
    if (index != NSNotFound) {
        [_progressForGroupKey setObject:[NSNumber numberWithFloat:progress] forKey:group.key];
        RMBTQoSProgressCell *cell = (RMBTQoSProgressCell *)[self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]];
        dispatch_async(dispatch_get_main_queue(), ^{
            [cell.progressView setProgress:progress animated:YES];
        });
    } else {
        NSParameterAssert(false);
    }
}

- (void)setTestGroups:(NSArray<RMBTQoSTestGroup *> *)testGroups {
    _testGroups = testGroups;
    _progressForGroupKey = [NSMutableDictionary dictionary];
    for (RMBTQoSTestGroup *g in testGroups) {
        [_progressForGroupKey setObject:[NSNumber numberWithFloat:0.0f] forKey:g.key];
    }
    [self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (!self.testGroups) { return 0; }
    return self.testGroups.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    RMBTQoSTestGroup *g = [_testGroups objectAtIndex:indexPath.row];

    RMBTQoSProgressCell *cell = (RMBTQoSProgressCell *)[tableView dequeueReusableCellWithIdentifier:@"qos_progress_cell" forIndexPath:indexPath];
    cell.progressView.progress = [_progressForGroupKey[g.key] floatValue];
    cell.descriptionLabel.text = g.localizedDescription;
    return cell;
}
@end
