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
#import "QueueManager.h"
#import "Program.h"
#import "FXBlurView.h"
#import <pop/POP.h>
#import "SCPRPullDownMenu.h"
#import "Episode.h"
#import "Segment.h"
#import "SCPRJogShuttleViewController.h"
#import "SCPRPreRollViewController.h"
#import "SCPRProgressViewController.h"

@interface SCPRMasterViewController : UIViewController<SCPRMenuDelegate>

@property IBOutlet UILabel *programTitleLabel;
@property IBOutlet UIImageView *programImageView;
@property IBOutlet UIButton *playPauseButton;
@property IBOutlet UIButton *initialPlayButton;
@property IBOutlet UIButton *rewindToShowStartButton;
@property IBOutlet UIButton *liveRewindAltButton;
@property IBOutlet UILabel *liveDescriptionLabel;
@property IBOutlet UIView *horizDividerLine;
@property IBOutlet UIButton *backToLiveButton;
@property IBOutlet FXBlurView *blurView;
@property IBOutlet UIView *darkBgView;

@property NSInteger tickCounter;

// For audio queue
@property (nonatomic,strong) UIScrollView *queueScrollView;
@property (nonatomic) int queueCurrentPage;
@property IBOutlet FXBlurView *queueBlurView;
@property IBOutlet UIView *queueDarkBgView;
@property (nonatomic,strong) NSTimer *queueScrollTimer;
@property (nonatomic,strong) NSArray *queueContents;

// Major holder views for different playback states.
@property IBOutlet UIView *liveStreamView;
@property IBOutlet UIView *onDemandPlayerView;
@property IBOutlet UIView *playerControlsView;
@property IBOutlet UIView *initialControlsView;


// Views for On-Demand playback;
@property IBOutlet UILabel *programTitleOnDemand;
@property IBOutlet UIView *dividerOnDemand;
@property IBOutlet UILabel *timeLabelOnDemand;
@property IBOutlet UIButton *shareButton;
@property IBOutlet UIProgressView *progressView;


// Important Attrs.
@property (nonatomic,strong) Program *currentProgram;
@property (nonatomic,strong) Program *onDemandProgram;
@property (nonatomic,strong) NSString *onDemandEpUrl;
@property (nonatomic,strong) SCPRPullDownMenu *pulldownMenu;
@property (nonatomic) BOOL menuOpen;
@property (nonatomic) BOOL preRollOpen;


// Live
@property (nonatomic,strong) SCPRProgressViewController *liveProgressViewController;
@property (nonatomic,strong) IBOutlet UIView *liveProgressView;
@property (nonatomic,strong) IBOutlet UIView *currentProgressBarView;
@property (nonatomic,strong) IBOutlet UIView *liveProgressBarView;

// Pre-Roll
@property (nonatomic,strong) SCPRPreRollViewController *preRollViewController;

// Rewinding UI
@property (nonatomic,strong) SCPRJogShuttleViewController *jogShuttle;
@property (nonatomic,strong) IBOutlet UIView *rewindView;
@property BOOL rewindGate;

- (void)activateRewind:(RewindDistance)distance;
- (void)activateFastForward;
- (void)snapJogWheel;
- (BOOL)uiIsJogging;
- (NSTimeInterval)rewindAgainstStreamDelta;

// Instance methods.
- (void)cloakForMenu:(BOOL)animated;
- (void)decloakForMenu:(BOOL)animated;

- (void)setOnDemandUI:(BOOL)animated forProgram:(Program*)program withAudio:(NSArray*)array atCurrentIndex:(int)index;
- (void)setLiveStreamingUI:(BOOL)animated;
- (void)setPositionForQueue:(int)index animated:(BOOL)animated;

- (void)treatUIforProgram;

- (void)moveTextIntoPlace:(BOOL)animated;
- (void)goLive;

@end
