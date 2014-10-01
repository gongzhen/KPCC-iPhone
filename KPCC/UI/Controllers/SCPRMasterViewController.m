//
//  SCPRMasterViewController.m
//  KPCC
//
//  Created by John Meeker on 8/8/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "SCPRMasterViewController.h"
#import "SCPRMenuButton.h"
#import "SCPRProgramsListViewController.h"
#import "AFNetworking.h"
#import "UIImageView+AFNetworking.h"

@interface SCPRMasterViewController () <AudioManagerDelegate, ContentProcessor, MenuButtonDelegate>

@property BOOL setPlaying;
@property BOOL seekRequested;
@property BOOL busyZoomAnim;

@property BOOL setForLiveStreamUI;
@property BOOL setForOnDemandUI;

@property IBOutlet NSLayoutConstraint *playerControlsTopYConstraint;
@property IBOutlet NSLayoutConstraint *playerControlsBottomYConstraint;
@end

@implementation SCPRMasterViewController

@synthesize pulldownMenu,
            seekRequested,
            setPlaying,
            busyZoomAnim,
            setForLiveStreamUI,
            setForOnDemandUI;

#pragma mark - UIViewController

// Allows for interaction with system audio controls.
- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (void)remoteControlReceivedWithEvent:(UIEvent *)event {
    // Handle remote audio control events.
    if (event.type == UIEventTypeRemoteControl) {
        if (event.subtype == UIEventSubtypeRemoteControlPlay ||
            event.subtype == UIEventSubtypeRemoteControlPause ||
            event.subtype == UIEventSubtypeRemoteControlTogglePlayPause) {
            //[self playOrPauseTapped:nil];
        } else if (event.subtype == UIEventSubtypeRemoteControlPreviousTrack) {
            [self rewindFifteen];
        } else if (event.subtype == UIEventSubtypeRemoteControlNextTrack) {
            [self fastForwardFifteen];
        }
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];

    pulldownMenu = [[SCPRPullDownMenu alloc] initWithView:self.view];
    [self.view addSubview:pulldownMenu];

    pulldownMenu.delegate = self;
    [pulldownMenu loadMenu];
    
    SCPRMenuButton *menuButton = [SCPRMenuButton buttonWithOrigin:CGPointMake(10.f, 10.f)];
    menuButton.delegate = self;
    //self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:menuButton];

    // Fetch program info and update audio control state.
    [self updateDataForUI];

    // Observe when the application becomes active again, and update UI if need-be.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateDataForUI) name:UIApplicationWillEnterForegroundNotification object:nil];

    // Make sure the system follows our playback status - to support the playback when the app enters the background mode.
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    [[AVAudioSession sharedInstance] setActive: YES error: nil];
    
    // Config blur view.
    [self.blurView setAlpha:0.0];
    [self.blurView setTintColor:[UIColor clearColor]];
    [self.blurView setBlurRadius:20.0f];
    [self.blurView setDynamic:NO];
    
    // Config dark background view. Will sit on top of blur view, between player controls view.
    [self.darkBgView setAlpha:0.0];

    MPRemoteCommandCenter *rcc = [MPRemoteCommandCenter sharedCommandCenter];

    MPSkipIntervalCommand *skipBackwardIntervalCommand = [rcc skipBackwardCommand];
    [skipBackwardIntervalCommand setEnabled:YES];
    [skipBackwardIntervalCommand addTarget:self action:@selector(skipBackwardEvent:)];
    skipBackwardIntervalCommand.preferredIntervals = @[@(15)];

    MPSkipIntervalCommand *skipForwardIntervalCommand = [rcc skipForwardCommand];
    skipForwardIntervalCommand.preferredIntervals = @[@(15)];  // Max 99
    [skipForwardIntervalCommand setEnabled:YES];
    [skipForwardIntervalCommand addTarget:self action:@selector(skipForwardEvent:)];

    MPRemoteCommand *pauseCommand = [rcc pauseCommand];
    [pauseCommand setEnabled:YES];
    [pauseCommand addTarget:self action:@selector(playOrPauseTapped:)];

    MPRemoteCommand *playCommand = [rcc playCommand];
    [playCommand setEnabled:YES];
    [playCommand addTarget:self action:@selector(playOrPauseTapped:)];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    // Set the current view to receive events from the AudioManagerDelegate.
    [AudioManager shared].delegate = self;

    if (self.menuOpen) {
        self.navigationItem.title = @"Menu";
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    // Once the view has appeared we can register to begin receiving system audio controls.
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    [self becomeFirstResponder];

    //[self updateControlsAndUI:YES];
}

-(void)skipBackwardEvent: (MPSkipIntervalCommandEvent *)skipEvent {
    NSLog(@"Skip backward by %f", skipEvent.interval);
    [self rewindFifteen];
}

-(void)skipForwardEvent: (MPSkipIntervalCommandEvent *)skipEvent {
    NSLog(@"Skip forward by %f", skipEvent.interval);
    [self fastForwardFifteen];
}

- (IBAction)playOrPauseTapped:(id)sender {
    if (seekRequested) {
        seekRequested = NO;
    }

    if (![[AudioManager shared] isStreamPlaying]) {
        self.setPlaying = YES;

        if ([[AudioManager shared] isStreamBuffering]) {
            [[AudioManager shared] stopAllAudio];
        } else {
            [self playStream];
        }
    } else {
        self.setPlaying = NO;

        [self pauseStream];
    }
}

- (IBAction)rewindToStartTapped:(id)sender {
    if (_currentProgram) {
        seekRequested = YES;
        [[AudioManager shared] seekToDate:_currentProgram.starts_at];
    }
}

- (IBAction)backToLiveTapped:(id)sender {
    seekRequested = YES;
    [[AudioManager shared] forwardSeekLive];
}

- (void)playStream {
    [[AudioManager shared] startStream];
}

- (void)pauseStream {
    [[AudioManager shared] pauseStream];
}

- (void)rewindFifteen {
    seekRequested = YES;
    [[AudioManager shared] backwardSeekFifteenSeconds];
}

- (void)fastForwardFifteen {
    seekRequested = YES;
    [[AudioManager shared] forwardSeekFifteenSeconds];
}

- (void)updateDataForUI {
    [[NetworkManager shared] fetchProgramInformationFor:[NSDate date] display:self];
}

- (void)updateControlsAndUI:(BOOL)animated {

    // First set contents of background, live-status labels, and play button.
    [self setUIContents:animated];

    // Set positioning of UI elements.
    [self setUIPositioning];
}

- (void)setUIContents:(BOOL)animated {

    if (animated) {
        [UIView animateWithDuration:0.1 animations:^{
            [self.playPauseButton setAlpha:0.0];

            if ([[AudioManager shared] isStreamPlaying] || [[AudioManager shared] isStreamBuffering]) {
                [self.liveDescriptionLabel setText:@"LIVE"];
                [self.rewindToShowStartButton setAlpha:0.0];
            } else {
                [self.liveDescriptionLabel setText:@"ON NOW"];
                [self.liveRewindAltButton setAlpha:0.0];
                [self.backToLiveButton setAlpha:0.0];
            }

        } completion:^(BOOL finished) {
            if ([[AudioManager shared] isStreamPlaying] || [[AudioManager shared] isStreamBuffering]) {
                [self.playPauseButton setImage:[UIImage imageNamed:@"btn_pause"] forState:UIControlStateNormal];
            } else {
                [self.playPauseButton setImage:[UIImage imageNamed:@"btn_play_large"] forState:UIControlStateNormal];
            }

            // Leave this out for now.
            // [self scaleBackgroundImage];

            [UIView animateWithDuration:0.1 animations:^{
                [self.playPauseButton setAlpha:1.0];
            }];
        }];

    } else {
        if ([[AudioManager shared] isStreamPlaying] || [[AudioManager shared] isStreamBuffering]) {
            [self.liveDescriptionLabel setText:@"LIVE"];
            [self.rewindToShowStartButton setAlpha:0.0];
        } else {
            [self.liveDescriptionLabel setText:@"ON NOW"];
            [self.liveRewindAltButton setAlpha:0.0];
            [self.backToLiveButton setAlpha:0.0];
        }

        if ([[AudioManager shared] isStreamPlaying] || [[AudioManager shared] isStreamBuffering]) {
            [self.playPauseButton setImage:[UIImage imageNamed:@"btn_pause"] forState:UIControlStateNormal];
        } else {
            [self.playPauseButton setImage:[UIImage imageNamed:@"btn_play_large"] forState:UIControlStateNormal];
        }
    }
}

- (void)setUIPositioning {

    if ([[AudioManager shared] isStreamPlaying] || [[AudioManager shared] isStreamBuffering]) {

        POPBasicAnimation *dividerFadeAnim = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
        dividerFadeAnim.toValue = @(0.4);
        [self.horizDividerLine.layer pop_addAnimation:dividerFadeAnim forKey:@"dividerFadeInAnim"];

        POPBasicAnimation *genericFadeInAnim = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
        genericFadeInAnim.toValue = @(1);
        [self.liveRewindAltButton.layer pop_addAnimation:genericFadeInAnim forKey:@"liveRewindFadeInAnim"];
        [self.backToLiveButton.layer pop_addAnimation:genericFadeInAnim forKey:@"backToLiveFadeInAnim"];

        POPBasicAnimation *genericFadeOutAnim = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
        genericFadeOutAnim.toValue = @(0);
        [self.rewindToShowStartButton.layer pop_addAnimation:genericFadeOutAnim forKey:@"rewindToStartFadeInAnim"];

        if (!seekRequested) {
            POPBasicAnimation *bottomAnim = [POPBasicAnimation animationWithPropertyNamed:kPOPLayoutConstraintConstant];
            bottomAnim.toValue = @(45);
            bottomAnim.duration = .3;
            [self.playerControlsBottomYConstraint pop_addAnimation:bottomAnim forKey:@"animatePlayControlsDown"];

            POPBasicAnimation *topAnim = [POPBasicAnimation animationWithPropertyNamed:kPOPLayoutConstraintConstant];
            topAnim.toValue = @(CGRectGetMaxY(self.view.frame) - 240);
            topAnim.duration = .3;
            [self.playerControlsTopYConstraint pop_addAnimation:topAnim forKey:@"animateTopPlayControlsDown"];
        }
    } else {
        if (!setPlaying) {
            POPBasicAnimation *genericFadeInAnim = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
            genericFadeInAnim.toValue = @(1);
            [self.rewindToShowStartButton.layer pop_addAnimation:genericFadeInAnim forKey:@"rewindToStartFadeInAnim"];

            POPBasicAnimation *dividerFadeAnim = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
            dividerFadeAnim.toValue = @(0);
            [self.horizDividerLine.layer pop_addAnimation:dividerFadeAnim forKey:@"dividerFadeOutAnim"];
        }

        if (!seekRequested) {
            POPBasicAnimation *bottomAnim = [POPBasicAnimation animationWithPropertyNamed:kPOPLayoutConstraintConstant];
            bottomAnim.toValue = @(220);
            bottomAnim.duration = .3;
            [self.playerControlsBottomYConstraint pop_addAnimation:bottomAnim forKey:@"animateBottomPlayControlsUp"];

            POPBasicAnimation *topAnim = [POPBasicAnimation animationWithPropertyNamed:kPOPLayoutConstraintConstant];
            topAnim.toValue = @(146);
            topAnim.duration = .3;
            [self.playerControlsTopYConstraint pop_addAnimation:topAnim forKey:@"animateTopPlayControlsUp"];
        }
    }
}

/**
 * Dev note: Not being called for now.. zooms in background program image slightly
 */
- (void)scaleBackgroundImage {
    POPSpringAnimation *scaleAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerScaleXY];

    if ([[AudioManager shared] isStreamPlaying] || [[AudioManager shared] isStreamBuffering]) {
        scaleAnimation.fromValue  = [NSValue valueWithCGSize:CGSizeMake(1.0f, 1.0f)];
        scaleAnimation.toValue  = [NSValue valueWithCGSize:CGSizeMake(1.2f, 1.2f)];
    } else {
        scaleAnimation.fromValue  = [NSValue valueWithCGSize:CGSizeMake(1.2f, 1.2f)];
        scaleAnimation.toValue  = [NSValue valueWithCGSize:CGSizeMake(1.0f, 1.0f)];
    }

    scaleAnimation.springBounciness = 2.0f;
    scaleAnimation.springSpeed = 2.0f;

    // Used to ensure animation only gets started once.
    // This method stems from onRateChange: firing, which sometimes gets called rapidly.
    [scaleAnimation setCompletionBlock:^(POPAnimation *animation, BOOL done) {
        busyZoomAnim = NO;
    }];

    if (!seekRequested && !busyZoomAnim) {
        busyZoomAnim = YES;
        [self.programImageView.layer pop_addAnimation:scaleAnimation forKey:@"scaleAnimation"];
    }
}

