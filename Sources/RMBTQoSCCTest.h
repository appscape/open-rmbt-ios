/*
 * Copyright 2017 appscape gmbh
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

#import "RMBTQoSTest.h"
#import "RMBTQoSControlConnection.h"

// Superclass for all tests requiring a connection to the QoS control server (UDP, VoIP etc.)
@interface RMBTQoSCCTest : RMBTQoSTest
@property (nullable, nonatomic, readonly) RMBTQoSControlConnectionParams *controlConnectionParams;
- (void)setControlConnection:(RMBTQoSControlConnection*)connection;


- (NSString*)sendCommand:(NSString*)line readReply:(BOOL)readReply error:(NSError* __autoreleasing *)error;
- (NSString*)uuidFromToken;
@end
