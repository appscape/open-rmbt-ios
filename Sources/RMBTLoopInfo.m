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

#import "RMBTLoopInfo.h"

@implementation RMBTLoopInfo

- (instancetype)initWithMeters:(NSUInteger)meters minutes:(NSUInteger)minutes total:(NSUInteger)total {
    if (self = [super init]) {
        _waitMeters = meters;
        _waitMinutes = minutes;
        _total = total;
        _current = 0;
    }
    return self;
}

- (void)increment {
    _current += 1;
}

- (BOOL)isFinished {
    return _current >= _total;
}

- (NSDictionary*)params {
    return @{
        @"loopmode_info": @{
            @"max_delay": @(_waitMinutes),
            @"max_movement": @(_waitMeters),
            @"max_tests": @(_total),
            @"test_counter": @(_current),
            // text_counter was a typo in old server api, send for compatibility
            @"text_counter": @(_current)
        }
    };
}

@end
