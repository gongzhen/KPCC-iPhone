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

static AnalyticsManager *singleton = nil;

@interface AnalyticsManager ()

- (NSString*)stringForInterruptionCause:(NetworkHealth)cause;

@end

@implementation AnalyticsManager

+ (AnalyticsManager*)shared {
    if (!singleton) {
        @synchronized(self) {
            singleton = [[AnalyticsManager alloc] init];
        }
    }
    return singleton;
}

- (void)setup {
    
    
    NSString *mixPanelToken = @"SandboxToken";
    NSString *flurryToken = @"DebugKey";
#ifdef PRODUCTION
#ifdef PRERELEASE
    mixPanelToken = @"SandboxToken";
    flurryToken = @"DebugKey";
#else
    mixPanelToken = @"ProductionToken";
    flurryToken = @"ProductionKey";
#endif
#endif
    
#ifdef BETA
    mixPanelToken = @"BetaToken";
#endif
    
    NSDictionary *globalConfig = [Utils globalConfig];
    
#ifndef TURN_OFF_SANDBOX_CONFIG
    [Flurry setCrashReportingEnabled:YES];
    [Flurry setDebugLogEnabled:NO];
    [Flurry startSession: globalConfig[@"Flurry"][flurryToken] ];
    [Flurry setBackgroundSessionEnabled:NO];
    
    NSLog(@"Mixpanel : %@ : %@",mixPanelToken,globalConfig[@"Mixpanel"][mixPanelToken]);
    
    [Mixpanel sharedInstanceWithToken:globalConfig[@"Mixpanel"][mixPanelToken]];
    Mixpanel *mxp = [Mixpanel sharedInstance];
    NSString *uuid = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    [mxp identify:uuid];
    [mxp.people set:@{ @"uuid" : uuid }];
    
#ifdef USE_KOCHAVA
    NSString *kKey = globalConfig[@"Kochava"][@"AppKey"];
    if ( kKey ) {
        NSDictionary *kDict = @{ @"kochavaAppId" : kKey };
        self.kTracker = [[KochavaTracker alloc] initKochavaWithParams:kDict];
    }
#endif
    
    [NewRelicAgent startWithApplicationToken:globalConfig[@"NewRelic"][@"production"]];
    
#endif
    
}

- (void)setAccessLog:(AVPlayerItemAccessLog *)accessLog {
    _accessLog = accessLog;
    if ( accessLog ) {
        self.accessLogReceivedAt = [NSDate date];
    }
}

- (void)setErrorLog:(AVPlayerItemErrorLog *)errorLog {
    _errorLog = errorLog;
    if ( errorLog ) {
        self.errorLogReceivedAt = [NSDate date];
    }
}

- (void)kTrackSession:(NSString *)modifier {
#ifdef USE_KOCHAVA
    [self.kTracker trackEvent:@"session"
                             :modifier];
#endif
}

- (void)trackHeadlinesDismissal {
    [self logEvent:@"userClosedHeadlines"
    withParameters:@{ }];
}


- (void)logEvent:(NSString *)event withParameters:(NSDictionary *)parameters {
    
    NSLog(@"Logging Event : %@",event);
#if TARGET_IPHONE_SIMULATOR
    return;
#endif
    
    NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
    
    NSMutableDictionary *mParams = [parameters mutableCopy];
    if ( parameters[@"short"] ) {
        [mParams removeObjectForKey:@"short"];
        parameters = mParams;
    } else {
        parameters = [self logifiedParamsList:parameters];
    }
    
    if ( ![[UXmanager shared].settings userHasViewedOnboarding] ) return;
    
    for ( NSString *key in [parameters allKeys] ) {
        userInfo[key] = parameters[key];
    }
    
#ifdef DEBUG
#ifdef VERBOSE_LOGGING
    NSLog(@"Logging to Analytics now - %@ - with params %@", event, userInfo);
#endif
#endif
    
#ifdef SUPPRESS_NETWORK_LOGGING
    NSLog(@"%@",userInfo);
#else
    
    Mixpanel *mxp = [Mixpanel sharedInstance];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [mxp track:event properties:userInfo];
    });
    
    if ( [userInfo count] >= 10 ) {
        if ( userInfo[@"numberOfStalls"] ) {
            [userInfo removeObjectForKey:@"numberOfStalls"];
        }
        if ( userInfo[@"observedMaxBitrate"] ) {
            [userInfo removeObjectForKey:@"observedMaxBitrate"];
        }
        if ( userInfo[@"observedMinBitrate"] ) {
            [userInfo removeObjectForKey:@"observedMinBitrate"];
        }
        if ( userInfo[@"bytesTransferred"] ) {
            [userInfo removeObjectForKey:@"bytesTransferred"];
        }
        if ( userInfo[@"accessLogPostedAt"] ) {
            [userInfo removeObjectForKey:@"accessLogPostedAt"];
        }
    }
    
    [Flurry logEvent:event withParameters:userInfo timed:YES];
    
