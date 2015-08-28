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
#import <Parse/Parse.h>



@implementation SessionManager

+ (SessionManager*)shared {
    static SessionManager *mgr = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mgr = [[SessionManager alloc] init];
#ifdef TESTING_PROGRAM_CHANGE
        mgr.initialProgramRequested = 0;
#endif
        mgr.prevCheckedMinute = -1;
        mgr.peakDrift = kAllowableDriftCeiling;
    });
    return mgr;
}

#pragma mark - Session Mgmt
- (NSDate*)vLive {
    
    
    NSDate *live = [[NSDate date] dateByAddingTimeInterval:-90.0f]; // Add in what we know is going to be slightly behind live
    if ( self.localLiveTime > 0.0f ) {
        live = [NSDate dateWithTimeIntervalSince1970:self.localLiveTime];
    } else if ( [[AudioManager shared] maxSeekableDate] ) {
        live = [[AudioManager shared] maxSeekableDate];
    }

    
    if ( [AudioManager shared].audioPlayer.currentItem ) {
        NSDate *msd = [[AudioManager shared].audioPlayer.currentItem currentDate];
        if ( !msd ) {
            // AVPlayer has no current date, so it's probably stopped
            return [[NSDate date] dateByAddingTimeInterval:60*60*24*10];
        }
    }
    
    return live;
}

- (NSDate*)vNow {
    
    NSDate *cd = [[AudioManager shared].audioPlayer.currentItem currentDate];
    if ( cd ) {
        if ( [[SessionManager shared] dateIsReasonable:cd] ) {
            return cd;
        } else {
            NSLog(@" ************* AUDIO PLAYER CURRENT DATE IS CORRUPTED : %@",[NSDate stringFromDate:cd
                                                                                            withFormat:@"MM/dd/yyyy h:mm:ss a"]);
        }
    }
        
    cd = [[SessionManager shared] lastValidCurrentPlayerTime];
    if ( cd ) {
        if ( [[SessionManager shared] dateIsReasonable:cd] ) {
            return cd;
        }
    }
    
    return [self vLive];
}

- (NSTimeInterval)secondsBehindLive {
    NSDate *currentTime = [AudioManager shared].audioPlayer.currentItem.currentDate;
    if ( !currentTime ) return 0;
    
#ifndef SUPPRESS_V_LIVE
    NSDate *msd = [self vLive];
#else
    NSDate *msd = [NSDate date];
#endif
    
    NSTimeInterval ctTI = [currentTime timeIntervalSince1970];
    NSTimeInterval msdTI = [msd timeIntervalSince1970];
    NSTimeInterval seconds = fabs(ctTI - msdTI);
    return seconds;
}

- (NSTimeInterval)virtualSecondsBehindLive {
    CGFloat sbl = [[[SessionManager shared] vLive] timeIntervalSince1970] - [[[AudioManager shared].audioPlayer.currentItem currentDate] timeIntervalSince1970];
    if ( sbl < 0.0f ) {
        sbl = 0.0f;
    } 
    
    return (NSTimeInterval)sbl;
}

#pragma mark - Analytics
- (void)handlePauseEventAgainstSessionAudio {
    if ( self.killSessionTimer ) {
        if ( [self.killSessionTimer isValid] ) {
            [self.killSessionTimer invalidate];
        }
        self.killSessionTimer = nil;
    }
    
    self.killSessionTimer = [NSTimer scheduledTimerWithTimeInterval:80.0f
                                                             target:self
                                                           selector:@selector(endAnalyticsForAudio:)
                                                           userInfo:nil
                                                            repeats:NO];
}

- (void)forceAnalyticsSessionEndForSessionAudio {
    [self endAnalyticsForAudio:nil];
}

- (void)endAnalyticsForAudio:(NSNotification*)note {
    NSString *eventName = [[AudioManager shared] currentAudioMode] == AudioModeLive ? @"liveStreamPlay" : @"episodePlay";
    [Flurry endTimedEvent:eventName
           withParameters:nil];
    
    [[AnalyticsManager shared] nielsenStop];
}

