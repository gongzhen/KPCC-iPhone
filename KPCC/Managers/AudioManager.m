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
static NSInteger kLocalSampleSize = 5;

// Define this constant for the key-value observation context.
static const NSString *ItemStatusContext;

@implementation AudioManager

+ (AudioManager*)shared {
    if (!singleton) {
        @synchronized(self) {
            singleton = [[AudioManager alloc] init];
            singleton.fadeQueue = [[NSOperationQueue alloc] init];
            singleton.status = StreamStatusStopped;
            singleton.savedVolumeFromMute = -1.0f;
            singleton.currentAudioMode = AudioModeNeutral;
            singleton.localBufferSample = [NSMutableDictionary new];
            singleton.frameCount = 1;

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

- (NSString*)standardHlsStream {
    return [self streamingURL:YES
                      preskip:NO
                          mp3:NO];
}

- (NSString*)streamingURL:(BOOL)hls preskip:(BOOL)preskip mp3:(BOOL)mp3 {
    
    NSDictionary *streams = [[Utils globalConfig] objectForKey:@"StreamMachine"];
    NSString *streamURL = @"";
    if ( hls ) {
        
        if ( [[UXmanager shared].settings userHasSelectedXFS] ) {
            streamURL = streams[@"xfs"];
        } else {
            streamURL = streams[@"standard"];
        }
        streamURL = [NSString stringWithFormat:@"%@?ua=KPCCiPhone-%@",streamURL,[Utils urlSafeVersion]];
        
    } else {
        
        NSString *keybase = @"xcast-";
        if ( mp3 ) {
            keybase = [keybase stringByAppendingString:@"mp3"];
        } else {
            keybase = [keybase stringByAppendingString:@"aac"];
        }
        streamURL = streams[keybase];

        if ( preskip ) {
            streamURL = [streamURL stringByAppendingString:@"?preskip=true"];
        }
        
    }

#ifdef SANITY_STREAM_TEST
    streamURL = streams[@"external-test"];
#endif
    
    return streamURL;
    
}

- (void)audioHardwareRouteChanged:(NSNotification*)note {
    NSLog(@"Received external audio route change notification...");
    NSLog(@"User Info : %@",[[note userInfo] description]);
    
    AVAudioSessionRouteDescription *previous = note.userInfo[AVAudioSessionRouteChangePreviousRouteKey];
    
    if ( [self isPlayingAudio] ) {
        BOOL userPause = [self userPause];
        if ( previous ) {
            NSArray *outputs = [previous outputs];
            for ( AVAudioSessionPortDescription *port in outputs ) {
                NSLog(@"Changing from %@ output",[port portName]);
                if ( SEQ(port.portType,AVAudioSessionPortBuiltInSpeaker) ) {
                    userPause = NO;
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
    NSLog(@"Options : %@",[note.userInfo description]);
    NSNumber *resume = note.userInfo[AVAudioSessionInterruptionOptionKey];
    
    BOOL pickup = NO;
    if ( resume ) {
        if ( [resume intValue] == AVAudioSessionInterruptionOptionShouldResume ) {
            pickup = YES;
        }
    }
    
    if ( interruptionType == AVAudioSessionInterruptionTypeEnded && !pickup ) {
        NSLog(@"Probably interrupted from another app, so don't resume");
        self.reactivate = NO;
        return;
    }
    
    if ( self.currentAudioMode == AudioModeOnboarding ) {

        [[UXmanager shared] godPauseOrPlay];
        
    } else if ( self.currentAudioMode == AudioModePreroll ) {
        
        SCPRMasterViewController *mvc = [[Utils del] masterViewController];
        if ( mvc.preRollViewController ) {
            if ( interruptionType == AVAudioSessionInterruptionTypeBegan ) {
                if ( [mvc.preRollViewController.prerollPlayer rate] > 0.0 ) {
                    self.reactivate = YES;
                    [mvc.preRollViewController.prerollPlayer pause];
                } else {
                    self.reactivate = NO;
                }
            } else if ( interruptionType == AVAudioSessionInterruptionTypeEnded ) {
                if ( [mvc.preRollViewController.prerollPlayer rate] <= 0.0 && self.reactivate ) {
                    [mvc.preRollViewController.prerollPlayer play];
                    self.reactivate = NO;
                } else {
                    self.reactivate = NO;
                }
            }
        }
        
    } else {
        if (interruptionType == AVAudioSessionInterruptionTypeBegan) {
            if ( self.audioPlayer ) {
                if ( self.audioPlayer.rate > 0.0 ) {
                    self.reactivate = YES;
                    [self setAudioOutputSourceChanging:YES];
                    [[SessionManager shared] setLastKnownPauseExplanation:PauseExplanationAudioInterruption];
                    [self pauseAudio];
                } else {
                    self.reactivate = NO;
                }
            }
            
            [[ContentManager shared] saveContext];
            
        } else if (interruptionType == AVAudioSessionInterruptionTypeEnded) {
            if ( self.audioPlayer ) {
                if ( self.audioPlayer.rate <= 0.0 && self.reactivate ) {
                    [self playAudio];
                    self.reactivate = NO;
                } else {
                    self.reactivate = NO;
                }
            }
        }
    }
    
    [self printStatus];
}

- (void)printStatus {
    switch (self.status) {
        case StreamStatusPaused:
            NSLog(@"CurrentStatus - Stream is paused");
            break;
        case StreamStatusPlaying:
            NSLog(@"CurrentStatus - Stream is playing");
            break;
        case StreamStatusStopped:
            NSLog(@"CurrentStatus - Stream is stopped");
            break;
        default:
            break;
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                        change:(NSDictionary *)change context:(void *)context {
    
    NSAssert([NSThread isMainThread],@"not the main queue...");
#ifdef VERBOSE_LOGGING
    NSLog(@"Event received for : %@",[object description]);
#endif
    
    if ( object == self.audioPlayer.currentItem && [keyPath isEqualToString:@"status"] ) {
        if ([self.audioPlayer.currentItem status] == AVPlayerItemStatusFailed) {
            NSError *error = [self.audioPlayer.currentItem error];
            NSLog(@"AVPlayerItemStatus ERROR! --- %@", error);
            
            if ( [self currentAudioMode] == AudioModeOnDemand ) {
                if ( [self.delegate respondsToSelector:@selector(onDemandAudioFailed)] ) {
                    [self.delegate onDemandAudioFailed];
                }
            } else {
                if ( self.audioPlayer ) {
                    self.failoverCount++;
                    if ( self.failoverCount > kFailoverThreshold ) {
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                            self.tryAgain = NO;
                            self.failoverCount = 0;
                            [self analyzeStreamError:[error prettyAnalytics]];
                            [self stopAudio];
                        });
                    } else {
                    
                        self.tryAgain = YES;  
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                            [self resetPlayer];
                        });
                        
                    }

                }
            }
            return;
            
        } else if ([self.audioPlayer.currentItem status] == AVPlayerItemStatusReadyToPlay) {
            
            if ( self.waitForSeek ) {
                NSLog(@"Delayed seek");
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self backwardSeekToBeginningOfProgram];
                });
            } else if ( self.tryAgain ) {
                NSLog(@"Trying again after failure...");
                self.failoverCount = 0;
                self.tryAgain = NO;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self playAudio];
                });
            } else {
#ifndef SUPPRESS_BITRATE_THROTTLING
                if ( [Utils isIOS8] ) {
                    if ( ![[NetworkManager shared] wifi] ) {
                        [self.audioPlayer.currentItem setPreferredPeakBitRate:kPreferredPeakBitRateTolerance];
                    }
                }
#endif
                if ( self.waitForOnDemandSeek ) {
                    self.waitForOnDemandSeek = NO;
                    @try {
                        [self.audioPlayer.currentItem seekToTime:CMTimeMakeWithSeconds(self.onDemandSeekPosition, 1) completionHandler:^(BOOL finished) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [self.audioPlayer play];
                            });
                        }];
                    }
                    @catch (NSException *exception) {
                        NSLog(@"Couldn't seek : %@",[exception description]);
                        [self.audioPlayer play];
                    }
                    @finally {
                        
                    }
                } else {
                    if ( self.dropoutOccurred ) {
                        [self.audioPlayer pause];
                    }
                    if ( (self.audioPlayer.rate == 0.0 && self.beginNormally) || (self.audioPlayer.rate == 0.0 && self.dropoutOccurred) ) {
                        if ( !self.userPause ) {
                            if ( !self.seekWillEffectBuffer ) {
                                NSLog(@"All systems go...");
                                [self.audioPlayer play];
                            }
                        }
                    }
                    if ( self.appGaveUp ) {
#ifndef SUPPRESS_BITRATE_THROTTLING
                        if ( [Utils isIOS8] ) {
                            [self.audioPlayer.currentItem setPreferredPeakBitRate:kPreferredPeakBitRateTolerance];
                        }
#endif
                        [[AnalyticsManager shared] logEvent:@"streamRecoveredAfterUserInteraction"
                                             withParameters:nil];
                        
                    }
                }
            }
            
        } else if ([self.audioPlayer.currentItem status] == AVPlayerItemStatusUnknown) {
            NSLog(@"AVPlayerItemStatus - Unknown");
        }
    }
    
    // Monitoring AVPlayer->currentItem with empty playback buffer.
    if (object == self.audioPlayer.currentItem && [keyPath isEqualToString:@"playbackBufferEmpty"]) {
        if ( [change[@"new"] intValue] == 1 ) {
            if ( !self.seekWillEffectBuffer ) {
                NSLog(@"Buffer is empty ...");
#ifndef SUPPRESS_BITRATE_THROTTLING
                if ( !self.userPause ) {
                    if ( !self.audioOutputSourceChanging ) {
                        if ( [Utils isIOS8] ) {
                            [self.audioPlayer.currentItem setPreferredPeakBitRate:kPreferredPeakBitRateTolerance];
                        }
                        
                        [[NSNotificationCenter defaultCenter] postNotificationName:AVPlayerItemPlaybackStalledNotification
                                                                            object:nil];
                        
                        
                    } else {
                        NSLog(@"Ignoring this buffer emptiness because it was triggered by an output source change");
                    }
                } else {
                    NSLog(@"Ignoring buffer emptiness because we're not attempting to play audio");
                }
#endif
            }
        } else {
            //NSLog(@"AVPlayerItem - Buffer filled normally...");
        }
    }
    
    if (object == self.audioPlayer.currentItem && [keyPath isEqualToString:@"playbackLikelyToKeepUp"]) {
        if ( [change[@"new"] intValue] == 0 ) {
            if ( [self isPlayingAudio] ) {
                if ( !self.seekWillEffectBuffer ) {
                    NSLog(@"AVPlayerItem - Stream not likely to keep up...");
                    if ( !self.audioOutputSourceChanging ) {
                        [self waitPatiently];
                    }
                }
            }
        } else {
            if ( self.dropoutOccurred ) {
                NSLog(@"AVPlayerItem - Stream likely to return after failure...");
                [self attemptToRecover];
            }
        }
    }
    
    // Monitoring AVPlayer status.
    if (object == self.audioPlayer && [keyPath isEqualToString:@"status"]) {
        if ([self.audioPlayer status] == AVPlayerStatusFailed) {
            NSError *error = [self.audioPlayer error];
            NSLog(@"AVPlayerStatus ERROR! --- %@", error);
            return;
        } else if ([self.audioPlayer status] == AVPlayerStatusReadyToPlay) {
            NSLog(@"AVPlayerStatus - ReadyToPlay");
        } else if ([self.audioPlayer status] == AVPlayerStatusUnknown) {
            NSLog(@"AVPlayerStatus - Unknown");
        }
    }
    
    // Monitoring AVPlayer rate.
    if (object == self.audioPlayer && [keyPath isEqualToString:@"rate"]) {
        
        CGFloat oldRate = [change[@"old"] floatValue];
        CGFloat newRate = [change[@"new"] floatValue];
        
        // Now playing, was stopped.
        if (oldRate == 0.0 && newRate == 1.0) {
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self startObservingTime];
            });
        }
        
        if ( oldRate == 1.0 && newRate == 0.0 ) {
            self.status = StreamStatusPaused;
        }
        
        if ([self.delegate respondsToSelector:@selector(onRateChange)]) {
            [self.delegate onRateChange];
        }
        
    }
}



