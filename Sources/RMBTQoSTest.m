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
    if (self.cancelled) {
        RMBTLog(@"Test %@ cancelled.", self);
    }
    NSParameterAssert(!self.finished);
    if (!self.cancelled) { RMBTLog(@"Test %@ started.", self); }
    _startedAtNanos = RMBTCurrentNanos();
    [super start];
    _durationNanos = @(RMBTCurrentNanos() - _startedAtNanos);
    if (!self.cancelled) { RMBTLog(@"Test %@ finished.", self); }
}

@end
