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

@interface RMBTTestParams : NSObject

@property (nonatomic, readonly) NSString*           clientRemoteIp;
@property (nonatomic, readonly) NSUInteger          pingCount;
@property (nonatomic, readonly) NSTimeInterval      pretestDuration;
@property (nonatomic, readonly) NSUInteger          pretestMinChunkCountForMultithreading;
@property (nonatomic, readonly) NSString*           serverAddress;
@property (nonatomic, readonly) BOOL                serverEncryption;
@property (nonatomic, readonly) NSString*           serverName;
@property (nonatomic, readonly) NSUInteger          serverPort;

// New protocol
@property (nonatomic, readonly) BOOL                serverIsRmbtHTTP;

@property (nonatomic, readonly) NSString*           resultURLString;
@property (nonatomic, readonly) NSTimeInterval      testDuration;
@property (nonatomic, readonly) NSString*           testToken;
@property (nonatomic, readonly) NSString*           testUUID;
@property (nonatomic, readonly) NSUInteger          threadCount;
@property (nonatomic, readonly) NSTimeInterval      waitDuration;
@property (nonatomic, readonly) NSString*           resultQoSURLString;

- (id)initWithResponse:(NSDictionary*)response;

@end
