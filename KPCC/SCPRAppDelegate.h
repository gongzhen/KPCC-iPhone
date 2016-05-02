//
//  SCPRAppDelegate.h
//  KPCC
//
//  Created by John Meeker on 3/6/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Parse/Parse.h>
#import <FBSDKCoreKit/FBSDKCoreKit.h>
#import <Flurry-iOS-SDK/Flurry.h>

@class SCPRMasterViewController;
@class SCPRNavigationController;
@class SCPROnboardingViewController;
@class SCPRXFSViewController;

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
