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
    self.userHasConnectedWithKochava = [aDecoder decodeBoolForKey:@"userHasConnectedWithKochava"];
    self.lastBookmarkSweep = [aDecoder decodeObjectForKey:@"lastBookmarkSweep"];
    self.alarmFireDate = [aDecoder decodeObjectForKey:@"alarmFireDate"];
    
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
    [aCoder encodeBool:self.userHasConnectedWithKochava
                forKey:@"userHasConnectedWithKochava"];
    [aCoder encodeBool:self.userHasViewedScrubbingOnboarding
                forKey:@"userHasViewedScrubbingOnboarding"];
    [aCoder encodeObject:self.lastBookmarkSweep
                  forKey:@"lastBookmarkSweep"];
    [aCoder encodeObject:self.alarmFireDate
                  forKey:@"alarmFireDate"];
    
    
}

@end