#pragma mark - Sessions
- (void)trackLiveSession {
    if ( !self.sessionIsHot ) return;
    if ( [AudioManager shared].currentAudioMode != AudioModeLive ) return;
    
    @synchronized(self) {
        self.sessionIsHot = NO;
    }
    
    if ( self.killSessionTimer ) {
        if ( [self.killSessionTimer isValid] ) {
            [self.killSessionTimer invalidate];
        }
        self.killSessionTimer = nil;
    }
    
    NSTimeInterval seconds = [self secondsBehindLive];
    NSString *pt = @"";
    if ( seconds > kAllowableDriftCeiling ) {
        pt = [NSDate prettyTextFromSeconds:seconds];
    } else {
        pt = @"LIVE";
    }
    
    NSString *literalValue = [NSString stringWithFormat:@"%ld",(long)seconds];
    
    Program *p = self.currentProgram;
    
    NSString *title = @"[UNKNOWN]";
    if ( p.title ) {
        title = p.title;
    }

    
#if !TARGET_IPHONE_SIMULATOR
    
    NSString *plus = [[UXmanager shared].settings userHasSelectedXFS] ? @"KPCC Plus" : @"KPCC Live";
    
    
    [[AnalyticsManager shared] beginTimedEvent:@"liveStreamPlay"
                                    parameters:@{
                                                 @"behindLiveStatus" : pt,
                                                 @"behindLiveSeconds" : literalValue,
                                                 @"programTitle" : title,
                                                 @"streamId" : plus
                                                 }];
    
    [[AnalyticsManager shared] nielsenPlay];

#endif
    
    
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

- (void)startAudioSession {
    if ( [[AudioManager shared] currentAudioMode] == AudioModeLive ) {
        [self startLiveSession];
    } else if ( [[AudioManager shared] currentAudioMode] == AudioModeOnDemand ) {
        [self startOnDemandSession];
    }
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
    
    [self trackLiveSession];
    
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
    
    if ( [self sessionIsBehindLive] ) {
        [self setSessionPausedDate:[[AudioManager shared].audioPlayer.currentItem currentDate]];
    } else {
        [self setSessionPausedDate:[NSDate date]];
    }
    
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    NSTimeInterval sessionLength = fabs(now - self.liveStreamSessionBegan);
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
    
    
#if !TARGET_IPHONE_SIMULATOR
    [[AnalyticsManager shared] logEvent:@"liveStreamPause"
                         withParameters:@{ @"kpccSessionId" : sid,
                                           @"programTitle" : title,
                                           @"sessionLength" : pt,
                                           @"sessionLengthInSeconds" : [NSString stringWithFormat:@"%ld",(long)sessionLength] }];
    [self handlePauseEventAgainstSessionAudio];
#endif
    
    self.sessionIsHot = NO;
    self.liveSessionID = nil;
    return sid;
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

    
    NSString *sid = self.odSessionID;
    if ( !sid ) {
        NSString *ct = [NSString stringWithFormat:@"%ld",(long)[[NSDate date] timeIntervalSince1970]];
        sid = [Utils sha1:ct];
    }
    
    BOOL timed = NO;
    
    NSString *event = @"";
    switch (reason) {
        case OnDemandFinishedReasonEpisodeEnd:
            event = @"episodeCompleted";
            break;
        case OnDemandFinishedReasonEpisodePaused:
            event = @"episodePaused";
            timed = YES;
            break;
        case OnDemandFinishedReasonEpisodeSkipped:
            event = @"episodeSkipped";
            break;
        default:
            break;
    }
    
    [[AnalyticsManager shared] logEvent:event
                         withParameters:[[AnalyticsManager shared] typicalOnDemandEpisodeInformation]];
    
    if ( timed ) {
        [self handlePauseEventAgainstSessionAudio];
    } else {
        [[AnalyticsManager shared] nielsenStop];
    }
    
    self.odSessionIsHot = NO;
    self.odSessionID = nil;
    return sid;
}

- (CGFloat)acceptableBufferWindow {
    NSTimeInterval buffer = [self bufferLength];
    return buffer+(20.0f*60.0f);
}

- (BOOL)dateIsReasonable:(NSDate *)date {
    return [date isWithinTimeFrame:[self acceptableBufferWindow]
                            ofDate:[NSDate date]];
}

#pragma mark - Sleep Timer
- (BOOL)sleepTimerActive {
    return self.sleepTimerArmed;
}

- (void)armSleepTimerWithSeconds:(NSInteger)seconds completed:(CompletionBlock)completed {
    
    [self disarmSleepTimerWithCompletion:nil];
#ifdef DEBUG
    seconds = 65;
#endif
    self.originalSleepTimerRequest = seconds;
    self.remainingSleepTimerSeconds = seconds;

    /*self.sleepTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                       target:self
                                                     selector:@selector(tickSleepTimer)
                                                     userInfo:nil
                                                      repeats:YES];*/
    self.sleepTimerArmed = YES;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"sleep-timer-armed"
                                                        object:nil];
    
    if ( completed ) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completed();
            
            [[AnalyticsManager shared] logEvent:@"sleepTimerArmed"
                                 withParameters:nil];
            
        });
    }
    
}

