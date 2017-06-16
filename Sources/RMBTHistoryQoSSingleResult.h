//
//  RMBTHistoryQoSSingleResult.h
//  RMBT
//
//  Created by Esad Hajdarevic on 11/12/16.
//  Copyright © 2016 appscape gmbh. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RMBTHistoryQoSSingleResult : NSObject

// Test summary, e.g. @"Target: ebay.de \nEntry: A\nResolver: Standard"
@property (nonatomic, readonly) NSString *summary;
// Details of the executed test
@property (nonatomic, readonly) NSString *details;
@property (nonatomic, readonly) BOOL successful;

@property (nonatomic, readonly) NSNumber *uid;
@property (nonatomic, copy) NSString *statusDetails;

- (instancetype)initWithResponse:(NSDictionary*)response;
- (UIImage*)statusIcon;

@end
