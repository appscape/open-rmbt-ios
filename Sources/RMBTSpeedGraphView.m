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

#import "RMBTSpeedGraphView.h"
#import <QuartzCore/QuartzCore.h>

static CGRect const RMBTSpeedGraphViewContentFrame = {{46.0, 49.0},{244.0, 98.0}};
static NSTimeInterval const RMBTSpeedGraphViewSeconds = 8.0;

@interface RMBTSpeedGraphView() {
    UIImage *_backgroundImage, *_glossImage;
    UIBezierPath *_path;
    UIColor *_strokeColor;

    CGFloat _widthPerSecond;

    NSUInteger _valueCount;
    
    CALayer *_backgroundLayer;
    
    CAShapeLayer *_linesLayer;
    CALayer *_maskLayer;
}
@end

@implementation RMBTSpeedGraphView

- (CGSize)intrinsicContentSize {
    return _backgroundImage.size;
}

- (void)setup {
    _strokeColor = [UIColor colorWithRed:0.086 green:0.718 blue:0.357 alpha:1];
    self.backgroundColor = [UIColor clearColor];
    
    _backgroundImage = [self markedBackgroundImage];
    NSAssert(_backgroundImage.size.width == self.frame.size.width, @"Invalid bg image size");
    NSAssert(_backgroundImage.size.height == self.frame.size.height, @"Invalid bg image size");
    
    _backgroundLayer = [CALayer layer];
    _backgroundLayer.frame = self.bounds;
    _backgroundLayer.contents = (__bridge id)[_backgroundImage CGImage];
    
    [self.layer addSublayer:_backgroundLayer];
    
    _linesLayer = [CAShapeLayer layer];
    _linesLayer.lineWidth = 1.0;
    _linesLayer.strokeColor = [_strokeColor CGColor];
    _linesLayer.lineCap = kCALineCapRound;
    _linesLayer.fillColor = nil;
    _linesLayer.frame = RMBTSpeedGraphViewContentFrame;
    
    [self.layer addSublayer:_linesLayer];
    
    _widthPerSecond = RMBTSpeedGraphViewContentFrame.size.width / RMBTSpeedGraphViewSeconds;
    _path = [[UIBezierPath alloc] init];
}

- (id)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self setup];
    }
    return self;
}

- (void)awakeFromNib {
    [self setup];
}

- (void)addValue:(float)value atTimeInterval:(NSTimeInterval)interval {
    CGFloat y = RMBTSpeedGraphViewContentFrame.size.height * (1.0 - value);

    // Ignore values that come in after max seconds
    if (interval > RMBTSpeedGraphViewSeconds) return;

    CGPoint p = CGPointMake(interval * _widthPerSecond, y);

    if (_valueCount == 0) {
        CGPoint previousPoint = p;
        previousPoint.x = 0;
        [_path moveToPoint:previousPoint];
    }
    [_path addLineToPoint:p];

    _valueCount++;
    
    _linesLayer.path = [_path CGPath];
//    [_linesLayer setNeedsDisplay];
}

- (void)clear {
    _maxTimeInterval = 0;
    _valueCount = 0;
    [_path removeAllPoints];
    _linesLayer.path = [_path CGPath];
//    [_linesLayer setNeedsDisplay];
}

- (UIImage *)markedBackgroundImage {
    UIImage *image = [UIImage imageNamed:@"speed_graph_bg"]; // Background image
    return image;

//	UIGraphicsBeginImageContextWithOptions(image.size, NO, 0.0 /* device main screen*/);
//    CGContextRef ctx = UIGraphicsGetCurrentContext();
//
//    CGContextSetShouldAntialias(ctx, NO);
//    CGContextSetStrokeColorWithColor(ctx, [_strokeColor CGColor]);
//    CGContextSetLineWidth(ctx, 1.0);
//
//	[image drawAtPoint:CGPointZero];
//
//    CGRect frame = RMBTSpeedGraphViewContentFrame;
//
////    [self drawMarkAtPoint:frame.origin horizontal:YES context:ctx];
////    [self drawMarkAtPoint:CGPointMake(frame.origin.x, CGRectGetMaxY(frame)) horizontal:YES context:ctx];
////    [self drawMarkAtPoint:CGPointMake(frame.origin.x, CGRectGetMaxY(frame)) horizontal:NO context:ctx];
//    [self drawMarkAtPoint:CGPointMake(CGRectGetMaxX(frame), CGRectGetMaxY(frame)) horizontal:NO context:ctx];
//
//	UIImage *markedImage = UIGraphicsGetImageFromCurrentImageContext();
//    UIGraphicsEndImageContext();
//
//	return markedImage;
}

- (void)drawMarkAtPoint:(CGPoint)p horizontal:(BOOL)horizontal context:(CGContextRef)ctx {
    CGContextMoveToPoint(ctx, p.x, p.y);
    if (horizontal) {
        CGContextAddLineToPoint(ctx, p.x-5, p.y);
    } else {
        CGContextAddLineToPoint(ctx, p.x, p.y+5);
    }
    CGContextStrokePath(ctx);
}
@end