#endif
    
}

- (void)failStream:(NetworkHealth)cause comments:(NSString *)comments {
    [self failStream:cause comments:comments force:NO];
}

- (void)failStream:(NetworkHealth)cause comments:(NSString *)comments force:(BOOL)force {
    
    if ( !comments || SEQ(comments,@"") ) return;
    
    self.accessLog = [[AudioManager shared].audioPlayer.currentItem accessLog];
    self.errorLog = [[AudioManager shared].audioPlayer.currentItem errorLog];
    
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
    
    if ( [[SessionManager shared] liveSessionID] && !SEQ([[SessionManager shared] liveSessionID],@"") ) {
        NSMutableDictionary *mD = [analysis mutableCopy];
        mD[@"kpccSessionId"] = [[SessionManager shared] liveSessionID];
        analysis = mD;
    } else if ( [[SessionManager shared] odSessionID] && !SEQ([[SessionManager shared] odSessionID],@"") ) {
        NSMutableDictionary *mD = [analysis mutableCopy];
        mD[@"kpccSessionId"] = [[SessionManager shared] odSessionID];
        analysis = mD;
    }
    
    NSLog(@"Sending stream failure report to analytics");
    [self logEvent:@"streamException" withParameters:analysis];
    
    
}

- (void)forceAnalysis:(NSTimer*)timer {
  /*  NSDictionary *ui = [timer userInfo];
    [[AudioManager shared] setLoggingGateOpen:NO];
    [self failStream:(NetworkHealth)[ui[@"cause"] intValue]
            comments:ui[@"comments"]];
   */
}

- (NSDictionary*)logifiedParamsList:(NSDictionary *)originalParams {
    
    NSMutableDictionary *nParams = [originalParams mutableCopy];
    if ( self.errorLog ) {
        if ( self.errorLog.events && self.errorLog.events.count > 0 ) {
            
            AVPlayerItemErrorLogEvent *event = self.errorLog.events.lastObject;
            if ( event.playbackSessionID ) {
                nParams[@"avPlayerSessionId"] = event.playbackSessionID;
            }
            nParams[@"errorStatusCode"] = @(event.errorStatusCode);
            if ( event.errorDomain ) {
                nParams[@"errorDomain"] = event.errorDomain;
            }
            if ( self.errorLogReceivedAt ) {
                nParams[@"errorLogPostedAt"] = self.errorLogReceivedAt;
            }
            if ( event.errorComment ) {
                nParams[@"errorComment"] = event.errorComment;
            }
        }
        self.errorLog = nil;
    }
    if ( self.accessLog ) {
        if ( self.accessLog.events && self.accessLog.events.count > 0 ) {
            
            AVPlayerItemAccessLogEvent *event = self.accessLog.events.lastObject;
            if ( event.playbackSessionID ) {
                nParams[@"avPlayerSessionId"] = event.playbackSessionID;
            }
            
            nParams[@"numberOfStalls"] = @(event.numberOfStalls);
            
            [[SessionManager shared] setLastKnownBitrate:event.indicatedBitrate];
            
            if ( event.observedBitrateStandardDeviation >= 0.0 ) {
                nParams[@"bitrateDeviation"] = @(event.observedBitrateStandardDeviation);
            }
            
            nParams[@"indicatedBitrate"] = [NSString stringWithFormat:@"%1.1f",event.indicatedBitrate];
            nParams[@"observedBitrate"] =  [NSString stringWithFormat:@"%1.1f",event.observedBitrate];
            nParams[@"bytesTransferred"] = @(event.numberOfBytesTransferred);
            
            if ( self.accessLogReceivedAt ) {
                nParams[@"accessLogPostedAt"] = self.accessLogReceivedAt;
            }
            
            if ( event.URI ) {
                nParams[@"uri"] = event.URI;
            }
        }
        self.accessLog = nil;
    }
    
    if ( !nParams[@"avPlayerSessionId"] ) {
        NSString *avpid = [[AudioManager shared] avPlayerSessionString];
        if ( avpid ) {
            nParams[@"avPlayerSessionId"] = avpid;
        }
    }
    
    NSError *misc = [[[AudioManager shared] audioPlayer] currentItem].error;
    if ( misc ) {
        for ( NSString *key in [[misc userInfo] allKeys] ) {
            nParams[key] = [misc userInfo][key];
        }
    }
    
    //NSLog(@" •••••••• FINISHED LOGGIFYING ANALYTICS ••••••• ");
    
    
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
        eventName = @"liveStreamScrubbed";
    }
    if ( [[AudioManager shared] currentAudioMode] == AudioModeOnDemand ) {
        eventName = @"onDemandAudioScrubbed";
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

@end
