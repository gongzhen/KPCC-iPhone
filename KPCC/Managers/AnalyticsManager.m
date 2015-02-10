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
    NSLog(@"Logging to Analytics now - %@ - with params %@", event, userInfo);
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
    
    if ( !comments ) {
        comments = @"";
    }
    
    if ( !force ) {
        if ( !self.accessLog && !self.errorLog ) {
            
            if ( ![[AudioManager shared].audioPlayer.currentItem accessLog] && ![[AudioManager shared].audioPlayer.currentItem errorLog] ) {
                [[AudioManager shared] setLoggingGateOpen:YES];
                self.analyticsSuspensionTimer = [NSTimer scheduledTimerWithTimeInterval:5.0
                                                                             target:self
                                                                           selector:@selector(forceAnalysis:)
                                                                           userInfo:@{ @"cause" : @(cause),
                                                                                       @"comments" : comments } repeats:NO];
                return;
            } else {
                self.accessLog = [[AudioManager shared].audioPlayer.currentItem accessLog];
                self.errorLog = [[AudioManager shared].audioPlayer.currentItem errorLog];
            }
        }
    }

    if ( self.analyticsSuspensionTimer ) {
        if ( [self.analyticsSuspensionTimer isValid] ) {
            [self.analyticsSuspensionTimer invalidate];
        }
        self.analyticsSuspensionTimer = nil;
    }
    
    self.lastErrorLoggedComments = comments;
    
    NSMutableDictionary *analysis = [@{ @"cause" : [self stringForInterruptionCause:cause],
                                @"timeDropped"  : [NSDate stringFromDate:[NSDate date]
                                                              withFormat:@"YYYY-MM-dd hh:mm:ss"],
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
        
    analysis[@"audioSurvivedException"] = [[AudioManager shared].audioPlayer rate] > 0.0 ? @(YES) : @(NO);
    if ( [[AudioManager shared] tryAgain] ) {
        analysis[@"audioSurvivedException"] = @(NO);
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
        }
    }
    if ( self.accessLog ) {
        if ( self.accessLog.events && self.accessLog.events.count > 0 ) {
            AVPlayerItemAccessLogEvent *event = self.accessLog.events.firstObject;
            if ( event.playbackSessionID ) {
                nParams[@"avPlayerSessionId"] = event.playbackSessionID;
            }
         
            nParams[@"numberOfStalls"] = @(event.numberOfStalls);
            nParams[@"numberOfDroppedFrames"] = @(event.numberOfDroppedVideoFrames);
            nParams[@"switchBitrate"] = @(event.switchBitrate);
            
            [[SessionManager shared] setLastKnownBitrate:event.switchBitrate];
            
            nParams[@"bitrateDeviation"] = @(event.observedBitrateStandardDeviation);
            nParams[@"downloadOverdue"] = @(event.downloadOverdue);
            nParams[@"transferDuration"] = @(event.transferDuration);
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
    
    [[AudioManager shared] setLoggingGateOpen:NO];
    
    NSLog(@" •••••••• FINISHED LOGGIFYING ANALYTICS ••••••• ");
    
    return nParams;
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
