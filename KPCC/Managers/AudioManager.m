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

static AudioManager *singleton = nil;
static NSInteger kBufferObservationThreshold = 25;
static NSInteger kAllowableDriftThreshold = 45;

// Define this constant for the key-value observation context.
static const NSString *ItemStatusContext;

@implementation AudioManager

+ (AudioManager*)shared {
    if (!singleton) {
        @synchronized(self) {
            singleton = [[AudioManager alloc] init];
            singleton.fadeQueue = [[NSOperationQueue alloc] init];
            singleton.status = StreamStatusStopped;
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
            return;
        } else if ([self.audioPlayer.currentItem status] == AVPlayerItemStatusReadyToPlay) {
            NSLog(@"AVPlayerItemStatus - ReadyToPlay");
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
        
        CGFloat oldRate = [[change objectForKey:@"old"] floatValue];
        CGFloat newRate = [[change objectForKey:@"new"] floatValue];
        
        if ([self.delegate respondsToSelector:@selector(onRateChange)]) {
            [self.delegate onRateChange];
        }
        
        // Now playing, was stopped.
        if (oldRate == 0.0 && newRate == 1.0) {
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
        }
    }
}



- (void)buildStreamer:(NSString*)urlString {
    NSURL *url;
    if (urlString == nil) {
        url = [NSURL URLWithString:kHLSLiveStreamURL];
    } else {
        url = [NSURL URLWithString:urlString];
    }
    
    self.playerItem = [AVPlayerItem playerItemWithURL:url];
    [self.playerItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionOld|NSKeyValueObservingOptionNew context:nil];
    [self.playerItem addObserver:self forKeyPath:@"playbackBufferEmpty" options:NSKeyValueObservingOptionNew context:nil];
    [self.playerItem addObserver:self forKeyPath:@"playbackLikelyToKeepUp" options:NSKeyValueObservingOptionNew context:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerItemFailedToPlayToEndTime:) name:AVPlayerItemFailedToPlayToEndTimeNotification object:self.playerItem];

    self.audioPlayer = [AVPlayer playerWithPlayerItem:self.playerItem];
    [self.audioPlayer addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionOld|NSKeyValueObservingOptionNew context:nil];
    [self.audioPlayer addObserver:self forKeyPath:@"rate" options:NSKeyValueObservingOptionOld|NSKeyValueObservingOptionNew context:nil];

    
    [self startObservingTime];
}


- (void)playAudioWithURL:(NSString *)url {
    [self takedownAudioPlayer];
    [self buildStreamer:url];

// Subscribe to the AVPlayerItem's DidPlayToEndTime notification.
//    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerItemDidFinishPlaying:) name:AVPlayerItemDidPlayToEndTimeNotification object:self.playerItem];

    [self startStream];
}

