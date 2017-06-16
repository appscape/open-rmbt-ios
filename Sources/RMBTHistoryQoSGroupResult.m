//
//  RMBTHistoryQoSResult.m
//  RMBT
//
//  Created by Esad Hajdarevic on 17/11/16.
//  Copyright © 2016 appscape gmbh. All rights reserved.
//

#import "RMBTHistoryQoSGroupResult.h"
#import "RMBTHistoryResult.h"
#import <BlocksKit/NSArray+BlocksKit.h>

@interface RMBTHistoryQoSGroupResult() {
    RMBTHistoryResultItem* _item;
}
@end

@implementation RMBTHistoryQoSGroupResult

+ (NSArray<RMBTHistoryQoSGroupResult*>*)resultsWithResponse:(NSDictionary*)response {
    NSMutableArray *identifiers = [NSMutableArray array];
    NSMutableDictionary *resultsMap = [NSMutableDictionary dictionary];
    NSMutableDictionary *statusDetailsMap = [NSMutableDictionary dictionary];

    for (NSDictionary *testDesc in response[@"testresultdetail_testdesc"]) {
        NSString *name = testDesc[@"name"];
        NSString *identifier = [testDesc[@"test_type"] uppercaseString];
        resultsMap[identifier] = [@{@"name": name, @"tests": [NSMutableArray array]} mutableCopy];

        [identifiers addObject:identifier];
    }

    for (NSDictionary *info in response[@"testresultdetail_desc"]) {
        for (NSString *uid in info[@"uid"]) {
            statusDetailsMap[uid] = info[@"desc"];
        }
    }

    for (NSDictionary *info in response[@"testresultdetail"]) {
        NSString *identifier = [info[@"test_type"] uppercaseString];
        NSMutableDictionary *data = resultsMap[identifier];
        if (data) {
            RMBTHistoryQoSSingleResult *r = [[RMBTHistoryQoSSingleResult alloc] initWithResponse:info];
            r.statusDetails = statusDetailsMap[r.uid];
            [(NSMutableArray*)data[@"tests"] addObject:r];
        }
    }

    for (NSDictionary *info in response[@"testresultdetail_testdesc"]) {
        NSString *identifier = [info[@"test_type"] uppercaseString];
        NSMutableDictionary *data = resultsMap[identifier];
        if (data) {
            data[@"about"] = info[@"desc"];
        }
    }

    NSMutableArray *result = [NSMutableArray array];
    for (NSString *identifier in identifiers) {
        NSArray *tests = resultsMap[identifier][@"tests"];
        if (tests.count > 0) {
            // Sort tests so that failed ones come first:
            tests = [tests sortedArrayUsingComparator:^NSComparisonResult(RMBTHistoryQoSSingleResult * _Nonnull t1, RMBTHistoryQoSSingleResult * _Nonnull t2) {
                if (!t1.successful && t2.successful) {
                    return NSOrderedAscending;
                } else if (t1.successful && !t2.successful) {
                    return NSOrderedDescending;
                } else {
                    return [t1.uid compare:t2.uid];
                }
            }];

            [result addObject:[[RMBTHistoryQoSGroupResult alloc] initWithIdentifier:identifier
                                                                               name:resultsMap[identifier][@"name"]
                                                                              about:resultsMap[identifier][@"about"]
                                                                              tests:tests]];
        }
    }
    return result;
}

- (instancetype)initWithIdentifier:(NSString*)identifier name:(NSString*)name about:(NSString*)about tests:(NSArray*)tests {
    if (self = [super init]) {
        _name = name;
        _about = about;
        _tests = tests;
        _succeededCount = [tests bk_select:^BOOL(RMBTHistoryQoSSingleResult *r) {
            return r.successful;
        }].count;
    }
    return self;
}

- (NSString*)description {
    return [NSString stringWithFormat:@"RMBTHistoryQoSGroupResult (name=%@, about=%@, %ld/%ld)",
            _name, _about, (unsigned long)_succeededCount, (unsigned long)_tests.count];
}

- (RMBTHistoryResultItem*)toResultItem {
    if (!_item) {
        NSString *count = [NSString stringWithFormat:@"%ld/%ld",
                          (unsigned long)_succeededCount, (unsigned long)_tests.count];
        NSUInteger classification = (_succeededCount != _tests.count) ? 1 : 3;
        _item = [[RMBTHistoryResultItem alloc] initWithTitle:_name value:count classification:classification hasDetails:YES];
    }
    return _item;
}
@end
