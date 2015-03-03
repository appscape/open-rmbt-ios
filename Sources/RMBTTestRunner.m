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

#import "RMBTTestRunner.h"
#import "RMBTTestWorker.h"
#import "RMBTSettings.h"
#import "RMBTPing.h"

#import "RMBTLocationTracker.h"
#import "RMBTConnectivityTracker.h"

static NSString * const RMBTTestStatusNone = @"NONE";
static NSString * const RMBTTestStatusAborted = @"ABORTED";
static NSString * const RMBTTestStatusError = @"ERROR";
static NSString * const RMBTTestStatusErrorFetching = @"ERROR_FETCH";
static NSString * const RMBTTestStatusErrorSubmitting = @"ERROR_SUBMIT";
static NSString * const RMBTTestStatusErrorBackgrounded = @"ABORTED_BACKGROUNDED";
static NSString * const RMBTTestStatusEnded = @"END";

static const NSTimeInterval RMBTTestRunnerProgressUpdateInterval = 0.1; //seconds

// Used to assert that we are running on a correct queue via dispatch_queue_set_specific(),
// as dispatch_get_current_queue() is deprecated.
static void *const kWorkerQueueIdentityKey = (void *)&kWorkerQueueIdentityKey;
#define ASSERT_ON_WORKER_QUEUE() NSAssert(dispatch_get_specific(kWorkerQueueIdentityKey) != NULL, @"Running on a wrong queue")

@interface RMBTTestRunner()<RMBTTestWorkerDelegate, RMBTConnectivityTrackerDelegate> {
    __weak id<RMBTTestRunnerDelegate> _delegate;
    RMBTTestParams *_testParams;
    RMBTTestResult *_testResult;

    RMBTTestRunnerPhase _phase;

    // Flag indicating that downlink pretest in one of the workers was too slow and we need to
    // continue with a single thread only
    BOOL _singleThreaded;
    
    NSMutableArray *_workers;
    dispatch_queue_t _workerQueue; // We perform all work on this background queue. Workers also callback onto this queue.

    NSUInteger _finishedWorkers;
    NSUInteger _activeWorkers;

    dispatch_source_t _timer;

    uint64_t _progressStartedAtNanos;
    uint64_t _progressDurationNanos;
    RMBTBlock _progressCompletionHandler;

    uint64_t _downlinkTestStartedAtNanos;
    uint64_t _uplinkTestStartedAtNanos;

    RMBTConnectivityTracker *_connectivityTracker;

    // Snapshots of the network interface byte counts at a given phase
    RMBTConnectivityInterfaceInfo _startInterfaceInfo;
    RMBTConnectivityInterfaceInfo _uplinkStartInterfaceInfo, _uplinkEndInterfaceInfo;
    RMBTConnectivityInterfaceInfo _downlinkStartInterfaceInfo, _downlinkEndInterfaceInfo;

    BOOL _dead;
}

@end

@implementation RMBTTestRunner

- (id)initWithDelegate:(id<RMBTTestRunnerDelegate>)delegate {
    if (self = [super init]) {
        _delegate = delegate;
        _phase = RMBTTestRunnerPhaseNone;
        _workerQueue = dispatch_queue_create("at.rtr.rmbt.testrunner", NULL);

        void *nonNullValue = kWorkerQueueIdentityKey;
		dispatch_queue_set_specific(_workerQueue, kWorkerQueueIdentityKey, nonNullValue, NULL);

        _connectivityTracker = [[RMBTConnectivityTracker alloc] initWithDelegate:self stopOnMixed:YES];
        [_connectivityTracker start];
    }
    return self;
}

