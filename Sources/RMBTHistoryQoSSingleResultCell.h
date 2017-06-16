//
//  RMBTHistoryQoSSingleResultCell.h
//  RMBT
//
//  Created by Esad Hajdarevic on 12/12/16.
//  Copyright © 2016 appscape gmbh. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "RMBTHistoryQoSSingleResult.h"

@interface RMBTHistoryQoSSingleResultCell : UITableViewCell
@property (nonatomic, weak) IBOutlet UILabel *sequenceNumberLabel;
@property (nonatomic, weak) IBOutlet UILabel *summaryLabel;
@property (nonatomic, weak) IBOutlet UIImageView *successImageView;

- (void)setResult:(RMBTHistoryQoSSingleResult*)result sequenceNumber:(NSUInteger)number;
@end
