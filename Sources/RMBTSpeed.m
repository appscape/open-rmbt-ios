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

#import "RMBTSpeed.h"
#include <math.h>

double RMBTSpeedLogValue(uint32_t kbps) {
    uint64_t bps = kbps * 1000;
    double log;
    if (bps < 10000) {
        log = 0;
    } else {
        log = (2.0f + log10(bps/1e6))/4.0;
    }
    return log;
}

NSString* RMBTSpeedMbpsSuffix() {
    static NSString *localizedMps = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        localizedMps = NSLocalizedString(@"Mbps", @"Speed suffix");
    });
    return localizedMps;
}

NSString* RMBTSpeedMbpsStringWithSuffix(uint32_t kbps, BOOL suffix) {
    NSString *speed = RMBTFormatNumber([NSNumber numberWithDouble:(double)kbps/1000.0]);
    if (suffix) {
        return [NSString stringWithFormat:@"%@ %@", speed, RMBTSpeedMbpsSuffix()];
    } else {
        return speed;
    }

}

NSString* RMBTSpeedMbpsString(uint32_t kbps) {
    return RMBTSpeedMbpsStringWithSuffix(kbps, YES);
}
