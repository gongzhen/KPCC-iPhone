//
//  AudioManager.m
//  KPCC
//
//  Created by John Meeker on 3/6/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "AudioManager.h"

static AudioManager *singleton = nil;

@implementation AudioManager

+ (AudioManager*)shared {
    if ( !singleton ) {
        @synchronized(self) {
            singleton = [[AudioManager alloc] init];
            [singleton buildStreamer:kLiveStreamURL];
        }
    }
    
    return singleton;
}

- (void)buildStreamer:(NSString*)urlForStream {
    
    if ( !urlForStream ) {
        urlForStream = kLiveStreamURL;
    }
    self.streamPlaying = NO;
    self.audioPlayer = [[STKAudioPlayer alloc]init];
    self.audioDataSource = [STKAudioPlayer dataSourceFromURL:[NSURL URLWithString:urlForStream]];
    //self.audioDataSource = [STKAudioPlayer]
}

- (void)startStream {    
    [self.audioPlayer setDataSource:self.audioDataSource withQueueItemId:nil];

    //[self.audioPlayer resume];
    self.streamPlaying = YES;

    NSDictionary *audioMetaData = @{ MPMediaItemPropertyArtist : @"89.3 KPCC",
                                     MPMediaItemPropertyTitle : @"Live" };
    
    [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:audioMetaData];
}

- (void)stopStream {
    [self.audioPlayer stop];
    self.streamPlaying = NO;
    
    NSDictionary *audioMetaData = @{ MPMediaItemPropertyArtist : @"89.3 KPCC",
                                     MPMediaItemPropertyTitle : @"---" };
    
    [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:audioMetaData];
}


#pragma mark - STKAudioPlayerDelegate
- (void)audioPlayer:(STKAudioPlayer *)audioPlayer stateChanged:(STKAudioPlayerState)state previousState:(STKAudioPlayerState)previousState {
    NSLog(@"stateChanged: %i", state);
    
    if (state == STKAudioPlayerStateError) {
        NSLog(@"STKAudioPlayerStateError");
        //[self playNextStream];
    }
}

- (void)audioPlayer:(STKAudioPlayer*)audioPlayer unexpectedError:(STKAudioPlayerErrorCode)errorCode {
    NSLog(@"unexpectedError: %i", errorCode);
    
    if (errorCode == STKAudioPlayerErrorDataNotFound) {
        NSLog(@"STKAudioPlayerErrorDataNotFound");
        //[self playNextStream];
    }
}

- (void)audioPlayer:(STKAudioPlayer *)audioPlayer didStartPlayingQueueItemId:(NSObject *)queueItemId {}
- (void)audioPlayer:(STKAudioPlayer *)audioPlayer didFinishBufferingSourceWithQueueItemId:(NSObject *)queueItemId {}
- (void)audioPlayer:(STKAudioPlayer *)audioPlayer didFinishPlayingQueueItemId:(NSObject *)queueItemId withReason:(STKAudioPlayerStopReason)stopReason andProgress:(double)progress andDuration:(double)duration {}

@end
