//
//  UIColor+RMBTHex.h
//  RMBT
//
//  Created by Esad Hajdarevic on 12/12/14.
//  Copyright (c) 2014 appscape gmbh. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIColor (RMBTHex)
+(UIColor *)rmbt_colorWithRGBHex:(UInt32)hex;
+(UIColor *)rmbt_colorWithRGBHex:(UInt32)hex alpha:(CGFloat)alpha;
@end
