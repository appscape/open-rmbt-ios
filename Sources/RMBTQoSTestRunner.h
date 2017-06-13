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
#import "RMBTQoSTest.h"

@protocol RMBTQoSTestRunnerDelegate <NSObject>
- (void)qosRunnerDidFail;
- (void)qosRunnerDidStartWithTestGroups:(NSArray<RMBTQoSTestGroup*>*)groups;
//- (void)qosRunnerDidFinishTestInGroup:(RMBTQoSTestGroup*)group groupProgress:(NSProgress*)gp totalProgress:(NSProgress*)tp;

- (void)qosRunnerDidUpdateProgress:(float)p inGroup:(RMBTQoSTestGroup*)group totalProgress:(float)tp;

- (void)qosRunnerDidCompleteWithResults:(NSArray<NSDictionary*> *)results;
@end

@interface RMBTQoSTestRunner : NSObject
- (instancetype)initWithDelegate:(id<RMBTQoSTestRunnerDelegate>)delegate;
- (void)startWithToken:(NSString*)token; // needed for qos control server connection 
- (void)cancel;
@end
