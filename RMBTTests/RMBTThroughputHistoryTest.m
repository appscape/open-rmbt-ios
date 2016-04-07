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

@interface RMBTThroughputHistoryTest : XCTestCase
@end

@implementation RMBTThroughputHistoryTest

- (void)testSpread {
    // One block = 250ms
    RMBTThroughputHistory *h = [[RMBTThroughputHistory alloc] initWithResolutionNanos:T(250)];
    
    XCTAssertEqual(h.totalThroughput.endNanos, T(0));
    
    // Transfer 10 kilobit in one second
    [h addLength:1250 atNanos:T(1000)];
    
    // Assert correct total throughput
    XCTAssertEqual(h.totalThroughput.endNanos, T(1000));
    XCTAssertTrue(h.totalThroughput.kilobitsPerSecond == 10);
    
    // Assert correct period division
    XCTAssertEqual(h.periods.count, 4U);
    
    // ..and bytes per period (note that 1250 isn't divisible by 4)
    for (int i = 0; i<3;i++) {
        XCTAssertTrue([h.periods[i] length] == 312);
    }
    XCTAssertTrue([h.periods[3] length] == 314);
}

- (void)testBoundaries {
    RMBTThroughputHistory *h = [[RMBTThroughputHistory alloc] initWithResolutionNanos:T(1000)];
    XCTAssertEqual(h.lastFrozenPeriodIndex, -1);
    
    [h addLength:1050 atNanos:T(1050)];
    XCTAssertEqual(h.lastFrozenPeriodIndex, 0);

    [h addLength:150 atNanos:T(1200)];
    XCTAssertEqual(h.lastFrozenPeriodIndex, 0);
    XCTAssertEqual(h.periods.count, 2U);
    XCTAssertEqual(h.totalThroughput.endNanos, T(1200));
    XCTAssertEqual([[h.periods lastObject] endNanos], T(1200));
    
    [h addLength:800 atNanos:T(2000)];
    XCTAssertEqual(h.lastFrozenPeriodIndex, 0);
    XCTAssertEqual(h.periods.count, 2U);
    
    XCTAssertTrue([h.periods[0] length] == 1000);
    XCTAssertTrue([h.periods[1] length] == 1000);
    
    [h addLength:1000 atNanos:T(3000)];
    XCTAssertEqual(h.lastFrozenPeriodIndex, 1);
    XCTAssertEqual(h.periods.count, 3U);
    XCTAssertEqual([[h.periods lastObject] startNanos], T(2000));
    XCTAssertEqual([[h.periods lastObject] endNanos], T(3000));
    XCTAssertTrue([h.periods[2] length] == 1000);
}

- (void)testFreeze {
    RMBTThroughputHistory *h = [[RMBTThroughputHistory alloc] initWithResolutionNanos:T(1000)];
    [h addLength:1024 atNanos:T(500)];
    XCTAssertEqual(h.lastFrozenPeriodIndex, -1);
    XCTAssertEqual([[h totalThroughput] endNanos], T(500));
    [h freeze];
    XCTAssertEqual(h.lastFrozenPeriodIndex, 0);
    XCTAssertEqual([[h.periods lastObject] endNanos], T(500));
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
    
    XCTAssertEqual([[h periods] count], 3U);
    [h squashLastPeriods:1];
    
    XCTAssertEqual([[h periods] count], 2U);
    XCTAssertEqual([[[h periods] lastObject] endNanos], T(3000));
    XCTAssertEqual([[[h periods] lastObject] length], 4000U);
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
    
    XCTAssertEqual([[h periods] count], 3U);
    [h squashLastPeriods:2];
    
    XCTAssertEqual([[h periods] count], 1U);
    XCTAssertEqual([[[h periods] lastObject] endNanos], T(3000));
    XCTAssertEqual([[[h periods] lastObject] length], 6000U);
}

@end
