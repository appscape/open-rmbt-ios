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

#import <CocoaAsyncSocket/GCDAsyncSocket.h>

#import "RMBTTestWorker.h"
#import "RMBTSSLHelper.h"

typedef enum {
    RMBTTestWorkerStateInitialized,

    RMBTTestWorkerStateDownlinkPretestStarted,
    RMBTTestWorkerStateDownlinkPretestFinished,

    RMBTTestWorkerStateLatencyTestStarted,
    RMBTTestWorkerStateLatencyTestFinished,

    RMBTTestWorkerStateDownlinkTestStarted,
    RMBTTestWorkerStateDownlinkTestFinished,

    RMBTTestWorkerStateUplinkPretestStarted,
    RMBTTestWorkerStateUplinkPretestFinished,

    RMBTTestWorkerStateUplinkTestStarted,
    RMBTTestWorkerStateUplinkTestFinished,

    RMBTTestWorkerStateStopping,
    RMBTTestWorkerStateStopped,

    RMBTTestWorkerStateAborted,
    RMBTTestWorkerStateFailed
} RMBTTestWorkerState;

// We use long to be compatible with GCDAsyncSocket tag datatype
typedef NS_ENUM(long, RMBTTestTag) {
    RMBTTestTagRxPretestPart = -2,
    RMBTTestTagRxDownlinkPart = -1,

    RMBTTestTagRxBanner = 1,
    RMBTTestTagRxBannerAccept,
    RMBTTestTagTxUpgrade,
    RMBTTestTagRxUpgradeResponse,
    RMBTTestTagTxToken,
    RMBTTestTagRxTokenOK,
    RMBTTestTagRxChunksize,
    RMBTTestTagRxChunksizeAccept,
    RMBTTestTagTxGetChunks,
    RMBTTestTagRxChunk,
    RMBTTestTagTxChunkOK,
    RMBTTestTagRxStatistic,
    RMBTTestTagRxStatisticAccept,
    RMBTTestTagTxPing,
    RMBTTestTagRxPong,
    RMBTTestTagTxPongOK,
    RMBTTestTagRxPongStatistic,
    RMBTTestTagRxPongAccept,
    RMBTTestTagTxGetTime,
    RMBTTestTagRxGetTime,
    RMBTTestTagRxGetTimeLeftoverChunk,
    RMBTTestTagTxGetTimeOK,
    RMBTTestTagRxGetTimeStatistic,
    RMBTTestTagRxGetTimeAccept,
    RMBTTestTagTxQuit,
    RMBTTestTagTxPutNoResult,
    RMBTTestTagRxPutNoResultOK,
    RMBTTestTagTxPutNoResultChunk,
    RMBTTestTagRxPutNoResultStatistic,
    RMBTTestTagRxPutNoResultAccept,
    RMBTTestTagTxPut,
    RMBTTestTagRxPutOK,
    RMBTTestTagTxPutChunk,
    RMBTTestTagRxPutStatistic,
    RMBTTestTagRxPutStatisticLast
};

@interface RMBTTestWorker()<GCDAsyncSocketDelegate> {
    RMBTTestParams *_params; // Test parameters
    __weak id<RMBTTestWorkerDelegate> _delegate; // Weak reference to the delegate
    RMBTTestWorkerState _state; // Current state of the worker
    GCDAsyncSocket* _socket;

    NSUInteger      _chunksize; // CHUNKSIZE received from server
    NSMutableData*  _chunkData; // One chunk of data cached from the downlink phase, to be used as upload data

    // In pretest, we first request or send 1 chunk at once, then 2, 4, 8 etc.
    NSUInteger      _pretestChunksCount;    // Number of chunks to request/send in this iteration
    NSUInteger      _pretestChunksSent;     // Uplink pretest: number of chunks sent so far in this iteration
    uint64_t        _pretestLengthReceived; // Download pretest: length received so far
    uint64_t        _pretestStartNanos;     // Nanoseconds at which we started pretest

    uint64_t        _pingStartNanos;        // Nanoseconds at which we sent the PING
    uint64_t        _pingPongNanos;         // Nanoseconds at which we received PONG
    NSUInteger      _pingSeq;               // Current ping sequence number (0.._params.pingCount-1)

