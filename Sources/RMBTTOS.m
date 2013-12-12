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

#import "RMBTTOS.h"

static NSString * const kTOSPreferenceKey = @"tos_version";

@interface RMBTTOS()
@property (nonatomic, assign) NSUInteger lastAcceptedVersion;
@end

@implementation RMBTTOS

+ (instancetype)sharedTOS {
    static RMBTTOS *instance = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        NSNumber *tosVersionNumber = [[NSUserDefaults standardUserDefaults] objectForKey:kTOSPreferenceKey];
        if (tosVersionNumber) {
            _lastAcceptedVersion = [tosVersionNumber unsignedIntegerValue];
        } else {
            _lastAcceptedVersion = 0;
        }
    }
    return self;
}

- (NSUInteger)currentVersion {
    return RMBT_TOS_VERSION;
}

- (BOOL)isCurrentVersionAccepted {
    return self.lastAcceptedVersion >= self.currentVersion;
}

- (void)acceptCurrentVersion {
    self.lastAcceptedVersion = RMBT_TOS_VERSION;
    [[NSUserDefaults standardUserDefaults] setObject:@(_lastAcceptedVersion) forKey:kTOSPreferenceKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end
