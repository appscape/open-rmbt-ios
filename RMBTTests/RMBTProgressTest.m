//
//  RMBTProgressTest.m
//  RMBT
//
//  Created by Esad Hajdarevic on 28/01/17.
//  Copyright © 2017 appscape gmbh. All rights reserved.
//

#import "RMBTProgress.h"

@interface RMBTProgressTest : XCTestCase
@end

@implementation RMBTProgressTest

- (void)testSimple {
    RMBTProgress *p = [[RMBTProgress alloc] initWithTotalUnitCount:100];
    XCTAssertEqualWithAccuracy(p.fractionCompleted, 0.0, FLT_EPSILON);
    p.completedUnitCount = 25;
    XCTAssertEqualWithAccuracy(p.fractionCompleted, 0.25, FLT_EPSILON);
    p.completedUnitCount = 200;
    XCTAssertEqualWithAccuracy(p.fractionCompleted, 1.0, FLT_EPSILON, @"Clamp");
}

- (void)testChildren {
    RMBTProgress *c1 = [[RMBTProgress alloc] initWithTotalUnitCount:40];
    c1.completedUnitCount = 20;
    RMBTProgress *c2 = [[RMBTProgress alloc] initWithTotalUnitCount:40];

    RMBTCompositeProgress *b1 = [[RMBTCompositeProgress alloc] initWithChildren:@[c1,c2]];
    // Both children count equally: so (0.5+0)/2=0.25
    XCTAssertEqualWithAccuracy(b1.fractionCompleted, 0.25, FLT_EPSILON);
    RMBTProgress *b2 = [[RMBTProgress alloc] initWithTotalUnitCount:40];

    RMBTCompositeProgress *a = [[RMBTCompositeProgress alloc] initWithChildren:@[b1,b2]];
    XCTAssertEqualWithAccuracy(a.fractionCompleted, 0.125, FLT_EPSILON);

    c1.completedUnitCount = 0;
    XCTAssertEqualWithAccuracy(a.fractionCompleted, 0.0, FLT_EPSILON);

    c2.completedUnitCount = 10;
    XCTAssertEqualWithAccuracy(a.fractionCompleted, 0.0625, FLT_EPSILON);

    c1.completedUnitCount = 40;
    // (1 + 0.25)/2 = 0.625, (0.625+0)/2 = 0.25
    XCTAssertEqualWithAccuracy(a.fractionCompleted, 0.3125, FLT_EPSILON);
}

- (void)testNotify {
    NSMutableArray *updates = [NSMutableArray array];
    RMBTProgress *b1 = [[RMBTProgress alloc] initWithTotalUnitCount:10];
    RMBTProgress *b2 = [[RMBTProgress alloc] initWithTotalUnitCount:100];
    RMBTCompositeProgress *a = [[RMBTCompositeProgress alloc] initWithChildren:@[b1,b2]];

    a.onFractionCompleteChange = ^(float p) {
        [updates addObject:@(p)];
    };

    b1.onFractionCompleteChange = ^(float p) {
        [updates addObject:@(p)];
    };

    b1.completedUnitCount = 2;
    b1.completedUnitCount = 4;
    b1.completedUnitCount = 20;


    XCTAssertEqual(updates.count, 6); // 3 for b1, 3 for a
    XCTAssertEqualWithAccuracy([updates[0] floatValue], 0.2, FLT_EPSILON);
    XCTAssertEqualWithAccuracy([updates[1] floatValue], 0.1, FLT_EPSILON);
    XCTAssertEqualWithAccuracy([updates[2] floatValue], 0.4, FLT_EPSILON);
    XCTAssertEqualWithAccuracy([updates[3] floatValue], 0.2, FLT_EPSILON);
    XCTAssertEqualWithAccuracy([updates[4] floatValue], 1.0, FLT_EPSILON);
    XCTAssertEqualWithAccuracy([updates[5] floatValue], 0.5, FLT_EPSILON);
}

@end
