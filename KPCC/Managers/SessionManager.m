//
//  SessionManager.m
//  KPCC
//
//  Created by Ben Hochberg on 11/4/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "SessionManager.h"
#import "AudioManager.h"
#import "NetworkManager.h"
#import "AnalyticsManager.h"
#import "AudioChunk.h"
#import "QueueManager.h"
#import "UXmanager.h"
#import "SCPRMasterViewController.h"




@implementation SessionManager

+ (SessionManager*)shared {
    static SessionManager *mgr = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mgr = [[SessionManager alloc] init];
#ifdef TESTING_PROGRAM_CHANGE
        mgr.initialProgramRequested = 0;
#endif
    });
    return mgr;
}

#pragma mark - Session Mgmt
- (NSTimeInterval)secondsBehindLive {
    NSDate *currentTime = [AudioManager shared].audioPlayer.currentItem.currentDate;
    if ( !currentTime ) return 0;
    
    NSDate *msd = [NSDate date];
    NSTimeInterval ctTI = [currentTime timeIntervalSince1970];
    NSTimeInterval msdTI = [msd timeIntervalSince1970];
    NSTimeInterval seconds = abs(ctTI - msdTI);
    return seconds;
}

- (NSString*)startLiveSession {
    
    if ( self.sessionIsHot ) return @"";
    
    NSString *ct = [NSString stringWithFormat:@"%ld",(long)[[NSDate date] timeIntervalSince1970]];
    NSString *sid = [Utils sha1:ct];
    self.sessionPausedDate = nil;
    self.liveSessionID = sid;
    @synchronized(self) {
        self.sessionIsHot = YES;
    }
    
    self.liveStreamSessionBegan = (int64_t)[[NSDate date] timeIntervalSince1970];
    
    return sid;
}

- (NSString*)endLiveSession {
    
    if ( self.rewindSessionWillBegin ) {
        self.rewindSessionWillBegin = NO;
        
        NSString *sid = self.liveSessionID;
        if ( !sid ) {
            NSString *ct = [NSString stringWithFormat:@"%ld",(long)[[NSDate date] timeIntervalSince1970]];
            self.liveSessionID = [Utils sha1:ct];
        }
        
        return @"";
    }
    
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    NSTimeInterval sessionLength = abs(now - self.liveStreamSessionBegan);
    NSString *pt = [NSDate prettyTextFromSeconds:sessionLength];
    if ( sessionLength > 30000 ) return @"";
    
    NSString *sid = self.liveSessionID;
    if ( !sid ) {
        NSString *ct = [NSString stringWithFormat:@"%ld",(long)[[NSDate date] timeIntervalSince1970]];
        sid = [Utils sha1:ct];
    }
    NSLog(@"Logging pause event for Live Stream...");
    
    Program *p = self.currentProgram;
    NSString *title = p.title ? p.title : @"[UNKNOWN]";
    
    [[AnalyticsManager shared] logEvent:@"liveStreamPause"
                         withParameters:@{ @"kpccSessionId" : sid,
                                           @"programTitle" : title,
                                           @"sessionLength" : pt,
                                           @"sessionLengthInSeconds" : [NSString stringWithFormat:@"%ld",(long)sessionLength] }];
    self.sessionIsHot = NO;
    self.liveSessionID = nil;
    return sid;
}

- (void)trackLiveSession {
    if ( !self.sessionIsHot ) return;
    if ( [AudioManager shared].currentAudioMode != AudioModeLive ) return;
    
    @synchronized(self) {
        self.sessionIsHot = NO;
    }
    
    NSTimeInterval seconds = [self secondsBehindLive];
    NSString *pt = @"";
    if ( seconds > 60 ) {
        pt = [NSDate prettyTextFromSeconds:seconds];
    } else {
        pt = @"LIVE";
    }
    
    NSString *literalValue = [NSString stringWithFormat:@"%ld",(long)seconds];
    
    Program *p = self.currentProgram;
    
    NSLog(@"Logging play event for Live Stream...");
    NSString *title = @"[UNKNOWN]";
    if ( p.title ) {
        title = p.title;
    }
    [[AnalyticsManager shared] logEvent:@"liveStreamPlay"
                         withParameters:@{ @"kpccSessionId" : self.liveSessionID ,
                                           @"behindLiveStatus" : pt,
                                           @"behindLiveSeconds" : literalValue,
                                           @"programTitle" : title }];
    
}