- (void)tickSleepTimer {
    self.remainingSleepTimerSeconds = self.remainingSleepTimerSeconds - 1;
    if ( self.remainingSleepTimerSeconds <= 0 ) {
        [self disarmSleepTimerWithCompletion:^{
            self.remainingSleepTimerSeconds = 300;
        }];
        [[AudioManager shared] adjustAudioWithValue:-.045 completion:^{
            [[AudioManager shared] stopAllAudio];
            
            [[AnalyticsManager shared] logEvent:@"sleepTimerFired"
                                 withParameters:nil];
        }];
        return;
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"sleep-timer-ticked"
                                                        object:nil];
}

- (void)cancelSleepTimerWithCompletion:(CompletionBlock)completed {
    [[AnalyticsManager shared] logEvent:@"sleepTimerCanceled"
                         withParameters:nil];
    [self disarmSleepTimerWithCompletion:completed];
}

- (void)disarmSleepTimerWithCompletion:(CompletionBlock)completed {
    if ( self.sleepTimer ) {
        if ( [self.sleepTimer isValid] ) {
            [self.sleepTimer invalidate];
        }
        self.sleepTimer = nil;
    }
    
    self.sleepTimerArmed = NO;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"sleep-timer-disarmed"
                                                        object:nil];
    
    if ( completed ) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completed();
        });
    }
}

#pragma mark - Cache
- (void)resetCache {
    
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
    [[NSNotificationCenter defaultCenter] postNotificationName:@"program-has-changed"
                                                        object:nil
                                                      userInfo:nil];
    
    completed(p);
    

    
    return;
#endif
    
    NSString *urlString = [NSString stringWithFormat:@"%@/schedule/at?time=%d",kServerBase,(int)[date timeIntervalSince1970]];
    [[NetworkManager shared] requestFromSCPRWithEndpoint:urlString completion:^(id returnedObject) {
        // Create Program and insert into managed object context
        if ( returnedObject && [(NSDictionary*)returnedObject count] > 0 ) {
            self.programFetchFailoverCount = 0;
            if ( completed ) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    Program *programObj = [Program insertProgramWithDictionary:returnedObject
                                                        inManagedObjectContext:[[ContentManager shared] managedObjectContext]];
                    
                    [[ContentManager shared] saveContext];
                    
                    completed(programObj);
                });
            }
        } else {
            
            if ( self.programFetchFailoverCount < 3 ) {
                self.programFetchFailoverCount++;
                // Don't allow nil right now, do a failover
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self fetchProgramAtDate:date completed:completed];
                });
            } else {
                self.programFetchFailoverCount = 0;
                dispatch_async(dispatch_get_main_queue(), ^{
                    if ( completed ) {
                        completed(nil);
                    }
                });
            }
            
        }
    }];
    
}

