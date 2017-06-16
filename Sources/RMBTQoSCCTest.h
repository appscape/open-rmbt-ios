//
//  RMBTQoSCCTest.h
//  RMBT
//
//  Created by Esad Hajdarevic on 18/03/17.
//  Copyright © 2017 appscape gmbh. All rights reserved.
//

#import "RMBTQoSTest.h"
#import "RMBTQoSControlConnection.h"

// Superclass for all tests requiring a connection to the QoS control server (UDP, VoIP etc.)
@interface RMBTQoSCCTest : RMBTQoSTest
@property (nullable, nonatomic, readonly) RMBTQoSControlConnectionParams *controlConnectionParams;
- (void)setControlConnection:(RMBTQoSControlConnection*)connection;


- (NSString*)sendCommand:(NSString*)line readReply:(BOOL)readReply error:(NSError* __autoreleasing *)error;
- (NSString*)uuidFromToken;
@end
