//
//  SCPRProgramsTableViewController.h
//  KPCC
//
//  Created by John Meeker on 9/15/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Program.h"

@interface SCPRProgramsTableViewController : UITableViewController
- (id)initWithBackgroundProgram:(Program*)program;
@end
