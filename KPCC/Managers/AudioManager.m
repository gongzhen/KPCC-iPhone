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
//@synthesize audioPlayer;

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
    self.audioPlayer = [[STKAudioPlayer alloc]init];
    self.audioPlayer.delegate = self;
    self.audioPlayer.meteringEnabled = YES;
}

- (void)startStream {
    long currentTimeSeconds = [[NSDate date] timeIntervalSince1970];
    if (self.lastPreRoll < (currentTimeSeconds - kLiveStreamPreRollThreshold)) {
        self.lastPreRoll = currentTimeSeconds;
        self.audioDataSource = [STKAudioPlayer dataSourceFromURL:[NSURL URLWithString:kLiveStreamURL]];
    } else {
        self.audioDataSource = [STKAudioPlayer dataSourceFromURL:[NSURL URLWithString:kLiveStreamNoPreRollURL]];
    }
    
    [self.audioPlayer playDataSource:self.audioDataSource];
}

- (void)stopStream {
    [self.audioPlayer stop];
}

- (BOOL)isStreamPlaying {
    if (self.audioPlayer && self.audioPlayer.state == STKAudioPlayerStatePlaying) {
        return YES;
    } else {
        return NO;
    }
}


#pragma mark - Error Logging
- (void)analyzeStreamError:(NSString *)comments {
    
    NSURL *liveURL = [NSURL URLWithString:kLiveStreamURL];
    NetworkHealth netHealth = [[NetworkManager shared] checkNetworkHealth:[liveURL host]];

    switch (netHealth) {
        case NetworkHealthAllOK:
            if (![self isStreamPlaying] && self.audioPlayer.state != STKAudioPlayerStateBuffering) {
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

#pragma mark - STKAudioPlayerDelegate
- (void)audioPlayer:(STKAudioPlayer *)audioPlayer stateChanged:(STKAudioPlayerState)state previousState:(STKAudioPlayerState)previousState {
    NSLog(@"STKAudioPlayerStateChanged to: %i .... previously: %i", state, previousState);
    
    if (state == STKAudioPlayerStateBuffering && previousState == STKAudioPlayerStatePlaying) {
        // TODO: WIP -- hacky way to restart stream without preroll after recovering from a drop.
        [self startStream];
    }
}

- (void)audioPlayer:(STKAudioPlayer*)audioPlayer unexpectedError:(STKAudioPlayerErrorCode)errorCode {
    NSLog(@"STKAudioPlayer UnexpectedError: %i", errorCode);
    
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
    NSLog(@"audioPlayer didStartPlaying");
    [[AnalyticsManager shared] logEvent:@"streamStartedPlaying" withParameters:nil];
}
- (void)audioPlayer:(STKAudioPlayer *)audioPlayer logInfo:(NSString *)line {
    NSLog(@"audioPlayerLog: %@", line);
    [[AnalyticsManager shared] logEvent:@"audioPlayerLogItem" withParameters:@{@"event": line}];
}

- (void)audioPlayer:(STKAudioPlayer *)audioPlayer didFinishBufferingSourceWithQueueItemId:(NSObject *)queueItemId {}
- (void)audioPlayer:(STKAudioPlayer *)audioPlayer didFinishPlayingQueueItemId:(NSObject *)queueItemId withReason:(STKAudioPlayerStopReason)stopReason andProgress:(double)progress andDuration:(double)duration {}

@end
