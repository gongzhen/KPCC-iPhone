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

static NSInteger kStreamIsLiveTolerance = 120;

#ifndef PRODUCTION
static NSInteger kProgramPollingPressure = 30;
#else
static NSInteger kProgramPollingPressure = 15;
#endif

@interface SessionManager : NSObject

+ (SessionManager*)shared;

@property (nonatomic, copy) NSDate *sessionLeftDate;
@property (nonatomic, copy) NSDate *sessionReturnedDate;
@property (nonatomic, copy) NSDate *sessionPausedDate;
@property (nonatomic, copy) NSDate *lastProgramUpdate;
@property (nonatomic, copy) NSString *liveSessionID;
@property (nonatomic, copy) NSString *odSessionID;
@property (nonatomic, strong) NSTimer *programUpdateTimer;
@property (nonatomic,strong) NSDictionary *onboardingAudio;

@property NSInteger prevCheckedMinute;

@property int64_t liveStreamSessionBegan;
@property int64_t liveStreamSessionEnded;
@property int64_t onDemandSessionBegan;
@property int64_t onDemandSessionEnded;

@property BOOL useLocalNotifications;
@property BOOL onboardingRewound;
@property BOOL expiring;
@property BOOL userLeavingForClickthrough;
@property BOOL updaterArmed;
@property (nonatomic) double lastKnownBitrate;
@property NSInteger latestDriftValue;
@property (atomic) BOOL userIsViewingHeadlines;

@property (nonatomic, strong) Program *currentProgram;

- (void)fetchCurrentProgram:(CompletionBlockWithValue)completed;
- (void)fetchProgramAtDate:(NSDate*)date completed:(CompletionBlockWithValue)completed;
- (void)fetchOnboardingProgramWithSegment:(NSInteger)segment completed:(CompletionBlockWithValue)completed;

- (void)armProgramUpdater;
- (void)disarmProgramUpdater;
- (void)resetCache;
- (void)checkProgramUpdate:(BOOL)force;

- (BOOL)sessionIsInBackground;

// Drift
- (NSDate*)vLive;
- (NSInteger)calculatedDriftValue;

- (NSTimeInterval)secondsBehindLive;

- (void)processNotification:(UILocalNotification*)programUpdate;
@property (NS_NONATOMIC_IOSONLY) BOOL ignoreProgramUpdating;
@property (NS_NONATOMIC_IOSONLY) BOOL sessionIsExpired;
@property (NS_NONATOMIC_IOSONLY) BOOL sessionIsBehindLive;


- (BOOL)sessionIsInRecess;
- (BOOL)sessionIsInRecess:(BOOL)respectPause;

@property BOOL sessionIsHot;
@property BOOL rewindSessionIsHot;
@property BOOL rewindSessionWillBegin;
@property BOOL odSessionIsHot;
@property BOOL seekForwardRequested;
@property BOOL prerollDirty;

- (void)handleSessionReactivation;
- (void)invalidateSession;
- (void)expireSession;

- (NSString*)startLiveSession;
- (NSString*)endLiveSession;
- (void)trackLiveSession;
- (void)trackRewindSession;

- (NSString*)startOnDemandSession;
- (NSString*)endOnDemandSessionWithReason:(OnDemandFinishedReason)reason;
- (void)trackOnDemandSession;
- (BOOL)programDirty:(Program*)p;

- (NSDate*)pushDateToNearestTenMinutes:(NSDate*)date;

- (long)bufferLength;

#ifdef TESTING_PROGRAM_CHANGE
@property (NS_NONATOMIC_IOSONLY, readonly, strong) Program *fakeProgram;
@property NSInteger initialProgramRequested;
@property (nonatomic,strong) Program *fakeCurrent;
#endif


@end
