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
        urlForStream =kLiveStreamURL;
    }

    self.audioPlayer = [[STKAudioPlayer alloc]init];
    self.audioDataSource = [STKAudioPlayer dataSourceFromURL:[NSURL URLWithString:urlForStream]];
}

- (void)startStream {
    [self.audioPlayer setDataSource:self.audioDataSource withQueueItemId:nil];
}

- (void)stopStream {
    [self.audioPlayer stop];
}


@end
