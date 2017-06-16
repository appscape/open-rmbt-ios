//
//  RMBTHistorySpeedGraph.h
//  RMBT
//
//  Created by Esad Hajdarevic on 05/04/17.
//  Copyright © 2017 appscape gmbh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RMBTThroughput.h"

@interface RMBTHistorySpeedGraph : NSObject
@property (nonatomic, readonly) NSArray<RMBTThroughput*> *throughputs;

- (instancetype)initWithResponse:(NSArray*)response;
@end
