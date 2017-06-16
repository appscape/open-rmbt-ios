//
//  UIView+UIVIew_RMBTSubview.h
//  RMBT
//
//  Created by Esad Hajdarevic on 06/04/17.
//  Copyright © 2017 appscape gmbh. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIView (RMBTSubviews)

- (void)rmbt_enumerateSubviewsOfType:(Class)type usingBlock:(void (^)(UIView *view))block;

@end
