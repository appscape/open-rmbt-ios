//
//  RMBTQoSTracerouteTest.m
//  RMBT
//
//  Created by Esad Hajdarevic on 09/01/17.
//  Copyright © 2017 appscape gmbh. All rights reserved.
//

#import "RMBTQoSTracerouteTest.h"

#import <arpa/inet.h>
#import <netdb.h>
#import <netinet/in.h>
#import <sys/socket.h>
#import <unistd.h>
#import <netinet/in.h>
#import <netinet/tcp.h>
#import <netinet/ip.h>
#import <netinet/udp.h>
#import <netinet/ip_icmp.h>

#import <pthread.h>

static const NSUInteger kDefaultMaxHops = 30;
static const NSUInteger kStartPort = 32768 + 666;
static const NSUInteger kTimeout = 3; // timeout for each try (-w)

@interface RMBTQoSTracerouteTest() {
    NSUInteger _maxHops;
    NSString *_host;
    NSArray *_result;

    BOOL _masked;
    BOOL _timedOut;
    BOOL _maxHopsExceeded;
}

@end

@implementation RMBTQoSTracerouteTest

- (instancetype)initWithParams:(NSDictionary *)params masked:(BOOL)masked {
    if (self = [super initWithParams:params]) {
        _host = params[@"host"];
        _maxHops = params[@"max_hops"] ? (NSUInteger)[params[@"max_hops"] integerValue] : kDefaultMaxHops;
        _masked = masked;
        _progress = [[RMBTProgress alloc] initWithTotalUnitCount:_maxHops];
    }
    return self;
}

- (void)main {
    uint64_t startedAt = RMBTCurrentNanos();

    struct sockaddr_in addr;
    addr.sin_family = AF_INET;
    memset(&addr.sin_zero, 0, sizeof(addr.sin_zero));

    const char *host = [_host UTF8String];
    addr.sin_addr.s_addr = inet_addr(host);
    if (addr.sin_addr.s_addr == INADDR_NONE) {
        struct hostent* hostinfo = gethostbyname(host);
        if (hostinfo == NULL) {
            RMBTLog(@"Traceroute error resolving %@: %s", _host, strerror(h_errno));
            return;
        }
        memcpy(&addr.sin_addr.s_addr, hostinfo->h_addr_list[0], hostinfo->h_length);
    }

    RMBTLog(@"Running traceroute to %s", inet_ntoa(addr.sin_addr));

    int recv_sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP);
    if (recv_sock == -1) {
        RMBTLog(@"Traceroute error creating receive socket: %s", strerror(errno));
        return;
    }

    if (fcntl(recv_sock, F_SETFL, O_NONBLOCK) == -1) {
        RMBTLog(@"Traceroute error putting receive socket into non-blocking mode: %s", strerror(errno));
        close(recv_sock);
        return;
    }

    int send_sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_IP);
    if (send_sock == -1) {
        RMBTLog(@"Traceroute error creating send socket: %s", strerror(errno));
        close(recv_sock);
        return;
    }

    // Bind to thread-unique source port
    struct sockaddr_in sa_bind;
    memset(&sa_bind.sin_zero, 0, sizeof(sa_bind.sin_zero));
    sa_bind.sin_family = AF_INET;
    sa_bind.sin_len = sizeof(sa_bind);
    sa_bind.sin_addr.s_addr = htonl(INADDR_ANY);

    uint16_t tid = pthread_mach_thread_np(pthread_self());
    sa_bind.sin_port   = htons((0xffff & tid) | 0x8000);

    if (bind(send_sock, (struct sockaddr*) &sa_bind, sizeof(sa_bind)) == -1) {
        RMBTLog(@"Traceroute error in bind: %s", strerror(errno));
        return;
    };

    int ttl = 1;
    in_addr_t ip = 0;
    NSDictionary* hopResult;
    NSMutableArray* result = [NSMutableArray array];
    do {
        addr.sin_port = htons(kStartPort+ttl-1);
        hopResult = [self traceWithSendSock:send_sock recvSock:recv_sock ttl:ttl port:sa_bind.sin_port addr:&addr ip:&ip];
        if (hopResult) {
            [result addObject:hopResult];
        }
        ttl++;
        if (ttl > _maxHops) {
            RMBTLog(@"Traceroute reached max hops (%lld)", _maxHops);
            _maxHopsExceeded = YES;
            break;
        }
        if (RMBTCurrentNanos() - startedAt > self.timeoutNanos) {
            RMBTLog(@"Traceroute timed out after %@", RMBTSecondsStringWithNanos(self.timeoutNanos));
            _timedOut = YES;
            break;
        }
        self.progress.completedUnitCount += 1;
    } while (
        hopResult && // otherwise error
        !self.isCancelled &&
        ip != addr.sin_addr.s_addr
    );

    close(send_sock);
    close(recv_sock);

    if (hopResult) {
        _result = result;
    } else {
        _result = nil;
    }
}


