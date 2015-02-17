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
    mixPanelToken = @"ProductionToken";
    flurryToken = @"ProductionKey";
#endif
    
#ifdef BETA
    mixPanelToken = @"BetaToken";
#endif
    
    NSString *path = [[NSBundle mainBundle] pathForResource:@"Config" ofType:@"plist"];
    NSDictionary *globalConfig = [[NSDictionary alloc] initWithContentsOfFile:path];
    
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
    
    NSString *kKey = globalConfig[@"Kochava"][@"AppKey"];
    if ( kKey ) {
        NSDictionary *kDict = @{ @"kochavaAppId" : kKey };
        self.kTracker = [[KochavaTracker alloc] initKochavaWithParams:kDict];
    }
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
    [self.kTracker trackEvent:@"session"
                             :modifier];
}

- (void)trackHeadlinesDismissal {
    [self logEvent:@"userClosedHeadlines"
    withParameters:@{ }];
}


- (void)logEvent:(NSString *)event withParameters:(NSDictionary *)parameters {
    NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];

    parameters = [self logifiedParamsList:parameters];
    
    if ( ![[UXmanager shared].settings userHasViewedOnboarding] ) return;
    
    for ( NSString *key in [parameters allKeys] ) {
        userInfo[key] = parameters[key];
    }
    
#ifdef DEBUG
#ifdef VERBOSE_LOGGING
    NSLog(@"Logging to Analytics now - %@ - with params %@", event, userInfo);
#endif
#endif
    
    [Flurry logEvent:event withParameters:userInfo timed:YES];
    
    Mixpanel *mxp = [Mixpanel sharedInstance];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [mxp track:event properties:userInfo];
    });
    
    
}

- (void)failStream:(NetworkHealth)cause comments:(NSString *)comments {
    [self failStream:cause comments:comments force:NO];
}

- (void)failStream:(NetworkHealth)cause comments:(NSString *)comments force:(BOOL)force {
    
    if ( !comments || SEQ(comments,@"") ) return;
 
#ifdef MICRO_MANAGE_EXCEPTIONS
    if ( [[NSDate date] timeIntervalSinceDate:self.lastStreamException] > kExceptionInterval ) {
        self.allowedExceptions = 0;
        self.lastStreamException = [NSDate date];
    } else {
        self.allowedExceptions++;
        if ( self.allowedExceptions > kMaxAllowedExceptionsPerInterval ) {
            return;
        }
    }
#endif
    
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
    NSDictionary *ui = [timer userInfo];
    [[AudioManager shared] setLoggingGateOpen:NO];
    [self failStream:(NetworkHealth)[ui[@"cause"] intValue]
            comments:ui[@"comments"]];
}

- (NSDictionary*)logifiedParamsList:(NSDictionary *)originalParams {
    
    NSMutableDictionary *nParams = [originalParams mutableCopy];
    if ( self.errorLog ) {
        if ( self.errorLog.events && self.errorLog.events.count > 0 ) {
            AVPlayerItemErrorLogEvent *event = self.errorLog.events.firstObject;
            if ( event.playbackSessionID ) {
                nParams[@"avPlayerSessionId"] = event.playbackSessionID;
            }
            nParams[@"errorStatusCode"] = @(event.errorStatusCode);
            if ( event.errorDomain ) {
                nParams[@"errorDomain"] = event.errorDomain;
            }
            if ( self.errorLogReceivedAt ) {
                nParams[@"errorLogPostedAt"] = [NSDate prettyTextFromSeconds:[[NSDate date] timeIntervalSinceDate:self.errorLogReceivedAt]];
            }
        }
    }
    if ( self.accessLog ) {
        if ( self.accessLog.events && self.accessLog.events.count > 0 ) {
            AVPlayerItemAccessLogEvent *event = self.accessLog.events.firstObject;
            if ( event.playbackSessionID ) {
                nParams[@"avPlayerSessionId"] = event.playbackSessionID;
            }
         
            nParams[@"numberOfStalls"] = @(event.numberOfStalls);
            nParams[@"switchBitrate"] = @(event.switchBitrate);
            
            [[SessionManager shared] setLastKnownBitrate:event.observedBitrate];
            
            if ( event.observedBitrateStandardDeviation >= 0.0 ) {
                nParams[@"bitrateDeviation"] = @(event.observedBitrateStandardDeviation);
            }

            if ( event.downloadOverdue > 0 ) {
                nParams[@"downloadOverdue"] = @(event.downloadOverdue);
            }

            if ( event.transferDuration >= 0 ) {
                nParams[@"transferDuration"] = @(event.transferDuration);
            }

            nParams[@"indicatedBitrate"] = @(event.indicatedBitrate);
            nParams[@"observedBitrate"] = @(event.observedBitrate);
            if ( event.observedMaxBitrate != event.observedBitrate ) {
                nParams[@"observedMaxBitrate"] = @(event.observedMaxBitrate);
            }
            if ( event.observedMinBitrate != event.observedBitrate ) {
                nParams[@"observedMinBitrate"] = @(event.observedMinBitrate);
            }
            
            nParams[@"bytesTransferred"] = @(event.numberOfBytesTransferred);
            
            if ( self.accessLogReceivedAt ) {
                nParams[@"accessLogPostedAt"] = [NSDate prettyTextFromSeconds:[[NSDate date] timeIntervalSinceDate:self.accessLogReceivedAt]];
            }
            
            if ( event.URI ) {
                nParams[@"uri"] = event.URI;
            }
        }
    }
    
    if ( !nParams[@"avPlayerSessionId"] ) {
        NSString *avpid = [[AudioManager shared] avPlayerSessionString];
        if ( avpid ) {
            nParams[@"avPlayerSessionId"] = avpid;
        }
    }
    
    
    //NSLog(@" •••••••• FINISHED LOGGIFYING ANALYTICS ••••••• ");
    
    return nParams;
}

- (void)clearLogs {
    if ( [self.accessLogReceivedAt timeIntervalSinceNow] > 120 ) {
        self.accessLog = nil;
    }
    if ( [self.errorLogReceivedAt timeIntervalSinceNow] > 120 ) {
        self.errorLog = nil;
    }
}

- (NSString*)stringForInterruptionCause:(NetworkHealth)cause {
    NSString *english = @"";
    switch (cause) {
        case NetworkHealthStreamingServerDown:
            english = [NSString stringWithFormat:@"Device could not communicate with streaming server : %@",kHLSLiveStreamURL];
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

@end
