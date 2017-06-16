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

#import "RMBTHistoryResultItemCell.h"
#import "RMBTHistoryResult.h"
#import "UIView+RMBTSubviews.h"

NSString * const RMBTTrafficLightTappedNotification = @"RMBTTrafficLightTappedNotification";

@interface RMBTHistoryResultItemCell() {
    UIButton *_trafficLightButton;

    UIButton *_accessoryButton;
    BOOL _accessoryButtonRotated;
    dispatch_once_t _accessoryButtonLookupDone;
}
@end

@implementation RMBTHistoryResultItemCell

- (void)setup {
    _trafficLightButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _trafficLightButton.imageEdgeInsets = UIEdgeInsetsMake(1.0f, 0.0f, 0.0f, 0.0f);
    [_trafficLightButton bk_addEventHandler:^(id sender) {
        [[NSNotificationCenter defaultCenter] postNotificationName:RMBTTrafficLightTappedNotification object:self userInfo:nil];
    } forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:_trafficLightButton];
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:reuseIdentifier]) {
        [self setup];
    }
    return self;
}

- (void)awakeFromNib {
    [super awakeFromNib];
    [self setup];
}

- (void)setItem:(RMBTHistoryResultItem *)item {
    self.textLabel.text = item.title;
    self.detailTextLabel.text = item.value;

    self.accessoryType = UITableViewCellAccessoryNone;
    [_trafficLightButton setImage:nil forState:UIControlStateNormal];

    if (item.classification != -1) {
        UIImage *image;
        if (item.classification == 1) {
            image = [UIImage imageNamed:@"traffic_lights_red"];
        } else  if (item.classification == 2) {
            image = [UIImage imageNamed:@"traffic_lights_yellow"];
        } else if (item.classification == 3) {
            image = [UIImage imageNamed:@"traffic_lights_green"];
        } else if (item.classification == 4) {
            image = [UIImage imageNamed:@"traffic_lights_darkgreen"];
        } else {
            image = [UIImage imageNamed:@"traffic_lights_none"];
        }

        [_trafficLightButton setImage:image forState:UIControlStateNormal];
    }

    if (item.hasDetails) {
        self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        self.selectionStyle = UITableViewCellSelectionStyleGray;
    } else {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    if ([_trafficLightButton imageForState:UIControlStateNormal]) {
        [_trafficLightButton sizeToFit];
        CGFloat widthWithPadding = _trafficLightButton.frameWidth + 20.0f;

        _trafficLightButton.frame = CGRectMake(self.detailTextLabel.frameRight-widthWithPadding + 10.0f, 0.0f, widthWithPadding, self.contentView.frameHeight);
        self.detailTextLabel.frameRight -= (widthWithPadding - 10.0f);
    } else {
        _trafficLightButton.frame = CGRectZero;
    }
}

- (void)setEmbedded:(BOOL)embedded {
    if (embedded) {
        self.textLabel.font = [UIFont systemFontOfSize:15.0f];
        self.detailTextLabel.font = [UIFont systemFontOfSize:15.0f];
        self.detailTextLabel.numberOfLines = 2;
    }
}

- (UIButton*)accessoryButton {
    dispatch_once(&_accessoryButtonLookupDone, ^{
        [self rmbt_enumerateSubviewsOfType:[UIButton class] usingBlock:^(UIView *view) {
            if (!_accessoryButton && view != _trafficLightButton) {
                _accessoryButton = (UIButton*)view;
            }
        }];
    });

    return _accessoryButton;
}

- (void)setAccessoryRotated:(BOOL)state {
    if (state != _accessoryButtonRotated) {
        UIButton *button = [self accessoryButton];
        _accessoryButtonRotated = state;
        if (!button) return;

        [CATransaction begin];
        CABasicAnimation* ba = [CABasicAnimation animationWithKeyPath:@"transform"];
        ba.removedOnCompletion = NO;
        ba.fillMode = kCAFillModeForwards;
        ba.duration = 0.25f;
        ba.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        ba.toValue = [NSValue valueWithCATransform3D:CATransform3DMakeRotation(state ? M_PI_2 : 0,0,0,1)];
        if (!state) {
            // we're returning back to default state, just remove all forward-filling animations to get back to 0
            [CATransaction setCompletionBlock:^{
                [button.layer removeAllAnimations];
            }];
        }
        [button.layer addAnimation:ba forKey:nil];
        [CATransaction commit];
    }
}

- (void)setTrafficLightInteractionEnabled:(BOOL)state {
    _trafficLightButton.userInteractionEnabled = state;
}

@end
