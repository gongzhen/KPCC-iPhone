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
#import "Program.h"
#import "SessionManager.h"

@interface SCPRScrubbingUIViewController ()

@end

@implementation SCPRScrubbingUIViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.darkeningView.backgroundColor = [[UIColor virtualBlackColor] translucify:0.35];
    

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(primeForAudioMode)
                                                 name:@"audio-mode-changed"
                                               object:nil];
    
    [self primeForAudioMode];
    
    // Do any additional setup after loading the view from its nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidLayoutSubviews {
    
}

- (void)primeForAudioMode {
    
    if ( [[AudioManager shared] currentAudioMode] == AudioModeLive ) {
        
        self.liveProgressView.alpha = 1.0f;
        self.liveProgressView.backgroundColor = [[UIColor virtualWhiteColor] translucify:0.4f];
        self.scrubberController.liveProgressView = self.liveProgressView;
        self.scrubberController.liveProgressAnchor = self.liveStreamProgressAnchor;
        
        Program *p = [[SessionManager shared] currentProgram];
        
        NSDate *startDate = p.starts_at;
        NSDate *endDate = p.ends_at;
        
        NSString *sdFmtRaw = [Utils formatOfInterestFromDate:startDate
                                                startDate:NO
                           gapped:NO];
        NSString *edFmtRaw = [Utils formatOfInterestFromDate:endDate
                                                startDate:NO
                           gapped:NO];
        
        NSString *sdFmt = [NSDate stringFromDate:startDate
                                      withFormat:sdFmtRaw];
        NSString *edFmt = [NSDate stringFromDate:endDate
                                      withFormat:edFmtRaw];
        
        self.lowerBoundLabel.alpha = 1.0f;
        self.upperBoundLabel.alpha = 1.0f;
        
        self.lowerBoundLabel.attributedText = [[DesignManager shared] standardTimeFormatWithString:[sdFmt lowercaseString]
                                                                                        attributes:@{ @"digits" : [[DesignManager shared] proLight:16.0f],
                                                                                                      @"period" : [[DesignManager shared] proLight:16.0f] }];
        
        self.upperBoundLabel.attributedText = [[DesignManager shared] standardTimeFormatWithString:[edFmt lowercaseString]
                                                                                        attributes:@{ @"digits" : [[DesignManager shared] proLight:16.0f],
                                                                                                      @"period" : [[DesignManager shared] proLight:16.0f] }];
        

        self.maxPercentage = [self livePercentage];
        [self tickLive];
        
        [self.timeNumericLabel proLightFontize];
        [self.timeBehindLiveLabel proMediumFontize];
        
        if ( [[AudioManager shared] status] != StreamStatusStopped ) {
            
            self.timeNumericLabel.alpha = 1.0f;
            self.timeBehindLiveLabel.alpha = 1.0f;
            
            NSInteger seconds = [[SessionManager shared] secondsBehindLive];
            NSString *readable = @"LIVE";
            if ( seconds >= kAllowableDriftCeiling ) {
                readable = [[NSDate scientificStringFromSeconds:seconds] lowercaseString];
            }
            
            self.timeNumericLabel.text = readable;
            
        } else {
            self.timeNumericLabel.alpha = 0.0f;
            self.timeBehindLiveLabel.alpha = 0.0f;
        }

        self.timeNumericLabel.textColor = [UIColor whiteColor];
        self.timeBehindLiveLabel.textColor = [UIColor kpccOrangeColor];
        self.captionLabel.alpha = 0.0f;
        
        self.liveProgressNeedleView.alpha = 1.0f;
        self.liveProgressNeedleReadingLabel.alpha = 1.0f;
        [self.liveProgressNeedleReadingLabel proMediumFontize];
        
        
    }
    if ( [[AudioManager shared] currentAudioMode] == AudioModeOnDemand ) {
        self.liveProgressView.alpha = 0.0f;
        self.lowerBoundLabel.alpha = 0.0f;
        self.upperBoundLabel.alpha = 0.0f;
        self.timeNumericLabel.alpha = 0.0f;
        self.timeBehindLiveLabel.alpha = 0.0f;
        self.captionLabel.alpha = 1.0f;
        self.maxPercentage = -1.0f;
        self.liveProgressNeedleReadingLabel.alpha = 0.0f;
        self.liveProgressNeedleView.alpha = 0.0f;
    }
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
        if ( [[AudioManager shared] currentAudioMode] == AudioModeOnDemand ) {
            [self onDemandSeekCompleted];
        }
    }];
    
}

