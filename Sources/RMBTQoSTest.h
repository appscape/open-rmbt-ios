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
