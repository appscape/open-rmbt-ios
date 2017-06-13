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

#import "RMBTLoopModeTestViewController.h"
#import "RMBTLoopMeasurementsViewController.h"
#import "RMBTLoopDetailsViewController.h"
#import "RMBTSpeed.h"
#import "RMBTLocationTracker.h"

@interface RMBTLoopModeTestViewController()<RMBTBaseTestViewControllerSubclass> {
    NSTimer *_countdownTimer;

    uint64_t _bytesOnPreviousConnectivity;
    RMBTConnectivity *_lastConnectivity;
    NSTimer *_interfaceInfoTimer;
    RMBTConnectivityInterfaceInfo _initialInterfaceInfo;

    BOOL _finished, _waiting, _movementReached;

    RMBTLoopMeasurementsViewController *_measurementsViewController;
    RMBTLoopDetailsViewController *_detailsViewController;

    RMBTLocationTracker *_locationTracker;
    CLLocation *_lastTestFirstGoodLocation;

    NSDate *_firstTestStartedAt;

    NSDate *_timingReferenceTestStartedAt;
    NSUInteger _timingReferenceTestNumber; // 1-based, 1=first test
}
@end

@implementation RMBTLoopModeTestViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.progressView.progress = 0;
    [self updateCount];
    [self updateLastTestStatus:nil];
    [self startTest];

    // Remove the gap between measurements and details on iPhone 4/5 and make rows have smaller font
    // size so all data fields fit nicely:
    if (RMBTGetFormFactor() < RMBTFormFactoriPhone6) {
        _detailsViewController.compact = YES;
        self.gapConstraint.constant = 5;
    }
}

- (IBAction)done:(id)sender {
    if (_finished) {
        [self close];
    } else {
        [self cancelTest];
    }
}

- (void)close {
    [self cleanup];
    [self dismissViewControllerAnimated:YES completion:^{}];
}

- (void)cleanup {
    [_interfaceInfoTimer invalidate];
    _interfaceInfoTimer = nil;

    [_countdownTimer invalidate];
    _countdownTimer = nil;

    [[NSNotificationCenter defaultCenter] removeObserver:self name:RMBTLocationTrackerNotification object:nil];
    [_locationTracker stop];
    _locationTracker = nil;
    _lastTestFirstGoodLocation = nil;
}

- (void)startTest {
    _waiting = NO;
    _movementReached = NO;
    [self cleanup];

    [self updateDistance:nil];

    [self.info increment];
    [self updateCount];

    if (!_firstTestStartedAt) {
        _firstTestStartedAt = [NSDate date];
    }

    if (!_timingReferenceTestStartedAt) {
        _timingReferenceTestStartedAt = [NSDate date];
        _timingReferenceTestNumber = self.info.current;
    }

    if (!_countdownTimer) {
        __weak typeof(self) weakSelf = self;
        _countdownTimer = [NSTimer bk_scheduledTimerWithTimeInterval:1.0 block:^(NSTimer *timer) {
            typeof(self) strongSelf = weakSelf;
            if (!strongSelf) return;
            [strongSelf tick];
        } repeats:YES];
    }
    [_countdownTimer fire];
    [super startTestWithExtraParams:[self.info params]];
}

- (void)tick {
    if (_finished) {
        return;
    }

    NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:self->_timingReferenceTestStartedAt];
    NSTimeInterval nextTestAfter = (self.info.current - _timingReferenceTestNumber + 1) * self.info.waitMinutes * 60;

    if (_waiting) {
        if (_movementReached) {
            _timingReferenceTestStartedAt = nil; // take next test as new reference
            [self startTest];
            return;
        }
        NSCParameterAssert(_timingReferenceTestStartedAt);
        if (elapsed > nextTestAfter) {
            [self startTest];
            return;
        }
    }

    NSParameterAssert(_timingReferenceTestStartedAt);
    NSString* details = (elapsed > nextTestAfter) || _movementReached ?
        @"00:00"
        : RMBTMMSSStringWithInterval(nextTestAfter - elapsed);

    [self updateCountdown:details];
}

- (void)waitForNextTest {
    NSParameterAssert(self.info.current <= self.info.total);

    _waiting = YES;

    [self onTestUpdatedStatus:NSLocalizedString(@"Waiting", @"Loop Mode status")];

    if ([self.info isFinished] || ([[NSDate date] timeIntervalSinceDate:_firstTestStartedAt] >= RMBT_TEST_LOOPMODE_MAX_DURATION_S)) {
        // All loop tests were performed or the 48h have elapsed
        [self cleanup];
        [self onTestUpdatedStatus:@"Loop Mode Finished"];
        [self updateCountdown:nil];
        [self updateDistance:nil];
        [self.doneButton setTitle:@"Done"];
        _finished = YES;
        return;
    }

    // Start monitoring location changes
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(locationsDidChange:) name:RMBTLocationTrackerNotification object:nil];
    _locationTracker = [[RMBTLocationTracker alloc] init];
    [_locationTracker startIfAuthorized];
}