    uint64_t        _testStartNanos;        // Nanoseconds at which test started. Used for both up/down tests.
    NSMutableData*  _testDownloadedData;    // Download buffer for capturing bytes for _chunkData

    uint64_t        _testUploadOffsetNanos; // How many nanoseconds is this thread behind the first thread that started upload test

    // Local timestamps after which we'll start discarding server reports and finalize the upload test
    uint64_t        _testUploadEnoughClientNanos;
    uint64_t        _testUploadMaxWaitReachedClientNanos;

    // Server timestamp after which it is considered that we have enough upload
    uint64_t        _testUploadEnoughServerNanos;

    // Flag indicating that last uplink packet has been sent. After last chunk has been sent, we'll wait upto X sec to
    // collect statistics, then terminate the test.
    BOOL            _testUploadLastChunkSent;

    // Server reports total number of bytes received. We need to track last amount reported so we can calculate relative amounts.
    long long       _testUploadLastUploadLength;

    uint            _hostLookupRetries;
}
@end

@implementation RMBTTestWorker

- (id)initWithDelegate:(id<RMBTTestWorkerDelegate>)delegate delegateQueue:(dispatch_queue_t)delegateQueue index:(NSUInteger)index testParams:(RMBTTestParams*)params {
    if (self = [super init]) {
        _delegate = delegate;
        _index = index;
        _params = params;

        _state = RMBTTestWorkerStateInitialized;
        _socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:delegateQueue socketQueue:nil];
    }
    return self;
}

#pragma mark - State handling

- (void)startDownlinkPretest {
    NSAssert(_state == RMBTTestWorkerStateInitialized, @"Invalid state");
    _state = RMBTTestWorkerStateDownlinkPretestStarted;

    [self connect];
}

- (void)stop {
    NSAssert(_state == RMBTTestWorkerStateDownlinkPretestFinished, @"Invalid state");
    _state = RMBTTestWorkerStateStopping;

    [_socket disconnect];
}

- (void)startLatencyTest {
    NSAssert(_state == RMBTTestWorkerStateDownlinkPretestFinished, @"Invalid state");
    _state = RMBTTestWorkerStateLatencyTestStarted;

    _pingSeq = 0;
    [self writeLine:@"PING" withTag:RMBTTestTagTxPing];

    _pingStartNanos = RMBTCurrentNanos();
}

- (void)startDownlinkTest {
    NSAssert(_state == RMBTTestWorkerStateLatencyTestFinished || _state == RMBTTestWorkerStateDownlinkPretestFinished, @"Invalid state");
    _state = RMBTTestWorkerStateDownlinkTestStarted;

    [self writeLine:[NSString stringWithFormat:@"GETTIME %d", (int)_params.testDuration] withTag:RMBTTestTagTxGetTime];
}


- (void)startUplinkPretest {
    NSAssert(_state == RMBTTestWorkerStateDownlinkTestFinished, @"Invalid state");
    _state = RMBTTestWorkerStateUplinkPretestStarted;

    [self connect];
}

- (void)startUplinkTest {
    NSAssert(_state == RMBTTestWorkerStateUplinkPretestFinished, @"Invalid state");
    _state = RMBTTestWorkerStateUplinkTestStarted;

    [self writeLine:@"PUT" withTag:RMBTTestTagTxPut];
}

- (void)connect {
    NSError *error;
    [_socket connectToHost:_params.serverAddress onPort:_params.serverPort withTimeout:RMBT_TEST_SOCKET_TIMEOUT_S error:&error];
}


- (void)abort {
    _state = RMBTTestWorkerStateAborted;
    if (_socket.isConnected) [_socket disconnect];
}

- (void)fail {
    if (_state == RMBTTestWorkerStateAborted) return; // already aborted
    _state = RMBTTestWorkerStateFailed;
    [_delegate testWorkerDidFail:self];

    if (_socket.isConnected) [_socket disconnect];
}

