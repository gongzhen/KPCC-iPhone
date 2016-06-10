//
//  AudioManager.m
//  KPCC
//
//  Created by John Meeker on 3/6/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "AudioManager.h"
#import "NetworkManager.h"
#import "AnalyticsManager.h"
#import "QueueManager.h"
#import "AVPlayer+Additions.h"
#import "Program.h"
#import "Episode.h"
#import "Segment.h"
#import "NSDate+Helper.h"
#import "SessionManager.h"
#import "UXmanager.h"
#import "SCPRMasterViewController.h"
#import "Bookmark.h"

static AudioManager *singleton = nil;

// Define this constant for the key-value observation context.
static const NSString *ItemStatusContext;

@implementation AudioManager

+ (AudioManager*)shared {
    if (!singleton) {
        @synchronized(self) {
            singleton = [[AudioManager alloc] init];
            singleton.fadeQueue = [[NSOperationQueue alloc] init];
            singleton.savedVolumeFromMute = -1.0f;
            singleton.currentAudioMode = AudioModeNeutral;

            singleton.status = [[AVStatus alloc] init];
            UIImage* img = [UIImage imageNamed:@"coverart"];
            singleton.nowPlaying = [[NowPlayingManager alloc] initWithStatus:singleton.status image:img];
            
            [[NSNotificationCenter defaultCenter] addObserver:singleton
                                                         selector:@selector(handleInterruption:)
                                                             name:AVAudioSessionInterruptionNotification
                                                           object:nil];
            
            
            [[NSNotificationCenter defaultCenter] addObserver:singleton
                                                     selector:@selector(audioHardwareRouteChanged:)
                                                         name:AVAudioSessionRouteChangeNotification
                                                       object:nil];
        }
    }
    return singleton;
}

- (void)loadXfsStreamUrlWithCompletion:(Block)completion {
    
    PFQuery *settingsQuery = [PFQuery queryWithClassName:@"iPhoneSettings"];
    [settingsQuery whereKey:@"settingName"
             containsString:@"kpccPlus"];
    [settingsQuery findObjectsInBackgroundWithBlock:^( NSArray *objects, NSError *error ) {
        if (error) {
            CLS_LOG(@"loadXFS Parse query errored: %@",error);
            if (completion) completion();
            return;
        }
       
        if ( [objects count] > 0 ) {
            NSArray *names = @[@"kpccPlusStream",@"kpccPlusDriveStart",@"kpccPlusDriveEnd"];
            for ( PFObject *obj in objects) {
                NSString *v = obj[@"settingValue"];

                switch ([names indexOfObject:obj[@"settingName"]]) {
                    case 0:
                        self.xfsStreamUrl = v;
                        break;
                    case 1:
                        self.xfsDriveStart = [Utils dateFromRFCString:v];
                        break;
                    case 2:
                        self.xfsDriveEnd = [Utils dateFromRFCString:v];
                        break;
                }
            }

            self.xfsCheckComplete = YES;
        }

        if ( completion ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                CLS_LOG(@"Parse xfs information has loaded.");
                completion();
            });
        }
    }];
    
}

- (NSString*)streamingURL {
    
    NSDictionary *streams = [[Utils globalConfig] objectForKey:@"StreamMachine"];
    NSString *streamURL = @"";
        
    if ( [[UXmanager shared].settings userHasSelectedXFS] ) {
        if ( self.xfsStreamUrl ) {
            streamURL = self.xfsStreamUrl;
        } else {
            streamURL = streams[@"xfs"];
        }
    } else {
        streamURL = streams[@"standard"];
    }
    streamURL = [NSString stringWithFormat:@"%@?ua=KPCCiPhone-%@",streamURL,[Utils urlSafeVersion]];
    
    return streamURL;
    
}