- (void)setLiveStreamingUI:(BOOL)animated {
    self.navigationItem.title = @"KPCC Live";

    if ([self.liveStreamView isHidden]) {
        [self.liveStreamView setHidden:NO];
    }

    if (![self.onDemandPlayerView isHidden]) {
        [self.onDemandPlayerView setHidden:YES];
        setForOnDemandUI = NO;
    }

    setForLiveStreamUI = YES;
}

- (void)setPausedUI:(BOOL)animated {

}

- (void)setOnDemandUI:(BOOL)animated withProgram:(Program *)program andEpisode:(NSObject *)episode {
    if (self.menuOpen) {
        [self decloakForMenu:NO];
    }

    self.navigationItem.title = @"Programs";

    // Update UILabels, content, etc.
    [self setDataForOnDemand:program andEpisode:episode];

    if ([self.onDemandPlayerView isHidden]) {
        [self.onDemandPlayerView setHidden:NO];
    }

    if (![self.liveStreamView isHidden]) {
        [self.liveStreamView setHidden:YES];
        setForLiveStreamUI = NO;
    }

    setForOnDemandUI = YES;
}

- (void)setDataForOnDemand:(Program *)program andEpisode:(NSObject *)episode {
    if (program != nil) {
        self.onDemandProgram = program;

        [self updateNowPlayingInfoWithProgram:program];

        [[DesignManager shared] loadProgramImage:program.program_slug
                                    andImageView:self.programImageView
                                      completion:^(BOOL status) {
                                          [self.blurView setNeedsDisplay];
                                      }];

        [self.programTitleOnDemand setText:[program.title uppercaseString]];
    }

    if (episode != nil) {
        if ([episode isKindOfClass:[Episode class]]) {
            Episode *ep = (Episode *) episode;
            [self.episodeTitleOnDemand setText:ep.title];
        } else {
            Segment *seg = (Segment *) episode;
            [self.episodeTitleOnDemand setText:seg.title];
        }
    }

    // TODO: Set handler for end of episode playback. Fallback/start livestream?
}

