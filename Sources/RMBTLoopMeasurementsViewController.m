/*
 * Copyright 2017 appscape gmbh
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

#import "RMBTLoopMeasurementsViewController.h"
#import "RMBTSpeed.h"

NSString * const RMBTLoopMeasurementPing = @"Ping";
NSString * const RMBTLoopMeasurementDown = @"Down";
NSString * const RMBTLoopMeasurementUp = @"Up";
NSString * const RMBTLoopMeasurementQoS = @"QoS";

@implementation RMBTLoopMeasurementCell : UITableViewCell
- (void)awakeFromNib {
    [super awakeFromNib];
    self.measurementNameLabel.text = @"";
    self.currentValueLabel.text = @"";
    self.medianValueLabel.text = @"";
}
@end

typedef NSMutableDictionary<NSString*, id> RMBTMeasurementValuesDictionary;

@interface RMBTLoopMeasurementsViewController () {
    RMBTMeasurementValuesDictionary *_values;
    NSMutableArray<RMBTMeasurementValuesDictionary*> *_pastValues;
    RMBTMeasurementValuesDictionary *_medians;

    NSString *_currentMeasurement;
    NSMutableSet *_finishedMeasurements;

    BOOL _active;
}

@end

@implementation RMBTLoopMeasurementsViewController

+ (NSArray<NSString*>*)allMeasurements {
    static NSArray* result;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        result = @[RMBTLoopMeasurementPing, RMBTLoopMeasurementDown, RMBTLoopMeasurementUp, RMBTLoopMeasurementQoS];
    });
    return result;
}

- (void)refresh {
    NSString *leftText = _pastValues.count == 0 ? nil : NSLocalizedString(@"Median", @"Loop mode header title");
    self.rightHeaderLabel.text = [leftText localizedUppercaseString];

    NSString *midText = _active ? NSLocalizedString(@"Current", @"Loop mode header title") : NSLocalizedString(@"Previous test", @"Loop mode header title");
    self.middleHeaderLabel.text = [midText localizedUppercaseString];
    [self.tableView reloadData];
}

- (void)start {
    if (!_pastValues) { _pastValues = [NSMutableArray array]; }
    _values = [NSMutableDictionary dictionary];
    _finishedMeasurements = [NSMutableSet set];

    _active = YES;
    [self refresh];
}

- (void)cancel {
    _currentMeasurement = nil;
    _active = NO;
    [self refresh];
}

- (void)finish {
    {
        NSMutableDictionary *values = [_values mutableCopy];
        [values removeObjectForKey:RMBTLoopMeasurementQoS]; // don't copy qos value to past values
        [_pastValues addObject:values];
    }

    // Update medians
    _medians = [NSMutableDictionary dictionary];
    for (NSString* measurement in [[self class] allMeasurements]) {
        if ([measurement isEqualToString:RMBTLoopMeasurementQoS]) { continue; }

        NSMutableArray* values = [NSMutableArray array];
        for (RMBTMeasurementValuesDictionary* p in _pastValues) {
            NSNumber *n = p[measurement];
            if (n) {
                [values addObject:n];
            } else {
                NSParameterAssert(false); // all measurements except qos should have a value at this point
            }
        }

        _medians[measurement] = RMBTMedian(values);
        NSParameterAssert(_medians[measurement]);
    }

    [_finishedMeasurements removeAllObjects];

    _active = NO;
    _currentMeasurement = nil;

    [self refresh];
}

- (void)setValue:(id)value forMeasurement:(NSString*)measurement final:(BOOL)isFinal {
    if (value) {
        _values[measurement] = value;
    }

    if (isFinal) {
        [_finishedMeasurements addObject:measurement];
    }

    if (![_currentMeasurement isEqualToString:measurement]) {
        _currentMeasurement = measurement;
        [self.tableView reloadData];
    } else {
        NSInteger i = [[self.class allMeasurements] indexOfObject:measurement];
        if (i != NSNotFound) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:i inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
            });
        } else {
            NSParameterAssert(false);
        }
    }
}

- (NSString*)formatValue:(id)value forMeasurement:(NSString*)measurement {
    if (!value) return nil;

    if ([measurement isEqualToString:RMBTLoopMeasurementDown] || [measurement isEqualToString:RMBTLoopMeasurementUp]) {
        return [NSString stringWithFormat:@"%.2f", [(NSNumber*)value doubleValue]/1e3f];
    } else if ([measurement isEqualToString:RMBTLoopMeasurementPing]) {
        return [NSString stringWithFormat:@"%.2f", [(NSNumber*)value doubleValue]/NSEC_PER_MSEC];
    } else if ([value isKindOfClass:[NSString class]]){
        return value;
    } else {
        NSParameterAssert(false);
        return @"";
    }
}

- (NSString*)localizedMeasurementName:(NSString*)measurement {
    NSString *suffix;
    if ([measurement isEqualToString:RMBTLoopMeasurementDown] || [measurement isEqualToString:RMBTLoopMeasurementUp]) {
        suffix = RMBTSpeedMbpsSuffix();
    } else if ([measurement isEqualToString:RMBTLoopMeasurementPing]) {
        suffix = @"ms";
    }
    return [NSString stringWithFormat:@"%@%@", measurement, suffix ? [NSString stringWithFormat:@" (%@)", suffix] : @""];
}


#pragma mark - UITableViewController

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.class allMeasurements].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    RMBTLoopMeasurementCell *cell = (RMBTLoopMeasurementCell*)[tableView dequeueReusableCellWithIdentifier:@"loop_measurement_cell" forIndexPath:indexPath];
    NSParameterAssert(cell);

    NSString *m = [[self.class allMeasurements] objectAtIndex:indexPath.row];
    NSParameterAssert(m);

    cell.measurementNameLabel.text = [self localizedMeasurementName:m];
    cell.currentValueLabel.text = [self formatValue:_values[m] forMeasurement:m];
    cell.medianValueLabel.text = [self formatValue:_medians[m] forMeasurement:m];

    cell.checkMarkImageView.hidden = !_active || ![_finishedMeasurements containsObject:m];
    if (cell.checkMarkImageView.hidden && [_currentMeasurement isEqualToString:m]) {
        [cell.activityIndicatorView startAnimating];
    } else {
        [cell.activityIndicatorView stopAnimating];
    }
    return cell;
}

@end
