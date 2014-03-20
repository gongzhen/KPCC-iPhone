//
//  AudioManager.m
//  KPCC
//
//  Created by John Meeker on 3/6/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "AudioManager.h"
#import "NetworkManager.h"

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
    self.streamPlaying = NO;
    self.audioPlayer = [[STKAudioPlayer alloc]init];
    self.audioPlayer.meteringEnabled = YES;
}

- (void)startStream {
    long currentTimeSeconds = [[NSDate date] timeIntervalSince1970] / 1000;
    if (self.lastPreRoll < (currentTimeSeconds - kLiveStreamPreRollThreshold)) {
        self.lastPreRoll = currentTimeSeconds;
        self.audioDataSource = [STKAudioPlayer dataSourceFromURL:[NSURL URLWithString:kLiveStreamAACURL]];
    } else {
        self.audioDataSource = [STKAudioPlayer dataSourceFromURL:[NSURL URLWithString:kLiveStreamAACNoPreRollURL]];
    }
    
    [self.audioPlayer playDataSource:self.audioDataSource];

    self.streamPlaying = YES;
}

- (void)stopStream {
    [self.audioPlayer pause];
    self.streamPlaying = NO;
}


#pragma mark - Error Logging
- (void)analyzeStreamError:(NSString *)comments {
    
    NSURL *liveURL = [NSURL URLWithString:kLiveStreamURL];
    NetworkHealth netHealth = [[NetworkManager shared] checkNetworkHealth:[liveURL host]];
    if ( NetworkHealthNetworkDown == netHealth ) {
        //[self failStream:StreamStateLostConnectivity comments:comments];
    } else if ( NetworkHealthServerDown == netHealth ) {
        //[self failStream:StreamStateServerFail comments:comments];
    } else {
        //[self failStream:StreamStateUnknown comments:comments];
    }
    
    NSLog(@"Stream error...");
}

#pragma mark - STKAudioPlayerDelegate
- (void)audioPlayer:(STKAudioPlayer *)audioPlayer stateChanged:(STKAudioPlayerState)state previousState:(STKAudioPlayerState)previousState {
    NSLog(@"stateChanged: %i", state);
    
    if (state == STKAudioPlayerStateError) {
        NSLog(@"STKAudioPlayerStateError");
    }
}

- (void)audioPlayer:(STKAudioPlayer*)audioPlayer unexpectedError:(STKAudioPlayerErrorCode)errorCode {
    NSLog(@"unexpectedError: %i", errorCode);
    
    if (errorCode == STKAudioPlayerErrorDataNotFound) {
        NSLog(@"STKAudioPlayerErrorDataNotFound");
    }
}

- (void)audioPlayer:(STKAudioPlayer *)audioPlayer didStartPlayingQueueItemId:(NSObject *)queueItemId {
    NSLog(@"audioPlayer didStartPlaying");
}
- (void)audioPlayer:(STKAudioPlayer *)audioPlayer logInfo:(NSString *)line {
    NSLog(@"audioPlayer LOG - %@", line);
}

- (void)audioPlayer:(STKAudioPlayer *)audioPlayer didFinishBufferingSourceWithQueueItemId:(NSObject *)queueItemId {
    NSLog(@"didFinishBuffering!");
}
- (void)audioPlayer:(STKAudioPlayer *)audioPlayer didFinishPlayingQueueItemId:(NSObject *)queueItemId withReason:(STKAudioPlayerStopReason)stopReason andProgress:(double)progress andDuration:(double)duration {}

@end
