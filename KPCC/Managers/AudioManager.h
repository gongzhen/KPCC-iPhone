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


#ifdef SHORTENED_BUFFER
static long kStreamBufferLimit = 1*60;
static long kStreamCorrectionTolerance = 60*5;
#else
static long kStreamBufferLimit = 4*60*60;
static long kStreamCorrectionTolerance = 60*5;
#endif

#define kLargeSkipInterval [[SessionManager shared] peakDrift]
#define kSmallSkipInterval 10.0
#define kHLS [[AudioManager shared] standardHlsStream]
#define kLiveStreamPreRollThreshold 3600
#define kFailedConnectionAudioFile @"Wood_Crash"
#define kFailedStreamAudioFile @"Glass_Crash"

#ifdef DEBUG
#	define SCPRDebugLog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
#else
#	define SCPRDebugLog(...)
#endif

@class AudioChunk;

typedef NS_ENUM(NSUInteger, AudioMode) {
    AudioModeNeutral = 0,
    AudioModeLive,
    AudioModeOnDemand,
    AudioModeOnboarding,
    AudioModePreroll
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
- (void)onDemandSeekCompleted;
- (void)restoreUIIfNeeded;

@end

#define kPreferredPeakBitRateTolerance 1000
#define kImpatientWaitingTolerance 15.0
#define kGiveUpTolerance 15.0
#define kBookmarkingTolerance 10

@interface AudioManager : NSObject<AVAssetResourceLoaderDelegate>

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
@property Float64 onDemandSeekPosition;

@property BOOL seekRequested;
@property BOOL bufferMutex;
@property BOOL waitForFirstTick;
@property BOOL autoMuted;
@property BOOL temporaryMutex;
@property BOOL easeInAudio;
@property BOOL waitForSeek;
@property BOOL waitForOnDemandSeek;
@property BOOL prerollPlaying;
@property BOOL tryAgain;
@property BOOL dumpedOnce;
@property BOOL recoveryGateOpen;
@property BOOL loggingGateOpen;
@property BOOL reactivate;
@property BOOL dropoutOccurred;
@property BOOL seekWillEffectBuffer;
@property BOOL streamStabilized;
@property BOOL smooth;
@property BOOL userPause;
@property BOOL waitingForRecovery;
@property BOOL beginNormally;
@property BOOL bufferEmpty;
@property BOOL streamWarning;
@property BOOL appGaveUp;
@property BOOL audioOutputSourceChanging;

@property (nonatomic, strong) NSMutableDictionary *localBufferSample;

@property UIBackgroundTaskIdentifier rescueTask;

@property NSInteger failoverCount;

@property (nonatomic, copy) NSString *previousUrl;
@property (nonatomic, strong) NSDate *queuedSeekDate;

@property NSInteger onboardingSegment;
@property (nonatomic) AudioMode currentAudioMode;

- (NSString*)standardHlsStream;
- (NSString*)streamingURL:(BOOL)hls preskip:(BOOL)preskip mp3:(BOOL)mp3;

- (void)playQueueItemWithUrl:(NSString *)url;
- (void)playQueueItem:(AudioChunk*)chunk;
- (void)playLiveStream;

@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString *liveStreamURL;
- (void)startStream;
- (void)playAudio;
- (void)pauseAudio;
- (void)stopAllAudio;
- (void)stopAudio;
- (void)muteAudio;
- (void)switchPlusMinusStreams;
- (void)unmuteAudio;
- (void)buildStreamer:(NSString*)urlString;
- (void)buildStreamer:(NSString*)urlString local:(BOOL)local;
- (void)printStatus;
- (void)playOnboardingAudio:(NSInteger)segment;
- (void)sanitizeFromOnboarding;

// Recovery
- (void)waitPatiently;
- (void)attemptToRecover;
- (void)interruptAutorecovery;
- (void)stopWaiting;
- (void)localSample:(CMTime)time;

@property (NS_NONATOMIC_IOSONLY, getter=isStreamPlaying, readonly) BOOL streamPlaying;
@property (NS_NONATOMIC_IOSONLY, getter=isStreamBuffering, readonly) BOOL streamBuffering;

@property (NS_NONATOMIC_IOSONLY, readonly) double indicatedBitrate;
@property (NS_NONATOMIC_IOSONLY, readonly) double observedMaxBitrate;
@property (NS_NONATOMIC_IOSONLY, readonly) double observedMinBitrate;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString *currentDateTimeString;

@property NSInteger frameCount;

@property BOOL audioCheating;
@property BOOL ignoreDriftTolerance;
@property BOOL calibrating;
@property BOOL failureGate;

@property BOOL playerNeedsToSeekToLive;
@property BOOL playerNeedsToSeekGenerally;
@property NSTimeInterval queuedTimeInterval;
@property NSInteger queuedSeekType;
@property (nonatomic, copy) CompletionBlock queuedCompletion;

@property (nonatomic, copy) NSString *reasonToReportError;

@property NSInteger skipCount;

@property NSTimeInterval newPositionDelta;

@property (nonatomic, strong) NSTimer *kickstartTimer;
@property (nonatomic, strong) NSTimer *giveupTimer;
@property (nonatomic, strong) NSTimer *waitForLogTimer;

@property (nonatomic, copy) NSDate *seekTargetReferenceDate;

- (void)updateNowPlayingInfoWithAudio:(id)audio;

- (void)seekToPercent:(CGFloat)percent;

/*
- (void)seekToDate:(NSDate *)date;
- (void)seekToDate:(NSDate *)date forward:(BOOL)forward failover:(BOOL)failover;
- (void)specialSeekToDate:(NSDate*)date;*/

- (void)recalibrateAfterScrub;

- (void)forwardSeekLiveWithType:(NSInteger)type completion:(CompletionBlock)completion;
- (void)forwardSeekThirtySecondsWithCompletion:(CompletionBlock)completion;
- (void)backwardSeekThirtySecondsWithCompletion:(CompletionBlock)completion;
- (void)seekToDate:(NSDate*)date completion:(CompletionBlock)completion;
- (void)intervalSeekWithTimeInterval:(NSTimeInterval)interval completion:(CompletionBlock)completion;
- (void)finishIntervalSeek:(NSTimeInterval)interval completion:(CompletionBlock)completion;
- (void)finishSeekToLive;

- (void)backwardSeekToBeginningOfProgram;

- (void)forwardSeekFifteenSecondsWithCompletion:(CompletionBlock)completion;
- (void)backwardSeekFifteenSecondsWithCompletion:(CompletionBlock)completion;

- (void)analyzeStreamError:(NSString*)comments;
- (void)adjustAudioWithValue:(CGFloat)increment completion:(void (^)(void))completion;
- (void)threadedAdjustWithValue:(CGFloat)increment completion:(void (^)(void))completion;
- (void)takedownAudioPlayer;
- (void)resetPlayer;

- (BOOL)isPlayingAudio;
- (BOOL)isActiveForAudioMode:(AudioMode)mode;
- (void)invalidateTimeObserver;
- (void)startObservingTime;

- (NSString*)avPlayerSessionString;
- (NSDate*)cookDateForActualSchedule:(NSDate*)date;

#ifdef DEBUG
@property long frame;
@property (nonatomic,strong) NSDate *previousCD;
- (void)dump:(BOOL)superVerbose;
- (void)streamFrame;
@property (nonatomic, strong) NSTimer *multipurposeTimer;

#endif

@end
