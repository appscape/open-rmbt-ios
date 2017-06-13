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

#import "RMBTProgress.h"

@interface RMBTProgressBase()
@property (nonatomic, weak) RMBTCompositeProgress *parent;
- (void)notify;
@end

@implementation RMBTProgressBase
- (void)notify {
    if(self.onFractionCompleteChange) {
        self.onFractionCompleteChange(self.fractionCompleted);
    }
    if (self.parent) { [self.parent notify]; }
}
@end

@interface RMBTCompositeProgress() {
    NSArray<RMBTProgressBase*>* _children;
}
@end

@implementation RMBTCompositeProgress
- (instancetype)initWithChildren:(NSArray<RMBTProgressBase*>*)children {
    if (self = [super init]) {
        NSParameterAssert(children.count > 0);
        _children = children;
        for (RMBTProgressBase *c in _children) {
            c.parent = self;
        }
    }
    return self;
}

- (float)fractionCompleted {
    float total = 0;
    if (_children.count > 0) {
        for (RMBTProgress *c in _children) {
            total += c.fractionCompleted;
        }
        return total/_children.count;
    } else {
        return 0;
    }
}

- (NSString*)description {
    return [NSString stringWithFormat:@"RMBTCompositeProgress %f (%@)", self.fractionCompleted, _children];
}
@end

@implementation RMBTProgress

- (instancetype)initWithTotalUnitCount:(uint64_t)count {
    if (self = [super init]) {
        _completedUnitCount = 0;
        _totalUnitCount = count;
    }
    return self;
}

- (void)setCompletedUnitCount:(uint64_t)completedUnitCount {
    _completedUnitCount = MIN(_totalUnitCount,completedUnitCount); // clamp
    [self notify];
}

- (float)fractionCompleted {
    return _totalUnitCount == 0 ? 0 : (double)_completedUnitCount/_totalUnitCount;
}


- (NSString*)description {
    return [NSString stringWithFormat:@"RMBTProgress %f (%llu/%llu)", self.fractionCompleted, _completedUnitCount, _totalUnitCount];
}
@end