// Run on main queue (called from VC)
- (void)start {
    dispatch_async(_workerQueue, ^{
        NSAssert(_phase == RMBTTestRunnerPhaseNone, @"Invalid state");
        NSAssert(!_dead, @"Invalid state");

        CLLocation *l = [RMBTLocationTracker sharedTracker].location;

        NSDictionary *locationJSON = nil;

        if (l) {
            locationJSON = [l paramsDictionary];
        }

        NSDictionary *params = @{
          @"testCounter": [NSNumber numberWithUnsignedInteger:[RMBTSettings sharedSettings].testCounter],
          @"previousTestStatus": RMBTValueOrString([RMBTSettings sharedSettings].previousTestStatus, RMBTTestStatusNone),
          @"location": RMBTValueOrNull(locationJSON),
        };

        // Notice that we post previous counter (the test before this one) when requesting the params
        [RMBTSettings sharedSettings].testCounter += 1;
        self.phase = RMBTTestRunnerPhaseFetchingTestParams;

        [[RMBTControlServer sharedControlServer] getTestParamsWithParams:params success:^(id testParams) {
            dispatch_async(_workerQueue, ^{
                [self continueWithTestParams:testParams];
            });
        } error:^{
            dispatch_async(_workerQueue, ^{
                [self cancelWithReason:RMBTTestRunnerCancelReasonErrorFetchingTestingParams];
            });
        }];
    });
}

// Run on worker queue
- (void)continueWithTestParams:(RMBTTestParams*)testParams {
    ASSERT_ON_WORKER_QUEUE();

    if (_dead) return; // Cancelled
    NSAssert(_phase == RMBTTestRunnerPhaseFetchingTestParams || _phase == RMBTTestRunnerPhaseNone, @"Invalid state");

    _testParams = testParams;
    _testResult = [[RMBTTestResult alloc] initWithResolutionNanos:RMBT_TEST_SAMPLING_RESOLUTION_MS * NSEC_PER_MSEC];
    [_testResult markTestStart];

    _workers = [NSMutableArray arrayWithCapacity:_testParams.threadCount];

    for (int i=0;i<_testParams.threadCount;i++) {
        [_workers addObject:[[RMBTTestWorker alloc] initWithDelegate:self delegateQueue:_workerQueue index:i testParams:_testParams]];
    }

    // Start observing app going to background notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidSwitchToBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];

    // Register as observer for location tracker updates
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(locationsDidChange:) name:RMBTLocationTrackerNotification object:nil];
    // ..and force an update right away
    [[RMBTLocationTracker sharedTracker] forceUpdate];
    [_connectivityTracker forceUpdate];

    RMBTBlock startInit = ^{
        [self startPhase:RMBTTestRunnerPhaseInit withAllWorkers:YES performingSelector:@selector(startDownlinkPretest) expectedDuration:_testParams.pretestDuration completion:nil];
    };

    if (_testParams.waitDuration > 0) {
        // Let progress timer run, then start init
        [self startPhase:RMBTTestRunnerPhaseWait withAllWorkers:NO performingSelector:nil expectedDuration:_testParams.waitDuration completion:startInit];
    } else {
        startInit();
    }
}

#pragma mark - Test worker delegate method

- (void)testWorker:(RMBTTestWorker*)worker didFinishDownlinkPretestWithChunkCount:(NSUInteger)chunks {
    ASSERT_ON_WORKER_QUEUE();
    NSAssert(_phase == RMBTTestRunnerPhaseInit, @"Invalid state");
    NSAssert(!_dead, @"Invalid state");

    RMBTLog(@"Thread %u: finished download pretest (chunks = %d)", worker.index, chunks);
    if (!_singleThreaded && chunks <= _testParams.pretestMinChunkCountForMultithreading) {
        _singleThreaded = YES;
    }
    if ([self markWorkerAsFinished]) {
        if (_singleThreaded) {
            RMBTLog(@"Downloaded <= %u chunks in the pretest, continuing with single thread.", _testParams.pretestMinChunkCountForMultithreading);
            _activeWorkers = _testParams.threadCount - 1;
            _finishedWorkers = 0;
            for (int i=1;i<_testParams.threadCount;i++) {
                [[_workers objectAtIndex:i] stop];
            }
            [_testResult startDownloadWithThreadCount:1];
        } else {
            [_testResult startDownloadWithThreadCount:_testParams.threadCount];
            [self startPhase:RMBTTestRunnerPhaseLatency withAllWorkers:NO performingSelector:@selector(startLatencyTest) expectedDuration:0 completion:nil];
        }
    }
}

