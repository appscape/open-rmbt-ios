//
//  RMBTHistoryQoSSingleResultCell.m
//  RMBT
//
//  Created by Esad Hajdarevic on 12/12/16.
//  Copyright © 2016 appscape gmbh. All rights reserved.
//

#import "RMBTHistoryQoSSingleResultCell.h"

@implementation RMBTHistoryQoSSingleResultCell
- (void)setResult:(RMBTHistoryQoSSingleResult*)result sequenceNumber:(NSUInteger)number {
    self.sequenceNumberLabel.text = [NSString stringWithFormat:@"#%ld", (unsigned long)number];
    self.summaryLabel.text = result.summary;
    self.successImageView.image = result.statusIcon;
}
@end
