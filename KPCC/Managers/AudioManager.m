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
    self.audioPlayer = [AVPlayer playerWithURL:[NSURL URLWithString:kHLSLiveStreamURL]];
}

- (NSString *)liveStreamURL {
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
}

- (void)startStream {
    [self.audioPlayer play];
}

- (void)stopStream {
    [self.audioPlayer setRate:0.0];
}

- (void)stopAllAudio {
    [self stopStream];

    if (self.localAudioPlayer && self.localAudioPlayer.isPlaying) {
        [self.localAudioPlayer stop];
    }
}

- (BOOL)isStreamPlaying {
    if ([self.audioPlayer rate] > 0.0) {
        return YES;
    } else {
        return NO;
    }
}

- (BOOL)isStreamBuffering {
    return NO;
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
