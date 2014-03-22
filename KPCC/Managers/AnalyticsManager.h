//
//  AnalyticsManager.h
//  KPCC
//
//  Created by John Meeker on 3/21/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Flurry.h"
#include <mach/mach_time.h>

typedef enum {
    StreamStateHealthy = 0,
    StreamStateLostConnectivity = 1,
    StreamStateServerFail = 2,
    StreamStateUnknown = 3
} StreamState;

@interface AnalyticsManager : NSObject

@property long lastErrorLoggedTime;
@property NSString *lastErrorLoggedComments;

+ (AnalyticsManager*)shared;
- (void)failStream:(StreamState)cause comments:(NSString*)comments;


- (void)logEvent:(NSString*)event withParameters:(NSDictionary*)parameters;

@end
