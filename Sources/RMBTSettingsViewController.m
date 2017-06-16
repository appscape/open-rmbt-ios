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
                [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:2]
                              withRowAnimation:UITableViewRowAnimationAutomatic];
                [self.tableView reloadData];
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

    [self bindSwitch:self.debugLoopModeSwitch
   toSettingsKeyPath:@keypath(settings, debugLoopMode)
            onToggle:nil];
    
    [self bindSwitch:self.debugLoggingEnabledSwitch
   toSettingsKeyPath:@keypath(settings, debugLoggingEnabled)
            onToggle:^(BOOL value) {
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:3] withRowAnimation:UITableViewRowAnimationAutomatic];
        [self.tableView reloadData];
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
    id value = [[RMBTSettings sharedSettings] valueForKey:keyPath];
    NSString *stringValue = numeric ? [value stringValue] : value;
    if (numeric && [stringValue isEqualToString:@"0"]) stringValue = nil;
    aTextField.text = stringValue;

    [aTextField bk_addEventHandler:^(UITextField *sender) {
        id newValue = numeric ? [NSNumber numberWithInteger:[sender.text integerValue]] : sender.text;
        [[RMBTSettings sharedSettings] setValue:newValue forKey:keyPath];
    } forControlEvents:UIControlEventEditingDidEnd];
}

#pragma mark - Table view

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [RMBTSettings sharedSettings].debugUnlocked ? 4 : 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // If control server customization is disabled, hide hostname/port/ssl cells
    if (section == 2 && ![RMBTSettings sharedSettings].debugControlServerCustomizationEnabled) {
        return 1;
    } else if (section == 3 && ![RMBTSettings sharedSettings].debugLoggingEnabled) {
        return 1;
    } else {
        return [super tableView:tableView numberOfRowsInSection:section];
    }
}

#pragma mark - Textfield delegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

@end
