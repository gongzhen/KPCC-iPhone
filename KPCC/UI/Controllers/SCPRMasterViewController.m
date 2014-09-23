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
@property BOOL menuOpen;
@property BOOL setPlaying;
@property BOOL backgroundZoomed;
@end

@implementation SCPRMasterViewController

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

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationItem.title = @"KPCC Live";

    // Set the current view to receive events from the AudioManagerDelegate.
    [AudioManager shared].delegate = self;

    if (self.menuOpen) {
        //[pulldownMenu loadMenu];
        //[pulldownMenu openDropDown:NO];
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
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:menuButton];

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

    //[self.navigationController.navigationBar.topItem setTitle:@"KPCC Live"];
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

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    // Once the view has appeared we can register to begin receiving system audio controls.
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    [self becomeFirstResponder];

    [self updateControlsAndUI:YES];
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
    if (_seekRequested) {
        _seekRequested = NO;
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
        _seekRequested = YES;
        [[AudioManager shared] seekToDate:_currentProgram.starts_at];
    }
}

- (IBAction)backToLiveTapped:(id)sender {
    _seekRequested = YES;
    [[AudioManager shared] forwardSeekLive];
}

- (void)playStream {
    [[AudioManager shared] startStream];
}

- (void)pauseStream {
    [[AudioManager shared] pauseStream];
}

- (void)rewindFifteen {
    _seekRequested = YES;
    [[AudioManager shared] backwardSeekFifteenSeconds];
}

- (void)fastForwardFifteen {
    _seekRequested = YES;
    [[AudioManager shared] forwardSeekFifteenSeconds];
}

- (void)receivePlayerStateNotification {
    [self updateControlsAndUI:YES];
}

- (void)updateDataForUI {
    [[NetworkManager shared] fetchProgramInformationFor:[NSDate date] display:self];
}

- (void)updateControlsAndUI:(BOOL)animated {

    // First set contents of background, live-status labels, and play button.
    [self setUIContents:animated];

    // Set positioning of UI elements.
    /*if (animated) {
        [UIView animateWithDuration:0.25 animations:^{
            [self setUIPositioning];
        }];
    } else {
        [self setUIPositioning];
    }*/
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

            POPSpringAnimation *scaleAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerScaleXY];

            if ([[AudioManager shared] isStreamPlaying] || [[AudioManager shared] isStreamBuffering]) {
                [self.playPauseButton setImage:[UIImage imageNamed:@"btn_pause"] forState:UIControlStateNormal];

                scaleAnimation.fromValue  = [NSValue valueWithCGSize:CGSizeMake(1.0f, 1.0f)];
                scaleAnimation.toValue  = [NSValue valueWithCGSize:CGSizeMake(1.2f, 1.2f)];
                self.backgroundZoomed = YES;
            } else {
                [self.playPauseButton setImage:[UIImage imageNamed:@"btn_play_large"] forState:UIControlStateNormal];

                scaleAnimation.fromValue  = [NSValue valueWithCGSize:CGSizeMake(1.2f, 1.2f)];
                scaleAnimation.toValue  = [NSValue valueWithCGSize:CGSizeMake(1.0f, 1.0f)];
                self.backgroundZoomed = NO;
            }

            scaleAnimation.springBounciness = 2.0f;
            scaleAnimation.springSpeed = 2.0f;
            if (!_seekRequested) {
                [self.programImageView.layer pop_addAnimation:scaleAnimation forKey:@"scaleAnimation"];
            }

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
        [self.horizDividerLine setAlpha:0.4];
        [self.liveRewindAltButton setAlpha:1.0];
        [self.backToLiveButton setAlpha:1.0];
        
        if (!_seekRequested) {
            POPBasicAnimation *playButtonAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerPositionY];
            playButtonAnimation.fromValue = @(self.playPauseButton.frame.origin.y);
            playButtonAnimation.toValue = @(self.playPauseButton.frame.origin.y + 50);
            [self.playPauseButton.layer pop_addAnimation:playButtonAnimation forKey:@"playButtonAnimation"];
            
        }

        /*if (!_seekRequested) {
            [self.playPauseButton setFrame:CGRectMake(_playPauseButton.frame.origin.x,
                                                      385.0,
                                                      _playPauseButton.frame.size.width,
                                                      _playPauseButton.frame.size.height)];

            [self.liveDescriptionLabel setFrame:CGRectMake(_liveDescriptionLabel.frame.origin.x,
                                                           286.0,
                                                           _liveDescriptionLabel.frame.size.width,
                                                           _liveDescriptionLabel.frame.size.height)];

            [self.programTitleLabel setFrame:CGRectMake(_programTitleLabel.frame.origin.x,
                                                        303.0,
                                                        _programTitleLabel.frame.size.width,
                                                        _programTitleLabel.frame.size.height)];
        }*/
    } else {
        if (!_setPlaying) {
            [self.rewindToShowStartButton setAlpha:1.0];
            [self.horizDividerLine setAlpha:0.0];
        }

        /*if (!_seekRequested) {
            [self.playPauseButton setFrame:CGRectMake(_playPauseButton.frame.origin.x,
                                                      225.0,
                                                      _playPauseButton.frame.size.width,
                                                      _playPauseButton.frame.size.height)];
            
            [self.liveDescriptionLabel setFrame:CGRectMake(_liveDescriptionLabel.frame.origin.x,
                                                           95.0,
                                                           _liveDescriptionLabel.frame.size.width,
                                                           _liveDescriptionLabel.frame.size.height)];
            
            [self.programTitleLabel setFrame:CGRectMake(_programTitleLabel.frame.origin.x,
                                                        113.0,
                                                        _programTitleLabel.frame.size.width,
                                                        _programTitleLabel.frame.size.height)];
        }*/
    }
}

