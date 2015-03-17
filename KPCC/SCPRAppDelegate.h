//
//  SCPRAppDelegate.h
//  KPCC
//
//  Created by John Meeker on 3/6/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Program.h"



#define TICK   NSDate *startTime = [NSDate date]
#define TOCK   NSLog(@"Execution Time: %f  -- [ %s ]=[ Line %d ]", -[startTime timeIntervalSinceNow], __PRETTY_FUNCTION__, __LINE__)

#ifdef PRODUCTION
#define NSLog //
#define kPushChannel @"listenLive"
#else
#ifdef RELEASE
#define kPushChannel @"sandbox_listenLive"
//#define kPushChannel @"private_listenLive"
#else
#define kPushChannel @"sandbox_listenLive"
#endif
#endif


@class SCPRMasterViewController;
@class SCPRNavigationController;
@class SCPROnboardingViewController;

@interface SCPRAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) SCPRMasterViewController *masterViewController;
@property (strong, nonatomic) SCPRNavigationController *masterNavigationController;
@property (strong, nonatomic) SCPROnboardingViewController *onboardingController;
@property BOOL userRespondedToPushWhileClosed;

@property (strong, nonatomic) NSDictionary *latestPush;

- (void)actOnNotification:(NSDictionary*)userInfo;

@end
