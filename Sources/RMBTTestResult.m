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

#import "RMBTTestResult.h"
#import "RMBTThroughputHistory.h"
#import "RMBTPing.h"

const int32_t RMBTTestResultSpeedNotAvailable = -1;
const int32_t RMBTTestResultSpeedMeasurementFinished = -2;

@interface RMBTTestResult() {
    NSMutableArray *_pings;

    NSMutableArray *_locations;
    NSMutableArray *_connectivities;
    NSMutableArray *_perThreadDownloadHistories, *_perThreadUploadHistories;
    NSMutableArray __weak *_currentHistories;
    
    RMBTThroughputHistory __weak *_totalCurrentHistory;

    NSInteger _maxFrozenPeriodIndex;
}

@end

@implementation RMBTTestResult

- (instancetype)initWithResolutionNanos:(uint64_t)nanos {
    if (self = [super init]) {
        _resolutionNanos = nanos;
        
        _locations = [NSMutableArray array];
        _connectivities = [NSMutableArray array];
        _pings = [NSMutableArray array];

        _totalDownloadHistory = [[RMBTThroughputHistory alloc] initWithResolutionNanos:nanos];
        _totalUploadHistory = [[RMBTThroughputHistory alloc] initWithResolutionNanos:nanos];

        _bestPingNanos = 0;
    }
    return self;
}

- (void)addPingWithServerNanos:(uint64_t)serverNanos clientNanos:(uint64_t)clientNanos {
    RMBTPing *p = [[RMBTPing alloc] initWithServerNanos:serverNanos clientNanos:clientNanos];
    [_pings addObject:p];

    if (_bestPingNanos == 0 || _bestPingNanos > serverNanos) _bestPingNanos = serverNanos;
    if (_bestPingNanos > clientNanos) _bestPingNanos = clientNanos;
}

- (NSArray*)addLength:(uint64_t)length atNanos:(uint64_t)ns forThreadIndex:(NSUInteger)threadIndex {
    NSAssert(threadIndex >= 0 && threadIndex < _threadCount, @"Invalid thread index");

    RMBTThroughputHistory *h = [_currentHistories objectAtIndex:threadIndex];
    [h addLength:length atNanos:ns];

    //TODO: optimize calling updateTotalHistory only when certain preconditions are met
    
    return [self updateTotalHistory];
}

// Returns array of throughputs in intervals for which all threads have reported speed
- (NSArray*)updateTotalHistory {
    NSInteger commonFrozenPeriodIndex = NSIntegerMax;
    
    for (RMBTThroughputHistory *h in _currentHistories) {
        commonFrozenPeriodIndex = MIN(commonFrozenPeriodIndex, h.lastFrozenPeriodIndex);
    }

    //TODO: assert ==
    if (commonFrozenPeriodIndex == NSIntegerMax || commonFrozenPeriodIndex <= _maxFrozenPeriodIndex) return nil;

    for (NSInteger i = _maxFrozenPeriodIndex+1; i<=commonFrozenPeriodIndex; i++) {
        if (i == commonFrozenPeriodIndex && [[_currentHistories objectAtIndex:0] isFrozen]) {
            // We're adding up the last throughput, clip totals according to spec
            // 1) find t*
            uint64_t minEndNanos = 0;
            uint64_t minPeriodIndex = 0;
            for (NSUInteger threadIndex = 0; threadIndex<_threadCount; threadIndex++) {
                RMBTThroughputHistory *threadHistory = [_currentHistories objectAtIndex:threadIndex];
                NSAssert(threadHistory.isFrozen, nil);
                
                NSInteger threadLastFrozenPeriodIndex = [threadHistory lastFrozenPeriodIndex];
                
                RMBTThroughput *threadLastTput = [[threadHistory periods] objectAtIndex:threadLastFrozenPeriodIndex];
                if (minEndNanos == 0 || threadLastTput.endNanos < minEndNanos) {
                    minEndNanos = threadLastTput.endNanos;
                    minPeriodIndex = threadLastFrozenPeriodIndex;
                }
            }
            
            // 2) Add up bytes in proportion to t*
            uint64_t length = 0;
            for (NSUInteger threadIndex = 0; threadIndex<_threadCount; threadIndex++) {
                RMBTThroughput *threadLastTput = [[[_currentHistories objectAtIndex:threadIndex] periods] objectAtIndex:minPeriodIndex];
                // Factor = (t*-t(k,m-1)/t(k,m)-t(k,m-1))
                double factor = (double)(minEndNanos - threadLastTput.startNanos) / (threadLastTput.durationNanos);
                NSAssert(factor >= 0.0 && factor <= 1.0, @"Invalid factor");
                length += factor * threadLastTput.length;
            }
            [_totalCurrentHistory addLength:length atNanos:minEndNanos];
        } else {
            uint64_t length = 0;
            for (NSUInteger threadIndex = 0; threadIndex<_threadCount; threadIndex++) {
                RMBTThroughput *tt = ((RMBTThroughputHistory*)[_currentHistories objectAtIndex:threadIndex]).periods[i];
                length += tt.length;
                NSAssert(_totalCurrentHistory.totalThroughput.endNanos == tt.startNanos, @"Period start time mismatch");
            }
            [_totalCurrentHistory addLength:length atNanos:(i+1)*_resolutionNanos];
        }
    }

    NSArray *result = [_totalCurrentHistory.periods subarrayWithRange:NSMakeRange(_maxFrozenPeriodIndex+1, commonFrozenPeriodIndex-_maxFrozenPeriodIndex)];
    _maxFrozenPeriodIndex = commonFrozenPeriodIndex;
    return result;
}

