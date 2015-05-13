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

static CGFloat kVirtualBehindLiveTolerance = 20.0f;

@interface SCPRScrubbingUIViewController ()

@end

@implementation SCPRScrubbingUIViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.darkeningView.backgroundColor = [[UIColor virtualBlackColor] translucify:0.35];
    


    

    
    [self primeForAudioMode];
    
    // Do any additional setup after loading the view from its nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidLayoutSubviews {
    
}

- (void)programChanged {
    [self primeForAudioMode];
}

- (void)primeForAudioMode {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                 name:@"program-has-changed"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:@"audio-mode-changed"
                                                  object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(programChanged)
                                                 name:@"program-has-changed"
                                               object:nil];
    
    self.currentProgressNeedleView.alpha = 0.0f;
    self.currentProgressReadingLabel.alpha = 0.0f;
    
    if ( [[AudioManager shared] currentAudioMode] == AudioModeLive ) {
        
        self.liveProgressView.alpha = 1.0f;
        self.liveProgressView.backgroundColor = [[UIColor virtualWhiteColor] translucify:0.4f];
        self.scrubberController.liveProgressView = self.liveProgressView;
        self.scrubberController.liveProgressAnchor = self.liveStreamProgressAnchor;
        self.currentProgressNeedleView.alpha = 0.0f;
        self.currentProgressReadingLabel.alpha = 0.0f;
        
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
        
        self.lowerBoundThreshold = [self convertToTimeValueFromPercentage:0.0f];
        
        [self.timeNumericLabel proLightFontize];
        [self.timeBehindLiveLabel proMediumFontize];
        
        if ( [[AudioManager shared] status] != StreamStatusStopped ) {

            self.timeBehindLiveLabel.alpha = 0.0f;
            self.timeNumericLabel.alpha = 1.0f;
            
            [self behindLiveStatus];
            
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
        
        [self.currentProgressReadingLabel proMediumFontize];
        self.currentProgressReadingLabel.textColor = [UIColor kpccOrangeColor];
        self.currentProgressNeedleView.backgroundColor = [UIColor kpccOrangeColor];
        
        
    }
    if ( [[AudioManager shared] currentAudioMode] == AudioModeOnDemand ) {
        self.liveProgressView.alpha = 0.0f;
        self.lowerBoundLabel.alpha = 0.0f;
        self.upperBoundLabel.alpha = 0.0f;
        self.timeNumericLabel.alpha = 0.0f;
        self.timeBehindLiveLabel.alpha = 0.0f;
        self.captionLabel.alpha = 1.0f;
        self.maxPercentage = MAXFLOAT;
        self.liveProgressNeedleReadingLabel.alpha = 0.0f;
        self.liveProgressNeedleView.alpha = 0.0f;
    }
}

- (void)printCurrentDate {
    NSDate *cd = [[AudioManager shared].audioPlayer.currentItem currentDate];
    NSLog(@"Time is : %@",[NSDate stringFromDate:cd
                                      withFormat:@"h:mm:ss a"]);
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
    
    [[AudioManager shared].audioPlayer pause];
    [[AudioManager shared] invalidateTimeObserver];
    [self printCurrentDate];
    [[AudioManager shared].audioPlayer.currentItem seekToTime:ct completionHandler:^(BOOL finished) {
        if ( [[AudioManager shared] currentAudioMode] == AudioModeOnDemand ) {
            [self onDemandSeekCompleted];
        }
        if ( [[AudioManager shared] currentAudioMode] == AudioModeLive ) {
            [self recalibrateAfterScrub];
        }
        
        [[AudioManager shared].audioPlayer play];
        [self printCurrentDate];
        
        [[AudioManager shared] startObservingTime];
        
    }];
    
}

- (void)rewind30 {
    
    [[AudioManager shared] setSeekWillEffectBuffer:YES];
    CMTime ct = [[AudioManager shared].audioPlayer.currentItem currentTime];
    ct.value -= (30.0*ct.timescale);
    
    self.ignoringThresholdGate = YES;
    
    [[AudioManager shared].audioPlayer pause];
    [[AudioManager shared] invalidateTimeObserver];
    [self printCurrentDate];
    [[AudioManager shared].audioPlayer.currentItem seekToTime:ct completionHandler:^(BOOL finished) {
        if ( [[AudioManager shared] currentAudioMode] == AudioModeOnDemand ) {
            [self onDemandSeekCompleted];
        }
        if ( [[AudioManager shared] currentAudioMode] == AudioModeLive ) {
            [self recalibrateAfterScrub];
        }
        
        [self printCurrentDate];
        [[AudioManager shared].audioPlayer play];
        [[AudioManager shared] startObservingTime];
    }];
    
}

