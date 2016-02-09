//
//  AnalyticsManager.m
//  KPCC
//
//  Created by John Meeker on 3/21/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "AnalyticsManager.h"
#import "AudioManager.h"
#import "NetworkManager.h"
#import "NSDate+Helper.h"
#import "SessionManager.h"
#import "Program.h"
#import "QueueManager.h"
#import "UXmanager.h"
#import <Google/Analytics.h>
#import "SCPRAppDelegate.h"

static AnalyticsManager *singleton = nil;

@interface AnalyticsManager ()

- (NSString*)stringForInterruptionCause:(NetworkHealth)cause;

@end

@implementation AnalyticsManager

+ (AnalyticsManager*)shared {
    if (!singleton) {
        @synchronized(self) {
            singleton = [[AnalyticsManager alloc] init];
            [singleton buildQualityMap];
            singleton.progressMap = [NSMutableDictionary new];
        }
    }
    return singleton;
}

- (void)setup {
    
#ifdef RELEASE
    [Fabric with:@[[Crashlytics class]]];
#endif
    
    NSDictionary *globalConfig = [Utils globalConfig];
    
    NSString *token = globalConfig[@"Flurry"][@"key"];
    [Flurry setCrashReportingEnabled:NO];
    [Flurry setDebugLogEnabled:NO];
    [Flurry startSession:token];
    [Flurry setBackgroundSessionEnabled:NO];

    self.mxp = [Mixpanel sharedInstanceWithToken:globalConfig[@"Mixpanel"][@"token"]];

    NSString *uuid = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    [self.mxp identify:uuid];
    [self.mxp.people set:@{ @"uuid" : uuid }];
    
    // Configure tracker from GoogleService-Info.plist.
    NSError *configureError;
    [[GGLContext sharedInstance] configureWithError:&configureError];
    NSAssert(!configureError, @"Error configuring Google services: %@", configureError);
    
//#ifndef SUPPRESS_NIELSEN_TRACKING
//    NSString *theAppVersion = [Utils prettyVersion];
//    
//    NSDictionary* appInformation = @{
//                                     @"appid": @"TO BE PROVIDED",
//                                     @"appversion": theAppVersion,
//                                     @"appname": @"KPCC iPhone",
//                                     @"sfcode": @"us"
//                                     };
//    
//    
//    
//    NSData* jsonDataAppInfo = [NSJSONSerialization dataWithJSONObject:appInformation options:0 error:nil];
//    NSString* jsonStringAppInfo = [[NSString alloc] initWithBytes:[jsonDataAppInfo bytes] length:[jsonDataAppInfo length] encoding:NSUTF8StringEncoding];
//    
//
//    self.nielsenTracker = [[NielsenAppApi sharedInstance] initWithAppInfo:jsonStringAppInfo];
//
//#endif

    
}