#pragma mark - Recovery / Logging / Stalls
- (void)playbackStalled:(NSNotification*)note {
    
    self.dropoutOccurred = YES;
    
#ifndef SUPPRESS_GIVEUP_TIMER
    if ( self.giveupTimer ) {
        if ( [self.giveupTimer isValid] ) {
            [self.giveupTimer invalidate];
        }
        self.giveupTimer = nil;
    }
    
    self.giveupTimer = [NSTimer scheduledTimerWithTimeInterval:kGiveUpTolerance
                                                        target:self
                                                      selector:@selector(giveUpOnStream)
                                                      userInfo:nil
                                                       repeats:NO];

#endif
    
    if ( !self.seekWillEffectBuffer ) {
        if ( !self.audioOutputSourceChanging ) {
            self.dropoutOccurred = YES;
#ifndef SUPPRESS_LOCAL_SAMPLING
            [self invalidateTimeObserver];
#endif
#ifndef SUPPRESS_AGGRESSIVE_KICKSTART
            self.kickstartTimer = [NSTimer scheduledTimerWithTimeInterval:kImpatientWaitingTolerance
                                                                   target:self
                                                                 selector:@selector(impatientRestart)
                                                                 userInfo:nil
                                                                  repeats:NO];
#endif
            if ( !self.failureGate ) {
                NSLog(@"Playback stalled ... ");
                self.failureGate = YES;
                self.reasonToReportError = @"playbackStalled";
                self.waitForLogTimer = [NSTimer scheduledTimerWithTimeInterval:4.0f
                                                                        target:self
                                                                      selector:@selector(forceAnalysis)
                                                                      userInfo:nil
                                                                       repeats:NO];
            }
            
        } else {
            NSLog(@"Ignoring this failure as it was generated by changing the audio source");
        }
    }
    
    

}

- (void)forceAnalysis {
    [[AnalyticsManager shared] clearLogs];
    [[AnalyticsManager shared] logEvent:self.reasonToReportError
                         withParameters:@{ @"errorComment" : @"No error log posted" }];
    self.reasonToReportError = nil;
}

- (void)giveUpOnStream {
    if ( self.dropoutOccurred ) {
        NSLog(@"Giving up. Restarting requires user action...");
        [self stopAudio];
        self.dropoutOccurred = NO;
        self.appGaveUp = YES;
    }
}

- (void)interruptAutorecovery {
    if ( self.kickstartTimer ) {
        if ( [self.kickstartTimer isValid] ) {
            [self.kickstartTimer invalidate];
        }
        self.kickstartTimer = nil;
    }
}