- (void)fetchCurrentProgram:(CompletionBlockWithValue)completed {
    
    if ( ![[UXmanager shared] onboardingEnding] && ![[UXmanager shared].settings userHasViewedOnboarding] ) {
        return;
    }
    
    NSDate *ct = [self vNow];
    [self fetchProgramAtDate:ct completed:^(id returnedObject) {
#ifdef TESTING_SCHEDULE
        returnedObject = nil;
#endif
        if ( returnedObject ) {
            Program *programObj = (Program*)returnedObject;
            BOOL touch = NO;
            if ( self.currentProgram ) {
                if ( !SEQ(self.currentProgram.program_slug,
                          programObj.program_slug) ) {
                    touch = YES;
                }
            } else if ( programObj ) {
                touch = YES;
            }
            
            if ( self.genericImageForProgram && programObj ) {
                touch = YES;
                self.genericImageForProgram = NO;
            }
            
            self.currentProgram = programObj;
            if ( touch ) {
                [[NSNotificationCenter defaultCenter] postNotificationName:@"program-has-changed"
                                                                    object:nil
                                                                  userInfo:nil];
            }
            
            [self xFreeStreamIsAvailableWithCompletion:nil];
            
            completed(programObj);
            
        } else {
            
            // Create a fake program to simulate live
            
            NSDate *now = [self vNow];
            NSDictionary *bookends = [now bookends];
            
            NSString *endsAt = [NSDate stringFromDate:bookends[@"bottom"]
                                           withFormat:@"yyyy-MM-dd'T'HHmmssZZZ"];
            NSString *top = [NSDate stringFromDate:bookends[@"top"]
                                        withFormat:@"yyyy-MM-dd'T'HHmmssZZZ"];
            
            Program *gp = [Program insertProgramWithDictionary:@{ @"title" : kMainLiveStreamTitle,
                                                                  @"ends_at" : endsAt,
                                                                  @"starts_at" : top,
                                                                  @"soft_starts_at" : top,
                                                                  @"is_recurring" : @(NO),
                                                                  @"public_url" : @"http://scpr.org",
                                                                  @"program" : @{ @"slug" : @"kpcc-live" }
                                                                  }
                                        inManagedObjectContext:[[ContentManager shared] managedObjectContext]];
            
            [gp setStarts_at:bookends[@"top"]];
            [gp setEnds_at:bookends[@"bottom"]];
            [gp setSoft_starts_at:bookends[@"top"]];
            [gp setTitle:kMainLiveStreamTitle];
            
            [[ContentManager shared] saveContext];
            
            self.currentProgram = gp;
            
            [[NSNotificationCenter defaultCenter] postNotificationName:@"program-has-changed"
                                                                object:nil
                                                              userInfo:nil];
            
            completed(gp);
            
        }
            

    }];

}

- (void)fetchScheduleForTodayAndTomorrow:(CompletionBlockWithValue)completed {
    
    NSDate *now = [[AudioManager shared].audioPlayer.currentItem currentDate];
    if ( !now ) {
        now = [NSDate date];
    }
    
    NSDateComponents *comps = [[NSCalendar currentCalendar] components:NSCalendarUnitYear|NSCalendarUnitDay|NSCalendarUnitMonth|NSCalendarUnitHour|NSCalendarUnitMinute|NSCalendarUnitSecond
                                                              fromDate:now];
    [comps setHour:23];
    [comps setMinute:59];
    [comps setMinute:59];
    
    NSDate *tonight = [[NSCalendar currentCalendar] dateFromComponents:comps];
    NSTimeInterval timeUntilMidnight = [tonight timeIntervalSince1970] - [now timeIntervalSince1970];
    timeUntilMidnight += 60*60*24;
    
    NSString *endpoint = [NSString stringWithFormat:@"%@/schedule?start_time=%ld&length=%ld",kServerBase,(long)[now timeIntervalSince1970],(long)timeUntilMidnight];
    [[NetworkManager shared] requestFromSCPRWithEndpoint:endpoint completion:^(id returnedObject) {
        
        if ( completed ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completed(returnedObject);
            });
        }
        
    }];
    
    
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

