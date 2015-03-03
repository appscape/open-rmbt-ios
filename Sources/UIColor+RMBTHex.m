//
//  UIColor+RMBTHex.m
//  RMBT
//
//  Created by Esad Hajdarevic on 12/12/14.
//  Copyright (c) 2014 appscape gmbh. All rights reserved.
//

#import "UIColor+RMBTHex.h"

@implementation UIColor (RMBTHex)
+ (UIColor *)rmbt_colorWithRGBHex:(UInt32)hex alpha:(CGFloat)alpha {
    int r = (hex >> 16) & 0xFF;
    int g = (hex >> 8) & 0xFF;
    int b = (hex) & 0xFF;

    return [UIColor colorWithRed:r / 255.0f
                           green:g / 255.0f
                            blue:b / 255.0f
                           alpha:alpha];
}

+ (UIColor *)rmbt_colorWithRGBHex:(UInt32)hex {
    return [self rmbt_colorWithRGBHex:hex alpha:1.0f];
}

@end
