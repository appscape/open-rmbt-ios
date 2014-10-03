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

#import "RMBTMapCalloutView.h"
#import "RMBTHistoryResultItemCell.h"
#import <QuartzCore/QuartzCore.h>

static const CGFloat kRoundedCornerRadius = 6.0f;
static const CGSize kTriangleSize = {30.0f, 20.0f};

@interface RMBTMapCalloutView()<UITableViewDataSource, UITableViewDelegate> {
    NSArray *_measurementCells, *_netCells;
}
@property (nonatomic, strong) RMBTMapMeasurement *measurement;
@end

@implementation RMBTMapCalloutView

+ (UIView*)calloutViewWithMeasurement:(RMBTMapMeasurement*)measurement {
    RMBTMapCalloutView *view = [[[NSBundle mainBundle] loadNibNamed:@"RMBTMapCalloutView" owner:self options:nil] objectAtIndex:0];
    view.measurement = measurement;
    return view;
}

- (void)setMeasurement:(RMBTMapMeasurement *)measurement {
    _titleLabel.text = measurement.timeString;

    _measurementCells = [measurement.measurementItems bk_map:^id(RMBTHistoryResultItem* i) {
        RMBTHistoryResultItemCell *cell = [[RMBTHistoryResultItemCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
        cell.item = i;
        [cell setEmbedded:YES];
        return cell;
    }];

    _netCells = [measurement.netItems bk_map:^id(RMBTHistoryResultItem* i) {
        RMBTHistoryResultItemCell *cell = [[RMBTHistoryResultItemCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
        cell.item = i;
        [cell setEmbedded:YES];
        return cell;
    }];

    [self.tableView reloadData];

    self.frameHeight = self.tableView.contentSize.height;
}

- (void)setup {
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
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

- (void)layoutSubviews {
    [super layoutSubviews];
    [self applyMask];
}

- (void)applyMask {
    CGFloat bottom = self.frameHeight-kTriangleSize.height;

    CGMutablePathRef path = CGPathCreateMutable();
    CGPathMoveToPoint(path,NULL,kRoundedCornerRadius, 0.0f);
    CGPathAddLineToPoint(path, NULL, self.frameWidth-kRoundedCornerRadius, 0.0f);
    CGPathAddArcToPoint(path, NULL, self.frameWidth, 0.0f, self.frameWidth, kRoundedCornerRadius, kRoundedCornerRadius);
    CGPathAddLineToPoint(path, NULL, self.frameWidth, bottom-kRoundedCornerRadius);
    CGPathAddArcToPoint(path, NULL, self.frameWidth, bottom, self.frameWidth-kRoundedCornerRadius, bottom, kRoundedCornerRadius);
    CGPathAddLineToPoint(path, NULL, CGRectGetMidX(self.frame)+kTriangleSize.width/2.0f, bottom);
    CGPathAddLineToPoint(path, NULL, CGRectGetMidX(self.frame), self.frameHeight);
    CGPathAddLineToPoint(path, NULL, CGRectGetMidX(self.frame)-kTriangleSize.width/2.0f, bottom);
    CGPathAddLineToPoint(path, NULL, kRoundedCornerRadius, bottom);
    CGPathAddArcToPoint(path, NULL, 0.0f, bottom, 0.0f, bottom-kRoundedCornerRadius, kRoundedCornerRadius);
    CGPathAddLineToPoint(path, NULL, 0.0f, kRoundedCornerRadius);
    CGPathAddArcToPoint(path, NULL, 0.0f, 0.0f, kRoundedCornerRadius, 0.0f, kRoundedCornerRadius);

    CAShapeLayer *shapeLayer = [CAShapeLayer layer];
    [shapeLayer setPath:path];
    shapeLayer.fillColor = [[UIColor redColor] CGColor];
    shapeLayer.strokeColor = nil;
    shapeLayer.lineWidth = 0.0;
    [shapeLayer setBounds:self.bounds];
    [shapeLayer setAnchorPoint:CGPointMake(0.0f, 0.0f)];
    [shapeLayer setPosition:CGPointMake(0.0f, 0.0f)];

    CAShapeLayer *borderLayer = [NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:shapeLayer]];
    borderLayer.fillColor = nil;
    borderLayer.strokeColor = [[RMBT_DARK_COLOR colorWithAlphaComponent:0.75] CGColor];
    borderLayer.lineWidth = 3.0f;

    [self.layer addSublayer:borderLayer];
    self.layer.mask = shapeLayer;
}

#pragma mark - Table delegate

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        return [_measurementCells objectAtIndex:indexPath.row];
    } else {
        return [_netCells objectAtIndex:indexPath.row];
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        return _measurementCells.count;
    } else {
        return _netCells.count;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0 ) {
        return @"Measurement";
    } else {
        return @"Network";
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 30.0f;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    RMBTHistoryResultItemCell *cell = (RMBTHistoryResultItemCell*)[self tableView:tableView cellForRowAtIndexPath:indexPath];

    CGSize textSize = [cell.detailTextLabel.text sizeWithAttributes:@{NSFontAttributeName: cell.detailTextLabel.font}];

    if (textSize.width >= 130.0f) {
        return 50.0f;
    } else {
        return 30.0f;
    }
}

@end
