//
//  RMBTQoSIPTest.m
//  RMBT
//
//  Created by Esad Hajdarevic on 26/05/17.
//  Copyright © 2017 appscape gmbh. All rights reserved.
//

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