- (void)start {
    if (_params.serverIsRmbtHTTP) {
        // Send upgrade string as part of the new protcol
        NSString *line = @"GET /rmbt HTTP/1.1\r\nConnection: Upgrade\r\nUpgrade: RMBT\r\nRMBT-Version: 1.2.0@\r\n\r\n";
        [self writeLine:line withTag:RMBTTestTagTxUpgrade];
    } else {
        [self readLineWithTag:RMBTTestTagRxBanner];
    }
}

#pragma mark - Socket delegate methods

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port {
    if (_state == RMBTTestWorkerStateAborted) {
        [sock disconnect];
        return;
    }

    NSAssert(_state == RMBTTestWorkerStateDownlinkPretestStarted || _state == RMBTTestWorkerStateUplinkPretestStarted, @"Invalid state");

    _localIp = sock.localHost;
    _serverIp = sock.connectedHost;

    if (_params.serverEncryption) {
        [sock startTLS:@{
            //GCDAsyncSocketSSLCipherSuites: @[[NSNumber numberWithShort:RMBT_TEST_CIPHER]]
        }];
    } else {
        [self start];
    }
}

- (BOOL)socketShouldManuallyEvaluateTrust:(GCDAsyncSocket *)sock {
    return YES;
}

- (BOOL)socket:(GCDAsyncSocket *)sock shouldTrustPeer:(SecTrustRef)trust {
    return YES;
}