- (void)locationsDidChange:(NSNotification*)notification {
    CLLocation* l = [notification.userInfo[@"locations"] lastObject];

    if (!l || !CLLocationCoordinate2DIsValid(l.coordinate)) {
        NSParameterAssert(false);
        return;
    }

    if (!_lastTestFirstGoodLocation) {
        _lastTestFirstGoodLocation = l;
    }

    [self updateLocation:l];
}

- (void)updateLocation:(CLLocation*)location {
    //NSParameterAssert(_lastTestFirstGoodLocation);
    CLLocationDistance d = _lastTestFirstGoodLocation ? [location distanceFromLocation:_lastTestFirstGoodLocation] : 0;
    [_detailsViewController setDetails:[location rmbtFormattedString] forField:RMBTLoopDetailsFieldLocation];

    [self updateDistance:[NSString stringWithFormat:@"%.2f/%lu m", d, (unsigned long)self.info.waitMeters]];

    _movementReached = (d >= self.info.waitMeters);
}

- (void)updateDistance:(NSString*)distance {
    self.distanceLabel.text = distance ?: @"-";
}

- (void)updateCountdown:(NSString*)countdown {
    self.countdownLabel.text = countdown ?: @"-";
}

- (void)updateCount {
    self.navigationBar.topItem.title = [NSString stringWithFormat:@"%@ %lu/%lu", NSLocalizedString(@"Loop Mode", @"Screen title"), (unsigned long)_info.current, (unsigned long)_info.total];
}

- (void)updateLastTestStatus:(NSString*)status {
    self.lastTestStatusLabel.text = status ?: @"-";
    if (status) {
        CGFloat alpha = status ? 1.0 : 0.0;
        [UIView animateWithDuration:0.5f delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            self.lastTestStatusLabel.alpha = alpha;
            self.lastTestStatusHeaderLabel.alpha = alpha;
        } completion:nil];
    }
}

#pragma mark - Subclass

- (void)onTestUpdatedStatus:(NSString *)status {
    self.statusLabel.text = status;
}

- (void)onTestUpdatedTotalProgress:(NSUInteger)percentage {
    self.progressView.progress = percentage/100.0f;
}

- (void)onTestUpdatedConnectivity:(RMBTConnectivity*)connectivity {
    [_interfaceInfoTimer invalidate];

    if (_lastConnectivity && _lastConnectivity.networkType != connectivity.networkType) {
        // Connectivity changed, reset counters
        RMBTConnectivityInterfaceInfo lastInfo = [_lastConnectivity getInterfaceInfo];
        _bytesOnPreviousConnectivity += [RMBTConnectivity countTraffic:RMBTConnectivityInterfaceInfoTrafficTotal between:_initialInterfaceInfo and:lastInfo];
        _initialInterfaceInfo = [connectivity getInterfaceInfo];
    }

    _lastConnectivity = connectivity;

    [_detailsViewController setDetails:[connectivity networkTypeDescription] forField:RMBTLoopDetailsFieldNetworkType];
    [_detailsViewController setDetails:[connectivity networkName] forField:RMBTLoopDetailsFieldNetworkName];

    if (_initialInterfaceInfo.bytesReceived == 0 && _initialInterfaceInfo.bytesSent == 0) {
        _initialInterfaceInfo = [connectivity getInterfaceInfo];
    }

    __weak typeof(self) weakSelf = self;

    _interfaceInfoTimer = [NSTimer bk_scheduledTimerWithTimeInterval:3.0 block:^(NSTimer *timer) {
        typeof(self) strongSelf = weakSelf;
        if (!strongSelf) return;
        uint64_t currentTraffic = [RMBTConnectivity countTraffic:RMBTConnectivityInterfaceInfoTrafficTotal between:strongSelf->_initialInterfaceInfo and:[connectivity getInterfaceInfo]];
        [strongSelf updateTraffic:strongSelf->_bytesOnPreviousConnectivity + currentTraffic];
    } repeats:YES];
    [_interfaceInfoTimer fire];
}

- (void)updateTraffic:(uint64_t)bytes {
    [_detailsViewController setDetails:RMBTMegabytesString(bytes) forField:RMBTLoopDetailsFieldTraffic];
}

- (void)onTestUpdatedLocation:(CLLocation*)location {
    if (location.horizontalAccuracy <= RMBT_TEST_LOOPMODE_MOVEMENT_MIN_ACCURACY_M) {
        if (!_lastTestFirstGoodLocation) { _lastTestFirstGoodLocation = location; }
    } else {
        RMBTLog(@"Not considering location %@ for movement, accuracy to low", location);
    }
    [self updateLocation:location];
}