- (void)trackRewindSession {
    if ( !self.rewindSessionIsHot ) return;
    if ( [AudioManager shared].currentAudioMode != AudioModeLive ) return;
    
    @synchronized(self) {
        self.rewindSessionIsHot = NO;
    }
    
    NSInteger seconds = [self secondsBehindLive];
    NSString *pt = [NSDate prettyTextFromSeconds:seconds];
    
    NSLog(@"Tracking rewind session...");
    
    NSString *title = self.currentProgram.title ? self.currentProgram.title : @"[UNKNOWN]";
    [[AnalyticsManager shared] logEvent:@"liveStreamRewound"
                         withParameters:@{ @"behindLiveStatus" : pt,
                                           @"behindLiveSeconds" : [NSString stringWithFormat:@"%ld",(long)seconds],
                                           @"programTitle" : title }];
}

- (NSString*)startOnDemandSession {
    
    if ( self.odSessionIsHot ) return @"";
    
    NSString *ct = [NSString stringWithFormat:@"%ld",(long)[[NSDate date] timeIntervalSince1970]];
    NSString *sid = [Utils sha1:ct];
    self.odSessionID = sid;
    @synchronized(self) {
        self.odSessionIsHot = YES;
    }
    
    self.onDemandSessionBegan = (int64_t)[[NSDate date] timeIntervalSince1970];
    
    return sid;
}

- (NSString*)endOnDemandSessionWithReason:(OnDemandFinishedReason)reason {
    
    if ( !self.odSessionIsHot ) return @"";

    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    NSTimeInterval sessionLength = abs(now - self.onDemandSessionBegan);
    NSString *pt = [NSDate prettyTextFromSeconds:sessionLength];
    
    NSString *sid = self.odSessionID;
    if ( !sid ) {
        NSString *ct = [NSString stringWithFormat:@"%ld",(long)[[NSDate date] timeIntervalSince1970]];
        sid = [Utils sha1:ct];
    }
    NSLog(@"Logging pause event for Live Stream...");
    
    AudioChunk *chunk = [[QueueManager shared] currentChunk];
    NSString *event = @"";
    switch (reason) {
        case OnDemandFinishedReasonEpisodeEnd:
            event = @"onDemandAudioCompleted";
            break;
        case OnDemandFinishedReasonEpisodePaused:
            event = @"onDemandAudioPaused";
            break;
        case OnDemandFinishedReasonEpisodeSkipped:
            event = @"onDemandEpisodeSkipped";
            break;
        default:
            break;
    }
    
    NSString *title = chunk.audioTitle ? chunk.audioTitle : @"[UNKNOWN]";
    
    [[AnalyticsManager shared] logEvent:event
                         withParameters:@{ @"kpccSessionId" : sid,
                                           @"programTitle" : title,
                                           @"sessionLength" : pt,
                                           @"sessionLengthInSeconds" : [NSString stringWithFormat:@"%ld",(long)sessionLength] }];
    self.odSessionIsHot = NO;
    self.odSessionID = nil;
    return sid;
}

- (void)trackOnDemandSession {
    if ( !self.odSessionIsHot ) return;
    if ( [AudioManager shared].currentAudioMode != AudioModeOnDemand ) return;
    
    @synchronized(self) {
        self.odSessionIsHot = NO;
    }
    
    NSLog(@"Logging play event for Live Stream...");
    
    NSDate *d = [[[QueueManager shared] currentChunk] audioTimeStamp];
    NSString *pubDateStr = [NSDate stringFromDate:d
                                       withFormat:@"MM/dd/YYYY hh:mm a"];
    NSNumber *duration = [[[QueueManager shared] currentChunk] audioDuration];
    NSInteger dur = [duration intValue];
    NSString *pretty = [NSDate prettyTextFromSeconds:dur];
    
    AudioChunk *chunk = [[QueueManager shared] currentChunk];
    NSString *title = chunk.programTitle ? chunk.programTitle : @"[UNKNOWN]";
    
    [[AnalyticsManager shared] logEvent:@"onDemandEpisodeBegan"
                         withParameters:@{ @"kpccSessionId" : self.odSessionID,
                                           @"programPublishedAt" : pubDateStr,
                                           @"programTitle" : title,
                                           @"programLengthInSeconds" : [NSString stringWithFormat:@"%@",duration],
                                           @"programLength" : pretty
                                           }];
}