- (void)rewind30 {
    
    [[AudioManager shared] setSeekWillEffectBuffer:YES];
    CMTime ct = [[AudioManager shared].audioPlayer.currentItem currentTime];
    ct.value -= (30.0*ct.timescale);
    [[AudioManager shared].audioPlayer.currentItem seekToTime:ct completionHandler:^(BOOL finished) {
        if ( [[AudioManager shared] currentAudioMode] == AudioModeOnDemand ) {
            [self onDemandSeekCompleted];
        }
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
    CMTime seek;
    
    if ( [[AudioManager shared] currentAudioMode] == AudioModeOnDemand ) {
        CMTime total = [[[[AudioManager shared].audioPlayer currentItem] asset] duration];
        seek = CMTimeMake(total.value*multiplier, total.timescale);
    } else if ( [[AudioManager shared] currentAudioMode] == AudioModeLive ) {
        seek = [self convertToTimeValueFromPercentage:multiplier];
        NSLog(@"Live S2T : %ld",(long)CMTimeGetSeconds(seek));
    }
    
    [[AudioManager shared] invalidateTimeObserver];
    [[AudioManager shared] setSeekWillEffectBuffer:YES];
    [[AudioManager shared].audioPlayer.currentItem seekToTime:seek completionHandler:^(BOOL finished) {
        
        NSDate *cd = [[AudioManager shared].audioPlayer.currentItem currentDate];
        NSLog(@"Current Time is Now : %@",[NSDate stringFromDate:cd
                                                      withFormat:@"hh:mm a"]);
        [[AudioManager shared] setSeekWillEffectBuffer:NO];
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
    if ( [[AudioManager shared] isStreamPlaying] || [[AudioManager shared] isStreamBuffering] ) {
        [self.playPauseButton fadeImage:[UIImage imageNamed:@"btn_pause.png"]
                               duration:0.2];
    } else {
        [self.playPauseButton fadeImage:[UIImage imageNamed:@"btn_play.png"]
                               duration:0.2];
    }
}

- (void)onTimeChange {
    
    if ( !self.scrubberController.panning ) {
        if ( [[AudioManager shared] currentAudioMode] == AudioModeOnboarding ) {
            if (CMTimeGetSeconds([[[[AudioManager shared].audioPlayer currentItem] asset] duration]) > 0) {
                double currentTime = CMTimeGetSeconds([[[AudioManager shared].audioPlayer currentItem] currentTime]);
                double duration = CMTimeGetSeconds([[[[AudioManager shared].audioPlayer currentItem] asset] duration]);
                NSString *pretty = [Utils elapsedTimeStringWithPosition:currentTime
                                                            andDuration:duration];
                [self.scrubbingIndicatorLabel setText:pretty];
            }
        } else {
            [self tickLive];
        }
    }
    
    double se = [self strokeEndForCurrentTime];
    [self.scrubberController tick:se];
    [self unmuteUI];
    
}

- (double)strokeEndForCurrentTime {
    if ( [[AudioManager shared] currentAudioMode] == AudioModeOnDemand ) {
        NSInteger cS = CMTimeGetSeconds([[AudioManager shared].audioPlayer.currentItem currentTime]);
        NSInteger tS = CMTimeGetSeconds([[AudioManager shared].audioPlayer.currentItem.asset duration]);
        return (cS*1.0f / tS*1.0f)*1.0f;
    }
    if ( [[AudioManager shared] currentAudioMode] == AudioModeLive ) {
        return [self percentageThroughCurrentProgram];
    }
    
    return 0.0f;
}

#pragma mark - Live
- (double)livePercentage {
    Program *p = [[SessionManager shared] currentProgram];
    if ( !p ) {
        return 0.0f;
    }
    
    NSDate *startDate = p.starts_at;
    NSDate *endDate = p.ends_at;
    NSDate *now = [[SessionManager shared] vLive];
    NSTimeInterval nowTI = [now timeIntervalSince1970];
    NSTimeInterval total = [endDate timeIntervalSince1970] - [startDate timeIntervalSince1970];
    NSTimeInterval diff = nowTI - [startDate timeIntervalSince1970];
    
    return (double) ( diff / ( total * 1.0f ) );
}

- (double)percentageThroughCurrentProgram {
    
    if ( [[SessionManager shared] sessionIsBehindLive] ) {
        NSDate *currentPlayerDate = [[SessionManager shared] vNow];
        Program *p = [[SessionManager shared] currentProgram];
        NSDate *endDate = p.ends_at;
        NSDate *startDate = p.starts_at;
        CGFloat duration = [endDate timeIntervalSince1970] - [startDate timeIntervalSince1970];
        CGFloat chunk = [currentPlayerDate timeIntervalSince1970] - [startDate timeIntervalSince1970];
        
        return chunk / duration;
    }
    
    return [self livePercentage];
}

- (void)tickLive {
    
    NSDate *live = [[SessionManager shared] vLive];
    NSString *prettyTime = [NSDate stringFromDate:live
                                       withFormat:@"h:mma"];
    self.liveProgressNeedleReadingLabel.text = [prettyTime lowercaseString];
    
    self.maxPercentage = [self livePercentage];
    
    if ( [[SessionManager shared] sessionIsBehindLive] ) {
        [self.timeNumericLabel setText:[NSDate scientificStringFromSeconds:[[SessionManager shared] secondsBehindLive]]];
    } else {
        [self.timeNumericLabel setText:@"LIVE"];
    }
    
    CGFloat endPoint = self.scrubberController.view.frame.size.width * self.maxPercentage;
    [UIView animateWithDuration:0.25 animations:^{
        self.liveStreamProgressAnchor.constant = endPoint;
        [self.view layoutIfNeeded];
    }];
}

- (CMTime)convertToTimeValueFromPercentage:(double)percent {
    Program *p = [[SessionManager shared] currentProgram];
    NSDate *startDate = p.starts_at;
    NSDate *endDate = p.ends_at;

    NSTimeInterval total = [endDate timeIntervalSince1970] - [startDate timeIntervalSince1970];
    NSInteger secondsThroughProgram = floorf(total * percent);
    NSDate *msd = [[SessionManager shared] vLive];
    
    NSInteger liveInSeconds = [msd timeIntervalSince1970];
    NSInteger programEndInSeconds = [endDate timeIntervalSince1970];
    
    NSInteger totalTime = 0;
    if ( programEndInSeconds > liveInSeconds ) {
        
        CGFloat chunkUpToLive = liveInSeconds - [startDate timeIntervalSince1970];
        totalTime = chunkUpToLive - secondsThroughProgram;
        
    } else {

        
    }
    
    NSArray *ranges = [[AudioManager shared].audioPlayer.currentItem seekableTimeRanges];
    CMTimeRange range = [ranges[0] CMTimeRangeValue];
    NSInteger end = CMTimeGetSeconds(CMTimeRangeGetEnd(range));
    return CMTimeMake(end - totalTime, 1);
    
    
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
