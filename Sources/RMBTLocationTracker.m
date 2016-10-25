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

#import "RMBTLocationTracker.h"

NSString * const RMBTLocationTrackerNotification = @"RMBTLocationTrackerNotification";

@interface RMBTLocationTracker()<CLLocationManagerDelegate> {
    CLLocationManager *_locationManager;
    RMBTBlock _authorizationCallback;
    CLGeocoder *_geocoder;
}
@end

@implementation RMBTLocationTracker

+ (instancetype)sharedTracker {
    static id instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        _locationManager = [[CLLocationManager alloc] init];
        _locationManager.desiredAccuracy = kCLLocationAccuracyBest;
        _locationManager.distanceFilter = 3.0;
        _locationManager.delegate = self;
    }
    return self;
}

- (void)stop {
    [_locationManager stopMonitoringSignificantLocationChanges];
    [_locationManager stopUpdatingLocation];
}

- (BOOL)startIfAuthorized {
    if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusAuthorizedAlways ||
        [CLLocationManager authorizationStatus] == kCLAuthorizationStatusAuthorizedWhenInUse ) {
        [_locationManager startUpdatingLocation];
        return YES;
    } else {
        return NO;
    }
}

- (void)startAfterDeterminingAuthorizationStatus:(RMBTBlock)callback {
    if ([self startIfAuthorized]) {
        callback();
    } else if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusNotDetermined) {
        // Not determined yet
        _authorizationCallback = callback;
        if ([_locationManager respondsToSelector:@selector(requestWhenInUseAuthorization)]) {
            [_locationManager requestWhenInUseAuthorization];
        } else {
            [_locationManager startUpdatingLocation];
        }
    } else {
        RMBTLog(@"User hasn't enabled or authorized location services");
        // Location services was denied
        callback();
    }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    NSLog(@"Failed to obtain location: %@", error);
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
    [[NSNotificationCenter defaultCenter] postNotificationName:RMBTLocationTrackerNotification object:self userInfo:@{@"locations": locations}];
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    if ([_locationManager respondsToSelector:@selector(requestWhenInUseAuthorization)]) {
        [_locationManager startUpdatingLocation];
    }
    if (_authorizationCallback) _authorizationCallback();
}

- (void)forceUpdate {
    [self stop];
    [self startIfAuthorized];
}

- (CLLocation*)location {
    CLLocation* result = [_locationManager.location copy];
    if (!result || !CLLocationCoordinate2DIsValid(result.coordinate)) return nil;
    return result;
}

@end
