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
#import "RMBTNetworkType.h"

typedef NS_ENUM(NSUInteger, RMBTConnectivityInterfaceInfoTraffic) {
    RMBTConnectivityInterfaceInfoTrafficSent,
    RMBTConnectivityInterfaceInfoTrafficReceived,
    RMBTConnectivityInterfaceInfoTrafficTotal
};

typedef struct {
    uint32_t bytesReceived;
    uint32_t bytesSent;
} RMBTConnectivityInterfaceInfo;

@interface RMBTConnectivity : NSObject

@property (nonatomic, readonly) RMBTNetworkType networkType;

// Human readable description of the network type: Wi-Fi, Celullar
@property (nonatomic, readonly) NSString *networkTypeDescription;

// Carrier name for cellular, SSID for Wi-Fi
@property (nonatomic, readonly) NSString *networkName;

// Timestamp at which connectivity was detected
@property (nonatomic, readonly) NSDate *timestamp;

- (instancetype)initWithNetworkType:(RMBTNetworkType)networkType;

- (NSDictionary*)testResultDictionary;

- (BOOL)isEqualToConnectivity:(RMBTConnectivity*)other;

// Gets byte counts from the network interface used for the connectivity.
// Note that the count refers to number of bytes since device boot.
- (RMBTConnectivityInterfaceInfo)getInterfaceInfo;

// Total (up+down) difference in bytes transferred between two readouts. If counter has wrapped returns 0.
+ (uint64_t)countTraffic:(RMBTConnectivityInterfaceInfoTraffic)traffic between:(RMBTConnectivityInterfaceInfo)info1 and:(RMBTConnectivityInterfaceInfo)info2;

@end
