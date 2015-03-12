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
            singleton.savedVolumeFromMute = -1.0;
            singleton.currentAudioMode = AudioModeNeutral;
            singleton.localBufferSample = [NSMutableDictionary new];
            
            if ( [Utils isIOS8] ) {
                [[NSNotificationCenter defaultCenter] addObserver:singleton
                                                         selector:@selector(handleInterruption:)
                                                             name:AVAudioSessionInterruptionNotification
                                                           object:nil];
            }
        }
    }
    return singleton;
}

- (void)handleInterruption:(NSNotification*)note {
    int interruptionType = [note.userInfo[AVAudioSessionInterruptionTypeKey] intValue];
    
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

- (void)setCurrentAudioMode:(AudioMode)currentAudioMode {
    _currentAudioMode = currentAudioMode;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                        change:(NSDictionary *)change context:(void *)context {
    
    // Monitoring AVPlayer->currentItem status.
    
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
                            [self takedownAudioPlayer];
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
                    [self.audioPlayer play];
                    [self seekToDate:self.queuedSeekDate forward:NO failover:NO];
                });
            } else if ( self.tryAgain ) {
                NSLog(@"Trying again after failure...");
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
                    if ( self.audioPlayer.rate == 0.0 ) {
                        [self.audioPlayer play];
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
                self.dropoutOccurred = YES;
#ifndef SUPPRESS_BITRATE_THROTTLING
                if ( [Utils isIOS8] ) {
                    [self.audioPlayer.currentItem setPreferredPeakBitRate:kPreferredPeakBitRateTolerance];
                }
#endif
                [self waitPatiently];

            }
        } else {
            NSLog(@"AVPlayerItem - Buffer filled normally...");
        }
    }
    
    if (object == self.audioPlayer.currentItem && [keyPath isEqualToString:@"playbackLikelyToKeepUp"]) {
        if ( [change[@"new"] intValue] == 0 ) {
            NSLog(@"AVPlayerItem - Stream not likely to keep up...");
            
            if ( !self.seekWillEffectBuffer ) {
                [self analyzeStreamError:@"Stream not likely to keep up..."];
                
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

- (void)interruptAutorecovery {
    if ( self.kickstartTimer ) {
        if ( [self.kickstartTimer isValid] ) {
            [self.kickstartTimer invalidate];
        }
        self.kickstartTimer = nil;
    }
}


#pragma mark - Recovery / Logging / Stalls
- (void)attemptToRecover {
#ifndef SUPPRESS_AGGRESSIVE_KICKSTART
    if ( self.kickstartTimer ) {
        if ( [self.kickstartTimer isValid] ) {
            [self.kickstartTimer invalidate];
        }
        self.kickstartTimer = nil;
    }
#endif
    
#ifndef SUPPRESS_LOCAL_SAMPLING
    [self startObservingTime];
#endif
    
    [self stopWaiting];
    self.localBufferSample = nil;
    
    NSLog(@"AVPlayerItem - Stream likely to return after interrupt (preferred BR : %1.6f...)",self.audioPlayer.currentItem.preferredPeakBitRate);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[AnalyticsManager shared] clearLogs];
        [[AnalyticsManager shared] logEvent:@"streamRecovered"
                             withParameters:@{}];
        
    });
}

- (void)impatientRestart {
#ifndef SUPPRESS_AGGRESSIVE_KICKSTART
    if ( [self.audioPlayer rate] > 0.0 && self.dropoutOccurred ) {
        [self takedownAudioPlayer];
        [self buildStreamer:kHLSLiveStreamURL];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self playAudio];
        });
    }
#endif
}

- (void)waitPatiently {
#ifdef DEBUG
    self.multipurposeTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self
                                   selector:@selector(timeRemaining)
                                   userInfo:nil
                                    repeats:YES];
