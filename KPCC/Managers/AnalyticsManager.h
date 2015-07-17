//
//  AnalyticsManager.h
//  KPCC
//
//  Created by John Meeker on 3/21/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <mach/mach_time.h>
#import "AudioManager.h"
#import "Flurry.h"
#import "Mixpanel.h"
#import "NetworkManager.h"
#import <NewRelicAgent/NewRelic.h>
#import <Crashlytics/Crashlytics.h>
#import <Fabric/Fabric.h>

static NSInteger kMaxAllowedExceptionsPerInterval = 5;
static NSInteger kExceptionInterval = 60;

typedef NS_ENUM(NSInteger, ScrubbingType) {
    ScrubbingTypeUnknown = 0,
    ScrubbingTypeScrubber,
    ScrubbingTypeBack30,
    ScrubbingTypeFwd30,
    ScrubbingTypeRewindToStart,
    ScrubbingTypeBackToLive,
    ScrubbingTypeSystem
};

@interface AnalyticsManager : NSObject

@property long lastErrorLoggedTime;
@property NSString *lastErrorLoggedComments;
@property (nonatomic, strong) NSTimer *analyticsSuspensionTimer;
@property (nonatomic, strong) AVPlayerItemAccessLog *accessLog;
@property (nonatomic, strong) AVPlayerItemErrorLog *errorLog;

@property (nonatomic, strong) NSDate *errorLogReceivedAt;
@property (nonatomic, strong) NSDate *accessLogReceivedAt;
@property (nonatomic, strong) NSDate *lastStreamException;
@property (nonatomic, strong) Mixpanel *mxp;

@property BOOL flurryActiveInBackground;
@property BOOL gaSessionStarted;

@property NSInteger allowedExceptions;

+ (AnalyticsManager*)shared;

- (void)setup;
- (void)trackHeadlinesDismissal;
- (void)logEvent:(NSString *)event withParameters:(NSDictionary *)parameters;
- (void)logEvent:(NSString *)event withParameters:(NSDictionary *)parameters timed:(BOOL)timed;
- (void)logScreenView:(NSString *)screenName;
- (void)beginTimedEvent:(NSString *)event parameters:(NSDictionary*)parameters;
- (void)endTimedEvent:(NSString *)event;

- (NSString*)buildGALabelStringFromParams:(NSDictionary*)params;
- (void)gaSessionStartWithScreenView:(NSString*)screenName;
- (void)gaSessionEnd;

- (void)failStream:(NetworkHealth)cause comments:(NSString*)comments;
- (void)failStream:(NetworkHealth)cause comments:(NSString *)comments force:(BOOL)force;
- (void)trackPlaybackStalled;

- (void)kTrackSession:(NSString*)modifier;
- (void)clearLogs;

- (void)buildQualityMap;
- (void)applyUserQuality;

- (void)trackSeekUsageWithType:(ScrubbingType)type;

- (NSString*)categoryForEvent:(NSString*)event;

- (NSDictionary*)logifiedParamsList:(NSDictionary*)originalParams;

@end
