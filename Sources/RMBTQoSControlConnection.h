//
//  RMBTQoSControlConnection.h
//  RMBT
//
//  Created by Esad Hajdarevic on 18/03/17.
//  Copyright © 2017 appscape gmbh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RMBTQoSControlConnectionParams.h"

@interface RMBTQoSControlConnection : NSObject
@property (nonatomic, readonly) NSString *token;
- (instancetype)initWithConnectionParams:(RMBTQoSControlConnectionParams*)params
                                   token:(NSString*)token;
- (void)sendCommand:(NSString*)line readReply:(BOOL)readReply success:(RMBTSuccessBlock)success error:(RMBTErrorBlock)error;
- (void)close;
@end