- (void)checkProgramUpdate:(BOOL)force {

    if ( [[AudioManager shared] currentAudioMode] == AudioModeOnDemand ) return;
    
    if ( force ) {
        [self processTimer:nil];
        return;
    }
    
    NSDate *ct = [self vNow];
    NSTimeInterval ctInSeconds = [ct timeIntervalSince1970];
    Program *p = self.currentProgram;
    if ( p ) {
        NSDate *ends = p.ends_at;
        NSTimeInterval eaInSeconds = [ends timeIntervalSince1970];
        if ( (ctInSeconds*1.0f) >= eaInSeconds ) {
            [self processTimer:nil];
        }
    } else {
        [self processTimer:nil];
    }
    
}

#pragma mark - XFS
- (void)xFreeStreamIsAvailableWithCompletion:(CompletionBlock)completion {
 
    /*
    [self setXFreeStreamIsAvailable:NO];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"pledge-drive-status-updated"
                                                        object:nil];
    
    if ( completion ) {
        completion();
    }
    
    return;
    
    



    
    if ( self.numberOfChecks == 2 ) {
        [self setXFreeStreamIsAvailable:NO];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"pledge-drive-status-updated"
                                                            object:nil];
    } else if ( self.numberOfChecks < 2 ) {
        self.numberOfChecks++;
        [self setXFreeStreamIsAvailable:YES];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"pledge-drive-status-updated"
                                                            object:nil];
    }
    
     */

    NSString *endpoint = [NSString stringWithFormat:@"%@/schedule?pledge_status=true",kServerBase];
    NSURL *url = [NSURL URLWithString:endpoint];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    [NSURLConnection sendAsynchronousRequest:request
                                       queue:[[NSOperationQueue alloc] init]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                               
                               NSError *jsonError = nil;
                               
                               if ( !data || connectionError ) {
                                   if ( connectionError ) {
                                       NSLog(@"Connection error : %@",[connectionError localizedDescription]);
                                   }
                                   
                                   [self setXFreeStreamIsAvailable:NO];
                                   
                                   return;
                               }
                               
                               NSDictionary *responseObject = [NSJSONSerialization JSONObjectWithData:data
                                                                                              options:NSJSONReadingMutableLeaves
                                                                                                error:&jsonError];
                               
                               if (responseObject[@"meta"] && [responseObject[@"meta"][@"status"][@"code"] intValue] == 200) {
                                   
                                   if ( responseObject[@"pledge_drive"] ) {
                                       
                                       BOOL updated = [responseObject[@"pledge_drive"] boolValue];

                                       [self setXFreeStreamIsAvailable:updated];
                                       
                                       dispatch_async(dispatch_get_main_queue(), ^{
                                           [[NSNotificationCenter defaultCenter] postNotificationName:@"pledge-drive-status-updated"
                                                                                               object:nil];
                                       });
                                       
                                   } else {
                                       
                                       [self setXFreeStreamIsAvailable:NO];
                                 
                                       dispatch_async(dispatch_get_main_queue(), ^{
                                           [[NSNotificationCenter defaultCenter] postNotificationName:@"pledge-drive-status-updated"
                                                                                               object:nil];
                                       });
                                       
                                   }
                               }
                               
                           }];
 
    
}

