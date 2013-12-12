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

#import "RMBTSettings.h"
#import <BlocksKit/BlocksKit.h>

@implementation RMBTSettings

+ (instancetype)sharedSettings {
    static RMBTSettings *_sharedSettings = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        _sharedSettings = [[self alloc] init];
    });
    return _sharedSettings;
}

- (instancetype)init {
    if (self = [super init]) {
        _mapOptionsSelection = [[RMBTMapOptionsSelection alloc] init];
        [self bindKeyPaths: @[
            @keypath(self.testCounter),
            @keypath(self.previousTestStatus),
            @keypath(self.forceIPv4),
            @keypath(self.debugUnlocked),
            @keypath(self.debugForceIPv6),
            @keypath(self.debugControlServerCustomizationEnabled),
            @keypath(self.debugControlServerHostname),
            @keypath(self.debugControlServerPort),
            @keypath(self.debugControlServerUseSSL),
            @keypath(self.debugLoopMode),
            @keypath(self.debugLoggingEnabled),
            @keypath(self.debugLoggingHostname),
            @keypath(self.debugLoggingPort)
        ]];
    }
    return self;
}

- (void)bindKeyPaths:(NSArray*)keyPaths {
    for (NSString *keyPath in keyPaths) {
        id value = [[NSUserDefaults standardUserDefaults] objectForKey:keyPath];
        if (value) [self setValue:value forKey:keyPath];

        // Start observing
        [self addObserverForKeyPath:keyPath options:NSKeyValueObservingOptionNew task:^(id obj, NSDictionary *change) {
            id newValue = change[NSKeyValueChangeNewKey];
            [[NSUserDefaults standardUserDefaults] setObject:newValue forKey:keyPath];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }];
    }
}

@end
