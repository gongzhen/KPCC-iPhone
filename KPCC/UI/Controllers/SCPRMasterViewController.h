//
//  SCPRMasterViewController.h
//  KPCC
//
//  Created by John Meeker on 8/8/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Utils.h"
#import "AudioManager.h"
#import "NetworkManager.h"
#import "DesignManager.h"
#import "Program.h"
#import "FXBlurView.h"
#import <pop/POP.h>
#import "PulldownMenu.h"

@interface SCPRMasterViewController : UIViewController<PulldownMenuDelegate> {
    PulldownMenu *pulldownMenu;
}

@property IBOutlet UILabel *programTitleLabel;
@property IBOutlet UIImageView *programImageView;
@property IBOutlet UIButton *playPauseButton;
@property IBOutlet UIButton *rewindToShowStartButton;
@property IBOutlet UIButton *liveRewindAltButton;
@property IBOutlet UILabel *liveDescriptionLabel;
@property IBOutlet UIView *horizDividerLine;
@property IBOutlet UIButton *backToLiveButton;
@property IBOutlet FXBlurView *blurView;
@property IBOutlet UIView *playerControlsView;

@property (nonatomic,strong) Program *currentProgram;
@property Boolean seekRequested;

- (void)cloakForMenu:(BOOL)animated;
- (void)decloakForMenu:(BOOL)animated;

@end
