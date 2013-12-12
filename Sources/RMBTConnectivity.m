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

#import <SystemConfiguration/CaptiveNetwork.h>

#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCarrier.h>

#include <sys/types.h>
#include <sys/socket.h>
#include <ifaddrs.h>
#include <net/if_var.h>

#import "RMBTConnectivity.h"

@interface RMBTConnectivity()
@property (nonatomic, readonly) NSString *bssid;
@property (nonatomic, readonly) NSNumber *cellularCode;
@property (nonatomic, readonly) NSString *cellularCodeDescription;
//@property (nonatomic, readonly) NSString *cellularCodeGenerationString;
@property (nonatomic, readonly) NSString *telephonyNetworkSimOperator;
@property (nonatomic, readonly) NSString *telephonyNetworkSimCountry;
@end

@implementation RMBTConnectivity

- (instancetype)initWithNetworkType:(RMBTNetworkType)networkType {
    if (self = [super init]) {
        _networkType = networkType;
        _timestamp = [NSDate date];
        [self getNetworkDetails];
    }
    return self;
}

- (NSString*)networkTypeDescription {
    switch (_networkType) {
        case RMBTNetworkTypeNone:
            return @"Not connected";
        case RMBTNetworkTypeWiFi:
            return @"Wi-Fi";
        case RMBTNetworkTypeCellular:
            if (_cellularCodeDescription) {
                return _cellularCodeDescription;
            } else {
                return @"Cellular";
            }
        default:
            NSLog(@"Invalid network type %d", _networkType);
            return @"Unknown";
    }
}

#pragma mark - Internal

- (void)getNetworkDetails {
    _networkName = nil;
    _bssid = nil;
    _cellularCode = nil;
    _cellularCodeDescription = nil;
    
    switch (_networkType) {
        case RMBTNetworkTypeCellular: {
            // Get carrier name
            CTTelephonyNetworkInfo *netinfo = [[CTTelephonyNetworkInfo alloc] init];
            CTCarrier *carrier = [netinfo subscriberCellularProvider];
            _networkName = carrier.carrierName;
            _telephonyNetworkSimCountry = carrier.isoCountryCode;
            _telephonyNetworkSimOperator = [NSString stringWithFormat:@"%@-%@", carrier.mobileCountryCode, carrier.mobileNetworkCode];
            
            if ([netinfo respondsToSelector:@selector(currentRadioAccessTechnology)]) {
                // iOS7
                _cellularCode = [self cellularCodeForCTValue:netinfo.currentRadioAccessTechnology];
                _cellularCodeDescription = [self cellularCodeDescriptionForCTValue:netinfo.currentRadioAccessTechnology];
//                _cellularCodeGenerationString = [self cellularCodeGenerationString:netinfo.currentRadioAccessTechnology];
            }

            break;
        }
            
        case RMBTNetworkTypeWiFi: {
            // If WLAN, then show SSID as network name. Fetching SSID does not work on the simulator.
            NSArray *ifs = (__bridge_transfer id)CNCopySupportedInterfaces();
            for (NSString *ifnam in ifs) {
                NSDictionary *info = (__bridge_transfer id)CNCopyCurrentNetworkInfo((__bridge CFStringRef)ifnam);
                if (info) {
                    if (info[(NSString*)kCNNetworkInfoKeySSID]) _networkName = info[(NSString*)kCNNetworkInfoKeySSID];
                    if (info[(NSString*)kCNNetworkInfoKeyBSSID]) _bssid = RMBTReformatHexIdentifier(info[(NSString*)kCNNetworkInfoKeyBSSID]);
                    break;
                }
            }
            break;
        }
        case RMBTNetworkTypeNone:
            break;
        default:
            NSAssert1(false, @"Invalid network type %d", _networkType);
    }
}


- (NSNumber*)cellularCodeForCTValue:(NSString*)value {
    static NSDictionary *lookup = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        lookup = @{
           CTRadioAccessTechnologyGPRS:         @(1),
           CTRadioAccessTechnologyEdge:         @(2),
           CTRadioAccessTechnologyWCDMA:        @(3),
           CTRadioAccessTechnologyCDMA1x:       @(4),
           CTRadioAccessTechnologyCDMAEVDORev0: @(5),
           CTRadioAccessTechnologyCDMAEVDORevA: @(6),
           CTRadioAccessTechnologyHSDPA:        @(8),
           CTRadioAccessTechnologyHSUPA:        @(9),
           CTRadioAccessTechnologyCDMAEVDORevB: @(12),
           CTRadioAccessTechnologyLTE:          @(13),
           CTRadioAccessTechnologyeHRPD:        @(14),
        };
    });
    return lookup[value];
}

