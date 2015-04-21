//
//  SCPRScrubbingUIViewController.m
//  KPCC
//
//  Created by Ben Hochberg on 2/9/15.
//  Copyright (c) 2015 SCPR. All rights reserved.
//

#import "SCPRScrubbingUIViewController.h"
#import "DesignManager.h"
#import "SCPRMasterViewController.h"
#import "SCPRJogShuttleViewController.h"

@interface SCPRScrubbingUIViewController ()

@end

@implementation SCPRScrubbingUIViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.darkeningView.backgroundColor = [[UIColor virtualBlackColor] translucify:0.35];
    

    // Do any additional setup after loading the view from its nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidLayoutSubviews {
    
}

- (void)prerender {
  
    [self.scrubberController setupWithDelegate:self];
    
    
    [self.fw30Button addTarget:self
                        action:@selector(forward30)
              forControlEvents:UIControlEventTouchUpInside];
    
    [self.rw30Button addTarget:self
                        action:@selector(rewind30)
              forControlEvents:UIControlEventTouchUpInside];

}

- (void)forward30 {
    
    [[AudioManager shared] setSeekWillEffectBuffer:YES];
    
    CMTime ct = [[AudioManager shared].audioPlayer.currentItem currentTime];
    ct.value += (30.0*ct.timescale);
    [[AudioManager shared].audioPlayer.currentItem seekToTime:ct completionHandler:^(BOOL finished) {
        [self onDemandSeekCompleted];
    }];
}

- (void)rewind30 {
    
    [[AudioManager shared] setSeekWillEffectBuffer:YES];
    
    CMTime ct = [[AudioManager shared].audioPlayer.currentItem currentTime];
    ct.value -= (30.0*ct.timescale);
    [[AudioManager shared].audioPlayer.currentItem seekToTime:ct completionHandler:^(BOOL finished) {
        [self onDemandSeekCompleted];
    }];
}

- (void)setupWithProgram:(NSDictionary *)program blurredImage:(UIImage *)image parent:(id)parent {
    self.parentControlView = parent;
    self.blurredImageView.image = image;
    AudioChunk *ac = program[@"chunk"];
    
    self.captionLabel.text = ac.audioTitle;
    self.blurredImageView.alpha = 0.0;
    

    self.captionLabel.font = [[DesignManager shared] proLight:self.captionLabel.font.pointSize];
    
    [self.closeButton addTarget:self
                         action:@selector(closeScrubber)
               forControlEvents:UIControlEventTouchUpInside];
    
}

- (void)closeScrubber {
    SCPRMasterViewController *mvc = (SCPRMasterViewController*)self.parentControlView;
    [UIView animateWithDuration:0.25 animations:^{
        [mvc killCloseButton];
        [mvc decloakForScrubber];
        [self.scrubberController applyMask];
        [[DesignManager shared] fauxRevealNavigationBar];
        self.view.alpha = 0.0;
    } completion:^(BOOL finished) {
        [mvc finishedWithScrubber];
    }];
}

- (void)setCloseButton:(UIButton *)closeButton {
    _closeButton = closeButton;
    if ( closeButton ) {
        [closeButton addTarget:self
                        action:@selector(closeScrubber)
              forControlEvents:UIControlEventTouchUpInside];
    }
}

- (void)takedown {
    
    self.scrubberController.panning = NO;
    self.scrubberController.currentBarLine.strokeEnd = 0.0;
    
}

#pragma mark - Seeking
- (void)audioWillSeek {
    
    self.seekLatencyTimer = [NSTimer scheduledTimerWithTimeInterval:1.5
                                                             target:self
                                                           selector:@selector(muteUI)
                                                           userInfo:nil
                                                            repeats:NO];
    
}

- (void)killLatencyTimer {
    if ( self.seekLatencyTimer ) {
        if ( [self.seekLatencyTimer isValid] ) {
            [self.seekLatencyTimer invalidate];
        }
        self.seekLatencyTimer = nil;
    }
}

- (void)muteUI {
    self.uiIsMutedForSeek = YES;
    
    [UIView animateWithDuration:0.26 animations:^{
        self.fw30Button.alpha = 0.25;
        self.rw30Button.alpha = 0.25;
        self.scrubberController.view.alpha = 0.25;
    } completion:^(BOOL finished) {
        
        self.fw30Button.userInteractionEnabled = NO;
        self.rw30Button.userInteractionEnabled = NO;
        self.scrubberController.view.userInteractionEnabled = NO;
        
        [[AudioManager shared] muteAudio];
        [(SCPRMasterViewController*)self.parentControlView beginScrubbingWaitMode];
    }];

}

