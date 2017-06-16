//
//  RMBTQoSControlConnectionParams.m
//  RMBT
//
//  Created by Esad Hajdarevic on 18/03/17.
//  Copyright © 2017 appscape gmbh. All rights reserved.
//

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
