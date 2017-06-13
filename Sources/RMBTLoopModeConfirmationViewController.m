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

#import "RMBTLoopModeConfirmationViewController.h"

@interface RMBTLoopModeConfirmationViewController () {
    BOOL _step2;
}
@end

@implementation RMBTLoopModeConfirmationViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self show];
}

- (void)show {
    self.navigationItem.prompt = [NSString stringWithFormat:NSLocalizedString(@"Loop mode %@/2", @"Confirmation dialog subtitle"), _step2 ? @2 : @1];
    self.navigationItem.title = NSLocalizedString(@"Activation and privacy", @"Confirmation dialog title 1/2");
    NSString *html = @"loop_mode_info";

    if (_step2) {
        self.navigationItem.title = NSLocalizedString(@"Usage", @"Confirmation dialog title 1/2");
        html = @"loop_mode_info2";
    }

    NSURL* url = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:html ofType:@"html"]];
    [self.webView loadRequest:[NSURLRequest requestWithURL:url]];
}

- (void)accept:(id)sender {
    if (!_step2) {
        _step2 = YES;
        [self show];
    } else {
        [self performSegueWithIdentifier:@"accept" sender:self];
    }
}

@end