- (void)unmuteUI {
    [self killLatencyTimer];
    if ( self.uiIsMutedForSeek ) {
        [UIView animateWithDuration:0.26 animations:^{
            self.fw30Button.alpha = 1.0;
            self.rw30Button.alpha = 1.0;
            self.scrubberController.view.alpha = 1.0;
        } completion:^(BOOL finished) {
            
            self.fw30Button.userInteractionEnabled = YES;
            self.rw30Button.userInteractionEnabled = YES;
            self.scrubberController.view.userInteractionEnabled = YES;

            [(SCPRMasterViewController*)self.parentControlView endScrubbingWaitMode];
            [[AudioManager shared] unmuteAudio];
            self.uiIsMutedForSeek = NO;
        }];
    }
}

#pragma mark - Scrubbable
- (void)actionOfInterestWithPercentage:(CGFloat)percent {
    CMTime total = [[[[AudioManager shared].audioPlayer currentItem] asset] duration];
    double duration = CMTimeGetSeconds(total);
    
    NSString *pretty = [Utils elapsedTimeStringWithPosition:duration*percent
                                                andDuration:duration];
    [self.scrubbingIndicatorLabel setText:pretty];
}

- (void)actionOfInterestAfterScrub:(CGFloat)finalValue {
    
    double multiplier = finalValue;
    CMTime total = [[[[AudioManager shared].audioPlayer currentItem] asset] duration];
    CMTime seek = CMTimeMake(total.value*multiplier, total.timescale);
    [[AudioManager shared] invalidateTimeObserver];
    [[AudioManager shared].audioPlayer.currentItem seekToTime:seek completionHandler:^(BOOL finished) {
        [[AudioManager shared] startObservingTime];
    }];

}

- (UILabel*)scrubbingIndicatorLabel {
    SCPRMasterViewController *mvc = (SCPRMasterViewController*)self.parentControlView;
    return [mvc scrubberTimeLabel];
}

- (SCPRTouchableScrubberView*)scrubbableView {
    SCPRMasterViewController *mvc = (SCPRMasterViewController*)self.parentControlView;
    return mvc.touchableScrubberView;
}

#pragma mark - AudioManager
- (void)onRateChange {
    if ([[AudioManager shared] isStreamPlaying] || [[AudioManager shared] isStreamBuffering]) {
        [self.playPauseButton fadeImage:[UIImage imageNamed:@"btn_pause.png"] duration:0.2];
    } else {
        [self.playPauseButton fadeImage:[UIImage imageNamed:@"btn_play.png"] duration:0.2];
    }
}

- (void)onTimeChange {
    
    if ( !self.scrubberController.panning ) {
        if (CMTimeGetSeconds([[[[AudioManager shared].audioPlayer currentItem] asset] duration]) > 0) {
            double currentTime = CMTimeGetSeconds([[[AudioManager shared].audioPlayer currentItem] currentTime]);
            double duration = CMTimeGetSeconds([[[[AudioManager shared].audioPlayer currentItem] asset] duration]);
            NSString *pretty = [Utils elapsedTimeStringWithPosition:currentTime
                                                        andDuration:duration];
            [self.scrubbingIndicatorLabel setText:pretty];
        }
    }
    
    double se = [self strokeEndForCurrentTime];
    [self.scrubberController tick:se];
    [self unmuteUI];
    
}

- (double)strokeEndForCurrentTime {
    NSInteger cS = CMTimeGetSeconds([[AudioManager shared].audioPlayer.currentItem currentTime]);
    NSInteger tS = CMTimeGetSeconds([[AudioManager shared].audioPlayer.currentItem.asset duration]);
    return (cS*1.0f / tS*1.0f)*1.0f;
}

- (void)onSeekCompleted {
    // No-op
}

- (void)onDemandSeekCompleted {
    [(id<AudioManagerDelegate>)self.parentControlView onDemandSeekCompleted];
}

- (void)scrubberWillAppear {
    StreamStatus s = [[AudioManager shared] status];
    if ( s == StreamStatusPlaying ) {
        self.scrubberController.currentBarLine.strokeEnd = 0.0;
    } else {
        [self.scrubberController tick:0.0f];
    }
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