- (void)attemptToRecover {
#ifndef SUPPRESS_GIVEUP_TIMER
    if ( self.giveupTimer ) {
        if ( [self.giveupTimer isValid] ) {
            [self.giveupTimer invalidate];
        }
        self.giveupTimer = nil;
    }
#endif
    
#ifndef SUPPRESS_AGGRESSIVE_KICKSTART
    if ( self.kickstartTimer ) {
        if ( [self.kickstartTimer isValid] ) {
            [self.kickstartTimer invalidate];
        }
        self.kickstartTimer = nil;
    }
#endif
    
    [self stopWaiting];
    
    self.localBufferSample = nil;
    self.dropoutOccurred = NO;
    self.failureGate = NO;
    
    if ( self.audioPlayer.rate == 1.0f ) {
        if ( !self.timeObserver ) {
            [self startObservingTime];
        }
    }
    
    if ( !self.appGaveUp ) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [[AnalyticsManager shared] clearLogs];
            [[AnalyticsManager shared] logEvent:@"streamRecovered"
                                 withParameters:@{}];
            
        });
    }
}

- (void)impatientRestart {
#ifndef SUPPRESS_AGGRESSIVE_KICKSTART
    if ( [self.audioPlayer rate] > 0.0 && self.dropoutOccurred ) {
        [self.audioPlayer pause];
        [self takedownAudioPlayer];
        [self buildStreamer:kHLS];
    }
#endif
}

- (void)waitPatiently {

    if ( [[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground ) {
#ifdef DEBUG
        self.multipurposeTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self
                                                                selector:@selector(timeRemaining)
                                                                userInfo:nil
                                                                 repeats:YES];
#endif
        self.rescueTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
            NSLog(@"System is killing us off ... wrapping it up");
            self.dropoutOccurred = NO;
            [self stopWaiting];
            [self stopAllAudio];
        }];
    }
}

- (void)stopWaiting {
#ifdef DEBUG
    if ( self.multipurposeTimer ) {
        if ( [self.multipurposeTimer isValid] ) {
            [self.multipurposeTimer invalidate];
        }
        self.multipurposeTimer = nil;
    }
#endif
    if ( self.rescueTask > 0 ) {
        [[UIApplication sharedApplication] endBackgroundTask:self.rescueTask];
        self.rescueTask = 0;
    }
}

- (void)timeRemaining {
    NSLog(@"Expiry in : %ld",(long)[[UIApplication sharedApplication] backgroundTimeRemaining]);
}

- (void)logReceived:(NSNotification*)note {
    if ( SEQ([note name],AVPlayerItemNewErrorLogEntryNotification) ) {
        
        NSLog(@"Error log received....");
        
        if ( self.waitForLogTimer ) {
            if ( [self.waitForLogTimer isValid] ) {
                [self.waitForLogTimer invalidate];
            }
            self.waitForLogTimer = nil;
        }
        
        [[AnalyticsManager shared] setErrorLog:self.audioPlayer.currentItem.errorLog];
        if ( self.reasonToReportError ) {
            [[AnalyticsManager shared] logEvent:self.reasonToReportError
                                 withParameters:@{}];
            self.reasonToReportError = nil;
        }
    }
    if ( SEQ([note name],AVPlayerItemNewAccessLogEntryNotification) ) {
        [[AnalyticsManager shared] setAccessLog:self.audioPlayer.currentItem.accessLog];
    }
}



- (void)localSample:(CMTime)time {
    NSArray *seekRange = self.audioPlayer.currentItem.seekableTimeRanges;
    
    NSDate *now = [NSDate date];
    NSDate *msd = self.maxSeekableDate;
    if ( msd && [msd isWithinReasonableframeOfDate:now] ) {
        
        NSInteger drift = [now timeIntervalSince1970] - [msd timeIntervalSince1970];
        if ( (drift - [[SessionManager shared] peakDrift] > kToleratedIncreaseInDrift) ) {
            [[AnalyticsManager shared] logEvent:@"driftIncreasing"
                                 withParameters:@{ @"oldDrift" : @([[SessionManager shared] peakDrift]),
                                                   @"newDrift" : @(drift) }];
            NSLog(@"Drift increasing - Old : %ld, New : %ld",(long)[[SessionManager shared] peakDrift], (long)drift);
        } else {
            //NSLog(@"Drift stabilizing - Old : %ld, New : %ld",(long)[[SessionManager shared] peakDrift], (long)drift);
        }
        
        [[SessionManager shared] setPeakDrift:MAX(drift,[[SessionManager shared] peakDrift])];
        if ( [[SessionManager shared] minDrift] > 0 ) {
            [[SessionManager shared] setMinDrift:MIN(drift,[[SessionManager shared] minDrift])];
        } else {
            [[SessionManager shared] setMinDrift:drift];
        }
        
        [[SessionManager shared] setCurDrift:drift];
        
    }
    
    AVPlayer *audioPlayer = self.audioPlayer;
    if ( !self.localBufferSample || !self.localBufferSample[@"expectedDate"] ) {
        self.localBufferSample = [NSMutableDictionary new];
        self.localBufferSample[@"expectedDate"] = audioPlayer.currentItem.currentDate;
        NSMutableArray *samples = [NSMutableArray new];
        self.localBufferSample[@"samples"] = samples;
        self.localBufferSample[@"open"] = @(YES);
        self.localBufferSample[@"frame"] = @(self.frameCount);
        self.localBufferSample[@"expectedTime"] = [NSValue valueWithCMTime:audioPlayer.currentItem.currentTime];
    }
    
    
    if ( [self.localBufferSample[@"open"] boolValue] ) {
        NSMutableArray *localSamples = self.localBufferSample[@"samples"];
        if ( [localSamples count] >= kLocalSampleSize ) {
            [localSamples removeAllObjects];
        }
        
        NSDate *expectedDate = self.localBufferSample[@"expectedDate"];
        NSDate *reportedDate = self.audioPlayer.currentItem.currentDate;
        
        CMTime expectedTime = [self.localBufferSample[@"expectedTime"] CMTimeValue];
        CMTime reportedTime = time;
   
        Float64 etFloat = CMTimeGetSeconds(expectedTime);
        Float64 rtFloat = CMTimeGetSeconds(reportedTime);
        
        NSString *expStr = [NSDate stringFromDate:[expectedDate dateByAddingTimeInterval:1]
                                       withFormat:@"HH:mm:ss a"];
        NSString *repStr = [NSDate stringFromDate:reportedDate
                                       withFormat:@"HH:mm:ss a"];
        
        CMTimeRange range = [seekRange[0] CMTimeRangeValue];
        Float64 maxSeekTime = CMTimeGetSeconds(CMTimeRangeGetEnd(range));
        
        //NSLog(@"Reported Date : %@, Expected Date : %@",repStr,expStr);
        if ( fabs(etFloat - rtFloat) > kSmallSkipInterval || ![expectedDate isWithinTimeFrame:kSmallSkipInterval ofDate:reportedDate] ) {
            
            if ( !self.seekWillEffectBuffer ) {
                if ( self.userPause ) {
                    return;
                }
            
                NSLog(@"Stream skipped a bit : %ld seconds",(long)fabs([reportedDate timeIntervalSince1970] - [expectedDate timeIntervalSince1970]));
                NSLog(@"Reported Date : %@, Expected Date : %@",repStr,expStr);
                
#ifndef SUPPRESS_SKIP_FIXER
                
                self.localBufferSample[@"expectedDate"] = expectedDate;
                self.localBufferSample[@"open"] = @(NO);


                if ( self.skipCount < 1 ) {
                    
                    NSDate *seek = [[SessionManager shared] vLive];
                    if ( [[SessionManager shared] lastValidCurrentPlayerTime] ) {
                        seek = [[SessionManager shared] lastValidCurrentPlayerTime];
                    }
                    NSLog(@"ATTEMPT TO FIX : Get back to %@ when now is %@",[NSDate stringFromDate:seek
                                                                         withFormat:@"h:mm:ss"],repStr);
                    
                    [self seekToDate:[reportedDate laterDate:seek] completion:^{
                        
                        self.skipCount++;
                        NSDate *now = self.audioPlayer.currentItem.currentDate;
                        NSString *currTime = [NSDate stringFromDate:now
                                                         withFormat:@"HH:mm:ss a"];
                        
                        [[AnalyticsManager shared] logEvent:@"attemptToFixLargeGapInStream"
                                             withParameters:@{ @"expected" : expStr,
                                                               @"reported" : repStr,
                                                               @"timeAfterAttemptToFix" : currTime,
                                                               @"reportedTimeValue" : @(rtFloat),
                                                               @"reportedMaxSeekTime" : @(maxSeekTime)}];
                        
                    }];
                    
                } else {
                    [[AnalyticsManager shared] logEvent:@"skippedTooManyTimes"
                                         withParameters:@{}];
                    
                    [self stopAudio];
                }

            }
#endif
            return;
        }
        
        
        self.localBufferSample[@"frame"] = @([localSamples count]);
        
        
        [localSamples addObject:@{ @"frame" : @(self.frameCount),
                                   @"sampleTime" : [NSValue valueWithCMTime:time] }];
        
        self.localBufferSample[@"expectedDate"] = self.audioPlayer.currentItem.currentDate;
        self.localBufferSample[@"expectedTime"] = [NSValue valueWithCMTime:time];
        
    }
}

