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

#define kHLSLiveStreamURL @"http://streammachine-hls001.scprdev.org/sg/kpcc-aac.m3u8"

#define kLiveStreamURL @"http://live.scpr.org/kpcclive"
#define kLiveStreamNoPreRollURL @"http://live.scpr.org/kpcclive?preskip=true"
#define kLiveStreamAACURL @"http://live.scpr.org/aac"
#define kLiveStreamAACNoPreRollURL @"http://live.scpr.org/aac?preskip=true"
#define kLiveStreamPreRollThreshold 3600

#define kFailedConnectionAudioFile @"Wood_Crash"
#define kFailedStreamAudioFile @"Glass_Crash"

#ifdef DEBUG
#	define SCPRDebugLog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
#else
#	define SCPRDebugLog(...)
#endif

typedef enum {
    StreamStateHealthy = 0,
    StreamStateLostConnectivity = 1,
    StreamStateServerFail = 2,
    StreamStateUnknown = 3
} StreamState;

typedef enum {
    StreamStatusStopped = 0,
    StreamStatusPlaying = 1,
    StreamStatusPaused = 2
} StreamStatus;

@protocol AudioManagerDelegate <NSObject>
@optional
- (void)handleUIForFailedConnection;
- (void)handleUIForFailedStream;
- (void)handleUIForRecoveredStream;
- (void)onTimeChange;
@end

@interface AudioManager : NSObject

+ (AudioManager*)shared;

/// Gets and sets the delegate used for receiving events from the AudioManager
@property (readwrite, unsafe_unretained) id<AudioManagerDelegate> delegate;

@property AVPlayer *audioPlayer;
@property AVPlayerItem *playerItem;
@property AVAudioPlayer *localAudioPlayer;

@property StreamStatus status;
@property long lastPreRoll;

@property NSDate *currentDate;
@property NSDate *minSeekableDate;
@property NSDate *maxSeekableDate;

@property (strong,nonatomic) NSDateFormatter *dateFormatter;


- (NSString *)liveStreamURL;
- (void)startStream;
- (void)stopStream;
- (void)stopAllAudio;
- (void)seekToPercent:(CGFloat)percent;
- (BOOL)isStreamPlaying;
- (BOOL)isStreamBuffering;
- (double)indicatedBitrate;
- (double)observedMaxBitrate;
- (double)observedMinBitrate;
- (NSString *)currentDateTimeString;

- (void)analyzeStreamError:(NSString*)comments;




@end
