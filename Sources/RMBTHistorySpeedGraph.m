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

#import "RMBTHistorySpeedGraph.h"
#import "RMBTThroughput.h"
#import "RMBTSpeed.h"

@implementation RMBTHistorySpeedGraph

- (instancetype)initWithResponse:(NSArray*)response {
    if (self = [super init]) {
        __block uint64_t t = 0;
        __block uint64_t bytes = 0;
        _throughputs = [response bk_map:^id(NSDictionary *entry) {
            uint64_t end = [entry[@"time_elapsed"] longValue] * NSEC_PER_MSEC;
            uint64_t deltaBytes = [entry[@"bytes_total"] longValue] - bytes;
            RMBTThroughput *result = [[RMBTThroughput alloc] initWithLength:deltaBytes startNanos:t endNanos:end];
            t = end;
            bytes += deltaBytes;
            return result;
        }];
    }
    return self;
}

- (NSString*)description {
    return [[_throughputs bk_map:^id(RMBTThroughput *t) {
        return [NSString stringWithFormat:@"[%@ %@]", RMBTSecondsStringWithNanos(t.endNanos), RMBTSpeedMbpsString(t.kilobitsPerSecond)];
    }] componentsJoinedByString:@"-"];
}

@end