#endif
    if ( [[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground ) {
        self.rescueTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
            self.dropoutOccurred = NO;
            [self stopWaiting];
            [self stopAllAudio];
            [self takedownAudioPlayer];
            SCPRMasterViewController *master = (SCPRMasterViewController*)[[Utils del] masterViewController];
            [master resetUI];
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
        [[AnalyticsManager shared] setErrorLog:self.audioPlayer.currentItem.errorLog];
        [self analyzeStreamError:nil];
    }
    if ( SEQ([note name],AVPlayerItemNewAccessLogEntryNotification) ) {
        [[AnalyticsManager shared] setAccessLog:self.audioPlayer.currentItem.accessLog];
    }
}

- (void)playbackStalled:(NSNotification*)note {
    
    if ( self.dropoutOccurred ) return;
    
    self.dropoutOccurred = YES;
    [self waitPatiently];
    
    NSLog(@"Playback stalled ... ");
    if ( [note object] ) {
        NSLog(@"%@",[[note object] description]);
    }
    if ( [note userInfo] ) {
        NSLog(@"%@",[[note userInfo] description]);
    }
    
}

- (void)localSample:(CMTime)time {
    NSArray *seekRange = self.audioPlayer.currentItem.seekableTimeRanges;
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
        
        NSString *expStr = [NSDate stringFromDate:expectedDate
                                       withFormat:@"HH:mm:ss a"];
        NSString *repStr = [NSDate stringFromDate:reportedDate
                                       withFormat:@"HH:mm:ss a"];
        
        CMTimeRange range = [seekRange[0] CMTimeRangeValue];
        Float64 maxSeekTime = CMTimeGetSeconds(CMTimeRangeGetEnd(range));
        
        //NSLog(@"Reported Date : %@, Expected Date : %@",repStr,expStr);
        if ( fabs(etFloat - rtFloat) > 20.0 || ![expectedDate isWithinTimeFrame:20 ofDate:reportedDate] ) {
            
            if ( self.userPause ) {
                return;
            }

            
            [[AnalyticsManager shared] logEvent:@"streamSkippedByLargeInterval"
                                 withParameters:@{ @"expected" : expStr,
                                                   @"reported" : repStr,
                                                   @"reportedTimeValue" : @(rtFloat),
                                                   @"reportedMaxSeekTime" : @(maxSeekTime)}];
        }
        
        
        self.localBufferSample[@"frame"] = @([localSamples count]);
        
        
        [localSamples addObject:@{ @"frame" : @(self.frameCount),
                                   @"sampleTime" : [NSValue valueWithCMTime:time] }];
        
        self.localBufferSample[@"expectedDate"] = self.audioPlayer.currentItem.currentDate;
        self.localBufferSample[@"expectedTime"] = [NSValue valueWithCMTime:time];
        
    }
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

    [self invalidateTimeObserver];
    

    self.timeObserver = nil;
    self.waitForFirstTick = YES;
    self.frameCount = 0;
    self.timeObserver = [self.audioPlayer addPeriodicTimeObserverForInterval:CMTimeMake(1, 10) queue:NULL
                                                                  usingBlock:^(CMTime time) {
        
        if ( weakSelf.frameCount % 10 == 0 ) {
            weakSelf.currentDate = audioPlayer.currentItem.currentDate;
        }
                                                                      
        weakSelf.dropoutOccurred = NO;
        NSArray *seekRange = audioPlayer.currentItem.seekableTimeRanges;
        if (seekRange && [seekRange count] > 0) {
            CMTimeRange range = [seekRange[0] CMTimeRangeValue];
            if ([weakSelf.delegate respondsToSelector:@selector(onTimeChange)]) {
                if ( weakSelf.waitForFirstTick ) {
                    weakSelf.waitForFirstTick = NO;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[NSNotificationCenter defaultCenter] postNotificationName:@"audio_player_began_playing"
                                                                            object:nil];
                    });
                }
                [weakSelf.delegate onTimeChange];
            }
            

            if ( weakSelf.smooth ) {
                [weakSelf adjustAudioWithValue:0.0045 completion:^{
                    weakSelf.smooth = NO;
                }];
            }
            
            if ( weakSelf.kickstartTimer ) {
                if ( [weakSelf.kickstartTimer isValid] ) {
                    [weakSelf.kickstartTimer invalidate];
                }
                weakSelf.kickstartTimer = nil;
            }
            
            weakSelf.seekRequested = NO;

            if ( weakSelf.frameCount % 10 == 0 ) {
                
                NSArray *tmd = weakSelf.audioPlayer.currentItem.timedMetadata;
                for ( NSObject *obj in tmd ) {
                    NSLog(@"MD : %@",[obj description]);
                }
                
#ifndef SUPPRESS_LOCAL_SAMPLING
                if ( weakSelf.currentAudioMode == AudioModeLive ) {
                    [weakSelf localSample:time];
                }
#endif
                
                if ( weakSelf.currentAudioMode == AudioModeOnDemand ) {
                    [[QueueManager shared] handleBookmarkingActivity];
                }
                
                weakSelf.userPause = NO;
                weakSelf.minSeekableDate = [NSDate dateWithTimeInterval:( -1 * (CMTimeGetSeconds(time) - CMTimeGetSeconds(range.start))) sinceDate:weakSelf.currentDate];
                weakSelf.maxSeekableDate = [NSDate dateWithTimeInterval:(CMTimeGetSeconds(CMTimeRangeGetEnd(range)) - CMTimeGetSeconds(time)) sinceDate:weakSelf.currentDate];
 
                [[SessionManager shared] trackLiveSession];
                [[SessionManager shared] trackRewindSession];
                [[SessionManager shared] trackOnDemandSession];
                [[SessionManager shared] checkProgramUpdate:NO];
                
            }

            weakSelf.frameCount++;
            
        }
        
        
    }];
    
}