- (void)playQueueItemWithUrl:(NSString *)url {
    [self playAudioWithURL:url];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerItemDidFinishPlaying:) name:AVPlayerItemDidPlayToEndTimeNotification object:self.playerItem];
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
    
    @synchronized(self) {
        self.bufferMutex = YES;
        self.bufferObservationCount = 0;
    }
    
    self.timeObserver = [self.audioPlayer addPeriodicTimeObserverForInterval:CMTimeMake(1, 10)  queue:nil usingBlock:^(CMTime time) {
        weakSelf.currentDate = audioPlayer.currentItem.currentDate;
        
        NSDate *d2u = weakSelf.requestedSeekDate ? weakSelf.requestedSeekDate : [NSDate date];
        NSTimeInterval drift = [d2u timeIntervalSinceDate:[weakSelf currentDate]];
        if ( weakSelf.bufferMutex ) {
            if ( abs(drift) <= kAllowableDriftThreshold ) {
                if ( weakSelf.bufferObservationCount >= kBufferObservationThreshold ) {
                    @synchronized(weakSelf) {
                        weakSelf.bufferMutex = NO;
#ifdef VERBOSE_STREAM_LOGGING
                        NSLog(@"Finished buffering...");
#endif
                    }
                } else {
#ifdef VERBOSE_STREAM_LOGGING
                    NSLog(@"Drift Stabilizing... : %ld seconds",(long)drift);
#endif
                    weakSelf.bufferObservationCount++;
                }
            } else {
#ifdef VERBOSE_STREAM_LOGGING
                NSLog(@"Drift (Buffering) : %ld seconds",(long)drift);
#endif
            }
        }
        
#ifdef DEBUG
        [weakSelf streamFrame];
#endif
        
        NSArray *seekRange = audioPlayer.currentItem.seekableTimeRanges;
        if (seekRange && [seekRange count] > 0) {
            CMTimeRange range = [[seekRange objectAtIndex:0] CMTimeRangeValue];

            weakSelf.minSeekableDate = [NSDate dateWithTimeInterval:( -1 * (CMTimeGetSeconds(time) - CMTimeGetSeconds(range.start))) sinceDate:weakSelf.currentDate];
            weakSelf.maxSeekableDate = [NSDate dateWithTimeInterval:(CMTimeGetSeconds(CMTimeRangeGetEnd(range)) - CMTimeGetSeconds(time)) sinceDate:weakSelf.currentDate];
            weakSelf.latencyCorrection = [[NSDate date] timeIntervalSince1970] - [weakSelf.maxSeekableDate timeIntervalSince1970];
            
            if ([weakSelf.delegate respondsToSelector:@selector(onTimeChange)]) {
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
        CMTimeRange range = [[seekRange objectAtIndex:0] CMTimeRangeValue];

        CMTime seekTime = CMTimeMakeWithSeconds( CMTimeGetSeconds(range.start) + ( CMTimeGetSeconds(range.duration) * (percent / 100)),
                                                range.start.timescale);

        [self.audioPlayer.currentItem seekToTime:seekTime];
    }
}

- (void)seekToDate:(NSDate *)date {
    if (!self.audioPlayer) {
        [self buildStreamer:kHLSLiveStreamURL];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [self.audioPlayer.currentItem seekToDate:date completionHandler:^(BOOL finished) {
                if(self.audioPlayer.status == AVPlayerStatusReadyToPlay &&
                   self.audioPlayer.currentItem.status == AVPlayerItemStatusReadyToPlay) {
                    [self.audioPlayer play];

                    if ([self.delegate respondsToSelector:@selector(onSeekCompleted)]) {
                        [self.delegate onSeekCompleted];
                    }
                }
            }];
        });

    } else {
        [self.audioPlayer pause];
        [self.audioPlayer.currentItem seekToDate:date completionHandler:^(BOOL finished) {
            if ( !finished ) {
                NSLog(@" **************** AUDIOPLAYER NOT FINISHED BUFFERING ****************** ");
            }
            if(self.audioPlayer.status == AVPlayerStatusReadyToPlay &&
               self.audioPlayer.currentItem.status == AVPlayerItemStatusReadyToPlay) {
                
                if ( [[NSDate date] timeIntervalSinceDate:date] > 60 ) {
                    self.requestedSeekDate = date;
                } else {
                    self.requestedSeekDate = nil;
                }
                
                self.bufferMutex = YES;
                self.bufferObservationCount = 0;
                
                if ( [self.audioPlayer rate] == 0.0 ) {
                    [self.audioPlayer play];
                }

                if ([self.delegate respondsToSelector:@selector(onSeekCompleted)]) {
                    [self.delegate onSeekCompleted];
                }
                
#ifdef VERBOSE_STREAM_LOGGING
                [self dump:NO];
#endif
            }
        }];
    }
}

- (void)specialSeekToDate:(NSDate *)date {
    [self.audioPlayer pause];
    [self.audioPlayer.currentItem seekToDate:[self maxSeekableDate] completionHandler:^(BOOL finished) {

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self seekToDate:date];
        });
        
    }];
}

