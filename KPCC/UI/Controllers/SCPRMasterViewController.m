//
//  SCPRMasterViewController.m
//  KPCC
//
//  Created by John Meeker on 8/8/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "SCPRMasterViewController.h"

@interface SCPRMasterViewController () <AudioManagerDelegate>

@end

@implementation SCPRMasterViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    // Set the current view to recieve events from the AudioManagerDelegate.
    [AudioManager shared].delegate = self;

    [self updateControlsAndUI];
}

- (IBAction)playOrPauseTapped:(id)sender {
//    Swifty!
//
//    if !AudioManager.shared().isStreamPlaying() {
//        if AudioManager.shared().isStreamBuffering() {
//            AudioManager.shared().stopAllAudio()
//            JDStatusBarNotification.dismiss()
//        } else {
//            playStream()
//        }
//    } else {
//        pauseStream()
//    }


    if (![[AudioManager shared] isStreamPlaying]) {
        if ([[AudioManager shared] isStreamBuffering]) {
            [[AudioManager shared] stopAllAudio];
            // Dismiss JDStatusBar
        } else {
            [self playStream];
        }
    } else {
        [self pauseStream];
    }
    //updateNowPlayingInfoWithProgram(currentProgram)
}

- (void)playStream {
    [[AudioManager shared] startStream];
}

- (void)pauseStream {
    [[AudioManager shared] pauseStream];
}
- (void)receivePlayerStateNotification {
    [self updateControlsAndUI];
}

- (void)updateControlsAndUI {

    if ([[AudioManager shared] isStreamPlaying] || [[AudioManager shared] isStreamBuffering]) {
        [self.playPauseButton setImage:[UIImage imageNamed:@"btn_pause"] forState:UIControlStateNormal];
    } else {
        [self.playPauseButton setImage:[UIImage imageNamed:@"btn_play_large"] forState:UIControlStateNormal];
    }
}


#pragma mark - AudioManagerDelegate

-(void) onRateChange {
    [self updateControlsAndUI];
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
