//
//  RMBTHistorySpeedGraphCell.h
//  RMBT
//
//  Created by Esad Hajdarevic on 06/04/17.
//  Copyright © 2017 appscape gmbh. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "RMBTSpeedGraphView.h"
#import "RMBTHistorySpeedGraph.h"

@interface RMBTHistorySpeedGraphCell : UITableViewCell
@property (nonatomic, readwrite) IBOutlet UIActivityIndicatorView *activityView;
@property (nonatomic, readwrite) IBOutlet RMBTSpeedGraphView *speedGraphView;
- (void)drawSpeedGraph:(RMBTHistorySpeedGraph*)graph;
@end