- (void)socketDidSecure:(GCDAsyncSocket *)sock {
    NSAssert(_state == RMBTTestWorkerStateDownlinkPretestStarted || _state == RMBTTestWorkerStateUplinkPretestStarted, @"Invalid state");

    [_socket performBlock:^{
        _negotiatedEncryptionString = [RMBTSSLHelper encryptionStringForSSLContext:sock.sslContext];
    }];

    RMBTLog(@"Thread %lu: connected and secured.", (long)_index);

    [self start];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    if (err) {
        RMBTLog(@"Socket disconnected with error %@", err);
        // See https://github.com/robbiehanson/CocoaAsyncSocket/issues/382
        if ([err.domain isEqualToString:@"kCFStreamErrorDomainNetDB"] && _hostLookupRetries++ < RMBT_TEST_HOST_LOOKUP_RETRIES) {
            RMBTLog(@"Thread %ld retrying lookup (%ld/%ld)", (long)_index, (long)_hostLookupRetries, RMBT_TEST_HOST_LOOKUP_RETRIES);
            usleep(RMBT_TEST_HOST_LOOKUP_WAIT_S * USEC_PER_SEC);
            [self connect];
        } else {
            [self fail];
        }
    } else {
        if (_state == RMBTTestWorkerStateDownlinkTestStarted) {
            _state = RMBTTestWorkerStateDownlinkTestFinished;
            [_delegate testWorkerDidFinishDownlinkTest:self];
        } else if (_state == RMBTTestWorkerStateStopping) {
            _state = RMBTTestWorkerStateStopped;
            [_delegate testWorkerDidStop:self];
        } else if (_state == RMBTTestWorkerStateFailed || _state == RMBTTestWorkerStateAborted || _state == RMBTTestWorkerStateUplinkTestFinished) {
            // We've finished/aborted/failed and socket has disconnected. Nothing to do!
        } else {
            NSAssert(false, @"Disconnection in an unexpected state");
        }
    }
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag {
    if (_state == RMBTTestWorkerStateAborted) return; // Ignore
    [self socketDidReadOrWriteData:nil withTag:tag read:NO];
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    if (_state == RMBTTestWorkerStateAborted) return;
    _totalBytesDownloaded += data.length;
    [self socketDidReadOrWriteData:data withTag:tag read:YES];
}

// We unify read and write callbacks for better state documentation
- (void)socketDidReadOrWriteData:(NSData*)data withTag:(long)tag read:(BOOL)read {
    // Pretest
    if (tag == RMBTTestTagTxUpgrade) {
        // -> ...Upgrade..
        [_socket readDataToData:[@"Upgrade: RMBT\n" dataUsingEncoding:NSASCIIStringEncoding]
                    withTimeout:RMBT_TEST_SOCKET_TIMEOUT_S
                            tag:RMBTTestTagRxUpgradeResponse];
    } else if (tag == RMBTTestTagRxUpgradeResponse) {
        // <- HTTP/1.1 101 Switching Protocols\r\nConnection: Upgrade\r\nUpgrade: RMBT\r\n\r\n
        // Upgraded. Proceed to read banner:
        [self readLineWithTag:RMBTTestTagRxBanner];
    } else if (tag == RMBTTestTagRxBanner) {
        // <- RMBTv0.3
        [self readLineWithTag:RMBTTestTagRxBannerAccept];
    } else if (tag == RMBTTestTagRxBannerAccept) {
        // <- ACCEPT
        [self writeLine:[NSString stringWithFormat:@"TOKEN %@", _params.testToken] withTag:RMBTTestTagTxToken];
    } else if (tag == RMBTTestTagTxToken) {
        // -> TOKEN ...
        [self readLineWithTag:RMBTTestTagRxTokenOK];
    } else if (tag == RMBTTestTagRxTokenOK) {
        // <- OK
        [self readLineWithTag:RMBTTestTagRxChunksize];
    } else if (tag == RMBTTestTagRxChunksize) {
        // <- CHUNKSIZE
        int scannedChunkSize = 0;
        NSString *line = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
        NSScanner *scanner = [NSScanner scannerWithString:line];

        if (![scanner scanString:@"CHUNKSIZE" intoString:NULL]) {
            NSAssert(false, @"Didn't get CHUNKSIZE");
        };
        if (![scanner scanInt:&scannedChunkSize]) {
            NSAssert(false, @"Didn't get int value for chunksize");
        }
        NSAssert(scannedChunkSize > 0, @"Invalid chunksize");
        _chunksize = (NSUInteger)scannedChunkSize;

        [self readLineWithTag:RMBTTestTagRxChunksizeAccept];
    } else if (tag == RMBTTestTagRxChunksizeAccept) {
        // <- ACCEPT ...
        if (_state == RMBTTestWorkerStateDownlinkPretestStarted) {
            _pretestChunksCount = 1;
            [self writeLine:@"GETCHUNKS 1" withTag:RMBTTestTagTxGetChunks];
        } else if (_state == RMBTTestWorkerStateUplinkPretestStarted) {
            _pretestChunksCount = 1;
            [self writeLine:@"PUTNORESULT" withTag:RMBTTestTagTxPutNoResult];
        } else {
            NSAssert(false, @"Invalid state");
        }
    } else if (tag == RMBTTestTagTxGetChunks) {
        // -> GETCHUNKS X
        if (_pretestChunksCount == 1) _pretestStartNanos = RMBTCurrentNanos();
        _pretestLengthReceived = 0;
        [_socket readDataWithTimeout:RMBT_TEST_SOCKET_TIMEOUT_S tag:RMBTTestTagRxPretestPart];
    } else if (tag == RMBTTestTagRxPretestPart) {
        _pretestLengthReceived += data.length;
        if (_pretestLengthReceived >= _pretestChunksCount * _chunksize) {
            NSAssert(_pretestLengthReceived == _pretestChunksCount * _chunksize, @"Received more than expected");
            [self writeLine:@"OK" withTag:RMBTTestTagTxChunkOK];
        } else {
            // Read more
            [_socket readDataWithTimeout:RMBT_TEST_SOCKET_TIMEOUT_S tag:RMBTTestTagRxPretestPart];
        }
    } else if (tag == RMBTTestTagTxChunkOK) {
        // -> OK
        [self readLineWithTag:RMBTTestTagRxStatistic];
    } else if (tag == RMBTTestTagRxStatistic) {
        // <- STATISTIC
        [self readLineWithTag:RMBTTestTagRxStatisticAccept];
    } else if (tag == RMBTTestTagRxStatisticAccept) {
        // <- ACCEPT ...

        // Did we run out of time?
        if (RMBTCurrentNanos() - _pretestStartNanos >= (_params.pretestDuration * NSEC_PER_SEC)) {
            _state = RMBTTestWorkerStateDownlinkPretestFinished;
            [_delegate testWorker:self didFinishDownlinkPretestWithChunkCount:_pretestChunksCount];
        } else {
            // ..no, get more chunks
            _pretestChunksCount *= 2;
            // -> GETCHUNKS *2
            [self writeLine:[NSString stringWithFormat:@"GETCHUNKS %lu",(unsigned long)_pretestChunksCount] withTag:RMBTTestTagTxGetChunks];
        }
    }

    // Latency test
    else if (tag == RMBTTestTagTxPing) {
        // -> PING
        _pingSeq++;
        RMBTLog(@"Ping packet sent (delta = %" PRIu64 ")", RMBTCurrentNanos() - _pingStartNanos);
        [self readLineWithTag:RMBTTestTagRxPong];
    } else if (tag == RMBTTestTagRxPong) {
        _pingPongNanos = RMBTCurrentNanos();
        // <- PONG
        [self writeLine:@"OK" withTag:RMBTTestTagTxPongOK];
    } else if (tag == RMBTTestTagTxPongOK) {
        // -> OK
        [self readLineWithTag:RMBTTestTagRxPongStatistic];
    } else if (tag == RMBTTestTagRxPongStatistic) {
        // <- TIME
        long long ns = -1;

        NSString *line = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
        NSScanner *scanner = [NSScanner scannerWithString:line];
        if (![scanner scanString:@"TIME" intoString:NULL]) {
            NSAssert1(false, @"Didn't get TIME statistic -> %@", line);
        };

        if (![scanner scanLongLong:&ns]) {
            NSAssert(false, @"Didn't get long value for latency");
        }
        NSAssert(ns > 0, @"Invalid latency time");

        [_delegate testWorker:self didMeasureLatencyWithServerNanos:(uint64_t)ns clientNanos:_pingPongNanos-_pingStartNanos];

        [self readLineWithTag:RMBTTestTagRxPongAccept];
    } else if (tag == RMBTTestTagRxPongAccept) {
        // <- ACCEPT
        NSAssert(_pingSeq <= _params.pingCount, @"Invalid ping count");
        if (_pingSeq == _params.pingCount) {
            _state = RMBTTestWorkerStateLatencyTestFinished;
            [_delegate testWorkerDidFinishLatencyTest:self];
        } else {
            // Send PING again
            [self writeLine:@"PING" withTag:RMBTTestTagTxPing];
            _pingStartNanos = RMBTCurrentNanos();
        }
    }

    // Downlink test
    else if (tag == RMBTTestTagTxGetTime) {
        // -> GETTIME (duration)
        _testDownloadedData = [NSMutableData dataWithCapacity:_chunksize];
        [_socket readDataWithTimeout:RMBT_TEST_SOCKET_TIMEOUT_S tag:RMBTTestTagRxDownlinkPart];

        // We want to align starting times of all threads, so allow delegate to supply us a start timestamp
        // (usually from the first thread that reached this point)
        _testStartNanos = [_delegate testWorker:self didStartDownlinkTestAtNanos:RMBTCurrentNanos()];
    } else if (tag == RMBTTestTagRxDownlinkPart) {
        uint64_t elapsedNanos = RMBTCurrentNanos() - _testStartNanos;
        BOOL finished = (elapsedNanos >= _params.testDuration * NSEC_PER_SEC);
        
        if (!_chunkData) {
            // We still need to fill up one chunk for transmission in upload test
            [_testDownloadedData appendData:data];
            if (_testDownloadedData.length >= _chunksize) {
                _chunkData = [NSMutableData dataWithData:[_testDownloadedData subdataWithRange:NSMakeRange(0, _chunksize)]];
            }
        } // else discard the received data

        [_delegate testWorker:self didDownloadLength:data.length atNanos:elapsedNanos];
        
        if (finished) {
            [_socket disconnect];
        } else {
            // Request more
            [_socket readDataWithTimeout:RMBT_TEST_SOCKET_TIMEOUT_S tag:RMBTTestTagRxDownlinkPart];
        }
    }
// We always abruptly disconnect after test duration has passed, so following is not really used
//    } else if (tag == RMBTTestTagTxGetTimeOK) {
//        // -> OK
//        [self readLineWithTag:RMBTTestTagRxGetTimeStatistic];
//    } else if (tag == RMBTTestTagRxGetTimeStatistic) {
//        // <- TIME ...
//        [self readLineWithTag:RMBTTestTagRxGetTimeAccept];
//    } else if (tag == RMBTTestTagRxGetTimeAccept) {
//        // -> QUIT
//        [self writeLine:@"QUIT" withTag:RMBTTestTagTxQuit];
//        [_socket disconnectAfterWriting];
//    }

    // Uplink pretest

    else if (tag == RMBTTestTagTxPutNoResult) {
        [self readLineWithTag:RMBTTestTagRxPutNoResultOK];
    } else if (tag == RMBTTestTagRxPutNoResultOK) {
        if (_pretestChunksCount == 1) _pretestStartNanos = RMBTCurrentNanos();
        _pretestChunksSent = 0;

        [self updateLastChunkFlagToValue:(_pretestChunksCount==1)];
        
        [self writeData:_chunkData withTag:RMBTTestTagTxPutNoResultChunk];
    } else if (tag == RMBTTestTagTxPutNoResultChunk) {
        _pretestChunksSent++;
        NSAssert(_pretestChunksSent <= _pretestChunksCount, nil);
        if (_pretestChunksSent == _pretestChunksCount) {
            [self readLineWithTag:RMBTTestTagRxPutNoResultStatistic];
        } else {
            [self updateLastChunkFlagToValue:(_pretestChunksSent == (_pretestChunksCount - 1))];
            [self writeData:_chunkData withTag:RMBTTestTagTxPutNoResultChunk];
        }
    } else if (tag == RMBTTestTagRxPutNoResultStatistic) {
        [self readLineWithTag:RMBTTestTagRxPutNoResultAccept];
    } else if (tag == RMBTTestTagRxPutNoResultAccept) {
        if (RMBTCurrentNanos() - _pretestStartNanos >= (_params.pretestDuration * NSEC_PER_SEC)) {
            _state = RMBTTestWorkerStateUplinkPretestFinished;
            [_delegate testWorker:self didFinishUplinkPretestWithChunkCount:_pretestChunksCount];
        } else {
            _pretestChunksCount *= 2;
            [self writeLine:@"PUTNORESULT" withTag:RMBTTestTagTxPutNoResult];
        }
    }

    // Uplink test
    else if (tag == RMBTTestTagTxPut) {
        // -> PUT
        [self readLineWithTag:RMBTTestTagRxPutOK];
    } else if (tag == RMBTTestTagRxPutOK) {
        _testUploadLastUploadLength = 0;
        _testUploadLastChunkSent = NO;
        _testStartNanos = RMBTCurrentNanos();
        _testUploadOffsetNanos = [_delegate testWorker:self didStartUplinkTestAtNanos:_testStartNanos];

        NSTimeInterval enoughInterval = (_params.testDuration - RMBT_TEST_UPLOAD_MAX_DISCARD_S);
        if (enoughInterval < 0) enoughInterval = 0;
        _testUploadEnoughServerNanos = enoughInterval * NSEC_PER_SEC;
        _testUploadEnoughClientNanos = _testStartNanos + (_params.testDuration + RMBT_TEST_UPLOAD_MIN_WAIT_S) * NSEC_PER_SEC;

        [self updateLastChunkFlagToValue:NO];
        [self writeData:_chunkData withTag:RMBTTestTagTxPutChunk];
        [self readLineWithTag:RMBTTestTagRxPutStatistic];
    } else if (tag == RMBTTestTagTxPutChunk) {
        if (_testUploadLastChunkSent) {
            // This was the last chunk
        } else {
            uint64_t nanos = RMBTCurrentNanos() + _testUploadOffsetNanos;
            if (nanos - _testStartNanos >= (_params.testDuration * NSEC_PER_SEC)) {
                RMBTLog(@"Sending last chunk in thread %u", _index);
                _testUploadLastChunkSent = YES;
                _testUploadMaxWaitReachedClientNanos = RMBTCurrentNanos() + RMBT_TEST_UPLOAD_MAX_WAIT_S * NSEC_PER_SEC;
                // We're done, send last chunk
                [self updateLastChunkFlagToValue:YES];
            }
            [self writeData:_chunkData withTag:RMBTTestTagTxPutChunk];
        }
    } else if (tag == RMBTTestTagRxPutStatistic) {
        // <- TIME
        NSString *line = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];

        if ([line hasPrefix:@"TIME"]) {
            long long ns = -1;
            long long bytes = -1;
            
            NSScanner *scanner = [NSScanner scannerWithString:line];

            if (![scanner scanString:@"TIME" intoString:NULL]) { NSAssert(false, @"Didn't scan TIME"); }

            if (![scanner scanLongLong:&ns]) { NSAssert(false, @"Didn't get long value for TIME"); }
            NSAssert(ns > 0, @"Invalid time");

            if ([scanner scanString:@"BYTES" intoString:NULL]) {
                if (![scanner scanLongLong:&bytes]) {
                    NSAssert(false, @"Didn't get long value for BYTES");
                }
                NSAssert(bytes > 0, @"Invalid bytes");
            }

            ns += _testUploadOffsetNanos;

            // Did upload
            if (bytes > 0) {
                [_delegate testWorker:self didUploadLength:(uint64_t)(bytes-_testUploadLastUploadLength) atNanos:(uint64_t)ns];
                _testUploadLastUploadLength = bytes;
            }

            uint64_t now = RMBTCurrentNanos();

            if (_testUploadLastChunkSent && now >= _testUploadMaxWaitReachedClientNanos) {
                RMBTLog(@"Max wait reached in thread %u. Finalizing.", _index);
                [self succeed];
                return;
            }

            if (_testUploadLastChunkSent && now >= _testUploadEnoughClientNanos && ns >= _testUploadEnoughServerNanos) {
                // We can finalize
                RMBTLog(@"Thread %u has read enough upload reports at local=%" PRIu64 " server=%" PRIu64 ". Finalizing...", _index, now - _testStartNanos, ns);
                [self succeed];
                return;
            }
            
            [self readLineWithTag:RMBTTestTagRxPutStatistic];
        } else if ([line hasPrefix:@"ACCEPT"]) {
            RMBTLog(@"Thread %u has read ALL upload reports. Finalizing...", _index);
            [self succeed];
        } else {
            // INVALID LINE
            NSAssert(false, @"Invalid response received");
            RMBTLog(@"Protocol error");
            [self fail];
        }
    } else {
        NSAssert1(false, @"RX/TX with unknown tag %ld", tag);
        RMBTLog(@"Protocol error");
        [self fail];
    }
}

