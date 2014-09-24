//
//  SCPRAppDelegate.h
//  KPCC
//
//  Created by John Meeker on 3/6/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NetworkManager.h"
#import "Program.h"

#define TICK   NSDate *startTime = [NSDate date]
#define TOCK   NSLog(@"Execution Time: %f  -- [ %s ]=[ Line %d ]", -[startTime timeIntervalSinceNow], __PRETTY_FUNCTION__, __LINE__)

@class SCPRMasterViewController;

@interface SCPRAppDelegate : UIResponder <UIApplicationDelegate, ContentProcessor>

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) SCPRMasterViewController *masterViewController;

@end