- (void)testWorkerDidStop:(RMBTTestWorker *)worker {
    ASSERT_ON_WORKER_QUEUE();
    NSAssert(_phase == RMBTTestRunnerPhaseInit, @"Invalid state");
    NSAssert(!_dead, @"Invalid state");

    RMBTLog(@"Thread %u: stopped", worker.index);
    [_workers removeObject:worker];
    if ([self markWorkerAsFinished]) {
        // We stopped all but one workers because of slow connection. Proceed to latency with single worker.
        [self startPhase:RMBTTestRunnerPhaseLatency withAllWorkers:NO performingSelector:@selector(startLatencyTest) expectedDuration:0 completion:nil];
    }
}

- (void)testWorker:(RMBTTestWorker*)worker didMeasureLatencyWithServerNanos:(uint64_t)serverNanos clientNanos:(uint64_t)clientNanos {
    ASSERT_ON_WORKER_QUEUE();
    NSAssert(_phase == RMBTTestRunnerPhaseLatency, @"Invalid state");
    NSAssert(!_dead, @"Invalid state");

    RMBTLog(@"Thread %u: pong (server = %" PRIu64 ", client = %" PRIu64 ")", worker.index, serverNanos, clientNanos);

    [_testResult addPingWithServerNanos:serverNanos clientNanos:clientNanos];

    float p = ((float)_testResult.pings.count) / _testParams.pingCount;
    dispatch_async(dispatch_get_main_queue(),^{
        [_delegate testRunnerDidUpdateProgress:p inPhase:_phase];
    });
}

- (void)testWorkerDidFinishLatencyTest:(RMBTTestWorker*)worker {
    ASSERT_ON_WORKER_QUEUE();
    NSAssert(_phase == RMBTTestRunnerPhaseLatency, @"Invalid state");
    NSAssert(!_dead, @"Invalid state");

    if ([self markWorkerAsFinished]) {
        [self startPhase:RMBTTestRunnerPhaseDown withAllWorkers:YES performingSelector:@selector(startDownlinkTest) expectedDuration:_testParams.testDuration completion:nil];
    }
}

- (uint64_t)testWorker:(RMBTTestWorker *)worker didStartDownlinkTestAtNanos:(uint64_t)nanos {
    ASSERT_ON_WORKER_QUEUE();
    NSAssert(_phase == RMBTTestRunnerPhaseDown, @"Invalid state");
    NSAssert(!_dead, @"Invalid state");

    if (_downlinkTestStartedAtNanos == 0) {
        _downlinkStartInterfaceInfo = [[_testResult lastConnectivity] getInterfaceInfo];
        _downlinkTestStartedAtNanos = nanos;
    }

    RMBTLog(@"Thread %u: started downlink test with delay %" PRIu64, worker.index, nanos-_downlinkTestStartedAtNanos);

    return _downlinkTestStartedAtNanos;
}

- (void)testWorker:(RMBTTestWorker*)worker didDownloadLength:(uint64_t)length atNanos:(uint64_t)nanos {
    ASSERT_ON_WORKER_QUEUE();
    NSAssert(_phase == RMBTTestRunnerPhaseDown, @"Invalid state");
    NSAssert(!_dead, @"Invalid state");

    NSArray* measuredThroughputs = [_testResult addLength:length atNanos:nanos forThreadIndex:worker.index];
    if (measuredThroughputs) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [_delegate testRunnerDidMeasureThroughputs:measuredThroughputs inPhase:RMBTTestRunnerPhaseDown];
        });
    }
}

