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

#import "RMBTStatsViewController.h"

@interface RMBTStatsWebViewController : SVWebViewController
@end

@implementation RMBTStatsWebViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.opaque = NO;
    self.view.backgroundColor = [UIColor whiteColor];
}

@end

static const NSTimeInterval kUnloadViewTimeout = 5.0;

@interface RMBTStatsViewController() {
    NSTimer *_idleTimer;
}
@end

@implementation RMBTStatsViewController

- (void)awakeFromNib {
    [self.tabBarItem setSelectedImage:[UIImage imageNamed:@"tab_stats_selected"]];
    [self setNavigationBarHidden:YES animated:NO];
}

- (void)viewWillAppear:(BOOL)animated {;
    [super viewWillAppear:animated];
    [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationNone];
    [_idleTimer invalidate];

    if (self.viewControllers.count == 0) {
        [self loadWebView];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationNone];

    _idleTimer = [NSTimer scheduledTimerWithTimeInterval:kUnloadViewTimeout target:self selector:@selector(unloadWebView) userInfo:nil repeats:NO];
}

- (void)unloadWebView {
    [self setViewControllers:@[] animated:NO];
}

- (void)loadWebView {
    NSURL *url = [RMBTControlServer sharedControlServer].statsURL;
    RMBTLog(@"Stats URL = %@", url);
    RMBTStatsWebViewController *webView = [[RMBTStatsWebViewController alloc] initWithURL:url];
    [self setViewControllers:@[webView] animated:NO];
}

@end
