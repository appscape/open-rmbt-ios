/*
 * Copyright 2013 appscape gmbh
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
#import "RMBTNavigationBar.h"

@interface RMBTNavigationBar ()
@property (nonatomic, strong) CALayer *colorLayer;
@end

@implementation RMBTNavigationBar

static CGFloat const kDefaultColorLayerOpacity = 0.6f;
static CGFloat const kSpaceToCoverStatusBars = 20.0f;
static CGFloat const kExtendedHeight = 60.0f;

- (void)setBarTintColor:(UIColor *)barTintColor {
    [super setBarTintColor:barTintColor];


    if (self.colorLayer == nil) {
        self.colorLayer = [CALayer layer];
        self.colorLayer.opacity = kDefaultColorLayerOpacity;
        [self.layer addSublayer:self.colorLayer];
    }
    
    self.colorLayer.backgroundColor = barTintColor.CGColor;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    for (UIView *v in self.subviews) {
        if(v.tag == 100) {
            self.boundsHeight = kSpaceToCoverStatusBars + kExtendedHeight;
            v.frameY = kSpaceToCoverStatusBars;
            v.frameHeight = kExtendedHeight;
//            v.backgroundColor = [UIColor redColor];
            break;
        }
    }


    if (self.colorLayer != nil) {
        self.colorLayer.frame = CGRectMake(0, 0 - kSpaceToCoverStatusBars, CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds) + kSpaceToCoverStatusBars);
        
        [self.layer insertSublayer:self.colorLayer atIndex:1];
    }
}

@end