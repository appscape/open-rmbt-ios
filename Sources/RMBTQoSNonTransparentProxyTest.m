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

#import "RMBTQoSNonTransparentProxyTest.h"
#import <CocoaAsyncSocket/GCDAsyncSocket.h>

@interface RMBTQoSNonTransparentProxyTest()<GCDAsyncSocketDelegate> {
    NSString *_request;
    NSString *_result;
    NSUInteger _port;
    dispatch_semaphore_t _sem;
}
@end

@implementation RMBTQoSNonTransparentProxyTest
-(instancetype)initWithParams:(NSDictionary *)params {
    if (self = [super initWithParams:params]) {
        _port = (NSUInteger)[params[@"port"] integerValue];
        _request = params[@"request"];
        _sem = dispatch_semaphore_create(0);
        RMBTAssertValidPort(_port);
    }
    return self;
}


- (NSDictionary*)result {
    return @{
        @"nontransproxy_objective_request": _request,
        @"nontransproxy_objective_port": @(_port),
        @"nontransproxy_objective_timeout": @(self.timeoutNanos),
        @"nontransproxy_result_response": RMBTValueOrNull(_result),
        @"nontransproxy_result": [self statusName],
    };
}

- (void)main {
    NSParameterAssert(self.status == RMBTQoSTestStatusUnknown);
    NSParameterAssert(!_result);

    NSError *error = nil;

    NSString *cmd = [NSString stringWithFormat:@"NTPTEST %lu", (unsigned long)_port];
    NSString *response = [self sendCommand:cmd readReply:YES error:&error];
    RMBTLog(@"Receive %@", response);

    if (error || ![response hasPrefix:@"OK"]) {
        RMBTLog(@"%@ failed: %@ %@", self, error, response);
        self.status = RMBTQoSTestStatusError;
        return;
    }

    dispatch_queue_t delegateQueue = dispatch_queue_create("at.rmbt.qos.ntp.delegate", DISPATCH_QUEUE_SERIAL);
    GCDAsyncSocket *socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:delegateQueue];

    [socket connectToHost:self.controlConnectionParams.serverAddress onPort:_port withTimeout:self.timeoutSeconds error:&error];

    if (error) {
        RMBTLog(@"%@ error connecting to %@: %@", self, self.controlConnectionParams.serverAddress, error);
        self.status = RMBTQoSTestStatusError;
        return;
    }

    if (dispatch_semaphore_wait(_sem, dispatch_time(DISPATCH_TIME_NOW, self.timeoutNanos)) != 0) {
        RMBTLog(@"%@ timed out", self);
        self.status = RMBTQoSTestStatusTimeout;
    } else {
        if (_result) {
            self.status = RMBTQoSTestStatusOk;
        } else {
            self.status = RMBTQoSTestStatusError;
        }
    };
    [socket disconnect];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    dispatch_semaphore_signal(_sem);
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    [sock writeData:[[_request stringByAppendingString:@"\n"] dataUsingEncoding:NSASCIIStringEncoding] withTimeout:self.timeoutSeconds tag:0];
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag {
    [sock readDataToData:[@"\n" dataUsingEncoding:NSASCIIStringEncoding] withTimeout:self.timeoutSeconds tag:1];
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    NSString *line = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
    _result = RMBTChomp(line);
    dispatch_semaphore_signal(_sem);
}

- (NSString*)description {
    return [NSString stringWithFormat:@"RMBTQoSNonTransparentProxyTest (uid=%@, cg=%lu, server=%@, request=%@, port=%lu)",
            self.uid,
            (unsigned long)self.concurrencyGroup,
            self.controlConnectionParams,
            _request,
            (unsigned long)_port
            ];
}

@end
