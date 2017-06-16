//
//  RMBTHistoryQoSSingleResult.m
//  RMBT
//
//  Created by Esad Hajdarevic on 11/12/16.
//  Copyright © 2016 appscape gmbh. All rights reserved.
//

#import "RMBTHistoryQoSSingleResult.h"

@implementation RMBTHistoryQoSSingleResult

- (instancetype)initWithResponse:(NSDictionary*)response {
    if (self = [super init]) {
        NSInteger failed = [[response valueForKey:@"failure_count"] integerValue];
        NSInteger succeeded = [[response valueForKey:@"success_count"] integerValue];
        _successful = (failed == 0 && succeeded > 0);
        _summary = response[@"test_summary"];
        _details = response[@"test_desc"];
        _uid = response[@"uid"];
    }
    return self;
}

- (UIImage*)statusIcon {
    return [UIImage imageNamed: self.successful ? @"traffic_lights_green" : @"traffic_lights_red"];
}

@end
