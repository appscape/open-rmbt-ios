//
//  RMBTQoSIPTest.h
//  RMBT
//
//  Created by Esad Hajdarevic on 26/05/17.
//  Copyright © 2017 appscape gmbh. All rights reserved.
//

#import "RMBTQoSCCTest.h"

typedef NS_ENUM(NSInteger, RMBTQoIPTestDirection) {
    RMBTQoSIPTestDirectionOut,
    RMBTQoSIPTestDirectionIn,
    RMBTQoSIPTestDirectionError
};

@interface RMBTQoSIPTest : RMBTQoSCCTest
@property (nonatomic, assign) RMBTQoIPTestDirection direction;
@property (nonatomic, readonly) NSUInteger outPort, inPort;

- (void)ipMain:(BOOL)outgoing;
@end
