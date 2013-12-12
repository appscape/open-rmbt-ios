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

#import "RMBTGaugeView.h"
#import "UIView+Position.h"
#import <QuartzCore/QuartzCore.h>

@interface RMBTGaugeView() {
    CGFloat _startAngle;
    CGFloat _endAngle;

    UIImage *_backgroundImage, *_foregroundImage;

    CAShapeLayer *_maskLayer;
    
    CGRect _ovalRect;

    float _value;
}

@end

@implementation RMBTGaugeView

- (id)initWithFrame:(CGRect)frame name:(NSString*)name startAngle:(CGFloat)startAngle endAngle:(CGFloat)endAngle ovalRect:(CGRect)rect {
    if (self = [super initWithFrame:frame]) {
        self.opaque = NO;
        self.backgroundColor = [UIColor clearColor];
        
        _backgroundImage = [UIImage imageNamed:[NSString stringWithFormat:@"gauge_%@_bg", name]];
        _foregroundImage = [UIImage imageNamed:[NSString stringWithFormat:@"gauge_%@_fg", name]];

        NSAssert(_backgroundImage, @"Couldn't load image");
        NSAssert(_foregroundImage, @"Couldn't load image");
        
        _startAngle = (startAngle * M_PI)/180.0f;
        _endAngle = (endAngle * M_PI)/180.0f;
        
        _ovalRect = rect;
        
        _value = 0.0f;
        
        CALayer *foregroundLayer = [CALayer layer];
        foregroundLayer.frame = CGRectMake(0,0,_foregroundImage.size.width, _foregroundImage.size.height);
        foregroundLayer.contents = (__bridge id)[_foregroundImage CGImage];

        CALayer *backgroundLayer = [CALayer layer];
        backgroundLayer.frame = CGRectMake(0,0,_backgroundImage.size.width, _backgroundImage.size.height);
        backgroundLayer.contents = (__bridge id)[_backgroundImage CGImage];

        [self.layer addSublayer:backgroundLayer];
        [self.layer addSublayer:foregroundLayer];
        
        _maskLayer = [CAShapeLayer layer];
        [foregroundLayer setMask:_maskLayer];
    }
    return self;
}

- (void)setValue:(float)value {
    if (_value == value) return;
    _value = value;
    
    CGFloat angle = _startAngle +(_endAngle-_startAngle)*_value;
    
    UIBezierPath *path = [UIBezierPath bezierPathWithArcCenter:CGPointMake(CGRectGetMidX(_ovalRect), CGRectGetMidY(_ovalRect)) radius:_ovalRect.size.width/2.0 startAngle:_startAngle endAngle:angle clockwise:YES];
    CGFloat backEndAngle = _startAngle - 2 * M_PI;
    CGFloat backStartAngle = angle - 2 * M_PI;
    [path addArcWithCenter:CGPointMake(CGRectGetMidX(_ovalRect), CGRectGetMidY(_ovalRect)) radius:(_ovalRect.size.width/2.0)-15 startAngle:backStartAngle endAngle:backEndAngle clockwise:NO];
    [path closePath];

    _maskLayer.path = [path CGPath];
}

@end
