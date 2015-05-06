//
//  SCPRCurrentProgramViewController.h
//  KPCC
//
//  Created by Ben Hochberg on 5/5/15.
//  Copyright (c) 2015 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SCPRCurrentProgramViewController : UIViewController

@property IBOutlet UILabel *upNextLabel;
@property IBOutlet UILabel *programTitleLabel;
@property IBOutlet UIImageView *avatarImageView;
@property IBOutlet UIImageView *clockImageView;
@property IBOutlet UILabel *timeLabel;
@property IBOutlet UIView *dividerViewLeft;
@property IBOutlet UIView *dividerViewRight;
@property IBOutlet UIButton *viewFullScheduleButton;

@end
