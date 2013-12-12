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

#import <QuartzCore/QuartzCore.h>

#import "RMBTTestViewController.h"
#import "RMBTTestRunner.h"
#import "RMBTSpeed.h"
#import "RMBTSettings.h"
#import "RMBTHistoryResultViewController.h"
#import "CLLocation+RMBTFormat.h"
#import "RMBTVerticalTransitionController.h"
#import "RMBTGaugeView.h"

typedef NS_ENUM(NSUInteger, RMBTTestViewFooter) {
    RMBTTestViewFooterStatus,
    RMBTTestViewFooterLocation,
    RMBTTestViewFooterLoop,
    RMBTTestViewFooterConnection,
    RMBTTestViewFooterPing,
    RMBTTestViewFooterUp,
    RMBTTestViewFooterDown,
    RMBTTestViewFooterTestServer
};

@interface RMBTTestViewController ()<RMBTTestRunnerDelegate, UIAlertViewDelegate, RMBTTestRunnerDelegate, UIViewControllerTransitioningDelegate> {
    RMBTTestRunner *_testRunner;

    UIAlertView *_alertView;
    
    NSUInteger _finishedPercentage;
    NSUInteger _loopCounter;
    BOOL       _loopMode;
    NSTimer   *_loopRestartTimer;

    // Views
    RMBTGaugeView *_progressGaugeView, *_speedGaugeView;
}
@end

@implementation RMBTTestViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    NSParameterAssert(self.progressGaugePlaceholderView);
    _progressGaugeView = [[RMBTGaugeView alloc] initWithFrame:self.progressGaugePlaceholderView.frame name:@"progress" startAngle:219.0f endAngle:219.0f + 261.0f ovalRect:CGRectMake(0.0,0,175.0, 175.0)];
    [self.progressGaugePlaceholderView removeFromSuperview];
    self.progressGaugePlaceholderView = nil; // release the placeholder view
    [self.view addSubview:_progressGaugeView];

    NSParameterAssert(self.speedGaugePlaceholderView);
    _speedGaugeView = [[RMBTGaugeView alloc] initWithFrame:self.speedGaugePlaceholderView.frame name:@"speed" startAngle:37.0f endAngle:37.0f + 262.0f ovalRect:CGRectMake(0,0,175.0, 175.0)];
    [self.speedGaugePlaceholderView removeFromSuperview];
    self.speedGaugePlaceholderView = nil; // release the placeholder view
    [self.view addSubview:_speedGaugeView];

    UITapGestureRecognizer *gestureRecognizer = [[UITapGestureRecognizer alloc] init];
    gestureRecognizer.numberOfTapsRequired = 1;
    gestureRecognizer.numberOfTouchesRequired = 1;
    [gestureRecognizer addTarget:self action:@selector(tapped)];
    [self.view addGestureRecognizer:gestureRecognizer];

    _loopMode = [RMBTSettings sharedSettings].debugUnlocked && [RMBTSettings sharedSettings].debugLoopMode;
    _loopCounter = 1;

    // Only clear connectivity and location labels once at start to avoid blinking during test restart
    self.networkNameLabel.text = @"";
    [self displayText:@"-" forFooter:RMBTTestViewFooterConnection];
    [self displayText:@"-" forFooter:RMBTTestViewFooterLocation];

    [self setupLayout];

    [self startTest];
}

