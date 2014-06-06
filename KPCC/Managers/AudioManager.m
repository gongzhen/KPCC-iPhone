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

static AudioManager *singleton = nil;

@implementation AudioManager

+ (AudioManager*)shared {
    if ( !singleton ) {
        @synchronized(self) {
            singleton = [[AudioManager alloc] init];
            [singleton buildStreamer];
        }
    }
    
    return singleton;
}

- (void)buildStreamer {
#ifdef HLS_SUPPORT
    self.audioPlayer = [AVPlayer playerWithURL:[NSURL URLWithString:kHLSLiveStreamURL]];
#else
    self.audioPlayer = [[STKAudioPlayer alloc]init];
    self.audioPlayer.delegate = self;
    self.audioPlayer.meteringEnabled = YES;
#endif
    
}

- (NSString *)liveStreamURL {

#ifdef HLS_SUPPORT
    return kHLSLiveStreamURL;
#else

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
#endif
}

- (void)startStream {
#ifdef HLS_SUPPORT
    [self.audioPlayer play];
    
#else
    self.audioDataSource = [STKAudioPlayer dataSourceFromURL:[NSURL URLWithString:[self liveStreamURL]]];

    if ([[self liveStreamURL] isEqualToString:kLiveStreamAACURL]) {
        SCPRDebugLog(@"Setting lastPreRoll to now");
        self.lastPreRoll = [[NSDate date] timeIntervalSince1970];
    }

    [self.audioPlayer playDataSource:self.audioDataSource];
#endif
}

- (void)stopStream {
#ifdef HLS_SUPPORT
    [self.audioPlayer setRate:0.0];
#else
    [self.audioPlayer stop];
#endif
}

- (void)stopAllAudio {
    [self stopStream];

    if (self.localAudioPlayer && self.localAudioPlayer.isPlaying) {
        [self.localAudioPlayer stop];
    }
}

- (BOOL)isStreamPlaying {
#ifdef HLS_SUPPORT
    if ([self.audioPlayer rate] > 0.0) {
        return YES;
    } else {
        return NO;
    }
#else
    if (self.audioPlayer && self.audioPlayer.state == STKAudioPlayerStatePlaying) {
        return YES;
    } else {
        return NO;
    }
#endif
}

- (BOOL)isStreamBuffering {
#ifdef HLS_SUPPORT
    return NO;
#else
    if (self.audioPlayer && self.audioPlayer.state == STKAudioPlayerStateBuffering) {
        return YES;
    } else {
        return NO;
    }
#endif
}

- (NSString *)stringFromSTKAudioPlayerState:(STKAudioPlayerState)state {
    switch (state) {
        case STKAudioPlayerStatePlaying:
            return @"playing";
            break;

        case STKAudioPlayerStateBuffering:
            return @"buffering";
            break;

        case STKAudioPlayerStateDisposed:
            return @"disposed";
            break;

        case STKAudioPlayerStatePaused:
            return @"paused";
            break;

        case STKAudioPlayerStateReady:
            return @"ready";
            break;

        case STKAudioPlayerStateRunning:
            return @"running";
            break;

        case STKAudioPlayerStateStopped:
            return @"stopped";
            break;

        case STKAudioPlayerStateError:
            return @"error";
            break;

        default:
            return nil;
            break;
    }
    return nil;
 }


#pragma mark - Error Logging

- (void)analyzeStreamError:(NSString *)comments {
    
    NSURL *liveURL = [NSURL URLWithString:kLiveStreamAACURL];
    NetworkHealth netHealth = [[NetworkManager shared] checkNetworkHealth:[liveURL host]];

    switch (netHealth) {
        case NetworkHealthAllOK:
            if (![self isStreamPlaying] && ![self isStreamBuffering]) {
                [[AnalyticsManager shared] failStream:StreamStateUnknown comments:comments];
            }
            break;
            
        case NetworkHealthNetworkDown:
            [[AnalyticsManager shared] failStream:StreamStateLostConnectivity comments:comments];
            break;
        
        case NetworkHealthServerDown:
            [[AnalyticsManager shared] failStream:StreamStateServerFail comments:comments];
            break;
            
        default:
            [[AnalyticsManager shared] failStream:StreamStateUnknown comments:comments];
            break;
    }
}

#pragma mark - STKAudioPlayerDelegate protocol implementation

