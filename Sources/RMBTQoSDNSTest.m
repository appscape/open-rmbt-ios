/*
 * Copyright 2017 appscape gmbh
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

#import "RMBTQoSDNSTest.h"
#include <arpa/inet.h>
#include <ifaddrs.h>
#include <resolv.h>
#include <dns.h>
#include <netdb.h>

@interface RMBTQoSDNSTest() {
    NSString *_resolver;
    NSString *_host;
    NSString *_record;
    NSString *_rcode;

    BOOL _timedOut;

    NSMutableArray<NSDictionary *> *_entries;
}
@end

@implementation RMBTQoSDNSTest

-(instancetype)initWithParams:(NSDictionary *)params {
    if (self = [super initWithParams:params]) {
        _host = [params valueForKey:@"host"];
        _resolver = [params valueForKey:@"resolver"];
        _record = [params valueForKey:@"record"];
    }
    return self;
}

- (void)main {
    NSParameterAssert(!self.cancelled);

    ns_type t = [self queryType];
    if (t == ns_t_invalid) {
        RMBTLog(@"..unknown record type %@, won't run", _record);
        return;
    }

    res_state res = malloc(sizeof(struct __res_state));
    NSParameterAssert(res != NULL);

    int r = res_ninit(res);
    if (r != 0) {
        NSParameterAssert(false);
        free(res);
        return;
    }

    res->retry = 1;
    res->retrans = (int)[self timeoutSeconds];

    if (_resolver) {
        // Custom DNS server
        struct in_addr addr;
        inet_aton([_resolver cStringUsingEncoding:NSASCIIStringEncoding], &addr);
        res->nsaddr_list[0].sin_addr = addr;
        res->nsaddr_list[0].sin_family = AF_INET;
        res->nsaddr_list[0].sin_port = htons(NS_DEFAULTPORT);
        res->nscount = 1;
    }

    if (self.cancelled) return;

    _entries = [NSMutableArray array];

    u_char answer[NS_PACKETSZ];
    int len = res_nquery(res, [_host cStringUsingEncoding:NSASCIIStringEncoding], ns_c_in, t, answer, sizeof(answer));
    if (len == -1) {
        if (h_errno == HOST_NOT_FOUND) {
            _rcode = @"NXDOMAIN";
        } else if (h_errno == TRY_AGAIN) {
            _timedOut = YES;
        }
    } else {
        ns_msg handle;
        ns_initparse(answer, len, &handle);

        int rcode = ns_msg_getflag(handle, ns_f_rcode);
        const char *rcode_str = p_rcode(rcode);
        _rcode = [NSString stringWithCString:rcode_str encoding:NSASCIIStringEncoding];

        if(ns_msg_count(handle, ns_s_an) > 0) {
            int count = ns_msg_count(handle, ns_s_an);
            ns_rr rr;
            for (int i = 0; i < count; i++) {
                if (self.cancelled) break;

                if(ns_parserr(&handle, ns_s_an, i, &rr) == 0) {
                    uint32_t ttl = ns_rr_ttl(rr);
                    NSMutableDictionary *result = [@{
                        @"dns_result_ttl": @(ttl)
                    } mutableCopy];


                    if(ns_rr_type(rr) == ns_t_a) {
                        char buf[INET_ADDRSTRLEN+1];
                        const char *p = inet_ntop(AF_INET, ns_rr_rdata(rr), buf, INET_ADDRSTRLEN);
                        if (p != NULL) {
                            result[@"dns_result_address"] = [NSString stringWithCString:buf encoding:NSASCIIStringEncoding];
                        }
                    } else if (ns_rr_type(rr) == ns_t_aaaa) {
                        char buf[INET6_ADDRSTRLEN+1];
                        const char *p = inet_ntop(AF_INET6, ns_rr_rdata(rr), buf, INET6_ADDRSTRLEN);
                        if (p != NULL) {
                            result[@"dns_result_address"] = [NSString stringWithCString:buf encoding:NSASCIIStringEncoding];
                        }
                    } else if (ns_rr_type(rr) == ns_t_mx || ns_rr_type(rr) == ns_t_cname) {
                        char buf[NS_MAXDNAME];
                        const u_char *rdata = ns_rr_rdata(rr);
                        if (ns_name_uncompress(ns_msg_base(handle), ns_msg_end(handle), rdata, buf, sizeof buf) != -1) {

                            result[@"dns_result_address"] = [NSString stringWithCString:buf encoding:NSASCIIStringEncoding];

                            if (ns_rr_type(rr) == ns_t_mx) {
                                uint16_t preference = (uint16_t)ns_get16(rdata);
                                result[@"dns_result_priority"] = @(preference);
                            }
                        }
                    }

                    [_entries addObject:result];
                }
            }
        }
    }

    res_ndestroy(res);
}

- (ns_type)queryType {
    if ([_record isEqualToString:@"A"]) {
        return ns_t_a;
    } else if ([_record isEqualToString:@"AAAA"]){
        return ns_t_aaaa;
    } else if ([_record isEqualToString:@"MX"]) {
        return ns_t_mx;
    } else if ([_record isEqualToString:@"CNAME"]) {
        return ns_t_cname;
    } else {
        return ns_t_invalid;
    }
}

- (NSDictionary*)result {
    NSMutableDictionary *result = [@{
        @"dns_objective_resolver": _resolver ?: @"Standard",
        @"dns_objective_dns_record": _record,
        @"dns_objective_host": _host,
        @"dns_objective_timeout": @(self.timeoutNanos)
    } mutableCopy];

    if (_timedOut) {
        [result addEntriesFromDictionary:@{@"dns_result_info": @"TIMEOUT"}];
    } else if (!_entries) {
        [result addEntriesFromDictionary:@{@"dns_result_info": @"ERROR"}];
    } else {
        [result addEntriesFromDictionary:@{
            @"dns_result_status": _rcode ?: @"UNKNOWN",
            @"dns_result_info": @"OK",
            @"dns_result_entries_found": @(_entries.count),
            @"dns_result_entries": _entries.count > 0 ? _entries : [NSNull null]
        }];
    }

    return result;
}

- (NSString*)description {
    return [NSString stringWithFormat:@"RMBTQoSDNSTest (uid=%@, cg=%ld, %@ %@@%@)",
            self.uid,
            (unsigned long)self.concurrencyGroup,
            _record,
            _host,
            _resolver ?: @"-"];
}

@end
