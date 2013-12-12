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

#import <UIKit/UIKit.h>
#import <CoreLocation/CLLocation.h>
#import "RMBTMapOptions.h"

@interface RMBTMapViewController : UIViewController

@property (nonatomic, strong) IBOutlet UIButton *locateMeButton;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *toastBarButtonItem;
@property (nonatomic, strong) IBOutlet UIView *toastView;
@property (nonatomic, strong) IBOutlet UILabel *toastTitleLabel, *toastKeysLabel, *toastValuesLabel;

// If set, blue pin will be shown at this location and map initially zoomed here. Used to
// display a test on the map.
@property (nonatomic, retain) CLLocation* initialLocation;

- (IBAction)toggleToast:(id)sender;
- (IBAction)locateMe:(id)sender;

@end
