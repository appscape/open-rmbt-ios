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

#import "RMBTMapMeasurement.h"
#import "RMBTHistoryResult.h"

@interface RMBTMapMeasurement() {
    NSMutableArray *_measurementItems, *_netItems;
}

@end

@implementation RMBTMapMeasurement

- (instancetype)initWithResponse:(id)response {
    if (self = [super init]) {
        _coordinate = CLLocationCoordinate2DMake([response[@"lat"] doubleValue], [response[@"lon"] doubleValue]);
        _timeString = response[@"time_string"];
        _openTestUUID = response[@"open_test_uuid"];
        _measurementItems = [NSMutableArray array];
        for (id subresponse in response[@"measurement"]) {
            [_measurementItems addObject:[[RMBTHistoryResultItem alloc] initWithResponse:subresponse]];
        }
        _netItems = [NSMutableArray array];
        for (id subresponse in response[@"net"]) {
            [_netItems addObject:[[RMBTHistoryResultItem alloc] initWithResponse:subresponse]];
        }
    }
    return self;
}

- (NSString *)snippetText {
    NSMutableString *result = [NSMutableString string];
    
//    [result appendFormat:@"%@\n", _timeString];
    
    for (RMBTHistoryResultItem *i in _measurementItems) {
        [result appendFormat:@"%@: %@\n", i.title, i.value];
    }
    
    for (RMBTHistoryResultItem *i in _netItems) {
        [result appendFormat:@"%@: %@\n", i.title, i.value];
    }
    
    return result;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"RMBTMapMarker (%f, %f)", _coordinate.latitude, _coordinate.longitude];
}


@end
