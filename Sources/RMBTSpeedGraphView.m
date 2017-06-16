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

static CGRect const RMBTSpeedGraphViewContentFrame = {{34.5, 32.5},{243.0, 92.0}};
static NSTimeInterval const RMBTSpeedGraphViewSeconds = 8.0;

@interface RMBTSpeedGraphView() {
    UIImage *_backgroundImage;
    UIBezierPath *_path;
    CGPoint _firstPoint;

    CGFloat _widthPerSecond;

    NSUInteger _valueCount;
    
    CALayer *_backgroundLayer;
    
    CAShapeLayer *_linesLayer, *_fillLayer;
}
@end

@implementation RMBTSpeedGraphView

- (CGSize)intrinsicContentSize {
    return _backgroundImage.size;
}

- (void)setup {
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
    _linesLayer.strokeColor = [UIColor rmbt_colorWithRGBHex:0x3da11b].CGColor;
    _linesLayer.lineCap = kCALineCapRound;
    _linesLayer.fillColor = nil;
    _linesLayer.frame = RMBTSpeedGraphViewContentFrame;
    
    [self.layer addSublayer:_linesLayer];

    _fillLayer = [CAShapeLayer layer];
    _fillLayer.lineWidth = 0.0f;
    _fillLayer.fillColor = [UIColor rmbt_colorWithRGBHex:0x52d301 alpha:0.4].CGColor;

    _fillLayer.frame = RMBTSpeedGraphViewContentFrame;
    [self.layer insertSublayer:_fillLayer below:_linesLayer];
    
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
    [super awakeFromNib];
    [self setup];
}

- (void)addValue:(float)value atTimeInterval:(NSTimeInterval)interval {
    if (value>1.0) { value = 1.0; } // Clip to 1.0 (Gbit/s)

    CGFloat maxY = RMBTSpeedGraphViewContentFrame.size.height;
    CGFloat y = maxY * (1.0 - value);

    // Ignore values that come in after max seconds
    if (interval > RMBTSpeedGraphViewSeconds) return;

    CGPoint p = CGPointMake(interval * _widthPerSecond, y);

    if (_valueCount == 0) {
        CGPoint previousPoint = p;
        previousPoint.x = 0;
        _firstPoint = previousPoint;
        [_path moveToPoint:previousPoint];
    }
    [_path addLineToPoint:p];

    _valueCount++;
    
    _linesLayer.path = [_path CGPath];

    // Fill path

    UIBezierPath *fillPath = [[UIBezierPath alloc] init];
    [fillPath appendPath:_path];
    [fillPath addLineToPoint:CGPointMake(p.x, maxY)];
    [fillPath addLineToPoint:CGPointMake(0, maxY)];
    [fillPath addLineToPoint:_firstPoint];
    [fillPath closePath];

    _fillLayer.path = [fillPath CGPath];;
}

- (void)clear {
    _valueCount = 0;
    [_path removeAllPoints];
    _linesLayer.path = [_path CGPath];
    _fillLayer.path = nil;
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