- (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForRenewalOfRequestedResource:(AVAssetResourceRenewalRequest *)renewalRequest {
    return YES;
}


#pragma mark - State
- (void)setCurrentAudioMode:(AudioMode)currentAudioMode {
    _currentAudioMode = currentAudioMode;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"audio-mode-changed"
                                                        object:nil
                                                      userInfo:@{ @"new-state" : @(currentAudioMode) }];
                                                                  
}

#pragma mark - General
- (void)updateNowPlayingInfoWithAudio:(id)audio {
    if (!audio) {
        return;
    }

    NSDictionary *audioMetaData = @{};
    if ([audio isKindOfClass:[Episode class]]) {
        Episode *episode = (Episode*)audio;
        if ( episode.programName && episode.title && episode.audio ) {
            audioMetaData = @{ MPMediaItemPropertyArtist : episode.programName,
                               MPMediaItemPropertyTitle : episode.title,
                               MPMediaItemPropertyPlaybackDuration : episode.audio.duration };
        }
    } else if ([audio isKindOfClass:[Segment class]]) {
        Segment *segment = (Segment*)audio;
        if ( segment.programName && segment.title && segment.audio ) {
            audioMetaData = @{ MPMediaItemPropertyArtist : segment.programName,
                               MPMediaItemPropertyTitle : segment.title,
                               MPMediaItemPropertyPlaybackDuration : segment.audio.duration};
        }
    } else if ([audio isKindOfClass:[Program class]]) {
        Program *program = (Program*)audio;
        if ( program.title ) {
            audioMetaData = @{ MPMediaItemPropertyArtist : @"89.3 KPCC",
                               MPMediaItemPropertyTitle : program.title };
        }
    } else if ([audio isKindOfClass:[AudioChunk class]]) {
        AudioChunk *chunk = (AudioChunk*)audio;
        if (chunk.programTitle && chunk.audioTitle && chunk.audioDuration) {
            audioMetaData = @{ MPMediaItemPropertyArtist : chunk.programTitle,
                               MPMediaItemPropertyTitle : chunk.audioTitle,
                               MPMediaItemPropertyPlaybackDuration : chunk.audioDuration};
        }
    } else {
        audioMetaData = @{ MPMediaItemPropertyArtist : @"89.3 KPCC"};
    }

    [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:audioMetaData];
}


- (void)startObservingTime {
    
    AVPlayer *audioPlayer = self.audioPlayer;
    __unsafe_unretained typeof(self) weakSelf = self;

    if ( [[Utils del] alarmTask] > 0 ) {
        [[Utils del] killBackgroundTask];
    }
    
    [self invalidateTimeObserver];
    
    self.calibrating = YES;
    self.timeObserver = nil;
    self.waitForFirstTick = YES;
    self.frameCount = 0;
    self.failureGate = NO;
    
    self.timeObserver = [self.audioPlayer addPeriodicTimeObserverForInterval:CMTimeMake(1, 10) queue:NULL usingBlock:^(CMTime time) {
                                                                      
        if ( weakSelf.frameCount % 10 == 0 ) {
            weakSelf.currentDate = audioPlayer.currentItem.currentDate;
            if ( [[SessionManager shared] dateIsReasonable:weakSelf.currentDate] ) {
                [[SessionManager shared] setLastValidCurrentPlayerTime:weakSelf.currentDate];
            }
            weakSelf.seekWillEffectBuffer = NO;
        }
        
        if ( weakSelf.dropoutOccurred ) {
            weakSelf.dropoutOccurred = NO;
#ifndef SUPPRESS_BITRATE_THROTTLING
            if ( [Utils isIOS8] ) {
                weakSelf.audioPlayer.currentItem.preferredPeakBitRate = kPreferredPeakBitRateTolerance;
            }
#endif
        }
        weakSelf.bufferEmpty = NO;
        weakSelf.beginNormally = NO;
        weakSelf.streamWarning = NO;
        
        NSArray *seekRange = audioPlayer.currentItem.seekableTimeRanges;
        if (seekRange && [seekRange count] > 0) {
            CMTimeRange range = [seekRange[0] CMTimeRangeValue];
            if ([weakSelf.delegate respondsToSelector:@selector(onTimeChange)]) {
                [weakSelf.delegate onTimeChange];
            }
            
            if ( weakSelf.smooth ) {
                [weakSelf adjustAudioWithValue:0.0045 completion:^{
                    
                }];
            }
            
#ifndef SUPPRESS_AGGRESSIVE_KICKSTART
            if ( weakSelf.kickstartTimer ) {
                if ( [weakSelf.kickstartTimer isValid] ) {
                    [weakSelf.kickstartTimer invalidate];
                }
                weakSelf.kickstartTimer = nil;
            }
#endif
            
            weakSelf.minSeekableDate = [NSDate dateWithTimeInterval:( -1 * (CMTimeGetSeconds(time) - CMTimeGetSeconds(range.start))) sinceDate:weakSelf.currentDate];
            weakSelf.maxSeekableDate = [NSDate dateWithTimeInterval:(CMTimeGetSeconds(CMTimeRangeGetEnd(range)) - CMTimeGetSeconds(time)) sinceDate:weakSelf.currentDate];
            

            if ( self.currentAudioMode == AudioModeLive ) {
                if ( [[SessionManager shared] localLiveTime] == 0.0f ) {
                    NSDate *vLive = [[SessionManager shared] vLive];
                    if ( [[SessionManager shared] dateIsReasonable:vLive] ) {
                        [[SessionManager shared] setLocalLiveTime:[vLive timeIntervalSince1970]];
                    }
                } else {
                    [[SessionManager shared] setLocalLiveTime:[[SessionManager shared] localLiveTime]+0.1f];
                }
            } else {
                [[SessionManager shared] setLocalLiveTime:0.0f];
            }
            
            if ( weakSelf.frameCount % 10 == 0 ) {
                
#ifndef SUPPRESS_LOCAL_SAMPLING
                if ( weakSelf.currentAudioMode == AudioModeLive ) {
                    [weakSelf localSample:time];
                }
#endif
                if ( weakSelf.currentAudioMode == AudioModeOnDemand ) {
                    [[QueueManager shared] handleBookmarkingActivity];
                }
                
                weakSelf.userPause = NO;
                weakSelf.seekWillEffectBuffer = NO;
                weakSelf.seekRequested = NO;
                weakSelf.appGaveUp = NO;
                
                if ( [[SessionManager shared] sleepTimerArmed] ) {
                    [[SessionManager shared] tickSleepTimer];
                }
                
                [[SessionManager shared] trackLiveSession];
                [[SessionManager shared] trackRewindSession];
                [[SessionManager shared] trackOnDemandSession];
                [[SessionManager shared] checkProgramUpdate:NO];
                

                weakSelf.calibrating = NO;
                weakSelf.audioOutputSourceChanging = NO;
                
            }

            if ( weakSelf.frameCount == 300) {
                // After 30 seconds, consider skip probation period over
                weakSelf.skipCount = 0;
                NSLog(@"Ending skip probation period");
            }
            
            if ( weakSelf.frameCount % 10000 == 0 ) {
                weakSelf.frameCount = 0;
            }
            
            weakSelf.frameCount++;
            
        }
        
        
    }];
    
}