- (void)validateXFSToken:(NSString *)token completion:(CompletionBlockWithValue)completion {
    
    PFQuery *q = [PFQuery queryWithClassName:@"PfsUser"];
    [q whereKey:@"pledgeToken" equalTo:token];
    [q findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        
        if ( error || objects.count == 0 ) {
            if ( completion ) {
                completion(@{ @"error" : @"no-match" });
            }
            return;
        }
        
        if ( completion ) {
            PFObject *pfsu = objects.firstObject;
            if ( [pfsu[@"viewsLeft"] intValue] <= 0 ) {
                completion(@{ @"error" : @"no-views-left" });
                return;
            }
            
            if ( objects.firstObject ) {
                completion(@{ @"success" : objects.firstObject });
            }
        }
        
    }];
   
    
}

#pragma mark - Error Handling
- (NSDictionary*)parseErrors {
    NSData *parseErrors = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"pfsu-errors"
                                                                                         ofType:@"json"]];
    NSError *jsonError = nil;
    NSDictionary *errors = [NSJSONSerialization JSONObjectWithData:parseErrors
                                                           options:NSJSONReadingMutableLeaves
                                                             error:&jsonError];
    return errors;
}

#pragma mark - State handling
- (BOOL)virtualLiveAudioMode {
    return ([[AudioManager shared] currentAudioMode] == AudioModeLive || [[AudioManager shared] currentAudioMode] == AudioModeNeutral);
}

