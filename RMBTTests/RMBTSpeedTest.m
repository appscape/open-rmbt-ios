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

#import "RMBTSpeed.h"

@interface RMBTSpeedTest : SenTestCase
@end

@implementation RMBTSpeedTest

- (void)testFormatting {
    STAssertEqualObjects(RMBTSpeedMbpsString(11221), @"11 Mbps", NULL);
    STAssertEqualObjects(RMBTSpeedMbpsString(11500), @"12 Mbps", NULL); // bankers' rounding
    STAssertEqualObjects(RMBTSpeedMbpsString(11490), @"11 Mbps", NULL);
    
    STAssertEqualObjects(RMBTSpeedMbpsString(11490), @"11 Mbps", NULL);
    STAssertEqualObjects(RMBTSpeedMbpsString(11490), @"11 Mbps", NULL);
    STAssertEqualObjects(RMBTSpeedMbpsString(11490), @"11 Mbps", NULL);
    
    STAssertEqualObjects(RMBTSpeedMbpsString(154), @"0.15 Mbps", NULL);
    STAssertEqualObjects(RMBTSpeedMbpsString(155), @"0.16 Mbps", NULL);
    
    STAssertEqualObjects(RMBTSpeedMbpsString(123000), @"120 Mbps", NULL);
    
    STAssertEqualObjects(RMBTSpeedMbpsString(1250), @"1.2 Mbps", NULL);
}

@end