- (void)invalidateTimeObserver {
    if ( self.timeObserver ) {
        [[SessionManager shared] setLocalLiveTime:0.0f];
        [self.audioPlayer removeTimeObserver:self.timeObserver];
        self.timeObserver = nil;
        self.localBufferSample = nil;
    }
}

#pragma mark - Scrubbing and Seeking
- (void)seekToPercent:(CGFloat)percent {
    NSArray *seekRange = self.audioPlayer.currentItem.seekableTimeRanges;
    if (seekRange && [seekRange count] > 0) {
        CMTimeRange range = [seekRange[0] CMTimeRangeValue];

        CMTime seekTime = CMTimeMakeWithSeconds( CMTimeGetSeconds(range.start) + ( CMTimeGetSeconds(range.duration) * (percent / 100)),
                                                range.start.timescale);

        [self.audioPlayer.currentItem seekToTime:seekTime];
    }
}

- (void)backwardSeekToBeginningOfProgram {
    
    if (!self.audioPlayer) {
        self.waitForSeek = YES;
        self.audioPlayer.volume = 0.0f;
        self.savedVolume = 1.0f;
        [self buildStreamer:kHLS];
        return;
    }
    
    self.waitForSeek = NO;
    self.seekWillEffectBuffer = YES;
    
    NSDate *cd = self.audioPlayer.currentItem.currentDate;
    Program *p = [[SessionManager shared] currentProgram];
    if ( p ) {
        NSTimeInterval beginning = [p.soft_starts_at timeIntervalSince1970];
        NSTimeInterval now = [cd timeIntervalSince1970];
        [self intervalSeekWithTimeInterval:(beginning - now)+kVirtualMediumBehindLiveTolerance completion:^{
            
#ifndef SUPPRESS_LOCAL_SAMPLING
            self.localBufferSample[@"expectedDate"] = self.audioPlayer.currentItem.currentDate;
            self.localBufferSample[@"open"] = @(YES);
#endif
            if ( self.audioPlayer.rate <= 0.0 || self.status != StreamStatusPlaying ) {
                [self playAudio];
            }
            
            if ([self.delegate respondsToSelector:@selector(onSeekCompleted)]) {
                [self.delegate onSeekCompleted];
            }
            
            [[AnalyticsManager shared] trackSeekUsageWithType:ScrubbingTypeRewindToStart];
            
        }];
    }
    
}

- (void)forwardSeekLiveWithType:(NSInteger)type completion:(CompletionBlock)completion {
    if (!self.audioPlayer) {
        [self buildStreamer:kHLS];
    }
    
    self.seekWillEffectBuffer = YES;
    self.ignoreDriftTolerance = NO;
    
    [self invalidateTimeObserver];
    if ( [self isPlayingAudio] ) {
        [self.audioPlayer pause];
    }
    
    [self.audioPlayer.currentItem cancelPendingSeeks];
    [self.audioPlayer.currentItem seekToTime:CMTimeMake(MAXFLOAT * HUGE_VALF, 1) completionHandler:^(BOOL finished) {
        
        NSDate *landingDate = self.audioPlayer.currentItem.currentDate;
        NSTimeInterval diff = fabs([landingDate timeIntervalSince1970] - [[[SessionManager shared] vLive] timeIntervalSince1970]);
        if ( diff > kVirtualBehindLiveTolerance ) {
            
            NSLog(@"Trying again...");
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self.audioPlayer.currentItem seekToTime:CMTimeMake(MAXFLOAT * HUGE_VALF, 1) completionHandler:^(BOOL finished) {
                    [self finishSeekToLive];
                    if ( completion ) {
                        dispatch_async(dispatch_get_main_queue(), completion);
                    }
                }];
            });

            return;
        }
        
        [self finishSeekToLive];
        
        if ( completion ) {
            dispatch_async(dispatch_get_main_queue(), completion);
        }
        
        [[AnalyticsManager shared] trackSeekUsageWithType:type];
        
    }];
    
}

- (void)finishSeekToLive {
    if ( [self.audioPlayer rate] <= 0.0 ) {
        [self.audioPlayer play];
    } else {
        [self startObservingTime];
    }
    
    [self.delegate onSeekCompleted];

}

- (void)seekToDate:(NSDate *)date completion:(CompletionBlock)completion {
    
    NSDate *now = [[SessionManager shared] vNow];
    [self intervalSeekWithTimeInterval:(-1.0f*[now timeIntervalSinceDate:date]) completion:completion];
    
}

- (void)intervalSeekWithTimeInterval:(NSTimeInterval)interval completion:(CompletionBlock)completion {
    [self setSeekWillEffectBuffer:YES];
    CMTime ct = [self.audioPlayer.currentItem currentTime];
    ct.value += (interval*ct.timescale);
    
    self.calibrating = YES;
    
    NSDate *targetDate = self.audioPlayer.currentItem.currentDate;
    targetDate = [targetDate dateByAddingTimeInterval:interval];
    
    [self invalidateTimeObserver];
    [self.audioPlayer.currentItem cancelPendingSeeks];
    [self.audioPlayer.currentItem seekToTime:ct completionHandler:^(BOOL finished) {
        
        __block NSDate *landingDate = self.audioPlayer.currentItem.currentDate;
        NSTimeInterval diff = [landingDate timeIntervalSince1970] - [targetDate timeIntervalSince1970];
        NSLog(@"After 1 attempt the difference between live and target seek is %1.1f",diff);
        self.seekTargetReferenceDate = targetDate;
        
        if ( fabs(diff) > kVirtualBehindLiveTolerance ) {
            
            NSLog(@"Trying again...");
            
            [self.audioPlayer pause];
            CMTime ctFail = self.audioPlayer.currentItem.currentTime;
            ctFail.value += -1.0f*diff*ctFail.timescale;
          
            NSAssert([NSThread isMainThread],@"Should be main thread");
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self.audioPlayer.currentItem seekToTime:ctFail completionHandler:^(BOOL finished) {
                    self.seekTargetReferenceDate = targetDate;
                    [self finishIntervalSeek:interval completion:completion];
                }];
            });

            
            return;
        }

        [self finishIntervalSeek:interval completion:completion];
        
    }];
}

