//
//  RMBTQoSControlConnection.m
//  RMBT
//
//  Created by Esad Hajdarevic on 18/03/17.
//  Copyright © 2017 appscape gmbh. All rights reserved.
//

#import <CocoaAsyncSocket/GCDAsyncSocket.h>
#import "RMBTQoSControlConnection.h"

NSString *const RMBTQoSControlConnectionErrorDomain = @"RMBTQoSControlConnectionErrorDomain";

// We use long to be compatible with GCDAsyncSocket tag datatype
typedef NS_ENUM(NSInteger, RMBTQoSControlConnectionState) {
    RMBTQoSControlConnectionStateDisconnected,
    RMBTQoSControlConnectionStateDisconnecting,
    RMBTQoSControlConnectionStateConnecting,
    RMBTQoSControlConnectionStateAuthenticating,
    RMBTQoSControlConnectionStateAuthenticated
};

typedef NS_ENUM(long, RMBTQoSControlConnectionTag) {
    RMBTQoSControlConnectionTagGreeting = 1,
    RMBTQoSControlConnectionTagAccept,
    RMBTQoSControlConnectionTagToken,
    RMBTQoSControlConnectionTagAccept2,
    RMBTQoSControlConnectionTagRequestTimeout,
    RMBTQoSControlConnectionTagCommand
};

@interface RMBTQoSControlConnection()<GCDAsyncSocketDelegate> {
    NSString *_token;
    GCDAsyncSocket* _socket;
    RMBTQoSControlConnectionParams *_params;
    dispatch_queue_t _delegateQueue, _commandsQueue;

    NSString *_currentCommand;
    RMBTSuccessBlock _currentCommandSuccess;
    RMBTErrorBlock _currentCommandError;
    BOOL _currentReadReply;

    RMBTQoSControlConnectionState _state;
}
@end

@implementation RMBTQoSControlConnection
- (instancetype)initWithConnectionParams:(RMBTQoSControlConnectionParams*)params
                                   token:(NSString*)token
{
    if (self = [super init]) {
        _state = RMBTQoSControlConnectionStateDisconnected;
        _token = token;
        _params = params;
        _commandsQueue = dispatch_queue_create("at.rmbt.qos.control.commands", DISPATCH_QUEUE_SERIAL);
        _delegateQueue = dispatch_queue_create("at.rmbt.qos.control.delegate", DISPATCH_QUEUE_SERIAL);
        _socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:_delegateQueue];
    }
    return self;
}

- (void)connect {
    NSParameterAssert(_state == RMBTQoSControlConnectionStateDisconnected);
    _state = RMBTQoSControlConnectionStateConnecting;
    NSError *error;
    [_socket connectToHost:_params.serverAddress onPort:_params.port withTimeout:RMBT_QOS_CC_TIMEOUT_S error:&error];

    if (error && _currentCommandError) {
        _state = RMBTQoSControlConnectionStateDisconnected;
        [self doneWithResult:nil error:error];
    }
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    [sock startTLS:nil];
}

- (BOOL)socketShouldManuallyEvaluateTrust:(GCDAsyncSocket *)sock {
    return YES;
}

- (BOOL)socket:(GCDAsyncSocket *)sock shouldTrustPeer:(SecTrustRef)trust {
    return YES;
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    RMBTLog(@"QoS control server disconnected: %@", err);
    _state = RMBTQoSControlConnectionStateDisconnected;
    if (_currentCommandError) {
        [self doneWithResult:nil error:err];
    }
}

- (void)socketDidSecure:(GCDAsyncSocket *)sock  {
    [self readLineWithTag:RMBTQoSControlConnectionTagGreeting];
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    NSString *line = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
//    RMBTLog(@"RX %@", line);
    if (tag == RMBTQoSControlConnectionTagGreeting) {
        [self readLineWithTag:RMBTQoSControlConnectionTagAccept];
    } else if (tag == RMBTQoSControlConnectionTagAccept) {
        [self writeLine:[NSString stringWithFormat:@"TOKEN %@", _token] withTag:RMBTQoSControlConnectionTagToken];
        [self readLineWithTag:RMBTQoSControlConnectionTagToken];
    } else if (tag == RMBTQoSControlConnectionTagToken) {
        [self readLineWithTag:RMBTQoSControlConnectionTagAccept2];
    } else if (tag == RMBTQoSControlConnectionTagAccept2) {
        _state = RMBTQoSControlConnectionStateAuthenticated;
        [self transmit];
//        [self writeLine:@"REQUEST CONN TIMEOUT 10000" withTag:RMBTQoSControlConnectionTagRequestTimeout];
//        [self readLineWithTag:RMBTQoSControlConnectionTagRequestTimeout];
//    } else if (tag == RMBTQoSControlConnectionTagRequestTimeout) {
//        [_delegate qosControlConnectionDidStart:self];
    } else if (tag == RMBTQoSControlConnectionTagCommand) {
        [self doneWithResult:line error:nil];
    } else {
        NSParameterAssert(false);
        _state = RMBTQoSControlConnectionStateDisconnecting;
        [_socket disconnect];
    }
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag {
    if (tag == RMBTQoSControlConnectionTagCommand && !_currentReadReply) {
        [self doneWithResult:nil error:nil];
    }
}

- (void)doneWithResult:(NSString*)result error:(NSError*)error {
    if (error) {
        NSParameterAssert(_currentCommandError);
        _currentCommandError(error, nil);
    } else {
        NSParameterAssert(_currentCommandSuccess);
        _currentCommandSuccess(result);
    }
    _currentCommandSuccess = nil;
    _currentCommandError = nil;
    _currentCommand = nil;
    dispatch_resume(_commandsQueue);
}

- (void)sendCommand:(NSString*)line readReply:(BOOL)readReply success:(RMBTSuccessBlock)success error:(RMBTErrorBlock)error {
    dispatch_async(_commandsQueue, ^{
        dispatch_suspend(_commandsQueue);

        _currentCommand = line;
        _currentReadReply = readReply;
        _currentCommandSuccess = success;
        _currentCommandError = error;

        // Connected?
        if (_state == RMBTQoSControlConnectionStateDisconnected) {
            [self connect];
        } else {
            NSParameterAssert(_state == RMBTQoSControlConnectionStateAuthenticated);
            [self transmit];
        }
    });
}

- (void)close {
    NSParameterAssert(!_currentCommand);
    _state = RMBTQoSControlConnectionStateDisconnecting;
    [_socket disconnect];
}

- (void)transmit {
    NSParameterAssert(_currentCommand);
    [self writeLine:_currentCommand withTag:RMBTQoSControlConnectionTagCommand];
    if (_currentReadReply) {
        [self readLineWithTag:RMBTQoSControlConnectionTagCommand];
    }
}
#pragma mark - Socket helpers

- (void)readLineWithTag:(long)tag {
    [_socket readDataToData:[@"\n" dataUsingEncoding:NSASCIIStringEncoding] withTimeout:RMBT_QOS_CC_TIMEOUT_S tag:tag];
}

- (void)writeLine:(NSString*)line withTag:(long)tag {
//    RMBTLog(@"TX %@", line);
    [_socket writeData:[[line stringByAppendingString:@"\n"] dataUsingEncoding:NSASCIIStringEncoding] withTimeout:RMBT_QOS_CC_TIMEOUT_S tag:tag];
}

@end