- (void)audioHardwareRouteChanged:(NSNotification*)note {
    CLS_LOG(@"Received external audio route change notification...");
    NSLog(@"User Info : %@",[[note userInfo] description]);
    
    AVAudioSessionRouteDescription *previous = note.userInfo[AVAudioSessionRouteChangePreviousRouteKey];
    
    if ( [self isPlayingAudio] ) {
        BOOL userPause = [self userPause];
        if ( previous ) {
            NSArray *outputs = [previous outputs];
            for ( AVAudioSessionPortDescription *port in outputs ) {
                CLS_LOG(@"Changing from %@ output",[port portName]);
                if ( SEQ(port.portType,AVAudioSessionPortBuiltInSpeaker) ) {
                    userPause = NO;
                    break;
                } else {
                    userPause = YES;
                    break;
                }
            }
        }
        [self setUserPause:userPause];
    }
    [self setAudioOutputSourceChanging:YES];
}

- (void)handleInterruption:(NSNotification*)note {
    int interruptionType = [note.userInfo[AVAudioSessionInterruptionTypeKey] intValue];
    CLS_LOG(@"Interruption Options : %@",[note.userInfo description]);
    NSNumber *options = note.userInfo[AVAudioSessionInterruptionOptionKey];

    BOOL resume = NO;
    if ( options ) {
        if ( [options intValue] == AVAudioSessionInterruptionOptionShouldResume ) {
            resume = YES;
        }
    }

    SCPRMasterViewController *mvc = [[Utils del] masterViewController];

    switch (interruptionType) {
        case AVAudioSessionInterruptionTypeBegan:
            // not much to do at the start of an interruption.

            // stash audioplayer status, so that we know we can look at prev
            // when coming back from the interruption
            if (self.audioPlayer != nil) {
                [self.audioPlayer setPrevStatus:self.audioPlayer.status];
            }

            break;

        case AVAudioSessionInterruptionTypeEnded:
            switch (self.currentAudioMode) {
                case AudioModeOnboarding:
                    [[UXmanager shared] godPauseOrPlay];
                    break;

                case AudioModePreroll:

                    if ( mvc.preRollViewController && resume) {
                        [mvc.preRollViewController playOrPause];
                    }

                    break;

                default:
                    if ( self.audioPlayer != nil && [self.audioPlayer prevStatus] == AudioStatusPlaying ) {
                        // make sure we're able to start an audio session
                        if (![self.status beginAudioSession]) {
                            // abort...
                            CLS_LOG(@"Failed to start audio session after interruption.");
                            return;
                        }

                        if ([self.audioPlayer currentDates] != nil && [[self.audioPlayer currentDates] hasDates]) {
                            [self.audioPlayer seekToDate:[self.audioPlayer currentDates].curDate completion:^(BOOL finished) {
                                CLS_LOG(@"Played by seeking after interruption.");
                            }];
                        } else {
                            CLS_LOG("@Playing by hitting play after interruption.");
                            [self.audioPlayer play];
                        }
                    }

                    break;
            }

            break;

    }
    
    if ( interruptionType == AVAudioSessionInterruptionTypeEnded && !resume ) {
        CLS_LOG(@"Probably interrupted from another app, so don't resume");
        return;
    }

    [self printStatus];
}

- (void)printStatus {
    NSLog(@"Current audio status is %@",[self.status toString]);
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                        change:(NSDictionary *)change context:(void *)context {
    
}

#pragma mark - State
- (void)setCurrentAudioMode:(AudioMode)currentAudioMode {
    _currentAudioMode = currentAudioMode;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"audio-mode-changed"
                                                        object:nil
                                                      userInfo:@{ @"new-state" : @(currentAudioMode) }];
                                                                  
}

#pragma mark - Scrubbing and Seeking
- (void)seekToPercent:(CGFloat)percent {
    [self.audioPlayer seekToPercent:percent completion:^(BOOL finished) {
        if ([self.delegate respondsToSelector:@selector(onSeekCompleted)]) {
            [self.delegate onSeekCompleted];
        }
    }];
}

