//
//  RMBTQosWebTestURLProtocol.h
//  RMBT
//
//  Created by Esad Hajdarevic on 15/04/17.
//  Copyright © 2017 appscape gmbh. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString * const RMBTQosWebTestURLProtocolResultStatusKey;
extern NSString * const RMBTQosWebTestURLProtocolResultRxBytesKey;

@interface RMBTQosWebTestURLProtocol : NSURLProtocol
+ (void)start;
+ (void)stop;
+ (void)tagRequest:(NSMutableURLRequest*)request withValue:(NSString*)value;
+ (NSDictionary*)queryResultWithTag:(NSString*)tag;
@end
