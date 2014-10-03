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

NSString * const RMBTTrafficLightTappedNotification = @"RMBTTrafficLightTappedNotification";

@implementation RMBTHistoryResultItemCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
    }
    return self;
}

- (void)setItem:(RMBTHistoryResultItem *)item {
    self.textLabel.text = item.title;
    self.detailTextLabel.text = item.value;

    if (item.classification != -1) {
        UIImage *image;
        if (item.classification == 1) {
            image = [UIImage imageNamed:@"traffic_lights_red"];
        } else  if (item.classification == 2) {
            image = [UIImage imageNamed:@"traffic_lights_yellow"];
        } else if (item.classification == 3) {
            image = [UIImage imageNamed:@"traffic_lights_green"];
        } else {
            image = [UIImage imageNamed:@"traffic_lights_none"];
        }
        self.accessoryView = [[UIImageView alloc] initWithImage:image];

        CGFloat rightEdge = self.boundsWidth - 44.0f;

        UITapGestureRecognizer *r = [UITapGestureRecognizer bk_recognizerWithHandler:^(UIGestureRecognizer *sender, UIGestureRecognizerState state, CGPoint location) {
            if (location.x >=rightEdge) {
                [[NSNotificationCenter defaultCenter] postNotificationName:RMBTTrafficLightTappedNotification object:self userInfo:nil];
            }
        }];
        r.numberOfTapsRequired = 1;
        r.numberOfTouchesRequired = 1;
        [self addGestureRecognizer:r];

    } else {
        self.accessoryView = nil;
    }
}

- (void)setEmbedded:(BOOL)embedded {
    if (embedded) {
        self.textLabel.font = [UIFont systemFontOfSize:15.0f];
        self.detailTextLabel.font = [UIFont systemFontOfSize:15.0f];
        self.detailTextLabel.numberOfLines = 2;
    }
}

@end