- (void)forwardSeekLive {
    if (!self.audioPlayer) {
        [self buildStreamer:kHLSLiveStreamURL];
    } else {
        [self.audioPlayer pause];
    }

    //double time = MAXFLOAT;
    //[self.audioPlayer seekToTime: CMTimeMakeWithSeconds(time, NSEC_PER_SEC) completionHandler:^(BOOL finished) {
#ifdef VERBOSE_STREAM_LOGGING
    [self dump:NO];
#endif
    [self.audioPlayer seekToDate:[self maxSeekableDate] completionHandler:^(BOOL finished) {
        [self.audioPlayer play];

        if ([self.delegate respondsToSelector:@selector(onSeekCompleted)]) {
            [self.delegate onSeekCompleted];
        }
    }];
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
        [[NSNotificationCenter defaultCenter] removeObserver:self.playerItem forKeyPath:AVPlayerItemDidPlayToEndTimeNotification];
    } @catch (NSException *exception) {
        // Wasn't necessary
        NSLog(@"Exception - failed to remove AVPlayerItemDidPlayToEndTimeNotification");
    }

    if ( ![[QueueManager shared]isQueueEmpty] ) {
        [[QueueManager shared] playNext];
    } else {
        [self takedownAudioPlayer];
        [self buildStreamer:kHLSLiveStreamURL];
        [self startStream];
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

- (void)startStream {
    if (!self.audioPlayer) {
        [self buildStreamer:kHLSLiveStreamURL];
    }
    
    [self.audioPlayer play];
    
    self.status = StreamStatusPlaying;
}

- (void)pauseStream {
    [self.audioPlayer pause];
    self.status = StreamStatusPaused;
}

- (void)stopStream {
    [self takedownAudioPlayer];
    self.status = StreamStatusStopped;
}

- (void)stopAllAudio {
    [self stopStream];

    if (self.localAudioPlayer && self.localAudioPlayer.isPlaying) {
        [self.localAudioPlayer stop];
    }
}

- (void)adjustAudioWithValue:(CGFloat)increment completion:(void (^)(void))completion {
    if ( increment < 0.0 ) {
        self.savedVolume = self.audioPlayer.volume;
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

    //NSLog(@"Player Volume : %1.1f",self.audioPlayer.volume);
    
    if ( basecase ) {
        if ( increasing ) {
            self.audioPlayer.volume = self.savedVolume;
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


- (void)takedownAudioPlayer {
    [self.audioPlayer pause];

    if (self.timeObserver) {
        [self.audioPlayer removeTimeObserver:self.timeObserver];
        self.timeObserver = nil;
    }

    @try {
        [self.audioPlayer removeObserver:self forKeyPath:@"rate"];
        [self.audioPlayer removeObserver:self forKeyPath:@"status"];
        [self.playerItem removeObserver:self forKeyPath:@"status"];
        [self.playerItem removeObserver:self forKeyPath:@"playbackBufferEmpty"];
        [self.playerItem removeObserver:self forKeyPath:@"playbackLikelyToKeepUp"];
        [self.playerItem removeObserver:self forKeyPath:AVPlayerItemDidPlayToEndTimeNotification];
        [self.playerItem removeObserver:self forKeyPath:AVPlayerItemFailedToPlayToEndTimeNotification];
    } @catch (NSException *e) {
        // Wasn't necessary
    }

    
    self.audioPlayer = nil;
    self.playerItem = nil;
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
    
    NSLog(@"currentDate : %@",[self.audioPlayer.currentItem.currentDate prettyTimeString]);
    NSDate *msd = [self maxSeekableDate];
    NSLog(@" ******* MAX SEEKABLE DATE : %@ *******",msd);
    NSDate *minSd = [self minSeekableDate];
    NSLog(@" ******* MIN SEEKABLE DATE : %@ *******",minSd);
    
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
            [self localAudioFallback:[[NSBundle mainBundle] pathForResource:kFailedConnectionAudioFile ofType:@"mp3"]];
            if ([self.delegate respondsToSelector:@selector(handleUIForFailedConnection)]) {
                [self.delegate handleUIForFailedConnection];
            }
            [[AnalyticsManager shared] failStream:StreamStateLostConnectivity comments:comments];
            break;
        
        case NetworkHealthServerDown:
            [self localAudioFallback:[[NSBundle mainBundle] pathForResource:kFailedStreamAudioFile ofType:@"mp3"]];
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
