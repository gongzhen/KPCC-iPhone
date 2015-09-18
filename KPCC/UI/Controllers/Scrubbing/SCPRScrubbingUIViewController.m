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
#import "AnalyticsManager.h"
#import "KPCC-Swift.h"


@interface SCPRScrubbingUIViewController ()

@end

@implementation SCPRScrubbingUIViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.darkeningView.backgroundColor = [[UIColor virtualBlackColor] translucify:0.35];
    
//    [[NSNotificationCenter defaultCenter] addObserver:self
//                                             selector:@selector(enableScrubbingUI)
//                                                 name:@"playback-stalled"
//                                               object:nil];
//    
//    [[NSNotificationCenter defaultCenter] addObserver:self
//                                             selector:@selector(disableScrubbingUI)
//                                                 name:@"player-ready"
//                                               object:nil];

    [self primeForAudioMode];



    // Do any additional setup after loading the view from its nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidLayoutSubviews {
    
}

- (void)activateStatusObserver {
    // listen for audio state changes
    [[[AudioManager shared] status] observe:^(enum AudioStatus o) {
        switch (o) {
            case AudioStatusPlaying:
                self.seeking = NO;
                break;
            case AudioStatusSeeking:
            case AudioStatusWaiting:
                self.seeking = YES;

                break;
            default:
                self.seeking = NO;
                break;
        }
    }];
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
    


    if ( [[AudioManager shared] currentAudioMode] == AudioModeLive ) {
        
        self.liveProgressView.alpha = 1.0f;
        self.liveProgressView.backgroundColor = [[UIColor virtualWhiteColor] translucify:0.4f];
        self.scrubberController.liveProgressView = self.liveProgressView;
        self.scrubberController.liveProgressAnchor = self.liveStreamProgressAnchor;
        self.timeBehindLiveLabel.text = @"YOUR LISTENING SPOT";
        ScheduleOccurrence *p = [[SessionManager shared] currentSchedule];
        
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
        

        self.maxPercentage = [p dateToPercentage:[[SessionManager shared] vLive]];
        [self tickLive];
                
        [self.timeNumericLabel proLightFontize];
        [self.timeBehindLiveLabel proMediumFontize];
        
        if ( ![[[AudioManager shared] status] stopped] ) {

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

    } else if ( [[AudioManager shared] currentAudioMode] == AudioModeOnDemand ) {
        self.liveProgressView.alpha = 0.0f;
        self.lowerBoundLabel.alpha = 0.0f;
        self.upperBoundLabel.alpha = 0.0f;
        self.timeNumericLabel.alpha = 0.0f;
        self.timeBehindLiveLabel.alpha = 0.0f;
        self.captionLabel.alpha = 1.0f;
        self.maxPercentage = MAXFLOAT;

        [[self scrubbingIndicatorLabel] proLightFontize];
    }
}

- (void)prerender {
  
    [self.scrubberController setupWithDelegate:self];
    
    


}

- (void)forward30 {
    [[AudioManager shared] forwardSeekThirtySecondsWithCompletion:^{
        if ( [[AudioManager shared] currentAudioMode] == AudioModeOnDemand ) {
            [self onDemandSeekCompleted];
        }
        if ( [[AudioManager shared] currentAudioMode] == AudioModeLive ) {
            [[AudioManager shared] recalibrateAfterScrub];
        }
    }];

    
}

- (void)rewind30 {
    [AudioManager shared].ignoreDriftTolerance = YES;
    
    [[AudioManager shared] backwardSeekThirtySecondsWithCompletion:^{
        if ( [[AudioManager shared] currentAudioMode] == AudioModeOnDemand ) {
            [self onDemandSeekCompleted];
        }
        if ( [[AudioManager shared] currentAudioMode] == AudioModeLive ) {
            [[AudioManager shared] recalibrateAfterScrub];
        }
        
        [self behindLiveStatus];
    }];
    
    
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

- (void)enableScrubbingUI {
    self.scrubbingAvailable = YES;
    self.rw30Button.alpha = 1.0f;
    self.fw30Button.alpha = 1.0f;
    self.rw30Button.userInteractionEnabled = YES;
    self.fw30Button.userInteractionEnabled = YES;
}

- (void)disableScrubbingUI {
    self.scrubbingAvailable = NO;
    self.rw30Button.alpha = 0.4f;
    self.fw30Button.alpha = 0.4f;
    self.rw30Button.userInteractionEnabled = NO;
    self.fw30Button.userInteractionEnabled = NO;
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
//    [self killLatencyTimer];
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




#pragma mark - Scrubbable
- (void)actionOfInterestOnScrubBegin {
}

- (void)actionOfInterestWithPercentage:(CGFloat)percent {
    NSString *pretty = @"";
    
    if ( [[AudioManager shared] currentAudioMode] == AudioModeOnDemand ) {
        CMTime total = [[AudioManager shared].audioPlayer duration];
        double duration = CMTimeGetSeconds(total);
        
        pretty = [Utils elapsedTimeStringWithPosition:duration*percent
                                                    andDuration:duration];
        
        [[self scrubbingIndicatorLabel] setText:pretty];
    }
    if ( [[AudioManager shared] currentAudioMode] == AudioModeLive ) {

        ScheduleOccurrence *p = [[SessionManager shared] currentSchedule];
        NSDate *scrubbed  = [p percentageToDate:percent];

        pretty = [[NSDate stringFromDate:scrubbed
                             withFormat:@"h:mm:ss a"] lowercaseString];

        NSAttributedString *fancyTime = [[DesignManager shared] standardTimeFormatWithString:pretty
                                                                                  attributes:@{ @"digits" : [[DesignManager shared] proLight:32.0f],
                                                                                                @"period" : [[DesignManager shared] proLight:18.0f] }];
        
        [[self scrubbingIndicatorLabel] setAttributedText:fancyTime];
        
        [UIView animateWithDuration:0.25f animations:^{
            [self.view updateConstraintsIfNeeded];
            [self.view layoutIfNeeded];
        }];
        
    }
    

}

- (void)actionOfInterestAfterScrub:(CGFloat)finalValue {

    if ( [[AudioManager shared] currentAudioMode] == AudioModeOnDemand ) {
        // on-demand seeks are just based on percentage, so we're good
        [[[AudioManager shared] audioPlayer] seekToPercent:(double)finalValue completion:^(BOOL finished) {
            [self postSeek];
        }];

        return;
    }

    ScheduleOccurrence *p = [[SessionManager shared] currentSchedule];
    NSDate* seekDate = [p percentageToDate:finalValue];
    
    self.positionBeforeScrub = [[[SessionManager shared] vNow] timeIntervalSince1970];
    NSLog(@"Position before scrub : %ld", (long)self.positionBeforeScrub);

    if ( !seekDate ) {
        // a nil seekDate implies seeking to live
        [[[AudioManager shared] audioPlayer] seekToLive:^(BOOL finished){
            [self postSeek];
        }];
        
        return;
    }

    [[[AudioManager shared] audioPlayer] seekToDate:seekDate completion:^(BOOL finished){
        [self postSeek];
    }];

}

- (void)postSeek {

    [(SCPRMasterViewController*)self.parentControlView primeManualControlButton];
    [[AnalyticsManager shared] trackSeekUsageWithType:ScrubbingTypeScrubber];

    [AudioManager shared].newPositionDelta = [[[SessionManager shared] vNow] timeIntervalSince1970] - self.positionBeforeScrub;
    NSLog(@"Scrub Delta : %ld",(long)[AudioManager shared].newPositionDelta);
    
    if ( [[AudioManager shared] currentAudioMode] == AudioModeLive ) {
        [[AudioManager shared] recalibrateAfterScrub];
    }

    [(SCPRMasterViewController*)self.parentControlView primeManualControlButton];
    
    [[AnalyticsManager shared] trackSeekUsageWithType:ScrubbingTypeScrubber];
}

- (UILabel*)scrubbingIndicatorLabel {
    if ( [[AudioManager shared] currentAudioMode] == AudioModeOnDemand ) {
        SCPRMasterViewController *mvc = (SCPRMasterViewController*)self.parentControlView;
        return [mvc scrubberTimeLabel];
    }
    
    return self.timeNumericLabel;
}

- (SCPRTouchableScrubberView*)scrubbableView {
    SCPRMasterViewController *mvc = (SCPRMasterViewController*)self.parentControlView;
    return mvc.touchableScrubberView;
}

#pragma mark - AudioManager
- (void)onTimeChange {
    if (self.seeking) {
        return;
    }
    
    if ( !self.scrubberController.panning ) {
        if ( [[AudioManager shared] currentAudioMode] == AudioModeOnDemand ) {
            if (CMTimeGetSeconds([[AudioManager shared].audioPlayer duration]) > 0) {
                double currentTime = CMTimeGetSeconds([[AudioManager shared].audioPlayer currentTime]);
                double duration = CMTimeGetSeconds([[AudioManager shared].audioPlayer duration]);
                NSString *pretty = [Utils elapsedTimeStringWithPosition:currentTime
                                                            andDuration:duration];
                [[self scrubbingIndicatorLabel] setText:pretty];
                
                double se = [self strokeEndForCurrentTime];
                [self.scrubberController tick:se];
                
            }
        } else {
            [self tickLive];
        }
    }
    
    [self unmuteUI];
    
}

- (double)strokeEndForCurrentTime {
    if ( [[AudioManager shared] currentAudioMode] == AudioModeLive ) {
        ScheduleOccurrence *p = [[SessionManager shared] currentSchedule];
        return [p dateToPercentage:[[SessionManager shared] vNow]];

    } else if ( [[AudioManager shared] currentAudioMode] == AudioModeOnDemand ) {
        NSInteger cS = CMTimeGetSeconds([[[AudioManager shared] audioPlayer] currentTime]);
        NSInteger tS = CMTimeGetSeconds([[[AudioManager shared] audioPlayer] duration]);
        return (cS*1.0f / tS*1.0f);

    }

    
    return 0.0f;
}

#pragma mark - Live

- (void)tickLive:(BOOL)animated {
    [self tickLive];
}

- (void)tickLive {
    ScheduleOccurrence *p = [[SessionManager shared] currentSchedule];

    self.maxPercentage = [p dateToPercentage:[[SessionManager shared] vLive]];

    CGFloat percent = [p dateToPercentage:[[SessionManager shared] vNow]];

    CGFloat endPoint = self.scrubberController.view.frame.size.width * self.maxPercentage;

    [UIView animateWithDuration:0.25 animations:^{
        self.liveStreamProgressAnchor.constant = endPoint;

        [self behindLiveStatus];

        [self.scrubberController tick:percent];
        
        [self.view layoutIfNeeded];
    }];
}

- (void)recalibrateAfterScrub {
    

}

- (void)behindLiveStatus {
    [(SCPRMasterViewController*)self.parentControlView adjustScrubbingState];
    
    [UIView animateWithDuration:0.25f animations:^{
        self.timeBehindLiveLabel.alpha = 0.0f;
        
        NSString *uglyString = [[NSDate stringFromDate:[[SessionManager shared] vNow] withFormat:@"h:mm:ss a"] lowercaseString];
        NSAttributedString *fancyTime = [[DesignManager shared] standardTimeFormatWithString:uglyString
                                                                                  attributes:@{ @"digits" : [[DesignManager shared] proLight:32.0f],
                                                                                                @"period" : [[DesignManager shared] proLight:18.0f] }];
        [[self scrubbingIndicatorLabel] setAttributedText:fancyTime];
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
    if ( [[[AudioManager shared] status] status] == AudioStatusPlaying ) {
        self.scrubberController.currentBarLine.strokeEnd = 0.0f;
    } else {
        [self.scrubberController tick:0.0f];
    }
    
    [self.fw30Button addTarget:self
                        action:@selector(forward30)
              forControlEvents:UIControlEventTouchUpInside
     special:YES];
    
    [self.rw30Button addTarget:self
                        action:@selector(rewind30)
              forControlEvents:UIControlEventTouchUpInside
     special:YES];
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