- (void)invalidateTimeObserver {
    if ( self.timeObserver ) {
        [self.audioPlayer removeTimeObserver:self.timeObserver];
        self.timeObserver = nil;
    }
}

- (void)seekToPercent:(CGFloat)percent {
    NSArray *seekRange = self.audioPlayer.currentItem.seekableTimeRanges;
    if (seekRange && [seekRange count] > 0) {
        CMTimeRange range = [seekRange[0] CMTimeRangeValue];

        CMTime seekTime = CMTimeMakeWithSeconds( CMTimeGetSeconds(range.start) + ( CMTimeGetSeconds(range.duration) * (percent / 100)),
                                                range.start.timescale);

        [self.audioPlayer.currentItem seekToTime:seekTime];
    }
}

- (void)seekToDate:(NSDate *)date forward:(BOOL)forward failover:(BOOL)failover {
    if ( [self.audioPlayer.currentItem status] != AVPlayerItemStatusReadyToPlay ) {
        NSLog(@" ******* PLAYER ITEM NOT READY TO PLAY BEFORE SEEKING ******* ");
    }
    
    NSLog(@"Requesting a seek to : %@",[NSDate stringFromDate:date
                                                   withFormat:@"hh:mm:ss a"]);
    
#ifndef SUPPRESS_LOCAL_SAMPLING
    self.localBufferSample[@"expectedDate"] = date;
    self.localBufferSample[@"open"] = @(NO);
#endif
    
    if (!self.audioPlayer) {
        self.waitForSeek = YES;
        self.audioPlayer.volume = 0.0;
        self.savedVolume = 1.0;
        self.queuedSeekDate = date;
        [self buildStreamer:kHLSLiveStreamURL];
        return;
    }
    
    self.waitForSeek = NO;
    self.seekRequested = YES;
    self.seekWillEffectBuffer = YES;
    
    if ( !failover ) {
        NSTimeInterval s2d = [date timeIntervalSince1970];
#ifndef SUPPRESS_V_LIVE
        NSTimeInterval now = [[[SessionManager shared] vLive] timeIntervalSince1970];
#else
        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
#endif
        
        BOOL nudge = NO;
        if ( abs(now - s2d) > kStreamIsLiveTolerance ) {
            nudge = YES;
        }
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{

            NSDate *justABitInTheFuture = nudge ? [date dateByAddingTimeInterval:[[SessionManager shared] calculatedDriftValue]] : date;
            [self.audioPlayer.currentItem seekToDate:justABitInTheFuture completionHandler:^(BOOL finished) {
                if ( !finished ) {
                    NSLog(@" **************** AUDIOPLAYER NOT FINISHED BUFFERING ****************** ");
                }
                if(self.audioPlayer.status == AVPlayerStatusReadyToPlay &&
                   self.audioPlayer.currentItem.status == AVPlayerItemStatusReadyToPlay) {
                    
                    if ( ![self verifyPositionAuthenticity] ) {
                        // Try again
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.75 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                            NSLog(@"*********** // Buffering ... \\ ************");
                            if ( [self.delegate respondsToSelector:@selector(interfere)] ) {
                                [self.delegate interfere];
                            }
                            if ( self.audioPlayer.rate > 0.0 ) {
                                [self.audioPlayer pause];
                            }
                            [self.audioPlayer.currentItem cancelPendingSeeks];
                            [self seekToDate:justABitInTheFuture forward:NO failover:YES];
                        });
                        
                        return;
                    }
                    
                    if ( !failover ) {
                        NSLog(@"*** Seek to date : SUCCESS : %@",[NSDate stringFromDate:self.audioPlayer.currentItem.currentDate
                                                                             withFormat:@"hh:mm:ss a"]);
                    }
                    
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
                    
                } else {
                    NSLog(@"Stream was not ready to play at the time of the seek request");
                }
            }];
            
        });
        
        return;
    }
    
    long tsn = 0;
    long tsmsd = 0;
    long start = 0;
    CMTime barometer;
    for ( NSValue *str in self.audioPlayer.currentItem.seekableTimeRanges ) {
        CMTimeRange r = [str CMTimeRangeValue];
        NSLog(@"Seekable Start : %ld, duration : %ld",(long)CMTimeGetSeconds(r.start),(long)CMTimeGetSeconds(r.duration));
        if ( CMTimeGetSeconds(r.duration) >= kStreamBufferLimit ) {
            barometer = r.duration;
        }
        
        tsn = [date timeIntervalSinceDate:[NSDate date]];
        tsmsd = [date timeIntervalSinceDate:[self maxSeekableDate]];
        NSInteger diff = [[self maxSeekableDate] timeIntervalSinceDate:[NSDate date]];
        
        start = CMTimeGetSeconds(r.start);
        tsn = labs(tsn) - CMTimeGetSeconds(r.start);
        tsmsd = labs(tsmsd) - CMTimeGetSeconds(r.start);
        
        tsn = MAX(tsmsd, tsn);
        
        if ( diff < 0 ) {
            tsn += diff;
        }
        if ( start < 0 ) {
            tsn -= start;
        }
        break;
    }
    
    if ( self.audioPlayer.currentItem.seekableTimeRanges.count == 0 ) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.75 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSLog(@" ******* BUFFERING ******* ");
            if ( [self.delegate respondsToSelector:@selector(interfere)] ) {
                [self.delegate interfere];
            }
            [self.audioPlayer.currentItem cancelPendingSeeks];
            [self seekToDate:date forward:forward failover:YES];
        });
        return;
    }
    
    NSLog(@"Seek in seconds : %ld",(long)tsn);
    
    CMTime seekTime = CMTimeMakeWithSeconds(CMTimeGetSeconds(barometer) - tsn + 10.0, barometer.timescale);
    
    [self.audioPlayer.currentItem seekToTime:seekTime completionHandler:^(BOOL finished) {
        dispatch_async(dispatch_get_main_queue(), ^{
            
            if ( ![self verifyPositionAuthenticity] ) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.75 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    NSLog(@" ******* BUFFERING ******* ");
                    if ( [self.delegate respondsToSelector:@selector(interfere)] ) {
                        [self.delegate interfere];
                    }
                    [self.audioPlayer.currentItem cancelPendingSeeks];
                    [self seekToDate:date forward:forward failover:YES];
                });
                return;
            }
            
#ifndef SUPPRESS_LOCAL_SAMPLING
            self.localBufferSample[@"expectedDate"] = self.audioPlayer.currentItem.currentDate;
            self.localBufferSample[@"open"] = @(YES);
#endif
            
            if ( [self.audioPlayer rate] == 0.0 ) {
                [self playAudio];
            }
            
            self.status = StreamStatusPlaying;
            if ([self.delegate respondsToSelector:@selector(onSeekCompleted)]) {
                [self.delegate onSeekCompleted];
            }
            
        });
    }];
}

