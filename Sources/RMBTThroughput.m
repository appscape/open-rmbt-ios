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

#import "RMBTThroughput.h"
#import "RMBTSpeed.h"

@interface RMBTThroughput() {
    uint64_t _length;
    uint64_t _startNanos, _endNanos, _durationNanos;
}
@end

@implementation RMBTThroughput

- (instancetype)init {
    if (self = [self initWithLength:0 startNanos:0 endNanos:0]) {
    }
    return self;
}

- (instancetype)initWithLength:(uint64_t)length startNanos:(uint64_t)startNanos endNanos:(uint64_t)endNanos {
    if (self = [super init]) {
        _length = length;
        _startNanos = startNanos;
        _endNanos = endNanos;
        _durationNanos = _endNanos - _startNanos;
        NSAssert(_durationNanos >= 0, @"Invalid duration");
    }
    return self;
}

- (void)setStartNanos:(uint64_t)startNanos {
    _startNanos = startNanos;
    _durationNanos = _endNanos - _startNanos;
    NSAssert(_durationNanos >= 0, @"Invalid duration");
}

- (void)setEndNanos:(uint64_t)endNanos {
    _endNanos = endNanos;
    _durationNanos = _endNanos - _startNanos;
    NSAssert(_durationNanos >= 0, @"Invalid duration");
}

- (void)setDurationNanos:(uint64_t)durationNanos {
    _durationNanos = durationNanos;
    _endNanos = _startNanos + _durationNanos;
    NSAssert(_durationNanos >= 0, @"Invalid duration");
}

- (BOOL)containsNanos:(uint64_t)nanos {
    return (_startNanos <= nanos && _endNanos >= nanos);
}

- (uint32_t)kilobitsPerSecond {
    return (_length * 8.0) / ((double)_durationNanos * 1e-6);
}

- (NSString*)description {
    return [NSString stringWithFormat:@"(%@-%@, %lld bytes, %@)",
            RMBTSecondsStringWithNanos(_startNanos),
            RMBTSecondsStringWithNanos(_endNanos),
            _length,
            RMBTSpeedMbpsString([self kilobitsPerSecond])];
}


@end
