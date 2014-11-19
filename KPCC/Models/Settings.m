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
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeBool:self.userHasViewedOnboarding
                forKey:@"userHasViewedOnboarding"];
}

@end