- (void)testWorkerDidFinishDownlinkTest:(RMBTTestWorker *)worker {
    ASSERT_ON_WORKER_QUEUE();
    NSAssert(_phase == RMBTTestRunnerPhaseDown, @"Invalid state");
    NSAssert(!_dead, @"Invalid state");

    if ([self markWorkerAsFinished]) {
        RMBTLog(@"Downlink test finished");

        _downlinkEndInterfaceInfo = [[_testResult lastConnectivity] getInterfaceInfo];

        NSArray *measuredThroughputs = [_testResult flush];

        [_testResult.totalDownloadHistory log];

        if (measuredThroughputs) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [_delegate testRunnerDidMeasureThroughputs:measuredThroughputs inPhase:RMBTTestRunnerPhaseDown];
            });
        }

        [self startPhase:RMBTTestRunnerPhaseInitUp withAllWorkers:YES performingSelector:@selector(startUplinkPretest) expectedDuration:_testParams.pretestDuration completion:nil];
    }
}

- (void)testWorker:(RMBTTestWorker*)worker didFinishUplinkPretestWithChunkCount:(NSUInteger)chunks {
    ASSERT_ON_WORKER_QUEUE();
    NSAssert(_phase == RMBTTestRunnerPhaseInitUp, @"Invalid state");
    NSAssert(!_dead, @"Invalid state");

    RMBTLog(@"Thread %u: finished uplink pretest (chunks = %d)", worker.index, chunks);

    if ([self markWorkerAsFinished]) {
        RMBTLog(@"Uplink pretest finished");
        [_testResult startUpload];
        [self startPhase:RMBTTestRunnerPhaseUp withAllWorkers:YES performingSelector:@selector(startUplinkTest) expectedDuration:_testParams.testDuration completion:nil];
    }
}

- (uint64_t)testWorker:(RMBTTestWorker*)worker didStartUplinkTestAtNanos:(uint64_t)nanos {
    ASSERT_ON_WORKER_QUEUE();
    NSAssert(_phase == RMBTTestRunnerPhaseUp, @"Invalid state");
    NSAssert(!_dead, @"Invalid state");

    uint64_t delay;
    if (_uplinkTestStartedAtNanos == 0) {
        _uplinkTestStartedAtNanos = nanos;
        delay = 0;
        _uplinkStartInterfaceInfo = [[_testResult lastConnectivity] getInterfaceInfo];
    } else {
        delay = nanos - _uplinkTestStartedAtNanos;
    }

    RMBTLog(@"Thread %u: started uplink test with delay %" PRIu64, worker.index, delay);

    return delay;
}

- (void)testWorker:(RMBTTestWorker*)worker didUploadLength:(uint64_t)length atNanos:(uint64_t)nanos {
    ASSERT_ON_WORKER_QUEUE();
    NSAssert(_phase == RMBTTestRunnerPhaseUp, @"Invalid state");
    NSAssert(!_dead, @"Invalid state");

    NSArray* measuredThroughputs = [_testResult addLength:length atNanos:nanos forThreadIndex:worker.index];
    if (measuredThroughputs) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [_delegate testRunnerDidMeasureThroughputs:measuredThroughputs inPhase:RMBTTestRunnerPhaseUp];
        });
    }
}

- (void)testWorkerDidFinishUplinkTest:(RMBTTestWorker *)worker {
    ASSERT_ON_WORKER_QUEUE();
    NSAssert(_phase == RMBTTestRunnerPhaseUp, @"Invalid state");
    NSAssert(!_dead, @"Invalid state");

    if ([self markWorkerAsFinished]) {
        // Stop observing now, test is finished
        [self finalize];

        _uplinkEndInterfaceInfo = [[_testResult lastConnectivity] getInterfaceInfo];

        NSArray *measuredThroughputs = [_testResult flush];
        RMBTLog(@"Uplink test finished.");

        [_testResult.totalUploadHistory log];

        if (measuredThroughputs) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [_delegate testRunnerDidMeasureThroughputs:measuredThroughputs inPhase:RMBTTestRunnerPhaseUp];
            });
        }

        self.phase = RMBTTestRunnerPhaseSubmittingTestResult;

        [self submitResult];
    }
}

