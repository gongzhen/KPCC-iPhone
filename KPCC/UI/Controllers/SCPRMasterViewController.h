//
//  SCPRMasterViewController.h
//  KPCC
//
//  Created by John Meeker on 8/8/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AudioManager.h"
#import "NetworkManager.h"
#import "Program.h"

@interface SCPRMasterViewController : UIViewController

@property IBOutlet UILabel *programTitleLabel;
@property IBOutlet UIImageView *programImageView;
@property IBOutlet UIButton *playPauseButton;
@property IBOutlet UIButton *rewindToShowStartButton;
@property IBOutlet UIButton *liveRewindAltButton;
@property IBOutlet UILabel *liveDescriptionLabel;
@property IBOutlet UIView *horizDividerLine;

@property (nonatomic,strong) Program *currentProgram;
@property Boolean seekRequested;

@end
