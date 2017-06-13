/*
 * Copyright 2017 appscape gmbh
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
