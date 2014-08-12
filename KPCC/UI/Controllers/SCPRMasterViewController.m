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

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    // Set the current view to recieve events from the AudioManagerDelegate.
    [AudioManager shared].delegate = self;

    [self updateControlsAndUI];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.

    // Fetch program info and update audio control state.
    [self updateDataForUI];
}

- (IBAction)playOrPauseTapped:(id)sender {
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
- (void)receivePlayerStateNotification {
    [self updateControlsAndUI];
}

- (void)updateDataForUI {
    [[NetworkManager shared] fetchProgramInformationFor:[NSDate date] display:self];
}

- (void)updateControlsAndUI {
    [UIView animateWithDuration:0.1 animations:^{
        [self.playPauseButton setAlpha:0.0];
    } completion:^(BOOL finished) {
        if ([[AudioManager shared] isStreamPlaying] || [[AudioManager shared] isStreamBuffering]) {
            [self.playPauseButton setImage:[UIImage imageNamed:@"btn_pause"] forState:UIControlStateNormal];
        } else {
            [self.playPauseButton setImage:[UIImage imageNamed:@"btn_play_large"] forState:UIControlStateNormal];
        }

        [UIView animateWithDuration:0.1 animations:^{
            [self.playPauseButton setAlpha:1.0];
        }];
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
//        updateNowPlayingInfoWithProgram(currentProgram)

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
