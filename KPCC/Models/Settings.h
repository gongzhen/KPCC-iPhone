//
//  Settings.h
//  KPCC
//
//  Created by Ben Hochberg on 11/18/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Settings : NSObject<NSCoding>

@property BOOL userHasViewedOnboarding;
@property BOOL userHasViewedOnDemandOnboarding;
@property BOOL userHasViewedScrubbingOnboarding;
@property BOOL userHasConnectedWithKochava;
@property BOOL userHasViewedLiveScrubbingOnboarding;
@property BOOL userHasViewedScheduleOnboarding;
@property BOOL userHasColdStartedAudioOnce;
@property BOOL userHasViewedXFSOnboarding;



@property (nonatomic) BOOL userHasSelectedXFS;

@property (nonatomic, strong) NSData *pushTokenData;
@property (nonatomic, strong) NSString *pushTokenString;
@property (nonatomic, strong) NSString *latestPushJson;
@property (nonatomic, strong) NSDate *lastBookmarkSweep;
@property (nonatomic, strong) NSDate *alarmFireDate;
@property (nonatomic, strong) NSString *xfsToken;
@property (nonatomic, strong) NSMutableDictionary *userQualityMap;
@property (nonatomic, strong) NSDate *historyBeganAt;
@property (nonatomic, strong) NSNumber *userPoints;
@property (nonatomic, strong) NSString *ssoKey;

@end
