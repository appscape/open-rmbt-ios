//
//  RMBTQoSTest.h
//  RMBT
//
//  Created by Esad Hajdarevic on 13/11/16.
//  Copyright © 2016 appscape gmbh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RMBTQoSTestGroup.h"
#import "RMBTProgress.h"

typedef NS_ENUM(NSInteger, RMBTQoSTestStatus) {
    RMBTQoSTestStatusUnknown,
    RMBTQoSTestStatusOk,
    RMBTQoSTestStatusError,
    RMBTQoSTestStatusTimeout
};


@interface RMBTQoSTest : NSOperation {
    @protected
    RMBTProgress *_progress;
}

@property (nonatomic, strong) RMBTQoSTestGroup *group;

@property (nonatomic, readonly) NSUInteger concurrencyGroup;
@property (nonatomic, readonly) NSString *uid;
@property (nonatomic, readonly) uint64_t timeoutNanos;

@property (nonatomic, readonly) NSDictionary *result;
@property (nonatomic, readonly) NSNumber *durationNanos;

@property (nonnull, readonly) RMBTProgress *progress;

@property (nonatomic, assign) RMBTQoSTestStatus status;

- (instancetype)initWithParams:(NSDictionary*)params;
- (NSInteger)timeoutSeconds;

- (NSString*)statusName;

@end
