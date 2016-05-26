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

#import "RMBTControlServer.h"
#import "RMBTSettings.h"
#import "RMBTTOS.h"

#import <AFNetworking/AFHTTPClient.h>
#include <sys/sysctl.h>

static NSString * const kLastNewsUidPreferenceKey = @"last_news_uid";

@interface RMBTControlServer() {
    NSString *_uuidKey;
    dispatch_queue_t _uuidQueue;
}
@property (nonatomic, strong) AFHTTPClient *httpClient;
@property (nonatomic, copy) NSString *uuid;
@property (nonatomic, assign) long lastNewsUid;
@end

@implementation RMBTControlServer

+ (instancetype)sharedControlServer {
    static id instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
        [instance updateWithCurrentSettings];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        _uuidQueue = dispatch_queue_create("at.rtr.rmbt.controlserver.uuid", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)updateWithCurrentSettings {
    RMBTSettings *settings = [RMBTSettings sharedSettings];

    NSString *urlString = RMBT_CONTROL_SERVER_URL;

    if (settings.debugUnlocked && settings.debugForceIPv6) {
        NSAssert(!settings.forceIPv4, @"Force IPv4 and IPv6 should be mutually exclusive");
        urlString = RMBT_CONTROL_SERVER_IPV6_URL;
    } else if (settings.forceIPv4) {
        urlString = RMBT_CONTROL_SERVER_IPV4_URL;
    }

    NSURL *baseURL = [NSURL URLWithString:urlString];

    if (settings.debugUnlocked && settings.debugControlServerCustomizationEnabled) {
        NSString *scheme = settings.debugControlServerUseSSL ? @"https" : @"http";
        NSString *hostname = settings.debugControlServerHostname;
        if (settings.debugControlServerPort != 0 && settings.debugControlServerPort != 80) {
            hostname = [hostname stringByAppendingFormat:@":%lu", (unsigned long)settings.debugControlServerPort];
        }
        baseURL =  [[NSURL alloc] initWithScheme:scheme host:hostname path:@"/RMBTControlServer"];
        _uuidKey = [NSString stringWithFormat:@"uuid_%@", baseURL.host];
    } else {
        // For UUID storage key, always take the default hostname to avoid getting 2 different UUIDs for
        // ipv4-only and regular control server URLs
        _uuidKey = [NSString stringWithFormat:@"uuid_%@", [[NSURL URLWithString:RMBT_CONTROL_SERVER_URL] host]];
    }
    
    self.httpClient = [[AFHTTPClient alloc] initWithBaseURL:baseURL];
    self.httpClient.parameterEncoding = AFJSONParameterEncoding;

    self.uuid = [[NSUserDefaults standardUserDefaults] objectForKey:_uuidKey];

    NSNumber *lastNewsUidNumber = [[NSUserDefaults standardUserDefaults] objectForKey:kLastNewsUidPreferenceKey];
    if (lastNewsUidNumber) {
        _lastNewsUid = [lastNewsUidNumber longValue];
    } else {
        _lastNewsUid = 0;
    }
}

- (void)setLastNewsUid:(long)lastNewsUid {
    _lastNewsUid = lastNewsUid;
    [[NSUserDefaults standardUserDefaults] setObject:@(_lastNewsUid) forKey:kLastNewsUidPreferenceKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSString*)uuid {
    return _uuid;
}

- (void)submitResult:(NSDictionary*)result success:(RMBTSuccessBlock)success error:(RMBTBlock)error {
    NSMutableDictionary *mergedParams = [NSMutableDictionary dictionary];
    [mergedParams addEntriesFromDictionary:result];

    NSDictionary *systemInfo = [self systemInfoParams];
    
    // Note:
    // Unlike /settings, the /result resource expects "name" and "version" params
    // to be prefixed as "client_"
    [mergedParams addEntriesFromDictionary:@{
      @"client_name": systemInfo[@"client"],
      @"client_version": systemInfo[@"version"],
      @"client_language": systemInfo[@"language"],
      @"client_software_version": systemInfo[@"softwareVersion"]
    }];
    
//    NSLog(@"Submit %@", mergedParams);

    [self requestWithMethod:@"POST" path:@"result" params:mergedParams success:^(NSDictionary *response) {
        if (!response || (response[@"error"] && [response[@"error"] count] > 0)) {
            RMBTLog(@"Error submitting rest result: %@", response[@"error"]);
            error();
        } else {
            RMBTLog(@"Test result submitted");
            success(nil);
        }
    } error:^(NSError *err, NSDictionary *response) {
        RMBTLog(@"Error submitting result err=%@, response=%@", err, response);
        error();
    }];
}

- (void)getSettings:(RMBTBlock)success error:(RMBTErrorBlock)errorCallback {
    [self requestWithMethod:@"POST"
                       path:@"settings"
                     params:@{
                              @"terms_and_conditions_accepted": @YES,
                              @"terms_and_conditions_accepted_version": @([RMBTTOS sharedTOS].lastAcceptedVersion)
                            }
                    success:^(NSDictionary *response) {
        // If we didn't have UUID yet and server is sending us one, save it for future requests
        if (!self.uuid && response[@"settings"] && response[@"settings"][0][@"uuid"]) {
            self.uuid = response[@"settings"][0][@"uuid"];
            [[NSUserDefaults standardUserDefaults] setObject:self.uuid forKey:_uuidKey];
            [[NSUserDefaults standardUserDefaults] synchronize];
            RMBTLog(@"Got new uuid %@", self.uuid);
        }
        
        _historyFilters = response[@"settings"][0][@"history"];
        _openTestBaseURL = response[@"settings"][0][@"urls"][@"open_data_prefix"];

        success();
    } error:^(NSError *error, NSDictionary *response) {
        RMBTLog(@"Error getting settings (error=%@, response=%@)", error, response);
        errorCallback(error, response);
    }];
}


- (void)getNews:(RMBTSuccessBlock)success {
    RMBTLog(@"Getting news (lastNewsUid=%ld)...", _lastNewsUid);

    [self requestWithMethod:@"POST" path:@"news" params:@{
        @"lastNewsUid": @(_lastNewsUid)
    } success:^(id response) {
        if (response[@"news"]) {
            long maxNewsUid = 0;
            NSMutableArray *result = [NSMutableArray array];
            for (NSDictionary *subresponse in response[@"news"]) {
                RMBTNews* n = [[RMBTNews alloc] initWithResponse:subresponse];
                [result addObject:n];
                if (n.uid > maxNewsUid) maxNewsUid = n.uid;
            }
            if (maxNewsUid > 0) self.lastNewsUid = maxNewsUid;
            success(result);
        } else {
            // error
        }
    } error:^(NSError *error, NSDictionary *info) {
        // error
    }];
}

- (void)getRoamingStatusWithParams:(NSDictionary*)params success:(RMBTSuccessBlock)success {
    RMBTLog(@"Checking roaming status (params = %@)", params);
    [self performWithUUID:^{
        [self requestWithMethod:@"POST" path:@"status" params:params success:^(id response) {
            if (response && response[@"home_country"] && [response[@"home_country"] boolValue] == NO) {
                success(@(YES));
            } else {
                success(@(NO));
            }
        } error:^(NSError *error, NSDictionary *info) {
        }];
    } error:^(NSError *error, NSDictionary *info) {
    }];
}

- (void)getTestParamsWithParams:(NSDictionary*)params success:(RMBTSuccessBlock)success error:(RMBTBlock)errorCallback {
    NSMutableDictionary *requestParams = [NSMutableDictionary dictionaryWithDictionary:@{
        @"ndt": @NO,
        @"time": RMBTTimestampWithNSDate([NSDate date])
    }];
    
    [requestParams addEntriesFromDictionary:params];
    
    [self performWithUUID:^{
        [self requestWithMethod:@"POST" path:@"testRequest" params:requestParams success:^(NSDictionary *response) {
             RMBTTestParams *tp = [[RMBTTestParams alloc] initWithResponse:response];
             success(tp);
         } error:^(NSError *err, NSDictionary *response) {
             RMBTLog(@"Fetching test parameters failed with err=%@, response=%@", err, response);
             errorCallback();
         }];
    } error:^(NSError *error, NSDictionary *info) {
        errorCallback();
    }];
}

- (void)getHistoryWithFilters:(NSDictionary*)filters length:(NSUInteger)length offset:(NSUInteger)offset success:(RMBTSuccessBlock)success error:(RMBTErrorBlock)errorCallback {
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:@{
        @"result_offset": [NSNumber numberWithUnsignedInteger:offset],
        @"result_limit": [NSNumber numberWithUnsignedInteger:length]
    }];
    
    if (filters) {
        [params addEntriesFromDictionary:filters];
    }
    
    [self performWithUUID:^{
        [self requestWithMethod:@"POST" path:@"history" params:params success:^(id response) {
            // TODO: check for errors
            success(response[@"history"]);
        } error:^(NSError *error, NSDictionary *info) {
            RMBTLog(@"Error fetching history with filters (error=%@, info=%@)", error, info);
            errorCallback(error, info);
        }];
    } error:^(NSError *error, NSDictionary *info) {
        errorCallback(error, info);
    }];
}

- (void)getHistoryResultWithUUID:(NSString*)uuid fullDetails:(BOOL)fullDetails success:(RMBTSuccessBlock)success error:(RMBTErrorBlock)errorCallback {
    NSString *key = fullDetails ? @"testresultdetail" : @"testresult";
    [self performWithUUID:^{
        [self requestWithMethod:@"POST" path:key params:@{@"test_uuid": uuid} success:^(id response) {
            if (fullDetails) {
                success(response[key]);
            } else {
                success([response[key] objectAtIndex:0]);
            }
        } error:^(NSError *error, NSDictionary *info) {
            RMBTLog(@"Error fetching history result (uuid=%@, error=%@, info=%@)", uuid, error, info);
            errorCallback(error, info);
        }];
    } error:^(NSError *error, NSDictionary *info) {
        errorCallback(error, info);
    }];
}

- (void)getSyncCode:(RMBTSuccessBlock)success error:(RMBTErrorBlock)errorCallback {
    [self performWithUUID:^{
        [self requestWithMethod:@"POST" path:@"sync" params:@{} success:^(id response) {
            if (response && response[@"sync"]) {
                NSDictionary *syncDictionary = [response[@"sync"] objectAtIndex:0];
                success(syncDictionary[@"sync_code"]);
            }
        } error:^(NSError *error, NSDictionary *info) {
            RMBTLog(@"Error fetching sync code (error=%@, info=%@)", error, info);
        }];
    } error:^(NSError *error, NSDictionary *info) {
        errorCallback(error, info);
    }];
}

- (void)syncWithCode:(NSString*)code success:(RMBTBlock)success error:(RMBTErrorBlock)errorCallback {
    [self performWithUUID:^{
        [self requestWithMethod:@"POST" path:@"sync" params:@{@"sync_code":code} success:^(id response) {
            if (response && response[@"sync"]) {
                NSDictionary *syncDictionary = [response[@"sync"] objectAtIndex:0];
                if ([syncDictionary[@"success"] unsignedIntegerValue] > 0) {
                    success();
                } else {
                    // TODO title and text extract here
                    errorCallback([NSError errorWithDomain:@"RMBTControlServer" code:0 userInfo:syncDictionary], response);
                }
            }
        } error:^(NSError *error, NSDictionary *info) {
            RMBTLog(@"Error syncing (code=%@, error=@, info=%@)", code, error, info);
            errorCallback(error, info);
        }];
    } error:^(NSError *error, NSDictionary *info) {
        errorCallback(error, info);
    }];
}

- (void)performWithUUID:(RMBTBlock)callback error:(RMBTErrorBlock)errorCallback {
    dispatch_async(_uuidQueue, ^{
        if (self.uuid) {
            callback();
        } else {
            dispatch_suspend(_uuidQueue);
            [self getSettings:^{
                dispatch_resume(_uuidQueue);
                if (self.uuid) {
                    callback();
                } else {
                    NSAssert(false, @"Couldn't obtain UUID from control server");
                }
            } error:^(NSError *error, NSDictionary *info) {
                dispatch_resume(_uuidQueue);
                RMBTLog(@"Error fetching UUID (error=%@, response=%@)", error, info);
                errorCallback(error, info);
            }];
        }
    });
}

- (void)requestWithMethod:(NSString*)method
                     path:(NSString*)path
                   params:(NSDictionary*)params
                  success:(RMBTSuccessBlock)success
                   error:(RMBTErrorBlock)failure
{
    NSMutableDictionary *mergedParams = [NSMutableDictionary dictionary];

    if (self.uuid) [mergedParams setObject:self.uuid forKey:@"uuid"];

    [mergedParams addEntriesFromDictionary:self.systemInfoParams];
    [mergedParams addEntriesFromDictionary:params];

//    NSLog(@"Requesting %@", mergedParams);

    NSMutableURLRequest *request = [self.httpClient requestWithMethod:method path:path parameters:mergedParams];

    AFJSONRequestOperation *operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:request success:^(id request, id response, id json) {
        success(json);
    } failure:^(id request, id response, NSError *error, id json) {
        if (error && error.code == kCFURLErrorCancelled) return; // Ignore cancelled requests
        failure(error, json);
    }];

    [self.httpClient enqueueHTTPRequestOperation:operation];
}


