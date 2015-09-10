//
//  SCPRAppDelegate.h
//  KPCC
//
//  Created by John Meeker on 3/6/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SCPRXFSViewController.h"


#define TICK   NSDate *startTime = [NSDate date]
#define TOCK   NSLog(@"Execution Time: %f  -- [ %s ]=[ Line %d ]", -[startTime timeIntervalSinceNow], __PRETTY_FUNCTION__, __LINE__)

#ifdef PRODUCTION
#define NSLog //
#define kPushChannel @"listenLive"
#define kAlarmChannel @"iPhoneAlarm"
#else
#ifdef RELEASE
//#define kPushChannel @"sandbox_listenLive"
#define kPushChannel @"private_listenLive"
#define kAlarmChannel @"private_iPhoneAlarm"
#else
#define kPushChannel @"sandbox_listenLive"
#define kAlarmChannel @"sandbox_iPhoneAlarm"
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
@property (strong, nonatomic) NSTimer *timer;
@property (strong, nonatomic) NSDate *alarmDate;
@property (strong, nonatomic) NSTimer *initialCheckTimer;
@property (strong, nonatomic) NSTimer *alarmTimer;
@property (strong, nonatomic) SCPRXFSViewController *xfsInterface;

@property UIBackgroundFetchResult alarmResults;


@property BOOL userRespondedToPushWhileClosed;

@property UIBackgroundTaskIdentifier alarmTask;

@property (strong, nonatomic) NSDictionary *latestPush;

- (void)actOnNotification:(NSDictionary*)userInfo;
- (void)armAlarmClockWithDate:(NSDate*)date;
- (void)fireAlarmClock;
- (void)cancelAlarmClock;
- (void)endAlarmClock;
- (void)buildTimer;
- (void)manuallyCheckAlarm;
- (void)killBackgroundTask;
- (void)onboardForLiveFunctionality;

// XFS
- (void)applyXFSButton;
- (void)controlXFSAvailability:(BOOL)available;
- (void)showCoachingBalloonWithText:(NSString*)text;

@end
