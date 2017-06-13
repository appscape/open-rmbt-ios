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

#import "RMBTQoSIPTest.h"

@implementation RMBTQoSIPTest

-(instancetype)initWithParams:(NSDictionary *)params {
    if (self = [super initWithParams:params]) {
        _inPort = (NSUInteger)[params[@"in_port"] integerValue];
        _outPort = (NSUInteger)[params[@"out_port"] integerValue];
        _direction = RMBTQoSIPTestDirectionError;
    }
    return self;
}

- (void)main {
    if (_direction != RMBTQoSIPTestDirectionOut && _direction != RMBTQoSIPTestDirectionIn) {
        NSParameterAssert(false); // catch this invalid state in debug, but don't bail if we encounter it in production
        RMBTLog(@"%@ has invalid direction", self);
        self.status = RMBTQoSTestStatusError;
        return;
    }

    [self ipMain:(_direction == RMBTQoSIPTestDirectionOut)];
}

- (void)ipMain:(BOOL)outgoing {
    NSParameterAssert(false); // should be overriden in subclass
}
@end
