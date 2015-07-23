//
//  Settings.m
//  KPCC
//
//  Created by Ben Hochberg on 11/18/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "Settings.h"
#import "SCPRAppDelegate.h"
#import "Utils.h"

@implementation Settings

- (id)initWithCoder:(NSCoder *)aDecoder {
    self.userHasViewedOnboarding = [aDecoder decodeBoolForKey:@"userHasViewedOnboarding"];
    self.userHasViewedOnDemandOnboarding = [aDecoder decodeBoolForKey:@"userHasViewedOnDemandOnboarding"];
    self.userHasViewedScrubbingOnboarding = [aDecoder decodeBoolForKey:@"userHasViewedScrubbingOnboarding"];
    self.pushTokenString = [aDecoder decodeObjectForKey:@"pushTokenString"];
    self.pushTokenData = [aDecoder decodeObjectForKey:@"pushTokenData"];
    self.lastBookmarkSweep = [aDecoder decodeObjectForKey:@"lastBookmarkSweep"];
    self.alarmFireDate = [aDecoder decodeObjectForKey:@"alarmFireDate"];
    self.userHasViewedLiveScrubbingOnboarding = [aDecoder decodeBoolForKey:@"userHasViewedLiveScrubbingOnboarding"];
    self.userHasViewedScheduleOnboarding = [aDecoder decodeBoolForKey:@"userHasViewedScheduleOnboarding"];
    self.userHasColdStartedAudioOnce = [aDecoder decodeBoolForKey:@"userHasColdStartedAudioOnce"];
    self.userHasSelectedXFS = [aDecoder decodeBoolForKey:@"userHasSelectedXFS"];
    self.userHasViewedXFSOnboarding = [aDecoder decodeBoolForKey:@"userHasViewedXFSOnboarding"];
    self.xfsToken = [aDecoder decodeObjectForKey:@"xfsToken"];
    self.userQualityMap = [aDecoder decodeObjectForKey:@"userQualityMap"];
    self.historyBeganAt = [aDecoder decodeObjectForKey:@"historyBeganAt"];
    self.userPoints = [aDecoder decodeObjectForKey:@"userPoints"];
    [[Utils del] setAlarmDate:self.alarmFireDate];
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeBool:self.userHasViewedOnboarding
                forKey:@"userHasViewedOnboarding"];
    [aCoder encodeBool:self.userHasViewedOnDemandOnboarding
                forKey:@"userHasViewedOnDemandOnboarding"];
    [aCoder encodeObject:self.pushTokenData
                  forKey:@"pushTokenData"];
    [aCoder encodeObject:self.pushTokenString
                  forKey:@"pushTokenString"];
    [aCoder encodeBool:self.userHasViewedScrubbingOnboarding
                forKey:@"userHasViewedScrubbingOnboarding"];
    [aCoder encodeObject:self.lastBookmarkSweep
                  forKey:@"lastBookmarkSweep"];
    [aCoder encodeObject:self.alarmFireDate
                  forKey:@"alarmFireDate"];
    
    [aCoder encodeBool:self.userHasViewedScheduleOnboarding
                forKey:@"userHasViewedScheduleOnboarding"];
    [aCoder encodeBool:self.userHasViewedLiveScrubbingOnboarding
                forKey:@"userHasViewedLiveScrubbingOnboarding"];
    [aCoder encodeBool:self.userHasColdStartedAudioOnce
                forKey:@"userHasColdStartedAudioOnce"];
    [aCoder encodeBool:self.userHasSelectedXFS
                forKey:@"userHasSelectedXFS"];
    [aCoder encodeBool:self.userHasViewedXFSOnboarding
                forKey:@"userHasViewedXFSOnboarding"];
    
    [aCoder encodeObject:self.xfsToken
                  forKey:@"xfsToken"];
    [aCoder encodeObject:self.userQualityMap
                  forKey:@"userQualityMap"];
    
    [aCoder encodeObject:self.historyBeganAt
                  forKey:@"historyBeganAt"];
    [aCoder encodeObject:self.userPoints
                  forKey:@"userPoints"];
    
}

- (void)setUserHasSelectedXFS:(BOOL)userHasSelectedXFS {
    _userHasSelectedXFS = userHasSelectedXFS;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"xfs-toggle"
                                                        object:nil
                                                      userInfo:@{ @"value" : [NSNumber numberWithBool:userHasSelectedXFS] }];
    
}

@end
