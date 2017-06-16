//
//  RMBTQoSTestGroup.h
//  RMBT
//
//  Created by Esad Hajdarevic on 13/11/16.
//  Copyright © 2016 appscape gmbh. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RMBTQoSTest;

@interface RMBTQoSTestGroup : NSObject

@property (nonatomic, readonly) NSString *key, *localizedDescription;

+(instancetype)groupForKey:(NSString*)key localizedDescription:(NSString*)description;
-(RMBTQoSTest*)testWithParams:(NSDictionary*)params;

@end