// Finishes the uplink test and closes the connection
- (void)succeed {
    _state = RMBTTestWorkerStateUplinkTestFinished;
    [_socket disconnect];
    [_delegate testWorkerDidFinishUplinkTest:self];
}

#pragma mark - Socket helpers

- (void)readLineWithTag:(long)tag {
    [_socket readDataToData:[@"\n" dataUsingEncoding:NSASCIIStringEncoding] withTimeout:RMBT_TEST_SOCKET_TIMEOUT_S tag:tag];
}

- (void)writeLine:(NSString*)line withTag:(long)tag {
    [self writeData:[[line stringByAppendingString:@"\n"] dataUsingEncoding:NSASCIIStringEncoding] withTag:tag];
}

- (void)writeData:(NSData*)data withTag:(long)tag {
    _totalBytesUploaded += data.length;
    [_socket writeData:data withTimeout:RMBT_TEST_SOCKET_TIMEOUT_S tag:tag];
}

- (void)logData:(NSData*)data {
    NSString *s = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
    NSLog(@"RX: %@", s);
}

- (BOOL)isLastChunk:(NSData*)data {
    unsigned char *bytes = (unsigned char*)[data bytes];
    unsigned char lastByte = bytes[data.length-1];
    return (lastByte == 0xff);
}

- (void)updateLastChunkFlagToValue:(BOOL)lastChunk {
    unsigned char lastByte = lastChunk ? 0xff : 0x00;
    [_chunkData replaceBytesInRange:NSMakeRange(_chunkData.length-1, 1) withBytes:&lastByte];
}

@end
