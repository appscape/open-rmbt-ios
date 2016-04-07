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

#import "RMBTLogger.h"
#import "RMBTSettings.h"
#import <CocoaAsyncSocket/GCDAsyncUdpSocket.h>

@interface RMBTLogger : NSObject {
    GCDAsyncUdpSocket *_udpSocket;
    dispatch_queue_t _delegate_queue;
}

@property (nonatomic, copy) NSString *destinationHostname;
@property (nonatomic, assign) NSUInteger destinationPort;
@end

@implementation RMBTLogger

- (instancetype)init {
    if (self = [super init]) {
        _delegate_queue = dispatch_queue_create("at.rtr.rmbt.loggerdelegate", NULL);
        _udpSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:_delegate_queue socketQueue:nil];
        NSError *error = nil;
        [_udpSocket enableBroadcast:YES error:&error];
        if (error) {
            NSLog(@"Error enabling UDP broadcast %@", error);
        }
    }
    return self;
}

- (void)broadcast:(NSString*)message {
    NSAssert(self.destinationHostname, @"UDP Logging destination host not set");
    NSAssert(self.destinationPort > 0, @"UDP Logging destination port not set");
    [_udpSocket sendData:[message dataUsingEncoding:NSASCIIStringEncoding] toHost:self.destinationHostname port:self.destinationPort withTimeout:-1 tag:0];
}

@end


void RMBTLog(NSString* format, ...) {
    static BOOL enabled = NO;

    static NSDateFormatter *_timestampFormatter = nil;
    static RMBTSettings *_sharedSettings = nil;
    static RMBTLogger *_sharedLogger = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        _sharedSettings = [RMBTSettings sharedSettings];
        if (_sharedSettings.debugUnlocked) {
            _timestampFormatter = [[NSDateFormatter alloc] init];
            [_timestampFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS"];
            
            _sharedLogger = [[RMBTLogger alloc] init];
            
            
            void (^announce)() = ^(void) {
                if (enabled) {
                    NSLog(@"Logging via UDP to %@:%lu", _sharedLogger.destinationHostname, (unsigned long)_sharedLogger.destinationPort);
                } else {
                    NSLog(@"Logging via UDP disabled.");
                }
            };
 
            // Observe settings
            
            // 1. enabled
            [_sharedSettings bk_addObserverForKeyPath:@keypath(_sharedSettings.debugLoggingEnabled) options:NSKeyValueObservingOptionInitial|NSKeyValueObservingOptionNew task:^(id obj, NSDictionary *change) {
                enabled = _sharedSettings.debugLoggingEnabled;
            }];
            
            // 2. hostname and port
            [_sharedSettings bk_addObserverForKeyPath:@keypath(_sharedSettings.debugLoggingHostname) options:NSKeyValueObservingOptionInitial|NSKeyValueObservingOptionNew task:^(id obj, NSDictionary *change) {
                NSString *hostname = _sharedSettings.debugLoggingHostname;
                if (!hostname) hostname = @"255.255.255.255";
                _sharedLogger.destinationHostname = hostname;
            }];

            // 3. port
            [_sharedSettings bk_addObserverForKeyPath:@keypath(_sharedSettings.debugLoggingHostname) options:NSKeyValueObservingOptionInitial|NSKeyValueObservingOptionNew task:^(id obj, NSDictionary *change) {
                NSUInteger port = _sharedSettings.debugLoggingPort;
                if (port == 0) port = 9000;
                _sharedLogger.destinationPort = port;
            }];
            
            announce();
        }
    });

#if DEBUG
#else
    if (!_sharedLogger || !enabled) return;
#endif
    
    va_list vl;
    va_start(vl, format);
    NSString* message = [[NSString alloc] initWithFormat:format arguments:vl];
    va_end(vl);
    
    NSLog(@"> %@", message);
    
    NSString *line = [NSString stringWithFormat:@"[%@] %@\n", [_timestampFormatter stringFromDate:[NSDate date]], message];
    
    [_sharedLogger broadcast:line];
}
