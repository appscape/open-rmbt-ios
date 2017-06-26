//
//  RMBTQoSTest.m
//  RMBT
//
//  Created by Esad Hajdarevic on 13/11/16.
//  Copyright © 2016 appscape gmbh. All rights reserved.
//

#import "RMBTQoSTest.h"

static const uint64_t kDefaultTimeoutNanos = 10 * NSEC_PER_SEC;

@interface RMBTQoSTest() {
    uint64_t _startedAtNanos;
}
@end

@implementation RMBTQoSTest

-(instancetype)initWithParams:(NSDictionary *)params {
    if (self = [super init]) {
        _concurrencyGroup = [params[@"concurrency_group"] integerValue];
        _uid = [params valueForKey:@"qos_test_uid"];
        if (!_uid || [_uid isEqualToString:@""]) {
            NSAssert(false, @"Invalid QoS Test UID");
            return nil;
        }

        NSString *timeoutStr = [NSString stringWithFormat:@"%@",params[@"timeout"] ?: @(kDefaultTimeoutNanos)];
        _timeoutNanos = strtoull([timeoutStr UTF8String], NULL, 10);

        _progress = [[RMBTProgress alloc] initWithTotalUnitCount:100];
        _status = RMBTQoSTestStatusUnknown;
    }
    return self;
}

- (NSInteger)timeoutSeconds {
    return MAX(1, (NSInteger)(_timeoutNanos / NSEC_PER_SEC));
}

- (NSString*)statusName {
    switch (self.status) {
        case RMBTQoSTestStatusOk:
            return @"OK";
        case RMBTQoSTestStatusError:
            return @"ERROR";
        case RMBTQoSTestStatusTimeout:
            return @"TIMEOUT";
        case RMBTQoSTestStatusUnknown:
            return @"UKNOWN";
    }
}

- (void)start {
    NSParameterAssert(!self.cancelled);
    NSParameterAssert(!self.finished);

    RMBTLog(@"Test %@ started.", self);
    _startedAtNanos = RMBTCurrentNanos();
    [super start];
    _durationNanos = @(RMBTCurrentNanos() - _startedAtNanos);
    RMBTLog(@"Test %@ finished.", self);
}

@end

