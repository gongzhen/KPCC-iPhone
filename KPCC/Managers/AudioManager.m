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

static AudioManager *singleton = nil;


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
        }
    }
    return singleton;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                        change:(NSDictionary *)change context:(void *)context {
    
    // Monitoring AVPlayer->currentItem status.
    if (object == self.audioPlayer.currentItem && [keyPath isEqualToString:@"status"]) {
#ifdef DEBUG
        NSNumber *old = (NSNumber*)change[@"old"];
        NSNumber *new = (NSNumber*)change[@"new"];

        if ( [old intValue] == [new intValue] ) {
            int x = 1;
            x++;
        }
#endif
        if ([self.audioPlayer.currentItem status] == AVPlayerItemStatusFailed) {
            NSError *error = [self.audioPlayer.currentItem error];
            NSLog(@"AVPlayerItemStatus ERROR! --- %@", error);
            if ( [self currentAudioMode] == AudioModeOnDemand ) {
                if ( [self.delegate respondsToSelector:@selector(onDemandAudioFailed)] ) {
                    [self.delegate onDemandAudioFailed];
                }
            }
            return;
        } else if ([self.audioPlayer.currentItem status] == AVPlayerItemStatusReadyToPlay) {
            NSLog(@"AVPlayerItemStatus - ReadyToPlay");
            if ( self.waitForSeek ) {
                NSLog(@"Delayed seek");
                self.waitForSeek = NO;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self seekToDate:self.queuedSeekDate forward:NO failover:NO];
                });
            }
        } else if ([self.audioPlayer.currentItem status] == AVPlayerItemStatusUnknown) {
            NSLog(@"AVPlayerItemStatus - Unknown");
        }
    }
    
    // Monitoring AVPlayer->currentItem with empty playback buffer.
    if (object == self.audioPlayer.currentItem && [keyPath isEqualToString:@"playbackBufferEmpty"]) {
        [self analyzeStreamError:nil];
    }
    
    if (object == self.audioPlayer.currentItem && [keyPath isEqualToString:@"playbackLikelyToKeepUp"]) {
        if ( [change[@"new"] intValue] == 0 ) {
            NSLog(@"Stream not likely to keep up...");
            [self analyzeStreamError:nil];
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
            [self startObservingTime];
        }
        if ( oldRate == 1.0 && newRate == 0.0 ) {
            self.status = StreamStatusPaused;
        }
        
        if ([self.delegate respondsToSelector:@selector(onRateChange)]) {
            [self.delegate onRateChange];
        }
        
    }
}




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

    if ( self.timeObserver ) {
        [self.audioPlayer removeTimeObserver:self.timeObserver];
    }
    self.timeObserver = nil;
    self.waitForFirstTick = YES;
    
#ifdef USE_LEGACY_STREAM_ANALYSIS
    @synchronized(self) {
        self.bufferMutex = YES;
        self.bufferObservationCount = 0;
    }
#else
    self.bufferMutex = NO;
