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
    AudioModeNeutral = 0,
    AudioModeLive,
    AudioModeOnDemand,
    AudioModeOnboarding
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
- (void)interfere;
- (void)onDemandAudioFailed;
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
@property NSDate *relativeFauxDate;

@property long latencyCorrection;

@property (strong,nonatomic) NSDateFormatter *dateFormatter;
@property (nonatomic,strong) NSOperationQueue *fadeQueue;
@property long bufferObservationCount;

@property CGFloat savedVolume;
@property CGFloat savedVolumeFromMute;
@property BOOL bufferMutex;
@property BOOL waitForFirstTick;
@property BOOL autoMuted;
@property BOOL temporaryMutex;
@property BOOL easeInAudio;
@property BOOL waitForSeek;

@property (nonatomic, copy) NSString *previousUrl;
@property (nonatomic, strong) NSDate *queuedSeekDate;

@property NSInteger onboardingSegment;
@property AudioMode currentAudioMode;

- (void)playAudioWithURL:(NSString *)url;
- (void)playQueueItemWithUrl:(NSString *)url;
- (void)playLiveStream;

@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString *liveStreamURL;
- (void)startStream;
- (void)playStream;
- (void)pauseStream;
- (void)stopStream;
- (void)stopAllAudio;
- (void)muteAudio;
- (void)unmuteAudio;
- (void)buildStreamer:(NSString*)urlString;
- (void)buildStreamer:(NSString*)urlString local:(BOOL)local;

- (void)playOnboardingAudio:(NSInteger)segment;
- (void)sanitizeFromOnboarding;

@property (NS_NONATOMIC_IOSONLY, getter=isStreamPlaying, readonly) BOOL streamPlaying;
@property (NS_NONATOMIC_IOSONLY, getter=isStreamBuffering, readonly) BOOL streamBuffering;

@property (NS_NONATOMIC_IOSONLY, readonly) double indicatedBitrate;
@property (NS_NONATOMIC_IOSONLY, readonly) double observedMaxBitrate;
@property (NS_NONATOMIC_IOSONLY, readonly) double observedMinBitrate;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString *currentDateTimeString;

@property BOOL audioCheating;

- (void)updateNowPlayingInfoWithAudio:(id)audio;

- (void)seekToPercent:(CGFloat)percent;
- (void)seekToDate:(NSDate *)date;
- (void)seekToDate:(NSDate *)date forward:(BOOL)forward failover:(BOOL)failover;
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
- (void)resetPlayer;

- (void)cheatPlay;

- (NSDate*)cookDateForActualSchedule:(NSDate*)date;

#ifdef DEBUG
@property long frame;
@property (nonatomic,strong) NSDate *previousCD;
- (void)dump:(BOOL)superVerbose;
- (void)streamFrame;
#endif

@end
