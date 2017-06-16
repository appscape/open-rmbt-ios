//
//  RMBTQoSProgressViewController.h
//  RMBT
//
//  Created by Esad Hajdarevic on 12/12/16.
//  Copyright © 2016 appscape gmbh. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "RMBTQoSTestGroup.h"

@interface RMBTQoSProgressCell : UITableViewCell
@property (nonatomic, weak) IBOutlet UILabel *descriptionLabel;
@property (nonatomic, weak) IBOutlet UIProgressView *progressView;
@end

@interface RMBTQoSProgressViewController : UITableViewController
@property (nonatomic, strong) NSArray<RMBTQoSTestGroup*> *testGroups;
- (void)updateProgress:(float)progress forGroup:(RMBTQoSTestGroup*)group;
@end
