//
//  RMBTQoSCCTest.m
//  RMBT
//
//  Created by Esad Hajdarevic on 18/03/17.
//  Copyright © 2017 appscape gmbh. All rights reserved.
//

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
