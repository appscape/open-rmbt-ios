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

#import "RMBTInfoViewController.h"
#import "RMBTInfoTextViewController.h"

#import <GoogleMaps/GoogleMaps.h>
 #import <MessageUI/MFMailComposeViewController.h>

#import "RMBTSettings.h"
#import "UIViewController+ModalBrowser.h"
#import "UITableViewCell+RMBTHeight.h"

typedef NS_ENUM(NSUInteger, RMBTInfoViewControllerSection) {
    RMBTInfoViewControllerSectionLinks = 0,
    RMBTInfoViewControllerSectionClientInfo = 1,
    RMBTInfoViewControllerSectionDevInfo = 2,
};

@interface RMBTInfoViewController ()<MFMailComposeViewControllerDelegate, UITabBarControllerDelegate> {
    NSString* _uuid;
}

@end

@implementation RMBTInfoViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [self.navigationController.tabBarItem setSelectedImage:[UIImage imageNamed:@"tab_info_selected"]];

    self.buildDetailsLabel.lineBreakMode = NSLineBreakByCharWrapping;
    self.buildDetailsLabel.text = [NSString stringWithFormat:@"%@ %@\n(%@)",
                                   [[NSBundle mainBundle] infoDictionary]
                                    [@"CFBundleShortVersionString"],
                                   RMBTBuildInfoString(),
                                   RMBTBuildDateString()];

    self.uuidLabel.lineBreakMode = NSLineBreakByCharWrapping;
    self.uuidLabel.numberOfLines = 0;

    self.headerTitleLabel.text = RMBTAppTitle();
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    // Refresh test counter and uuid labels:
    self.testCounterLabel.text = [NSString stringWithFormat:@"%lu",(unsigned long)[RMBTSettings sharedSettings].testCounter];

    _uuid = [RMBTControlServer sharedControlServer].uuid;
    if (_uuid) {
        self.uuidLabel.text = [NSString stringWithFormat:@"U%@",_uuid];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    self.tabBarController.delegate = self;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    self.tabBarController.delegate = nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == RMBTInfoViewControllerSectionClientInfo && indexPath.row == 0) {
        // UUID
        return [self.uuidCell rmbtApproximateOptimalHeight];
    } else if (indexPath.section == RMBTInfoViewControllerSectionLinks && indexPath.row == 2) {
        // Privacy
        return [self.privacyCell rmbtApproximateOptimalHeight];
    } else if (indexPath.section == RMBTInfoViewControllerSectionClientInfo && indexPath.row == 2) {
        // Version
        return 62.0f;
    } else {
        return 44.0f;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == RMBTInfoViewControllerSectionLinks) {
        switch (indexPath.row) {
            case 0:
                [self presentModalBrowserWithURLString:RMBT_PROJECT_URL];
                break;
            case 1: {
                if ([MFMailComposeViewController canSendMail]) {
                    MFMailComposeViewController *mailVC = [[MFMailComposeViewController alloc] init];
                    [mailVC setToRecipients:@[RMBT_PROJECT_EMAIL]];
                    mailVC.mailComposeDelegate = self;
                    [self presentViewController:mailVC animated:YES completion:^{}];
                }
                break;
            }
            case 2:
                [self presentModalBrowserWithURLString:RMBT_PRIVACY_TOS_URL];
                break;
            default:
                NSAssert(false, @"Invalid row");
        }
    } else if (indexPath.section == RMBTInfoViewControllerSectionDevInfo) {
        switch (indexPath.row) {
            case 0:
                [self presentModalBrowserWithURLString:RMBT_DEVELOPER_URL];
                break;
            case 1:
                [self presentModalBrowserWithURLString:RMBT_REPO_URL];
                break;
        }
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}


- (void)mailComposeController:(MFMailComposeViewController*)controller
          didFinishWithResult:(MFMailComposeResult)result
                        error:(NSError*)error {
    [self dismissViewControllerAnimated:YES completion:^{}];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"show_google_maps_notice"]) {
        RMBTInfoTextViewController *textVC = segue.destinationViewController;
        textVC.text = [GMSServices openSourceLicenseInfo];
        textVC.title = NSLocalizedString(@"Legal Notice", @"Google Maps Legal Notice navigation title");
    }
}

#pragma mark - Tableview actions (copying UUID)

// Show "Copy" action for cell showing client UUID
- (BOOL)tableView:(UITableView *)tableView shouldShowMenuForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == RMBTInfoViewControllerSectionClientInfo && indexPath.row == 0 && _uuid) {
        return YES;
    } else {
        return NO;
    }
}

// As client UUID is the only cell we can perform action for, we allow "copy" here
- (BOOL)tableView:(UITableView *)tableView canPerformAction:(SEL)action forRowAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender {
    return (action == @selector(copy:));
}

// ..and we copy the UUID value to pastboard in case "copy" action is performed
- (void)tableView:(UITableView *)tableView performAction:(SEL)action forRowAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender {
    if (action == @selector(copy:)) {
        // Copy UUID to pasteboard
        [[UIPasteboard generalPasteboard] setString:_uuid];
    }
}

#pragma mark - Tab bar reloading

- (void)tabBarController:(UITabBarController *)tabBarController didSelectViewController:(UIViewController *)viewController {
    if (viewController == self.navigationController) {
        [self.tableView setContentOffset:CGPointMake(0,-64.0f) animated:YES];
    }
}

@end