- (void)audioPlayer:(STKAudioPlayer *)audioPlayer stateChanged:(STKAudioPlayerState)state previousState:(STKAudioPlayerState)previousState {
    SCPRDebugLog();

    [[NSNotificationCenter defaultCenter] postNotificationName:@"STKAudioPlayerStateNotification" object:nil];
    
    // Log stream error -- currentState: buffering -- previousState: playing
    if (state == STKAudioPlayerStateBuffering && previousState == STKAudioPlayerStatePlaying) {
        SCPRDebugLog(@"BUFFERING, WAS PLAYING");
        [self analyzeStreamError:nil];
        
        // Setup the local file audio player, play respective failure sounds depending on error.
        NSString *localAudioFilePath;
        if ([[NetworkManager shared] checkNetworkHealth:[[NSURL URLWithString:kLiveStreamAACURL] host]] == NetworkHealthServerDown) {
            localAudioFilePath = [[NSBundle mainBundle] pathForResource:kFailedStreamAudioFile ofType:@"mp3"];

            if ([self.delegate respondsToSelector:@selector(handleUIForFailedStream)]) {
                [self.delegate handleUIForFailedStream];
            }
        } else {
            localAudioFilePath = [[NSBundle mainBundle] pathForResource:kFailedConnectionAudioFile ofType:@"mp3"];

            if ([self.delegate respondsToSelector:@selector(handleUIForFailedConnection)]) {
                [self.delegate handleUIForFailedConnection];
            }
        }
        
        // Init the local audio player, set to loop indefinitely, and play.
        self.localAudioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:localAudioFilePath] error:nil];
        self.localAudioPlayer.numberOfLoops = -1;
        [self.localAudioPlayer play];
    }
    
    // If recovering from stream failure, cancel playing of local audio file
    if (state == STKAudioPlayerStatePlaying && self.localAudioPlayer && self.localAudioPlayer.isPlaying) {
        [self.localAudioPlayer stop];

        if ([self.delegate respondsToSelector:@selector(handleUIForRecoveredStream)]) {
            [self.delegate handleUIForRecoveredStream];
        }
    }
}

- (void)audioPlayer:(STKAudioPlayer*)audioPlayer unexpectedError:(STKAudioPlayerErrorCode)errorCode {
    SCPRDebugLog();
    
    NSString *errorCodeString;
    switch (errorCode) {
        case STKAudioPlayerErrorAudioSystemError:
            errorCodeString = @"STKAudioPlayerErrorAudioSystemError";
            break;

        case STKAudioPlayerErrorCodecError:
            errorCodeString = @"STKAudioPlayerErrorCodecError";
            break;

        case STKAudioPlayerErrorDataNotFound:
            errorCodeString = @"STKAudioPlayerErrorDataNotFound";
            break;

        case STKAudioPlayerErrorDataSource:
            errorCodeString = @"STKAudioPlayerErrorDataSource";
            break;

        case STKAudioPlayerErrorStreamParseBytesFailed:
            errorCodeString = @"STKAudioPlayerErrorStreamParseBytesFailed";
            break;

        case STKAudioPlayerErrorOther:
            errorCodeString = @"STKAudioPlayerErrorOther";
            break;

        case STKAudioPlayerErrorNone:
            errorCodeString = @"STKAudioPlayerErrorNone";
            break;

        default:
            errorCodeString = @"STKAudioPlayerErrorUnknownCode";
            break;
    }
    
    [self analyzeStreamError:errorCodeString];
}

- (void)audioPlayer:(STKAudioPlayer *)audioPlayer didStartPlayingQueueItemId:(NSObject *)queueItemId {
    SCPRDebugLog();

    [[AnalyticsManager shared] logEvent:@"streamStartedPlaying" withParameters:nil];
}
- (void)audioPlayer:(STKAudioPlayer *)audioPlayer logInfo:(NSString *)line {
    SCPRDebugLog();

    [[AnalyticsManager shared] logEvent:@"audioPlayerLogItem" withParameters:@{@"event": line}];
}

- (void)audioPlayer:(STKAudioPlayer *)audioPlayer didFinishBufferingSourceWithQueueItemId:(NSObject *)queueItemId {
    SCPRDebugLog();
}
- (void)audioPlayer:(STKAudioPlayer *)audioPlayer didFinishPlayingQueueItemId:(NSObject *)queueItemId withReason:(STKAudioPlayerStopReason)stopReason andProgress:(double)progress andDuration:(double)duration {
    SCPRDebugLog();
}

#pragma mark - STKDataSourceDelegate protocol implementation

-(void) dataSourceDataAvailable:(STKDataSource*)dataSource {
    SCPRDebugLog();
}

-(void) dataSourceErrorOccured:(STKDataSource*)dataSource {
    SCPRDebugLog();
}

-(void) dataSourceEof:(STKDataSource*)dataSource {
    SCPRDebugLog();
}

@end