- (void)buildQualityMap {
   
#ifdef DEBUG
    [[UXmanager shared].settings setUserQualityMap:nil];
    [[UXmanager shared].settings setUserPoints:@0];
    [[UXmanager shared].settings setHistoryBeganAt:nil];
    [[UXmanager shared] persist];
#endif
    
    NSDate *today = [NSDate midnightThisMorning];
    NSMutableDictionary *incumbentMap = [[UXmanager shared].settings userQualityMap];
    if ( !incumbentMap ) {
        incumbentMap = [NSMutableDictionary new];

        NSDateComponents *compos = [[NSCalendar currentCalendar] components:NSCalendarUnitMonth|NSCalendarUnitYear|NSCalendarUnitDay
                                                                   fromDate:today];
        NSInteger day = [compos day];
        
        NSInteger start = 0;
        NSInteger finish = 15;
        if ( day > 15 ) {
            NSCalendar *cal = [NSCalendar currentCalendar];
            NSRange rng = [cal rangeOfUnit:NSDayCalendarUnit inUnit:NSMonthCalendarUnit forDate:[NSDate date]];
            NSUInteger numberOfDaysInMonth = rng.length;
            finish = numberOfDaysInMonth;
            start = 15;
        }
        
        for ( unsigned i = start; i < finish; i++ ) {
            [compos setDay:i+1];
            NSDate *monthDayDate = [[NSCalendar currentCalendar] dateFromComponents:compos];
            NSString *monthDay = [NSDate stringFromDate:monthDayDate
                                             withFormat:[NSDate simpleDateFormat]];
     
            NSNumber *value = @0;
#ifdef DEBUG
            NSInteger randy = arc4random() % 100;
            if ( randy <= 45 ) {
                value = @1;
            }
#endif
            if ( i > day ) value = @0;
            
            incumbentMap[monthDay] = value;

        }

    }
    
    NSArray *dateKeys = [incumbentMap allKeys];
    NSArray *sortedKeys = [dateKeys sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        
        NSString *s1 = (NSString*)obj1;
        NSString *s2 = (NSString*)obj2;
        NSDate *d1 = [NSDate dateFromString:s1 withFormat:[NSDate simpleDateFormat]];
        NSDate *d2 = [NSDate dateFromString:s2 withFormat:[NSDate simpleDateFormat]];
        return [d1 compare:d2];
        
    }];
    
    if ( ![[UXmanager shared].settings historyBeganAt] ) {
        NSString *startCapStr = sortedKeys.firstObject;
        NSDate *startCap = [NSDate dateFromString:startCapStr
                                     withFormat:[NSDate simpleDateFormat]];
        [[UXmanager shared].settings setHistoryBeganAt:startCap];
    }
    
    NSString *endCapStr = sortedKeys.lastObject;
    NSDate *endCap = [NSDate dateFromString:endCapStr
                                 withFormat:[NSDate simpleDateFormat]];
    
    if ( [today timeIntervalSince1970] > [endCap timeIntervalSince1970] ) {
        [[UXmanager shared].settings setUserQualityMap:nil];
        [[UXmanager shared] persist];
        [self buildQualityMap];
        return;
    }
    
    NSString *currentKey = [NSDate stringFromDate:today
                                       withFormat:[NSDate simpleDateFormat]];
    incumbentMap[currentKey] = @1;
    
    [[UXmanager shared].settings setUserQualityMap:incumbentMap];
    [[UXmanager shared] persist];
    
    [self applyUserQuality];
    
    
}

- (void)applyUserQuality {
    NSMutableDictionary *incumbentMap = [[UXmanager shared].settings userQualityMap];
    NSInteger positives = 0;
    for ( NSString *key in [incumbentMap allKeys] ) {
        positives += [incumbentMap[key] intValue];
    }
    
    NSDate *history = [[UXmanager shared].settings historyBeganAt];
    if ( !history ) {
        history = [NSDate date];
    }
    
    NSNumber *currentPoints = [[UXmanager shared].settings userPoints];
    positives += [currentPoints intValue];
    
    NSInteger numberOfDays = abs([[NSDate midnightThisMorning] daysBetween:history]);
    CGFloat percent = (positives / (numberOfDays * 1.0f))*100.0;
    
    [[UXmanager shared].settings setUserPoints:@(positives)];
    [[UXmanager shared] persist];
    
    NSString *userQuality = [NSString stringWithFormat:@"%ld",(long)floorf(percent)];

    GAI *gai = [GAI sharedInstance];
    id<GAITracker> tracker = [gai defaultTracker];
    
    NSString *metricValue = userQuality;
    [tracker set:[GAIFields customMetricForIndex:1] value:metricValue];
    
    [self.mxp.people set:@{ @"userQuality" : userQuality }];
    
    NSLog(@"User quality : %@",userQuality);
}

- (void)setAccessLog:(AVPlayerItemAccessLogEvent *)accessLog {
    _accessLog = accessLog;
    if ( accessLog ) {
        self.accessLogReceivedAt = [NSDate date];
    }
}

- (void)setErrorLog:(AVPlayerItemErrorLogEvent *)errorLog {
    _errorLog = errorLog;
    if ( errorLog ) {
        self.errorLogReceivedAt = [NSDate date];
    }
}

- (void)trackHeadlinesDismissal {
    [[AnalyticsManager shared] endTimedEvent:@"userIsViewingHeadlines"];
}


- (void)beginTimedEvent:(NSString *)event parameters:(NSDictionary *)parameters {
    [self logEvent:event withParameters:parameters timed:YES];
}

- (void)endTimedEvent:(NSString *)event {
}

- (void)logEvent:(NSString *)event withParameters:(NSDictionary *)parameters {
    [self logEvent:event withParameters:parameters timed:NO];
}

