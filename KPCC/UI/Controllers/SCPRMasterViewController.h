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
#import "SCPRButton.h"
#import "SCPRScrubbingUIViewController.h"
#import "SCPRTouchableScrubberView.h"

@interface SCPRMasterViewController : UIViewController<SCPRMenuDelegate,UIAlertViewDelegate>

@property IBOutlet UILabel *programTitleLabel;
@property IBOutlet UIImageView *programImageView;
@property IBOutlet SCPRButton *playPauseButton;
@property IBOutlet SCPRButton *initialPlayButton;
@property IBOutlet UIButton *rewindToShowStartButton;
@property IBOutlet SCPRButton *liveRewindAltButton;
@property IBOutlet UILabel *liveDescriptionLabel;
@property IBOutlet UIView *horizDividerLine;
@property IBOutlet UIButton *backToLiveButton;
@property IBOutlet FXBlurView *blurView;
@property IBOutlet UIView *darkBgView;

@property (nonatomic,strong) MPVolumeView *mpvv;

@property NSInteger tickCounter;

// For audio queue
@property (nonatomic,strong) UIScrollView *queueScrollView;
@property (nonatomic) int queueCurrentPage;
@property IBOutlet UIImageView *queueBlurView;
@property IBOutlet UIView *queueDarkBgView;
@property (nonatomic,strong) NSTimer *queueScrollTimer;
@property (nonatomic,strong) NSArray *queueContents;
@property (nonatomic,strong) NSMutableArray *queueUIContents;
@property (nonatomic,strong) UIView *scrubbingTriggerView;


// Major holder views for different playback states.
@property IBOutlet UIView *liveStreamView;
@property IBOutlet UIView *onDemandPlayerView;
@property IBOutlet UIView *playerControlsView;
@property IBOutlet UIView *initialControlsView;


// Views for On-Demand playback;
@property IBOutlet UILabel *programTitleOnDemand;
@property IBOutlet UIView *dividerOnDemand;
@property IBOutlet UILabel *timeLabelOnDemand;
@property IBOutlet SCPRButton *shareButton;
@property IBOutlet UIProgressView *progressView;

- (void)onDemandFadeDown;


// Important Attrs.
@property (nonatomic,strong) Program *currentProgram;
@property (nonatomic,strong) Program *onDemandProgram;
@property (nonatomic,strong) NSString *onDemandEpUrl;
@property (nonatomic,strong) SCPRPullDownMenu *pulldownMenu;
@property (nonatomic) BOOL menuOpen;
@property (nonatomic) BOOL preRollOpen;

// Controllable Constraints
@property (nonatomic,strong) IBOutlet NSLayoutConstraint *initialControlsYConstraint;

// Live
@property (nonatomic,strong) SCPRProgressViewController *liveProgressViewController;
@property (nonatomic,strong) IBOutlet UIView *liveProgressView;
@property (nonatomic,strong) IBOutlet UIView *currentProgressBarView;
@property (nonatomic,strong) IBOutlet UIView *liveProgressBarView;

// Pre-Roll
- (void)handlePreRollControl:(BOOL)paused;

@property (nonatomic,strong) SCPRPreRollViewController *preRollViewController;
@property BOOL lockPreroll;

@property BOOL updaterArmed;

// Rewinding UI
@property (nonatomic,strong) SCPRJogShuttleViewController *jogShuttle;
@property (nonatomic,strong) IBOutlet UIView *rewindView;

@property (nonatomic,strong) NSMutableDictionary *originalFrames;

@property (nonatomic, strong) IBOutlet NSLayoutConstraint *liveRewindBottomYConstraint;
@property BOOL shuttlingGate;
@property BOOL initiateRewind;
@property BOOL rewindNeedsUIRefresh;
@property BOOL springLock;
@property BOOL lockPlayback;
@property BOOL lockAnimationUI;
@property BOOL promptedAboutFailureAlready;
@property BOOL recovering;
@property BOOL uiLocked;
@property BOOL dirtyFromFailure;
@property BOOL audioWasPlaying;
@property BOOL scrubberLoadingGate;
@property BOOL playStateGate;
@property BOOL onDemandPanning;
@property BOOL onDemandFailing;

@property NSInteger onDemandGateCount;
@property NSInteger previousRewindThreshold;

// Onboarding
@property BOOL automationMode;
@property (nonatomic,strong) IBOutlet UILabel *letsGoLabel;

- (void)activateRewind:(RewindDistance)distance;
- (void)activateFastForward;
- (void)snapJogWheel;
- (void)specialRewind;

// Scrubbing
- (void)bringUpScrubber;
- (void)cloakForScrubber;
- (void)decloakForScrubber;
- (void)primeScrubber;
- (void)addCloseButton;
- (void)killCloseButton;
- (void)finishedWithScrubber;
- (void)tickOnDemand;
- (void)beginScrubbingWaitMode;
- (void)endScrubbingWaitMode;

@property (nonatomic, strong) SCPRScrubbingUIViewController *scrubbingUI;
@property (nonatomic, strong) SCPRButton *scrubberCloseButton;
@property (nonatomic, strong) IBOutlet UIView *scrubbingUIView;
@property (nonatomic, strong) IBOutlet SCPRButton *back30Button;
@property (nonatomic, strong) IBOutlet SCPRButton *fwd30Button;
@property (nonatomic, strong) IBOutlet UIView *scrubberControlView;
@property (nonatomic, strong) IBOutlet UILabel *scrubberTimeLabel;
@property (nonatomic, strong) IBOutlet SCPRTouchableScrubberView *touchableScrubberView;
@property (nonatomic,strong) IBOutlet NSLayoutConstraint *topYScrubbingAnchor;
@property (nonatomic, strong) IBOutlet NSLayoutConstraint *back30VerticalAnchor;
@property (nonatomic, strong) IBOutlet NSLayoutConstraint *fwd30VerticalAnchor;

@property BOOL scrubbing;

@property (NS_NONATOMIC_IOSONLY, readonly) BOOL uiIsJogging;
@property (NS_NONATOMIC_IOSONLY, readonly) NSTimeInterval rewindAgainstStreamDelta;

// Instance methods.
- (void)cloakForMenu:(BOOL)animated;
- (void)decloakForMenu:(BOOL)animated;

- (void)setOnDemandUI:(BOOL)animated forProgram:(Program*)program withAudio:(NSArray*)array atCurrentIndex:(int)index;
- (void)setLiveStreamingUI:(BOOL)animated;
- (void)setPositionForQueue:(int)index animated:(BOOL)animated;
- (void)primeManualControlButton;
- (void)treatUIforProgram;
- (void)determinePlayState;

- (void)moveTextIntoPlace:(BOOL)animated;
- (void)goLive:(BOOL)play;
- (void)goLive:(BOOL)play smooth:(BOOL)smooth;
- (void)warnUserOfOnDemandFailures;

- (void)resetUI;

// Onboarding methods
- (void)primeOnboarding;
- (void)onboarding_revealPlayerControls;
- (void)onboarding_beginOnboardingAudio;
- (void)onboarding_rewindToBeginning;
- (void)onboarding_beginOutro;
- (void)onboarding_fin;

@property (nonatomic, strong) IBOutlet NSLayoutConstraint *imageTopConstraint;
@property BOOL onboardingRewindButtonShown;

- (void)rollInterferenceText;
- (void)showOnDemandOnboarding;
- (void)prettifyBehindLiveStatus;
- (void)handleResponseForNotification;

@end
