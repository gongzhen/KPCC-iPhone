//
//  SCPRFirstViewController.m
//  KPCC
//
//  Created by John Meeker on 3/6/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "SCPRFirstViewController.h"
#import <AVFoundation/AVFoundation.h>

@interface SCPRFirstViewController ()
-(void) setupTimer;
@end

@implementation SCPRFirstViewController

- (void)viewDidLoad {
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    // Once the view has loaded then we can register to begin recieving system audio controls.
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    [self becomeFirstResponder];

    [self setupTimer];
}

// Allows for interaction with system audio controls.
- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [[NetworkManager shared] fetchProgramInformationFor:[NSDate date] display:self];
    
    if ([[AudioManager shared] isStreamPlaying]) {
        [self.actionButton setImage:[UIImage imageNamed:@"pauseButton"] forState:UIControlStateHighlighted];
        [self.actionButton setImage:[UIImage imageNamed:@"pauseButton"] forState:UIControlStateNormal];
    } else {
        [self.actionButton setImage:[UIImage imageNamed:@"playButton"] forState:UIControlStateHighlighted];
        [self.actionButton setImage:[UIImage imageNamed:@"playButton"] forState:UIControlStateNormal];
    }
}

- (void)remoteControlReceivedWithEvent:(UIEvent *)event {
    // Handle remote audio control events.
    if (event.type == UIEventTypeRemoteControl) {
        if (event.subtype == UIEventSubtypeRemoteControlPlay) {
            [self playStream];
        } else if (event.subtype == UIEventSubtypeRemoteControlPause) {
            [self stopStream];
        } else if (event.subtype == UIEventSubtypeRemoteControlTogglePlayPause) {
            [self stopStream];
        }
    }
}

-(void) setupTimer {
	timer = [NSTimer timerWithTimeInterval:0.025 target:self selector:@selector(tick) userInfo:nil repeats:YES];
	[[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
}

- (IBAction)buttonTapped:(id)sender {
    if (sender == self.actionButton) {
        [self playOrPauseTapped];
    }
}

-(void) playOrPauseTapped {
    if (![[AudioManager shared] isStreamPlaying]) {
        [self playStream];
    } else {
        [self stopStream];
    }
}

- (void)playStream {
    [[AudioManager shared] startStream];
}

- (void)stopStream {
    [[AudioManager shared] stopStream];
}

-(void) tick {
    STKAudioPlayerState stkAudioPlayerState = [[AudioManager shared] audioPlayer].state;
    NSString *audioPlayerStateString;
    
    if (stkAudioPlayerState != STKAudioPlayerStatePlaying) {

        if (!self.isUISetForPlaying) {

            [self.actionButton setImage:[UIImage imageNamed:@"playButton"] forState:UIControlStateHighlighted];
            [self.actionButton setImage:[UIImage imageNamed:@"playButton"] forState:UIControlStateNormal];
            
            [UIView animateWithDuration:0.44 animations:^{
                self.meter.frame = CGRectMake(self.meter.frame.origin.x, 150 + 240, self.meter.frame.size.width, 0);
            } completion:nil];
            
            self.isUISetForPaused = NO;
            self.isUISetForPlaying = YES;
        }
    } else {
        
        if (!self.isUISetForPaused) {
            [self.actionButton setImage:[UIImage imageNamed:@"pauseButton"] forState:UIControlStateHighlighted];
            [self.actionButton setImage:[UIImage imageNamed:@"pauseButton"] forState:UIControlStateNormal];
            
            self.isUISetForPaused = YES;
            self.isUISetForPlaying = NO;
        }
        
        [UIView animateWithDuration:0.1 animations:^{
            CGFloat newHeight = 240 * (([[[AudioManager shared] audioPlayer] averagePowerInDecibelsForChannel:0] + 60) / 60);
            self.meter.frame = CGRectMake(self.meter.frame.origin.x, 150 + newHeight, self.meter.frame.size.width, 240 - newHeight);
        } completion:nil];
    }
    
    switch (stkAudioPlayerState) {
        case STKAudioPlayerStateReady:
            audioPlayerStateString = @"ready";
            break;
            
        case STKAudioPlayerStateRunning:
            audioPlayerStateString = @"running";
            break;
            
        case STKAudioPlayerStateBuffering:
            audioPlayerStateString = @"buffering";
            [[AudioManager shared] analyzeStreamError:audioPlayerStateString];
            break;
            
        case STKAudioPlayerStateDisposed:
            audioPlayerStateString = @"disposed";
            break;
            
        case STKAudioPlayerStateError:
            audioPlayerStateString = @"error";
            break;
        
        case STKAudioPlayerStatePaused:
            audioPlayerStateString = @"paused";
            break;
        
        case STKAudioPlayerStatePlaying:
            audioPlayerStateString = @"playing";
            if (!self.isUISetForPaused) {
                [self.actionButton setImage:[UIImage imageNamed:@"pauseButton"] forState:UIControlStateHighlighted];
                [self.actionButton setImage:[UIImage imageNamed:@"pauseButton"] forState:UIControlStateHighlighted];
                self.isUISetForPaused = YES;
                self.isUISetForPlaying = NO;
            }
            break;
        
        case STKAudioPlayerStateStopped:
            audioPlayerStateString = @"stopped";
            break;
            
        default:
            audioPlayerStateString = @"";
            break;
    }

    [self.streamStatusLabel setText:audioPlayerStateString];
}



#pragma mark - ContentProcessor
- (void)handleProcessedContent:(NSArray *)content flags:(NSDictionary *)flags {
    
    if ( [content count] == 0 ) {
        return;
    }

    [self.programTitleLabel setText:[[content objectAtIndex:0] objectForKey:@"title"]];

    NSDictionary *audioMetaData = @{ MPMediaItemPropertyArtist : @"89.3 KPCC",
                                     MPMediaItemPropertyTitle : [[content objectAtIndex:0] objectForKey:@"title"] };
    
    [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:audioMetaData];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    // End recieving events
    [[UIApplication sharedApplication] endReceivingRemoteControlEvents];
    [self resignFirstResponder];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