- (void)logEvent:(NSString *)event withParameters:(NSDictionary *)parameters timed:(BOOL)timed {
    
    NSDictionary *cookedParams = [self logifiedParamsList:parameters];
    
    if ( timed ) {
    }
    
    Mixpanel *mxp = [Mixpanel sharedInstance];
    [mxp track:event properties:cookedParams];
    
    NSString *category = [self categoryForEvent:event];
    GAI *gai = [GAI sharedInstance];
    id<GAITracker> tracker = [gai defaultTracker];
    
    [tracker send:[[GAIDictionaryBuilder createEventWithCategory:category
                                                          action:event
                                                           label:[self buildGALabelStringFromParams:parameters]
                                                           value:nil] build]];
    
}

- (NSString*)buildGALabelStringFromParams:(NSDictionary *)params {
    
    NSString *total = @"";
    
    NSArray *sorted = [[params allKeys] sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        
        NSString *k1 = (NSString*)obj1;
        NSString *k2 = (NSString*)obj2;
        return [k1 compare:k2];
        
    }];
    
    for ( unsigned i = 0; i < [sorted count]; i++ ) {
        
        NSString *key = sorted[i];
        
        if ( !SEQ(total,@"") ) {
            total = [total stringByAppendingString:@"|-|"];
        }
        
        total = [total stringByAppendingFormat:@"%@:%@",key,params[key]];
        
    }
    
    if ( !SEQ(total,@"") ) {
        return total;
    }
    
    return nil;
    
}

- (void)screen:(NSString *)screen {
    GAIDictionaryBuilder *builder = [GAIDictionaryBuilder createScreenView];
    GAI *gai = [GAI sharedInstance];
    id<GAITracker> tracker = [gai defaultTracker];
    [tracker set:kGAIScreenName
           value:screen];
    [tracker send:[builder build]];
}

- (void)gaSessionStartWithScreenView:(NSString*)screenName {
    if ( self.gaSessionStarted ) return;
    
    GAIDictionaryBuilder *builder = [GAIDictionaryBuilder createScreenView];
    GAI *gai = [GAI sharedInstance];
    id<GAITracker> tracker = [gai defaultTracker];
    [builder set:@"start" forKey:kGAISessionControl];
    [tracker set:kGAIScreenName
           value:screenName];
    
    [tracker send:[builder build]];
    self.gaSessionStarted = YES;
}

- (void)gaSessionEnd {
    GAIDictionaryBuilder *builder = [GAIDictionaryBuilder createScreenView];
    GAI *gai = [GAI sharedInstance];
    id<GAITracker> tracker = [gai defaultTracker];
    [builder set:@"start" forKey:kGAISessionControl];
    [tracker set:kGAIScreenName
           value:@"Session End"];
    [tracker send:[builder build]];
    
    self.gaSessionStarted = NO;
}

- (void)logScreenView:(NSString *)screenName {
    GAI *gai = [GAI sharedInstance];
    id<GAITracker> tracker = [gai defaultTracker];
    [tracker set:kGAIScreenName
           value:screenName];
    [tracker send:[[GAIDictionaryBuilder createScreenView] build]];
}

#pragma mark - Track episode progress
- (void)clearEpisodeProgress {
    [self.progressMap removeAllObjects];
}

- (void)trackEpisodeProgress:(double)progress {
    NSInteger cooked = floor(progress * 100);
    if ( cooked >= 25 && !self.progressMap[@"25"] ) {
        [self logEvent:@"episodeReached25percent"
        withParameters:[self typicalOnDemandEpisodeInformation]];
        self.progressMap[@"25"] = @1;
    }
    if ( cooked >= 50 && !self.progressMap[@"50"] ) {
        [self logEvent:@"episodeReachedMidwayPoint"
        withParameters:[self typicalOnDemandEpisodeInformation]];
        self.progressMap[@"50"] = @1;
    }
    if ( cooked >= 75 && !self.progressMap[@"75"] ) {
        [self logEvent:@"episodeReached75percent"
        withParameters:[self typicalOnDemandEpisodeInformation]];
        self.progressMap[@"75"] = @1;
    }
}

- (NSString*)categoryForEvent:(NSString *)event {
    if ( [event rangeOfString:@"liveStream"].location != NSNotFound ) {
        return @"Live Stream";
    }
    if ( [event rangeOfString:@"episode"].location != NSNotFound ) {
        return @"On Demand";
    }
    if ( [event rangeOfString:@"user"].location == 0 ) {
        return @"User Interaction";
    }
    if ( [event rangeOfString:@"alarm"].location == 0 ) {
        return @"Alarm / Sleep Timer";
    }
    if ( [event rangeOfString:@"sleep"].location == 0 ) {
        return @"Alarm / Sleep Timer";
    }
    return @"General";
}

