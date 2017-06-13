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

#import "RMBTQoSTestRunner.h"
#import "RMBTQoSTestGroup.h"
#import "RMBTQoSTest.h"
#import "RMBTQoSCCTest.h"
#import "RMBTProgress.h"
#import "RMBTQosWebTestURLProtocol.h"

@interface RMBTQoSTestRunner() {
    __weak id<RMBTQoSTestRunnerDelegate> _delegate;
    NSArray<RMBTQoSTestGroup*> *_groups;
    NSArray<RMBTQoSTest*> *_tests;

    NSDictionary <RMBTQoSControlConnectionParams*,RMBTQoSControlConnection*> *_controlConnections;

    NSOperationQueue *_queue;
    dispatch_queue_t _notificationQueue;

    NSMutableDictionary *_results;

    BOOL _dead;
}
@property (nonatomic, readonly) RMBTCompositeProgress *totalProgress;
@end

@implementation RMBTQoSTestRunner

- (instancetype)initWithDelegate:(id<RMBTQoSTestRunnerDelegate>)delegate {
    if (self = [super init]) {
        _delegate = delegate;
        _queue = [[NSOperationQueue alloc] init];
        _queue.suspended = YES;
        _queue.maxConcurrentOperationCount = 4;
        _notificationQueue = dispatch_queue_create("at.rtr.rmbt.qostestrunner.notification", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

// Fetches qos objectives from control server and initializes internal state, enqueuing all tests to run
- (void)startWithToken:(NSString*)token {
    _results = [NSMutableDictionary dictionary];

    [[RMBTControlServer sharedControlServer] getQoSParams:^(NSDictionary* response) {
        NSDictionary *objectives = response[@"objectives"];
        if (!objectives) {
            RMBTLog(@"Error getting QoS params: no objectives received");
            [self fail];
        } else {
            NSMutableArray *tests = [NSMutableArray array];
            NSMutableArray *groups = [NSMutableArray array];
            NSMutableArray *groupsProgress = [NSMutableArray array];

            [objectives enumerateKeysAndObjectsUsingBlock:^(NSString*  _Nonnull key, NSArray<NSDictionary *> *  _Nonnull obj, BOOL * _Nonnull stop) {
                NSString *desc = [RMBTControlServer sharedControlServer].qosTestNames[[key uppercaseString]] ?: key;
                RMBTQoSTestGroup *g = [RMBTQoSTestGroup groupForKey:key localizedDescription:desc];
                if (g) {
                    NSMutableArray *groupTestsProgress = [NSMutableArray array];
                    for (NSDictionary* params in obj) {
                        RMBTQoSTest *t = [g testWithParams:params];
                        if (t) {
                            [tests addObject:t];
                            [groupTestsProgress addObject:t.progress];
                        }
                    }
                    if (groupTestsProgress.count > 0) {
                        [groups addObject:g];
                        RMBTCompositeProgress *gp = [[RMBTCompositeProgress alloc] initWithChildren:groupTestsProgress];
                        __weak RMBTQoSTestGroup *wg = g;
                        __weak RMBTQoSTestRunner *weakSelf = self;

                        gp.onFractionCompleteChange = ^(float p) {
                            typeof(self) strongSelf = weakSelf;
                            if (!strongSelf) return;

                            dispatch_async(strongSelf->_notificationQueue, ^{
                                [strongSelf->_delegate qosRunnerDidUpdateProgress:p inGroup:wg totalProgress:strongSelf.totalProgress.fractionCompleted];
                            });
                        };

                        [groupsProgress addObject:gp];
                    }
                }
            }];

            RMBTLog(@"Starting QoS with tests: %@", tests);

            _tests = tests;
            _groups = groups;
            _totalProgress = [[RMBTCompositeProgress alloc] initWithChildren:groupsProgress];

            // Construct a map of all different control server connection params and create/reuse a connection for each one,
            // then assign them to tests that use them:
            _controlConnections = [_tests bk_reduce:[NSMutableDictionary dictionary] withBlock:^id(NSMutableDictionary *connections, RMBTQoSTest *test) {
                if ([test isKindOfClass:[RMBTQoSCCTest class]]) {
                    RMBTQoSCCTest* ccTest = (RMBTQoSCCTest*)test;
                    RMBTQoSControlConnectionParams *ccParams = ccTest.controlConnectionParams;
                    NSParameterAssert(ccParams);
                    RMBTQoSControlConnection *conn = connections[ccParams];
                    if (!conn) {
                        conn = [[RMBTQoSControlConnection alloc] initWithConnectionParams:ccParams token:token];
                        connections[ccParams] = conn;
                    }
                    ccTest.controlConnection = conn;
                }
                return connections;
            }];

            [_delegate qosRunnerDidStartWithTestGroups:_groups];

            [self enqueue];
        }
    } error:^(NSError *error, NSDictionary *info) {
        RMBTLog(@"Error getting QoS params %@ %@", error, info);
        [self fail];
    }];
}


- (void)fail {
    [self cancel];
    [_delegate qosRunnerDidFail];
}

- (void)cancel {
    [_queue cancelAllOperations];
    [self done];
}

- (void)done {
    [RMBTQosWebTestURLProtocol stop];
    for (RMBTQoSControlConnection *c in [_controlConnections allValues]) {
        [c close];
    }
    _dead = YES;
}

- (void)enqueue {
    NSParameterAssert(_queue);
    NSParameterAssert(!_dead);
    NSParameterAssert(_tests);

    __weak typeof(self) weakSelf = self;

    dispatch_group_t group = dispatch_group_create();

    if (_tests.count > 0) {
        [RMBTQosWebTestURLProtocol start];

        NSArray<RMBTQoSTest*> *testsByConcurrency = [_tests sortedArrayUsingComparator:^NSComparisonResult(RMBTQoSTest* _Nonnull t1, RMBTQoSTest*  _Nonnull t2) {
            if (t1.concurrencyGroup < t2.concurrencyGroup) {
                return NSOrderedAscending;
            } else if (t1.concurrencyGroup > t2.concurrencyGroup) {
                return NSOrderedDescending;
            } else {
                return NSOrderedSame;
            }
        }];

        NSUInteger lastConcurrencyGroup = testsByConcurrency.firstObject.concurrencyGroup;
        NSMutableArray *lastConcurrencyGroupTests = [NSMutableArray array];
        NSOperation *marker = nil;

        for (RMBTQoSTest* t in testsByConcurrency) {
            if (t.concurrencyGroup != lastConcurrencyGroup) {
                marker = [[NSOperation alloc] init];
                marker.completionBlock = ^{
                    RMBTLog(@"QoS concurrency group %ld finished", lastConcurrencyGroup);
                };
                marker.name = [NSString stringWithFormat:@"End of concurrency group %ld", (unsigned long)lastConcurrencyGroup];
                for (RMBTQoSTest *pt in lastConcurrencyGroupTests) {
                    [marker addDependency:pt];
                }
                [_queue addOperation:marker];
                lastConcurrencyGroupTests = [NSMutableArray array];
                lastConcurrencyGroup = t.concurrencyGroup;
            }

            if (marker) { [t addDependency:marker]; }
            [lastConcurrencyGroupTests addObject:t];

            __weak RMBTQoSTest *weakTest = t;

            dispatch_group_enter(group);

            t.completionBlock = ^{
                typeof(self) strongSelf = weakSelf;
                if (!strongSelf) return;

                dispatch_async(strongSelf->_notificationQueue, ^{
                    NSCParameterAssert(weakTest);
                    // Add test type and uid to result dictionary and store it
                    NSMutableDictionary *result = [weakTest.result mutableCopy];
                    if (result) {
                        result[@"test_type"] = weakTest.group.key;
                        result[@"qos_test_uid"] = weakTest.uid;
                        if (weakTest.durationNanos) {
                            result[@"duration_ns"] = weakTest.durationNanos;
                        }
                        [strongSelf->_results setObject:result forKey:weakTest.uid];
                    }

                    // Ensure test progress is complete
                    weakTest.progress.completedUnitCount = weakTest.progress.totalUnitCount;

                    dispatch_group_leave(group);
                });
            };

            [_queue addOperation:t];
        }
    }

    [_queue addOperationWithBlock:^{
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        typeof(self) strongSelf = weakSelf;
        if (!strongSelf) return;
        dispatch_async(strongSelf->_notificationQueue, ^{
            [strongSelf->_delegate qosRunnerDidCompleteWithResults:[strongSelf->_results allValues]];
            [strongSelf done];
        });
    }];

    _queue.suspended = NO;
}

@end