//- (int32_t)speedAtTimeInterval:(NSTimeInterval)t {
//    uint64_t nanos = ((uint64_t)(t * NSEC_PER_SEC));
//
//    if (_totalCurrentHistory.isFrozen && nanos > _totalCurrentHistory.totalThroughput.endNanos) {
//        return RMBTTestResultSpeedMeasurementFinished; // We've reached the end
//    }
//
//    NSUInteger periodIndex = nanos / _resolutionNanos;
//    
//    if (nanos % _resolutionNanos == 0) {
//        // Round intervals belong to lower period
//        if (periodIndex>0) periodIndex -= 1;
//    }
//    
//    NSAssert(periodIndex>=0, nil);
//    
//    if(periodIndex >= _totalCurrentHistory.periods.count) {
//        // Not known yet
//        if (!_totalCurrentHistory.isFrozen) {
//            return RMBTTestResultSpeedNotAvailable;
//        } else {
//            // Probably dealing with squashed period
//            periodIndex = [_totalCurrentHistory.periods count]-1;
//            NSAssert([_totalCurrentHistory.periods[periodIndex] durationNanos] != _resolutionNanos, nil);
//        }
//    }
//    
//    // First chunk has no predecessor
//    if (periodIndex == 0) {
//        return [_totalCurrentHistory.periods[periodIndex] kilobitsPerSecond];
//    } else {
//        int32_t speedAtStart = [_totalCurrentHistory.periods[periodIndex-1] kilobitsPerSecond];
//        int32_t speedAtEnd = [_totalCurrentHistory.periods[periodIndex] kilobitsPerSecond];
//        
//        double k = (double)(nanos - periodIndex * _resolutionNanos)/[_totalCurrentHistory.periods[periodIndex] durationNanos];
//        
//        return speedAtStart + k * (speedAtEnd - speedAtStart);
//    }
//}

- (NSArray*)flush {
    NSArray* result;

    for (RMBTThroughputHistory* h in _currentHistories) {
        [h freeze];
    }

    result = [self updateTotalHistory];
    [_totalCurrentHistory freeze];
    
    NSUInteger totalPeriodCount = [[_totalCurrentHistory periods] count];
    
    [_totalCurrentHistory squashLastPeriods:1];

    // Squash last two periods in all histories
    for (RMBTThroughputHistory* h in _currentHistories) {
        [h squashLastPeriods:1+([[h periods] count]-totalPeriodCount)];
    }

    // Remove last measurement from result, as we don't want to plot that one as it's usually too short
    if (result.count > 0) {
        result = [result subarrayWithRange:NSMakeRange(0, result.count-1)];
    }
    return result;
}

- (void)startDownloadWithThreadCount:(NSUInteger)threadCount {
    _threadCount = threadCount;
    _perThreadDownloadHistories = [NSMutableArray arrayWithCapacity:threadCount];
    _perThreadUploadHistories = [NSMutableArray arrayWithCapacity:threadCount];
    
    for (NSUInteger i=0;i<threadCount;i++) {
        [_perThreadDownloadHistories addObject:[[RMBTThroughputHistory alloc] initWithResolutionNanos:_resolutionNanos]];
        [_perThreadUploadHistories addObject:[[RMBTThroughputHistory alloc] initWithResolutionNanos:_resolutionNanos]];
    }
    
    _totalCurrentHistory = _totalDownloadHistory;
    _currentHistories = _perThreadDownloadHistories;
    
    _maxFrozenPeriodIndex = -1;
}

- (void)startUpload {
    _totalCurrentHistory = _totalUploadHistory;
    _currentHistories = _perThreadUploadHistories;
    _maxFrozenPeriodIndex = -1;
}

- (void)addLocation:(CLLocation*)location {
    [_locations addObject:location];
}

- (void)addConnectivity:(RMBTConnectivity*)connectivity {
    [_connectivities addObject:connectivity];
}