- (void)setupWithProgram:(NSDictionary *)program blurredImage:(UIImage *)image parent:(id)parent {
    self.parentControlView = parent;
    self.blurredImageView.image = image;
    AudioChunk *ac = program[@"chunk"];
    
    self.captionLabel.text = ac.audioTitle;
    self.blurredImageView.alpha = 0.0f;
    

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
        self.view.alpha = 0.0f;
    } completion:^(BOOL finished) {
        self.tolerance = 0.0f;
        self.timeBehindLiveLabel.alpha = 0.0f;
        self.timeNumericLabel.text = @"";
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
    self.scrubberController.currentBarLine.strokeEnd = 0.0f;
    
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
            self.fw30Button.alpha = 1.0f;
            self.rw30Button.alpha = 1.0f;
            self.scrubberController.view.alpha = 1.0f;
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

#pragma mark - Events
- (void)trackScrubberUse {
    NSString *eventName = @"";
    NSString *method = @"scrubber";
    if ( [[AudioManager shared] currentAudioMode] == AudioModeLive ) {
        eventName = @"liveStreamScrubbed";
    }
    if ( [[AudioManager shared] currentAudioMode] == AudioModeOnDemand ) {
        eventName = @"onDemandAudioScrubbed";
    }
    
    NSString *direction = @"";
    if ( self.newPositionDelta < 0 ) {
        direction = @"Backward";
    } else {
        direction = @"Forward";
    }
}

#pragma mark - Scrubbable
- (void)actionOfInterestWithPercentage:(CGFloat)percent {
    NSString *pretty = @"";
    
    if ( [[AudioManager shared] currentAudioMode] == AudioModeOnDemand ) {
        CMTime total = [[[[AudioManager shared].audioPlayer currentItem] asset] duration];
        double duration = CMTimeGetSeconds(total);
        
        pretty = [Utils elapsedTimeStringWithPosition:duration*percent
                                                    andDuration:duration];
    }
    if ( [[AudioManager shared] currentAudioMode] == AudioModeLive ) {
        
        Program *p = [[SessionManager shared] currentProgram];
        NSInteger totalSeconds = [self convertToSecondsFromPercentage:percent];
        NSDate *cd = [[[AudioManager shared].audioPlayer.currentItem currentDate] earlierDate:p.ends_at];
        NSDate *scrubbed = [cd dateByAddingTimeInterval:-1.0*totalSeconds];
        pretty = [NSDate stringFromDate:scrubbed
                             withFormat:@"h:mma"];
        
        CGFloat where = percent * self.scrubbableView.frame.size.width;
        self.cpLeftAnchor.constant = -1.0f*where;
        
        
        [UIView animateWithDuration:0.25f animations:^{
            [self.view updateConstraintsIfNeeded];
            [self.view layoutIfNeeded];
            self.currentProgressReadingLabel.alpha = 0.0f;
            self.currentProgressNeedleView.alpha = 0.0f;
        }];
        
    }
    
    [[self scrubbingIndicatorLabel] setText:pretty];
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
    
    self.positionBeforeScrub = CMTimeGetSeconds(seek);
    
    [[AudioManager shared] invalidateTimeObserver];
    [[AudioManager shared] setSeekWillEffectBuffer:YES];
    [[AudioManager shared].audioPlayer pause];
    [self printCurrentDate];
    [[AudioManager shared].audioPlayer.currentItem seekToTime:seek completionHandler:^(BOOL finished) {
        
        CMTime ct = [[AudioManager shared].audioPlayer.currentItem currentTime];
        self.newPositionDelta = CMTimeGetSeconds(ct) - self.positionBeforeScrub;
        
        [[AudioManager shared] setSeekWillEffectBuffer:NO];
        [[AudioManager shared] startObservingTime];
        if ( [[AudioManager shared] currentAudioMode] == AudioModeLive ) {
            [self recalibrateAfterScrub];
        }
        
        [self printCurrentDate];
        [[AudioManager shared].audioPlayer play];
        
        [self trackScrubberUse];
        
    }];

}

- (UILabel*)scrubbingIndicatorLabel {
    if ( [[AudioManager shared] currentAudioMode] == AudioModeOnDemand ) {
        SCPRMasterViewController *mvc = (SCPRMasterViewController*)self.parentControlView;
        return [mvc scrubberTimeLabel];
    }
    
    return self.currentProgressReadingLabel;
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
        if ( [[AudioManager shared] currentAudioMode] == AudioModeOnDemand ) {
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

- (void)tickLive:(BOOL)animated {
    [self tickLive];
}

- (void)tickLive {
    
    NSDate *live = [[SessionManager shared] vLive];
    NSString *prettyTime = [NSDate stringFromDate:live
                                       withFormat:@"h:mma"];
    self.liveProgressNeedleReadingLabel.text = [prettyTime lowercaseString];
    
    self.maxPercentage = [self livePercentage];
    self.maxPercentage = fmin(self.maxPercentage, 1.0f);
    
    CGFloat endPoint = self.scrubberController.view.frame.size.width * self.maxPercentage;

    [UIView animateWithDuration:0.25 animations:^{
        self.liveStreamProgressAnchor.constant = endPoint;
        
        if ( self.maxPercentage >= 0.85f ) {
            self.flagAnchor.constant = self.liveProgressNeedleReadingLabel.frame.size.width;
        } else {
            self.flagAnchor.constant = 0.0f;
        }
        
        if ( self.maxPercentage >= 1.0f ) {
            self.liveProgressNeedleView.alpha = 0.0f;
            self.liveProgressNeedleReadingLabel.alpha = 0.0f;
        } else {
            self.liveProgressNeedleReadingLabel.alpha = 1.0f;
            self.liveProgressNeedleView.alpha = 1.0f;
        }
        
        [self behindLiveStatus];
        
        [self.view layoutIfNeeded];
    }];
}

- (CMTime)convertToTimeValueFromPercentage:(double)percent {

    NSInteger totalTime = [self convertToSecondsFromPercentage:percent];
    
    
    NSArray *ranges = [[AudioManager shared].audioPlayer.currentItem seekableTimeRanges];
    CMTimeRange range = [ranges[0] CMTimeRangeValue];
    NSInteger end = CMTimeGetSeconds(CMTimeRangeGetEnd(range));
    
    if ( totalTime > end ) {
        totalTime = end;
    }
    if ( totalTime < 0 ) {
        totalTime = 0;
    }
    
    return CMTimeMake(end - totalTime, 1);
    
}

- (NSInteger)convertToSecondsFromPercentage:(double)percent {
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
        
        CGFloat chunkUpToLive = programEndInSeconds - [startDate timeIntervalSince1970];
        totalTime = chunkUpToLive - secondsThroughProgram;
        
        CGFloat afterProgram = liveInSeconds - programEndInSeconds;
        totalTime += afterProgram;
        
    }
    
    
    totalTime -= [[SessionManager shared] peakDrift];
    
    return totalTime;
}

- (void)recalibrateAfterScrub {
    
    NSDate *vNow = [[SessionManager shared] vNow];
    Program *cp = [[SessionManager shared] currentProgram];
    NSTimeInterval vNowInSeconds = [vNow timeIntervalSince1970];
    NSTimeInterval saInSeconds = [cp.soft_starts_at timeIntervalSince1970];
    NSTimeInterval eaInSeconds = [cp.ends_at timeIntervalSince1970];
    
    if ( vNowInSeconds >= eaInSeconds || vNowInSeconds <= saInSeconds ) {
        NSLog(@"Scrub will force program update for vNow : %@",[NSDate stringFromDate:vNow
                                                                           withFormat:@"h:mm:s a"]);

        
        [[SessionManager shared] fetchCurrentProgram:^(id returnedObject) {
            
        }];
    }
}

- (void)behindLiveStatus {
    
    [UIView animateWithDuration:0.25f animations:^{
        
        CGFloat sbl = [[SessionManager shared] virtualSecondsBehindLive];
        if ( self.tolerance > kVirtualBehindLiveTolerance && fabs(sbl - self.tolerance) < kVirtualBehindLiveTolerance && self.tolerance > 0.0f ) {
            if ( sbl > kVirtualBehindLiveTolerance ) {
                self.timeBehindLiveLabel.alpha = 1.0f;
            } else {
                self.ignoringThresholdGate = NO;
            }
            return;
        }
        
        self.tolerance = sbl;
        
        self.ignoringThresholdGate = sbl > kVirtualBehindLiveTolerance;
        
        if ( self.tolerance > kVirtualBehindLiveTolerance || self.ignoringThresholdGate ) {
            self.timeBehindLiveLabel.alpha = 1.0f;
            [self.timeNumericLabel setText:[NSDate scientificStringFromSeconds:[[SessionManager shared] virtualSecondsBehindLive]]];
            self.currentProgressReadingLabel.alpha = 0.0f;
            self.currentProgressNeedleView.alpha = 0.0f;
        } else {
            self.ignoringThresholdGate = NO;
            self.timeBehindLiveLabel.alpha = 0.0f;
            self.currentProgressReadingLabel.alpha = 0.0f;
            self.currentProgressNeedleView.alpha = 0.0f;
            [self.timeNumericLabel setText:@"LIVE"];
        }
        
        
    }];
    

    

}

#pragma mark - OnDemand

- (void)onSeekCompleted {
    // No-op
}

- (void)onDemandSeekCompleted {
    [(id<AudioManagerDelegate>)self.parentControlView onDemandSeekCompleted];
}

- (void)scrubberWillAppear {
    StreamStatus s = [[AudioManager shared] status];
    if ( s == StreamStatusPlaying ) {
        self.scrubberController.currentBarLine.strokeEnd = 0.0f;
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