#pragma mark - Cache
- (void)resetCache {
    
  /*
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
    
    NSURLCache *shinyCache = [[NSURLCache alloc] initWithMemoryCapacity:2*1024*1024
                                                           diskCapacity:16*1024*1024
                                                               diskPath:nil];
    
    [NSURLCache setSharedURLCache:shinyCache];
   */
    
}

#pragma mark - Program
- (void)fetchOnboardingProgramWithSegment:(NSInteger)segment completed:(CompletionBlockWithValue)completed {
    NSMutableDictionary *p = [NSMutableDictionary new];
    p[@"soft_starts_at"] = [NSDate date];
    p[@"starts_at"] = [NSDate date];
    
    NSString *s = [NSString stringWithFormat:@"onboarding%ld.mp3",(long)segment];
    NSString *fqp = [[NSBundle mainBundle] pathForResource:s
                                                    ofType:@""];
    AVAsset *item = [AVAsset assetWithURL:[NSURL fileURLWithPath:fqp]];
    CMTime duration = item.duration;
    NSInteger seconds = CMTimeGetSeconds(duration);
    NSInteger modifier = segment == 1 ? 1 : 0;
    p[@"duration"] = @(seconds+(modifier*seconds));
    p[@"title"] = @"Welcome to KPCC";
    p[@"program_slug"] = [NSString stringWithFormat:@"onboarding%ld",(long)segment];
    self.onboardingAudio = p;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.33 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        completed(p);
    });
    
}

- (void)fetchProgramAtDate:(NSDate *)date completed:(CompletionBlockWithValue)completed {
    
#ifdef TESTING_PROGRAM_CHANGE
    Program *p = [self fakeProgram];
    self.currentProgram = p;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"program_has_changed"
                                                        object:nil
                                                      userInfo:nil];
    
    completed(p);
    

    
    [self armProgramUpdater];
    return;
#endif
    
    NSString *urlString = [NSString stringWithFormat:@"%@/schedule/at?time=%d",kServerBase,(int)[date timeIntervalSince1970]];
    [[NetworkManager shared] requestFromSCPRWithEndpoint:urlString completion:^(id returnedObject) {
        // Create Program and insert into managed object context
        if ( returnedObject && [(NSDictionary*)returnedObject count] > 0 ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                Program *programObj = [Program insertProgramWithDictionary:returnedObject inManagedObjectContext:[[ContentManager shared] managedObjectContext]];
                
                [[ContentManager shared] saveContext];
                
                BOOL touch = NO;
                if ( self.currentProgram ) {
                    if ( !SEQ(self.currentProgram.program_slug,
                              programObj.program_slug) ) {
                        touch = YES;
                    }
                } else if ( programObj ) {
                    touch = YES;
                }
                
#ifdef TEST_PROGRAM_IMAGE
                touch = YES;
#endif
                if ( touch ) {
                    touch = ![self ignoreProgramUpdating];
                }
                
                self.currentProgram = programObj;
                if ( touch ) {
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"program_has_changed"
                                                                        object:nil
                                                                      userInfo:nil];
                }
                completed(programObj);
                
                
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:@"program_has_changed"
                                                                    object:nil
                                                                  userInfo:nil];
                
                completed(nil);
            });
        }
    }];
    
}

- (void)fetchCurrentProgram:(CompletionBlockWithValue)completed {
#ifdef LEGACY_TIMER
    NSDate *d2u = [NSDate date];
    if ( [self sessionIsBehindLive] && ![self seekForwardRequested] && !self.expiring ) {
        d2u = [[AudioManager shared].audioPlayer.currentItem currentDate];
        d2u = [d2u minuteRoundedUpByThreshold:3];
        
        NSLog(@"Adjusted time to fetch program : %@",[NSDate stringFromDate:d2u
                                                                 withFormat:@"hh:mm:ss a"]);
    }
    
    if ( !d2u ) {
        completed(nil);
        return;
    }
    
    [self fetchProgramAtDate:d2u completed:completed];
#else
    NSDate *ct = [[AudioManager shared].audioPlayer.currentItem currentDate];
    if ( ct ) {
        [self fetchProgramAtDate:ct completed:completed];
    } else {
        [self fetchProgramAtDate:[NSDate date]
                       completed:completed];
    }
#endif
}

