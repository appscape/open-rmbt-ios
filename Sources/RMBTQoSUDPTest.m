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

#import "RMBTQoSUDPTest.h"
#import <GCDAsyncUdpSocket.h>

typedef NS_ENUM(long, RMBTQoSUDPPacketTag) {
    RMBTQoSUDPPacketTagOutgoing = 0,
    RMBTQoSUDPPacketTagIncomingResponse,
};

typedef NS_ENUM(uint8_t, RMBTQoSUDPTestPacketFlag) {
    RMBTQoSUDPTestPacketFlagOneDirection = 1,
    RMBTQoSUDPTestPacketFlagResponse = 2,
    RMBTQoSUDPTestPacketFlagAwaitResponse = 3
};

static const uint64_t kDefaultDelayNanos = 300 * NSEC_PER_MSEC;

@interface RMBTQoSUDPTest()<GCDAsyncUdpSocketDelegate> {
    NSUInteger _outPacketCount, _inPacketCount;

    uint64_t _delayNanos;

    uint64_t _delayLastPacketSentAt;
    dispatch_semaphore_t _delayElapsedSem;

    NSMutableSet *_receivedPacketSeqs;
    NSUInteger _receivedServerCount;

    dispatch_semaphore_t _stopReceivingSem;
}
@end


@implementation RMBTQoSUDPTest

-(instancetype)initWithParams:(NSDictionary *)params {
    if (self = [super initWithParams:params]) {
        _outPacketCount = (NSUInteger)[params[@"out_num_packets"] integerValue];
        _inPacketCount = (NSUInteger)[params[@"in_num_packets"] integerValue];

        NSString *delayStr = [NSString stringWithFormat:@"%@",params[@"delay"] ?: @(kDefaultDelayNanos)];
        _delayNanos = strtoull([delayStr UTF8String], NULL, 10);

        if (_outPacketCount > 0 && _inPacketCount == 0) {
            self.direction = RMBTQoSIPTestDirectionOut;
        } else if (_inPacketCount > 0 && _outPacketCount == 0) {
            self.direction = RMBTQoSIPTestDirectionIn;
        }
    }
    return self;
}

- (NSDictionary*)result {
    NSMutableDictionary *result = [@{
        @"udp_objective_delay": @(_delayNanos),
        @"udp_objective_timeout": @(self.timeoutNanos)
    } mutableCopy];

    // Server doesn't parse UDP tests with "error"/"timeout" result as failed, relying on packet count comparison instead,
    // so let's send zeroes:
    //if (self.status == RMBTQoSTestStatusOk) {
        BOOL outgoing = (self.direction == RMBTQoSIPTestDirectionOut);
        NSUInteger packetCount = (outgoing ? _outPacketCount : _inPacketCount);

        NSUInteger receivedClientCount = _receivedPacketSeqs ? _receivedPacketSeqs.count : 0;
        NSInteger lostPackets = packetCount - receivedClientCount;

        NSString *plr = [NSString stringWithFormat:@"%lu", (unsigned long)RMBTPercent(lostPackets, packetCount)];

        if (outgoing) {
            [result addEntriesFromDictionary:@{
                @"udp_objective_out_port": @(self.outPort),
                @"udp_objective_out_num_packets": @(packetCount),
                @"udp_result_out_num_packets": @(_receivedServerCount),
                @"udp_result_out_response_num_packets": @(receivedClientCount),
                @"udp_result_out_packet_loss_rate": plr
            }];
        } else {
            [result addEntriesFromDictionary:@{
               @"udp_objective_in_port": @(self.inPort),
               @"udp_objective_in_num_packets": @(packetCount),
               //
               @"udp_result_in_num_packets": @(receivedClientCount),
               @"udp_result_in_response_num_packets": @(_receivedServerCount),
               @"udp_result_in_packet_loss_rate": plr
           }];
        }
    //}

    return result;
}