#pragma mark - Config for show and hide menu

- (void)cloakForMenu:(BOOL)animated {
    self.navigationItem.title = @"Menu";
    [self.blurView setNeedsDisplay];

    if (animated) {
        [pulldownMenu openDropDown:YES];
    } else {
        [pulldownMenu openDropDown:NO];
    }

    POPBasicAnimation *blurFadeAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    blurFadeAnimation.toValue = @1;
    blurFadeAnimation.duration = 0.3;

    POPBasicAnimation *darkBgFadeAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    darkBgFadeAnimation.toValue = @0.35;
    darkBgFadeAnimation.duration = 0.3;

    POPBasicAnimation *controlsFadeAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    controlsFadeAnimation.toValue = @(0);
    controlsFadeAnimation.duration = 0.3;

    [self.blurView.layer pop_addAnimation:blurFadeAnimation forKey:@"blurViewFadeAnimation"];
    [self.darkBgView.layer pop_addAnimation:darkBgFadeAnimation forKey:@"darkBgFadeAnimation"];
    [self.playerControlsView.layer pop_addAnimation:controlsFadeAnimation forKey:@"controlsViewFadeAnimation"];
    [self.onDemandPlayerView.layer pop_addAnimation:controlsFadeAnimation forKey:@"onDemandViewFadeAnimation"];
    [self.liveStreamView.layer pop_addAnimation:controlsFadeAnimation forKey:@"liveStreamViewFadeAnimation"];

    POPBasicAnimation *dividerFadeAnim = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    dividerFadeAnim.toValue = @0;
    dividerFadeAnim.duration = 0.3;
    [self.horizDividerLine.layer pop_addAnimation:dividerFadeAnim forKey:@"horizDividerOutFadeAnimation"];

    self.menuOpen = YES;
}