- (void)setupLayout {
    NSMutableDictionary *m = [NSMutableDictionary dictionaryWithDictionary:@{@"s":@(10),@"v":@(6),@"ll":@(2)}];

    if (!RMBTIsRunningOnWideScreen()) {
        m[@"ll"] = @(0);
        m[@"v"] = @(4);
    }

    NSDictionary *labels = NSDictionaryOfVariableBindings(_speedGraphView,
                                                          _footerLoopLabel,
                                                          _footerLocationLabel,
                                                          _footerStatusLabel,
                                                          _footerTestServerLabel);
    for (UIView *l in [labels allValues]) {
        [l setTranslatesAutoresizingMaskIntoConstraints:NO];
        if (l != self.speedGraphView) {
            // left and right margin for labels
            [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-s-[l]-s-|" options:0 metrics:m views:NSDictionaryOfVariableBindings(l)]];
        } else {
            [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|[l]|" options:0 metrics:m views:NSDictionaryOfVariableBindings(l)]];
        }
    }

    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[_footerStatusLabel]-ll-[_footerTestServerLabel]-ll-[_footerLocationLabel]-ll-[_footerLoopLabel]-(v@20)-|" options:0 metrics:m views:labels]];

    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[_footerLocationLabel]-(v@10)-|" options:0 metrics:m views:labels]];

    NSLayoutConstraint *c = [NSLayoutConstraint constraintWithItem:self.speedGraphView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationGreaterThanOrEqual toItem:_speedGaugeView attribute:NSLayoutAttributeBottom multiplier:1.0 constant:-44.0];
    [self.view addConstraint:c];

    c = [NSLayoutConstraint constraintWithItem:self.speedGraphView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationGreaterThanOrEqual toItem:self.footerStatusLabel attribute:NSLayoutAttributeBottom multiplier:1.0 constant:RMBTIsRunningOnWideScreen() ? 24.0 : 26.0];
    [self.view addConstraint:c];

    if (!_loopMode) {
        [_footerLoopLabel removeFromSuperview];
    }

    if (!RMBTIsRunningOnWideScreen()) {
        // Hide test server label on 3.5"
        [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[_footerTestServerLabel(0)]" options:0 metrics:nil views:labels]];
    }
}


- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    // Allow turning off the screen again.
    // Note that enabling the idle timer won't reset it, so if the device has alredy been idle the screen will dim
    // immediately. To prevent this, we delay enabling by 5s.
    [[UIApplication sharedApplication] performBlock:^(id sender) {
        [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
    } afterDelay:5.0];
}

// Can be called multiple times if run in loop mode
- (void)startTest {
    NSAssert(_loopMode || _loopCounter == 1, @"Called test twice w/o being in loop mode");

    _finishedPercentage = 0;
    [self displayPercentage:0];

    [self displayText:@"-" forFooter:RMBTTestViewFooterPing];
    [self displayText:@"-" forFooter:RMBTTestViewFooterDown];
    [self displayText:@"-" forFooter:RMBTTestViewFooterUp];
    [self displayText:@"-" forFooter:RMBTTestViewFooterStatus];

    [self displayText:[NSString stringWithFormat:@"%u/%u", _loopCounter,RMBT_TEST_LOOPMODE_LIMIT] forFooter:RMBTTestViewFooterLoop];

    self.arrowImageView.image = nil;

    _speedGaugeView.value = 0.0;
    [self.speedGraphView clear];

    _testRunner = [[RMBTTestRunner alloc] initWithDelegate:self];
    [_testRunner start];
}

#pragma mark - Test runner delegate

- (void)testRunnerDidDetectConnectivity:(RMBTConnectivity *)connectivity {
    self.networkNameLabel.text = RMBTValueOrString(connectivity.networkName, @"n/a");
    [self displayText:RMBTValueOrString(connectivity.networkTypeDescription, @"n/a") forFooter:RMBTTestViewFooterConnection];

    if (connectivity.networkType == RMBTNetworkTypeCellular) {
        self.networkTypeImageView.image = [UIImage imageNamed:@"test_cellular"];
    } else if (connectivity.networkType == RMBTNetworkTypeWiFi) {
        self.networkTypeImageView.image = [UIImage imageNamed:@"test_wifi"];
    } else {
        self.networkTypeImageView.image = nil;
    }
}

- (void)testRunnerDidDetectLocation:(CLLocation *)location {
    // Show location in status
    [self displayText:[location rmbtFormattedString] forFooter:RMBTTestViewFooterLocation];
}

- (void)testRunnerDidStartPhase:(RMBTTestRunnerPhase)phase {
    if (phase == RMBTTestRunnerPhaseInit || phase == RMBTTestRunnerPhaseWait) {
        [self displayText:_testRunner.testParams.serverName forFooter:RMBTTestViewFooterTestServer];
//        self.footerTestServerLabel.text = _testRunner.testParams.serverName;
//        self.footerLocalIpLabel.text = _testRunner.testParams.clientRemoteIp;
    } else if (phase == RMBTTestRunnerPhaseDown) {
        self.arrowImageView.image = [UIImage imageNamed:@"test_arrow_down"];
    } else if (phase == RMBTTestRunnerPhaseUp) {
        [self.speedGraphView clear];
        self.arrowImageView.image = [UIImage imageNamed:@"test_arrow_up"];
    }
    [self displayText:[self statusStringForPhase:phase] forFooter:RMBTTestViewFooterStatus];
}

- (void)testRunnerDidFinishPhase:(RMBTTestRunnerPhase)phase {
    if (phase == RMBTTestRunnerPhaseLatency) {
        [self displayText:RMBTMillisecondsStringWithNanos(_testRunner.testResult.bestPingNanos) forFooter:RMBTTestViewFooterPing];
    } else if (phase == RMBTTestRunnerPhaseDown) {
        _speedGaugeView.value = 0;
        // Speed gauge set to 0, but leave the chart until we have measurements for the upload
        // [self.speedGraphView clear];
        [self updateSpeedLabelForPhase:phase
                             withSpeed:_testRunner.testResult.totalDownloadHistory.totalThroughput.kilobitsPerSecond
                               isFinal:YES];
    } else if (phase == RMBTTestRunnerPhaseUp) {
        [self updateSpeedLabelForPhase:phase
                             withSpeed:_testRunner.testResult.totalUploadHistory.totalThroughput.kilobitsPerSecond
                               isFinal:YES];
    }
    
    _finishedPercentage = [self percentageAfterPhase:phase];
    [self displayPercentage:_finishedPercentage];
    
    NSAssert(_finishedPercentage <= 100, @"Invalid percentage");
}

- (void)testRunnerDidUpdateProgress:(float)progress inPhase:(RMBTTestRunnerPhase)phase {
    NSUInteger totalPercentage = _finishedPercentage + [self percentageForPhase:phase] * progress;
    NSAssert(totalPercentage <= 100, @"Invalid percentage");

    [self displayPercentage:totalPercentage];
}

//- (void)testRunnerDidCalculateSpeed:(uint32_t)kbps
//                     atTimeInterval:(NSTimeInterval)interval
//                            inPhase:(RMBTTestRunnerPhase)phase
//{
//    NSAssert(phase == RMBTTestRunnerPhaseDown || phase == RMBTTestRunnerPhaseUp, @"Speed calculated outside dl/ul phase");
//    
//    double l = RMBTSpeedLogValue(kbps);
//    self.testBoxView.speedGaugeView.value = l;
//    [self.speedGraphView addValue:l atTimeInterval:interval];
//
//    [self updateSpeedLabelForPhase:phase withSpeed:kbps isFinal:NO];
//}

- (void)testRunnerDidMeasureThroughputs:(NSArray *)throughputs inPhase:(RMBTTestRunnerPhase)phase {
    uint32_t kbps = 0;
    double l;

    for (RMBTThroughput* t in throughputs) {
        kbps = t.kilobitsPerSecond;
        l = RMBTSpeedLogValue(kbps);
        [self.speedGraphView addValue:l atTimeInterval:(double)t.endNanos/NSEC_PER_SEC];
    }

    if (throughputs.count > 0) {
        // Use last values for momentary display (gauge and label)
        _speedGaugeView.value = l;
        [self updateSpeedLabelForPhase:phase withSpeed:kbps isFinal:NO];
    }
}


- (void)testRunnerDidCompleteWithResult:(RMBTHistoryResult *)result {
    [self hideAlert];

    if (_loopMode) {
        [self startNextLoop];
    } else {
        _result = result;
        [self performSegueWithIdentifier:@"finish" sender:self];
    }
}

- (void)testRunnerDidCancelTestWithReason:(RMBTTestRunnerCancelReason)cancelReason {
    switch(cancelReason) {
        case RMBTTestRunnerCancelReasonUserRequested: {
            [self dismissViewControllerAnimated:YES completion:^{}];
            break;
        }
        case RMBTTestRunnerCancelReasonMixedConnectivity: {
            RMBTLog(@"Test cancelled because of mixed connectivity");
            [self startTest];
            break;
        }
        case RMBTTestRunnerCancelReasonNoConnection:
        case RMBTTestRunnerCancelReasonErrorFetchingTestingParams:
            if (_loopMode) {
                [self restartTestAfterCountdown:RMBT_TEST_LOOPMODE_WAIT_BETWEEN_RETRIES_S];
            } else {
                NSString * message;
                if (cancelReason == RMBTTestRunnerCancelReasonNoConnection) {
                    RMBTLog(@"Test cancelled because of connection error");
                    message = NSLocalizedString(@"The connection to the test server was lost. Test aborted.", @"Alert view message");
                } else {
                    RMBTLog(@"Test cancelled failing to fetch test params");
                    message = NSLocalizedString(@"Couldn't connect to test server.", @"Alert view message");
                }

                [self displayAlertWithTitle:NSLocalizedString(@"Connection Error", @"Alert view title")
                                    message:message
                          cancelButtonTitle:NSLocalizedString(@"Cancel", @"Alert view button")
                           otherButtonTitle:NSLocalizedString(@"Try Again", @"Alert view button")
                              cancelHandler:^{ [self dismissViewControllerAnimated:YES completion:^{}]; }
                               otherHandler:^{ [self startTest]; }];
            }
            break;
        case RMBTTestRunnerCancelReasonErrorSubmittingTestResult: {
            if (_loopMode) {
                [self restartTestAfterCountdown:RMBT_TEST_LOOPMODE_WAIT_BETWEEN_RETRIES_S];
            } else {
                RMBTLog(@"Test cancelled failing to submit test results");
                [self displayAlertWithTitle:NSLocalizedString(@"Error", @"Alert view title")
                                    message:NSLocalizedString(@"Test was completed, but the results couldn't be submitted to the test server.", @"Alert view message")
                          cancelButtonTitle:NSLocalizedString(@"Dismiss", @"Alert view button")
                           otherButtonTitle:nil
                              cancelHandler:^{ [self dismissViewControllerAnimated:YES completion:^{}]; }
                               otherHandler:nil];
            }
            break;
        }
        case RMBTTestRunnerCancelReasonAppBackgrounded: {
            RMBTLog(@"Test cancelled because app backgrounded");
            [self displayAlertWithTitle:NSLocalizedString(@"Test aborted", @"Alert view title")
                                message:NSLocalizedString(@"Test was aborted because the app went into background. Tests can only be performed while the app is running in foreground.", @"Alert view message")
                      cancelButtonTitle:NSLocalizedString(@"Close", @"Alert view button")
                       otherButtonTitle:NSLocalizedString(@"Repeat Test", @"Alert view button")
                          cancelHandler:^{ [self dismissViewControllerAnimated:YES completion:^{}]; }
                           otherHandler:^{
                               [self startTest];
                           }];
            break;
        }
    }

    [self displayText:NSLocalizedString(@"Aborted", @"Footer status label") forFooter:RMBTTestViewFooterStatus];
}

#pragma mark - UI

- (void)updateSpeedLabelForPhase:(RMBTTestRunnerPhase)phase withSpeed:(uint32_t)kbps isFinal:(BOOL)final {
    RMBTTestViewFooter f = (phase == RMBTTestRunnerPhaseDown) ? RMBTTestViewFooterDown : RMBTTestViewFooterUp;
    [self displayText:RMBTSpeedMbpsString(kbps) forFooter:f];
//    NSAssert(kbps > 0, @"Speed zero?");
//
//    UILabel *label = (phase == RMBTTestRunnerPhaseDown) ? self.downResultLabel : self.upResultLabel;
//    
//    if (final) {
//        // Perform a bump animation of the label to indicate that this is the final,
//        // calculated speed value
//        NSString *mbpsString = RMBTSpeedMbpsString(kbps);
//
//        [UIView animateWithDuration:0.10f animations:^{
//            label.alpha = 0.0f;
//        } completion:^(BOOL finished) {
//            label.text = mbpsString;
//            label.layer.shouldRasterize = YES;
//            label.layer.rasterizationScale = 2.0f;
//            [UIView animateWithDuration:0.25f delay:0.0f options:0 animations:^{
//                label.alpha = 1.0f;
//                label.transform = CGAffineTransformScale(label.transform, 1.1f, 1.1f);
//            } completion:^(BOOL finished){
//                [UIView animateWithDuration:0.10f animations:^{
//                    label.transform = CGAffineTransformIdentity;
//                    label.layer.shouldRasterize = NO;
//                } completion:nil];
//            }];
//        }];
//    } else {
//        label.text = RMBTSpeedMbpsString(kbps);
//    }
}

- (NSUInteger)percentageAfterPhase:(RMBTTestRunnerPhase)phase {
    switch (phase) {
        case RMBTTestRunnerPhaseNone:
            return 0;
        case RMBTTestRunnerPhaseFetchingTestParams:
        case RMBTTestRunnerPhaseWait:
            return 4;
        case RMBTTestRunnerPhaseInit:
            return 18;
        case RMBTTestRunnerPhaseLatency:
            return 38;
        case RMBTTestRunnerPhaseDown:
            return 70;
        case RMBTTestRunnerPhaseInitUp:
            return 70; // no visualization for init up
        case RMBTTestRunnerPhaseUp:
            return 100;
        case RMBTTestRunnerPhaseSubmittingTestResult:
            return 100; // also no visualization for submission
    }
}

- (NSUInteger)percentageForPhase:(RMBTTestRunnerPhase)phase {
    switch (phase) {
        case RMBTTestRunnerPhaseInit:    return 14;
        case RMBTTestRunnerPhaseLatency: return 19;
        case RMBTTestRunnerPhaseDown:    return 31;
        case RMBTTestRunnerPhaseUp:      return 30;
        default: return 0;
    }
}

- (NSString*)statusStringForPhase:(RMBTTestRunnerPhase)phase {
    switch(phase) {
        case RMBTTestRunnerPhaseNone:
        case RMBTTestRunnerPhaseFetchingTestParams:
            return NSLocalizedString(@"Fetching test parameters", @"Phase status label");
        case RMBTTestRunnerPhaseWait:
            return NSLocalizedString(@"Waiting for test server", @"Phase status label");
        case RMBTTestRunnerPhaseInit:
            return NSLocalizedString(@"Initializing", @"Phase status label");
        case RMBTTestRunnerPhaseLatency:
            return NSLocalizedString(@"Pinging", @"Phase status label");
        case RMBTTestRunnerPhaseDown:
            return NSLocalizedString(@"Download", @"Phase status label");
        case RMBTTestRunnerPhaseInitUp:
            return NSLocalizedString(@"Initializing Upload", @"Phase status label");
        case RMBTTestRunnerPhaseUp:
            return NSLocalizedString(@"Upload", @"Phase status label");
        case RMBTTestRunnerPhaseSubmittingTestResult:
            return NSLocalizedString(@"Finalizing", @"Phase status label");
    }
}

- (void)displayPercentage:(NSUInteger)percentage {
    self.progressLabel.text = [NSString stringWithFormat:@"%d%%", percentage];
    _progressGaugeView.value = percentage/100.0f;
}

#pragma mark - Alert views

- (void)tapped {
    [self displayAlertWithTitle:RMBTAppTitle()
                        message:NSLocalizedString(@"Do you really want to abort the running test?", @"Abort test alert title")
              cancelButtonTitle:NSLocalizedString(@"Abort Test", @"Abort test alert button")
               otherButtonTitle:NSLocalizedString(@"Continue", @"Abort test alert button")
                  cancelHandler:^{
                      [[RMBTControlServer sharedControlServer] cancelAllRequests];
                      [_testRunner cancel];
                  } otherHandler:^{}];
}

- (void)displayAlertWithTitle:(NSString*)title
                      message:(NSString*)message
            cancelButtonTitle:(NSString*)cancelButtonTitle
             otherButtonTitle:(NSString*)otherButtonTitle
                cancelHandler:(RMBTBlock)cancelHandler
                 otherHandler:(RMBTBlock)otherHandler
{
    if (_alertView) [_alertView dismissWithClickedButtonIndex:-1 animated:NO];
    _alertView = [UIAlertView alertViewWithTitle:title message:message];
    if (cancelButtonTitle) [_alertView setCancelButtonWithTitle:cancelButtonTitle handler:cancelHandler];
    if (otherButtonTitle) [_alertView addButtonWithTitle:otherButtonTitle handler:otherHandler];
    [_alertView show];
}

- (void)hideAlert {
    if (_alertView) {
        [_alertView dismissWithClickedButtonIndex:-1 animated:YES];
        _alertView = nil;
    }
}

#pragma mark Restart test timer

- (void)startNextLoop {
    _loopCounter++;
    if (_loopCounter <= RMBT_TEST_LOOPMODE_LIMIT) {
        // Restart test
        RMBTLog(@"Loop mode active, starting new test (%d/%d)", _loopCounter, RMBT_TEST_LOOPMODE_LIMIT);
        [self startTest];
    } else {
        RMBTLog(@"Loop mode limit reached, stopping");
        [self dismissViewControllerAnimated:YES completion:^{}];
    }
}

- (void)restartTestAfterCountdown:(NSTimeInterval)interval {
    __block NSTimeInterval elapsed = 0;
    _loopRestartTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 block:^(NSTimer *timer) {
        elapsed += timer.timeInterval;
        if (elapsed > interval) {
            [timer invalidate];
            [self startNextLoop];
        } else {
            [self displayText:[NSString stringWithFormat:@"Restarting test in %d seconds", (NSUInteger)(interval-elapsed)] forFooter:RMBTTestViewFooterStatus];
        }
    } repeats:YES];
}

- (id <UIViewControllerAnimatedTransitioning>)animationControllerForPresentedController:(UIViewController *)presented presentingController:(UIViewController *)presenting sourceController:(UIViewController *)source
{
    return [[RMBTVerticalTransitionController alloc] init];
}

- (id <UIViewControllerAnimatedTransitioning>)animationControllerForDismissedController:(UIViewController *)dismissed {
    RMBTVerticalTransitionController *v = [[RMBTVerticalTransitionController alloc] init];
    v.reverse = YES;
    return v;
}

#pragma mark - Footer

- (void)displayText:(NSString*)text forFooter:(RMBTTestViewFooter)footer {
    UILabel *label = nil;
    NSString *title = nil;
    switch (footer) {
        case RMBTTestViewFooterLocation:
            label = self.footerLocationLabel;
            title = @"Location";
            break;
        case RMBTTestViewFooterStatus:
            label = self.footerStatusLabel;
            title = @"Status";
            break;
        case RMBTTestViewFooterLoop:
            label = self.footerLoopLabel;
            title = @"Loop";
            break;
        case RMBTTestViewFooterConnection: {
            static NSString *localizedTitle;
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^{
                localizedTitle = NSLocalizedString(@"Connection", @"Test view label");
            });
            title = localizedTitle;
            label = self.networkTypeLabel;
            break;
        }
        case RMBTTestViewFooterPing:
            title = @"Ping";
            label = self.pingResultLabel;
            break;
        case RMBTTestViewFooterUp:
            title = @"Upload";
            label = self.upResultLabel;
            break;
        case RMBTTestViewFooterDown:
            title = @"Download";
            label = self.downResultLabel;
            break;
        case RMBTTestViewFooterTestServer:
            title = @"Server";
            label = self.footerTestServerLabel;
            break;
    }

    NSParameterAssert(label);
    NSParameterAssert(title);

    label.text = [NSString stringWithFormat:@"%@: %@", title, text];
}

@end