- (void)backwardSeekToBeginningOfProgram {
    ScheduleOccurrence *p = [[SessionManager shared] currentSchedule];

    if (p) {
        self.savedVolume = 1.0f;

        if (!self.audioPlayer) {
            [self buildStreamer:nil];
        }

        [self.audioPlayer seekToDate:p.soft_starts_at completion:^(BOOL finished) {
            if ([self.delegate respondsToSelector:@selector(onSeekCompleted)]) {
                [self.delegate onSeekCompleted];
            }

            [[AnalyticsManager shared] trackSeekUsageWithType:ScrubbingTypeRewindToStart];
        }];
    }
}

- (void)forwardSeekLiveWithType:(NSInteger)type completion:(Block)completion {
    if (!self.audioPlayer) {
        [self buildStreamer:nil];
    }

    [self.audioPlayer seekToLive:^(BOOL finished) {
        [self.delegate onSeekCompleted];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion();
            }
        });

        [[AnalyticsManager shared] trackSeekUsageWithType:type];
    }];
}

- (void)seekToDate:(NSDate *)date completion:(Block)completion {
    
    NSDate *now = [[SessionManager shared] vNow];
    [self intervalSeekWithTimeInterval:(-1.0f*[now timeIntervalSinceDate:date]) completion:completion];
    
}

- (void)intervalSeekWithTimeInterval:(NSTimeInterval)interval completion:(Block)completion {
    [self.audioPlayer seekByInterval:interval completion:^(BOOL finished) {
        if (completion) {
            completion();
        }
    }];
}

- (void)forwardSeekThirtySecondsWithCompletion:(Block)completion {
    NSTimeInterval forward = 30.0f;
    [self intervalSeekWithTimeInterval:forward completion:^{
        [[AnalyticsManager shared] trackSeekUsageWithType:ScrubbingTypeFwd30];
        if ( completion ) {
            completion();
        }
    }];
}

- (void)backwardSeekThirtySecondsWithCompletion:(Block)completion {
    NSTimeInterval backward = -30.0f;
    [self intervalSeekWithTimeInterval:backward completion:^{
        [[AnalyticsManager shared] trackSeekUsageWithType:ScrubbingTypeBack30];
        if ( completion ) {
            completion();
        }
    }];
}

- (void)forwardSeekFifteenSecondsWithCompletion:(Block)completion {
    NSTimeInterval backward = 15.0f;
    [self intervalSeekWithTimeInterval:backward completion:completion];
}

- (void)backwardSeekFifteenSecondsWithCompletion:(Block)completion {
    NSTimeInterval backward = -15.0f;
    [self intervalSeekWithTimeInterval:backward completion:completion];
}

- (void)recalibrateAfterScrub {
    NSDate *vNow = [[SessionManager shared] vNow];
    ScheduleOccurrence *cp = [[SessionManager shared] currentSchedule];

    if ( cp != nil && ![cp containsDate:vNow]) {
        NSLog(@"Scrub will force program update for vNow : %@",[NSDate stringFromDate:vNow withFormat:@"h:mm:s a"]);
        [[SessionManager shared] fetchCurrentSchedule:^(id object) {
            
        }];
    }
}

- (void)onboardingSegmentCompleted {
    if ( self.onboardingSegment == 1 ) {
        [[UXmanager shared] presentLensOverRewindButton];
    }
    if ( self.onboardingSegment == 2 ) {
        [[UXmanager shared] endOnboarding];
    }
    if ( self.onboardingSegment == 3 ) {
        [[UXmanager shared] endOnboarding];
    }
}

- (NSString*)avPlayerSessionString {
    return self.avSessionId;
}