- (void)finishIntervalSeek:(NSTimeInterval)interval completion:(CompletionBlock)completion {

    self.newPositionDelta = interval;
    
    if ( [self.audioPlayer rate] <= 0.0f ) {
        [self.audioPlayer play];
    } else {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self startObservingTime];
        });
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        NSDate *landingDate = self.audioPlayer.currentItem.currentDate;
        NSTimeInterval failDiff = [landingDate timeIntervalSince1970] - [self.seekTargetReferenceDate timeIntervalSince1970];
        NSLog(@"After all attempts the difference between live and target seek is %1.1f - %@",failDiff,[NSDate stringFromDate:landingDate withFormat:@"h:mm:ss a"]);
        
        [self recalibrateAfterScrub];
        [self setCalibrating:NO];

        if ( completion ) {
            completion();
        }
        
    });
}

- (void)forwardSeekThirtySecondsWithCompletion:(CompletionBlock)completion {
    NSTimeInterval forward = 30.0f;
    [self intervalSeekWithTimeInterval:forward completion:^{
        [[AnalyticsManager shared] trackSeekUsageWithType:ScrubbingTypeFwd30];
        if ( completion ) {
            completion();
        }
    }];
}
- (void)backwardSeekThirtySecondsWithCompletion:(CompletionBlock)completion {
    NSTimeInterval backward = -30.0f;
    [self intervalSeekWithTimeInterval:backward completion:^{
        [[AnalyticsManager shared] trackSeekUsageWithType:ScrubbingTypeBack30];
        if ( completion ) {
            completion();
        }
    }];
}

- (void)forwardSeekFifteenSecondsWithCompletion:(CompletionBlock)completion {
    NSTimeInterval backward = 15.0f;
    [self intervalSeekWithTimeInterval:backward completion:completion];
}

- (void)backwardSeekFifteenSecondsWithCompletion:(CompletionBlock)completion {
    NSTimeInterval backward = -15.0f;
    [self intervalSeekWithTimeInterval:backward completion:completion];
}

- (void)recalibrateAfterScrub {
    NSDate *vNow = [[SessionManager shared] vNow];
    Program *cp = [[SessionManager shared] currentProgram];
    NSTimeInterval vNowInSeconds = [vNow timeIntervalSince1970];
    NSTimeInterval saInSeconds = [cp.starts_at timeIntervalSince1970];
    NSTimeInterval eaInSeconds = [cp.ends_at timeIntervalSince1970];
    
    if ( vNowInSeconds >= eaInSeconds || vNowInSeconds <= saInSeconds ) {
        NSLog(@"Scrub will force program update for vNow : %@",[NSDate stringFromDate:vNow withFormat:@"h:mm:s a"]);
        [[SessionManager shared] fetchCurrentProgram:^(id returnedObject) {
            
        }];
    }
}

#pragma mark - Date and Time helper operations
- (NSString *)currentDateTimeString {
    return [[self programDateTimeFormatter] stringFromDate:self.currentDate];
}

- (NSString *)minSeekableDateTimeString {
    return [[self programDateTimeFormatter] stringFromDate:self.minSeekableDate];
}

- (NSString *)maxSeekableDateTimeString {
    return [[self programDateTimeFormatter] stringFromDate:self.maxSeekableDate];
}

- (NSDateFormatter *)programDateTimeFormatter {
    if (_dateFormatter == nil) {
        _dateFormatter = [[NSDateFormatter alloc] init];
        [_dateFormatter setDateFormat:@"h:mm:ss a"];
        [_dateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT: [[NSTimeZone localTimeZone] secondsFromGMT]]];
    }
    return _dateFormatter;
}

- (void)playerItemFailedToPlayToEndTime:(NSNotification *)notification {
    NSError *error = notification.userInfo[AVPlayerItemFailedToPlayToEndTimeErrorKey];
#ifdef DEBUG
    [self dump:YES];
#endif
    NSLog(@"playerItemFailedToPlayToEndTime! --- %@ ", [error localizedDescription]);
}

- (void)playerItemDidFinishPlaying:(NSNotification *)notification {
    @try {
        [[NSNotificationCenter defaultCenter] removeObserver:self
         name:AVPlayerItemDidPlayToEndTimeNotification
                                                      object:nil];
    } @catch (NSException *exception) {
        // Wasn't necessary
        NSLog(@"Exception - failed to remove AVPlayerItemDidPlayToEndTimeNotification");
    }

    if ( [[QueueManager shared] currentBookmark] ) {
        [[ContentManager shared] destroyBookmark:[[QueueManager shared] currentBookmark]];
        [[QueueManager shared] setCurrentBookmark:nil];
    }
    
    if ( ![[QueueManager shared]isQueueEmpty] ) {
        [[SessionManager shared] endOnDemandSessionWithReason:OnDemandFinishedReasonEpisodeEnd];
        [[QueueManager shared] playNext];
    } else {
        [self stopAudio];
        [self playAudio];
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

- (NSString *)liveStreamURL {

    if (self.audioPlayer) {
        if ([self.audioPlayer.currentItem.accessLog.events.lastObject URI]) {
            return [NSString stringWithFormat:@"%@",[self.audioPlayer.currentItem.accessLog.events.lastObject URI]];
        }
    }
    return kHLS;

}

- (double)indicatedBitrate {
    return [self.audioPlayer indicatedBitrate];
}

- (double)observedMaxBitrate {
    return [self.audioPlayer observedMaxBitrate];
}

- (double)observedMinBitrate {
    return [self.audioPlayer observedMinBitrate];
}

- (NSString*)avPlayerSessionString {
    NSString *rv = nil;
    if ( self.audioPlayer ) {
        if ( self.audioPlayer.currentItem ) {
            AVPlayerItemErrorLog *errorLog = [self.audioPlayer.currentItem errorLog];
            
            NSString *logAsString = [[NSString alloc] initWithData:[errorLog extendedLogData]
                                                encoding:[errorLog extendedLogDataStringEncoding]];
            if ( logAsString && [logAsString length] > 0 ) {
                
                NSString *pattern = @"[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}";
                NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                                       options:0 error:NULL];
                NSTextCheckingResult *match = [regex firstMatchInString:logAsString options:0 range:NSMakeRange(0, [logAsString length])];
                if ( match ) {
                    
                    NSRange r1 = [match rangeAtIndex:0];
                    rv = [logAsString substringWithRange:r1];
                    
                }

            } else {
                AVPlayerItemAccessLog *accessLog = [self.audioPlayer.currentItem accessLog];
               logAsString = [[NSString alloc] initWithData:[accessLog extendedLogData]
                                                              encoding:[accessLog extendedLogDataStringEncoding]];
                
                NSString *pattern = @"[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}";
                NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                                       options:0 error:NULL];
                NSTextCheckingResult *match = [regex firstMatchInString:logAsString options:0 range:NSMakeRange(0, [logAsString length])];
                if ( match ) {
                    
                    NSRange r1 = [match rangeAtIndex:0];
                    rv = [logAsString substringWithRange:r1];
                    
                }
                
            }
        }
    }
    

    return rv;

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
    
    [[NetworkManager shared] setupFloatingReachabilityWithHost:urlString];
    
    self.audioPlayer = [AVPlayer playerWithURL:url];
    [self.audioPlayer.currentItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionOld|NSKeyValueObservingOptionNew context:nil];
    [self.audioPlayer.currentItem addObserver:self forKeyPath:@"playbackBufferEmpty" options:NSKeyValueObservingOptionNew context:nil];
    [self.audioPlayer.currentItem addObserver:self forKeyPath:@"playbackLikelyToKeepUp" options:NSKeyValueObservingOptionNew context:nil];
    [self.audioPlayer.currentItem addObserver:self forKeyPath:AVPlayerItemPlaybackStalledNotification options:NSKeyValueObservingOptionNew context:nil];
    
    //[self.audioPlayer.currentItem addObserver:self forKeyPath:AVPlayerItemNewAccessLogEntryNotification options:NSKeyValueObservingOptionNew context:nil];
    //[self.audioPlayer.currentItem addObserver:self forKeyPath:AVPlayerItemNewErrorLogEntryNotification options:NSKeyValueObservingOptionNew context:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(logReceived:)
                                                 name:AVPlayerItemNewAccessLogEntryNotification
                                               object:nil];
    
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(logReceived:)
                                                 name:AVPlayerItemNewErrorLogEntryNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playbackStalled:)
                                                 name:AVPlayerItemPlaybackStalledNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerItemFailedToPlayToEndTime:)
                                                 name:AVPlayerItemFailedToPlayToEndTimeNotification
                                               object:nil];
    
    
    [self.audioPlayer addObserver:self
                       forKeyPath:@"status"
                          options:NSKeyValueObservingOptionOld|NSKeyValueObservingOptionNew
                          context:nil];
    [self.audioPlayer addObserver:self
                       forKeyPath:@"rate"
                          options:NSKeyValueObservingOptionOld|NSKeyValueObservingOptionNew
                          context:nil];
    
