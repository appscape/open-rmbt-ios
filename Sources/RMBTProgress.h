//
//  RMBTProgress.h
//  RMBT
//
//  Created by Esad Hajdarevic on 28/01/17.
//  Copyright © 2017 appscape gmbh. All rights reserved.
//

#import <Foundation/Foundation.h>

// Ligtweight replacement for NSProgress that supports iOS 8 and allows for simple composition
// without use of thread-associated variables and without reliance on KVO.

@interface RMBTProgressBase : NSObject
@property (nonatomic, readonly) float fractionCompleted;
@property (nonatomic, copy) void(^onFractionCompleteChange)(float p);
@end

@interface RMBTProgress : RMBTProgressBase
- (instancetype)initWithTotalUnitCount:(uint64_t)count;
@property (nonatomic, readonly) uint64_t totalUnitCount;
@property (nonatomic, assign) uint64_t completedUnitCount;
@end

@interface RMBTCompositeProgress : RMBTProgressBase
- (instancetype)initWithChildren:(NSArray<RMBTProgressBase*>*)children;
@end
