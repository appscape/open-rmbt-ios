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
#import "RMBTTestParams.h"

@class RMBTTestWorker;

// All delegate methods are dispatched on the supplied delegate queue
@protocol RMBTTestWorkerDelegate <NSObject>
- (void)testWorker:(RMBTTestWorker*)worker didFinishDownlinkPretestWithChunkCount:(NSUInteger)chunks;

- (void)testWorker:(RMBTTestWorker*)worker didMeasureLatencyWithServerNanos:(uint64_t)serverNanos clientNanos:(uint64_t)clientNanos;
- (void)testWorkerDidFinishLatencyTest:(RMBTTestWorker*)worker;

- (uint64_t)testWorker:(RMBTTestWorker*)worker didStartDownlinkTestAtNanos:(uint64_t)nanos;
- (void)testWorker:(RMBTTestWorker*)worker didDownloadLength:(uint64_t)length atNanos:(uint64_t)nanos;
- (void)testWorkerDidFinishDownlinkTest:(RMBTTestWorker*)worker;

- (void)testWorker:(RMBTTestWorker*)worker didFinishUplinkPretestWithChunkCount:(NSUInteger)chunks;

- (uint64_t)testWorker:(RMBTTestWorker*)worker didStartUplinkTestAtNanos:(uint64_t)nanos;
- (void)testWorker:(RMBTTestWorker*)worker didUploadLength:(uint64_t)length atNanos:(uint64_t)nanos;
- (void)testWorkerDidFinishUplinkTest:(RMBTTestWorker*)worker;

- (void)testWorkerDidStop:(RMBTTestWorker*)worker;

- (void)testWorkerDidFail:(RMBTTestWorker*)worker;
@end

@interface RMBTTestWorker : NSObject

@property (nonatomic, readonly) NSUInteger index;
@property (nonatomic, readonly) uint64_t totalBytesUploaded, totalBytesDownloaded;

@property (nonatomic, readonly) NSString *negotiatedEncryptionString;
@property (nonatomic, readonly) NSString *localIp, *serverIp;

- (id)initWithDelegate:(id<RMBTTestWorkerDelegate>)delegate delegateQueue:(dispatch_queue_t)queue index:(NSUInteger)index testParams:(RMBTTestParams*)params;

- (void)startDownlinkPretest;
- (void)stop;
- (void)startLatencyTest;
- (void)startDownlinkTest;
- (void)startUplinkPretest;
- (void)startUplinkTest;

- (void)abort;

@end