#pragma mark - Audio Control
- (void)buildStreamer:(NSString*)urlString local:(BOOL)local {
    NSURL *url;
    if ( !urlString ) {
        urlString = self.previousUrl;
    }
    if ( urlString == nil || SEQ(urlString, kHLS) ) {
        url = [NSURL URLWithString:kHLS];
        self.currentAudioMode = AudioModeLive;

        // FIXME: This belongs somewhere else
        [[QueueManager shared] setCurrentBookmark:nil];
    } else {
        url = [NSURL URLWithString:urlString];
        self.currentAudioMode = AudioModeOnDemand;
    }
    
    if ( local ) {
        NSString *filePath = [[NSBundle mainBundle] pathForResource:urlString
                                                             ofType:@"mp3"];
        url = [NSURL fileURLWithPath:filePath];
        self.currentAudioMode = AudioModeOnboarding;
    }

    CLS_LOG(@"In buildStreamer for %@",urlString);
    
    if ( self.audioPlayer ) {
        [self takedownAudioPlayer];
    }

    // Note our current URL for Crashlytics
#ifdef RELEASE
    [[Crashlytics sharedInstance] setObjectValue:urlString forKey:@"streamerUrl"];
#endif

    self.audioPlayer = [[AudioPlayer alloc] initWithUrl:url hiResTick:local];

    // -- Time Observer -- //

    [self.audioPlayer observeTime:^(StreamDates* d) {
        // playing audio cancels an alarm
        if ( [[Utils del] alarmTask] > 0 ) {
            [[Utils del] killBackgroundTask];
        }

        // stash the date in our session
        if ([d hasDates]) {
            [[SessionManager shared] setLastValidCurrentPlayerTime:d.curDate];
        }

        // call our delegate if it wants to know about time changes
        if ([self.delegate respondsToSelector:@selector(onTimeChange)]) {
            [self.delegate onTimeChange];
        }

        // are we adjusting volume up?
        if ( self.smooth ) {
            [self adjustAudioWithValue:0.0045 completion:^{
            }];
        }

        // trigger bookmarking update
        if ( self.currentAudioMode == AudioModeOnDemand ) {
            [[QueueManager shared] handleBookmarkingActivity];
        }

        // tick the sleep timer
        if ( [[SessionManager shared] sleepTimerArmed] ) {
            [[SessionManager shared] tickSleepTimer];
        }

        // make sure our schedule occurrence is still correct
        [[SessionManager shared] checkProgramUpdate:NO];

        // Still needed?
        self.appGaveUp = NO;
        self.calibrating = NO;
        self.audioOutputSourceChanging = NO;
    }];

    [self.audioPlayer observeEvents:^(AudioEvent* e) {
        CLS_LOG(@"AudioPlayer: %@",e.message);
    }];

    // watch for failures
    void (^failure)(NSString*, id) = ^(NSString* msg, id obj) {
        switch ( [self.status status]) {
            case AudioStatusPlaying:
            case AudioStatusWaiting:
            case AudioStatusSeeking:
                if ( [self currentAudioMode] == AudioModeOnDemand ) {
                    // FIXME: do we need to also be tearing down our now-broken
                    // player?
                    if ( [self.delegate respondsToSelector:@selector(onDemandAudioFailed)] ) {
                        [self.delegate onDemandAudioFailed];
                    }
                } else {
                    CLS_LOG(@"Triggering tryAgain logic after player/item failed.");
                    self.failoverCount++;
                    if ( self.failoverCount > kFailoverThreshold ) {
                        self.tryAgain = NO;
                        self.failoverCount = 0;
                        [self stopAudio];
                    } else {
                        self.tryAgain = YES;

                        // do we have a position to restart with?
                        StreamDates* d = [self.audioPlayer currentDates];

                        [self resetPlayer];

                        if (d != nil && d.curDate != nil) {
                            [self.audioPlayer seekToDate:d.curDate completion:^(BOOL finished) {
                                CLS_LOG(@"Finished seek on player retry.");
                            }];
                        } else {
                            CLS_LOG(@"No retry position. Hitting play.");
                            [self playAudio];
                        }
                    }
                }

                break;

            default:
                CLS_LOG(@"Failure while player was not playing.");

                break;
        }
    };

    [self.audioPlayer.observer on:StatusesItemFailed callback:failure];
    [self.audioPlayer.observer on:StatusesPlayerFailed callback:failure];
    [self.audioPlayer.observer on:StatusesOtherFailed callback:failure];

    // watch for status changes and pass them on to our global status
    [self.audioPlayer observeStatus:^(AudioStatus status){
        [self.status setStatus:status];

        switch (status) {
            case AudioStatusPlaying:
            case AudioStatusPaused:
                if ([self.delegate respondsToSelector:@selector(onRateChange)]) {
                    [self.delegate onRateChange];
                }
                break;

            case AudioStatusError:
                failure(@"Player reports error.",nil);
                break;

            default:
                break;
        }
    }];

    // watch for logs
    [self.audioPlayer.observer on:StatusesAccessLog callback:^(NSString* msg, AVPlayerItemAccessLogEvent *obj) {
        [[AnalyticsManager shared] setAccessLog:obj];
    }];

    [self.audioPlayer.observer on:StatusesErrorLog callback:^(NSString* msg, AVPlayerItemErrorLogEvent *obj) {
        [[AnalyticsManager shared] setErrorLog:obj];
    }];

    // watch for item end
    [self.audioPlayer.observer on:StatusesItemEnded callback:^(NSString* msg, id obj) {
        if ([self currentAudioMode] == AudioModeOnDemand) {
            [[SessionManager shared] endOnDemandSessionWithReason:OnDemandFinishedReasonEpisodeEnd];

            if ( [[QueueManager shared] currentBookmark] ) {
                [[ContentManager shared] destroyBookmark:[[QueueManager shared] currentBookmark]];
                [[QueueManager shared] setCurrentBookmark:nil];
            }

            [[QueueManager shared] playNext];
        }
    }];

    // Watch for stalls
    [self.audioPlayer.observer on:StatusesStalled callback:^(NSString* msg, id obj) {
        NSLog(@"Playback has stalled ... ");
    }];

    // Watch for our session ID and stash it
    [self.audioPlayer.observer once:StatusesAccessLog callback:^(NSString *msg, AVPlayerItemAccessLogEvent *obj) {
        self.avSessionId = obj.playbackSessionID;
        CLS_LOG(@"Setting avSessionId to %@",self.avSessionId);
    }];

    [self.nowPlaying setPlayer:self.audioPlayer];

    [self.status setStatus:AudioStatusNew];

    self.previousUrl = urlString;
}

