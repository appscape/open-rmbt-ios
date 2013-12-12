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

#import "GCNetworkReachability.h"
#import <CoreTelephony/CTTelephonyNetworkInfo.h>

#import "RMBTConnectivityTracker.h"

// GCNetworkReachability is not made to be multiply instantiated, so we create a global
// singleton first time a RMBTConnectivityTracker is instatiated
static GCNetworkReachability* sharedReachability;

// According to http://www.objc.io/issue-5/iOS7-hidden-gems-and-workarounds.html one should
// keep a reference to CTTelephonyNetworkInfo live if we want to receive radio changed notifications (?)
static CTTelephonyNetworkInfo *sharedNetworkInfo;

@interface RMBTConnectivityTracker() {
    __weak id<RMBTConnectivityTrackerDelegate> _delegate;
    dispatch_queue_t _queue;
    id _lastRadioAccessTechnology;
    RMBTConnectivity *_lastConnectivity;
    BOOL _stopOnMixed;
    BOOL _started;
}
@end

@implementation RMBTConnectivityTracker

- (instancetype)initWithDelegate:(id<RMBTConnectivityTrackerDelegate>)delegate stopOnMixed:(BOOL)stopOnMixed {
    if (self = [super init]) {
        _stopOnMixed = stopOnMixed;
        _delegate = delegate;
        _queue = dispatch_queue_create("at.rtr.rmbt.connectivitytracker", DISPATCH_QUEUE_SERIAL);
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            sharedReachability = [GCNetworkReachability reachabilityForInternetConnection];
            [sharedReachability startMonitoringNetworkReachabilityWithNotification];
            sharedNetworkInfo = [[CTTelephonyNetworkInfo alloc] init];
        });
    }
    return self;
}

- (void)appWillEnterForeground:(NSNotification*)notification {
    dispatch_async(_queue, ^{
        // Restart various observartions and force update (if already started)
        if (_started) [self start];
    });
}

- (void)start {
    dispatch_async(_queue, ^{
        _started = YES;
        _lastRadioAccessTechnology = nil;

        // Re-Register for notifications
        [[NSNotificationCenter defaultCenter] removeObserver:self];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityDidChange:) name:kGCNetworkReachabilityDidChangeNotification object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(radioDidChange:) name:CTRadioAccessTechnologyDidChangeNotification object:nil];

        [self reachabilityDidChangeToStatus:sharedReachability.currentReachabilityStatus];
    });
}

- (void)stop {
    dispatch_async(_queue, ^{
        [[NSNotificationCenter defaultCenter] removeObserver:self];
        _started = NO;
    });
}

- (void)forceUpdate {
    dispatch_async(_queue, ^{
        NSAssert(_lastConnectivity, @"Connectivity should be known by now");
        [_delegate connectivityTracker:self didDetectConnectivity:_lastConnectivity];
    });
}

- (void)reachabilityDidChange:(NSNotification*)n {
    GCNetworkReachabilityStatus status = [[n.userInfo objectForKey:kGCNetworkReachabilityStatusKey] integerValue];
    dispatch_async(_queue, ^{
        [self reachabilityDidChangeToStatus:status];
    });
}

- (void)radioDidChange:(NSNotification*)n {
    dispatch_async(_queue, ^{
        // Note:Sometimes iOS delivers multiple notification w/o radio technology actually changing
        if (n.object == _lastRadioAccessTechnology) return;
        _lastRadioAccessTechnology = n.object;
        [self reachabilityDidChangeToStatus:sharedReachability.currentReachabilityStatus];
    });
}

- (void)reachabilityDidChangeToStatus:(GCNetworkReachabilityStatus)status {
    RMBTNetworkType networkType;
    switch (status) {
        case GCNetworkReachabilityStatusNotReachable:
            networkType = RMBTNetworkTypeNone;
            break;
        case GCNetworkReachabilityStatusWiFi:
            networkType = RMBTNetworkTypeWiFi;
            break;
        case GCNetworkReachabilityStatusWWAN:
            networkType = RMBTNetworkTypeCellular;
            break;
        default:
            // No assert here because simulator often returns unknown connectivity status
            NSLog(@"Unknown reachability status %d", status);
            return;
    }

    if (networkType == RMBTNetworkTypeNone) {
        RMBTLog(@"No connectivity detected.");
        _lastConnectivity = nil;
        [_delegate connectivityTrackerDidDetectNoConnectivity:self];
        return;
    }

    RMBTConnectivity *connectivity = [[RMBTConnectivity alloc] initWithNetworkType:networkType];

    if ([connectivity isEqualToConnectivity:_lastConnectivity]) return;

    RMBTLog(@"New connectivity = %@", connectivity.testResultDictionary);

    if (_stopOnMixed) {
        // Detect compatilibity
        BOOL compatible = YES;

        if (_lastConnectivity) {
            if (connectivity.networkType != _lastConnectivity.networkType) {
                RMBTLog(@"Connectivity network mismatched %@ -> %@", _lastConnectivity.networkTypeDescription, connectivity.networkTypeDescription);
                compatible = NO;
            } else if (![connectivity.networkName isEqualToString:_lastConnectivity.networkName]) {
                RMBTLog(@"Connectivity network name mismatched %@ -> %@", _lastConnectivity.networkName, connectivity.networkName);
                compatible = NO;
            }
        }

        _lastConnectivity = connectivity;

        if (compatible) {
            [_delegate connectivityTracker:self didDetectConnectivity:connectivity];
        } else {
            // stop
            [self stop];
            [_delegate connectivityTracker:self didStopAndDetectIncompatibleConnectivity:connectivity];
        }
    } else {
        _lastConnectivity = connectivity;
        [_delegate connectivityTracker:self didDetectConnectivity:connectivity];
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
