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

#import <UIKit/UIKit.h>
#import "RMBTTestRunner.h"

// A base class for both regular test view controller and loop view controller, which have different
// display logic. The behaviour is customized by implementing the RMBTBaseTestViewControllerSubclass protocol
@interface RMBTBaseTestViewController : UIViewController
- (void)startTestWithExtraParams:(NSDictionary*)params;
- (void)cancelTest;
@end

@class RMBTConnectivity;

@protocol RMBTBaseTestViewControllerSubclass

- (void)onTestUpdatedTotalProgress:(NSUInteger)percentage;

- (void)onTestUpdatedStatus:(NSString*)status;
- (void)onTestUpdatedConnectivity:(RMBTConnectivity*)connectivity;
- (void)onTestUpdatedLocation:(CLLocation*)location;
- (void)onTestUpdatedServerName:(NSString*)name;

- (void)onTestStartedPhase:(RMBTTestRunnerPhase)phase;
- (void)onTestFinishedPhase:(RMBTTestRunnerPhase)phase;

- (void)onTestMeasuredLatency:(uint64_t)nanos;
- (void)onTestMeasuredTroughputs:(NSArray*)throughputs inPhase:(RMBTTestRunnerPhase)phase;
- (void)onTestMeasuredDownloadSpeed:(uint32_t)kbps;
- (void)onTestMeasuredUploadSpeed:(uint32_t)kbps;

- (void)onTestStartedQoSWithGroups:(NSArray*)groups;
- (void)onTestUpdatedProgress:(float)progress inQoSGroup:(RMBTQoSTestGroup*)group;

- (void)onTestCompletedWithResult:(RMBTHistoryResult*)result qos:(BOOL)qosPerformed;
- (void)onTestCancelledWithReason:(RMBTTestRunnerCancelReason)reason;

@end
