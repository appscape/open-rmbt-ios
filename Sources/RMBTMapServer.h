/*
 * Copyright 2013 appscape gmbh
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

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import "RMBTMapOptions.h"

@interface RMBTMapServer : NSObject

- (void)getMapOptionsWithSuccess:(RMBTSuccessBlock)success;
- (void)getMeasurementsAtCoordinate:(CLLocationCoordinate2D)coordinate zoom:(NSUInteger)zoom params:(NSDictionary*)params success:(RMBTSuccessBlock)success;

- (NSURL*)tileURLForMapOverlayType:(NSString*)overlayType x:(NSUInteger)x y:(NSUInteger)y zoom:(NSUInteger)zoom params:(NSDictionary*)params;

- (void)getURLStringForOpenTestUUID:(NSString*)openTestUUID success:(RMBTSuccessBlock)success;
@end
