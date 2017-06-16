//
//  RMBTQosWebTestURLProtocol.m
//  RMBT
//
//  Created by Esad Hajdarevic on 15/04/17.
//  Copyright © 2017 appscape gmbh. All rights reserved.
//

#import "RMBTQosWebTestURLProtocol.h"

NSString * const RMBTQosWebTestURLProtocolResultStatusKey = @"status";
NSString * const RMBTQosWebTestURLProtocolResultRxBytesKey = @"rx";


static NSString * const RMBTQosWebTestURLProtocolTagKey = @"tag";
// See "Squashing the Infinite Loop with Tags":
// https://www.raywenderlich.com/59982/nsurlprotocol-tutorial
static NSString * const RMBTQosWebTestURLProtocolHandledKey = @"handled";

@interface RMBTQosWebTestURLProtocol() {
    NSURLConnection *_connection;
}
@end

@implementation RMBTQosWebTestURLProtocol

static NSMutableDictionary<NSString*, NSMutableDictionary*> *results; // uid -> {url,status,rxbytes,txbytes}

+ (void)start {
    NSParameterAssert(!results);
    results = [NSMutableDictionary dictionary];
    [NSURLProtocol registerClass:[RMBTQosWebTestURLProtocol class]];
}

+ (void)stop {
    [NSURLProtocol unregisterClass:[RMBTQosWebTestURLProtocol class]];
    results = nil;
}

+ (void)tagRequest:(NSMutableURLRequest*)request withValue:(NSString*)value {
    [NSURLProtocol setProperty:value forKey:RMBTQosWebTestURLProtocolTagKey inRequest:request];
}

+ (NSDictionary*)queryResultWithTag:(NSString*)tag {
    return results[tag];
}

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    NSString *tag = [NSURLProtocol propertyForKey:RMBTQosWebTestURLProtocolTagKey inRequest:request];
    NSNumber *handled = [NSURLProtocol propertyForKey:RMBTQosWebTestURLProtocolHandledKey inRequest:request];

    NSString *url = request.mainDocumentURL.absoluteString;

    if (handled && [handled boolValue]) {
        return NO;
    }

    if (tag) {
        if (!results[tag]) {
            NSMutableDictionary *entry = [@{RMBTQosWebTestURLProtocolResultStatusKey: @(-1),
                                            RMBTQosWebTestURLProtocolResultRxBytesKey: @0
                                            }
                                          mutableCopy];
            results[url] = entry;
            results[tag] = entry;
        }
        return YES;
    } else {
        NSMutableDictionary *entry = results[url];
        return (entry != nil);
    }
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}

- (NSCachedURLResponse*)cachedResponseForRequest:(NSURLRequest*)request {
    return nil;
}

+ (BOOL)requestIsCacheEquivalent:(NSURLRequest *)a toRequest:(NSURLRequest *)b {
    return [super requestIsCacheEquivalent:a toRequest:b];
}

- (void)stopLoading {
    [_connection cancel];
}

- (void)startLoading {
    NSMutableURLRequest *handledRequest = [self.request mutableCopy];
    [NSURLProtocol setProperty:@YES forKey:RMBTQosWebTestURLProtocolHandledKey inRequest:handledRequest];
    handledRequest.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
    _connection = [NSURLConnection connectionWithRequest:handledRequest delegate:self];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    NSString *currentURLString = connection.currentRequest.URL.absoluteString;
    if ([currentURLString isEqualToString:connection.currentRequest.mainDocumentURL.absoluteString] &&
        [response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSMutableDictionary *entry = results[currentURLString];
        NSParameterAssert(entry);
        entry[RMBTQosWebTestURLProtocolResultStatusKey] = @(((NSHTTPURLResponse*)response).statusCode);
    }
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
}

- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse {
    if (redirectResponse) {

        // Webview requests for page resources like images or stylesheets don't inherit NSURLProtocol properties
        // from the original request, so the only way to associate them with the webview is by comparing mainDocumentURL.
        //
        // For this reason, in the results dictionary we have the same entry under multiple keys (tag/uid as well as
        // mainDocumentURL).
        NSMutableDictionary *entry = results[connection.originalRequest.mainDocumentURL.absoluteString];
        if (entry) {
            // Here we let the new URL also point to the same entry:
            results[request.URL.absoluteString] = entry;
        }

        // We need to let webview know that the URL has been updated - so it can update its relative URLs.
        // However, webview will also start another request by itself, so we can return nil here to stop loading it ourselves.
        // The `request` is a copy of the original request, which means it will also have the NSURLProtocol property "handled"
        // set, which we need to unset and allow it to be handled by this protocol again.
        NSMutableURLRequest *unhandledRequest = [request mutableCopy];
        [NSURLProtocol removePropertyForKey:RMBTQosWebTestURLProtocolHandledKey inRequest:unhandledRequest];
        [self.client URLProtocol:self wasRedirectedToRequest:unhandledRequest redirectResponse:redirectResponse];

        [_connection cancel]; // otherwise we receive didReceiveData: for the redirect page itself
        return nil;
    }
    return request;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    NSMutableDictionary *entry = results[connection.originalRequest.mainDocumentURL.absoluteString];
    NSAssert1(entry, @"Expected entry for %@", connection.originalRequest.mainDocumentURL.absoluteString);
    entry[RMBTQosWebTestURLProtocolResultRxBytesKey] = @([entry[RMBTQosWebTestURLProtocolResultRxBytesKey] integerValue] + data.length);
    [self.client URLProtocol:self didLoadData:data];
    _connection = nil;
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    [self.client URLProtocol:self didFailWithError:error];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    [self.client URLProtocolDidFinishLoading:self];
}

@end
