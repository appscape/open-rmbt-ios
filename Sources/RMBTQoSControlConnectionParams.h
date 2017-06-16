//
//  RMBTQoSControlConnectionParams.h
//  RMBT
//
//  Created by Esad Hajdarevic on 18/03/17.
//  Copyright © 2017 appscape gmbh. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RMBTQoSControlConnectionParams : NSObject<NSCopying>
@property (nonatomic, readonly) NSString *serverAddress;
@property (nonatomic, readonly) NSUInteger port;
- (instancetype)initWithServerAddress:(NSString*)address port:(NSUInteger)port;
@end