- (void)seekToDate:(NSDate *)date {
    [self seekToDate:date forward:abs([date timeIntervalSinceDate:[NSDate date]] > 60)
            failover:NO];
}

- (BOOL)verifyPositionAuthenticity {
    
    long stableDuration = [[SessionManager shared] bufferLength];
    
    if ( [[SessionManager shared] secondsBehindLive] > stableDuration ) {
        Program *p = [[SessionManager shared] currentProgram];
        if ( p ) {
            if ( labs([[p ends_at] timeIntervalSince1970] - [[p starts_at] timeIntervalSince1970]) < stableDuration ) {
                return NO;
            }
        }
    }
    
    return YES;
    
}

- (void)specialSeekToDate:(NSDate *)date {
  /*  [self.audioPlayer pause];
    [self.audioPlayer.currentItem seekToDate:[self maxSeekableDate] completionHandler:^(BOOL finished) {

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self seekToDate:date];
        });
        
    }];
   
   */
}

- (void)forwardSeekLive {
    if (!self.audioPlayer) {
        [self buildStreamer:kHLSLiveStreamURL];
    }

#ifndef SUPPRESS_LOCAL_SAMPLING
    self.localBufferSample[@"expectedDate"] = [NSDate date];
    self.localBufferSample[@"open"] = @(NO);
#endif
    
    NSDate *target = [NSDate date];
    if ( labs([[self maxSeekableDate] timeIntervalSince1970] - [target timeIntervalSince1970] ) <= kStreamCorrectionTolerance ) {
        target = [self maxSeekableDate];
    }
    
#ifdef THREE_ZERO_ZERO
    [self seekToDate:target
             forward:YES
            failover:NO];
#else
    
    self.seekWillEffectBuffer = YES;
    [self.audioPlayer.currentItem seekToTime:CMTimeMake(MAXFLOAT * HUGE_VALF, 1) completionHandler:^(BOOL finished) {
        
#ifndef SUPPRESS_LOCAL_SAMPLING
        self.localBufferSample[@"expectedDate"] = self.audioPlayer.currentItem.currentDate;
        self.localBufferSample[@"open"] = @(YES);
#endif
        
        if ( [self.audioPlayer rate] <= 0.0 ) {
            [self.audioPlayer play];
        }
        [self.delegate onSeekCompleted];
    }];
    
#endif
}

