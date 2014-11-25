//
//  SCPRAppDelegate.h
//  KPCC
//
//  Created by John Meeker on 3/6/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Program.h"


typedef void (^CompletionBlock)(void);
typedef void (^CompletionBlockWithValue)(id returnedObject);

#define TICK   NSDate *startTime = [NSDate date]
#define TOCK   NSLog(@"Execution Time: %f  -- [ %s ]=[ Line %d ]", -[startTime timeIntervalSinceNow], __PRETTY_FUNCTION__, __LINE__)

@class SCPRMasterViewController;
@class SCPRNavigationController;
@class SCPROnboardingViewController;

@interface SCPRAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) SCPRMasterViewController *masterViewController;
@property (strong, nonatomic) SCPRNavigationController *masterNavigationController;
@property (strong, nonatomic) SCPROnboardingViewController *onboardingController;

@end
