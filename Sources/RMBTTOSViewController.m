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

#import "RMBTTOSViewController.h"
#import "UIViewController+ModalBrowser.h"
#import "RMBTTOS.h"

@implementation RMBTTOSViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.acceptIntroLabel.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0,0,300.f,44.0f)];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.text = self.navigationItem.title;
    titleLabel.font = [UIFont boldSystemFontOfSize:16.0f];
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.adjustsFontSizeToFitWidth = YES;
    self.navigationItem.titleView = titleLabel;

    UIEdgeInsets i = self.webView.scrollView.scrollIndicatorInsets;
    i.bottom = 88.0; // 2x44px for toolbars
    self.webView.scrollView.scrollIndicatorInsets = i;

    i = self.webView.scrollView.contentInset;
    i.bottom = 88.0;
    self.webView.scrollView.contentInset = i;

    NSURL* url = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"terms_conditions_long" ofType:@"html"]];
    [self.webView loadRequest:[NSURLRequest requestWithURL:url]];
}

// Handle external links in a modal browser window
- (BOOL)webView:(UIWebView *)webView
shouldStartLoadWithRequest:(NSURLRequest *)request
 navigationType:(UIWebViewNavigationType)navigationType
{
    NSString *scheme = request.URL.scheme;
    if ([scheme isEqualToString:@"file"]) {
        return YES;
    } else if ([scheme isEqualToString:@"mailto"]) {
        // TODO: Open compose dialog
        return NO;
    } else {
        [self presentModalBrowserWithURLString:request.URL.absoluteString];
        return NO;
    }
}

- (IBAction)agree:(id)sender {
    [[RMBTTOS sharedTOS] acceptCurrentVersion];
    [self dismissViewControllerAnimated:YES completion:^{}];
}

@end