- (void)forwardSeekThirtySeconds {
    NSDate *currentDate = self.audioPlayer.currentItem.currentDate;
    if (currentDate) {
        [self seekToDate:[currentDate dateByAddingTimeInterval:(30)]];
    }
}

- (void)backwardSeekThirtySeconds {
    NSDate *currentDate = self.audioPlayer.currentItem.currentDate;
    if (currentDate) {
        [self seekToDate:[currentDate dateByAddingTimeInterval:(-30)]];
    }
}

- (void)forwardSeekFifteenSeconds {
    NSDate *currentDate = self.audioPlayer.currentItem.currentDate;
    if (currentDate) {
        [self seekToDate:[currentDate dateByAddingTimeInterval:(15)]];
    }
}

- (void)backwardSeekFifteenSeconds {
    NSDate *currentDate = self.audioPlayer.currentItem.currentDate;
    if (currentDate) {
        [self seekToDate:[currentDate dateByAddingTimeInterval:(-15)]];
    }
}

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
        [self takedownAudioPlayer];
        [self buildStreamer:kHLSLiveStreamURL];
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
    return kHLSLiveStreamURL;

    // Old.. used for playing pre-roll after given threshold on playback start. May be useful in the future.
/*
    long currentTimeSeconds = [[NSDate date] timeIntervalSince1970];
    SCPRDebugLog(@"currentTimeSeconds: %ld", currentTimeSeconds);
    SCPRDebugLog(@"currentTimeSeconds - LiveStreamThreshold: %ld", (currentTimeSeconds - kLiveStreamPreRollThreshold));
    SCPRDebugLog(@"currentTimeSeconds - lastPreRoll: %ld", (currentTimeSeconds - self.lastPreRoll));
    SCPRDebugLog(@"Current lastPreRoll time: %ld", self.lastPreRoll);

    if (currentTimeSeconds - self.lastPreRoll > kLiveStreamPreRollThreshold || currentTimeSeconds - self.lastPreRoll < 3) {
        SCPRDebugLog(@"liveStreamURL returning WITH preroll");
        return kLiveStreamAACURL;
    } else {
        SCPRDebugLog(@"liveStreamURL returning NO preroll");
        return kLiveStreamAACNoPreRollURL;
    }
*/
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
            // [0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}
    }
    
    if ( rv ) {
        NSLog(@"Playback Session ID : %@",rv);
    }
    return rv;

}

#pragma mark - Audio Control
- (void)buildStreamer:(NSString*)urlString local:(BOOL)local {
    NSURL *url;
    if ( !urlString ) {
        urlString = self.previousUrl;
    }
    if ( urlString == nil || SEQ(urlString, kHLSLiveStreamURL) ) {
        url = [NSURL URLWithString:kHLSLiveStreamURL];
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
    
    self.maxSeekableDate = nil;
    self.minSeekableDate = nil;
    self.status = StreamStatusStopped;
    self.currentAudioMode = AudioModeNeutral;
    self.audioPlayer = nil;
}

- (void)resetPlayer {
    [self takedownAudioPlayer];
    [self buildStreamer:kHLSLiveStreamURL];
}

- (void)sanitizeFromOnboarding {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AVPlayerItemDidPlayToEndTimeNotification
                                                  object:nil];
}


