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

#import "RMBTSettingsViewController.h"
#import "RMBTSettings.h"
#import "UIView+RMBTSubviews.h"

typedef NS_ENUM(NSInteger, RMBTSettingsSection) {
    RMBTSettingsSectionGeneral = 0,
    RMBTSettingsSectionLoop,
    RMBTSettingsSectionDebug,
    RMBTSettingsSectionDebugCustomControlServer,
    RMBTSettingsSectionDebugLogging
};

@implementation RMBTSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    RMBTSettings *settings = [RMBTSettings sharedSettings];

    [self bindSwitch:self.forceIPv4Switch
   toSettingsKeyPath:@keypath(settings, forceIPv4)
            onToggle:^(BOOL value) {
                if (value && settings.debugUnlocked && self.debugForceIPv6Switch.on) {
                    settings.debugForceIPv6 = NO;
                    [self.debugForceIPv6Switch setOn:NO animated:YES];
                }
            }];

    [self bindSwitch:self.skipQoSSwitch
   toSettingsKeyPath:@keypath(settings, skipQoS)
            onToggle:nil];

    [self bindSwitch:self.expertModeSwitch
   toSettingsKeyPath:@keypath(settings, expertMode)
            onToggle:^(BOOL value) {
        if (!value) {
            // expert mode off -> loop mode off
            [self.loopModeSwitch setOn:NO animated:NO];
            [self.loopModeSwitch sendActionsForControlEvents:UIControlEventValueChanged];
        }
        // reload (section will be hidden)
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:RMBTSettingsSectionLoop]
                      withRowAnimation:UITableViewRowAnimationAutomatic];
    }];

    [self bindSwitch:self.loopModeSwitch
   toSettingsKeyPath:@keypath(settings, loopMode)
            onToggle:^(BOOL value) {
                if (value) {
                    // forget value in case user terminates the app while in the modal dialog
                    settings.loopMode = NO;
                    [self performSegueWithIdentifier:@"show_loop_mode_confirmation" sender:self];
                } else {
                    [self refreshSection:RMBTSettingsSectionLoop];
                }
    }];

    [self bindTextField:self.loopModeWaitTextField
      toSettingsKeyPath:@keypath(settings, loopModeEveryMinutes)
                numeric:YES
                    min:settings.debugUnlocked ? 1 : RMBT_TEST_LOOPMODE_MIN_DELAY_MINS
                    max:RMBT_TEST_LOOPMODE_MAX_DELAY_MINS
    ];

    [self bindTextField:self.loopModeDistanceTextField
      toSettingsKeyPath:@keypath(settings, loopModeEveryMeters)
                numeric:YES
                    min:settings.debugUnlocked ? 1 : RMBT_TEST_LOOPMODE_MIN_MOVEMENT_M
                    max:RMBT_TEST_LOOPMODE_MAX_MOVEMENT_M
    ];

    [self bindSwitch:self.debugForceIPv6Switch
   toSettingsKeyPath:@keypath(settings, debugForceIPv6) onToggle:^(BOOL value) {
       if (value && self.forceIPv4Switch.on) {
           settings.forceIPv4 = NO;
           [self.forceIPv4Switch setOn:NO animated:YES];
       }
   }];

    [self bindSwitch:self.debugControlServerCustomizationEnabledSwitch
   toSettingsKeyPath:@keypath(settings, debugControlServerCustomizationEnabled)
            onToggle:^(BOOL value) {
                [self refreshSection:RMBTSettingsSectionDebugCustomControlServer];
    }];

    [self bindTextField:self.debugControlServerHostnameTextField
      toSettingsKeyPath:@keypath(settings, debugControlServerHostname)
                numeric:NO];

    [self bindTextField:self.debugControlServerPortTextField
      toSettingsKeyPath:@keypath(settings, debugControlServerPort)
                numeric:YES];

    [self bindSwitch:self.debugControlServerUseSSLSwitch
   toSettingsKeyPath:@keypath(settings, debugControlServerUseSSL)
            onToggle:nil];

    [self bindSwitch:self.debugLoggingEnabledSwitch
   toSettingsKeyPath:@keypath(settings, debugLoggingEnabled)
            onToggle:^(BOOL value) {
                [self refreshSection:RMBTSettingsSectionDebugLogging];
    }];

    [self bindTextField:self.debugLoggingHostnameTextField
      toSettingsKeyPath:@keypath(settings, debugLoggingHostname)
                numeric:NO];

    [self bindTextField:self.debugLoggingPortTextField
      toSettingsKeyPath:@keypath(settings, debugLoggingPort)
                numeric:YES];
}

