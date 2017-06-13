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

@interface RMBTHelpersTest : XCTestCase
@end

@implementation RMBTHelpersTest

- (void)testBSSIDConversion {
    XCTAssertEqualObjects(RMBTReformatHexIdentifier(@"0:0:fb:1"), @"00:00:fb:01");
    XCTAssertEqualObjects(RMBTReformatHexIdentifier(@"hello"), @"hello");
    XCTAssertEqualObjects(RMBTReformatHexIdentifier(@"::FF:1"), @"00:00:FF:01");
}

- (void)testChomp {
    XCTAssertEqualObjects(RMBTChomp(@"\n\ntest\n "), @"\n\ntest\n ");
    XCTAssertEqualObjects(RMBTChomp(@"\n\ntest\n\r\n"), @"\n\ntest");
    XCTAssertEqualObjects(RMBTChomp(@""), @"");
    XCTAssertEqualObjects(RMBTChomp(@"\r\n"), @"");
    XCTAssertEqualObjects(RMBTChomp(@"\n"), @"");
}

- (void)testPercent {
    XCTAssertEqual(RMBTPercent(-1, -100), 1);
    XCTAssertEqual(RMBTPercent(100, 0), 0);
    XCTAssertEqual(RMBTPercent(3, 9), 33);
}

- (void)testMedian {
    XCTAssertEqualObjects(RMBTMedian(@[@(1024)]), @(1024));
    XCTAssertEqualObjects(RMBTMedian(@[@(0),@(10)]), @(5));
    XCTAssertEqualObjects(RMBTMedian(@[@(0),@(9)]), @(4)); // works only with integral values
    XCTAssertEqualObjects(RMBTMedian(@[@(0),@(100), @(101)]), @(100));
    XCTAssertNil(RMBTMedian(@[]));
}

- (void)testMMSS {
    XCTAssertEqualObjects(RMBTMMSSStringWithInterval(60), @"01:00");
    XCTAssertEqualObjects(RMBTMMSSStringWithInterval(89), @"01:29");
    XCTAssertEqualObjects(RMBTMMSSStringWithInterval(60.444445), @"01:00");
    XCTAssertEqualObjects(RMBTMMSSStringWithInterval(60*100), @"100:00");
    XCTAssertEqualObjects(RMBTMMSSStringWithInterval(12012), @"200:12");
}

@end
