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

#ifdef USE_TEST_STREAM
#define kHLSLiveStreamURL @"http://vevoplaylist-live.hls.adaptive.level3.net/vevo/ch1/06/prog_index.m3u8"
#else
#define kHLSLiveStreamURL @"http://streammachine-hls001.scprdev.org/sg/kpcc-aac.m3u8"
#endif

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

typedef NS_ENUM(NSUInteger, AudioMode) {
    AudioModeLive = 0,
    AudioModeOnDemand
};

typedef NS_ENUM(NSUInteger, StreamState) {
    StreamStateHealthy = 0,
    StreamStateLostConnectivity = 1,
    StreamStateServerFail = 2,
    StreamStateUnknown = 3
};

typedef NS_ENUM(NSUInteger, StreamStatus) {
    StreamStatusStopped = 0,
    StreamStatusPlaying = 1,
    StreamStatusPaused = 2
};

@protocol AudioManagerDelegate <NSObject>
@optional
- (void)handleUIForFailedConnection;
- (void)handleUIForFailedStream;
- (void)handleUIForRecoveredStream;
- (void)onTimeChange;
- (void)onRateChange;
- (void)onSeekCompleted;
@end

@interface AudioManager : NSObject

+ (AudioManager*)shared;

@property (readwrite, unsafe_unretained) id<AudioManagerDelegate> delegate;

@property (nonatomic,strong) id timeObserver;

@property AVPlayer *audioPlayer;
@property AVPlayerItem *playerItem;
@property AVAudioPlayer *localAudioPlayer;

@property StreamStatus status;
@property long lastPreRoll;

@property NSDate *currentDate;
@property NSDate *minSeekableDate;
@property NSDate *maxSeekableDate;
@property NSDate *requestedSeekDate;

@property long latencyCorrection;

@property (strong,nonatomic) NSDateFormatter *dateFormatter;
@property (nonatomic,strong) NSOperationQueue *fadeQueue;
@property long bufferObservationCount;

@property CGFloat savedVolume;
@property BOOL bufferMutex;

@property AudioMode currentAudioMode;

- (void)playAudioWithURL:(NSString *)url;
- (void)playQueueItemWithUrl:(NSString *)url;

- (NSString *)liveStreamURL;
- (void)startStream;
- (void)pauseStream;
- (void)stopStream;
- (void)stopAllAudio;
- (BOOL)isStreamPlaying;
- (BOOL)isStreamBuffering;

- (double)indicatedBitrate;
- (double)observedMaxBitrate;
- (double)observedMinBitrate;
- (NSString *)currentDateTimeString;
- (void)updateNowPlayingInfoWithAudio:(id)audio;

- (void)seekToPercent:(CGFloat)percent;
- (void)seekToDate:(NSDate *)date;
- (void)specialSeekToDate:(NSDate*)date;

- (void)forwardSeekLive;
- (void)forwardSeekThirtySeconds;
- (void)backwardSeekThirtySeconds;
- (void)forwardSeekFifteenSeconds;
- (void)backwardSeekFifteenSeconds;

- (void)analyzeStreamError:(NSString*)comments;
- (void)adjustAudioWithValue:(CGFloat)increment completion:(void (^)(void))completion;
- (void)threadedAdjustWithValue:(CGFloat)increment completion:(void (^)(void))completion;
- (void)takedownAudioPlayer;

- (NSDate*)cookDateForActualSchedule:(NSDate*)date;

#ifdef DEBUG
@property long frame;
@property (nonatomic,strong) NSDate *previousCD;
- (void)dump:(BOOL)superVerbose;
- (void)streamFrame;
#endif

@end