- (void)buildStreamer:(NSString *)urlString {
    [self buildStreamer:urlString local:NO];
}

- (void)takedownAudioPlayer {
    
    [[ContentManager shared] saveContext];
    
    if ( self.audioPlayer ) {
        [self.audioPlayer stop];
    }
    
    [self resetFlags];
    
    self.audioPlayer = nil;

    [self.nowPlaying setPlayer:nil];
    [self setCurrentAudioMode:AudioModeNeutral];
    [self.status setStatus:AudioStatusStopped];
}

- (void)resetPlayer {
    [self stopAudio];
    [self buildStreamer:kHLS];
}

- (void)resetFlags {
    self.seekWillAffectBuffer = NO;
    self.dropoutOccurred = NO;
    self.currentAudioMode = AudioModeNeutral;
    self.appGaveUp = NO;
}

- (void)sanitizeFromOnboarding {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AVPlayerItemDidPlayToEndTimeNotification
                                                  object:nil];
}

- (void)playQueueItem:(AudioChunk*)chunk {
    [self stopAudio];

    Bookmark *b = [[ContentManager shared] bookmarkForAudioChunk:chunk];
    [[QueueManager shared] setCurrentBookmark:b];

    if (!chunk.audioUrl) {
        if ( [self.delegate respondsToSelector:@selector(onDemandAudioFailed)] ) {
            [self.delegate onDemandAudioFailed];
        }
        return;
    }

    [self.nowPlaying setAudio:chunk];

    [[SessionManager shared] startOnDemandSession];
    [[[Utils del] masterViewController] showOnDemandOnboarding];

    NSString* url = [NSString stringWithString:chunk.audioUrl];
    if ( [url rangeOfString:@"?"].location == NSNotFound ) {
        url = [url stringByAppendingString:[NSString stringWithFormat:@"?ua=KPCCiPhone-%@",[Utils urlSafeVersion]]];
    } else {
        url = [url stringByAppendingString:[NSString stringWithFormat:@"&ua=KPCCiPhone-%@", [Utils urlSafeVersion]]];
    }

    [self buildStreamer:url];

    // see if we have a bookmark for where to start in this audio file
    Float64 resumeTime = 0;

    if ( b ) {
        Float64 duration = [b.duration floatValue];
        if ( b.resumeTimeInSeconds > 0 && ( fabs(duration - resumeTime) <= 1.0 || resumeTime >= duration )) {
            // invalid bookmark position. reset our stored value
            b.resumeTimeInSeconds = @(0);
        }

        resumeTime = [b.resumeTimeInSeconds floatValue];
    }

    if (resumeTime == 0) {
        CLS_LOG(@"ondemand playAudio should start from 0.");
        [self playAudio];
    } else {
        // seek
        CLS_LOG(@"ondemand playAudio should seek to %f.",resumeTime);

        // drop the volume so that we don't hear the initial play
        self.audioPlayer.volume = 0.0f;
        self.savedVolume = 1.0f;
        self.smooth = YES;

        [self intervalSeekWithTimeInterval:(NSTimeInterval)resumeTime completion:^{
            CLS_LOG(@"ondemand playAudio seek to %f successful.",resumeTime);
        }];
    }
}

