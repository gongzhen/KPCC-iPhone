//
//  AudioManager.h
//  KPCC
//
//  Created by John Meeker on 3/6/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import "STKAudioPlayer.h"
#import "STKHTTPDataSource.h"

#define kLiveStreamURL @"http://live.scpr.org/kpcclive?preskip=true"
#define kLiveStreamAACURL @"http://live.scpr.org/aac"


@interface AudioManager : NSObject<STKAudioPlayerDelegate>

+ (AudioManager*)shared;

@property STKAudioPlayer *audioPlayer;
@property STKDataSource *audioDataSource;

@property BOOL streamPlaying;

- (void)startStream;
- (void)stopStream;

@end
