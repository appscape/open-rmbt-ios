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

#import "RMBTQoSControlConnectionParams.h"

@implementation RMBTQoSControlConnectionParams
- (instancetype)initWithServerAddress:(NSString*)address port:(NSUInteger)port {
    if (self = [super init]) {
        NSParameterAssert(address);
        RMBTAssertValidPort(port);
        _serverAddress = address;
        _port = port;
    }
    return self;
}

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    } else if (![object isKindOfClass:[RMBTQoSControlConnectionParams class]]) {
        return NO;
    } else {
        RMBTQoSControlConnectionParams *p = (RMBTQoSControlConnectionParams*)object;
        return ([p.serverAddress isEqualToString:self.serverAddress] && p.port == self.port);
    }
}

- (NSUInteger)hash {
    return [[self description] hash];
}

-(id)copyWithZone:(NSZone *)zone {
    return self; // ARC will retain this object
}

- (NSString*)description {
    return [NSString stringWithFormat:@"%@:%ld", _serverAddress, (unsigned long)_port];
}
@end
