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

#import <Foundation/Foundation.h>

#import "RMBTThroughput.h"

@interface RMBTThroughputHistory : NSObject

// Total bytes/time transferred so far. Equal to sum of all reported lengths / largest reported timestamp.
@property (nonatomic, readonly) RMBTThroughput* totalThroughput;

// Time axis is split into periods of this duration. Each period has a throughput object associated with it.
// Reported transfers are then proportionally divided accross the throughputs it spans over.
@property (nonatomic, readonly) uint64_t resolutionNanos;

// Array of throughput objects for each period
@property (nonatomic, readonly) NSArray *periods;

// Returns the index of the last period which is complete, meaning that no reports can change its value.
// -1 if not even the first period is complete yet
@property (nonatomic, readonly) NSInteger lastFrozenPeriodIndex;

// See -freeze
@property (nonatomic, readonly) BOOL isFrozen;

- (instancetype)initWithResolutionNanos:(uint64_t)nanos;
- (instancetype)init __attribute__((unavailable("use initWithResolutionNanos:")));

- (void)addLength:(uint64_t)length atNanos:(uint64_t)ns;

// Marks history as frozen, also marking all periods as passed, not allowing futher reports.
- (void)freeze;

// Concatenetes last count periods into one, or nop if there are less than two periods in the history.
- (void)squashLastPeriods:(NSUInteger)count;

- (void)log;

@end