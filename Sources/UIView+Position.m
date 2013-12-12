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

#import "UIView+Position.h"


@implementation UIView (Position)

#pragma mark - frameOrigin

- (CGPoint)frameOrigin {
    return self.frame.origin;
}

- (void)setFrameOrigin:(CGPoint)newOrigin {
    CGRect rect = self.frame;
    rect.origin = newOrigin;
    self.frame = rect;
}

#pragma mark frameSize

- (CGSize)frameSize {
    return self.frame.size;
}

- (void)setFrameSize:(CGSize)newSize {
    CGRect rect = self.frame;
    rect.size = newSize;
    self.frame = rect;
}

#pragma mark frameX

- (CGFloat)frameX {
    return self.frame.origin.x;
}

- (void)setFrameX:(CGFloat)newX {
    CGRect rect = self.frame;
    rect.origin.x = newX;
    self.frame = rect;
}

#pragma mark frameY

- (CGFloat)frameY {
    return self.frame.origin.y;
}

- (void)setFrameY:(CGFloat)newY {
    CGRect rect = self.frame;
    rect.origin.y = newY;
    self.frame = rect;
}

#pragma mark frameRight

- (CGFloat)frameRight {
    CGRect rect = self.frame;
    return rect.origin.x + rect.size.width;
}

- (void)setFrameRight:(CGFloat)newRight {
    CGRect rect = self.frame;
    rect.origin.x = newRight - rect.size.width;
    self.frame = rect;
}

#pragma mark frameBottom

- (CGFloat)frameBottom {
    CGRect rect = self.frame;
    return rect.origin.y + rect.size.height;
}

- (void)setFrameBottom:(CGFloat)newBottom {
    CGRect rect = self.frame;
    rect.origin.y = newBottom - rect.size.height;
    self.frame = rect;
}

#pragma mark frameWidth

- (CGFloat)frameWidth {
    return self.frame.size.width;
}

- (void)setFrameWidth:(CGFloat)newWidth {
    CGRect rect = self.frame;
    rect.size.width = newWidth;
    self.frame = rect;
}

#pragma mark frameHeight

- (CGFloat)frameHeight {
    return self.frame.size.height;
}

- (void)setFrameHeight:(CGFloat)newHeight {
    CGRect rect = self.frame;
    rect.size.height = newHeight;
    self.frame = rect;
}

#pragma mark - boundsOrigin

- (CGPoint)boundsOrigin {
    return self.bounds.origin;
}

- (void)setBoundsOrigin:(CGPoint)newOrigin {
    CGRect rect = self.bounds;
    rect.origin = newOrigin;
    self.bounds = rect;
}

#pragma mark boundsSize

- (CGSize)boundsSize {
    return self.bounds.size;
}

- (void)setBoundsSize:(CGSize)newSize {
    CGRect rect = self.bounds;
    rect.size = newSize;
    self.bounds = rect;
}

#pragma mark boundsX

- (CGFloat)boundsX {
    return self.bounds.origin.x;
}

- (void)setBoundsX:(CGFloat)newX {
    CGRect rect = self.bounds;
    rect.origin.x = newX;
    self.bounds = rect;
}

#pragma mark boundsY

- (CGFloat)boundsY {
    return self.bounds.origin.y;
}

- (void)setBoundsY:(CGFloat)newY {
    CGRect rect = self.bounds;
    rect.origin.y = newY;
    self.bounds = rect;
}

#pragma mark boundsRight

- (CGFloat)boundsRight {
    CGRect rect = self.bounds;
    return rect.origin.x + rect.size.width;
}

- (void)setBoundsRight:(CGFloat)newRight {
    CGRect rect = self.bounds;
    rect.origin.x = newRight - rect.size.width;
    self.bounds = rect;
}

#pragma mark boundsBottom

- (CGFloat)boundsBottom {
    CGRect rect = self.bounds;
    return rect.origin.y + rect.size.height;
}

- (void)setBoundsBottom:(CGFloat)newBottom {
    CGRect rect = self.bounds;
    rect.origin.y = newBottom - rect.size.height;
    self.bounds = rect;
}

#pragma mark boundsWidth

- (CGFloat)boundsWidth {
    return self.bounds.size.width;
}

- (void)setBoundsWidth:(CGFloat)newWidth {
    CGRect rect = self.bounds;
    rect.size.width = newWidth;
    self.bounds = rect;
}

#pragma mark boundsHeight

- (CGFloat)boundsHeight {
    return self.bounds.size.height;
}

- (void)setBoundsHeight:(CGFloat)newHeight {
    CGRect rect = self.bounds;
    rect.size.height = newHeight;
    self.bounds = rect;
}

#pragma mark - centerX

- (CGFloat)centerX {
    return self.center.x;
}

- (void)setCenterX:(CGFloat)newX {
    CGPoint point = self.center;
    point.x = newX;
    self.center = point;
}

#pragma mark centerY

- (CGFloat)centerY {
    return self.center.y;
}

- (void)setCenterY:(CGFloat)newY {
    CGPoint point = self.center;
    point.y = newY;
    self.center = point;
}

@end