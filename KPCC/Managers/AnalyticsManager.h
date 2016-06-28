//
//  AnalyticsManager.h
//  KPCC
//
//  Created by John Meeker on 3/21/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <mach/mach_time.h>
#import <Crashlytics/Crashlytics.h>
#import <Fabric/Fabric.h>
#import <Flurry_iOS_SDK/Flurry.h>
#import <Google/Analytics.h>

@class AVPlayerItemAccessLogEvent, AVPlayerItemErrorLogEvent;

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
@property (nonatomic, strong) AVPlayerItemAccessLogEvent *accessLog;
@property (nonatomic, strong) AVPlayerItemErrorLogEvent *errorLog;

@property (nonatomic, strong) NSDate *errorLogReceivedAt;
@property (nonatomic, strong) NSDate *accessLogReceivedAt;
@property (nonatomic, strong) NSDate *lastStreamException;

@property (nonatomic, strong) NSMutableDictionary *progressMap;

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

- (void)trackPlaybackStalled;

- (void)clearLogs;

- (void)buildQualityMap;
- (void)applyUserQuality;
- (void)screen:(NSString*)screen;

- (void)trackSeekUsageWithType:(ScrubbingType)type;
- (void)trackEpisodeProgress:(double)progress;
- (void)clearEpisodeProgress;

- (NSString*)categoryForEvent:(NSString*)event;

- (NSDictionary*)logifiedParamsList:(NSDictionary*)originalParams;
- (NSDictionary*)typicalLiveProgramInformation;
- (NSDictionary*)typicalOnDemandEpisodeInformation;

@end