#endif
    
    self.timeObserver = [self.audioPlayer addPeriodicTimeObserverForInterval:CMTimeMake(1, 10)  queue:nil usingBlock:^(CMTime time) {
        weakSelf.currentDate = audioPlayer.currentItem.currentDate;
        
        NSArray *seekRange = audioPlayer.currentItem.seekableTimeRanges;
        if (seekRange && [seekRange count] > 0) {
            CMTimeRange range = [seekRange[0] CMTimeRangeValue];

            weakSelf.minSeekableDate = [NSDate dateWithTimeInterval:( -1 * (CMTimeGetSeconds(time) - CMTimeGetSeconds(range.start))) sinceDate:weakSelf.currentDate];
            weakSelf.maxSeekableDate = [NSDate dateWithTimeInterval:(CMTimeGetSeconds(CMTimeRangeGetEnd(range)) - CMTimeGetSeconds(time)) sinceDate:weakSelf.currentDate];
            weakSelf.latencyCorrection = [[NSDate date] timeIntervalSince1970] - [weakSelf.maxSeekableDate timeIntervalSince1970];
            
            [[SessionManager shared] trackLiveSession];
            [[SessionManager shared] trackRewindSession];
            [[SessionManager shared] trackOnDemandSession];
            
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
            
        } else {
            NSLog(@"no seekable time range for current item");
        }
        
    }];
    
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
    
    if (!self.audioPlayer) {
        [self buildStreamer:kHLSLiveStreamURL];
        self.waitForSeek = YES;
        self.audioPlayer.volume = 0.0;
        self.savedVolume = 1.0;
        self.queuedSeekDate = date;
        [self.audioPlayer play];
        return;
    }
    
    if ( !failover || forward ) {
        NSTimeInterval s2d = [date timeIntervalSince1970];
        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
        BOOL nudge = NO;
        if ( abs(now - s2d) > 60 ) {
            nudge = YES;
        }
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSDate *justABitInTheFuture = nudge ? [NSDate dateWithTimeInterval:2 sinceDate:date] : date;
            [self.audioPlayer.currentItem seekToDate:justABitInTheFuture completionHandler:^(BOOL finished) {
                if ( !finished ) {
                    NSLog(@" **************** AUDIOPLAYER NOT FINISHED BUFFERING ****************** ");
                }
                if(self.audioPlayer.status == AVPlayerStatusReadyToPlay &&
                   self.audioPlayer.currentItem.status == AVPlayerItemStatusReadyToPlay) {
                    
                    if ( [[SessionManager shared] secondsBehindLive] > 14000 ) {
                        // Try again
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.75 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                            NSLog(@"*********** // Buffering ... \\ ************");
                            if ( [self.delegate respondsToSelector:@selector(interfere)] ) {
                                //[self.delegate interfere];
                            }
                            if ( self.audioPlayer.rate > 0.0 ) {
                                [self.audioPlayer pause];
                            }
                            [self.audioPlayer.currentItem cancelPendingSeeks];
                            [self seekToDate:date forward:forward failover:YES];
                        });
                        
                        return;
                    }
                    
                    if ( !failover ) {
                        NSLog(@"*** Seek to date : SUCCESS : %@",[NSDate stringFromDate:justABitInTheFuture
                                                                             withFormat:@"hh:mm:ss a"]);
                    }
                    
                    if ( [self.audioPlayer rate] == 0.0 ) {
                        [self playStream];
                    }
                    self.status = StreamStatusPlaying;
                    if ([self.delegate respondsToSelector:@selector(onSeekCompleted)]) {
                        [self.delegate onSeekCompleted];
                    }
                }
            }];
            
        });
        
        return;
    }
    
    int64_t tsn = 0;
    int64_t tsmsd = 0;
    int64_t start = 0;
    CMTime barometer;
    for ( NSValue *str in self.audioPlayer.currentItem.seekableTimeRanges ) {
        CMTimeRange r = [str CMTimeRangeValue];
        NSLog(@"Seekable Start : %ld, duration : %ld",(long)CMTimeGetSeconds(r.start),(long)CMTimeGetSeconds(r.duration));
        if ( CMTimeGetSeconds(r.duration) > 14400 ) {
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
    
    CMTime seekTime = CMTimeMakeWithSeconds(CMTimeGetSeconds(barometer) - tsn, barometer.timescale);
    [self.audioPlayer.currentItem seekToTime:seekTime completionHandler:^(BOOL finished) {
        dispatch_async(dispatch_get_main_queue(), ^{
            
            if ( [[SessionManager shared] secondsBehindLive] > 14100 ) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.75 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    NSLog(@" ******* BUFFERING ******* ");
                    if ( [self.delegate respondsToSelector:@selector(interfere)] ) {
                        [self.delegate interfere];
                    }
                    [self.audioPlayer.currentItem cancelPendingSeeks];
                    [self seekToDate:date forward:forward failover:YES];
                });
            }
            
            if ( [self.audioPlayer rate] == 0.0 ) {
                [self playStream];
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

    [self seekToDate:[self maxSeekableDate] forward:YES failover:NO];
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

    if ( ![[QueueManager shared]isQueueEmpty] ) {
        [[SessionManager shared] endOnDemandSessionWithReason:OnDemandFinishedReasonEpisodeEnd];
        [[QueueManager shared] playNext];
    } else {
        [self takedownAudioPlayer];
        [self buildStreamer:kHLSLiveStreamURL];
        [self startStream];
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
    
    
    [self takedownAudioPlayer];
    [self buildStreamer:url];
    [self startStream];
    
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
    [self stopAllAudio];
    [self buildStreamer:kHLSLiveStreamURL];
    [self startStream];
}

- (void)playOnboardingAudio:(NSInteger)segment {
    if ( self.temporaryMutex ) {
        self.temporaryMutex = NO;
        return;
    }
    
    self.temporaryMutex = YES;
    
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
    
    [self startStream];
    
}

- (void)startStream {
    
    if ( self.temporaryMutex ) {
        self.temporaryMutex = NO;
        return;
    }
    
    self.temporaryMutex = YES;
    if (!self.audioPlayer) {
        [self buildStreamer:kHLSLiveStreamURL];
    }


    if ( self.currentAudioMode == AudioModeOnboarding ) {
        self.audioPlayer.volume = 0.0;
    }
    [self.audioPlayer play];
    
    if ( self.currentAudioMode == AudioModeLive ) {
        [[SessionManager shared] startLiveSession];
    }

    [[SessionManager shared] setSessionPausedDate:nil];
    
    self.status = StreamStatusPlaying;


}

- (void)playStream {
    if ( [self currentAudioMode] == AudioModeOnboarding ) {
        self.audioPlayer.volume = 0.0;
    }
    
    self.status = StreamStatusPlaying;
    [self.audioPlayer play];
    
}

- (void)pauseStream {
    [self.audioPlayer pause];
    self.status = StreamStatusPaused;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        if ( self.currentAudioMode == AudioModeLive ) {
            [[SessionManager shared] setSessionPausedDate:[NSDate date]];
            [[SessionManager shared] endLiveSession];
        } else {
            [[SessionManager shared] endOnDemandSessionWithReason:OnDemandFinishedReasonEpisodePaused];
        }
    });

}

- (void)stopStream {
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
    [self stopStream];

    if (self.localAudioPlayer && self.localAudioPlayer.isPlaying) {
        [self.localAudioPlayer stop];
    }
}

- (void)adjustAudioWithValue:(CGFloat)increment completion:(void (^)(void))completion {
    if ( increment < 0.0 ) {
        if ( self.savedVolumeFromMute >= 0.0 ) {
            self.savedVolume = self.savedVolumeFromMute;
        } else {
            self.savedVolume = self.audioPlayer.volume;
        }
    } else {
        if ( self.savedVolumeFromMute >= 0.0 ) {
            self.savedVolume = self.savedVolumeFromMute;
        }
        self.savedVolumeFromMute = -1.0;
    }
    [self threadedAdjustWithValue:increment completion:completion];
}

- (void)threadedAdjustWithValue:(CGFloat)increment completion:(void (^)(void))completion {
    BOOL basecase = NO;
    BOOL increasing = NO;
    if ( increment < 0.0 ) {
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
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self.audioPlayer setVolume:self.audioPlayer.volume+increment];
                [self threadedAdjustWithValue:increment completion:completion];
            });
        }];
        [self.fadeQueue addOperation:block];
    }
}

