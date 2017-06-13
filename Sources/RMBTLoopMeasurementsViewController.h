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

#import <UIKit/UIKit.h>


extern NSString * const RMBTLoopMeasurementPing;
extern NSString * const RMBTLoopMeasurementDown;
extern NSString * const RMBTLoopMeasurementUp;
extern NSString * const RMBTLoopMeasurementQoS;

@interface RMBTLoopMeasurementCell : UITableViewCell
@property (nonatomic, weak) IBOutlet UILabel *measurementNameLabel;
@property (nonatomic, weak) IBOutlet UILabel *currentValueLabel;
@property (nonatomic, weak) IBOutlet UILabel *medianValueLabel;
@property (nonatomic, weak) IBOutlet UIActivityIndicatorView *activityIndicatorView;
@property (nonatomic, weak) IBOutlet UIImageView *checkMarkImageView;
@end

@interface RMBTLoopMeasurementsViewController : UITableViewController

//@property (nonatomic, weak) IBOutlet UILabel *leftHeaderLabel;
@property (nonatomic, weak) IBOutlet UILabel *middleHeaderLabel;
@property (nonatomic, weak) IBOutlet UILabel *rightHeaderLabel;


// Prepares the view for next test iteration
- (void)start;

// Sets the current value for a measurement. Boolean flag final is used to update the UI.
- (void)setValue:(id)value forMeasurement:(NSString*)measurement final:(BOOL)isFinal;

// Moves set values to median and updates the UI/titles
- (void)finish;

// Marks current test as cancelled, updating the UI but not updating the median values
- (void)cancel;
@end