#ifndef SUPPRESS_LOCAL_SAMPLING
    self.localBufferSample = nil;
#endif
    
    if ( self.currentAudioMode != AudioModeLive ) {
        [[SessionManager shared] setLocalLiveTime:0.0f];
    }
    
    self.status = StreamStatusStopped;
    self.previousUrl = urlString;
    
}

- (void)buildStreamer:(NSString *)urlString {
    [self buildStreamer:urlString local:NO];
}

- (void)takedownAudioPlayer {
    
    [[ContentManager shared] saveContext];
    
    self.temporaryMutex = NO;
    if ( self.audioPlayer ) {
        [self.audioPlayer pause];
    }
    
    [self invalidateTimeObserver];
    
    @try {
        [self.audioPlayer removeObserver:self forKeyPath:@"rate"];
        [self.audioPlayer removeObserver:self forKeyPath:@"status"];
        [self.audioPlayer.currentItem removeObserver:self forKeyPath:@"status"];
        [self.audioPlayer.currentItem removeObserver:self forKeyPath:@"playbackBufferEmpty"];
        [self.audioPlayer.currentItem removeObserver:self forKeyPath:@"playbackLikelyToKeepUp"];
        [self.audioPlayer.currentItem removeObserver:self forKeyPath:AVPlayerItemPlaybackStalledNotification];
        
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:AVPlayerItemDidPlayToEndTimeNotification
                                                      object:nil];
        
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:AVPlayerItemFailedToPlayToEndTimeNotification
                                                      object:nil];
        
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:AVPlayerItemNewErrorLogEntryNotification
                                                      object:nil];
        
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:AVPlayerItemNewAccessLogEntryNotification
                                                      object:nil];
        
    } @catch (NSException *e) {
        // Wasn't necessary
    }
    
    [[SessionManager shared] resetCache];
    
    if ( self.currentAudioMode != AudioModeOnboarding ) {
        [self.audioPlayer cancelPendingPrerolls];
    }
    
    [[SessionManager shared] setLocalLiveTime:0.0f];
    
    self.localBufferSample = nil;
    self.maxSeekableDate = nil;
    self.minSeekableDate = nil;
    self.seekWillEffectBuffer = NO;
    self.waitForSeek = NO;
    self.waitForOnDemandSeek = NO;
    self.status = StreamStatusStopped;
    self.currentAudioMode = AudioModeNeutral;
    self.audioPlayer = nil;
    self.skipCount = 0;
    
}

- (void)resetPlayer {
    [self stopAudio];
    [self buildStreamer:kHLS];
}

- (void)sanitizeFromOnboarding {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AVPlayerItemDidPlayToEndTimeNotification
                                                  object:nil];
}


- (void)playAudioWithURL:(NSString *)url {
    
    if ( [self currentAudioMode] != AudioModePreroll ) {
        if ( [url rangeOfString:@"?"].location == NSNotFound ) {
            url = [url stringByAppendingString:[NSString stringWithFormat:@"?ua=KPCCiPhone-%@",[Utils urlSafeVersion]]];
        } else {
            url = [url stringByAppendingString:[NSString stringWithFormat:@"&ua=KPCCiPhone-%@", [Utils urlSafeVersion]]];
        }
    }
    
    [[UXmanager shared] timeBegin];
    [self stopAudio];
    [[UXmanager shared] timeEnd:@"Takedown audio player"];
    
    [[UXmanager shared] timeBegin];
    [self buildStreamer:url];
    [[UXmanager shared] timeEnd:@"Build audio player"];
    
    [[UXmanager shared] timeBegin];
    [self playAudio];
    [[UXmanager shared] timeEnd:@"Play Audio"];
    
    // IPH-18
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerItemDidFinishPlaying:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:nil];
    
}

- (void)playQueueItem:(AudioChunk*)chunk {
    Bookmark *b = [[ContentManager shared] bookmarkForAudioChunk:chunk];
    [[QueueManager shared] setCurrentBookmark:b];
    [self playQueueItemWithUrl:chunk.audioUrl];
}

- (void)playQueueItemWithUrl:(NSString *)url {
#ifdef DEBUG
    NSLog(@"playing queue item with url: %@", url);
#endif
    if ( !url ) {
        if ( [self.delegate respondsToSelector:@selector(onDemandAudioFailed)] ) {
            [self.delegate onDemandAudioFailed];
        }
        return;
    }
    
    [[SessionManager shared] startOnDemandSession];
    [[[Utils del] masterViewController] showOnDemandOnboarding];
    

    [self playAudioWithURL:url];
    
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
    
    [[AudioManager shared] setRelativeFauxDate:[NSDate date]];
    
    [self playAudio];
    
}

- (BOOL)isPlayingAudio {
    return [self.audioPlayer rate] > 0.0f;
}

- (BOOL)isActiveForAudioMode:(AudioMode)mode {
    if ( self.currentAudioMode != mode ) return NO;
    return self.status == StreamStatusPaused || self.status == StreamStatusPlaying;
}

- (void)startStream {
    [self playAudio];
}

