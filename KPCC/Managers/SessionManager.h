//
//  SessionManager.h
//  KPCC
//
//  Created by Ben Hochberg on 11/4/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Utils.h"
#import "Program.h"

typedef NS_ENUM(NSUInteger, OnDemandFinishedReason) {
    OnDemandFinishedReasonEpisodeEnd = 0,
    OnDemandFinishedReasonEpisodeSkipped,
    OnDemandFinishedReasonEpisodePaused
};

typedef NS_ENUM(NSUInteger, PauseExplanation) {
    PauseExplanationUnknown = 0,
    PauseExplanationAudioInterruption = 1,
    PauseExplanationAppIsTerminatingSession = 2,
    PauseExplanationUserHasPausedExplicitly = 3,
    PauseExplanationAppIsRespondingToPush = 4
};

static NSInteger kAllowableDriftCeiling = 180;
static NSInteger kToleratedIncreaseInDrift = 20;
static CGFloat kVirtualBehindLiveTolerance = 10.0f;
static CGFloat kVirtualMediumBehindLiveTolerance = 24.0f;
static CGFloat kVirtualLargeBehindLiveTolerance = 120.0f;

#ifndef PRODUCTION
static NSInteger kProgramPollingPressure = 5;
#else
static NSInteger kProgramPollingPressure = 5;
#endif

@interface SessionManager : NSObject

+ (SessionManager*)shared;

@property (nonatomic, copy) NSDate *sessionLeftDate;
@property (nonatomic, copy) NSDate *sessionReturnedDate;
@property (nonatomic, copy) NSDate *sessionPausedDate;
@property (nonatomic, copy) NSDate *lastProgramUpdate;
@property (nonatomic, copy) NSDate *lastValidCurrentPlayerTime;

@property (nonatomic, copy) NSString *liveSessionID;
@property (nonatomic, copy) NSString *odSessionID;
@property (nonatomic, strong) NSTimer *programUpdateTimer;
@property (nonatomic,strong) NSDictionary *onboardingAudio;

@property (nonatomic) NSInteger remainingSleepTimerSeconds;
@property (nonatomic) NSInteger originalSleepTimerRequest;

@property NSTimer *sleepTimer;

@property NSInteger prevCheckedMinute;
@property NSTimeInterval localLiveTime;

@property int64_t liveStreamSessionBegan;
@property int64_t liveStreamSessionEnded;
@property int64_t onDemandSessionBegan;
@property int64_t onDemandSessionEnded;

@property BOOL useLocalNotifications;
@property BOOL onboardingRewound;
@property BOOL expiring;
@property BOOL userLeavingForClickthrough;
@property BOOL updaterArmed;
@property BOOL sleepTimerArmed;
@property BOOL xFreeStreamIsAvailable;

@property (nonatomic) double lastKnownBitrate;
@property NSInteger latestDriftValue;
@property (atomic) BOOL userIsViewingHeadlines;
@property PauseExplanation lastKnownPauseExplanation;
@property NSInteger peakDrift;
@property NSInteger minDrift;
@property NSInteger curDrift;
@property (nonatomic, strong) Program *currentProgram;

@property NSInteger programFetchFailoverCount;

- (void)fetchCurrentProgram:(CompletionBlockWithValue)completed;
- (void)fetchProgramAtDate:(NSDate*)date completed:(CompletionBlockWithValue)completed;
- (void)fetchScheduleForTodayAndTomorrow:(CompletionBlockWithValue)completed;

- (void)fetchOnboardingProgramWithSegment:(NSInteger)segment completed:(CompletionBlockWithValue)completed;

- (void)armProgramUpdater;
- (void)disarmProgramUpdater;
- (void)resetCache;
- (void)checkProgramUpdate:(BOOL)force;

- (CGFloat)acceptableBufferWindow;

- (BOOL)sleepTimerActive;
- (void)armSleepTimerWithSeconds:(NSInteger)seconds completed:(CompletionBlock)completed;
- (void)disarmSleepTimerWithCompletion:(CompletionBlock)completed;
- (void)cancelSleepTimerWithCompletion:(CompletionBlock)completed;

- (BOOL)sessionIsInBackground;
- (void)tickSleepTimer;

// Drift
- (NSDate*)vLive;
- (NSDate*)vNow;

- (NSTimeInterval)secondsBehindLive;
- (NSTimeInterval)virtualSecondsBehindLive;

- (void)processNotification:(UILocalNotification*)programUpdate;
@property (NS_NONATOMIC_IOSONLY) BOOL ignoreProgramUpdating;
@property (NS_NONATOMIC_IOSONLY) BOOL sessionIsExpired;
@property (NS_NONATOMIC_IOSONLY) BOOL sessionIsBehindLive;


- (BOOL)sessionIsInRecess;
- (BOOL)sessionIsInRecess:(BOOL)respectPause;

// XFS
- (void)xFreeStreamIsAvailableWithCompletion:(CompletionBlock)completion;
- (void)validateXFSToken:(NSString*)token completion:(CompletionBlockWithValue)completion;
#ifdef DEBUG
@property NSInteger numberOfChecks;
#endif

@property BOOL sessionIsHot;
@property BOOL rewindSessionIsHot;
@property BOOL rewindSessionWillBegin;
@property BOOL odSessionIsHot;
@property BOOL seekForwardRequested;
@property BOOL prerollDirty;
@property BOOL genericImageForProgram;
@property BOOL userIsSwitchingToKPCCPlus;

// Analytics
@property (nonatomic, strong) NSTimer *killSessionTimer;
- (void)forceAnalyticsSessionEndForSessionAudio;
- (void)handlePauseEventAgainstSessionAudio;

@property NSTimeInterval timeAudioWasPutInBackground;

- (BOOL)virtualLiveAudioMode;

- (void)handleSessionMovingToBackground;
- (void)handleSessionReactivation;

- (void)invalidateSession;
- (void)expireSession;

- (void)startAudioSession;

- (NSString*)startLiveSession;
- (NSString*)endLiveSession;
- (void)trackLiveSession;
- (void)trackRewindSession;

- (BOOL)dateIsReasonable:(NSDate*)date;



- (NSString*)startOnDemandSession;
- (NSString*)endOnDemandSessionWithReason:(OnDemandFinishedReason)reason;

- (long)bufferLength;

- (NSDictionary*)parseErrors;

#ifdef TESTING_PROGRAM_CHANGE
@property (NS_NONATOMIC_IOSONLY, readonly, strong) Program *fakeProgram;
@property NSInteger initialProgramRequested;
@property (nonatomic,strong) Program *fakeCurrent;
#endif

- (BOOL)sessionHasNoProgram;

@end
