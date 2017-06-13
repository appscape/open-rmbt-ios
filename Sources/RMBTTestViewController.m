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
#import "RMBTSpeed.h"
#import "RMBTSettings.h"
#import "RMBTHistoryResultViewController.h"
#import "CLLocation+RMBTFormat.h"
#import "RMBTVerticalTransitionController.h"
#import "RMBTGaugeView.h"
#import "RMBTQoSProgressViewController.h"

#define RMBT_LIGHT_TEXT_DARK ([UIColor rmbt_colorWithRGBHex:0x3d454c])
#define RMBT_LIGHT_TEXT_LIGHT ([UIColor rmbt_colorWithRGBHex:0x9da2a6])

@interface RMBTTestViewController ()<UIAlertViewDelegate, UIViewControllerTransitioningDelegate, RMBTBaseTestViewControllerSubclass> {
    UIAlertView *_alertView;
    
    // Views
    RMBTGaugeView *_progressGaugeView, *_speedGaugeView;

    NSDictionary *_footerLabelTitleAttributes, *_footerLabelDetailsAttributes;

    RMBTQoSProgressViewController* _qosProgressViewController;
}
@end

@implementation RMBTTestViewController

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:YES];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent animated:YES];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    if (self.roaming) {
        self.networkNameLabel.hidden = YES;
    }

    self.speedSuffixLabel.text = RMBTSpeedMbpsSuffix();

    UITapGestureRecognizer *gestureRecognizer = [[UITapGestureRecognizer alloc] init];
    gestureRecognizer.numberOfTapsRequired = 1;
    gestureRecognizer.numberOfTouchesRequired = 1;
    [gestureRecognizer addTarget:self action:@selector(tapped)];
    [self.view addGestureRecognizer:gestureRecognizer];

    // Only clear connectivity and location labels once at start to avoid blinking during test restart
    self.networkNameLabel.text = @"";
    [self displayText:@"-" forLabel:self.networkTypeLabel];
    [self displayText:@"-" forLabel:self.footerLocationLabel];

    [self adaptLayout];

    [self.view layoutSubviews];

    // Replace placeholder with speed gauges:
    NSParameterAssert(self.progressGaugePlaceholderView);
    _progressGaugeView = [[RMBTGaugeView alloc] initWithFrame:self.progressGaugePlaceholderView.frame name:@"progress" startAngle:219.0f endAngle:219.0f + 261.0f ovalRect:CGRectMake(0.0,0,175.0, 175.0)];
    [self.view addSubview:_progressGaugeView];

    NSParameterAssert(self.speedGaugePlaceholderView);
    _speedGaugeView = [[RMBTGaugeView alloc] initWithFrame:self.speedGaugePlaceholderView.frame name:@"speed" startAngle:33.5f endAngle:299.0f ovalRect:CGRectMake(0,0,175.0, 175.0)];
    [self.view addSubview:_speedGaugeView];

    self.progressGaugePlaceholderView.hidden = YES;
    self.speedGaugePlaceholderView.hidden = YES;

    [self startTest];
}

// Tweaks layout for various iPhones
- (void)adaptLayout {
    switch (RMBTGetFormFactor()) {
        case RMBTFormFactoriPhone4:
            // Hide server label on iPhone 4 as there's not enough space:
            [self.footerTestServerLabel removeFromSuperview];
            self.speedGraphBottomConstraint.constant = -10.0f;
            self.progressGaugeTopConstraint.constant = 20.0f;
            break;
        case RMBTFormFactoriPhone5:
            self.networkNameWidthConstraint.constant = 132.0f;
            break;
        case RMBTFormFactoriPhone6:
            self.networkNameWidthConstraint.constant = 280.0f;
            self.networkSymbolLeftConstraint.constant = 30.0f;
            self.networkSymbolTopConstraint.constant = 60.0f;
            self.progressGaugeTopConstraint.constant = 84.0f;
            self.footerBottomConstraint.constant = 15.0f;
            self.speedGraphBottomConstraint.constant = 10.0f;
            break;
        case RMBTFormFactoriPhone6Plus:
            self.networkNameWidthConstraint.constant = 300.0f;
            self.networkSymbolLeftConstraint.constant = 40.0f;
            self.networkSymbolTopConstraint.constant = 70.0f;
            self.progressGaugeTopConstraint.constant = 94.0f;
            self.speedGraphBottomConstraint.constant = 20.0f;
            self.footerBottomConstraint.constant = 20.0f;
            break;
    }
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    _progressGaugeView.frame = self.progressGaugePlaceholderView.frame;
    _speedGaugeView.frame = self.speedGaugePlaceholderView.frame;
}

- (void)startTest {
    [self showQoSUI:NO]; // in case we're restarting because test was cancelled in qos phase

    [self displayText:@"-" forLabel:self.pingResultLabel];
    [self displayText:@"-" forLabel:self.downResultLabel];
    [self displayText:@"-" forLabel:self.upResultLabel];

    self.arrowImageView.image = nil;

    _speedGaugeView.value = 0.0;
    self.speedLabel.text = @"";
    self.speedSuffixLabel.hidden = YES;
    [self.speedGraphView clear];

    [super startTestWithExtraParams:nil];
}