- (void)decloakForMenu:(BOOL)animated {
    if (setForOnDemandUI) {
        self.navigationItem.title = @"Programs";
    } else {
        self.navigationItem.title = @"KPCC Live";
    }

    [self.blurView setNeedsDisplay];

    if (animated) {
        [pulldownMenu closeDropDown:YES];
    } else {
        [pulldownMenu closeDropDown:NO];
    }

    POPBasicAnimation *fadeAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    fadeAnimation.toValue = @0;
    fadeAnimation.duration = 0.3;

    POPBasicAnimation *darkBgFadeAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    darkBgFadeAnimation.toValue = @0;
    darkBgFadeAnimation.duration = 0.3;

    POPBasicAnimation *controlsFadeAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    controlsFadeAnimation.toValue = @1;
    controlsFadeAnimation.duration = 0.3;

    [self.blurView.layer pop_addAnimation:fadeAnimation forKey:@"blurViewFadeAnimation"];
    [self.darkBgView.layer pop_addAnimation:darkBgFadeAnimation forKey:@"darkBgFadeAnimation"];
    [self.playerControlsView.layer pop_addAnimation:controlsFadeAnimation forKey:@"controlsViewFadeAnimation"];
    [self.onDemandPlayerView.layer pop_addAnimation:controlsFadeAnimation forKey:@"onDemandViewFadeAnimation"];
    [self.liveStreamView.layer pop_addAnimation:controlsFadeAnimation forKey:@"liveStreamViewFadeAnimation"];

    if ([[AudioManager shared] isStreamPlaying]) {
        POPBasicAnimation *dividerFadeAnim = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
        dividerFadeAnim.toValue = @0.4;
        dividerFadeAnim.duration = 0.3;
        [self.horizDividerLine.layer pop_addAnimation:dividerFadeAnim forKey:@"horizDividerFadeOutAnimation"];
    }

    self.menuOpen = NO;
}


