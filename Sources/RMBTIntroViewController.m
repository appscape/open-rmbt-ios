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

#import "RMBTIntroViewController.h"
#import "RMBTConnectivityTracker.h"
#import "RMBTLocationTracker.h"
#import "RMBTTestViewController.h"
#import "RMBTHistoryIndexViewController.h"
#import "RMBTVerticalTransitionController.h"
#import "RMBTTOS.h"
#import "UIViewController+ModalBrowser.h"

static const CGFloat kRadiateAnimationStartRadius = 9.0;
static const CGFloat kRadiateAnimationStartOffsetWifi = 22.0f;
static const CGFloat kRadiateAnimationStartOffsetCellular = -28.0f;

@interface RMBTIntroViewController ()<RMBTConnectivityTrackerDelegate, UIViewControllerTransitioningDelegate> {
    RMBTConnectivityTracker *_connectivityTracker;
    RMBTHistoryResult *_result;
    id _radiateBlock;
    BOOL _visible;
}
@end

@implementation RMBTIntroViewController

- (void)awakeFromNib {
    [self.navigationController.tabBarItem setSelectedImage:[UIImage imageNamed:@"tab_test_selected"]];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.networkNameLabel.text = @"";
    self.networkTypeLabel.text = @"";
    self.networkTypeImageView.image = nil; // Clear placeholder image

    RMBTTOS *tos = [RMBTTOS sharedTOS];

    // If user hasn't agreed to new TOS version, show TOS modally
    if (!tos.isCurrentVersionAccepted) {
        RMBTLog(@"Current TOS version %d > last accepted version %d, showing dialog", tos.currentVersion, tos.lastAcceptedVersion);
        [self performSegueWithIdentifier:@"show_tos" sender:self];
    }

    [self.startTestButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.startTestButton setBackgroundImage:[self imageWithColor:RMBT_TINT_COLOR] forState:UIControlStateNormal];
    self.startTestButton.layer.masksToBounds = YES;
    self.startTestButton.layer.cornerRadius = 5.0f;

    if (!RMBTIsRunningOnWideScreen()) {
        self.startTestButton.frameY -= 14.0f;
    }

    if (RMBTIsRunningGermanLocale()) {
        self.logoImageView.image = [UIImage imageNamed:@"intro_logo_de"];
    }
}

- (UIImage *)imageWithColor:(UIColor *)color {
    CGRect rect = CGRectMake(0.0f, 0.0f, 1.0f, 1.0f);
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();

    CGContextSetFillColorWithColor(context, [color CGColor]);
    CGContextFillRect(context, rect);

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return image;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (!_connectivityTracker) {
        // First appearance
        _connectivityTracker = [[RMBTConnectivityTracker alloc] initWithDelegate:self stopOnMixed:NO];
        [_connectivityTracker start];
    }
    _visible = YES;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    _visible = NO;
}

#pragma mark - Segues and actions

- (IBAction)showHelp:(id)sender {
    [self presentModalBrowserWithURLString:RMBT_HELP_URL];
}

- (IBAction)unwindFromTest:(UIStoryboardSegue*)segue {
    RMBTTestViewController* testVC = segue.sourceViewController;
    NSParameterAssert(testVC.result);

    self.tabBarController.selectedIndex = 1; // TODO: avoid hardcoding tab index
    RMBTHistoryIndexViewController *historyVC = [((UINavigationController*)[self.tabBarController selectedViewController]).viewControllers firstObject];
    [historyVC displayTestResult:testVC.result];
}

// Before transitioning to test view controller, we want to wait for user to allow/deny location services first
- (IBAction)startTest:(id)sender {
    [[UIApplication sharedApplication] setIdleTimerDisabled:YES]; // Disallow turning off the screen

    [[RMBTLocationTracker sharedTracker] startAfterDeterminingAuthorizationStatus:^{
        RMBTTestViewController *testVC = [self.storyboard instantiateViewControllerWithIdentifier:@"test_vc"];
        testVC.transitioningDelegate = self;
        [self presentViewController:testVC animated:YES completion:^{

        }];
    }];
}


#pragma mark - RMBTConnectivityTracker Delegate

- (void)connectivityTrackerDidDetectNoConnectivity:(RMBTConnectivityTracker *)tracker {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (_radiateBlock) {
            [NSObject bk_cancelBlock:_radiateBlock];
            _radiateBlock = nil;
        }
        self.networkNameLabel.text = @"";
        self.networkTypeLabel.text = NSLocalizedString(@"No network connection available", @"Test intro screen title when there's no connectivity");
        self.networkTypeImageView.image = [UIImage imageNamed:@"intro_none"];
        self.startTestButton.hidden = YES;
    });
}