- (void)playLiveStream {
    [[QueueManager shared] setCurrentBookmark:nil];
    
    [self stopAllAudio];
    [self buildStreamer:kHLS];
    [self playAudio];
}

- (void)playOnboardingAudio:(NSInteger)segment {

    [self stopAudio];
    
    self.onboardingSegment = segment;
    NSString *file = [NSString stringWithFormat:@"onboarding%ld",(long)segment];
    [self buildStreamer:file local:YES];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AVPlayerItemDidPlayToEndTimeNotification
                                                  object:nil];
     
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onboardingSegmentCompleted)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:nil];
    
    [self playAudio];
    
}

- (BOOL)isPlayingAudio {
    // FIXME: How should we be computing this?
    return [self.status playing];
}

- (BOOL)isActiveForAudioMode:(AudioMode)mode {
    if ( self.currentAudioMode != mode ) return NO;

    switch (self.status.status) {
        case AudioStatusPlaying:
        case AudioStatusPaused:
        case AudioStatusWaiting:
        case AudioStatusSeeking:
            return YES;
            break;
        default:
            return NO;
    }
}

- (void)playAudio {
    if (self.audioPlayer != nil && self.audioPlayer.status == AudioStatusPlaying) {
        // we're good
        return;
    }

    [self.status setStatus:AudioStatusWaiting];
    
    [[ContentManager shared] saveContext];
    
    if (!self.audioPlayer) {
        [self buildStreamer:kHLS];
    }
    
    if ( [self currentAudioMode] == AudioModeOnboarding ) {
        self.audioPlayer.volume = 0.0f;
    }

    // make sure we're able to start an audio session
    if ([self.status beginAudioSession]) {
        // good to go
    } else {
        // abort...
        [self.status setStatus:AudioStatusPaused];
        return;
    }
    
    [self setUserPause:NO];
    
    [[SessionManager shared] startAudioSession];    
    [[SessionManager shared] setSessionPausedDate:nil];

    if ( self.smooth ) {
        self.savedVolume = self.audioPlayer.volume;
        if ( self.savedVolume <= 0.0 ) {
            self.savedVolume = 1.0f;
        }

        self.audioPlayer.volume = 0.0f;
    }

    [self.audioPlayer play];
}

