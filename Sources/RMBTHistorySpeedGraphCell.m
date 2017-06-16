//
//  RMBTHistorySpeedGraphCell.m
//  RMBT
//
//  Created by Esad Hajdarevic on 06/04/17.
//  Copyright © 2017 appscape gmbh. All rights reserved.
//

#import "RMBTHistorySpeedGraphCell.h"
#import "RMBTSpeed.h"

@implementation RMBTHistorySpeedGraphCell

- (void)awakeFromNib {
    [super awakeFromNib];
    self.userInteractionEnabled = NO;
}

- (void)drawSpeedGraph:(RMBTHistorySpeedGraph*)graph {
    if (graph) {
        [self.activityView stopAnimating];
        [self.speedGraphView clear];
        for (RMBTThroughput* t in graph.throughputs) {
            [self.speedGraphView addValue:RMBTSpeedLogValue(t.kilobitsPerSecond) atTimeInterval:(double)t.endNanos/NSEC_PER_SEC];
        }
        self.speedGraphView.hidden = NO;
    } else {
        self.speedGraphView.hidden = YES;
        [self.activityView startAnimating];
    }
}
@end
