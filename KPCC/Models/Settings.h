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

@end