- (void)muteAudio {
    self.savedVolumeFromMute = self.audioPlayer.volume;
    if ( self.savedVolumeFromMute == 0.0 ) self.savedVolumeFromMute = 1.0;
}

- (void)unmuteAudio {
    self.audioPlayer.volume = self.savedVolumeFromMute;
    self.savedVolumeFromMute = -1.0;
}

- (void)takedownAudioPlayer {
    
    
    self.temporaryMutex = NO;
    if ( self.audioPlayer ) {
        
        [self.audioPlayer pause];
        
    }
    if (self.timeObserver) {
        [self.audioPlayer removeTimeObserver:self.timeObserver];
        self.timeObserver = nil;
    }

    @try {
        [self.audioPlayer removeObserver:self forKeyPath:@"rate"];
        [self.audioPlayer removeObserver:self forKeyPath:@"status"];
        [self.audioPlayer.currentItem removeObserver:self forKeyPath:@"status"];
        [self.audioPlayer.currentItem removeObserver:self forKeyPath:@"playbackBufferEmpty"];
        [self.audioPlayer.currentItem removeObserver:self forKeyPath:@"playbackLikelyToKeepUp"];
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:AVPlayerItemDidPlayToEndTimeNotification
                                                      object:nil];
        // AVPlayerItemFailedToPlayToEndTimeNotification
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:AVPlayerItemFailedToPlayToEndTimeNotification
                                                      object:nil];
        
    } @catch (NSException *e) {
        // Wasn't necessary
    }
    
    [[SessionManager shared] resetCache];
    
    if ( self.currentAudioMode != AudioModeOnboarding ) {
        [self.audioPlayer cancelPendingPrerolls];
    }
    
    self.status = StreamStatusStopped;
    self.audioPlayer = nil;
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
    return [[AudioManager shared] bufferMutex];
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
            NSLog(@"Player access log : %@",logAsString);
        }
    }
    
    /*
    NSLog(@"currentDate : %@",[self.audioPlayer.currentItem.currentDate prettyTimeString]);
    NSDate *msd = [self maxSeekableDate];
    NSLog(@" ******* MAX SEEKABLE DATE : %@ *******",msd);
    NSDate *minSd = [self minSeekableDate];
    NSLog(@" ******* MIN SEEKABLE DATE : %@ *******",minSd);
     */
    
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

    NSURL *liveURL = [NSURL URLWithString:kHLSLiveStreamURL];
    NetworkHealth netHealth = [[NetworkManager shared] checkNetworkHealth:[liveURL host]];

    switch (netHealth) {
        case NetworkHealthAllOK:
            // If recovering from stream failure, cancel playing of local audio file
            if (self.localAudioPlayer && self.localAudioPlayer.isPlaying) {
                [self.localAudioPlayer stop];
                
                if ([self.delegate respondsToSelector:@selector(handleUIForRecoveredStream)]) {
                    [self.delegate handleUIForRecoveredStream];
                }
            }
            break;
            
        case NetworkHealthNetworkDown:
            //[self localAudioFallback:[[NSBundle mainBundle] pathForResource:kFailedConnectionAudioFile ofType:@"mp3"]];
            if ([self.delegate respondsToSelector:@selector(handleUIForFailedConnection)]) {
                [self.delegate handleUIForFailedConnection];
            }
            [[AnalyticsManager shared] failStream:StreamStateLostConnectivity comments:comments];
            break;
        
        case NetworkHealthServerDown:
            //[self localAudioFallback:[[NSBundle mainBundle] pathForResource:kFailedStreamAudioFile ofType:@"mp3"]];
            if ([self.delegate respondsToSelector:@selector(handleUIForFailedStream)]) {
                [self.delegate handleUIForFailedStream];
            }
            [[AnalyticsManager shared] failStream:StreamStateServerFail comments:comments];
            break;
            
        default:
            [[AnalyticsManager shared] failStream:StreamStateUnknown comments:comments];
            break;
    }
}

- (void)localAudioFallback:(NSString *)filePath {

    if (!filePath) {
        return;
    }

    [self stopStream];

    // Init the local audio player, set to loop indefinitely, and play.
    self.localAudioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:filePath] error:nil];
    self.localAudioPlayer.numberOfLoops = -1;
    [self.localAudioPlayer play];
}

@end