- (void)viewWillDisappear:(BOOL)animated {
    [[RMBTControlServer sharedControlServer] updateWithCurrentSettings];
}

#pragma mark - Two-way binding helpers

- (void)bindSwitch:(UISwitch*)aSwitch toSettingsKeyPath:(NSString*)keyPath onToggle:(void(^)(BOOL value))onToggle {
    aSwitch.on = [[[RMBTSettings sharedSettings] valueForKey:keyPath] boolValue];
    [aSwitch bk_addEventHandler:^(UISwitch *sender) {
        [[RMBTSettings sharedSettings] setValue:[NSNumber numberWithBool:sender.on] forKey:keyPath];
        if (onToggle) onToggle(sender.on);
    } forControlEvents:UIControlEventValueChanged];
}

- (void)bindTextField:(UITextField*)aTextField toSettingsKeyPath:(NSString*)keyPath numeric:(BOOL)numeric {
    [self bindTextField:aTextField toSettingsKeyPath:keyPath numeric:numeric min:NSIntegerMin max:NSIntegerMax];
}

- (void)bindTextField:(UITextField*)aTextField toSettingsKeyPath:(NSString*)keyPath numeric:(BOOL)numeric min:(NSInteger)min max:(NSInteger)max {
    id value = [[RMBTSettings sharedSettings] valueForKey:keyPath];
    NSString *stringValue = numeric ? [value stringValue] : value;
    if (numeric && [stringValue isEqualToString:@"0"]) stringValue = nil;
    aTextField.text = stringValue;

    [aTextField bk_addEventHandler:^(UITextField *sender) {
        NSInteger value = [sender.text integerValue];
        if (numeric && (value < min)) {
            sender.text = [@(min) stringValue];
        } else if (numeric && value > max) {
            sender.text = [@(max) stringValue];
        }
        id newValue = numeric ? [NSNumber numberWithInteger:[sender.text integerValue]] : sender.text;
        [[RMBTSettings sharedSettings] setValue:newValue forKey:keyPath];
    } forControlEvents:UIControlEventEditingDidEnd];
}

#pragma mark - Table view

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    NSInteger lastSectionIndex = [RMBTSettings sharedSettings].debugUnlocked ? RMBTSettingsSectionDebugLogging : RMBTSettingsSectionLoop;
    return lastSectionIndex + 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == RMBTSettingsSectionLoop && ![RMBTSettings sharedSettings].expertMode) {
        return 0;
    } else if (section == RMBTSettingsSectionLoop && ![RMBTSettings sharedSettings].loopMode)  {
        return 1; // hide customization
    } else if (section == RMBTSettingsSectionDebugCustomControlServer && ![RMBTSettings sharedSettings].debugControlServerCustomizationEnabled) {
        return 1; // hide customization
    } else if (section == RMBTSettingsSectionDebugLogging && ![RMBTSettings sharedSettings].debugLoggingEnabled) {
        return 1; // hide customization
    } else {
        return [super tableView:tableView numberOfRowsInSection:section];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (section == RMBTSettingsSectionLoop && ![RMBTSettings sharedSettings].expertMode) {
        return CGFLOAT_MIN;
    } else {
        return [super tableView:tableView heightForHeaderInSection:section];
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == RMBTSettingsSectionLoop && ![RMBTSettings sharedSettings].expertMode) {
        return nil;
    } else {
        return [super tableView:tableView titleForHeaderInSection:section];
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == RMBTSettingsSectionLoop && ![RMBTSettings sharedSettings].expertMode) {
        return nil;
    } else {
        return [super tableView:tableView titleForFooterInSection:section];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    [cell.contentView rmbt_enumerateSubviewsOfType:[UITextField class] usingBlock:^(UIView *f) {
        UITextField* tf = (UITextField*)f;
        if (!tf.isFirstResponder) {
            [tf becomeFirstResponder];
        }
    }];
}

- (void)refreshSection:(RMBTSettingsSection)section {
    NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:section];
    [self.tableView beginUpdates];
    [self.tableView reloadSections:indexSet withRowAnimation: UITableViewRowAnimationAutomatic];
    [self.tableView reloadData];
    [self.tableView endUpdates];
}

#pragma mark - Textfield delegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

#pragma mark - Loop mode confirmation

- (IBAction)declineLoopModeConfirmation:(UIStoryboardSegue*)segue {
    [self.loopModeSwitch setOn:NO];
    [segue.sourceViewController dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)acceptLoopModeConfirmation:(UIStoryboardSegue*)segue {
    [RMBTSettings sharedSettings].loopMode = YES;
    [self refreshSection:RMBTSettingsSectionLoop];
    [segue.sourceViewController dismissViewControllerAnimated:YES completion:nil];
}


@end