- (void)onTestUpdatedServerName:(NSString*)name {
    [_detailsViewController setDetails:name forField:RMBTLoopDetailsFieldServer];
}

- (void)onTestStartedPhase:(RMBTTestRunnerPhase)phase {
    if (phase == RMBTTestRunnerPhaseInit) {
        [_measurementsViewController start];
    } else if (phase == RMBTTestRunnerPhaseLatency) {
        [_measurementsViewController setValue:nil forMeasurement:RMBTLoopMeasurementPing final:NO];
    }
}

- (void)onTestFinishedPhase:(RMBTTestRunnerPhase)phase { }

- (void)onTestMeasuredLatency:(uint64_t)nanos {
    [_measurementsViewController setValue:@(nanos) forMeasurement:RMBTLoopMeasurementPing final:YES];
}

- (void)onTestMeasuredTroughputs:(NSArray*)throughputs inPhase:(RMBTTestRunnerPhase)phase {
    if (!(phase == RMBTTestRunnerPhaseUp || phase == RMBTTestRunnerPhaseDown)) {
        NSParameterAssert(false);
        return;
    };

    RMBTThroughput* t = [throughputs lastObject];
    if (t) {
        [_measurementsViewController setValue:@(t.kilobitsPerSecond) forMeasurement:phase == RMBTTestRunnerPhaseUp ? RMBTLoopMeasurementUp : RMBTLoopMeasurementDown final:NO];
    }
}

- (void)onTestMeasuredDownloadSpeed:(uint32_t)kbps {
    [_measurementsViewController setValue:@(kbps) forMeasurement:RMBTLoopMeasurementDown final:YES];
}

- (void)onTestMeasuredUploadSpeed:(uint32_t)kbps {
    [_measurementsViewController setValue:@(kbps) forMeasurement:RMBTLoopMeasurementUp final:YES];
}

- (void)onTestStartedQoSWithGroups:(NSArray*)groups {
    [_measurementsViewController setValue:nil forMeasurement:RMBTLoopMeasurementQoS final:NO];
}

- (void)onTestUpdatedProgress:(float)progress inQoSGroup:(RMBTQoSTestGroup*)group { }

- (void)onTestCompletedWithResult:(RMBTHistoryResult*)result qos:(BOOL)qos {
    dispatch_group_t done = dispatch_group_create();

    if (qos) {
        dispatch_group_enter(done);
        [[RMBTControlServer sharedControlServer] getHistoryQoSResultWithUUID:result.uuid success:^(id response) {
            NSString *summary = [RMBTHistoryQoSGroupResult summarize:[RMBTHistoryQoSGroupResult resultsWithResponse:response] withPercentage:NO];
            [_measurementsViewController setValue:summary forMeasurement:RMBTLoopMeasurementQoS final:YES];
            dispatch_group_leave(done);
        } error:^(NSError *error, NSDictionary *info) {
            RMBTLog(@"Error fetching QoS test results: %@. Info: %@", error, info);
            dispatch_group_leave(done);
        }];
    }

    dispatch_group_notify(done, dispatch_get_main_queue(), ^{
        [_measurementsViewController finish];
        [self updateLastTestStatus:NSLocalizedString(@"OK", @"Loop mode last test status")];
        [self waitForNextTest];
    });
}

- (void)onTestCancelledWithReason:(RMBTTestRunnerCancelReason)reason {
    if (reason == RMBTTestRunnerCancelReasonUserRequested) {
        [self close];
    } else {
        self.progressView.progress = 0;
        [_measurementsViewController cancel];
        [self updateLastTestStatus:[NSString stringWithFormat:NSLocalizedString(@"Error", @"Loop mode last test status")]]; //, [self statusForCancelReason:reason]]];
        [self waitForNextTest];
    }
}

- (NSString*)statusForCancelReason:(RMBTTestRunnerCancelReason)reason {
    switch (reason) {
        case RMBTTestRunnerCancelReasonUserRequested:
            // Should not happen
        case RMBTTestRunnerCancelReasonNoConnection:
            return @"No connectivity";
        case RMBTTestRunnerCancelReasonMixedConnectivity:
            return @"Mixed connectivity";
        case RMBTTestRunnerCancelReasonErrorFetchingTestingParams:
            return @"Error fetching test configuration";
        case RMBTTestRunnerCancelReasonErrorSubmittingTestResult:
            return @"Error submitting test results";
        case RMBTTestRunnerCancelReasonAppBackgrounded:
            return @"App went into background";
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString: @"embed_measurements"]) {
        _measurementsViewController = (RMBTLoopMeasurementsViewController*) [segue destinationViewController];
    } else if ([segue.identifier isEqualToString: @"embed_details"]) {
        _detailsViewController = (RMBTLoopDetailsViewController*) [segue destinationViewController];
    } else {
        NSParameterAssert(false);
    }
}

@end
