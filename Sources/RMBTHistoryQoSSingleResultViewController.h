//
//  RMBTHistoryQoSSingleResultViewController.h
//  RMBT
//
//  Created by Esad Hajdarevic on 20/12/16.
//  Copyright © 2016 appscape gmbh. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "RMBTHistoryQoSSingleResult.h"

@interface RMBTHistoryQoSSingleResultViewController : UITableViewController

@property (nonatomic, weak) IBOutlet UIImageView *statusIconImageView;


@property (nonatomic, retain) RMBTHistoryQoSSingleResult *result;
@property (nonatomic, assign) NSUInteger seqNumber;
@end
