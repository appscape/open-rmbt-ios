//
//  UIView+UIVIew_RMBTSubview.m
//  RMBT
//
//  Created by Esad Hajdarevic on 06/04/17.
//  Copyright © 2017 appscape gmbh. All rights reserved.
//

#import "UIView+RMBTSubviews.h"

@implementation UIView (RMBTSubviews)

- (void)rmbt_enumerateSubviewsOfType:(Class)type usingBlock:(void (^)(UIView *view))block {
    for (UIView* v in self.subviews) {
        if([v isKindOfClass:type]) {
            block(v);
        } else {
            [v rmbt_enumerateSubviewsOfType:type usingBlock:block];
        }
    }
}
@end
