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
    //userInfo[@"deviceIdentifier"] = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    
    NSString *playerSession = [[AudioManager shared] avPlayerSessionString];
    if ( playerSession && [playerSession length] > 0 ) {
        userInfo[@"avPlayerSessionId"] = playerSession;
    }
    
    if ( ![[UXmanager shared].settings userHasViewedOnboarding] ) return;
    
    for ( NSString *key in [parameters allKeys] ) {
        userInfo[key] = parameters[key];
    }
    
#ifdef DEBUG
    NSLog(@"Logging to Analytics now - %@ - with params %@", event, userInfo);
#endif
    
    [Flurry logEvent:event withParameters:userInfo timed:YES];
    
    Mixpanel *mxp = [Mixpanel sharedInstance];
    [mxp track:event properties:userInfo];
    
}

- (void)failStream:(NetworkHealth)cause comments:(NSString *)comments {
    
    // Only send a failure report once every 5 seconds.
    long currentTimeSeconds = [[NSDate date] timeIntervalSince1970];
    if (self.lastErrorLoggedTime < (currentTimeSeconds - 5) || (self.lastErrorLoggedComments && comments != self.lastErrorLoggedComments)) {
        self.lastErrorLoggedTime = currentTimeSeconds;
        
        if ( !comments ) {
            comments = @"";
        }
        self.lastErrorLoggedComments = comments;
        
        NSDictionary *analysis = @{ @"cause" : [self stringForInterruptionCause:cause],
                                    @"timeDropped"  : [NSDate stringFromDate:[NSDate date]
                                                                  withFormat:@"YYYY-MM-dd hh:mm:ss"],
                                    @"details" : comments,
                                    @"networkInfo" : [[NetworkManager shared] networkInformation],
                                    @"lastPrerollPlayedSecondsAgo" : [NSString stringWithFormat:@"%ld", currentTimeSeconds - [[AudioManager shared] lastPreRoll]],
                                    
                                    
                                    };
        
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
        [self logEvent:@"streamFailure" withParameters:analysis];
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
        case NetworkHealthAllOK:
        case NetworkHealthNetworkOK:
        case NetworkHealthServerOK:
        case NetworkHealthUnknown:
        default:
            english = @"Cause of this is unknown";
            break;
    }
    
    return english;
}

@end
