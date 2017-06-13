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

// Ligtweight replacement for NSProgress that supports iOS 8 and allows for simple composition
// without use of thread-associated variables and without reliance on KVO.

@interface RMBTProgressBase : NSObject
@property (nonatomic, readonly) float fractionCompleted;
@property (nonatomic, copy) void(^onFractionCompleteChange)(float p);
@end

@interface RMBTProgress : RMBTProgressBase
- (instancetype)initWithTotalUnitCount:(uint64_t)count;
@property (nonatomic, readonly) uint64_t totalUnitCount;
@property (nonatomic, assign) uint64_t completedUnitCount;
@end

@interface RMBTCompositeProgress : RMBTProgressBase
- (instancetype)initWithChildren:(NSArray<RMBTProgressBase*>*)children;
@end
