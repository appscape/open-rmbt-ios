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

#import "RMBTThroughputHistory.h"
#import "RMBTThroughput.h"

@interface RMBTThroughputHistory() {
    NSMutableArray *_periods;
}
@end

@implementation RMBTThroughputHistory

- (instancetype)initWithResolutionNanos:(uint64_t)ns {
    if (self = [super init]) {
        _lastFrozenPeriodIndex = -1;
        _resolutionNanos = ns;
        _periods = [NSMutableArray array];
        _totalThroughput = [[RMBTThroughput alloc] initWithLength:0 startNanos:0 endNanos:0];
    }
    return self;
}

- (void)addLength:(uint64_t)length atNanos:(uint64_t)timestampNanos {
    NSAssert(!_isFrozen, @"Tried adding to frozen history");
    
    _totalThroughput.length += length;
    _totalThroughput.endNanos = MAX(_totalThroughput.endNanos, timestampNanos);

    if (_periods.count == 0) {
        // Create first period
        [_periods addObject:[[RMBTThroughput alloc] initWithLength:0 startNanos:0 endNanos:0]];
    }
    
    uint64_t leftoverLength = length;
    
    NSUInteger startPeriodIndex = _periods.count - 1;
    NSUInteger endPeriodIndex = (NSUInteger)(timestampNanos / _resolutionNanos);
    if (timestampNanos - (_resolutionNanos * endPeriodIndex) == 0) endPeriodIndex -= 1; // Boundary condition

    NSAssert((int)startPeriodIndex > _lastFrozenPeriodIndex, @"Start period %lu < %ld", (unsigned long)startPeriodIndex, (long)_lastFrozenPeriodIndex);
    NSAssert((int)endPeriodIndex > _lastFrozenPeriodIndex, @"End period %lu < %ld", (unsigned long)endPeriodIndex, (long)_lastFrozenPeriodIndex);
        
    RMBTThroughput *startPeriod = [_periods objectAtIndex:startPeriodIndex];
    
    uint64_t transferNanos = timestampNanos - startPeriod.endNanos;
    NSAssert(transferNanos > 0, @"Transfer happened before last reported transfer?");

    uint64_t lengthPerPeriod = length * (double)_resolutionNanos/transferNanos;
    
    if (startPeriodIndex == endPeriodIndex) {
        // Just add to the start period
        startPeriod.length += length;
        startPeriod.endNanos = timestampNanos;
    } else {
        // Attribute part to the start period, except if we started on the boundary
        if (startPeriod.endNanos < (startPeriodIndex+1)*_resolutionNanos) {
            uint64_t startLength = length * (double)(_resolutionNanos - (startPeriod.endNanos % _resolutionNanos))/transferNanos;
            startPeriod.length += startLength;
            startPeriod.endNanos = (startPeriodIndex+1)*_resolutionNanos;
            leftoverLength -= startLength;
        }
    
        // Create periods in between
        for (NSUInteger i=startPeriodIndex+1;i<endPeriodIndex; i++) {
            leftoverLength -= lengthPerPeriod;
            [_periods addObject:[[RMBTThroughput alloc] initWithLength:lengthPerPeriod startNanos:i * _resolutionNanos endNanos:(i+1) * _resolutionNanos]];
        }
        
        // Create new end period and add the rest of bytes to it
        [_periods addObject:[[RMBTThroughput alloc] initWithLength:leftoverLength startNanos:endPeriodIndex * _resolutionNanos endNanos:timestampNanos]];
    }
    
    _lastFrozenPeriodIndex = endPeriodIndex - 1;
}

- (void)freeze {
    _isFrozen = YES;
    _lastFrozenPeriodIndex = _periods.count - 1;
}

- (void)squashLastPeriods:(NSUInteger)count {
    NSAssert(count >= 1, @"Count must be >= 1");
    NSAssert(_isFrozen, @"History should be frozen before squashing");
    
    if (_periods.count < count) return;
    
    RMBTThroughput *finalTput = [_periods objectAtIndex:_periods.count - count - 1];
    for (NSUInteger i=0;i<count;i++) {
        RMBTThroughput *t = [_periods lastObject];
        finalTput.endNanos = MAX(t.endNanos, finalTput.endNanos);
        finalTput.length += t.length;
        [_periods removeLastObject];
    }
}

- (NSString*)description {
    return [NSString stringWithFormat:@"total = %@, entries = %@", _totalThroughput, [_periods description]];
}

- (void)log {
    RMBTLog(@"Throughputs:");
    for (RMBTThroughput* t in _periods) {
        RMBTLog(@"- %@",[t description]);
    }
    RMBTLog(@"Total: %@", [_totalThroughput description]);
}
@end