- (void)failStream:(NetworkHealth)cause comments:(NSString *)comments {
    [self failStream:cause comments:comments force:NO];
}

- (void)failStream:(NetworkHealth)cause comments:(NSString *)comments force:(BOOL)force {
    
    if ( !comments || SEQ(comments,@"") ) return;
    
//    self.accessLog = [[AudioManager shared].audioPlayer.currentItem accessLog];
//    self.errorLog = [[AudioManager shared].audioPlayer.currentItem errorLog];

    if ( self.analyticsSuspensionTimer ) {
        if ( [self.analyticsSuspensionTimer isValid] ) {
            [self.analyticsSuspensionTimer invalidate];
        }
        self.analyticsSuspensionTimer = nil;
    }
    
    self.lastErrorLoggedComments = comments;
    
    NSMutableDictionary *analysis = [@{ @"cause" : [self stringForInterruptionCause:cause],
                                        @"details" : comments,
                                        @"networkInfo" : [[NetworkManager shared] networkInformation]
                                        } mutableCopy];
    
    NSLog(@"Sending stream failure report to analytics");
    [self logEvent:@"streamException" withParameters:analysis];
    
    
}

- (NSDictionary*)typicalLiveProgramInformation {
    
    NSMutableDictionary *programInfo = [NSMutableDictionary new];
    ScheduleOccurrence *p = [[SessionManager shared] currentSchedule];
    if ( p ) {
        NSString *pTitle = p.title;
        if ( pTitle ) {
            programInfo[@"program"] = pTitle;
        }
    }
    
    NSTimeInterval streamStart = [[SessionManager shared] liveStreamSessionBegan];
    NSTimeInterval duration = [[NSDate date] timeIntervalSince1970] - streamStart;
    if ( duration > 0 ) {
        programInfo[@"elapsedTime"] = [NSString stringWithFormat:@"%ld",(long)duration];
    }
    
    return programInfo;
}

- (NSDictionary*)typicalOnDemandEpisodeInformation {
    AudioChunk *ac = [[QueueManager shared] currentChunk];
    NSString *episodeTitle = ac.audioTitle;
    NSString *programTitle = ac.programTitle;
    
    NSMutableDictionary *params = [NSMutableDictionary new];
    if ( episodeTitle ) {
        params[@"episodeTitle"] = episodeTitle;
    }
    if ( programTitle ) {
        params[@"programTitle"] = programTitle;
    }
    
    double duration = [ac.audioDuration doubleValue];
    params[@"duration"] = @(duration);
    params[@"currentProgress"] = @([[QueueManager shared] globalProgress]);
    
    return params;
}

- (NSDictionary*)logifiedParamsList:(NSDictionary *)originalParams {
    
    NSMutableDictionary *nParams = [NSMutableDictionary new];
    if ( originalParams ) {
        nParams = [originalParams mutableCopy];
    }
    if ( self.errorLog ) {

        if ( self.errorLog.playbackSessionID ) {
            nParams[@"avPlayerSessionId"] = self.errorLog.playbackSessionID;
        }
        self.errorLog = nil;
    }
    if ( self.accessLog ) {
        self.accessLog = nil;
    }
    
    if ( !nParams[@"avPlayerSessionId"] ) {
        NSString *avpid = [[AudioManager shared] avPlayerSessionString];
        if ( avpid ) {
            nParams[@"avPlayerSessionId"] = avpid;
        }
    }
    nParams[@"UID"] = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    
    return nParams;
}

- (void)clearLogs {
    self.accessLog = nil;
    self.errorLog = nil;
}

- (NSString*)stringForInterruptionCause:(NetworkHealth)cause {
    NSString *english = @"";
    switch (cause) {
        case NetworkHealthStreamingServerDown:
            english = [NSString stringWithFormat:@"Device could not communicate with streaming server : %@",kHLS];
            break;
        case NetworkHealthContentServerDown:
            english = [NSString stringWithFormat:@"Device could not communicate with content server : %@",kServerBase];
            break;
        case NetworkHealthNetworkDown:
            english = @"Internet connectivity is non-existent";
            break;
        case NetworkHealthAllOK:
        case NetworkHealthNetworkOK:
        case NetworkHealthServerOK:
        case NetworkHealthUnknown:
        default:
            english = @"Network was reachable at time of failure";
            break;
    }
    
    return english;
}