- (void)showQoSUI:(BOOL)state {
    self.speedGraphView.hidden = state;
    _speedGaugeView.hidden = state;
    self.speedLabel.hidden = state;
    self.speedSuffixLabel.hidden = state;
    self.arrowImageView.hidden = state;
    self.qosProgressView.hidden = !state;
}

#pragma mark - Subclass

- (void)onTestUpdatedConnectivity:(RMBTConnectivity *)connectivity {
    self.networkNameLabel.text = RMBTValueOrString(connectivity.networkName, @"n/a");
    [self displayText:RMBTValueOrString(connectivity.networkTypeDescription, @"n/a") forLabel:self.networkTypeLabel];

    if (connectivity.networkType == RMBTNetworkTypeCellular) {
        self.networkTypeImageView.image = [UIImage imageNamed:@"test_cellular"];
    } else if (connectivity.networkType == RMBTNetworkTypeWiFi) {
        NSParameterAssert(!self.roaming);
        self.networkTypeImageView.image = [UIImage imageNamed:@"test_wifi"];
    } else {
        self.networkTypeImageView.image = nil;
    }
}

- (void)onTestUpdatedLocation:(CLLocation *)location {
    [self displayText:[location rmbtFormattedString] forLabel:self.footerLocationLabel];
}

- (void)onTestUpdatedServerName:(NSString *)name {
   [self displayText:name forLabel:self.footerTestServerLabel];
}

- (void)onTestUpdatedStatus:(NSString *)status {
    [self displayText:status forLabel:self.footerStatusLabel];
}

- (void)onTestUpdatedTotalProgress:(NSUInteger)percentage {
    self.progressLabel.text = [NSString stringWithFormat:@"%lu%%", (unsigned long)percentage];
    _progressGaugeView.value = percentage/100.0f;
}

- (void)onTestStartedPhase:(RMBTTestRunnerPhase)phase {
    if (phase == RMBTTestRunnerPhaseDown) {
        self.arrowImageView.image = [UIImage imageNamed:@"test_arrow_down"];
    } else if (phase == RMBTTestRunnerPhaseUp) {
        [self.speedGraphView clear];
        self.speedLabel.text = @"";
        self.speedSuffixLabel.hidden = YES;
        self.arrowImageView.image = [UIImage imageNamed:@"test_arrow_up"];
    } else if (phase == RMBTTestRunnerPhaseQoS) {
        NSParameterAssert(_qosProgressViewController);
    }
}

- (void)onTestFinishedPhase:(RMBTTestRunnerPhase)phase {
}

- (void)onTestMeasuredLatency:(uint64_t)nanos {
    [self displayText:RMBTMillisecondsStringWithNanos(nanos) forLabel:self.pingResultLabel final:YES];
}

- (void)onTestMeasuredDownloadSpeed:(uint32_t)kbps {
    _speedGaugeView.value = 0;
    // Speed gauge set to 0, but leave the chart until we have measurements for the upload
    // [self.speedGraphView clear];
    [self updateSpeedLabelForPhase:RMBTTestRunnerPhaseDown withSpeed:kbps isFinal:YES];

}

- (void)onTestMeasuredUploadSpeed:(uint32_t)kbps {
    [self updateSpeedLabelForPhase:RMBTTestRunnerPhaseUp withSpeed:kbps isFinal:YES];
}

