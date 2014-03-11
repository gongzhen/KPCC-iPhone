//
//  AudioManager.h
//  KPCC
//
//  Created by John Meeker on 3/6/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "STKAudioPlayer.h"

#define kLiveStreamURL @"http://live.scpr.org/kpcclive?preskip=true"

@interface AudioManager : NSObject<STKAudioPlayerDelegate>

+ (AudioManager*)shared;

@property STKAudioPlayer *audioPlayer;
@property STKDataSource *audioDataSource;

@property BOOL streamPlaying;

- (void)startStream;
- (void)stopStream;

@end