- (void)armProgramUpdater {
    [self disarmProgramUpdater];
    

    if ( [self ignoreProgramUpdating] ) return;
#ifdef LEGACY_TIMER
#ifndef TESTING_PROGRAM_CHANGE
    NSInteger unit = NSYearCalendarUnit|NSMonthCalendarUnit|NSDayCalendarUnit|NSHourCalendarUnit|NSMinuteCalendarUnit|NSSecondCalendarUnit;
    NSDate *now = [NSDate date];
    
    
    NSDate *fakeNow = nil;
    BOOL cookDate = NO;
    Program *cp = [self currentProgram];
    NSLog(@"%@ soft starts at %@",cp.title,[NSDate stringFromDate:cp.soft_starts_at
                                                       withFormat:@"hh:mm:ss a"]);
    
    if ( [self sessionIsBehindLive] ) {
        fakeNow = [[AudioManager shared].audioPlayer.currentItem currentDate];
        cookDate = YES;
    }
    
    NSDate *nowToUse = cookDate ? fakeNow : now;
    NSDateComponents *components = [[NSCalendar currentCalendar] components:unit
                                                                   fromDate:nowToUse];
    
    NSDate *then = nil;
    NSInteger minute = [components minute];
    NSInteger minDiff = 0;
    if ( minute < 30 ) {
        minDiff = 30 - minute;
    } else {
        minDiff = 60 - minute;
    }
    
    then = [NSDate dateWithTimeInterval:minDiff*60
                              sinceDate:now];

    NSDateComponents *cleanedComps = [[NSCalendar currentCalendar] components:unit
                                                                     fromDate:then];
    [cleanedComps setSecond:10];
    then = [[NSCalendar currentCalendar] dateFromComponents:cleanedComps];
    
    NSTimeInterval nowTI = [now timeIntervalSince1970];
    NSTimeInterval thenTI = [then timeIntervalSince1970];
    if ( abs(thenTI - nowTI) < 60 ) {
        then = [NSDate dateWithTimeInterval:30*60
                                  sinceDate:then];
    }


    NSTimeInterval sinceNow = [then timeIntervalSince1970] - [now timeIntervalSince1970];
    if ( cookDate ) {
        sinceNow = minDiff * 60 + 6;
    }

    self.programUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:sinceNow
                                                                   target:self
                                                                 selector:@selector(processTimer:)
                                                                 userInfo:nil
                                                                  repeats:NO];
#ifdef DEBUG
    NSLog(@"Program will check itself again at %@ (Approx %@ from now)",[then prettyTimeString],[NSDate prettyTextFromSeconds:sinceNow]);
    NSLog(@"Current player time is : %@",[NSDate stringFromDate:[[AudioManager shared].audioPlayer.currentItem currentDate]
                                                     withFormat:@"hh:mm:ss a"]);
#endif
   // }
#else
    NSDate *threeMinutesFromNow = [[NSDate date] dateByAddingTimeInterval:96];
    NSLog(@"Program will check itself again at : %@",[threeMinutesFromNow prettyTimeString]);
    self.programUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:abs([threeMinutesFromNow timeIntervalSinceNow])
                                                               target:self
                                                             selector:@selector(processTimer:)
                                                             userInfo:nil
                                                              repeats:NO];
    
#endif
#else
    
   // [self checkProgramUpdate:NO];
    
#endif
    
}

- (void)disarmProgramUpdater {
#ifdef LEGACY_TIMER
/*    if ( [self useLocalNotifications] ) {
        [[UIApplication sharedApplication] cancelAllLocalNotifications];
    } else {*/
    if ( self.programUpdateTimer ) {
        if ( [self.programUpdateTimer isValid] ) {
            [self.programUpdateTimer invalidate];
        }
        self.programUpdateTimer = nil;
    }
   // }
#endif
}

- (BOOL)ignoreProgramUpdating {
    
    if ( [[UXmanager shared] onboardingEnding] ) return NO;
    if ( [self seekForwardRequested] ) return NO;
    if ( [self sessionIsExpired] ) return NO;
    if (
            ([[AudioManager shared] status] == StreamStatusPaused && [AudioManager shared].currentAudioMode != AudioModeOnboarding)  ||
            [[AudioManager shared] currentAudioMode] == AudioModeOnDemand
        
        )
    {
        return YES;
    }
   
    return NO;
    
}