- (void)connectivityTracker:(RMBTConnectivityTracker *)tracker didDetectConnectivity:(RMBTConnectivity *)connectivity {
    dispatch_async(dispatch_get_main_queue(), ^{
        CGFloat radiateY = CGRectGetMidY(self.networkTypeImageView.frame);
        self.startTestButton.hidden = NO;
        self.networkNameLabel.text = connectivity.networkName;
        self.networkTypeLabel.text = connectivity.networkTypeDescription;
        if (connectivity.networkType == RMBTNetworkTypeWiFi) {
            self.networkTypeImageView.image = [UIImage imageNamed:@"intro_wifi"];
            radiateY += kRadiateAnimationStartOffsetWifi;
        } else if (connectivity.networkType == RMBTNetworkTypeCellular) {
            self.networkTypeImageView.image = [UIImage imageNamed:@"intro_cellular"];
            radiateY += kRadiateAnimationStartOffsetCellular;
        }

        if (_visible) {
            [self radiateFromPoint:CGPointMake(CGRectGetMidX(self.networkTypeImageView.frame),radiateY)];
        }
    });
}

#pragma mark - Animation delegate

- (id <UIViewControllerAnimatedTransitioning>)animationControllerForPresentedController:(UIViewController *)presented presentingController:(UIViewController *)presenting sourceController:(UIViewController *)source
{
    return [[RMBTVerticalTransitionController alloc] init];
}

- (id <UIViewControllerAnimatedTransitioning>)animationControllerForDismissedController:(UIViewController *)dismissed {
    RMBTVerticalTransitionController *v = [[RMBTVerticalTransitionController alloc] init];
    v.reverse = YES;
    return v;
}


#pragma mark - Circle animation

- (void)radiateFromPoint:(CGPoint)point {
    if (_radiateBlock) return;

    _radiateBlock = [self bk_performBlock:^(id sender) {
        [sender createWaveFromPoint:point last:NO];
        [sender createWaveFromPoint:point last:YES];
    } afterDelay:0.25]; // Wait half a second before starting animation
}

- (void)createWaveFromPoint:(CGPoint)point last:(BOOL)last {
    CGFloat radius = kRadiateAnimationStartRadius;

    CAShapeLayer *circle = [CAShapeLayer layer];
    circle.frame = CGRectMake(0, 0, 2.0 * radius, 2.0 * radius);
    circle.bounds = circle.frame;
    circle.anchorPoint = CGPointMake(0.5, 0.5);
    circle.opacity = 1.0;
    circle.path = [UIBezierPath bezierPathWithRoundedRect:circle.frame cornerRadius:radius].CGPath;
    circle.position = CGPointMake(point.x, point.y);
    circle.fillColor = nil;
    circle.strokeColor = [[UIColor colorWithWhite:0.8 alpha:1.0] CGColor];
    circle.lineWidth = 1.0;
    [self.view.layer insertSublayer:circle below:self.networkTypeImageView.layer];

    CABasicAnimation *scaleAnim = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    scaleAnim.fromValue= [NSNumber numberWithDouble:1.0];
    scaleAnim.toValue= [NSNumber numberWithDouble:20.0];
    scaleAnim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];

    CABasicAnimation *fadeAnim = [CABasicAnimation animationWithKeyPath:@"opacity"];
    fadeAnim.fromValue=[NSNumber numberWithDouble:1.0];
    fadeAnim.toValue=[NSNumber numberWithDouble:0.0];
    fadeAnim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];

    CAAnimationGroup *group = [CAAnimationGroup animation];
    group.duration = 0.85;
    if (last) {
        group.beginTime = CACurrentMediaTime()+0.25;
    }
    group.repeatCount = 1;
    group.autoreverses = NO;
    group.animations = @[scaleAnim, fadeAnim];
    group.delegate = self;
    [group setValue:@(last) forKey:@"animationLastCircle"];
    [group setValue:circle forKey:@"animationLayer"];
    [group setValue:@"groupRadiate" forKey:@"animationName"];
    
    [circle addAnimation:group forKey:@"groupRadiate"];
}

- (void)animationDidStop:(CAAnimation *)animation finished:(BOOL)finished {
    CALayer *layer = [animation valueForKey:@"animationLayer"];
    if (layer) {
        [layer removeFromSuperlayer];
    }

    if ([[animation valueForKey:@"animationLastCircle"] boolValue]) {
        _radiateBlock = NO;
    }
}

@end