- (void)playAudioWithURL:(NSString *)url {
    
    if ( [self currentAudioMode] != AudioModePreroll ) {
        //url = [url stringByAppendingString:[NSString stringWithFormat:@"?ua=KPCCiPhone-%@",[Utils urlSafeVersion]]];
    }
    
    [[UXmanager shared] timeBegin];
    [self takedownAudioPlayer];
    [[UXmanager shared] timeEnd:@"Takedown audio player"];
    
    [[UXmanager shared] timeBegin];
    [self buildStreamer:url];
    [[UXmanager shared] timeEnd:@"Build audio player"];
    
    [[UXmanager shared] timeBegin];
    [self playAudio];
    [[UXmanager shared] timeEnd:@"Play Audio"];
    
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
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerItemDidFinishPlaying:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:nil];
}


- (void)playLiveStream {
    [[QueueManager shared] setCurrentBookmark:nil];
    
    [self stopAllAudio];
    [self buildStreamer:kHLSLiveStreamURL];
    [self playAudio];
}

- (void)playOnboardingAudio:(NSInteger)segment {

    [self takedownAudioPlayer];
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

- (void)startStream {
    [self playAudio];
}

- (void)playAudio {
    
    [[ContentManager shared] saveContext];
    
    if (!self.audioPlayer) {
        [self buildStreamer:kHLSLiveStreamURL];
    }
    
    if ( [self currentAudioMode] == AudioModeOnboarding ) {
        self.audioPlayer.volume = 0.0;
    }
    
    [[SessionManager shared] startAudioSession];
    
    [[SessionManager shared] setSessionPausedDate:nil];
    self.status = StreamStatusPlaying;
    
    if ( self.smooth ) {
        self.savedVolume = self.audioPlayer.volume;
        if ( self.savedVolume <= 0.0 ) {
            self.savedVolume = 1.0;
        }
        self.audioPlayer.volume = 0.0;
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
                    
                }
            }
        }
    }
    
    if ( self.audioPlayer.currentItem.status == AVPlayerItemStatusReadyToPlay ) {
        [self.audioPlayer play];
    }

}

- (void)pauseAudio {
    
    [self.audioPlayer pause];
    self.status = StreamStatusPaused;
    self.localBufferSample = nil;
    
    if ( self.dropoutOccurred && !self.userPause ) {
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        if ( self.currentAudioMode == AudioModeLive ) {
            if ( [[SessionManager shared] sessionIsBehindLive] ) {
                [[SessionManager shared] setSessionPausedDate:[[AudioManager shared].audioPlayer.currentItem currentDate]];
            } else {
                [[SessionManager shared] setSessionPausedDate:[NSDate date]];
            }
            [[SessionManager shared] endLiveSession];
        } else {
            [[SessionManager shared] endOnDemandSessionWithReason:OnDemandFinishedReasonEpisodePaused];
        }
    });
     
}

- (void)stopAudio {
    [self takedownAudioPlayer];
    self.status = StreamStatusStopped;
}

- (void)cheatPlay {
    [self buildStreamer:kHLSLiveStreamURL];
    [self.audioPlayer setVolume:0.0];
    self.audioCheating = YES;
    [self.audioPlayer play];
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
        self.savedVolumeFromMute = -1.0;
    }
    [self threadedAdjustWithValue:increment completion:completion];
}

- (void)threadedAdjustWithValue:(CGFloat)increment completion:(void (^)(void))completion {
    
    //NSLog(@"Fading in audio : %1.2f",self.audioPlayer.volume);
    
    BOOL basecase = NO;
    BOOL increasing = NO;
    if ( increment < 0.0000f ) {
        basecase = self.audioPlayer.volume <= 0.0;
    } else {
        basecase = self.audioPlayer.volume >= self.savedVolume;
        increasing = YES;
    }
    
    if ( basecase ) {
        if ( increasing ) {
            self.audioPlayer.volume = self.savedVolume;
            self.autoMuted = NO;
        } else {
            self.autoMuted = YES;
        }
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
    if ( self.savedVolumeFromMute <= 0.0 ) self.savedVolumeFromMute = 1.0;
    self.audioPlayer.volume = 0.0;
}

- (void)unmuteAudio {
    self.audioPlayer.volume = self.savedVolumeFromMute;
    self.savedVolumeFromMute = -1.0;
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
                if ([self.delegate respondsToSelector:@selector(handleUIForRecoveredStream)]) {
                    //[self.delegate handleUIForRecoveredStream];
                }
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
