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

#import "UITableViewCell+RMBTHeight.h"

@implementation UITableViewCell (RMBTHeight)
+(CGFloat)rmbtApproximateOptimalHeightForText:(NSString*)text
                                    detailText:(NSString*)detailText {
    static UIFont *cellTextFont, *cellDetailTextFont;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cellTextFont = [UIFont boldSystemFontOfSize:17.0f];
        cellDetailTextFont = [UIFont systemFontOfSize:17.0f];
    });
    CGSize textSize = [text sizeWithAttributes:@{NSFontAttributeName: cellTextFont}];
    CGSize detailTextSize = [detailText sizeWithAttributes:@{NSFontAttributeName: cellDetailTextFont}];
    CGFloat totalWidth = textSize.width+detailTextSize.width;
    if (totalWidth > 380.0f) return 80.0f;
    if (totalWidth > 270.0f) return 62.0f;
    return 44.0f;

}

-(CGFloat)rmbtApproximateOptimalHeight {
    return [UITableViewCell rmbtApproximateOptimalHeightForText:self.textLabel.text detailText:self.detailTextLabel.text];
}

@end