- (void)testWorkerDidFail:(RMBTTestWorker *)worker {
    ASSERT_ON_WORKER_QUEUE();
    NSAssert(!_dead, @"Invalid state");
    [self cancelWithReason:RMBTTestRunnerCancelReasonNoConnection];
}

- (void)submitResult {
    dispatch_async(_workerQueue, ^{
        if (_dead) return; // cancelled

        NSDictionary *result = [self resultDictionary];

        self.phase = RMBTTestRunnerPhaseSubmittingTestResult;

        [[RMBTControlServer sharedControlServer] submitResult:result success:^(id response) {
            dispatch_async(_workerQueue, ^{
                self.phase = RMBTTestRunnerPhaseNone;
                _dead = YES;

                [RMBTSettings sharedSettings].previousTestStatus = RMBTTestStatusEnded;

                RMBTHistoryResult *historyResult = [[RMBTHistoryResult alloc] initWithResponse:@{@"test_uuid": _testParams.testUUID}];

                dispatch_async(dispatch_get_main_queue(), ^{
                    [_delegate testRunnerDidCompleteWithResult:historyResult];
                });
            });
        } error:^{
            dispatch_async(_workerQueue, ^{
                [self cancelWithReason:RMBTTestRunnerCancelReasonErrorSubmittingTestResult];
            });
        }];
    });
}

- (NSDictionary*)resultDictionary {
    NSMutableDictionary *result = [NSMutableDictionary dictionaryWithDictionary:[_testResult resultDictionary]];

    result[@"test_token"] = _testParams.testToken;

    // Collect total transfers from all threads
    uint64_t sumBytesDownloaded = 0;
    uint64_t sumBytesUploaded = 0;
    for (RMBTTestWorker* w in _workers) {
        sumBytesDownloaded += w.totalBytesDownloaded;
        sumBytesUploaded += w.totalBytesUploaded;
    }

    NSAssert(sumBytesDownloaded > 0, @"Total bytes <= 0");
    NSAssert(sumBytesUploaded > 0, @"Total bytes <= 0");

    RMBTTestWorker *firstWorker = [_workers objectAtIndex:0];
    [result addEntriesFromDictionary:@{
        @"test_total_bytes_download": [NSNumber numberWithUnsignedLongLong:sumBytesDownloaded],
        @"test_total_bytes_upload": [NSNumber numberWithUnsignedLongLong:sumBytesUploaded],
        @"test_encryption": firstWorker.negotiatedEncryptionString,
        @"test_ip_local": RMBTValueOrNull(firstWorker.localIp),
        @"test_ip_server": RMBTValueOrNull(firstWorker.serverIp),
    }];

    [result addEntriesFromDictionary:[self interfaceBytesResultDictionaryWithStartInfo:_downlinkStartInterfaceInfo
                                                                               endInfo:_downlinkEndInterfaceInfo
                                                                                prefix:@"testdl"]];

    [result addEntriesFromDictionary:[self interfaceBytesResultDictionaryWithStartInfo:_uplinkStartInterfaceInfo
                                                                               endInfo:_uplinkEndInterfaceInfo
                                                                                prefix:@"testul"]];

    [result addEntriesFromDictionary:[self interfaceBytesResultDictionaryWithStartInfo:_startInterfaceInfo
                                                                               endInfo:_uplinkEndInterfaceInfo
                                                                                prefix:@"test"]];

    // Add relative time_(dl/ul)_ns timestamps:
    uint64_t startNanos = _testResult.testStartNanos;

    [result addEntriesFromDictionary:@{
         @"time_dl_ns": [NSNumber numberWithUnsignedLongLong:_downlinkTestStartedAtNanos - startNanos],
         @"time_ul_ns": [NSNumber numberWithUnsignedLongLong:_uplinkTestStartedAtNanos - startNanos]
    }];

    return result;
}

