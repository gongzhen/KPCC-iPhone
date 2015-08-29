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
#import <Parse/Parse.h>

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

            singleton.interactionIdx = 0;
            
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

- (void)loadXfsStreamUrlWithCompletion:(CompletionBlock)completion {
    
    PFQuery *settingsQuery = [PFQuery queryWithClassName:@"iPhoneSettings"];
    [settingsQuery whereKey:@"settingName"
             containsString:@"kpccPlusStream"];
    [settingsQuery findObjectsInBackgroundWithBlock:^( NSArray *objects, NSError *error ) {
       
        if ( !error && [objects count] > 0 ) {
            
            PFObject *settings = [objects firstObject];
            self.xfsStreamUrl = settings[@"settingValue"];
            if ( completion ) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion();
                });
            }
            
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
    NSLog(@"Options : %@",[note.userInfo description]);
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
            // FIXME: Should we stash our status?

            break;

        case AVAudioSessionInterruptionTypeEnded:
            switch (self.currentAudioMode) {
                case AudioModeOnboarding:
                    [[UXmanager shared] godPauseOrPlay];
                    break;

                case AudioModePreroll:

                    if ( mvc.preRollViewController && resume) {
                        [mvc.preRollViewController.prerollPlayer play];
                    }

                    break;

                default:
                    if (self.audioPlayer && !self.userPause) {
                        [self playAudio];
                    }

                    break;
            }

            break;

    }
    
    if ( interruptionType == AVAudioSessionInterruptionTypeEnded && !resume ) {
        NSLog(@"Probably interrupted from another app, so don't resume");
        return;
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
    
    // Monitoring AVPlayer->currentItem with empty playback buffer.
    if (object == self.audioPlayer.currentItem && [keyPath isEqualToString:@"playbackBufferEmpty"]) {
        if ( [change[@"new"] intValue] == 1 ) {
            if ( !self.seekWillAffectBuffer ) {
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
                    NSLog(@"Ignoring buffer emptiness because user has paused the audio");
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
                if ( !self.seekWillAffectBuffer ) {
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
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:@"playback-ready"
                                                                    object:nil];
            });
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
}



#pragma mark - Recovery / Logging / Stalls
- (void)playbackStalled:(NSNotification*)note {
    
    
    if ( self.userPause ) return;
    if ( self.giveupTimer ) return;
    if ( !self.seekWillAffectBuffer ) {
        if ( !self.audioOutputSourceChanging ) {
            self.dropoutOccurred = YES;
            
            NSLog(@"Playback has stalled ... ");
            
            [[NSNotificationCenter defaultCenter] postNotificationName:@"playback-stalled"
                                                                object:nil];
            
#ifndef SUPPRESS_LOCAL_SAMPLING
//            [self invalidateTimeObserver];
#endif
#ifndef SUPPRESS_AGGRESSIVE_KICKSTART
            self.kickstartTimer = [NSTimer scheduledTimerWithTimeInterval:kImpatientWaitingTolerance
                                                                   target:self
                                                                 selector:@selector(impatientRestart)
                                                                 userInfo:nil
                                                                  repeats:NO];
#endif
            
            self.giveupTimer = [NSTimer scheduledTimerWithTimeInterval:kGiveUpTolerance
                                                                target:self
                                                              selector:@selector(giveUpOnStream)
                                                              userInfo:nil
                                                               repeats:NO];
            
        } else {
            NSLog(@"Ignoring this failure as it was generated by changing the audio source");
        }
    }
    
    

}

- (void)giveUpOnStream {
    if ( self.dropoutOccurred ) {
        [self stopAudio];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"playback-stalled"
                                                            object:nil];
        
        SCPRAppDelegate *del = [Utils del];
        SCPRMasterViewController *master = (SCPRMasterViewController*)[del masterViewController];
        if ( [master scrubbing] ) {
            [master finishedWithScrubber];
        }
        
        self.dropoutOccurred = NO;
        self.appGaveUp = YES;
        
        [self.delegate onRateChange];
        
        [[AnalyticsManager shared] logEvent:@"liveStreamStalled"
                             withParameters:[[AnalyticsManager shared] typicalLiveProgramInformation]];
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

    
    if ( self.audioPlayer.rate == 1.0f ) {
        if ( !self.timeObserver ) {
            [self startObservingTime];
        }
    }
    
    if ( !self.appGaveUp ) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [[AnalyticsManager shared] clearLogs];
            /*[[AnalyticsManager shared] logEvent:@"streamRecovered"
                                 withParameters:@{}];*/
            
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
        if ( self.multipurposeTimer ) {
            if ( [self.multipurposeTimer isValid] ) {
                [self.multipurposeTimer invalidate];
            }
            self.multipurposeTimer = nil;
        }
        
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

- (void)localSample:(CMTime)time {
    NSArray *seekRange = self.audioPlayer.currentItem.seekableTimeRanges;
    
    NSDate *now = [NSDate date];
    NSDate *msd = self.maxSeekableDate;
    if ( msd && [msd isWithinReasonableframeOfDate:now] ) {
        
        NSInteger drift = [now timeIntervalSince1970] - [msd timeIntervalSince1970];
        if ( (drift - [[SessionManager shared] peakDrift] > kToleratedIncreaseInDrift) ) {
            /*[[AnalyticsManager shared] logEvent:@"driftIncreasing"
                                 withParameters:@{ @"oldDrift" : @([[SessionManager shared] peakDrift]),
                                                   @"newDrift" : @(drift) }];
            NSLog(@"Drift increasing - Old : %ld, New : %ld",(long)[[SessionManager shared] peakDrift], (long)drift);*/
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
        //Float64 maxSeekTime = CMTimeGetSeconds(CMTimeRangeGetEnd(range));
        
        //NSLog(@"Reported Date : %@, Expected Date : %@",repStr,expStr);
        if ( fabs(etFloat - rtFloat) > kSmallSkipInterval || ![expectedDate isWithinTimeFrame:kSmallSkipInterval ofDate:reportedDate] ) {
            
            if ( !self.seekWillAffectBuffer ) {
                
                if ( self.userPause ) {
                    return;
                }
                if ( self.suppressSkipFixer ) {
                    NSLog(@"Ignoring because error log was received");
                    return;
                }
                if ( self.dropoutOccurred ) {
                    NSLog(@"Going to ignore this because the stream has dropped out");
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
                        
                        /*[[AnalyticsManager shared] logEvent:@"attemptToFixLargeGapInStream"
                                             withParameters:@{ @"expected" : expStr,
                                                               @"reported" : repStr,
                                                               @"timeAfterAttemptToFix" : currTime,
                                                               @"reportedTimeValue" : @(rtFloat),
                                                               @"reportedMaxSeekTime" : @(maxSeekTime)}];*/
                        
                    }];
                    
                } else {
                    /*[[AnalyticsManager shared] logEvent:@"skippedTooManyTimes"
                                         withParameters:@{}];*/
                    
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

    if (self.timeObserver) {
        NSLog(@"startObservingTime called with an observer already in place.");
        return;
    }
    
//    [self invalidateTimeObserver];

    self.calibrating = YES;
    self.timeObserver = nil;
    self.frameCount = 0;
    
    
    self.timeObserver = [self.audioPlayer addPeriodicTimeObserverForInterval:CMTimeMake(1, 10) queue:NULL usingBlock:^(CMTime time) {
                                                                      
        if ( weakSelf.frameCount % 10 == 0 ) {
            weakSelf.currentDate = audioPlayer.currentItem.currentDate;
            if ( [[SessionManager shared] dateIsReasonable:weakSelf.currentDate] ) {
                [[SessionManager shared] setLastValidCurrentPlayerTime:weakSelf.currentDate];
            }
            weakSelf.seekWillAffectBuffer = NO;
            weakSelf.audioOutputSourceChanging = NO;
        }
        
        if ( weakSelf.dropoutOccurred ) {
            weakSelf.dropoutOccurred = NO;
#ifndef SUPPRESS_BITRATE_THROTTLING
            if ( [Utils isIOS8] ) {
                weakSelf.audioPlayer.currentItem.preferredPeakBitRate = kPreferredPeakBitRateTolerance;
            }
#endif
        }
        weakSelf.beginNormally = NO;
        
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
                
//#ifndef SUPPRESS_LOCAL_SAMPLING
//                if ( weakSelf.currentAudioMode == AudioModeLive ) {
//                    [weakSelf localSample:time];
//                }
//#endif
                if ( weakSelf.currentAudioMode == AudioModeOnDemand ) {
                    [[QueueManager shared] handleBookmarkingActivity];
                }
                
                weakSelf.seekWillAffectBuffer = NO;
                weakSelf.seekRequested = NO;
                weakSelf.appGaveUp = NO;
                
                if ( [[SessionManager shared] sleepTimerArmed] ) {
                    [[SessionManager shared] tickSleepTimer];
                }
                
                [[SessionManager shared] checkProgramUpdate:NO];
                

                weakSelf.calibrating = NO;
                weakSelf.audioOutputSourceChanging = NO;
                
            }

            if ( weakSelf.frameCount == 300 ) {
                // After 30 seconds, consider skip probation period over
                weakSelf.skipCount = 0;
                weakSelf.suppressSkipFixer = NO;
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
    NSInteger seek_id = ++self.interactionIdx;

    self.savedVolume = 1.0f;

    [self getReadyPlayer:^{
        if (self.interactionIdx != seek_id) {
            return;
        }

        // FIXME: Manage volume

        NSDate *cd = self.audioPlayer.currentItem.currentDate;
        Program *p = [[SessionManager shared] currentProgram];
        if ( p ) {
            NSTimeInterval beginning = [p.soft_starts_at timeIntervalSince1970];
            NSTimeInterval now = [cd timeIntervalSince1970];
            [self intervalSeekWithTimeInterval:(beginning - now) completion:^{
                if ([self.delegate respondsToSelector:@selector(onSeekCompleted)]) {
                    [self.delegate onSeekCompleted];
                }

                [[AnalyticsManager shared] trackSeekUsageWithType:ScrubbingTypeRewindToStart];

            }];
        }
    }];
}

- (void)forwardSeekLiveWithType:(NSInteger)type completion:(CompletionBlock)completion {
    NSInteger seek_id = ++self.interactionIdx;

    [self getReadyPlayer:^{
        if (self.interactionIdx != seek_id) {
            return;
        }

        self.seekWillAffectBuffer = TRUE;

        [self.audioPlayer.currentItem seekToTime:kCMTimePositiveInfinity completionHandler:^(BOOL finished) {
            if (!finished) {
                return;
            }

            [self.audioPlayer play];

            [self.delegate onSeekCompleted];

            dispatch_async(dispatch_get_main_queue(), ^{
                [self startObservingTime];

                if (completion) {
                    completion();
                }
            });

            [[AnalyticsManager shared] trackSeekUsageWithType:type];
        }];
    }];
}

- (void)seekToDate:(NSDate *)date completion:(CompletionBlock)completion {
    
    NSDate *now = [[SessionManager shared] vNow];
    [self intervalSeekWithTimeInterval:(-1.0f*[now timeIntervalSinceDate:date]) completion:completion];
    
}

- (void)intervalSeekWithTimeInterval:(NSTimeInterval)interval completion:(CompletionBlock)completion {
    void (^finishBlock)(void) = ^{
        self.newPositionDelta = interval;

//        if ( [self.audioPlayer rate] <= 0.0f ) {
            [self.audioPlayer play];
//        } else {
//            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//            });
//        }

        dispatch_async(dispatch_get_main_queue(), ^{

            [self startObservingTime];

            NSDate *landingDate = self.audioPlayer.currentItem.currentDate;
            NSTimeInterval failDiff = [landingDate timeIntervalSince1970] - [self.seekTargetReferenceDate timeIntervalSince1970];
            NSLog(@"After all attempts the difference between live and target seek is %1.1f - %@",failDiff,[NSDate stringFromDate:landingDate withFormat:@"h:mm:ss a"]);

            [self recalibrateAfterScrub];
            [self setCalibrating:NO];

            if ( completion ) {
                completion();
            }

        });
    };
    
    [self getReadyPlayer:^{
        [self setSeekWillAffectBuffer:YES];
        CMTime ct = [self.audioPlayer.currentItem currentTime];
        ct.value += (interval*ct.timescale);

        NSDate *targetDate = self.audioPlayer.currentItem.currentDate;
        targetDate = [targetDate dateByAddingTimeInterval:interval];

        self.calibrating = YES;

//        [self invalidateTimeObserver];
        [self.audioPlayer.currentItem cancelPendingSeeks];
        [self.audioPlayer.currentItem seekToTime:ct toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero completionHandler:^(BOOL finished) {
            if (!finished) {
                return;
            }

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
                    [self.audioPlayer.currentItem seekToTime:ctFail toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero completionHandler:^(BOOL finished) {
                        self.seekTargetReferenceDate = targetDate;
                        finishBlock();
                    }];
                });
            } else {
                finishBlock();
            }
        }];
    }];
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
    
    [[SessionManager shared] endOnDemandSessionWithReason:OnDemandFinishedReasonEpisodeEnd];

    if ( [[QueueManager shared] currentBookmark] ) {
        [[ContentManager shared] destroyBookmark:[[QueueManager shared] currentBookmark]];
        [[QueueManager shared] setCurrentBookmark:nil];
    }
    
    if ( ![[QueueManager shared] isQueueEmpty] ) {
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
    return self.avSessionId;
}

- (void)getReadyPlayer:(CompletionBlock)completion {
    if (self.audioPlayer == nil) {
        NSLog(@"getReadyPlayer calling buildStreamer");
        [self buildStreamer:nil];
    }
    
    if (self.audioPlayer.currentItem != nil && self.audioPlayer.status == AVPlayerItemStatusReadyToPlay) {
        NSLog(@"getReadyPlayer: item is already ready to play");
        completion();
    } else {
        NSLog(@"getReadyPlayer: waiting for item");
        [self.avobserver once:StatusesItemReady callback:^(NSString *msg, id obj) {
            NSLog(@"getReadyPlayer: item is now ready");
            completion();
        } ];
    }
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
    
    if ( self.audioPlayer ) {
        [self takedownAudioPlayer];
    }
    
    self.audioPlayer = [AVPlayer playerWithURL:url];
    self.avobserver = [ [AVObserver alloc] initWithPlayer:self.audioPlayer callback:^ void (enum Statuses status, NSString *msg, id obj) {
        
        NSLog(@"AVObserver sent %ld: %@", (long)status, msg);

        switch (status) {
            case StatusesPlaying:
                if ([self.delegate respondsToSelector:@selector(onRateChange)]) {
                    [self.delegate onRateChange];
                }

                self.status = StreamStatusPlaying;

                break;
            case StatusesPaused:
                if ([self.delegate respondsToSelector:@selector(onRateChange)]) {
                    [self.delegate onRateChange];
                }

                self.status = StreamStatusPaused;

                break;
            case StatusesPlayerFailed:
            case StatusesItemFailed:
                NSLog(@"Player or Item Failed! %@",msg);

                if ( [self currentAudioMode] == AudioModeOnDemand ) {
                    // FIXME: do we need to also be tearing down our now-broken
                    // player?
                    if ( [self.delegate respondsToSelector:@selector(onDemandAudioFailed)] ) {
                        [self.delegate onDemandAudioFailed];
                    }
                } else {
                    self.failoverCount++;
                    if ( self.failoverCount > kFailoverThreshold ) {
                        self.tryAgain = NO;
                        self.failoverCount = 0;
                        [self stopAudio];
                    } else {
                        self.tryAgain = YES;
                        [self resetPlayer];
                    }
                }

                break;
            case StatusesLikelyToKeepUp:
                break;
            case StatusesAccessLog:
                [[AnalyticsManager shared] setAccessLog:obj];

                break;
            case StatusesErrorLog:
                [[AnalyticsManager shared] setErrorLog:obj];

                if ( self.waitForLogTimer ) {
                    if ( [self.waitForLogTimer isValid] ) {
                        [self.waitForLogTimer invalidate];
                    }
                    self.waitForLogTimer = nil;
                }

                break;
            case StatusesStalled:
                break;
            default:
                break;
        }
    } ];

    // Watch for our session ID and stash it
    [self.avobserver once:StatusesAccessLog callback:^(NSString *msg, AVPlayerItemAccessLogEvent *obj) {
        self.avSessionId = obj.playbackSessionID;
        NSLog(@"Setting avSessionId to %@",self.avSessionId);
    }];
    
    [self.audioPlayer.currentItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionOld|NSKeyValueObservingOptionNew context:nil];
    [self.audioPlayer.currentItem addObserver:self forKeyPath:@"playbackBufferEmpty" options:NSKeyValueObservingOptionNew context:nil];
    [self.audioPlayer.currentItem addObserver:self forKeyPath:@"playbackLikelyToKeepUp" options:NSKeyValueObservingOptionNew context:nil];
    
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
    
    if ( self.audioPlayer ) {
        [self.audioPlayer pause];
    }
    
    [self invalidateTimeObserver];
    
    @try {
        [self.audioPlayer removeObserver:self forKeyPath:@"status"];
        
        [self.audioPlayer.currentItem removeObserver:self forKeyPath:@"status"];
        NSLog(@"Removed status KVO without exception...");
        
        [self.audioPlayer.currentItem removeObserver:self forKeyPath:@"playbackBufferEmpty"];
        NSLog(@"Removed playbackBufferEmpty KVO without exception...");
        
        [self.audioPlayer.currentItem removeObserver:self forKeyPath:@"playbackLikelyToKeepUp"];
        NSLog(@"Removed playbackLikelyToKeepUp KVO without exception...");
        
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:AVPlayerItemDidPlayToEndTimeNotification
                                                      object:nil];
        
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:AVPlayerItemFailedToPlayToEndTimeNotification
                                                      object:nil];
        
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:AVPlayerItemPlaybackStalledNotification
                                                      object:nil];
        
    } @catch (NSException *e) {
        // Wasn't necessary
        NSLog(@"An exception occurred : %@",e.userInfo);
    }
    
    [[SessionManager shared] resetCache];
    
    if ( self.currentAudioMode != AudioModeOnboarding ) {
        [self.audioPlayer cancelPendingPrerolls];
    }
    
    [[SessionManager shared] setLocalLiveTime:0.0f];
    
    [self resetFlags];
    
    self.audioPlayer = nil;
    
    if ( self.avobserver != nil ) {
        [self.avobserver stop];
        self.avobserver = nil;
    }
    
}

- (void)resetPlayer {
    [self stopAudio];
    [self buildStreamer:kHLS];
}

- (void)resetFlags {
    self.localBufferSample = nil;
    self.maxSeekableDate = nil;
    self.minSeekableDate = nil;
    self.seekWillAffectBuffer = NO;
    self.dropoutOccurred = NO;
    self.playerNeedsToSeekGenerally = NO;
    self.playerNeedsToSeekToLive = NO;
    self.waitForSeek = NO;
    self.waitForOnDemandSeek = NO;
    self.status = StreamStatusStopped;
    self.currentAudioMode = AudioModeNeutral;
    self.skipCount = 0;
    self.appGaveUp = NO;
    self.suppressSkipFixer = NO;
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
    
    [self playAudio];
    
}

- (BOOL)isPlayingAudio {
    return [self.audioPlayer rate] > 0.0f;
}

- (BOOL)isActiveForAudioMode:(AudioMode)mode {
    if ( self.currentAudioMode != mode ) return NO;
    return self.status == StreamStatusPaused || self.status == StreamStatusPlaying;
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
    
    [self setUserPause:NO];
    
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

- (void)pauseAudio {
    
    [self.audioPlayer pause];
    self.status = StreamStatusPaused;
    self.localBufferSample = nil;
    
    [[SessionManager shared] setLocalLiveTime:0.0f];
    
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
        if ( self.seekWillAffectBuffer ) {
            
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

#endif

@end
