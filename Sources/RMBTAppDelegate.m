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

#import "RMBTAppDelegate.h"
#import "RMBTSettings.h"
#import "RMBTLocationTracker.h"
#import "RMBTTOS.h"
#import "RMBTNavigationBar.h"

@implementation RMBTAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [self applyAppearance];
    [self onStart:YES];

    return YES;
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
    if ([url.host isEqualToString:@"debug"] || [url.host isEqualToString:@"undebug"]) {
        BOOL unlock = [url.host isEqualToString:@"debug"];
        [RMBTSettings sharedSettings].debugUnlocked = unlock;
        NSString *stateString = unlock ? @"Unlocked" : @"Locked";

        [UIAlertView showAlertViewWithTitle:[NSString stringWithFormat:@"Debug Mode %@", stateString]
                                    message:@"The app will now quit to apply the new settings."
                          cancelButtonTitle:@"OK"
                          otherButtonTitles:nil
                                    handler:^(UIAlertView *alertView, NSInteger buttonIndex) {
                                        exit(0);
                                    }];
        return YES;
    } else {
        return NO;
    }
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    [[RMBTLocationTracker sharedTracker] stop];
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    [self onStart:NO];
}

// This method is called from both applicationWillEnterForeground and application:didFinishLaunchingWithOptions:
- (void)onStart:(BOOL)isLaunched {
    RMBTLog(@"App started");

    // If user has authorized location services, we should start tracking location now, so that when test starts,
    // we already have a more accurate location
    [[RMBTLocationTracker sharedTracker] startIfAuthorized];

    RMBTTOS *tos = [RMBTTOS sharedTOS];

    if (tos.isCurrentVersionAccepted) {
        [self checkNews];
    } else if (isLaunched) {
        // Re-check after TOS gets accepted, but don't re-add listener on every foreground
        [tos addObserverForKeyPath:@keypath(tos.lastAcceptedVersion) task:^(id sender) {
            RMBTLog(@"TOS accepted, checking news...");
            [self checkNews];
        }];
    }
}

- (void)checkNews {
    [[RMBTControlServer sharedControlServer] getNews:^(NSArray *news) {
        for (RMBTNews *n in news) {
            [UIAlertView showAlertViewWithTitle:n.title
                                        message:n.text
                              cancelButtonTitle:NSLocalizedString(@"Dismiss", @"News alert view button")
                              otherButtonTitles:nil
                                        handler:^(UIAlertView *alertView, NSInteger buttonIndex) {
            }];
        }
    }];
}

- (void)applyAppearance {
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];

    // Background color
    [[RMBTNavigationBar appearance] setBarTintColor:RMBT_DARK_COLOR];

    // Tint color
    [[RMBTNavigationBar appearance] setTintColor:RMBT_TINT_COLOR];
    [[UITabBar appearance] setTintColor:RMBT_TINT_COLOR];

    // Text color
    [[RMBTNavigationBar appearance] setTitleTextAttributes:@{NSForegroundColorAttributeName:[UIColor whiteColor]}];
}

@end