# pragma mark - PulldownMenuDelegate

- (void)menuItemSelected:(NSIndexPath *)indexPath {
    switch (indexPath.row) {
        case 0:{
            [[AudioManager shared] stopAllAudio];
            [self updateDataForUI];
            [self setLiveStreamingUI:YES];
            [self decloakForMenu:YES];
            [[AudioManager shared] startStream];
            break;
        }

        case 1: {
            Program *prog = self.currentProgram;
            if (setForOnDemandUI && self.onDemandProgram != nil) {
                prog = self.onDemandProgram;
            }
            SCPRProgramsListViewController *vc = [[SCPRProgramsListViewController alloc] initWithBackgroundProgram:prog];
            [self.navigationController pushViewController:vc animated:YES];
            break;
        }

        default: {
            [self decloakForMenu:YES];
            break;
        }
    }
}

- (void)pullDownAnimated:(BOOL)open {
    if (open) {
        NSLog(@"Pull down menu open %@", NSStringFromCGRect(pulldownMenu.menuList.frame));
        [[NSNotificationCenter defaultCenter] postNotificationName:@"pull_down_menu_opened"
                                                            object:nil];
    } else {
        NSLog(@"Pull down menu closed %@", NSStringFromCGRect(pulldownMenu.frame));
        [[NSNotificationCenter defaultCenter] postNotificationName:@"pull_down_menu_closed"
                                                            object:nil];
    }
}

- (void)updateUIWithProgram:(Program*)program {
    if (!program) {
        return;
    }

    if ([program title]) {
        if ([program title].length <= 14) {
            [self.programTitleLabel setFont:[self.programTitleLabel.font fontWithSize:46.0]];
        } else if ([program title].length > 14 && [program title].length <= 18) {
            [self.programTitleLabel setFont:[self.programTitleLabel.font fontWithSize:35.0]];
        } else {
            [self.programTitleLabel setFont:[self.programTitleLabel.font fontWithSize:30.0]];
        }
        [self.programTitleLabel setText:[program title]];
    }
}

