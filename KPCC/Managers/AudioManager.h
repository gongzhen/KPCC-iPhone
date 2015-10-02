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

#import "KPCC-Swift.h"


#ifdef SHORTENED_BUFFER
static long kStreamBufferLimit = 1*60;
static long kStreamCorrectionTolerance = 60*5;
#else
static long kStreamBufferLimit = 4*60*60;
static long kStreamCorrectionTolerance = 60*5;
#endif

#define kLargeSkipInterval [[SessionManager shared] peakDrift]
#define kSmallSkipInterval 10.0
#define kHLS [[AudioManager shared] streamingURL]
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
- (void)onTimeChange;
- (void)onRateChange;
- (void)onSeekCompleted;
- (void)interfere;
- (void)onDemandAudioFailed;
- (void)onDemandSeekCompleted;
- (void)restoreUIIfNeeded;

@end

#define kPreferredPeakBitRateTolerance 1000
#define kImpatientWaitingTolerance 20.0
#define kGiveUpTolerance 10.0
#define kBookmarkingTolerance 10

@interface AudioManager : NSObject

+ (AudioManager*)shared;

@property (readwrite, unsafe_unretained) id<AudioManagerDelegate> delegate;

@property AudioPlayer *audioPlayer;

@property NSString *avSessionId;
@property AVStatus *status;
@property NowPlayingManager *nowPlaying;

//@property StreamStatus status;

@property (nonatomic,copy) NSString *xfsStreamUrl;
@property (nonatomic,copy) NSDate *xfsDriveStart;
@property (nonatomic,copy) NSDate *xfsDriveEnd;

@property (strong,nonatomic) NSDateFormatter *dateFormatter;
@property (nonatomic,strong) NSOperationQueue *fadeQueue;

@property CGFloat savedVolume;
@property CGFloat savedVolumeFromMute;

@property BOOL tryAgain;
@property BOOL dropoutOccurred;
@property BOOL seekWillAffectBuffer;
@property BOOL smooth;
@property BOOL userPause;
@property BOOL appGaveUp;
@property BOOL audioOutputSourceChanging;


@property UIBackgroundTaskIdentifier rescueTask;

@property NSInteger failoverCount;

@property (nonatomic, copy) NSString *previousUrl;

@property NSInteger onboardingSegment;
@property (nonatomic) AudioMode currentAudioMode;

- (NSString*)streamingURL;

- (void)playQueueItem:(AudioChunk*)chunk;
- (void)playLiveStream;

- (void)playAudio;
- (void)pauseAudio;
- (void)stopAllAudio;
- (void)stopAudio;
- (void)muteAudio;
- (void)switchPlusMinusStreams;
- (void)finishSwitchPlusMinus;
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

@property (NS_NONATOMIC_IOSONLY, getter=isStreamPlaying, readonly) BOOL streamPlaying;
@property (NS_NONATOMIC_IOSONLY, getter=isStreamBuffering, readonly) BOOL streamBuffering;

@property BOOL ignoreDriftTolerance;
@property BOOL calibrating;

@property (nonatomic, copy) NSString *reasonToReportError;

@property NSTimeInterval newPositionDelta;

@property (nonatomic, strong) NSTimer *kickstartTimer;
@property (nonatomic, strong) NSTimer *giveupTimer;
@property (nonatomic, strong) NSTimer *waitForLogTimer;

- (void)seekToPercent:(CGFloat)percent;

- (void)recalibrateAfterScrub;

- (void)forwardSeekLiveWithType:(NSInteger)type completion:(CompletionBlock)completion;
- (void)forwardSeekThirtySecondsWithCompletion:(CompletionBlock)completion;
- (void)backwardSeekThirtySecondsWithCompletion:(CompletionBlock)completion;
- (void)seekToDate:(NSDate*)date completion:(CompletionBlock)completion;
- (void)intervalSeekWithTimeInterval:(NSTimeInterval)interval completion:(CompletionBlock)completion;

- (void)backwardSeekToBeginningOfProgram;

- (void)adjustAudioWithValue:(CGFloat)increment completion:(void (^)(void))completion;
- (void)threadedAdjustWithValue:(CGFloat)increment completion:(void (^)(void))completion;
- (void)takedownAudioPlayer;
- (void)resetPlayer;
- (void)resetFlags;

- (BOOL)isPlayingAudio;
- (BOOL)isActiveForAudioMode:(AudioMode)mode;

- (void)loadXfsStreamUrlWithCompletion:(CompletionBlock)completion;

- (NSString*)avPlayerSessionString;

#ifdef DEBUG
@property long frame;
@property (nonatomic,strong) NSDate *previousCD;
@property (nonatomic, strong) NSTimer *multipurposeTimer;

#endif

@end
