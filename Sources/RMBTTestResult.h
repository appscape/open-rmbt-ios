/*
 * Copyright 2013 appscape gmbh
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
#import <CoreLocation/CoreLocation.h>

#import "RMBTThroughputHistory.h"
#import "RMBTConnectivity.h"

@interface RMBTTestResult : NSObject

@property (nonatomic, readonly) NSUInteger threadCount;
@property (nonatomic, readonly) uint64_t resolutionNanos;

@property (nonatomic, readonly) NSArray *pings;
@property (nonatomic, readonly) uint64_t bestPingNanos;

@property (nonatomic, readonly) RMBTThroughputHistory *totalDownloadHistory, *totalUploadHistory, *totalCurrentHistory;
@property (nonatomic, readonly) NSArray *perThreadDownloadHistories, *perThreadUploadHistories;

@property (nonatomic, readonly) NSArray *locations;

- (instancetype)initWithResolutionNanos:(uint64_t)nanos;
- (instancetype)init __attribute__((unavailable("use initWithResolutionNanos:")));

- (void)addPingWithServerNanos:(uint64_t)serverNanos clientNanos:(uint64_t)clientNanos;

- (NSArray*)addLength:(uint64_t)length atNanos:(uint64_t)ns forThreadIndex:(NSUInteger)threadIndex;
- (void)addLocation:(CLLocation*)location;
- (void)addConnectivity:(RMBTConnectivity*)connectivity;
- (RMBTConnectivity*)lastConnectivity;

- (void)startDownloadWithThreadCount:(NSUInteger)threadCount;
- (void)startUpload; // Per spec has same thread count as download
// Called at the end of each phase. Flushes out values to total history.
- (NSArray*)flush;

- (NSDictionary*)resultDictionary;
- (NSDictionary*)locationsResultDictionary;

@end