- (void)updateNowPlayingInfoWithProgram:(Program*)program {
    if (!program) {
        return;
    }

    NSDictionary *audioMetaData = @{ MPMediaItemPropertyArtist : @"89.3 KPCC",
                                     MPMediaItemPropertyTitle : program.title//,
                                     /*MPNowPlayingInfoPropertyPlaybackRate : [[NSNumber alloc] initWithFloat:10],
                                     MPMediaItemPropertyAlbumTitle : @"LIVE",
                                     MPNowPlayingInfoPropertyElapsedPlaybackTime: [[NSNumber alloc] initWithDouble:40]*/ };

    [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:audioMetaData];
}


# pragma mark - AudioManagerDelegate

- (void)onRateChange {
    [self updateControlsAndUI:YES];
}

- (void)onTimeChange {
    if ([[[AudioManager shared] maxSeekableDate] timeIntervalSinceDate:[[AudioManager shared] currentDate]] > 60) {
        NSTimeInterval ti = [[[AudioManager shared] maxSeekableDate] timeIntervalSinceDate:[[AudioManager shared] currentDate]];
        NSInteger mins = (ti/60);

        [self.liveDescriptionLabel setText:[NSString stringWithFormat:@"%li MINUTES BEHIND LIVE", (long)mins]];
        [self.backToLiveButton setHidden:NO];
    } else {
        [self.liveDescriptionLabel setText:@"LIVE"];
        [self.backToLiveButton setHidden:YES];
    }

    if (setForOnDemandUI) {
        NSLog(@"elapsed: %@",[Utils elapsedTimeStringWithPosition:CMTimeGetSeconds([[[AudioManager shared] playerItem] currentTime])
                                                      andDuration:CMTimeGetSeconds([[[[AudioManager shared] playerItem] asset] duration])]);

        [self.timeLabelOnDemand setText:[Utils elapsedTimeStringWithPosition:CMTimeGetSeconds([[[AudioManager shared] playerItem] currentTime])
                                                                 andDuration:CMTimeGetSeconds([[[[AudioManager shared] playerItem] asset] duration])]];

        NSLog(@"width test: %f", CMTimeGetSeconds([[[AudioManager shared] playerItem] currentTime]) / CMTimeGetSeconds([[[[AudioManager shared] playerItem] asset] duration]) * (self.view.frame.size.width - 20));
        [self.progressBarView setFrame:CGRectMake(self.progressBarView.frame.origin.x,
                                                  self.progressBarView.frame.origin.y,
                                                  CMTimeGetSeconds([[[AudioManager shared] playerItem] currentTime]) / CMTimeGetSeconds([[[[AudioManager shared] playerItem] asset] duration]) * (self.view.frame.size.width - 20),
                                                  self.progressBarView.frame.size.height)];
    }
}

- (void)onSeekCompleted {
    // Make sure UI gets set to "Playing" state after a seek.
    if (!setPlaying) {
        seekRequested = NO;
        [self setUIPositioning];
        setPlaying = YES;
    }
}


#pragma mark - ContentProcessor 

- (void)handleProcessedContent:(NSArray *)content flags:(NSDictionary *)flags {
    if ([content count] == 0) {
        return;
    }

    // Create Program and insert into managed object context
    if ([content objectAtIndex:0]) {
        NSDictionary *programDict = [content objectAtIndex:0];

        Program *programObj = [Program insertProgramWithDictionary:programDict inManagedObjectContext:[[ContentManager shared] managedObjectContext]];

        // Only update background image when we're not in On Demand mode.
        if (!setForOnDemandUI){
            [[DesignManager shared] loadProgramImage:programObj.program_slug
                                        andImageView:self.programImageView
                                          completion:^(BOOL status) {
                                              [self.blurView setNeedsDisplay];
                                          }];
        }

        [self updateUIWithProgram:programObj];

        if (!setForOnDemandUI) {
            [self updateNowPlayingInfoWithProgram:programObj];
        }

        self.currentProgram = programObj;

        // Save any programObj changes to CoreData.
        [[ContentManager shared] saveContext];
    }
}

- (void)dealloc {
    //End receiving events.
    [[UIApplication sharedApplication] endReceivingRemoteControlEvents];
    [self resignFirstResponder];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
