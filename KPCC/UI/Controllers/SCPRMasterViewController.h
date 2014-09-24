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
#import "SCPRPullDownMenu.h"

@interface SCPRMasterViewController : UIViewController<PulldownMenuDelegate>

@property IBOutlet UILabel *programTitleLabel;
@property IBOutlet UIImageView *programImageView;
@property IBOutlet UIButton *playPauseButton;
@property IBOutlet UIButton *rewindToShowStartButton;
@property IBOutlet UIButton *liveRewindAltButton;
@property IBOutlet UILabel *liveDescriptionLabel;
@property IBOutlet UIView *horizDividerLine;
@property IBOutlet UIButton *backToLiveButton;
@property IBOutlet FXBlurView *blurView;
@property IBOutlet UIView *darkBgView;

@property IBOutlet UIView *playerControlsView;
@property IBOutlet UIView *onDemandPlayerView;

@property (nonatomic,strong) Program *currentProgram;
@property (nonatomic,strong) SCPRPullDownMenu *pulldownMenu;
@property Boolean seekRequested;

- (void)cloakForMenu:(BOOL)animated;
- (void)decloakForMenu:(BOOL)animated;

- (void)setOnDemandUI:(BOOL)animated;
- (void)setLiveStreamingUI:(BOOL)animated;

@end