- (void)onTestMeasuredTroughputs:(NSArray *)throughputs inPhase:(RMBTTestRunnerPhase)phase {
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

- (void)onTestCompletedWithResult:(RMBTHistoryResult *)result qos:(BOOL)qos {
    [self hideAlert];
    [self.delegate testViewController:self didFinishWithTestResult:result];
}

- (void)onTestCancelledWithReason:(RMBTTestRunnerCancelReason)reason {
    switch(reason) {
        case RMBTTestRunnerCancelReasonUserRequested: {
            [self dismissViewControllerAnimated:YES completion:^{}];
            break;
        }
        case RMBTTestRunnerCancelReasonMixedConnectivity: {
            RMBTLog(@"Test cancelled because of mixed connectivity");
            [self startTestWithExtraParams:nil];
            break;
        }
        case RMBTTestRunnerCancelReasonNoConnection:
        case RMBTTestRunnerCancelReasonErrorFetchingTestingParams: {
            NSString * message;
            if (reason == RMBTTestRunnerCancelReasonNoConnection) {
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

            break;
        }
        case RMBTTestRunnerCancelReasonErrorSubmittingTestResult: {
            RMBTLog(@"Test cancelled failing to submit test results");
            [self displayAlertWithTitle:NSLocalizedString(@"Error", @"Alert view title")
                                message:NSLocalizedString(@"Test was completed, but the results couldn't be submitted to the test server.", @"Alert view message")
                      cancelButtonTitle:NSLocalizedString(@"Dismiss", @"Alert view button")
                       otherButtonTitle:nil
                          cancelHandler:^{ [self dismissViewControllerAnimated:YES completion:^{}]; }
                           otherHandler:nil];
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
}

- (void)onTestStartedQoSWithGroups:(NSArray *)groups {
    NSParameterAssert(_qosProgressViewController);
    _qosProgressViewController.testGroups = groups;
    [self showQoSUI:YES];
}

- (void)onTestUpdatedProgress:(float)progress inQoSGroup:(RMBTQoSTestGroup *)group {
    [_qosProgressViewController updateProgress:progress forGroup:group];
}

#pragma mark - UI

- (void)updateSpeedLabelForPhase:(RMBTTestRunnerPhase)phase withSpeed:(uint32_t)kbps isFinal:(BOOL)final {
    self.speedSuffixLabel.hidden = NO;
    UILabel *l = (phase == RMBTTestRunnerPhaseDown) ? self.downResultLabel : self.upResultLabel;
    [self displayText:RMBTSpeedMbpsString(kbps) forLabel:l final:final];
    self.speedLabel.text = RMBTSpeedMbpsStringWithSuffix(kbps, NO);

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


#pragma mark - Alert views

- (void)tapped {
    [self displayAlertWithTitle:RMBTAppTitle()
                        message:NSLocalizedString(@"Do you really want to abort the running test?", @"Abort test alert title")
              cancelButtonTitle:NSLocalizedString(@"Abort Test", @"Abort test alert button")
               otherButtonTitle:NSLocalizedString(@"Continue", @"Abort test alert button")
                  cancelHandler:^{
                      [self cancelTest];
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
    _alertView = [UIAlertView bk_alertViewWithTitle:title message:message];
    if (cancelButtonTitle) [_alertView bk_setCancelButtonWithTitle:cancelButtonTitle handler:cancelHandler];
    if (otherButtonTitle) [_alertView bk_addButtonWithTitle:otherButtonTitle handler:otherHandler];
    [_alertView show];
}

- (void)hideAlert {
    if (_alertView) {
        [_alertView dismissWithClickedButtonIndex:-1 animated:YES];
        _alertView = nil;
    }
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

- (void)displayText:(NSString*)text forLabel:(UILabel*)label  {
    [self displayText:text forLabel:label final:NO];
}

- (void)displayText:(NSString*)text forLabel:(UILabel*)label final:(BOOL)final{
    NSString *title = nil;
    BOOL bottom = NO;

    if (label == self.footerLocationLabel) {
        bottom = YES;
        title = @"Location";
    } else if (label == self.footerStatusLabel) {
        bottom = YES;
        title = @"Status";
    } else if (label == self.networkTypeLabel) {
        static NSString *localizedTitle;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            localizedTitle = NSLocalizedString(@"Connection", @"Test view label");
        });
        title = localizedTitle;
    } else if (label == self.pingResultLabel) {
        title = @"Ping";
    } else if (label == self.upResultLabel) {
        title = @"Upload";
    } else if (label == self.downResultLabel) {
        title = @"Download";
    } else if (label == self.footerTestServerLabel) {
        bottom = YES;
        title = @"Server";
    } else {
        NSParameterAssert(NO);
    }

    NSParameterAssert(label);
    NSParameterAssert(title);

    if (final && label.hidden) {
        label.alpha = 0;
        label.hidden = NO;
        CGAffineTransform t = label.transform;
        label.transform = CGAffineTransformMakeTranslation(0, 10);
        [UIView animateWithDuration:0.4f delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            label.alpha = 1;
            label.transform = t;
        } completion:nil];
    }

    if (!_footerLabelTitleAttributes) {
        _footerLabelTitleAttributes = @{NSForegroundColorAttributeName: RMBT_LIGHT_TEXT_LIGHT, NSFontAttributeName : [UIFont fontWithName:@"HelveticaNeue-Medium" size:10.5]};
        _footerLabelDetailsAttributes = @{NSForegroundColorAttributeName: RMBT_LIGHT_TEXT_DARK, NSFontAttributeName : [UIFont fontWithName:@"HelveticaNeue" size:12.0]};
    };

    NSMutableAttributedString *line = [[NSMutableAttributedString alloc] init];

    NSAttributedString *attrTitle = [[NSAttributedString alloc] initWithString:[title uppercaseString] attributes:_footerLabelTitleAttributes];
    [line appendAttributedString:attrTitle];
    [line appendAttributedString:[[NSAttributedString alloc] initWithString:@" "]];
    NSAttributedString *attrText = [[NSAttributedString alloc] initWithString:text attributes:_footerLabelDetailsAttributes];
    [line appendAttributedString:attrText];

    label.attributedText = line;
}

#pragma mark - QoS segues

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender {
    if ([identifier isEqualToString:@"embed_qos_progress"] && [RMBTSettings sharedSettings].skipQoS) {
        return NO;
    }
    return YES;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString: @"embed_qos_progress"]) {
        _qosProgressViewController = (RMBTQoSProgressViewController *) [segue destinationViewController];
    }
}

@end