#ifdef TESTING_PROGRAM_CHANGE
- (Program*)fakeProgram {
    if ( self.initialProgramRequested >= 2 ) {
        Program *p = [Program insertNewObjectIntoContext:nil];
        p.soft_starts_at = [[NSDate date] dateByAddingTimeInterval:(60*4)];
        p.starts_at = [[NSDate date] dateByAddingTimeInterval:(60*3)];
        p.ends_at = [[NSDate date] dateByAddingTimeInterval:(60*10)];
        p.title = @"Next Program";
        p.program_slug = [NSString stringWithFormat:@"%ld",(long)arc4random() % 10000];
        return p;
    }
    
    self.initialProgramRequested++;
    if ( !self.fakeCurrent ) {
        self.fakeCurrent = [Program insertNewObjectIntoContext:nil];
        Program *p = self.fakeCurrent;
        p.soft_starts_at = [[NSDate date] dateByAddingTimeInterval:-120];
        p.starts_at = [[NSDate date] dateByAddingTimeInterval:-1*(120)];
        p.ends_at = [[NSDate date] dateByAddingTimeInterval:(60*1)];
        p.title = @"Current Program";
    }

    NSLog(@"Times a fake thing was requested : %d",self.initialProgramRequested);
    return self.fakeCurrent;
    
}
#endif

- (BOOL)programDirty:(Program *)p {
    Program *cp = self.currentProgram;
    if ( !cp ) {
        return YES;
    }
    return !SEQ(p.program_slug,cp.program_slug);
}

- (void)checkProgramUpdate:(BOOL)force {

    if ( [[AudioManager shared] currentAudioMode] == AudioModeOnDemand ) return;
    
    NSDate *ct = [[AudioManager shared].audioPlayer.currentItem currentDate];
    if ( ct ) {
        NSDateComponents *comps = [[NSCalendar currentCalendar] components:NSCalendarUnitMinute|NSCalendarUnitSecond
                                                                  fromDate:ct];
        if ( [comps minute] % 5 == 0 || force ) {
            
            if ( [comps minute] == self.prevCheckedMinute ) return;
            self.prevCheckedMinute = [comps minute];
            
            if ( [self updaterArmed] ) {
                return;
            } else {
                
                self.prevCheckedMinute = [comps minute];
                NSLog(@"Checking program : %@ (%ld)",[NSDate stringFromDate:ct
                                                                 withFormat:@"hh:mm a"],(long)[ct timeIntervalSince1970]);
                
                [self processTimer:nil];
            }
        } else {
            [self setUpdaterArmed:NO];
        }
        
    } else {
        if ( force ) {
            if ( [self updaterArmed] ) {
                return;
            } else {
                [self processTimer:nil];
            }
        } else {
            [self setUpdaterArmed:NO];
        }
    }
    
}

#pragma mark - State handling
- (void)setLastKnownBitrate:(double)lastKnownBitrate {
    double replacedBitrate = _lastKnownBitrate;
    _lastKnownBitrate = lastKnownBitrate;
    if ( replacedBitrate > 0.0 ) {
        if ( fabs(replacedBitrate - _lastKnownBitrate) > 10000.0 ) {
            [[AnalyticsManager shared] logEvent:@"bitRateSwitching"
                                 withParameters:@{}];
        }
    }
    
}

- (long)bufferLength {
    long stableDuration = kStreamBufferLimit;
    for ( NSValue *str in [[[AudioManager shared] audioPlayer] currentItem].seekableTimeRanges ) {
        CMTimeRange r = [str CMTimeRangeValue];
        if ( labs(CMTimeGetSeconds(r.duration) > kStreamCorrectionTolerance ) ) {
            stableDuration = CMTimeGetSeconds(r.duration);
        }
    }
    
    return stableDuration;
    
}

- (BOOL)sessionIsBehindLive {
    
    NSDate *currentDate = [[AudioManager shared].audioPlayer.currentItem currentDate];
    if ( !currentDate ) return NO;
    
    NSDate *live = [NSDate date];
    
    
    if ( abs([live timeIntervalSince1970] - [currentDate timeIntervalSince1970]) > kStreamIsLiveTolerance ) {
        return YES;
    }
    
    return NO;
}