- (void)playAudio {
    
    [[ContentManager shared] saveContext];
    
    self.beginNormally = YES;
    if (!self.audioPlayer) {
        [self buildStreamer:kHLS];
    }
    
    if ( [self currentAudioMode] == AudioModeOnboarding ) {
        self.audioPlayer.volume = 0.0f;
    }
    
    [[SessionManager shared] startAudioSession];
    
    [[SessionManager shared] setSessionPausedDate:nil];
    self.status = StreamStatusPlaying;
    
    if ( self.smooth ) {
        self.savedVolume = self.audioPlayer.volume;
        if ( self.savedVolume <= 0.0 ) {
            self.savedVolume = 1.0f;
        }
        self.audioPlayer.volume = 0.0f;
    }
    
    if ( self.currentAudioMode == AudioModeOnDemand ) {
        if ( [self.audioPlayer currentItem] ) {
            if ( CMTimeGetSeconds( self.audioPlayer.currentItem.currentTime ) == 0 ) {
                Bookmark *b = [[QueueManager shared] currentBookmark];
                if ( b ) {
                    Float64 resumeTime = [b.resumeTimeInSeconds floatValue];
                    Float64 duration = [b.duration floatValue];
                    if ( fabs(duration - resumeTime) <= 1.0 ) {
                        b.resumeTimeInSeconds = @(0);
                    }
                    if ( b && b.resumeTimeInSeconds > 0 ) {
                        if ( resumeTime >= duration ) {
                            b.resumeTimeInSeconds = @(0);
                        } else {
                            self.onDemandSeekPosition = resumeTime;
                            self.waitForOnDemandSeek = YES;
                            return;
                        }
                    }
                } else {
                    self.beginNormally = NO;
                    [self.audioPlayer play];
                }
            } else {
                [self.audioPlayer play];
            }
        }
    } else {
        if ( self.audioPlayer.currentItem.status == AVPlayerItemStatusReadyToPlay ) {
            NSLog(@"Player ready immediately");
            self.beginNormally = NO;
            [self.audioPlayer play];
        }
    }

}

- (void)switchPlusMinusStreams {
    if ( [self isActiveForAudioMode:AudioModeLive] ) {
        if ( self.seekWillEffectBuffer ) {
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [[AudioManager shared] stopAudio];
                [[AudioManager shared] setSmooth:YES];
                [[AudioManager shared] playAudio];
            });
            
        } else {
            [self adjustAudioWithValue:-0.1f
                                         completion:^{
                                             [[AudioManager shared] stopAudio];
                                             [[AudioManager shared] setSmooth:YES];
                                             [[AudioManager shared] playAudio];
                                         }];
        }
    }
}

- (void)pauseAudio {
    
    [self.audioPlayer pause];
    self.status = StreamStatusPaused;
    self.localBufferSample = nil;
    
    [[SessionManager shared] setLocalLiveTime:0.0f];
    
    if ( self.dropoutOccurred && !self.userPause ) {
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        if ( self.currentAudioMode == AudioModeLive ) {

            [[SessionManager shared] endLiveSession];
        } else {
            [[SessionManager shared] endOnDemandSessionWithReason:OnDemandFinishedReasonEpisodePaused];
        }
    });
     
}

- (void)stopAudio {
    if ( [self isPlayingAudio] && self.currentAudioMode == AudioModeLive ) {
        [[SessionManager shared] endLiveSession];
    }
    
    [self takedownAudioPlayer];
    self.status = StreamStatusStopped;
}

- (void)stopAllAudio {
    [self stopAudio];

    if (self.localAudioPlayer && self.localAudioPlayer.isPlaying) {
        [self.localAudioPlayer stop];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"panic"
                                                        object:nil];
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
            self.autoMuted = NO;
        } else {
            self.autoMuted = YES;
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
    if (self.audioPlayer && [self.audioPlayer rate] > 0.0) {
        return YES;
    } else {
        return NO;
    }
}

- (BOOL)isStreamBuffering {
    // Old.. can most likely be removed.
    return NO;
}

#pragma mark - General Utils
- (NSDate*)cookDateForActualSchedule:(NSDate *)date {
#ifdef USE_TEST_STREAM
    return [self minSeekableDate];
#else
#ifndef NO_PROGRAM_OFFSET_CORRECTION
    NSTimeInterval supposed = [date timeIntervalSince1970];
    NSTimeInterval actual = supposed + 60 * 6;
    NSDate *actualDate = [NSDate dateWithTimeIntervalSince1970:actual];
    return actualDate;
#else
    return date;
#endif
#endif
}


#pragma mark - Error Logging
#ifdef DEBUG
- (void)dump:(BOOL)superVerbose {
    AVPlayerItemErrorLog *log = [self.audioPlayer.currentItem errorLog];
    NSString *logAsString = [[NSString alloc] initWithData:[log extendedLogData]
                                                  encoding:[log extendedLogDataStringEncoding]];
    if ( [logAsString length] > 0 ) {
        NSLog(@"Player error log : %@",logAsString);
    }
    
    if ( superVerbose ) {
        AVPlayerItemAccessLog *accessLog = [self.audioPlayer.currentItem accessLog];
        logAsString = [[NSString alloc] initWithData:[accessLog extendedLogData]
                                            encoding:[accessLog extendedLogDataStringEncoding]];
        if ( [logAsString length] > 0 ) {
#ifdef VERBOSE_LOGGING
            NSLog(@"Player access log : %@",logAsString);
#endif
        }
    }
    
    NSString *sid = [self avPlayerSessionString];
    if ( sid ) {
        NSLog(@"Session ID : %@",sid);
    }
    
}


- (void)streamFrame {
    self.frame++;
    if ( self.frame % 100 == 0 ) {
        [self dump:NO];
        if ( self.previousCD ) {
            long diff = [self.audioPlayer.currentItem.currentDate timeIntervalSinceDate:self.previousCD];
            if ( diff > 60 ) {
                NSLog(@"Big drift spike : %ld, previous snapshot : %@",diff,[self.previousCD prettyTimeString]);
            }
        }
        
        self.previousCD = self.audioPlayer.currentItem.currentDate;
    }
}
#endif

- (void)analyzeStreamError:(NSString *)comments {

    NetworkHealth netHealth = [[NetworkManager shared] checkNetworkHealth];
    switch (netHealth) {
        case NetworkHealthAllOK:
            // If recovering from stream failure, cancel playing of local audio file
            if (self.localAudioPlayer && self.localAudioPlayer.isPlaying) {
                [self.localAudioPlayer stop];
            }
            
            [[AnalyticsManager shared] failStream:NetworkHealthUnknown
                                         comments:comments];
            
            break;
            
        case NetworkHealthNetworkDown:
            //[self localAudioFallback:[[NSBundle mainBundle] pathForResource:kFailedConnectionAudioFile ofType:@"mp3"]];
            if ([self.delegate respondsToSelector:@selector(handleUIForFailedConnection)]) {
                [self.delegate handleUIForFailedConnection];
            }
            [[AnalyticsManager shared] failStream:NetworkHealthNetworkDown comments:comments];
            break;
        
        case NetworkHealthContentServerDown:
            //[self localAudioFallback:[[NSBundle mainBundle] pathForResource:kFailedStreamAudioFile ofType:@"mp3"]];
            if ([self.delegate respondsToSelector:@selector(handleUIForFailedStream)]) {
                [self.delegate handleUIForFailedStream];
            }
            [[AnalyticsManager shared] failStream:NetworkHealthContentServerDown comments:comments];
            break;
        case NetworkHealthStreamingServerDown:
            if ([self.delegate respondsToSelector:@selector(handleUIForFailedStream)]) {
                [self.delegate handleUIForFailedStream];
            }
            [[AnalyticsManager shared] failStream:NetworkHealthStreamingServerDown comments:comments];
            break;
        default:
            [[AnalyticsManager shared] failStream:NetworkHealthUnknown comments:comments];
            break;
    }
}

- (void)localAudioFallback:(NSString *)filePath {

    if (!filePath) {
        return;
    }

    [self stopAudio];

    // Init the local audio player, set to loop indefinitely, and play.
    self.localAudioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:filePath] error:nil];
    self.localAudioPlayer.numberOfLoops = -1;
    [self.localAudioPlayer play];
}

@end
