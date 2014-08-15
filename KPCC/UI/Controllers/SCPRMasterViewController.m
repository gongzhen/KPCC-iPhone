//
//  SCPRMasterViewController.m
//  KPCC
//
//  Created by John Meeker on 8/8/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "SCPRMasterViewController.h"

@interface SCPRMasterViewController () <AudioManagerDelegate, ContentProcessor>

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
            [self playOrPauseTapped:nil];
        } else if (event.subtype == UIEventSubtypeRemoteControlPreviousTrack) {
            [self rewindFifteen];
        } else if (event.subtype == UIEventSubtypeRemoteControlNextTrack) {
            [self fastForwardFifteen];
        }
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    // Set the current view to recieve events from the AudioManagerDelegate.
    [AudioManager shared].delegate = self;

    [self updateControlsAndUI];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // Fetch program info and update audio control state.
    [self updateDataForUI];
    
    // Make sure the system follows our playback status - to support the playback when the app enters the background mode.
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    [[AVAudioSession sharedInstance] setActive: YES error: nil];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    // Once the view has appeared we can register to begin receiving system audio controls.
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    [self becomeFirstResponder];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];

    //End receiving events.
    [[UIApplication sharedApplication] endReceivingRemoteControlEvents];
    [self resignFirstResponder];
}

- (IBAction)playOrPauseTapped:(id)sender {
    if (![[AudioManager shared] isStreamPlaying]) {
        if ([[AudioManager shared] isStreamBuffering]) {
            [[AudioManager shared] stopAllAudio];
        } else {
            [self playStream];
        }
    } else {
        [self pauseStream];
    }
}

- (IBAction)rewindToStartTapped:(id)sender {
    if (_currentProgram) {
        [[AudioManager shared] seekToDate:_currentProgram.starts_at];
    }
}

- (void)playStream {
    [[AudioManager shared] startStream];
}

- (void)pauseStream {
    [[AudioManager shared] pauseStream];
}

- (void)rewindFifteen {
    [[AudioManager shared] backwardSeekFifteenSeconds];
}

- (void)fastForwardFifteen {
    [[AudioManager shared] forwardSeekFifteenSeconds];
}

- (void)receivePlayerStateNotification {
    [self updateControlsAndUI];
}

- (void)updateDataForUI {
    [[NetworkManager shared] fetchProgramInformationFor:[NSDate date] display:self];
}

- (void)updateControlsAndUI {
    [UIView animateWithDuration:0.1 animations:^{
        [self.playPauseButton setAlpha:0.0];

        if ([[AudioManager shared] isStreamPlaying] || [[AudioManager shared] isStreamBuffering]) {
            [self.liveDescriptionLabel setText:@"LIVE"];
            [self.rewindToShowStartButton setAlpha:0.0];
        } else {
            [self.liveDescriptionLabel setText:@"ON NOW"];
            [self.liveRewindAltButton setAlpha:0.0];
        }
        
    } completion:^(BOOL finished) {

        CGAffineTransform t;// = CGAffineTransformMakeScale(1.2, 1.2);

        if ([[AudioManager shared] isStreamPlaying] || [[AudioManager shared] isStreamBuffering]) {
            [self.playPauseButton setImage:[UIImage imageNamed:@"btn_pause"] forState:UIControlStateNormal];

            /*[self.playPauseButton setFrame:CGRectMake(_playPauseButton.frame.origin.x,
                                                      385.0,
                                                      _playPauseButton.frame.size.width,
                                                      _playPauseButton.frame.size.height)];*/

            t = CGAffineTransformMakeScale(1.2, 1.2);

        } else {
            [self.playPauseButton setImage:[UIImage imageNamed:@"btn_play_large"] forState:UIControlStateNormal];

/*            [self.playPauseButton setFrame:CGRectMake(_playPauseButton.frame.origin.x,
                                                      225.0,
                                                      _playPauseButton.frame.size.width,
                                                      _playPauseButton.frame.size.height)];*/

            t = CGAffineTransformMakeScale(1.0, 1.0);
        }

        CGPoint center = _programImageView.center; // or any point you want
        [UIView animateWithDuration:0.25 animations:^{
            //_programImageView.transform = t;
            //_programImageView.center = center;
        }];


        [UIView animateWithDuration:0.1 animations:^{
            [self.playPauseButton setAlpha:1.0];
        }];
    }];


    [UIView animateWithDuration:0.25 animations:^{

        if ([[AudioManager shared] isStreamPlaying] || [[AudioManager shared] isStreamBuffering]) {
            
            [self.horizDividerLine setAlpha:0.4];
            [self.liveRewindAltButton setAlpha:1.0];

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

        } else {

            [self.rewindToShowStartButton setAlpha:1.0];
            [self.horizDividerLine setAlpha:0.0];

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
        }
    }];

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
    [self updateControlsAndUI];
}


#pragma mark - ContentProcessor 

- (void)handleProcessedContent:(NSArray *)content flags:(NSDictionary *)flags {
    if ([content count] == 0) {
        return;
    }

    // Create Program and insert into managed object context
    if ([content objectAtIndex:0]) {
        NSDictionary *programDict = [content objectAtIndex:0];

        Program *programObj = [Program insertNewObjectIntoContext:[[ContentManager shared] managedObjectContext]];

        if ([programDict objectForKey:@"title"]) {
            programObj.title = [programDict objectForKey:@"title"];
        }

        [self updateUIWithProgram:programObj];

        self.currentProgram = programObj;
        [self updateNowPlayingInfoWithProgram:programObj];

        // Save the Program to persistant storage.
        [[ContentManager shared] saveContext];
    }
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
