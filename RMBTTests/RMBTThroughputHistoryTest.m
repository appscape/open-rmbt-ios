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

@interface RMBTThroughputHistoryTest : SenTestCase
@end

@implementation RMBTThroughputHistoryTest

- (void)testSpread {
    // One block = 250ms
    RMBTThroughputHistory *h = [[RMBTThroughputHistory alloc] initWithResolutionNanos:T(250)];
    
    STAssertEquals(h.totalThroughput.endNanos, T(0), nil);
    
    // Transfer 10 kilobit in one second
    [h addLength:1250 atNanos:T(1000)];
    
    // Assert correct total throughput
    STAssertEquals(h.totalThroughput.endNanos, T(1000), nil);
    STAssertTrue(h.totalThroughput.kilobitsPerSecond == 10, nil);
    
    // Assert correct period division
    STAssertEquals(h.periods.count, 4U, nil);
    
    // ..and bytes per period (note that 1250 isn't divisible by 4)
    for (int i = 0; i<3;i++) {
        STAssertTrue([h.periods[i] length] == 312, nil);
    }
    STAssertTrue([h.periods[3] length] == 314, nil);
}

- (void)testBoundaries {
    RMBTThroughputHistory *h = [[RMBTThroughputHistory alloc] initWithResolutionNanos:T(1000)];
    STAssertEquals(h.lastFrozenPeriodIndex, -1, nil);
    
    [h addLength:1050 atNanos:T(1050)];
    STAssertEquals(h.lastFrozenPeriodIndex, 0, nil);

    [h addLength:150 atNanos:T(1200)];
    STAssertEquals(h.lastFrozenPeriodIndex, 0, nil);
    STAssertEquals(h.periods.count, 2U, nil);
    STAssertEquals(h.totalThroughput.endNanos, T(1200), nil);
    STAssertEquals([[h.periods lastObject] endNanos], T(1200), nil);
    
    [h addLength:800 atNanos:T(2000)];
    STAssertEquals(h.lastFrozenPeriodIndex, 0, nil);
    STAssertEquals(h.periods.count, 2U, nil);
    
    STAssertTrue([h.periods[0] length] == 1000, nil);
    STAssertTrue([h.periods[1] length] == 1000, nil);
    
    [h addLength:1000 atNanos:T(3000)];
    STAssertEquals(h.lastFrozenPeriodIndex, 1, nil);
    STAssertEquals(h.periods.count, 3U, nil);
    STAssertEquals([[h.periods lastObject] startNanos], T(2000), nil);
    STAssertEquals([[h.periods lastObject] endNanos], T(3000), nil);
    STAssertTrue([h.periods[2] length] == 1000, nil);
}

- (void)testFreeze {
    RMBTThroughputHistory *h = [[RMBTThroughputHistory alloc] initWithResolutionNanos:T(1000)];
    [h addLength:1024 atNanos:T(500)];
    STAssertEquals(h.lastFrozenPeriodIndex, -1, nil);
    STAssertEquals([[h totalThroughput] endNanos], T(500), nil);
    [h freeze];
    STAssertEquals(h.lastFrozenPeriodIndex, 0, nil);
    STAssertEquals([[h.periods lastObject] endNanos], T(500), nil);
}

- (void)testSquash1 {
    RMBTThroughputHistory *h = [[RMBTThroughputHistory alloc] initWithResolutionNanos:T(1000)];
    [h addLength:1000 atNanos:T(500)];
    [h addLength:1000 atNanos:T(1000)];
    
    [h addLength:1000 atNanos:T(1500)];
    [h addLength:1000 atNanos:T(2000)];
    
    [h addLength:1000 atNanos:T(2500)];
    [h addLength:1000 atNanos:T(3000)];
    
    [h freeze];
    
    STAssertEquals([[h periods] count], 3U, nil);
    [h squashLastPeriods:1];
    
    STAssertEquals([[h periods] count], 2U, nil);
    STAssertEquals([[[h periods] lastObject] endNanos], T(3000), nil);
    STAssertEquals([[[h periods] lastObject] length], 4000U, nil);
}

- (void)testSquash2 {
    RMBTThroughputHistory *h = [[RMBTThroughputHistory alloc] initWithResolutionNanos:T(1000)];
    [h addLength:1000 atNanos:T(500)];
    [h addLength:1000 atNanos:T(1000)];
    
    [h addLength:1000 atNanos:T(1500)];
    [h addLength:1000 atNanos:T(2000)];
    
    [h addLength:1000 atNanos:T(2500)];
    [h addLength:1000 atNanos:T(3000)];
    
    [h freeze];
    
    STAssertEquals([[h periods] count], 3U, nil);
    [h squashLastPeriods:2];
    
    STAssertEquals([[h periods] count], 1U, nil);
    STAssertEquals([[[h periods] lastObject] endNanos], T(3000), nil);
    STAssertEquals([[[h periods] lastObject] length], 6000U, nil);
}

@end
