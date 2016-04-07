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

#import "CLLocation+RMBTFormat.h"

@implementation CLLocation (RMBTFormat)

- (NSString*)rmbtFormattedString {
    static NSDateFormatter *timestampFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        timestampFormatter = [[NSDateFormatter alloc] init];
        [timestampFormatter setDateFormat:@"HH:mm:ss"];
    });

    NSInteger latSeconds = (NSInteger)round(fabs(self.coordinate.latitude * 3600));
    NSInteger latDegrees = latSeconds / 3600;
    latSeconds = latSeconds % 3600;
    CLLocationDegrees latMinutes = latSeconds / 60.0;

    NSInteger longSeconds = (NSInteger)round(fabs(self.coordinate.longitude * 3600));
    NSInteger longDegrees = longSeconds / 3600;
    longSeconds = longSeconds % 3600;
    CLLocationDegrees longMinutes = longSeconds / 60.0;

    char latDirection = (self.coordinate.latitude  >= 0) ? 'N' : 'S';
    char longDirection = (self.coordinate.longitude >= 0) ? 'E' : 'W';

    

    return [NSString stringWithFormat:@"%c %ld° %.3f' %c %ld° %.3f' (+/- %.0fm)\n@%@", latDirection, (long)latDegrees, latMinutes, longDirection, (long)longDegrees, longMinutes, self.horizontalAccuracy, [timestampFormatter stringFromDate:self.timestamp]];
}

- (NSDictionary*)paramsDictionary {
    return @{
        @"long": [NSNumber numberWithDouble:self.coordinate.longitude],
        @"lat":  [NSNumber numberWithDouble:self.coordinate.latitude],
        @"time":  RMBTTimestampWithNSDate(self.timestamp),
        @"accuracy": [NSNumber numberWithDouble:self.horizontalAccuracy],
        @"altitude": [NSNumber numberWithDouble:self.altitude],
        @"speed": [NSNumber numberWithDouble:(self.speed > 0.0 ? self.speed : 0.0)]
    };
}
@end
