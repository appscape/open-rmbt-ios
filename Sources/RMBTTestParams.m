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

@implementation RMBTTestParams

- (id)initWithResponse:(NSDictionary*)response {
    if (!response[@"test_server_address"]) {
        // Probably invalid server response, return nil
        return nil;
    }

    if (self = [super init]) {
        _clientRemoteIp = [response[@"client_remote_ip"] copy];
        _pingCount = RMBT_TEST_PING_COUNT;
        _pretestDuration = RMBT_TEST_PRETEST_DURATION_S;
        _pretestMinChunkCountForMultithreading = RMBT_TEST_PRETEST_MIN_CHUNKS_FOR_MULTITHREADED_TEST;
        _serverAddress = [response[@"test_server_address"] copy];
        _serverEncryption = [response[@"test_server_encryption"] boolValue];
        _serverName = [response[@"test_server_name"] copy];

        // We use -integerValue as it's defined both on NSNumber and NSString, so we're more resilient in parsing:

        _serverPort = (NSUInteger)[response[@"test_server_port"] integerValue];
        RMBTAssertValidPort(_serverPort);

        _resultURLString = [response[@"result_url"] copy];
        _testDuration = (NSUInteger)[response[@"test_duration"] integerValue];

        NSAssert(_testDuration > 0 && _testDuration <= 100, @"Invalid test duration");

        _testToken = [response[@"test_token"] copy];
        _testUUID = [response[@"test_uuid"] copy];
        _threadCount = (NSUInteger)[response[@"test_numthreads"] integerValue];
        NSAssert(_threadCount > 0 && _threadCount <= 128, @"Invalid thread count");

        _waitDuration = (NSUInteger)[response[@"test_wait"] integerValue];
        NSAssert(_waitDuration >= 0 && _waitDuration <= 128, @"Invalid wait duration");

        _resultQoSURLString = [response[@"result_qos_url"] copy];
    }
    return self;
}

@end
