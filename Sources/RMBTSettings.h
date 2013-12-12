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

#import <Foundation/Foundation.h>
#import "RMBTConnectivity.h"
#import "RMBTMapOptions.h"

@interface RMBTSettings : NSObject

#pragma mark - Temporary app state (global variables)

@property (nonatomic, retain) RMBTMapOptionsSelection *mapOptionsSelection;

#pragma mark - Persisted app state

@property (nonatomic, assign) NSUInteger testCounter;
@property (nonatomic, copy) NSString    *previousTestStatus;

#pragma mark - User configurable properties

@property (nonatomic, assign) BOOL       forceIPv4;

#pragma mark - Debug properties

@property (nonatomic, assign) BOOL       debugUnlocked;

@property (nonatomic, assign) BOOL       debugForceIPv6;

@property (nonatomic, assign) BOOL       debugControlServerCustomizationEnabled;
@property (nonatomic, copy)   NSString  *debugControlServerHostname;
@property (nonatomic, assign) NSUInteger debugControlServerPort;
@property (nonatomic, assign) BOOL       debugControlServerUseSSL;

@property (nonatomic, assign) BOOL       debugLoopMode;

@property (nonatomic, assign) BOOL       debugLoggingEnabled;
@property (nonatomic, assign) NSString  *debugLoggingHostname;
@property (nonatomic, assign) NSUInteger debugLoggingPort;

+ (instancetype)sharedSettings;

@end