- (NSDictionary*)interfaceBytesResultDictionaryWithStartInfo:(RMBTConnectivityInterfaceInfo)startInfo
                                                     endInfo:(RMBTConnectivityInterfaceInfo)endInfo
                                                      prefix:(NSString*)prefix {
    if (startInfo.bytesReceived <= endInfo.bytesReceived &&
        startInfo.bytesSent < endInfo.bytesSent) {
        return @{
         [NSString stringWithFormat:@"%@_if_bytes_download", prefix]: [NSNumber numberWithUnsignedLongLong:endInfo.bytesReceived - startInfo.bytesReceived],
         [NSString stringWithFormat:@"%@_if_bytes_upload", prefix]: [NSNumber numberWithUnsignedLongLong:endInfo.bytesSent - startInfo.bytesSent]
        };
    } else {
        return @{};
    }
}

#pragma mark - Utility methods

- (void)setPhase:(RMBTTestRunnerPhase)phase {
    if (_phase != RMBTTestRunnerPhaseNone) {
        RMBTTestRunnerPhase oldPhase = _phase;
        dispatch_async(dispatch_get_main_queue(), ^{ [_delegate testRunnerDidFinishPhase:oldPhase]; });
    }

    _phase = phase;

    if (_phase != RMBTTestRunnerPhaseNone) {
        dispatch_async(dispatch_get_main_queue(), ^{ [_delegate testRunnerDidStartPhase:phase]; });
    }
}

- (void)startPhase:(RMBTTestRunnerPhase)phase withAllWorkers:(BOOL)allWorkers performingSelector:(SEL)selector expectedDuration:(NSTimeInterval)duration completion:(RMBTBlock)completionHandler {
    ASSERT_ON_WORKER_QUEUE();

    self.phase = phase;

    _finishedWorkers = 0;
    _progressStartedAtNanos = RMBTCurrentNanos();
    _progressDurationNanos = duration * NSEC_PER_SEC;

    if (_timer) {
        dispatch_source_cancel(_timer);
        _timer = nil;
    }

    NSAssert(!completionHandler || duration > 0, nil);

    if (duration > 0) {
        _progressCompletionHandler = completionHandler;
        _timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
        dispatch_source_set_timer(_timer, DISPATCH_TIME_NOW, RMBTTestRunnerProgressUpdateInterval * NSEC_PER_SEC, 50 * NSEC_PER_MSEC);
        dispatch_source_set_event_handler(_timer, ^{
            uint64_t elapsedNanos = (RMBTCurrentNanos() - _progressStartedAtNanos);
            if (elapsedNanos > _progressDurationNanos) {
                // We've reached end of interval...
                // ..send 1.0 progress one last time..
                dispatch_async(dispatch_get_main_queue(), ^{
                    [_delegate testRunnerDidUpdateProgress:1.0 inPhase:phase];
                });

                // ..then kill the timer
                dispatch_source_cancel(_timer);
                _timer = nil;
                // ..and perform completion handler, if any.
                if (_progressCompletionHandler) {
                    dispatch_async(_workerQueue, _progressCompletionHandler);
                    _progressCompletionHandler = nil;
                }
            } else {
                double p = (double)elapsedNanos/_progressDurationNanos;
                NSAssert(p<=1.0, @"Invalid percentage");
                dispatch_async(dispatch_get_main_queue(), ^{
                    [_delegate testRunnerDidUpdateProgress:p inPhase:phase];
                });
            }
        });
        dispatch_resume(_timer);
    }

    if (!selector) return;

    if (allWorkers) {
        _activeWorkers = _workers.count;
        [_workers makeObjectsPerformSelector:selector];
    } else {
        _activeWorkers = 1;
        [[_workers subarrayWithRange:NSMakeRange(0, 1)] makeObjectsPerformSelector:selector];
    }
}

- (BOOL)markWorkerAsFinished {
    _finishedWorkers++;
    return (_finishedWorkers == _activeWorkers);
}

#pragma mark - Connectivity tracking

- (void)connectivityTrackerDidDetectNoConnectivity:(RMBTConnectivityTracker*)tracker {
    // Ignore for now, let connection time out
}