//#pragma mark - Nielsen
//- (void)nielsenPlay {
//    [self.nielsenTracker play:[self nielsenInfoForCurrentAudio]];
//    [self.nielsenTracker loadMetadata:[self nielsenInfoForKPCC]];
//}
//
//- (void)nielsenStop {
//    [self.nielsenTracker stop];
//}
//
//- (void)nielsenTrack {
//    if ( [[AudioManager shared] currentAudioMode] == AudioModeLive ) {
//        [self.nielsenTracker playheadPosition:[[[SessionManager shared] vNow] timeIntervalSince1970]];
//    } else {
//        NSInteger seconds = CMTimeGetSeconds([[AudioManager shared].audioPlayer currentTime]);
//        [self.nielsenTracker playheadPosition:seconds];
//    }
//}
//
//- (NSString*)nielsenInfoForCurrentAudio {
//    if ( [[AudioManager shared] currentAudioMode] == AudioModeLive ) {
//        ScheduleOccurrence *p = [[SessionManager shared] currentSchedule];
//        if ( p ) {
//            return [NSString stringWithFormat:@"{ \"channelName\" : \"%@\" }",p.title];
//        } else {
//            return [NSString stringWithFormat:@"{ \"channelName\" : \"KPCC Live\" }"];
//        }
//    } else {
//        AudioChunk *ac = [[QueueManager shared] currentChunk];
//        if ( ac ) {
//            return [NSString stringWithFormat:@"{ \"channelName\" : \"%@\" }",ac.programTitle];
//        } else {
//            return [NSString stringWithFormat:@"{ \"channelName\" : \"KPCC OD\" }"];
//        }
//    }
//    
//    return @"{ \"channelName\" : \"KPCC\" }";
//}
//
//- (NSString*)nielsenInfoForKPCC {
//    return @"{ \"dataSrc\" : \"cms\", \"type\" : \"radio\", \"assetid\" : \"KPCC-FM\", \"stationType\" : \"1\", \"provider\" : \"KPCC iPhone\" }";
//}


#pragma mark - Events

- (void)trackSeekUsageWithType:(ScrubbingType)type {
    NSString *eventName = @"";
    NSString *method = @"";
    switch (type) {
        case ScrubbingTypeScrubber:
            method = @"scrubber";
            break;
        case ScrubbingTypeBack30:
        case ScrubbingTypeFwd30:
            method = @"button";
            break;
        case ScrubbingTypeBackToLive:
            method = @"back-to-live-button";
            break;
        case ScrubbingTypeRewindToStart:
            method = @"rewind-to-start-button";
            break;
        case ScrubbingTypeSystem:
            method = @"system-time-repair";
        case ScrubbingTypeUnknown:
        default:
            method = @"unknown";
            break;
    }
    
    if ( [[AudioManager shared] currentAudioMode] == AudioModeLive ) {
        eventName = @"liveStreamTimeShifted";
    }
    if ( [[AudioManager shared] currentAudioMode] == AudioModeOnDemand ) {
        eventName = @"episodeAudioTimeShifted";
    }
    
    NSString *direction = @"";
    if ( [[AudioManager shared] newPositionDelta] < 0 ) {
        direction = @"Backward";
    } else {
        direction = @"Forward";
    }
    
    [[AnalyticsManager shared] logEvent:eventName
                         withParameters:@{
                                          @"method" : method,
                                          @"amount" : [NSString stringWithFormat:@"%@ %1.1f",direction,fabs([[AudioManager shared] newPositionDelta])]
                                          }];
    
    NSLog(@"%@ : method : %@, amount : %@ %1.1f",eventName,method,direction,fabs([[AudioManager shared] newPositionDelta]));
}

- (void)trackPlaybackStalled {
    NSTimeInterval streamStarted = (NSTimeInterval)[[SessionManager shared] liveStreamSessionBegan];
    NSTimeInterval diff = [[NSDate date] timeIntervalSince1970] - streamStarted;
    
    ScheduleOccurrence *p = [[SessionManager shared] currentSchedule];
    
    NSString *title = @"[UNKNOWN]";
    if ( p.title ) {
        title = p.title;
    }
    
    [self logEvent:@"liveStreamPlaybackStalled"
    withParameters:@{ @"secondsSinceStreamBegan" : @(diff),
                      @"programTitle" : title }
             timed:NO];
}

@end