- (void)ipMain:(BOOL)outgoing {
    NSUInteger port = outgoing ? self.outPort : self.inPort;
    RMBTAssertValidPort(port);

    NSUInteger packetCount = outgoing ? _outPacketCount : _inPacketCount;

    NSParameterAssert(!_receivedPacketSeqs);
    _receivedPacketSeqs = [NSMutableSet set];

    NSError *error = nil;

    NSString *cmd = [NSString stringWithFormat:@"UDPTEST %@ %lu %lu +ID%@", outgoing ? @"OUT" : @"IN",
                     (unsigned long)port,
                     (unsigned long)packetCount,
                     self.uid];
    NSString *response1 = [self sendCommand:cmd readReply:outgoing ? YES : NO error:&error];
    if (error || (outgoing && ![response1 hasPrefix:@"OK"])) {
        RMBTLog(@"%@ failed: %@/%@", self, error, response1);
        self.status = RMBTQoSTestStatusError;
        return;
    }

    dispatch_queue_t delegateQueue = dispatch_queue_create("at.rmbt.qos.udp.delegate", DISPATCH_QUEUE_SERIAL);
    GCDAsyncUdpSocket *udpSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:delegateQueue];

    if (outgoing) {
        [udpSocket connectToHost:self.controlConnectionParams.serverAddress onPort:self.outPort error:&error];
    } else {
        [udpSocket bindToPort:self.inPort error:&error];
    }

    if (error) {
        RMBTLog(@"%@ error connecting/binding: %@", self, error);
        self.status = RMBTQoSTestStatusError;
        return;
    }

    _stopReceivingSem = dispatch_semaphore_create(0);
    dispatch_time_t stopReceivingSemTimeout = dispatch_time(DISPATCH_TIME_NOW, self.timeoutNanos);

    [udpSocket beginReceiving:&error];

    if (error) {
        RMBTLog(@"%@ error beginReceiving: %@", self, error);
        self.status = RMBTQoSTestStatusError;
        return;
    }

    if (outgoing) {
        _delayElapsedSem = dispatch_semaphore_create(0);

        for (uint8_t i=0;i<packetCount;i++) {
            _delayLastPacketSentAt = RMBTCurrentNanos();
            [udpSocket sendData:[self dataForOutgoingPacketWithFlag:RMBTQoSUDPTestPacketFlagAwaitResponse seq:i] withTimeout:self.timeoutSeconds tag:RMBTQoSUDPPacketTagOutgoing];
            if (dispatch_semaphore_wait(_delayElapsedSem, dispatch_time(DISPATCH_TIME_NOW, self.timeoutNanos)) != 0) {
                RMBTLog(@"%@ timed out waiting for send delay!", self);
                self.status = RMBTQoSTestStatusTimeout;
                break;
            }
        }
    }

    if (dispatch_semaphore_wait(_stopReceivingSem, stopReceivingSemTimeout) != 0) {
        RMBTLog(@"%@: receive timeout", self);
    }

    [udpSocket closeAfterSending];

    NSString* response2 = [self sendCommand:[NSString stringWithFormat:@"GET UDPRESULT %@ %lu +ID%@", outgoing ? @"OUT" : @"IN", (unsigned long)port, self.uid] readReply:YES error:&error];

    if (error || ![response2 hasPrefix:@"RCV"]) {
        RMBTLog(@"%@ error fetching udpresult: %@/%@", self, error, response2);
        self.status = RMBTQoSTestStatusError;
        return;
    }

    NSArray *components = [response2 componentsSeparatedByString:@" "];
    if (components.count < 2 ) {
        RMBTLog(@"%@ couldn't parse RCV string: %@", self, components);
        self.status = RMBTQoSTestStatusError;
        return;
    } else {
        _receivedServerCount = [components[1] integerValue];
    }

    if (self.status == RMBTQoSTestStatusUnknown) {
        self.status = RMBTQoSTestStatusOk;
    }
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock
   didReceiveData:(NSData *)data
      fromAddress:(NSData *)address
withFilterContext:(id)filterContext {
    uint8_t flag = 0;
    [data getBytes:&flag length:1];

    uint8_t seq = 0;
    [data getBytes:&seq range:NSMakeRange(1, 1)];

    if ([_receivedPacketSeqs containsObject:@(seq)]) {
        RMBTLog(@"%@ received duplicate packet!", self);
        self.status = RMBTQoSTestStatusError;
        dispatch_semaphore_signal(_stopReceivingSem);
    } else {
        [_receivedPacketSeqs addObject:@(seq)];
        if (self.direction == RMBTQoSIPTestDirectionIn) {
            NSParameterAssert(flag == 3);
            [sock sendData:[self dataForOutgoingPacketWithFlag:RMBTQoSUDPTestPacketFlagResponse seq:seq] toAddress:address withTimeout:self.timeoutSeconds tag:RMBTQoSUDPPacketTagIncomingResponse];
            if (_receivedPacketSeqs.count == _inPacketCount) {
                // Allow for the last confirmation packet to reach the server:
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, _delayNanos), sock.delegateQueue, ^{
                    dispatch_semaphore_signal(_stopReceivingSem);
                });
            }
        } else {
            NSParameterAssert(flag == 2);
            if (_receivedPacketSeqs.count == _outPacketCount) {
                dispatch_semaphore_signal(_stopReceivingSem);
            }
        }
    }
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didSendDataWithTag:(long)tag {
    if (tag == RMBTQoSUDPPacketTagOutgoing) {
        uint64_t elapsed = RMBTCurrentNanos() - _delayLastPacketSentAt;
        uint64_t delay = elapsed > _delayNanos ? 0 : _delayNanos - elapsed;
        //RMBTLog(@"%@ waiting %ld ns for delay", self, delay);
        RMBTBlock signal = ^{
            dispatch_semaphore_signal(_delayElapsedSem);
        };
        if (delay > 0) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delay), sock.delegateQueue, signal);
        } else {
            signal();
        }
    }
}

- (NSData*)dataForOutgoingPacketWithFlag:(RMBTQoSUDPTestPacketFlag)packetFlag seq:(uint8_t)seq {
    NSMutableData *data = [NSMutableData data];

    // Flag (1 byte)
    const uint8_t flag = packetFlag;
    [data appendBytes:&flag length:1];

    // Packet number (1 byte)
    [data appendBytes:&seq length:1];

    // UUID
    NSData *uuidData = [[self uuidFromToken] dataUsingEncoding:NSASCIIStringEncoding];
    NSParameterAssert(uuidData.length == 36);
    [data appendData:uuidData];

    // Timestamp
    NSData *timestampData = [[RMBTTimestampWithNSDate([NSDate date]) stringValue] dataUsingEncoding:NSASCIIStringEncoding];
    [data appendData:timestampData];

    return data;
}

- (NSString*)description {
    return [NSString stringWithFormat:@"RMBTQoSUDPTest (uid=%@, cg=%ld, server=%@, delay=%@, out=%@, in=%@)",
            self.uid,
            (unsigned long)self.concurrencyGroup,
            self.controlConnectionParams,
            RMBTSecondsStringWithNanos(_delayNanos),
            self.outPort > 0 ? [NSString stringWithFormat:@"%ld/%ld", (unsigned long)self.outPort, (unsigned long)_outPacketCount] : @"-",
            self.inPort > 0 ? [NSString stringWithFormat:@"%ld/%ld", (unsigned long)self.inPort, (unsigned long)_inPacketCount] : @"-"
    ];
}


@end
