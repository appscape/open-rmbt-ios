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

#import "RMBTTestParams.h"
#import "RMBTNews.h"

#import <Foundation/Foundation.h>
#import <AFNetworking/AFNetworking.h>

@interface RMBTControlServer : NSObject

@property (readonly, nonatomic) NSDictionary *historyFilters;
@property (readonly, nonatomic) NSString *openTestBaseURL;

+ (instancetype)sharedControlServer;

- (void)updateWithCurrentSettings;

- (void)getSettings:(RMBTBlock)success error:(RMBTErrorBlock)errorCallback;

// Retrieves news from server
- (void)getNews:(RMBTSuccessBlock)success;

// Retrieves home network (roaming) status from server. Resolved with a NSNumber representing
// a boolean value, which is true if user is out of home country.
- (void)getRoamingStatusWithParams:(NSDictionary*)params success:(RMBTSuccessBlock)success;

// Retrieves test parameters for the next test, submitting current test counter and last test status.
// If the client doesn't have an UUID yet, it first retrieves the settings to obtain the UUID
- (void)getTestParamsWithParams:(NSDictionary*)params success:(RMBTSuccessBlock)success error:(RMBTBlock)error;

// Retrieves list of previous test results.
// If the client doesn't have an UUID yet, it first retrieves the settings to obtain the UUID
- (void)getHistoryWithFilters:(NSDictionary*)filters length:(NSUInteger)length offset:(NSUInteger)offset success:(RMBTSuccessBlock)success error:(RMBTErrorBlock)errorCallback;

- (void)getHistoryResultWithUUID:(NSString*)uuid fullDetails:(BOOL)fullDetails success:(RMBTSuccessBlock)success error:(RMBTErrorBlock)errorCallback;

- (void)getSyncCode:(RMBTSuccessBlock)success error:(RMBTErrorBlock)errorCallback;
- (void)syncWithCode:(NSString*)code success:(RMBTBlock)success error:(RMBTErrorBlock)errorCallback;

- (void)submitResult:(NSDictionary*)result success:(RMBTSuccessBlock)success error:(RMBTBlock)error;

- (NSString *)uuid;
- (NSURL *)baseURL;

- (void)performWithUUID:(RMBTBlock)callback error:(RMBTErrorBlock)errorCallback;
- (void)cancelAllRequests;

@end