- (NSDictionary*)traceWithSendSock:(int)sendSock recvSock:(int)icmpSock ttl:(int)ttl port:(in_port_t)port addr:(struct sockaddr_in*)addr ip:(in_addr_t*)ipOut {
    int t = setsockopt(sendSock, IPPROTO_IP, IP_TTL, &ttl, sizeof(ttl));
    if (t == -1) {
        RMBTLog(@"Traceroute error setting ttl: %s", strerror(h_errno));
        return nil;
    }

    struct sockaddr_in storageAddr;
    socklen_t n = sizeof(struct sockaddr);

    char payload[] = {ttl & 0xFF};

    uint64_t startTime = RMBTCurrentNanos();

    ssize_t sent = sendto(sendSock, payload, sizeof(payload), 0, (struct sockaddr*)addr, sizeof(struct sockaddr));
    if (sent != sizeof(payload)) {
        RMBTLog(@"Traceroute error sending: %s", strerror(errno));
        return nil;
    }

    while((RMBTCurrentNanos() - startTime) < kTimeout * NSEC_PER_SEC) {
        struct timeval tv;
        tv.tv_sec = kTimeout;
        tv.tv_usec = 0;

        fd_set readfds;
        FD_ZERO(&readfds);
        FD_SET(icmpSock, &readfds);
        int ret = select(icmpSock+1, &readfds, NULL, NULL, &tv);

        uint64_t durationNanos = RMBTCurrentNanos() - startTime;

        if (ret < 0) {
            RMBTLog(@"Traceroute error in select() %s", strerror(errno));
            return nil;
        } else if (ret == 0) {
            // timeout
            break;
        } else {
            if (FD_ISSET(icmpSock, &readfds)) {
                char buff[512];
                ssize_t len = recvfrom(icmpSock, buff, sizeof(buff), 0, (struct sockaddr*)&storageAddr, &n);


                if (len < 0) {
                    RMBTLog(@"Traceroute error in recvfrom(): %s", strerror(errno));
                    return nil;
                } else {
                    struct ip *ipHeader = (struct ip *)buff;

                    int hlen = ipHeader->ip_hl << 2;
                    if (len < hlen + ICMP_MINLEN) {
                        RMBTLog(@"Received packet too short (%d bytes) from %s", len, inet_ntoa(storageAddr.sin_addr));
                        return nil;
                    }

                    char ips[16] = {0};
                    inet_ntop(AF_INET, &storageAddr.sin_addr.s_addr, ips, sizeof(ips));
                    NSString* remoteAddress = [NSString stringWithUTF8String:ips];

                    struct icmp *icmpHeader;
                    icmpHeader = (struct icmp *)(buff + hlen);
                    u_char icmpType = icmpHeader->icmp_type;
                    u_char icmpCode = icmpHeader->icmp_code;
                    if ((icmpType == ICMP_TIMXCEED && icmpCode == ICMP_TIMXCEED_INTRANS) || icmpType == ICMP_UNREACH) {
                        // Let's check if have the right packet, it might be from the other thread
                        struct ip *icmpIpHeader = &icmpHeader->icmp_ip;
                        int innerHlen = icmpIpHeader->ip_hl << 2;
                        if (icmpIpHeader->ip_p == IPPROTO_UDP) {
                            struct udphdr *udpHeader = (struct udphdr*)((char*)icmpIpHeader + innerHlen);

                            BOOL matching = (udpHeader->uh_sport == port) && (udpHeader->uh_dport == htons(kStartPort+ttl-1));

                            //RMBTLog(@"Traceroute %@ (%d) Reply from %@: t=%d c=%d | src=%d dst=%d | %d", _host, ttl, remoteAddress, icmpType, icmpCode, ntohs(udpHeader->uh_sport), ntohs(udpHeader->uh_dport), matching);

                            if (matching) {
                                // The right packet
                                *ipOut = storageAddr.sin_addr.s_addr;

                                return @{
                                  @"host": [self maskIP:remoteAddress],
                                  @"time": @(durationNanos)
                                };
                            }
                        }
                    }
                }
            }
        }
    } // receive loop

    // Timed out/unreachable
    return @{@"host": @"*", @"time": @(RMBTCurrentNanos() - startTime)};
}

- (NSString*)maskIP:(NSString*)address {
    if (_masked) {
        NSMutableArray<NSString*> *parts = [[address componentsSeparatedByString:@"."] mutableCopy];
        if (parts.count == 4) {
            parts[3] = @"x";
            return [parts componentsJoinedByString:@"."];
        }
    }
    return address;
}

- (NSDictionary*)result {
    NSMutableDictionary *result = [@{
        @"traceroute_objective_host": _host,
        @"traceroute_objective_max_hops": @(_maxHops),
        @"traceroute_objective_timeout": @(self.timeoutNanos),
    } mutableCopy];

    if (_maxHopsExceeded) {
        result[@"traceroute_result_status"] = @"MAX_HOPS_EXCEEDED";
    } else if (_timedOut) {
        result[@"traceroute_result_status"] = @"TIMEOUT";
    } else {
        result[@"traceroute_result_status"] = @"OK";
    }

    if (_result && _result.count > 0) {
        [result addEntriesFromDictionary:@{
            @"traceroute_result_details": _result,
            @"traceroute_result_hops": @(_result.count),
        }];
    } else {
        result[@"traceroute_result_status"] = @"ERROR";
    }
    return result;
}

- (NSString*)description {
    return [NSString stringWithFormat:@"RMBTQosTracerouteTest (masked=%@, uid=%@, cg=%ld, %@ (TTL: %lu)",
            _masked ? @"Y" : @"N",
            self.uid,
            (unsigned long)self.concurrencyGroup,
            _host,
            (unsigned long)_maxHops];
}

@end