- (BOOL)sessionIsExpired {
    
    if ( [[AudioManager shared] currentAudioMode] == AudioModeOnDemand ) return NO;
    
    if ( [[AudioManager shared] status] == StreamStatusPaused && [self sessionPausedDate] ) {
        NSDate *spd = [[SessionManager shared] sessionPausedDate];
        NSDate *cit = [[AudioManager shared].audioPlayer.currentItem currentDate];
        NSDate *aux = [spd earlierDate:cit];
        
        if ( !aux || [[NSDate date] timeIntervalSinceDate:aux] > kStreamBufferLimit ) {
            return YES;
        }
    }

    return NO;
}

- (BOOL)sessionIsInRecess {
    
   return [self sessionIsInRecess:YES];
    
}

- (BOOL)sessionIsInRecess:(BOOL)respectPause {
    if ( [[AudioManager shared] currentAudioMode] == AudioModeOnDemand ) return NO;
    if ( [[AudioManager shared] currentAudioMode] == AudioModeOnboarding ) return NO;
    if ( respectPause )
        if ( [[AudioManager shared] status] == StreamStatusPaused ) return NO;
    
    Program *cp = self.currentProgram;
    NSDate *soft = cp.soft_starts_at;
    NSDate *hard = cp.starts_at;
    NSDate *now = [NSDate date];
    
    if ( [[AudioManager shared] status] != StreamStatusStopped ) {
        if ( [self sessionIsBehindLive] ) {
            now = [[AudioManager shared].audioPlayer.currentItem currentDate];
        }
    }
    
    NSTimeInterval softTI = [soft timeIntervalSince1970]+60;
    NSTimeInterval hardTI = [hard timeIntervalSince1970];
    NSTimeInterval nowTI = [now timeIntervalSince1970];
    if ( nowTI >= hardTI && nowTI <= softTI ) {
        return YES;
    }
    
    return NO;
}

- (void)invalidateSession {
    if ( [[AudioManager shared] currentAudioMode] == AudioModeOnDemand ) return;
    [self armProgramUpdater];
}

- (void)setSessionLeftDate:(NSDate *)sessionLeftDate {
    _sessionLeftDate = sessionLeftDate;
    self.sessionIsInBackground = YES;
}

- (void)setSessionReturnedDate:(NSDate *)sessionReturnedDate {
    _sessionReturnedDate = sessionReturnedDate;
    self.sessionIsInBackground = NO;
    if ( sessionReturnedDate && self.sessionLeftDate ) {
        [self handleSessionReactivation];
    }
    
}

- (void)processNotification:(UILocalNotification*)programUpdate {
    
    if ( [self ignoreProgramUpdating] ) return;
    
    if ( SEQ([programUpdate alertBody],kUpdateProgramKey) ) {
        [self fetchCurrentProgram:^(id returnedObject) {
            
        }];
    }
}

- (void)processTimer:(NSTimer*)timer {
    
    if ( [self ignoreProgramUpdating] ) return;
    
    [self setUpdaterArmed:YES];
    [self fetchCurrentProgram:^(id returnedObject) {
        
    }];
}

- (void)handleSessionReactivation {
    
    if ( [[AudioManager shared] currentAudioMode] == AudioModeOnboarding ) return;
    if ( ![[UXmanager shared].settings userHasViewedOnboarding] ) return;
    
    if ( !self.sessionLeftDate || !self.sessionReturnedDate ) return;
    if ( [self sessionIsExpired] ) {
    
        [self expireSession];
        
    } else {
        if ( [[AudioManager shared] status] != StreamStatusPaused ) {
#ifdef LEGACY_TIMER
            if ( [self sessionIsBehindLive] ) {
                [self fetchProgramAtDate:[[AudioManager shared].audioPlayer.currentItem currentDate] completed:^(id returnedObject) {
                    self.sessionReturnedDate = nil;
                }];
            } else {
                [self fetchCurrentProgram:^(id returnedObject) {
                    self.sessionReturnedDate = nil;
                }];
            }
#else
            [self checkProgramUpdate:YES];
#endif
        }
    }
}

- (void)expireSession {
    self.sessionReturnedDate = nil;
    self.sessionPausedDate = nil;
    self.expiring = YES;
    [[AudioManager shared] setWaitForSeek:NO];
    [[AudioManager shared] setSeekRequested:NO];
    
    if ( [[AudioManager shared] audioPlayer] )
        [[AudioManager shared] takedownAudioPlayer];
    
    SCPRMasterViewController *master = [[Utils del] masterViewController];
    [master resetUI];
}



@end
