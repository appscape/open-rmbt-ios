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

#import "RMBTQoSCCTest.h"
#import "RMBTQoSControlConnection.h"

@interface RMBTQoSControlConnectionParams()
@property (nonatomic, readwrite, copy) NSString *serverAddress;
@property (nonatomic, readwrite) NSUInteger port;
@end

@interface RMBTQoSCCTest() {
    RMBTQoSControlConnection *_controlConnection;
}
@end

@implementation RMBTQoSCCTest

-(instancetype)initWithParams:(NSDictionary *)params {
    if (self = [super initWithParams:params]) {
        _controlConnectionParams = [[RMBTQoSControlConnectionParams alloc] initWithServerAddress:params[@"server_addr"] port:(NSUInteger)[params[@"server_port"] integerValue]];
    }
    return self;
}

- (void)setControlConnection:(RMBTQoSControlConnection*)connection {
    _controlConnection = connection;
}

- (NSString*)sendCommand:(NSString*)line readReply:(BOOL)readReply error:(NSError* __autoreleasing*)errPtr {
    NSParameterAssert(_controlConnection);

    __block NSString *result = nil;
    __block NSError *error = nil;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);

    //[NSString stringWithFormat:@"%@ +ID%@", line, self.uid]
    [_controlConnection sendCommand:line readReply:readReply success:^(id response) {
        result = response;
        dispatch_semaphore_signal(sem);
    } error:^(NSError *error, NSDictionary *info) {
        error = error;
        dispatch_semaphore_signal(sem);
    }];

    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);

    if (errPtr != NULL && error) {
        *errPtr = error;
    }

    return result;
}

- (NSString*)uuidFromToken {
    NSParameterAssert(_controlConnection.token);
    return [_controlConnection.token componentsSeparatedByString:@"_"][0];
}
@end