- (void)setLiveStreamingUI:(BOOL)animated {
    
}

- (void)setPausedUI:(BOOL)animated {

}

- (void)setOnDemandUI:(BOOL)animated {
    
}


- (void)menuPressed {
    if (self.menuOpen) {
        [pulldownMenu closeDropDown:YES];
        [self decloakForMenu:YES];
    } else {
        [self cloakForMenu:YES];
        [pulldownMenu openDropDown:YES];
    }
    self.menuOpen = !self.menuOpen;
}

- (void)cloakForMenu:(BOOL)animated {
    [self.blurView setNeedsDisplay];

    POPBasicAnimation *blurFadeAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    blurFadeAnimation.toValue = @1;
    blurFadeAnimation.duration = 0.3;

    POPBasicAnimation *darkBgFadeAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    darkBgFadeAnimation.toValue = @0.35;
    darkBgFadeAnimation.duration = 0.3;

    POPBasicAnimation *controlsFadeAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    controlsFadeAnimation.toValue = @0;
    controlsFadeAnimation.duration = 0.3;

    [self.blurView.layer pop_addAnimation:blurFadeAnimation forKey:@"blurViewFadeAnimation"];
    [self.darkBgView.layer pop_addAnimation:darkBgFadeAnimation forKey:@"darkBgFadeAnimation"];
    [self.playerControlsView.layer pop_addAnimation:controlsFadeAnimation forKey:@"controlsViewFadeAnimation"];
}

- (void)decloakForMenu:(BOOL)animated {
    [self.blurView setNeedsDisplay];

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
}


# pragma mark - PulldownMenuDelegate

- (void)menuItemSelected:(NSIndexPath *)indexPath {
    
    SCPRProgramsListViewController *vc = [[SCPRProgramsListViewController alloc] initWithBackgroundProgram:self.currentProgram];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)pullDownAnimated:(BOOL)open {
    if (open) {
        NSLog(@"Pull down menu open!");
        [[NSNotificationCenter defaultCenter] postNotificationName:@"pull_down_menu_opened"
                                                            object:nil];
        //[menuButton animateToClose];
    } else {
        NSLog(@"Pull down menu closed!");
        [[NSNotificationCenter defaultCenter] postNotificationName:@"pull_down_menu_closed"
                                                            object:nil];
        //[menuButton animateToMenu];
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


#pragma mark - AudioManagerDelegate

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
}

- (void)onSeekCompleted {

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

        if (!_currentProgram || (![_currentProgram.program_slug isEqualToString:programObj.program_slug])){
            [[DesignManager shared] loadProgramImage:programObj.program_slug
                                        andImageView:self.programImageView
                                          completion:^(BOOL status) {
                                              [self.blurView setNeedsDisplay];
                                          }];
        }

        [self updateUIWithProgram:programObj];
        [self updateNowPlayingInfoWithProgram:programObj];

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
