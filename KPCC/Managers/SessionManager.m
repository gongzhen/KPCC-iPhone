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

static long kStreamBufferLimit = 4*60*60;

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
    NSDate *msd = [[AudioManager shared] maxSeekableDate];
    NSTimeInterval ctTI = [currentTime timeIntervalSince1970];
    NSTimeInterval msdTI = [msd timeIntervalSince1970];
    NSTimeInterval seconds = abs(ctTI - msdTI);
    return seconds;
}

- (NSString*)startLiveSession {
    
    if ( self.sessionIsHot ) return @"";
    
    NSString *ct = [NSString stringWithFormat:@"%ld",(long)[[NSDate date] timeIntervalSince1970]];
    NSString *sid = [Utils sha1:ct];
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
    
    NSString *sid = self.liveSessionID;
    if ( !sid ) {
        NSString *ct = [NSString stringWithFormat:@"%ld",(long)[[NSDate date] timeIntervalSince1970]];
        sid = [Utils sha1:ct];
    }
    NSLog(@"Logging pause event for Live Stream...");
    
    Program *p = self.currentProgram;
    [[AnalyticsManager shared] logEvent:@"liveStreamPause"
                         withParameters:@{ @"sessionID" : sid,
                                           @"programTitle" : p.title,
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
    
    [[AnalyticsManager shared] logEvent:@"liveStreamPlay"
                         withParameters:@{ @"sessionID" : self.liveSessionID ,
                                           @"behindLiveStatus" : pt,
                                           @"behindLiveSeconds" : literalValue,
                                           @"programTitle" : p.title }];
    
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
    
    [[AnalyticsManager shared] logEvent:@"liveStreamRewound"
                         withParameters:@{ @"behindLiveStatus" : pt,
                                           @"behindLiveSeconds" : [NSString stringWithFormat:@"%ld",(long)seconds],
                                           @"programTitle" : self.currentProgram.title }];
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
    
    [[AnalyticsManager shared] logEvent:event
                         withParameters:@{ @"sessionID" : sid,
                                           @"programTitle" : chunk.audioTitle,
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
    
    [[AnalyticsManager shared] logEvent:@"onDemandEpisodeBegan"
                         withParameters:@{ @"sessionID" : self.odSessionID,
                                           @"programPublishedAt" : pubDateStr,
                                           @"programTitle" : [[[QueueManager shared] currentChunk] programTitle],
                                           @"programLengthInSeconds" : [NSString stringWithFormat:@"%@",duration],
                                           @"programLength" : pretty
                                           }];
}

#pragma mark - Cache
- (void)resetCache {
    
  
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
    
    NSURLCache *shinyCache = [[NSURLCache alloc] initWithMemoryCapacity:2*1024*1024
                                                           diskCapacity:16*1024*1024
                                                               diskPath:nil];
    
    [NSURLCache setSharedURLCache:shinyCache];
   
    
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
        if ( returnedObject ) {
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
                
                [self armProgramUpdater];
                
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                completed(nil);
                [self armProgramUpdater];
            });
        }
    }];
    
}

- (void)fetchCurrentProgram:(CompletionBlockWithValue)completed {
    
    NSDate *d2u = [NSDate date];
    if ( [self sessionIsBehindLive] && ![self seekForwardRequested] ) {
        d2u = [[AudioManager shared].audioPlayer.currentItem currentDate];
        NSLog(@"Adjusted time to fetch program : %@",[NSDate stringFromDate:d2u
                                                                 withFormat:@"hh:mm:ss a"]);
    }
    
    if ( !d2u ) {
        completed(nil);
        return;
    }
    
    [self fetchProgramAtDate:d2u completed:completed];
}

- (void)armProgramUpdater {
    [self disarmProgramUpdater];
    
    if ( [self ignoreProgramUpdating] ) return;
    
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
/*    if ( [self useLocalNotifications] ) {
        UILocalNotification *localNote = [[UILocalNotification alloc] init];
        localNote.fireDate = then;
        localNote.alertBody = kUpdateProgramKey;
        [[UIApplication sharedApplication] scheduleLocalNotification:localNote];
    } else { */
        

        self.programUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:sinceNow
                                                                   target:self
                                                                 selector:@selector(processTimer:)
                                                                 userInfo:nil
                                                                  repeats:NO];
#ifdef DEBUG
        NSLog(@"Program will check itself again at %@ (Approx %@ from now)",[then prettyTimeString],[NSDate prettyTextFromSeconds:sinceNow]);
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
    
}

- (void)disarmProgramUpdater {
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

#pragma mark - State handling
- (BOOL)sessionIsBehindLive {
    
    NSDate *currentDate = [[AudioManager shared].audioPlayer.currentItem currentDate];
    NSDate *live = [[AudioManager shared] maxSeekableDate];
    
    if ( abs([live timeIntervalSince1970] - [currentDate timeIntervalSince1970]) > 60 ) {
        return YES;
    }
    
    return NO;
}

- (BOOL)sessionIsExpired {
    
    if ( [[AudioManager shared] currentAudioMode] == AudioModeOnDemand ) return NO;
    
    if ( [self sessionPausedDate] ) {
        NSDate *spd = [[SessionManager shared] sessionPausedDate];
        if ( [[NSDate date] timeIntervalSinceDate:spd] > kStreamBufferLimit ) {
            return YES;
        }
    }
    
    return NO;
}

- (BOOL)sessionIsInRecess {
    
    if ( [[AudioManager shared] currentAudioMode] == AudioModeOnDemand ) return NO;
    if ( [[AudioManager shared] currentAudioMode] == AudioModeOnboarding ) return NO;
    Program *cp = self.currentProgram;
    NSDate *soft = cp.soft_starts_at;
    NSDate *hard = cp.starts_at;
    NSDate *now = [NSDate date];
    //if ( [self sessionIsBehindLive] ) {
        now = [[AudioManager shared].audioPlayer.currentItem currentDate];
    //}
    
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
}

- (void)setSessionReturnedDate:(NSDate *)sessionReturnedDate {
    _sessionReturnedDate = sessionReturnedDate;
    if ( sessionReturnedDate ) {
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
    
    [self fetchCurrentProgram:^(id returnedObject) {
        
    }];
}

- (void)handleSessionReactivation {
    if ( !self.sessionLeftDate || !self.sessionReturnedDate ) return;
    long tiBetween = [[self sessionReturnedDate] timeIntervalSince1970] - [[self sessionLeftDate] timeIntervalSince1970];
    if ( tiBetween > kStreamBufferLimit ) {
        [[AudioManager shared] stopStream];
        [self fetchCurrentProgram:^(id returnedObject) {
            self.sessionReturnedDate = nil;
        }];
    } else {
        if ( [[AudioManager shared] status] != StreamStatusPaused ) {
            if ( [self sessionIsBehindLive] ) {
                [self fetchProgramAtDate:[[AudioManager shared].audioPlayer.currentItem currentDate] completed:^(id returnedObject) {
                    self.sessionReturnedDate = nil;
                }];
            } else {
                [self fetchCurrentProgram:^(id returnedObject) {
                    self.sessionReturnedDate = nil;
                }];
            }
        }
    }
}



@end
