//
//  RMBTHistoryQoSResult.h
//  RMBT
//
//  Created by Esad Hajdarevic on 17/11/16.
//  Copyright © 2016 appscape gmbh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RMBTHistoryQoSSingleResult.h"

@class RMBTHistoryResultItem;

@interface RMBTHistoryQoSGroupResult : NSObject
@property (nonatomic, readonly) NSString *name, *about;
@property (nonatomic, readonly) NSArray<RMBTHistoryQoSSingleResult*> *tests;
@property (nonatomic, readonly) NSUInteger succeededCount;

+ (NSArray<RMBTHistoryQoSGroupResult*>*)resultsWithResponse:(NSDictionary*)response;
- (RMBTHistoryResultItem*)toResultItem;

@end
