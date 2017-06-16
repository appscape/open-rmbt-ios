//
//  RMBTHistorySpeedGraph.m
//  RMBT
//
//  Created by Esad Hajdarevic on 05/04/17.
//  Copyright © 2017 appscape gmbh. All rights reserved.
//

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