- (NSString*)cellularCodeDescriptionForCTValue:(NSString*)value {
    static NSDictionary *lookup = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        lookup = @{
            CTRadioAccessTechnologyGPRS:            @"GPRS (2G)",
            CTRadioAccessTechnologyEdge:            @"EDGE (2G)",
            CTRadioAccessTechnologyWCDMA:           @"UMTS (3G)",
            CTRadioAccessTechnologyCDMA1x:          @"CDMA (2G)",
            CTRadioAccessTechnologyCDMAEVDORev0:    @"EVDO0 (2G)",
            CTRadioAccessTechnologyCDMAEVDORevA:    @"EVDOA (2G)",
            CTRadioAccessTechnologyHSDPA:           @"HSDPA (3G)",
            CTRadioAccessTechnologyHSUPA:           @"HSUPA (3G)",
            CTRadioAccessTechnologyCDMAEVDORevB:    @"EVDOB (2G)",
            CTRadioAccessTechnologyLTE:             @"LTE (4G)",
            CTRadioAccessTechnologyeHRPD:           @"HRPD (2G)",
         };
    });
    return lookup[value];
}

//- (NSString*)cellularCodeGenerationString:(NSString*)value {
//    static NSDictionary *lookup = nil;
//    static dispatch_once_t onceToken;
//    dispatch_once(&onceToken, ^{
//        lookup = @{
//            CTRadioAccessTechnologyGPRS:            @"2G",
//            CTRadioAccessTechnologyEdge:            @"2G",
//            CTRadioAccessTechnologyWCDMA:           @"3G",
//            CTRadioAccessTechnologyCDMA1x:          @"2G",
//            CTRadioAccessTechnologyCDMAEVDORev0:    @"2G",
//            CTRadioAccessTechnologyCDMAEVDORevA:    @"2G",
//            CTRadioAccessTechnologyHSDPA:           @"3G",
//            CTRadioAccessTechnologyHSUPA:           @"3G",
//            CTRadioAccessTechnologyCDMAEVDORevB:    @"2G",
//            CTRadioAccessTechnologyLTE:             @"4G",
//            CTRadioAccessTechnologyeHRPD:           @"2G",
//        };
//    });
//    return lookup[value];
//}

- (NSDictionary*)testResultDictionary {
    NSMutableDictionary *result = [NSMutableDictionary dictionary];

    NSInteger code = self.networkType;
    if (code > 0) result[@"network_type"] = [NSNumber numberWithUnsignedInt:code];

    if (self.networkType == RMBTNetworkTypeWiFi) {
        if (_networkName) result[@"wifi_ssid"] = _networkName;
        if (_bssid) result[@"wifi_bssid"] = _bssid;
    } else if (self.networkType == RMBTNetworkTypeCellular) {
        if (_cellularCode) {
            result[@"network_type"] = _cellularCode;
        }
        result[@"telephony_network_sim_operator_name"] = RMBTValueOrNull(self.networkName);
        result[@"telephony_network_sim_country"] = RMBTValueOrNull(_telephonyNetworkSimCountry);
        result[@"telephony_network_sim_operator"] = RMBTValueOrNull(_telephonyNetworkSimOperator);
    }
    return result;
}

- (BOOL)isEqualToConnectivity:(RMBTConnectivity*)other {
    if (other == self) return YES;
    if (!other) return NO;
    return ([other.networkTypeDescription isEqualToString:self.networkTypeDescription] && [other.networkName isEqualToString:self.networkName]);
}

#pragma mark - Interface values

- (RMBTConnectivityInterfaceInfo)getInterfaceInfo {
    RMBTConnectivityInterfaceInfo result = {0,0};

    struct ifaddrs *addrs;
    const struct ifaddrs *cursor;
    const struct if_data *stats;

    if (getifaddrs(&addrs) == 0) {
        cursor = addrs;
        while (cursor != NULL) {
            NSString *name=[NSString stringWithCString:cursor->ifa_name encoding:NSASCIIStringEncoding];
            // en0 is WiFi, pdp_ip0 is WWAN
            if (cursor->ifa_addr->sa_family == AF_LINK && (
                ([name hasPrefix:@"en"] && self.networkType == RMBTNetworkTypeWiFi) ||
                ([name hasPrefix:@"pdp_ip"] && self.networkType == RMBTNetworkTypeCellular)
            )) {
                stats = (const struct if_data *) cursor->ifa_data;
                result.bytesSent += stats->ifi_obytes;
                result.bytesReceived += stats->ifi_ibytes;
            }
            cursor = cursor->ifa_next;
        }
        freeifaddrs(addrs);
    }
    return result;
}

@end