- (void)setLastKnownBitrate:(double)lastKnownBitrate {
    double replacedBitrate = _lastKnownBitrate;
    _lastKnownBitrate = lastKnownBitrate;
    if ( replacedBitrate > 0.0 ) {
        if ( fabs(replacedBitrate - _lastKnownBitrate) > 10000.0 ) {
            [[AnalyticsManager shared] logEvent:@"bitRateSwitching"
                                 withParameters:@{ @"lastLoggedBitRate" : @(replacedBitrate),
                                                   @"newBitRate" : @(lastKnownBitrate) }];
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
    return [self virtualSecondsBehindLive] > kVirtualLargeBehindLiveTolerance;
}

- (BOOL)sessionIsExpired {
    
    if ( [[AudioManager shared] currentAudioMode] == AudioModeOnDemand ) return NO;
    if ( [[AudioManager shared] status] == StreamStatusPaused ||
            [[AudioManager shared] status] == StreamStatusStopped ) {
        NSDate *spd = [[SessionManager shared] sessionPausedDate];
        if ( !spd ) {
            spd = [[SessionManager shared] sessionLeftDate];
        }
        
        if ( !spd ) return NO;
        
        NSDate *cit = [[AudioManager shared].audioPlayer.currentItem currentDate];
        if ( [[AudioManager shared] status] != StreamStatusStopped ) {
            if ( !cit ) {
                // Some kind of audio abnormality, so expire this session
                return YES;
            }
        }
        
        NSDate *aux = cit ? [spd earlierDate:cit] : spd;
        if ( !aux || [[NSDate date] timeIntervalSinceDate:aux] > [self bufferLength] ) {
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
    
    Program *cp = self.currentProgram;
    NSDate *soft = cp.soft_starts_at;
    NSDate *hard = cp.starts_at;

#ifndef SUPPRESS_V_LIVE
    NSDate *now = [self vLive];
#else
    NSDate *now = [NSDate date];
#endif
    
    if ( ![self sessionIsBehindLive] ) {
        if ( [[AudioManager shared].audioPlayer.currentItem currentDate] ) {
            now = [[AudioManager shared].audioPlayer.currentItem currentDate];
        }
    }
    
    NSTimeInterval softTI = [soft timeIntervalSince1970];
    NSTimeInterval hardTI = [hard timeIntervalSince1970];
    NSTimeInterval nowTI = [now timeIntervalSince1970];
    if ( nowTI >= hardTI && nowTI <= softTI ) {
        return YES;
    }
    
    return NO;
}

- (BOOL)sessionHasNoProgram {

    if ( SEQ(self.currentProgram.program_slug,@"kpcc-live") ) {
        return YES;
    }
    
    return NO;
}

- (void)invalidateSession {
    if ( [[AudioManager shared] currentAudioMode] == AudioModeOnDemand ) return;
}

- (void)setSessionLeftDate:(NSDate *)sessionLeftDate {
    _sessionLeftDate = sessionLeftDate;
}

- (void)setSessionReturnedDate:(NSDate *)sessionReturnedDate {
    _sessionReturnedDate = sessionReturnedDate;
    if ( sessionReturnedDate && self.sessionLeftDate ) {
        [self handleSessionReactivation];
    }
    
}

- (void)processNotification:(UILocalNotification*)programUpdate {
    
    if ( SEQ([programUpdate alertBody],kUpdateProgramKey) ) {
        [self fetchCurrentProgram:^(id returnedObject) {
            
        }];
    }
}

- (void)processTimer:(NSTimer*)timer {
    [self setUpdaterArmed:YES];
    [self fetchCurrentProgram:^(id returnedObject) {
        
    }];
}

- (void)handleSessionMovingToBackground {
    
    NSString *eventName = @"";
    NSInteger sessionBegan = 0;
    if ( [[AudioManager shared] currentAudioMode] == AudioModeLive ) {
        eventName = @"liveStreamMovedToBackground";
        sessionBegan = self.liveStreamSessionBegan;
    }
    if ( [[AudioManager shared] currentAudioMode] == AudioModeOnDemand ) {
        eventName = @"episodeAudioMovedToBackground";
        sessionBegan = self.onDemandSessionBegan;
    }
    
    self.timeAudioWasPutInBackground = [[NSDate date] timeIntervalSince1970];
    NSTimeInterval diff = self.timeAudioWasPutInBackground - sessionBegan;
    
    [[AnalyticsManager shared] logEvent:eventName
                         withParameters:@{ @"secondsSinceSessionBegan" : @(diff) }
                                  timed:NO];
}

- (void)handleSessionReactivation {
    
    if ( [[AudioManager shared] currentAudioMode] == AudioModeOnboarding ) return;
    if ( ![[UXmanager shared].settings userHasViewedOnboarding] ) return;
    if ( !self.sessionLeftDate || !self.sessionReturnedDate ) return;
    if ( [self sessionIsExpired] ) {
    
        [self expireSession];
        
    } else {
        if ( [[AudioManager shared] status] != StreamStatusPaused ) {
            
            [self checkProgramUpdate:NO];
            if ( [[AudioManager shared] isPlayingAudio] ) {

                NSString *eventName = @"";
                if ( [[AudioManager shared] currentAudioMode] == AudioModeLive ) {
                    eventName = @"liveStreamReturnedToForeground";
                }
                if ( [[AudioManager shared] currentAudioMode] == AudioModeOnDemand ) {
                    eventName = @"episodeAudioReturnedToForeground";
                }
                NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
                NSInteger diff = now - self.timeAudioWasPutInBackground;
                
                [[AnalyticsManager shared] logEvent:eventName
                                     withParameters:@{ @"secondsSinceAppWasBackgrounded" : @(diff) }
                                              timed:NO];
            }
            
        }
    }
    
    self.timeAudioWasPutInBackground = 0.0f;
}

- (void)expireSession {
    self.sessionReturnedDate = nil;
    self.sessionPausedDate = nil;
    self.expiring = YES;
    
    [[AudioManager shared] resetFlags];
    
    if ( [[AudioManager shared] audioPlayer] ) {
        if ( [[AudioManager shared] isPlayingAudio] ) {
            // Shouldn't happen, but...
            [[AudioManager shared] stopAudio];
        }
        [[AudioManager shared] takedownAudioPlayer];
    }
    
    SCPRMasterViewController *master = [[Utils del] masterViewController];
    [master resetUI];
}

- (BOOL)sessionIsInBackground {
    return [[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground;
}

@end
