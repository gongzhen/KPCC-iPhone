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


@interface SessionManager : NSObject

+ (SessionManager*)shared;

@property (nonatomic, copy) NSDate *sessionLeftDate;
@property (nonatomic, copy) NSDate *sessionReturnedDate;
@property (nonatomic, copy) NSDate *sessionPausedDate;
@property (nonatomic, copy) NSDate *lastProgramUpdate;
@property (nonatomic, strong) NSTimer *programUpdateTimer;

@property (nonatomic,strong) NSDictionary *onboardingAudio;

@property BOOL useLocalNotifications;
@property BOOL onboardingRewound;

@property (nonatomic, strong) Program *currentProgram;

- (void)fetchCurrentProgram:(CompletionBlockWithValue)completed;
- (void)fetchProgramAtDate:(NSDate*)date completed:(CompletionBlockWithValue)completed;
- (void)fetchOnboardingProgramWithSegment:(NSInteger)segment completed:(CompletionBlockWithValue)completed;

- (void)armProgramUpdater;
- (void)disarmProgramUpdater;

- (void)processNotification:(UILocalNotification*)programUpdate;
@property (NS_NONATOMIC_IOSONLY, readonly) BOOL ignoreProgramUpdating;
@property (NS_NONATOMIC_IOSONLY, readonly) BOOL sessionIsExpired;
@property (NS_NONATOMIC_IOSONLY, readonly) BOOL sessionIsBehindLive;
@property (NS_NONATOMIC_IOSONLY, readonly) BOOL sessionIsInRecess;
- (void)handleSessionReactivation;
- (void)invalidateSession;

#ifdef TESTING_PROGRAM_CHANGE
@property (NS_NONATOMIC_IOSONLY, readonly, strong) Program *fakeProgram;
@property NSInteger initialProgramRequested;
@property (nonatomic,strong) Program *fakeCurrent;

#endif


@end
