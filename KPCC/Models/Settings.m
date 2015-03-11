//
//  Settings.m
//  KPCC
//
//  Created by Ben Hochberg on 11/18/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "Settings.h"

@implementation Settings

- (id)initWithCoder:(NSCoder *)aDecoder {
    self.userHasViewedOnboarding = [aDecoder decodeBoolForKey:@"userHasViewedOnboarding"];
    self.userHasViewedOnDemandOnboarding = [aDecoder decodeBoolForKey:@"userHasViewedOnDemandOnboarding"];
    self.userHasViewedScrubbingOnboarding = [aDecoder decodeBoolForKey:@"userHasViewedScrubbingOnboarding"];
    self.pushTokenString = [aDecoder decodeObjectForKey:@"pushTokenString"];
    self.pushTokenData = [aDecoder decodeObjectForKey:@"pushTokenData"];
    self.userHasConnectedWithKochava = [aDecoder decodeBoolForKey:@"userHasConnectedWithKochava"];
    self.lastBookmarkSweep = [aDecoder decodeObjectForKey:@"lastBookmarkSweep"];
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
}

@end