- (void)pauseAudio {
    
    [self.audioPlayer pause];

    if ( self.dropoutOccurred && !self.userPause ) {
        return;
    }
    
    if ( self.currentAudioMode == AudioModeLive ) {
        [[SessionManager shared] endLiveSession];
    } else {
        [[SessionManager shared] endOnDemandSessionWithReason:OnDemandFinishedReasonEpisodePaused];
    }
    
}

- (void)stopAudio {
    if ( [self isPlayingAudio] && self.currentAudioMode == AudioModeLive ) {
        [[SessionManager shared] endLiveSession];
    }
    
    [self takedownAudioPlayer];
    [self.status setStatus:AudioStatusStopped];

    // FIXME: This is dirty, but during onboarding we have two players running at once.
    if ([[UXmanager shared].settings userHasViewedOnboarding]) {
        [self.status endAudioSession];
    }
}

- (void)stopAllAudio {
    [self stopAudio];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"panic"
                                                        object:nil];
}

- (void)switchPlusMinusStreams {
    
    if ( [[UXmanager shared].settings userHasSelectedXFS] ) {
        [self loadXfsStreamUrlWithCompletion:^{
            [self finishSwitchPlusMinus];
        }];
    } else {
        [self finishSwitchPlusMinus];
    }

}

- (void)finishSwitchPlusMinus {
    if ( [self isActiveForAudioMode:AudioModeLive] ) {
        [self adjustAudioWithValue:-0.1f
                        completion:^{
                            [[AudioManager shared] stopAudio];
                            [[AudioManager shared] setSmooth:YES];
                            [[AudioManager shared] playAudio];
                        }];
    }
}

- (void)adjustAudioWithValue:(CGFloat)increment completion:(void (^)(void))completion {
    if ( increment < 0.0000f ) {
        if ( self.savedVolumeFromMute >= 0.0000f ) {
            self.savedVolume = self.savedVolumeFromMute;
        } else {
            self.savedVolume = self.audioPlayer.volume;
        }
    } else {
        if ( self.savedVolumeFromMute >= 0.0000f ) {
            self.savedVolume = self.savedVolumeFromMute;
        }
        self.savedVolumeFromMute = -1.0f;
    }
    [self threadedAdjustWithValue:increment completion:completion];
}

- (void)threadedAdjustWithValue:(CGFloat)increment completion:(void (^)(void))completion {
    
    
    BOOL basecase = NO;
    BOOL increasing = NO;
    if ( increment < 0.0000f ) {
        basecase = self.audioPlayer.volume <= 0.0f;
    } else {
        if ( self.smooth ) {
            basecase = self.audioPlayer.volume >= 1.0f;
        } else {
            basecase = self.audioPlayer.volume >= self.savedVolume;
        }
        increasing = YES;
    }
    
    if ( basecase ) {
        if ( increasing ) {
            self.audioPlayer.volume = self.savedVolume;
        }
        
        self.smooth = NO;
        
        if ( completion ) {
            dispatch_async(dispatch_get_main_queue(), completion);
        }
    } else {
        NSBlockOperation *block = [NSBlockOperation blockOperationWithBlock:^{
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self.audioPlayer setVolume:self.audioPlayer.volume+increment];
                [self threadedAdjustWithValue:increment completion:completion];
            });
        }];
        [self.fadeQueue addOperation:block];
    }
}

- (void)muteAudio {
    self.savedVolumeFromMute = self.audioPlayer.volume;
    if ( self.savedVolumeFromMute <= 0.0 ) self.savedVolumeFromMute = 1.0f;
    self.audioPlayer.volume = 0.0f;
}

- (void)unmuteAudio {
    self.audioPlayer.volume = self.savedVolumeFromMute;
    self.savedVolumeFromMute = -1.0f;
}

- (BOOL)isStreamPlaying {
    if (self.audioPlayer && [self.audioPlayer._player rate] > 0.0) {
        return YES;
    } else {
        return NO;
    }
}

- (BOOL)isStreamBuffering {
    // Old.. can most likely be removed.
    return NO;
}

@end
