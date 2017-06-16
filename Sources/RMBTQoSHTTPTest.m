//
//  RMBTQoSHTTPTest.m
//  RMBT
//
//  Created by Esad Hajdarevic on 20/12/16.
//  Copyright © 2016 appscape gmbh. All rights reserved.
//

#import "RMBTQoSHTTPTest.h"
#import <CommonCrypto/CommonDigest.h>

static NSString* MD5HexDigest(NSData *input) {
    unsigned char result[CC_MD5_DIGEST_LENGTH];

    CC_MD5(input.bytes, (CC_LONG)input.length, result);
    NSMutableString *ret = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH*2];
    for (int i = 0; i<CC_MD5_DIGEST_LENGTH; i++) {
        [ret appendFormat:@"%02x",result[i]];
    }
    return ret;
}

@interface RMBTQoSHTTPTest()<NSURLSessionDelegate> {
    NSString *_url;
    NSString *_range;

    NSString *_responseFingerprint;
    NSString *_responseAllHeaders;
    NSNumber *_responseStatusCode;
    NSNumber *_responseExpectedContentLength;
}
@end

@implementation RMBTQoSHTTPTest

-(instancetype)initWithParams:(NSDictionary *)params {
    if (self = [super initWithParams:params]) {
        _url = [params valueForKey:@"url"];
        _range = [params valueForKey:@"range"];
    }
    return self;
}

- (NSDictionary*)result {
    return @{
        @"http_objective_range": RMBTValueOrNull(_range),
        @"http_objective_url": RMBTValueOrNull(_url),
        @"http_result_status": RMBTValueOrNull(_responseStatusCode),
        @"http_result_length": RMBTValueOrNull(_responseExpectedContentLength),
        @"http_result_header": RMBTValueOrNull(_responseAllHeaders),
        @"http_result_hash": RMBTValueOrNull(_responseFingerprint)
    };
}

- (void)main {
    dispatch_semaphore_t doneSem = dispatch_semaphore_create(0);

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:_url]];
    if (_range) {
        [request addValue:_range forHTTPHeaderField:@"Range"];
    }
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration] delegate:self delegateQueue:nil];

    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (!error) {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
            _responseStatusCode = @(httpResponse.statusCode);
            _responseExpectedContentLength = @(httpResponse.expectedContentLength);
            _responseFingerprint = MD5HexDigest(data);
            NSMutableString* concatHeaders = [NSMutableString string];
            [httpResponse.allHeaderFields enumerateKeysAndObjectsUsingBlock:^(NSString*  _Nonnull key, NSString*  _Nonnull value, BOOL * _Nonnull stop) {
                [concatHeaders appendFormat:@"%@: %@\n", key, value];
            }];
            _responseAllHeaders = concatHeaders;
        } else {
            // TODO: timeout
            _responseFingerprint = @"ERROR";
            _responseStatusCode = @(0);
            _responseExpectedContentLength = @(0);
            _responseAllHeaders = @"";
        }
        dispatch_semaphore_signal(doneSem);
    }];

    [task resume];

    dispatch_semaphore_wait(doneSem, DISPATCH_TIME_FOREVER);
}

- (NSString*)description {
    return [NSString stringWithFormat:@"RMBTQoSHTTPTest (uid=%@, cg=%ld, %@/%@)",
            self.uid,
            (unsigned long)self.concurrencyGroup,
            _url,
            _range];
}

#pragma mark - NSURLSessionDelegate

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
willPerformHTTPRedirection:(NSHTTPURLResponse *)response
        newRequest:(NSURLRequest *)request
 completionHandler:(void (^)(NSURLRequest * _Nullable))completionHandler {
    // Disallow redirects
    completionHandler(nil);
}
@end
