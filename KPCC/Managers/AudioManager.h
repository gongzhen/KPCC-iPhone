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

#define kLiveStreamURL @"http://live.scpr.org/kpcclive"
#define kLiveStreamNoPreRollURL @"http://live.scpr.org/kpcclive?preskip=true"
#define kLiveStreamAACURL @"http://live.scpr.org/aac"
#define kLiveStreamAACNoPreRollURL @"http://live.scpr.org/aac?preskip=true"
#define kLiveStreamPreRollThreshold 600


@interface AudioManager : NSObject<STKAudioPlayerDelegate>

+ (AudioManager*)shared;

@property STKAudioPlayer* audioPlayer;
@property STKDataSource *audioDataSource;

@property long lastPreRoll;

- (void)startStream;
- (void)stopStream;
- (BOOL)isStreamPlaying;

- (void)analyzeStreamError:(NSString*)comments;

@end
