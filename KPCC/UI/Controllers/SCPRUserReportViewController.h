//
//  SCPRUserReportViewController.h
//  KPCC
//
//  Created by John Meeker on 4/4/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SCPRUserReportViewController : UIViewController
@property IBOutlet UIBarButtonItem *cancelButton;
@property IBOutlet UIButton *sendReportButton;
@property IBOutlet UITextView *userReportDetails;
@property IBOutlet UILabel *versionNumberLabel;
@end
