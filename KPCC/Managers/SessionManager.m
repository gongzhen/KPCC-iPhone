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
        mgr.peakDrift = kAllowableDriftCeiling;
    });
    return mgr;
}

#pragma mark - Session Mgmt
// What is the "live" date for our stream?
- (NSDate*)vLive {

    // FIXME: Is there any context in which we would need live date while in
    // on-demand?
    if ([[AudioManager shared] currentAudioMode] == AudioModeOnDemand) {
        return nil;
    }

    NSDate *live = [[NSDate date] dateByAddingTimeInterval:-90.0f]; // Add in what we know is going to be slightly behind live

    NSDate *plive = [[[AudioManager shared] audioPlayer] liveDate];
    if ( plive != nil ) {
        live = plive;
    }

    return live;
}

// What date are we currently playing?
- (NSDate*)vNow {
    
    NSDate *cd = [[AudioManager shared].audioPlayer currentDate];
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
    NSDate *currentTime = [[AudioManager shared].audioPlayer currentDate];
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
    CGFloat sbl = [[[SessionManager shared] vLive] timeIntervalSince1970] - [[[AudioManager shared].audioPlayer currentDate] timeIntervalSince1970];
    if ( sbl < 0.0f ) {
        sbl = 0.0f;
    }

    return (NSTimeInterval)sbl;
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
    
    ScheduleOccurrence *s = self.currentSchedule;
    
    NSString *title = @"[UNKNOWN]";
    if ( s.title ) {
        title = s.title;
    }

    NSString *plus = [[UXmanager shared].settings userHasSelectedXFS] ? @"KPCC Plus" : @"KPCC Live";
    
    [[AnalyticsManager shared] beginTimedEvent:@"liveStreamPlay"
                                    parameters:@{
                                                 @"behindLiveStatus" : pt,
                                                 @"behindLiveSeconds" : literalValue,
                                                 @"programTitle" : title,
                                                 @"streamId" : plus
                                                 }];

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
    
    NSString *title = self.currentSchedule.title ? self.currentSchedule.title : @"[UNKNOWN]";
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

- (void)startLiveSession {
    if ( self.sessionIsHot ) return;
    
    self.sessionPausedDate = nil;
    @synchronized(self) {
        self.sessionIsHot = YES;
    }
    
    self.liveStreamSessionBegan = (int64_t)[[NSDate date] timeIntervalSince1970];
    
    [self trackLiveSession];
}

- (void)endLiveSession {
    if ( self.rewindSessionWillBegin ) {
        self.rewindSessionWillBegin = NO;
        return;
    }

    [self setSessionPausedDate:[NSDate date]];
    
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    NSTimeInterval sessionLength = fabs(now - self.liveStreamSessionBegan);
    NSString *pt = [NSDate prettyTextFromSeconds:sessionLength];
    if ( sessionLength > 30000 ) return;
    
    NSLog(@"Logging pause event for Live Stream...");
    
    ScheduleOccurrence *s = self.currentSchedule;
    NSString *title = s.title ? s.title : @"[UNKNOWN]";
    
    
    [[AnalyticsManager shared] logEvent:@"liveStreamPause"
                         withParameters:@{ @"programTitle" : title,
                                           @"sessionLength" : pt,
                                           @"sessionLengthInSeconds" : [NSString stringWithFormat:@"%ld",(long)sessionLength] }];

    self.sessionIsHot = NO;
}

- (void)startOnDemandSession {
    if ( self.odSessionIsHot ) return;
    
    @synchronized(self) {
        self.odSessionIsHot = YES;
    }
    
    self.onDemandSessionBegan = (int64_t)[[NSDate date] timeIntervalSince1970];
}

- (void)endOnDemandSessionWithReason:(OnDemandFinishedReason)reason {
    if ( !self.odSessionIsHot ) return;

    NSString *event = @"";
    switch (reason) {
        case OnDemandFinishedReasonEpisodeEnd:
            event = @"episodeCompleted";
            break;
        case OnDemandFinishedReasonEpisodePaused:
            event = @"episodePaused";
            break;
        case OnDemandFinishedReasonEpisodeSkipped:
            event = @"episodeSkipped";
            break;
        default:
            break;
    }
    
    [[AnalyticsManager shared] logEvent:event
                         withParameters:[[AnalyticsManager shared] typicalOnDemandEpisodeInformation]];
    
    self.odSessionIsHot = NO;
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

- (void)armSleepTimerWithSeconds:(NSInteger)seconds completed:(Block)completed {
    
    [self disarmSleepTimerWithCompletion:nil];

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

- (void)cancelSleepTimerWithCompletion:(Block)completed {
    [[AnalyticsManager shared] logEvent:@"sleepTimerCanceled"
                         withParameters:nil];
    [self disarmSleepTimerWithCompletion:completed];
}

- (void)disarmSleepTimerWithCompletion:(Block)completed {
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
- (void)fetchOnboardingProgramWithSegment:(NSInteger)segment completed:(BlockWithObject)completed {
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

- (void)fetchScheduleAtDate:(NSDate *)date completed:(BlockWithObject)completed {
    NSString *urlString = [NSString stringWithFormat:@"%@/schedule/at?time=%d",kServerBase,(int)[date timeIntervalSince1970]];
    [[NetworkManager shared] requestFromSCPRWithEndpoint:urlString completion:^(id object) {
        // Create ScheduleOccurrence and insert into managed object context
        if ( object && [(NSDictionary*)object count] > 0 ) {
            self.programFetchFailoverCount = 0;
            if ( completed ) {
                dispatch_async(dispatch_get_main_queue(), ^{

                    NSManagedObjectContext *context = ContentManager.shared.managedObjectContext;

                    ScheduleOccurrence *scheduleObj = [ScheduleOccurrence newScheduleOccurrenceWithContext:context
                                                                                                dictionary:object];

                    NSLog(@"fetchSched got %@",scheduleObj);
                    
                    if (scheduleObj) {
                        [[ContentManager shared] saveContext];
                    }
                    
                    completed(scheduleObj);
                });
            }
        } else {
            
            if ( self.programFetchFailoverCount < 3 ) {
                self.programFetchFailoverCount++;
                // Don't allow nil right now, do a failover
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self fetchScheduleAtDate:date completed:completed];
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

- (void)fetchCurrentSchedule:(BlockWithObject)completed {
    
    if ( ![[UXmanager shared] onboardingEnding] && ![[UXmanager shared].settings userHasViewedOnboarding] ) {
        return;
    }
    
    NSDate *ct = [self vNow];

    NSLog(@"In fetchCurrentSchedule for %@", ct);

    // do we already have this program?
    if ( self.currentSchedule && [self.currentSchedule containsDate:ct]) {
        NSLog(@"fetchCurrentSchedule returning existing current program.");
        completed(self.currentSchedule);
        return;
    }

    [self fetchScheduleAtDate:ct completed:^(id object) {
#ifdef TESTING_SCHEDULE
        object = nil;
#endif
        if ( object ) {
            ScheduleOccurrence *scheduleObj = (ScheduleOccurrence*)object;

            self.currentSchedule = scheduleObj;

            [[NSNotificationCenter defaultCenter] postNotificationName:@"program-has-changed"
                                                                object:nil
                                                              userInfo:nil];

            [self xFreeStreamIsAvailableWithCompletion:nil];
            
            completed(scheduleObj);
            
        } else {
            
            // Create a fake program to simulate live
            
            NSDate *now = [self vNow];
            NSDictionary *bookends = [now bookends];

            NSManagedObjectContext *context = ContentManager.shared.managedObjectContext;

            ScheduleOccurrence *gs = [ScheduleOccurrence newScheduleOccurrenceWithContext:context
                                                                                    title:kMainLiveStreamTitle
                                                                                  ends_at:bookends[@"bottom"]
                                                                                starts_at:bookends[@"top"]
                                                                           soft_starts_at:bookends[@"top"]
                                                                               public_url:@"http://www.scpr.org"
                                                                             program_slug:@"kpcc-live"];

            if (gs) {

                [[ContentManager shared] saveContext];

                self.currentSchedule = gs;

                [[NSNotificationCenter defaultCenter] postNotificationName:@"program-has-changed"
                                                                    object:nil
                                                                  userInfo:nil];

            }

            completed(gs);
            
        }
            

    }];

}

- (void)fetchScheduleForTodayAndTomorrow:(BlockWithObject)completed {
    
    NSDate *now = [[AudioManager shared].audioPlayer currentDate];
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
    [[NetworkManager shared] requestFromSCPRWithEndpoint:endpoint completion:^(id object) {
        
        if ( completed ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completed(object);
            });
        }
        
    }];
    
    
}

- (void)checkProgramUpdate:(BOOL)force {

    if ( [[AudioManager shared] currentAudioMode] == AudioModeOnDemand ) return;
    
    if ( force ) {
        [self fetchCurrentSchedule:^(id object) {

        }];

        return;
    }

    ScheduleOccurrence *s = self.currentSchedule;
    if ( s && [s containsDate:[self vNow]]) {
        // we're good
    } else {
        [self fetchCurrentSchedule:^(id object) {

        }];
    }
    
}

#pragma mark - XFS
- (void)xFreeStreamIsAvailableWithCompletion:(Block)completion {

    BOOL available = NO;

    if ([AudioManager shared].xfsCheckComplete) {
        // KPCC Plus (XFS) is available if a) we have xfsDriveStart and xfsDriveEnd
        // in AudioManager and b) now is between those two dates

        if ([AudioManager shared].xfsDriveStart != nil && [AudioManager shared].xfsDriveEnd != nil) {
            // is now between these dates?
            if (
                [[AudioManager shared].xfsDriveStart timeIntervalSinceNow] <= 0
                && [[AudioManager shared].xfsDriveEnd timeIntervalSinceNow] > 0
                ) {
                // YES!
                available = YES;
            } else {
                // NO
            }
        } else {
            // NO
        }

        // cache this info locally
        [[UXmanager shared].settings setXfsAvailable:available];
        [[UXmanager shared].settings setXfsStreamUrl:[AudioManager shared].xfsStreamUrl];
        [[UXmanager shared] persist];

    } else {
        // our Parse load hasn't completed, so use cached information if we have it
        BOOL cavail = [[UXmanager shared].settings xfsAvailable];

        if (cavail) {
            CLS_LOG(@"Using cached availability for XFS stream.");
            available = YES;
            [AudioManager shared].xfsStreamUrl = [[UXmanager shared].settings xfsStreamUrl];
        }
    }

    // last check... not available unless we have a stream URL
    if ([AudioManager shared].xfsStreamUrl == nil) {
        available = NO;
    }

    [self setXFreeStreamIsAvailable:available];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"pledge-drive-status-updated"
                                                        object:nil];
    
    if ( completion ) {
        completion();
    }    
}

- (void)validateXFSToken:(NSString *)token completion:(BlockWithObject)completion {
    
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
    // FIXME
//    for ( NSValue *str in [[[AudioManager shared] audioPlayer] currentItem].seekableTimeRanges ) {
//        CMTimeRange r = [str CMTimeRangeValue];
//        if ( labs(CMTimeGetSeconds(r.duration) > kStreamCorrectionTolerance ) ) {
//            stableDuration = CMTimeGetSeconds(r.duration);
//        }
//    }

    return stableDuration;
    
}

- (BOOL)sessionIsBehindLive {
    // FIXME: This should be something internal to the session
    switch ([[[AudioManager shared] status] status]) {
        case AudioStatusNew:
        case AudioStatusStopped:
            return NO;
        default:
            return [self virtualSecondsBehindLive] > kVirtualLargeBehindLiveTolerance;
    }
}

- (BOOL)sessionIsInRecess {
    
   return [self sessionIsInRecess:YES];
    
}

- (BOOL)sessionIsInRecess:(BOOL)respectPause {
    if ( [[AudioManager shared] currentAudioMode] == AudioModeOnDemand ) return NO;
    if ( [[AudioManager shared] currentAudioMode] == AudioModeOnboarding ) return NO;
    
    ScheduleOccurrence *cs = self.currentSchedule;
    NSDate *soft = cs.soft_starts_at;
    NSDate *hard = cs.starts_at;

#ifndef SUPPRESS_V_LIVE
    NSDate *now = [self vLive];
#else
    NSDate *now = [NSDate date];
#endif
    
    if ( ![self sessionIsBehindLive] ) {
        if ( [[AudioManager shared].audioPlayer currentDate] ) {
            now = [[AudioManager shared].audioPlayer currentDate];
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

    if ( SEQ(self.currentSchedule.program_slug,@"kpcc-live") ) {
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

- (void)processNotification:(UILocalNotification*)programUpdate {
    
    if ( SEQ([programUpdate alertBody],kUpdateProgramKey) ) {
        [self fetchCurrentSchedule:^(id object) {
            
        }];
    }
}

- (void)processTimer:(NSTimer*)timer {
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

- (void)handleSessionMovingToForeground {
    
    if ( [[AudioManager shared] currentAudioMode] == AudioModeOnboarding ) return;
    if ( ![[UXmanager shared].settings userHasViewedOnboarding] ) return;

    if ( !self.sessionLeftDate ) return;

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

    self.timeAudioWasPutInBackground = 0.0f;
    _sessionLeftDate = nil;
}

- (void)expireSessionIfExpired:(BOOL)willPlay {
    // A session should be expired if the user last played audio more than an hour ago
    if ([self sessionIsExpired]) {
        CLS_LOG(@"Marking session expired.");
        [self expireSession:willPlay];
    }
}

- (BOOL)sessionIsExpired {
    // session expiration only applies to the live stream
    if ( [[AudioManager shared] currentAudioMode] != AudioModeLive ) return NO;

    // a session can only expire while it is paused or stopped
    if ( [[[AudioManager shared] status] status] == AudioStatusPaused ||
        [[[AudioManager shared] status] status] == AudioStatusStopped ) {

        // when was the session last active?
        NSDate *spd = [[SessionManager shared] sessionPausedDate];

        if ( !spd ) return YES;

        double secs = -1 * [spd timeIntervalSinceNow];

        CLS_LOG(@"sessionIsExpired: Returning after %f seconds.",secs);

        // a session is expired if it was last active more than one hour ago

        if (secs > kSessionIdleExpiration) {
            // log a mixpanel event
            [[AnalyticsManager shared] logEvent:@"liveStreamSessionExpired"
                                 withParameters:@{ @"idle_seconds" : [NSNumber numberWithDouble:secs] }];

            return YES;
        }

        // FIXME: check against buffer?
        
    }
    
    return NO;
    
}

- (void)expireSession:(BOOL)willPlay {
    self.sessionReturnedDate = nil;
    self.sessionPausedDate = nil;
    self.expiring = YES;
    self.lastPrerollTime = nil;

    [[AudioManager shared] takedownAudioPlayer];

    SCPRMasterViewController *master = [[Utils del] masterViewController];

    if (!willPlay) {
        [master resetUI];
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:@"session-reset"
                                                        object:nil];
}

- (BOOL)sessionIsInBackground {
    return [[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground;
}

@end
