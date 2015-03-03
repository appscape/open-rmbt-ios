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
#import "RMBTHistoryResult.h"
#import "RMBTSpeedGraphView.h"

@class RMBTTestViewController;

@protocol RMBTTestViewControllerDelegate<NSObject>
- (void)testViewController:(RMBTTestViewController*)controller didFinishWithTestResult:(RMBTHistoryResult*)result;
@end

@interface RMBTTestViewController : UIViewController

@property (nonatomic, weak) id<RMBTTestViewControllerDelegate> delegate;

// This will hide the network name label in case of cellular connection
@property (nonatomic, assign) BOOL roaming;

// Network name and type
@property (nonatomic, strong) IBOutlet UILabel *networkTypeLabel, *networkNameLabel;
@property (nonatomic, strong) IBOutlet UIImageView *networkTypeImageView;

// Progress
@property (nonatomic, strong) IBOutlet UILabel *progressLabel;
@property (nonatomic, strong) IBOutlet UIImageView *progressGaugePlaceholderView;

// Results
@property (nonatomic, strong) IBOutlet UILabel *pingResultLabel, *downResultLabel, *upResultLabel;

// Speed chart
@property (nonatomic, strong) IBOutlet UIImageView *speedGaugePlaceholderView;
@property (nonatomic, strong) IBOutlet RMBTSpeedGraphView *speedGraphView;
@property (nonatomic, strong) IBOutlet UIImageView *arrowImageView;
@property (nonatomic, strong) IBOutlet UILabel *speedLabel, *speedSuffixLabel;


// Footer
@property (nonatomic, strong) IBOutlet UILabel *footerStatusLabel;
@property (nonatomic, strong) IBOutlet UILabel *footerTestServerLabel;
@property (nonatomic, strong) IBOutlet UILabel *footerLocalIpLabel;
@property (nonatomic, strong) IBOutlet UILabel *footerLocationLabel;
@property (nonatomic, strong) IBOutlet UILabel *footerLoopLabel;

// Layout constraints
@property (nonatomic, strong) IBOutlet NSLayoutConstraint *networkSymbolTopConstraint, *networkSymbolLeftConstraint;
@property (nonatomic, strong) IBOutlet NSLayoutConstraint *networkNameWidthConstraint;
@property (nonatomic, strong) IBOutlet NSLayoutConstraint *testServerLabelHeightConstraint;
@property (nonatomic, strong) IBOutlet NSLayoutConstraint *speedGraphBottomConstraint;
@property (nonatomic, strong) IBOutlet NSLayoutConstraint *progressGaugeTopConstraint;
@property (nonatomic, strong) IBOutlet NSLayoutConstraint *footerBottomConstraint;
@end
