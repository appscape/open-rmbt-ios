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

#import "RMBTMapServer.h"
#import "RMBTMapOptions.h"
#import "RMBTMapMeasurement.h"

#import <AFNetworking/AFHTTPClient.h>

NS_INLINE NSString *RMBTEscapeString(id input) {
    if (![input isKindOfClass:[NSString class]] && [input respondsToSelector:@selector(stringValue)]) input = [input stringValue];
    return (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(NULL, (__bridge CFStringRef)(input), NULL, (CFStringRef)@"!*'\"();:@&=+$,/?%#[]% ", kCFStringEncodingUTF8));
}

NSString *RMBTQueryStringFromDictionary(NSDictionary *input) {
    NSMutableArray *params = [NSMutableArray arrayWithCapacity:input.count];
    for (id key in [input allKeys])
        [params addObject:[NSString stringWithFormat:@"%@=%@", RMBTEscapeString(key), RMBTEscapeString(input[key])]];
    return [params componentsJoinedByString:@"&"];
}

@interface RMBTMapServer() {
    AFHTTPClient *_httpClient;
}
@end

@implementation RMBTMapServer

- (id)init {
    if (self = [super init]) {
        // Take over base URL from control server, but use /RMBTMapServer as path:
        NSURL *controlServerURL = [RMBTControlServer sharedControlServer].baseURL;
        NSURL *mapServerURL = [[controlServerURL URLByDeletingLastPathComponent] URLByAppendingPathComponent:@"RMBTMapServer"];
        _httpClient = [[AFHTTPClient alloc] initWithBaseURL:mapServerURL];
        _httpClient.parameterEncoding = AFJSONParameterEncoding;
    }
    return self;
}

- (void)getMapOptionsWithSuccess:(RMBTSuccessBlock)success {
    [self requestWithMethod:@"POST" path:@"tiles/info" params:nil success:^(id response) {
        RMBTMapOptions *mapOptions = [[RMBTMapOptions alloc] initWithResponse:response];
        success(mapOptions);
    } error:^(NSError *error, NSDictionary *info) {
        NSLog(@"Error %@ %@", error, info);
    }];
}

- (void)requestWithMethod:(NSString*)method
                     path:(NSString*)path
                   params:(NSDictionary*)params
                  success:(RMBTSuccessBlock)success
                    error:(RMBTErrorBlock)failure
{
    NSMutableDictionary *mergedParams = [NSMutableDictionary dictionaryWithDictionary:@{
        @"language": RMBTValueOrNull(RMBTPreferredLanguage())
    }];
    
    if (params) [mergedParams addEntriesFromDictionary:params];
    
    NSMutableURLRequest *request = [_httpClient requestWithMethod:method path:path parameters:mergedParams];
    
    AFJSONRequestOperation *operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:request success:^(id request, id response, id json) {
        success(json);
    } failure:^(id request, id response, NSError *error, id json) {
        failure(error, json);
    }];
    
    [_httpClient enqueueHTTPRequestOperation:operation];
}

- (NSURL*)tileURLForMapOverlayType:(NSString*)overlayType x:(NSUInteger)x y:(NSUInteger)y zoom:(NSUInteger)zoom params:(NSDictionary*)params {
    NSMutableString *urlString = [NSMutableString stringWithString:[_httpClient.baseURL absoluteString]];
    [urlString appendFormat:@"tiles/%@?path=%lu/%lu/%lu&", overlayType, (unsigned long)zoom, (unsigned long)x, (unsigned long)y];
    [urlString appendString:RMBTQueryStringFromDictionary(params)];
    
    NSString *uuid = [RMBTControlServer sharedControlServer].uuid;
    if (uuid) {
        [urlString appendFormat:@"&%@",RMBTQueryStringFromDictionary(@{@"highlight":uuid})];
    }
    
    return [NSURL URLWithString:urlString];
}

- (void)getMeasurementsAtCoordinate:(CLLocationCoordinate2D)coordinate zoom:(NSUInteger)zoom params:(NSDictionary*)params success:(RMBTSuccessBlock)success {

    RMBTLog(@"Getting measurements at coordinate %f,%f", coordinate.latitude, coordinate.longitude);
    
    NSMutableDictionary *finalParams = [NSMutableDictionary dictionaryWithDictionary:params];
    
    // Note: Android App has a hardcoded size of 20 with a todo notice "correct params (zoom, size)". We doubled the value for retina tiles.
    [finalParams addEntriesFromDictionary:@{
        @"coords": @{
             @"lat": [NSNumber numberWithDouble:coordinate.latitude],
             @"lon": [NSNumber numberWithDouble:coordinate.longitude],
             @"z": [NSNumber numberWithUnsignedInteger:zoom]
         },
         @"size": @"40"
    }];
    
    [self requestWithMethod:@"POST" path:@"tiles/markers" params:finalParams success:^(id response) {
        NSMutableArray *measurements = [NSMutableArray array];
        RMBTLog(@"Got %d measurements", measurements.count);
        for (id subresponse in response[@"measurements"]) {
            [measurements addObject:[[RMBTMapMeasurement alloc] initWithResponse:subresponse]];
        }
        success(measurements);
    } error:^(NSError *error, NSDictionary *info) {
        NSLog(@"Error %@ %@", error, info);
    }];
}

- (void)getURLStringForOpenTestUUID:(NSString*)openTestUUID success:(RMBTSuccessBlock)success {
    if (![RMBTControlServer sharedControlServer].openTestBaseURL) {
        [[RMBTControlServer sharedControlServer] getSettings:^{
            NSParameterAssert([RMBTControlServer sharedControlServer].openTestBaseURL);
            success([[RMBTControlServer sharedControlServer].openTestBaseURL stringByAppendingString:openTestUUID]);
        } error:^(NSError *error, NSDictionary *info) {
            //TODO: handle error
        }];
    } else {
        success([[RMBTControlServer sharedControlServer].openTestBaseURL stringByAppendingString:openTestUUID]);
    }
}

@end