- (void)connectivityTracker:(RMBTConnectivityTracker *)tracker didDetectConnectivity:(RMBTConnectivity *)connectivity {
    dispatch_async(_workerQueue, ^{
        if (![_testResult lastConnectivity]) {
            _startInterfaceInfo = [connectivity getInterfaceInfo];
        }
        if (_phase != RMBTTestRunnerPhaseNone) [_testResult addConnectivity:connectivity];
    });

    dispatch_async(dispatch_get_main_queue(), ^{
        [_delegate testRunnerDidDetectConnectivity:connectivity];
    });
}

- (void)connectivityTracker:(RMBTConnectivityTracker *)tracker didStopAndDetectIncompatibleConnectivity:(RMBTConnectivity *)connectivity {
    dispatch_async(dispatch_get_main_queue(), ^{
        [_delegate testRunnerDidDetectConnectivity:connectivity];
    });

    dispatch_async(_workerQueue, ^{
        if (_phase != RMBTTestRunnerPhaseNone) {
            [self cancelWithReason:RMBTTestRunnerCancelReasonMixedConnectivity];
        }
    });
}

#pragma mark - App state tracking

- (void)applicationDidSwitchToBackground:(NSNotification*)n {
    RMBTLog(@"App backgrounded, aborting %@",n);
    dispatch_async(_workerQueue, ^{
        [self cancelWithReason:RMBTTestRunnerCancelReasonAppBackgrounded];
    });
}

#pragma mark - Tracking location

- (void)locationsDidChange:(NSNotification*)notification {
    CLLocation *lastLocation = nil;
    for (CLLocation* l in notification.userInfo[@"locations"]) {
        if (CLLocationCoordinate2DIsValid(l.coordinate)) {
            lastLocation = l;
            [_testResult addLocation:l];

            RMBTLog(@"Location updated to (%f,%f,+/- %fm, %@)", l.coordinate.longitude, l.coordinate.latitude, l.horizontalAccuracy, l.timestamp);
        }
    }

    if (lastLocation) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [_delegate testRunnerDidDetectLocation:lastLocation];
        });
    }
}

#pragma mark - Cancelling and cleanup

- (void)finalize {
    // Stop observing
    [_connectivityTracker stop];
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    // Cancel timer
    if (_timer) {
        dispatch_source_cancel(_timer);
        _timer = nil;
    }
}

- (void)dealloc {
    [self finalize];
}

- (void)cancelWithReason:(RMBTTestRunnerCancelReason)reason {
    ASSERT_ON_WORKER_QUEUE();

    [self finalize];

    if (_workers) {
        for (RMBTTestWorker *w in _workers) {
            [w abort];
        }
    }

    switch(reason) {
        case RMBTTestRunnerCancelReasonUserRequested:
            [RMBTSettings sharedSettings].previousTestStatus = RMBTTestStatusAborted;
            break;
        case RMBTTestRunnerCancelReasonAppBackgrounded:
            [RMBTSettings sharedSettings].previousTestStatus = RMBTTestStatusErrorBackgrounded;
            break;
        case RMBTTestRunnerCancelReasonErrorFetchingTestingParams:
            [RMBTSettings sharedSettings].previousTestStatus = RMBTTestStatusErrorFetching;
            break;
        case RMBTTestRunnerCancelReasonErrorSubmittingTestResult:
            [RMBTSettings sharedSettings].previousTestStatus = RMBTTestStatusErrorSubmitting;
            break;
        default:
            [RMBTSettings sharedSettings].previousTestStatus = RMBTTestStatusError;
            break;
    }

    _phase = RMBTTestRunnerPhaseNone;
    _dead = YES;

    dispatch_async(dispatch_get_main_queue(), ^{
        [_delegate testRunnerDidCancelTestWithReason:reason];
    });
}

- (void)cancel {
    dispatch_async(_workerQueue, ^{
        [self cancelWithReason:RMBTTestRunnerCancelReasonUserRequested];
    });
}
@end