- (RMBTConnectivity*)lastConnectivity {
    return [_connectivities lastObject];
}

#pragma mark - Result dictionary

- (NSDictionary*)resultDictionary {
    NSMutableArray *pings = [NSMutableArray array];

    for (RMBTPing* p in _pings) {
        [pings addObject:[p testResultDictionary]];
    }

    NSMutableArray *speedDetails = [NSMutableArray array];

    [speedDetails addObjectsFromArray:[self subresultForThreadThroughputs:self.perThreadDownloadHistories withDirectionString:@"download"]];
    [speedDetails addObjectsFromArray:[self subresultForThreadThroughputs:self.perThreadUploadHistories withDirectionString:@"upload"]];

    NSMutableDictionary *result = [NSMutableDictionary dictionaryWithDictionary:@{
        @"test_ping_shortest": [NSNumber numberWithUnsignedLongLong:_bestPingNanos],
        @"pings": pings,
        @"speed_detail": speedDetails,
        @"test_num_threads": [NSNumber numberWithUnsignedInteger:_threadCount],
    }];

    [result addEntriesFromDictionary:[self subresultForTotalThroughput:self.totalDownloadHistory.totalThroughput withDirectionString:@"download"]];
    [result addEntriesFromDictionary:[self subresultForTotalThroughput:self.totalUploadHistory.totalThroughput withDirectionString:@"upload"]];
    [result addEntriesFromDictionary:[self locationsResultDictionary]];
    [result addEntriesFromDictionary:[self connectivitiesResultDictionary]];

    return result;
}

- (NSArray*)subresultForThreadThroughputs:(NSArray*)perThreadArray
                      withDirectionString:(NSString*)directionString
{
    NSMutableArray *result = [NSMutableArray array];
    for (NSUInteger i = 0; i<perThreadArray.count; i++) {
        RMBTThroughputHistory *h = [perThreadArray objectAtIndex:i];
        uint64_t totalLength = 0;
        for (RMBTThroughput *t in h.periods) {
            totalLength += t.length;
            [result addObject:@{
                                @"direction": directionString,
                                @"thread": [NSNumber numberWithUnsignedInteger:i],
                                @"time": [NSNumber numberWithUnsignedLongLong:t.endNanos],
                                @"bytes": [NSNumber numberWithUnsignedLongLong:totalLength]
                                }];
        }
    }
    return result;
}

- (NSDictionary*)subresultForTotalThroughput:(RMBTThroughput*)throughput
                         withDirectionString:(NSString*)directionString
{
    return @{
             [NSString stringWithFormat:@"test_speed_%@", directionString]:
                 [NSNumber numberWithUnsignedLong:throughput.kilobitsPerSecond],
             [NSString stringWithFormat:@"test_nsec_%@", directionString]:
                 [NSNumber numberWithUnsignedLongLong: throughput.endNanos],
             [NSString stringWithFormat:@"test_bytes_%@", directionString]:
                 [NSNumber numberWithUnsignedLongLong: throughput.length]
             };
}

- (NSDictionary*)locationsResultDictionary {
    NSMutableArray *result = [NSMutableArray array];
    for (CLLocation* l in _locations) {
        [result addObject:@{
           @"geo_long": [NSNumber numberWithDouble:l.coordinate.longitude],
           @"geo_lat":  [NSNumber numberWithDouble:l.coordinate.latitude],
           @"tstamp":   [NSNumber numberWithUnsignedLongLong:(unsigned long long)([l.timestamp timeIntervalSince1970] * 1000ul)],
           @"accuracy": [NSNumber numberWithDouble:l.horizontalAccuracy],
           @"altitude": [NSNumber numberWithDouble:l.altitude],
           @"speed": [NSNumber numberWithDouble:(l.speed > 0.0 ? l.speed : 0.0)]
         }];
    }
    return @{@"geoLocations": result};
}

- (NSDictionary*)connectivitiesResultDictionary {
    NSMutableDictionary* result;
    NSMutableArray* signals = [NSMutableArray array];
    for (RMBTConnectivity* c in _connectivities) {
        NSDictionary *cResult = c.testResultDictionary;

        [signals addObject:@{@"time":RMBTTimestampWithNSDate(c.timestamp), @"network_type_id": cResult[@"network_type"]}];

        if (!result) {
            result = [NSMutableDictionary dictionaryWithDictionary:cResult];
        } else {
            NSInteger previousNetworkType = [result[@"network_type"] integerValue];
            NSInteger currentNetworkType = [cResult[@"network_type"] integerValue];
            // Take maximum network type
            result[@"network_type"] = [NSNumber numberWithInteger:MAX(previousNetworkType, currentNetworkType)];
        }
    }
    result[@"signals"] = signals;
    return result;
}

@end
