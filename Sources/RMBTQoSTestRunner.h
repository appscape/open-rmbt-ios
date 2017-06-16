//
//  RMBTQoSTestRunner.h
//  RMBT
//
//  Created by Esad Hajdarevic on 13/11/16.
//  Copyright © 2016 appscape gmbh. All rights reserved.
//

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
