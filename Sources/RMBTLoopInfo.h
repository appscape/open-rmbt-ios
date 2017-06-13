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

@interface RMBTLoopInfo : NSObject

@property(nonatomic, assign) NSUInteger waitMeters;
@property(nonatomic, assign) NSUInteger waitMinutes;

@property(nonatomic, assign) NSUInteger current; // 1-based, but initialized with 0 -> increment before first run
@property(nonatomic, assign) NSUInteger total;

- (instancetype)initWithMeters:(NSUInteger)meters minutes:(NSUInteger)minutes total:(NSUInteger)total;

- (void)increment;
- (BOOL)isFinished;
- (NSDictionary*)params;

@end
