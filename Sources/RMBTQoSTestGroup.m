//
//  RMBTQoSTestGroup.m
//  RMBT
//
//  Created by Esad Hajdarevic on 13/11/16.
//  Copyright © 2016 appscape gmbh. All rights reserved.
//

#import "RMBTQoSTestGroup.h"
#import "RMBTQoSDNSTest.h"
#import "RMBTQoSHTTPTest.h"
#import "RMBTQoSTracerouteTest.h"
#import "RMBTQoSWebTest.h"
#import "RMBTQoSUDPTest.h"
#import "RMBTQoSTCPTest.h"
#import "RMBTQoSNonTransparentProxyTest.h"

typedef RMBTQoSTest* (^RMBTTestQoSInitializerBlock)(NSDictionary*);

@interface RMBTQoSTestGroup() {
    RMBTTestQoSInitializerBlock _initializer;
}
@end

@implementation RMBTQoSTestGroup

- (instancetype)initWithKey:(NSString*)key
       localizedDescription:(NSString*)description
                initializer:(RMBTTestQoSInitializerBlock)initializer {
    if (self = [super init]) {
        _key = key;
        _localizedDescription = description;
        _initializer = initializer;
    }
    return self;
}

-(RMBTQoSTest*)testWithParams:(NSDictionary*)params {
    RMBTQoSTest* t = _initializer(params);
    t.group = self;
    return t;
}

+ (instancetype)groupForKey:(NSString*)key localizedDescription:(NSString*)description {
    RMBTTestQoSInitializerBlock initializer;

    if ([key isEqualToString:@"dns"]) {
        initializer = ^(NSDictionary *p) {
             return [[RMBTQoSDNSTest alloc] initWithParams:p];
        };
    } else if ([key isEqualToString:@"http_proxy"]) {
        initializer = ^(NSDictionary *p) {
            return [[RMBTQoSHTTPTest alloc] initWithParams:p];
        };
    } else if ([key isEqualToString:@"traceroute"]) {
        initializer = ^(NSDictionary *p) {
            return [[RMBTQoSTracerouteTest alloc] initWithParams:p masked:NO];
        };
    } else if ([key isEqualToString:@"traceroute_masked"]) {
        initializer = ^(NSDictionary *p) {
            return [[RMBTQoSTracerouteTest alloc] initWithParams:p masked:YES];
        };
    } else if ([key isEqualToString:@"website"]) {
        initializer = ^(NSDictionary *p) {
            return [[RMBTQoSWebTest alloc] initWithParams:p];
        };
    } else if ([key isEqualToString:@"udp"]) {
        initializer = ^(NSDictionary *p) {
            return [[RMBTQoSUDPTest alloc] initWithParams:p];
        };
    } else if ([key isEqualToString:@"tcp"]) {
        initializer = ^(NSDictionary *p) {
            return [[RMBTQoSTCPTest alloc] initWithParams:p];
        };
    } else if ([key isEqualToString:@"non_transparent_proxy"]) {
        initializer = ^(NSDictionary *p) {
            return [[RMBTQoSNonTransparentProxyTest alloc] initWithParams:p];
        };
    } else {
        RMBTLog(@"Unknown QoS group: %@", key);
        return nil;
    }

    return [[RMBTQoSTestGroup alloc] initWithKey:key
                            localizedDescription:description
                                     initializer:initializer];
}

- (NSString*)description {
    return [NSString stringWithFormat:@"RMBTQoSTestGroup (key=%@)", _key];
}

@end
