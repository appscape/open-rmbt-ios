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

#import "RMBTNetworkType.h"

@interface RMBTHistoryResultItem : NSObject
@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readonly) NSString *value;
@property (nonatomic, readonly) NSInteger classification;
- (instancetype)initWithResponse:(NSDictionary*)response;
@end

typedef NS_ENUM(NSUInteger, RMBTHistoryResultDataState) {
    RMBTHistoryResultDataStateIndex,
    RMBTHistoryResultDataStateBasic,
    RMBTHistoryResultDataStateFull
};

@interface RMBTHistoryResult : NSObject

@property (nonatomic, readonly) RMBTHistoryResultDataState dataState;

#pragma - Index

@property (nonatomic, readonly) NSString *uuid;
@property (nonatomic, readonly) NSDate   *timestamp;
@property (nonatomic, readonly) NSString *downloadSpeedMbpsString, *uploadSpeedMbpsString;
@property (nonatomic, readonly) NSString *shortestPingMillisString;
@property (nonatomic, readonly) NSString *deviceModel;
@property (nonatomic, readonly) CLLocationCoordinate2D coordinate;
@property (nonatomic, readonly) NSString *networkTypeServerDescription; // "WLAN", "2G/3G" etc.

// Available in basic details
@property (nonatomic, readonly) RMBTNetworkType networkType;
@property (nonatomic, readonly) NSString *shareText;
@property (nonatomic, readonly) NSURL    *shareURL;

- (instancetype)initWithResponse:(NSDictionary*)response;

- (NSString*)formattedTimestamp;

#pragma mark - Basic Details

@property (nonatomic, readonly) NSArray *netItems;
@property (nonatomic, readonly) NSArray *measurementItems;

- (void)ensureBasicDetails:(RMBTBlock)success;

#pragma mark - Full Details

@property (nonatomic, readonly) NSArray *fullDetailsItems;
- (void)ensureFullDetails:(RMBTBlock)success;

@end

