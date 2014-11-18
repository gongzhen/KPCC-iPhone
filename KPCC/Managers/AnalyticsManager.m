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

static AnalyticsManager *singleton = nil;

@implementation AnalyticsManager

+ (AnalyticsManager*)shared {
    if (!singleton) {
        @synchronized(self) {
            singleton = [[AnalyticsManager alloc] init];
        }
    }
    return singleton;
}

- (void)logEvent:(NSString *)event withParameters:(NSDictionary *)parameters {
    NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
    
    for ( NSString *key in [parameters allKeys] ) {
        userInfo[key] = parameters[key];
    }
    
#ifdef DEBUG
    NSLog(@"Logging to Flurry now - %@ - with params %@", event, parameters);
#endif
    [Flurry logEvent:event withParameters:userInfo timed:YES];
}

- (void)failStream:(StreamState)cause comments:(NSString *)comments {
    
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
                                    @"NetworkInfo" : [[NetworkManager shared] networkInformation],
                                    @"LastPrerollPlayedSecondsAgo" : [NSString stringWithFormat:@"%ld", currentTimeSeconds - [[AudioManager shared] lastPreRoll]]};
        
        NSLog(@"Sending stream failure report to Flurry");
        [self logEvent:@"streamFailure" withParameters:analysis];
    }
}

- (NSString*)stringForInterruptionCause:(StreamState)cause {
    NSString *english = @"";
    switch (cause) {
        case StreamStateLostConnectivity:
            english = @"Device lost connectivity";
            break;
        case StreamStateServerFail:
            english = [NSString stringWithFormat:@"Device could not communicate with : %@",kLiveStreamURL];
            break;
        case StreamStateHealthy:
        case StreamStateUnknown:
            english = @"Stream failed for unknown reason";
        default:
            break;
    }
    
    return english;
}

@end