#pragma mark - System Info

- (NSDictionary *)systemInfoParams {
    id infoDictionary = [[NSBundle mainBundle] infoDictionary];

    return @{
             @"plattform": @"iOS",
             @"os_version": RMBTValueOrNull([[UIDevice currentDevice] systemVersion]),
             @"model": RMBTValueOrNull([self systemInfoDeviceInternalModel]),
             @"device": RMBTValueOrNull([[UIDevice currentDevice] model]),
             @"language": RMBTValueOrNull(RMBTPreferredLanguage()),
             @"timezone": RMBTValueOrNull([NSTimeZone systemTimeZone].name),
             @"type": @"MOBILE",
             @"name": @"RMBT",
             @"client": @"RMBT",
             @"version": @"0.3",
             @"softwareVersion": RMBTValueOrNull(infoDictionary[@"CFBundleShortVersionString"]),
             @"softwareVersionCode": RMBTValueOrNull(infoDictionary[@"CFBundleVersion"]),
             @"softwareRevision": RMBTValueOrNull(RMBTBuildInfoString()),
             @"capabilities": @{ @"classification": @{ @"count": @(4) } }
    };
}

- (NSString *)systemInfoDeviceInternalModel {
    char *typeSpecifier = "hw.machine";

    size_t size;
    sysctlbyname(typeSpecifier, NULL, &size, NULL, 0);

    char *answer = malloc(size);
    sysctlbyname(typeSpecifier, answer, &size, NULL, 0);

    NSString *result = @(answer);
    free(answer);
    return result;
}

- (NSURL*)baseURL {
    return self.httpClient.baseURL;
}

- (void)cancelAllRequests {
    [[self.httpClient operationQueue] cancelAllOperations];
}
@end
