//
//  SCPRAppDelegate.m
//  KPCC
//
//  Created by John Meeker on 3/6/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "SCPRAppDelegate.h"
#import "SCPRMasterViewController.h"
#import "SCPRNavigationController.h"
#import <AVFoundation/AVFoundation.h>
#import "Flurry.h"
#import "SessionManager.h"
#import "NetworkManager.h"
#import "SCPROnboardingViewController.h"
#import "UXmanager.h"
#import "AnalyticsManager.h"
#import <Parse/Parse.h>

#ifdef ENABLE_TESTFLIGHT
#import "TestFlight.h"
#endif


@implementation SCPRAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    //[[AudioManager shared] resetPlayer];
    
    NSError* error;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&error];
    [[AVAudioSession sharedInstance] setActive:YES error:&error];
    
    NSString *path = [[NSBundle mainBundle] pathForResource:@"Config" ofType:@"plist"];
    NSDictionary *globalConfig = [[NSDictionary alloc] initWithContentsOfFile:path];
    
#ifdef ENABLE_TESTFLIGHT
    [TestFlight takeOff: globalConfig[@"TestFlight"][@"AppToken"]];
#endif
    
    [[AnalyticsManager shared] setup];
    
#ifndef PRODUCTION
    [[UXmanager shared].settings setUserHasViewedOnboarding:YES];
    [[UXmanager shared].settings setUserHasViewedOnDemandOnboarding:YES];
#ifdef TESTING_SCRUBBER
    [[UXmanager shared].settings setUserHasViewedScrubbingOnboarding:NO];
#endif
    [[UXmanager shared] persist];
#endif
    
#ifndef TURN_OFF_SANDBOX_CONFIG
    [Parse setApplicationId:globalConfig[@"Parse"][@"ApplicationId"]
                  clientKey:globalConfig[@"Parse"][@"ClientKey"]];
#endif
    
#ifdef TESTING_SCRUBBER
    [[UXmanager shared].settings setUserHasViewedScrubbingOnboarding:NO];
    [[UXmanager shared] persist];
#endif
    
    // Apply application-wide styling
    [self applyStylesheet];
    
    // Initialize the window
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor blackColor];
    
    // Launch our root view controller
    SCPRNavigationController *navigationController = [[UIStoryboard storyboardWithName:@"Storyboard" bundle:nil] instantiateInitialViewController];

    self.onboardingController = [[SCPROnboardingViewController alloc] initWithNibName:@"SCPROnboardingViewController"
                                                                               bundle:nil];
    self.onboardingController.view.frame = CGRectMake(0.0,0.0,self.window.frame.size.width,
                                                      self.window.frame.size.height);

    self.onboardingController.view.backgroundColor = [UIColor clearColor];
    
    self.masterNavigationController = navigationController;
    self.masterViewController = navigationController.viewControllers.firstObject;
    self.window.rootViewController = navigationController;
    navigationController.navigationBarHidden = YES;

    NSString *ua = kHLSLiveStreamURL;
    NSLog(@"URL : %@",ua);
    
    [[AnalyticsManager shared] kTrackSession:@"began"];

    // Fetch initial list of Programs from SCPRV4 and store in CoreData for later usage.
    [[NetworkManager shared] fetchAllProgramInformation:^(id returnedObject) {
        
        //NSAssert([returnedObject isKindOfClass:[NSArray class]],@"Expecting an Array Here...");
        NSArray *content = (NSArray*)returnedObject;
        if ([content count] == 0) {
            return;
        }
        
        // Process Programs and insert into CoreData.
        NSLog(@"SCPRv4 returned %ld programs", (unsigned long)[content count]);
        [Program insertProgramsWithArray:content inManagedObjectContext:[[ContentManager shared] managedObjectContext]];
        
        // Save all changes made.
        [[ContentManager shared] saveContext];
        
    }];
    
    // Override point for customization after application launch.
    return YES;
}

- (void)application:(UIApplication *)application didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings {
    UIUserNotificationType types = notificationSettings.types;
    
    [application registerForRemoteNotifications];
    
    [[UXmanager shared] setSuppressBalloon:YES];
    [[SessionManager shared] setUseLocalNotifications:( types & UIUserNotificationTypeAlert )];
    if ( ![[UXmanager shared] userHasSeenOnboarding] ) {
        [[UXmanager shared] closeOutOnboarding];
    }
    
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    NSLog(@"•••• FAILED REGISTERING FOR PUSH ••••");
    if ( ![[UXmanager shared] userHasSeenOnboarding] ) {
        [[UXmanager shared] closeOutOnboarding];
    }
    
#ifndef TURN_OFF_SANDBOX_CONFIG
    [[PFInstallation currentInstallation] removeObject:kPushChannel
                                                forKey:@"channels"];
    [[PFInstallation currentInstallation] saveInBackground];
#endif
    
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    const unsigned *tokenBytes = [deviceToken bytes];
    NSString *hexToken = [NSString stringWithFormat:@"%08x%08x%08x%08x%08x%08x%08x%08x",
                          ntohl(tokenBytes[0]), ntohl(tokenBytes[1]), ntohl(tokenBytes[2]),
                          ntohl(tokenBytes[3]), ntohl(tokenBytes[4]), ntohl(tokenBytes[5]),
                          ntohl(tokenBytes[6]), ntohl(tokenBytes[7])];
    
    [[UXmanager shared].settings setPushTokenData:deviceToken];
    [[UXmanager shared].settings setPushTokenString:hexToken];
    
#ifndef TURN_OFF_SANDBOX_CONFIG
    PFInstallation *i = [PFInstallation currentInstallation];
        
#ifndef PRODUCTION
    NSLog(@" ••••• Forcing sandbox channel only •••• ");
    [i removeObject:@"listenLive" forKey:@"channels"];
#ifdef RELEASE
    [i removeObject:@"sandbox_listenLive" forKey:@"channels"];
#endif
    [i saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        
        [i setDeviceTokenFromData:deviceToken];
        [i addUniqueObject:kPushChannel
                    forKey:@"channels"];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [i saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
                [[UXmanager shared] persist];
            }];
        });
    }];
    
    NSLog(@" ***** REGISTERING PUSH TOKEN : %@ *****", hexToken);
    
    return;
#else
    NSLog(@" ••••• Got through to PFInstallation creation •••• ");
    

    [i setDeviceTokenFromData:deviceToken];
    [i addUniqueObject:kPushChannel
                                  forKey:@"channels"];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [i saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
            [[UXmanager shared] persist];
        }];
    });

    NSLog(@" ***** REGISTERING PUSH TOKEN : %@ *****", hexToken);
#endif
#endif
    
}


- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {

    NSError *jsonError = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:userInfo
                                                   options:NSJSONWritingPrettyPrinted
                                                     error:&jsonError];
    NSString *dataStr = [[NSString alloc] initWithData:data
                                              encoding:NSUTF8StringEncoding];
    NSLog(@" •••••••• >>>>>>>> User Info from Push : %@ <<<<<<<< ••••••••",dataStr);
    
#ifdef USE_PUSH_FOR_ALARM
    if ( userInfo[@"alarm"] ) {
        NSLog(@"Alarm Received");
        self.alarmTask = [application beginBackgroundTaskWithExpirationHandler:^{
            
        }];
        
        [self actOnNotification:userInfo];
        completionHandler(UIBackgroundFetchResultNewData);
        return;
    }
#endif
    
    if ( [[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground ) {
        NSLog(@" >>>>> ACTING ON PUSH NOW <<<<< ");
        [self actOnNotification:userInfo];
    } else if ( [[UIApplication sharedApplication] applicationState] == UIApplicationStateInactive ) {
        self.userRespondedToPushWhileClosed = YES;
        NSLog(@" >>>>> WAITING FOR UI TO RENDER BEFORE PLAYING <<<<< ");
    }
    
    completionHandler(UIBackgroundFetchResultNoData);

}

- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification {
    
    NSLog(@"Alarm Clock is firing");
    [self endAlarmClock];
    
    [[AnalyticsManager shared] logEvent:@"alarmClockFired"
                         withParameters:@{ @"short" : @1 }];
    
    [[AudioManager shared] setUserPause:NO];
    [self.masterViewController handleResponseForNotification];
    
}

- (void)actOnNotification:(NSDictionary *)userInfo {
    [[AudioManager shared] setUserPause:NO]; // Override the user's pause request
    [self.masterViewController handleResponseForNotification];
}

- (void)applicationWillResignActive:(UIApplication *)application {
    
    if ( [[AudioManager shared] currentAudioMode] == AudioModeOnboarding ) {
        if ( ![[UXmanager shared] paused] ) {
            [[UXmanager shared] godPauseOrPlay];
        }
    }
    
    if ( [[QueueManager shared] currentBookmark] ) {
        [[ContentManager shared] saveContext];
    }
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    
    if ( [[SessionManager shared] userIsViewingHeadlines] ) {
        //[[AnalyticsManager shared] trackHeadlinesDismissal];
    }
    
    if ( [[AudioManager shared] currentAudioMode] != AudioModeOnboarding ) {
        if ( ![[SessionManager shared] sessionLeftDate] ) {
            [[SessionManager shared] disarmProgramUpdater];
            [[SessionManager shared] setSessionLeftDate:[NSDate date]];
        }
    }
    
    if ( [[AudioManager shared] currentAudioMode] == AudioModePreroll ) {
        [[SessionManager shared] setUserLeavingForClickthrough:YES];
    }
    
    [[AnalyticsManager shared] kTrackSession:@"ended"];
    
    [[ContentManager shared] saveContext];
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    
    if ( [[AudioManager shared] currentAudioMode] != AudioModeOnboarding ) {
        [[SessionManager shared] setSessionReturnedDate:[NSDate date]];
        [self.masterViewController determinePlayState];
    }
    
    if ( [[AudioManager shared] currentAudioMode] == AudioModeOnboarding ) {
        if ( [[UXmanager shared] paused] ) {
            [[UXmanager shared] godPauseOrPlay];
        }
    }
    
    NSString *push = [[UXmanager shared].settings latestPushJson];
    if ( push && !SEQ(push,@"") ) {
        NSLog(@"Push received while app was in background : %@",push);
        [[UXmanager shared].settings setLatestPushJson:nil];
        [[UXmanager shared] persist];
    }
    
    [[AudioManager shared] interruptAutorecovery];
    [[AnalyticsManager shared] kTrackSession:@"began"];
    [[SessionManager shared] setUserLeavingForClickthrough:NO];
    [[AudioManager shared] stopWaiting];
    [[ContentManager shared] sweepBookmarks];
    if ( [[AudioManager shared] isPlayingAudio] ) {
        [[SessionManager shared] checkProgramUpdate:YES];
    }
    
    [self manuallyCheckAlarm];
    
#ifdef DEBUG
    if ( [[SessionManager shared] sessionPausedDate] ) {
        NSLog(@"Session Paused : %@",[NSDate stringFromDate:[[SessionManager shared] sessionPausedDate]
                                                 withFormat:@"HH:mm:ss a"]);
    }
#endif
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    
    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
    
    if ( self.userRespondedToPushWhileClosed ) {
        if ( [self.masterViewController viewHasAppeared] ) {
            [self actOnNotification:nil];
        } else {
            NSLog(@" >>>>>>>>>>> CONTINUE WAITING FOR UI TO CATCH UP <<<<<<<<<<<< ");
        }
    }
    
    
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
    

    [[ContentManager shared] saveContext];

    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}


# pragma mark - Stylesheet

- (void)applyStylesheet {
    [[UINavigationBar appearance] setBarTintColor:[UIColor colorWithRed:255.0f/255.0f
                                                                  green:126.0f/255.0f
                                                                   blue:20.0f/255.0f
                                                                  alpha:1.0f]];
    [[UINavigationBar appearance] setBarStyle:UIBarStyleBlackTranslucent];

    [[UINavigationBar appearance] setTitleTextAttributes:
     @{NSForegroundColorAttributeName: [UIColor whiteColor],
      NSFontAttributeName: [UIFont fontWithName:@"FreightSansProMedium-Regular" size:23.0f]}];
    
    /*[[UIBarButtonItem appearanceWhenContainedIn:[UINavigationBar class], nil]
    setTitleTextAttributes: @{NSForegroundColorAttributeName:[UIColor whiteColor],
                              NSFontAttributeName:[UIFont fontWithName:@"FreightSansProLight-Regular" size:16.0f]
                              }
     forState:UIControlStateNormal];*/
}


#pragma mark - Alarm Clock

- (void)armAlarmClockWithDate:(NSDate *)date {
#ifndef USE_PUSH_FOR_ALARM
    
#ifdef DEBUG
    date = [[NSDate date] dateByAddingTimeInterval:30.0f];
#endif
    
    self.alarmDate = [NSDate dateWithTimeIntervalSince1970:[date timeIntervalSince1970]];
    if ( [[AudioManager shared] isPlayingAudio] ) {
        [[AudioManager shared] adjustAudioWithValue:-0.075
                                         completion:^{
                                             [[AudioManager shared] stopAllAudio];
                                             [self buildTimer];
                                             [self.masterViewController superPop];
                                         }];
        return;
    }
    

    [self buildTimer];
    [self.masterViewController superPop];
    
    [[AnalyticsManager shared] logEvent:@"alarmClockArmed"
                         withParameters:@{ @"short" : @1 }];
    
#else
    
    PFInstallation *i = [PFInstallation currentInstallation];
    [i addUniqueObject:kAlarmChannel
                forKey:@"channels"];
    i[@"activeFireDate"] = date;
    [i saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        
        
        
    }];
    
#endif
}

- (void)buildTimer {
    UILocalNotification *alarm = [[UILocalNotification alloc] init];
    alarm.alertTitle = @"Wake Up!";
    alarm.alertBody = @"It's time for your fix of KPCC";
    alarm.fireDate = self.alarmDate;
    alarm.soundName = @"alarm_beat.aif";
    
    [[UIApplication sharedApplication] scheduleLocalNotification:alarm];
    
    
    
    NSLog(@"Alarm will fire at : %@",[NSDate stringFromDate:self.alarmDate
                                                 withFormat:@"EEE MM/dd, hh:mm:ss a"]);
    
    [[UXmanager shared].settings setAlarmFireDate:self.alarmDate];
    [[UXmanager shared] persist];
}

- (void)setAlarmDate:(NSDate *)alarmDate {
    _alarmDate = alarmDate;
    
}

- (void)application:(UIApplication *)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    /*NSLog(@"System performing bg fetch at : %@",[NSDate stringFromDate:[NSDate date]
                                                            withFormat:@"hh:mm a"]);
    [self checkAlarmClock];
    
    completionHandler(self.alarmResults);*/
}

- (void)checkAlarmClock {
    
    self.alarmTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        
    }];
    
    NSLog(@"Checking alarm...");
    if ( [[NSDate date] timeIntervalSinceDate:self.alarmDate] >= 0 ) {
        if ( self.timer ) {
            if ( [self.timer isValid] ) {
                [self.timer invalidate];
            }
            self.timer = nil;
        }
        [self.masterViewController handleAlarmClock];
        self.alarmResults = UIBackgroundFetchResultNewData;
    } else {
        if ( !self.timer ) {
            NSLog(@"Arming check timer...");
            self.timer = [NSTimer scheduledTimerWithTimeInterval:10.0f
                                                          target:self
                                                        selector:@selector(checkAlarmClock)
                                                        userInfo:nil
                                                         repeats:YES];
        }
        self.alarmResults = UIBackgroundFetchResultNoData;
        [[UIApplication sharedApplication] endBackgroundTask:self.alarmTask];
        self.alarmTask = 0;
    }
    
}

- (void)manuallyCheckAlarm {
    NSDate *alarmDate = [[UXmanager shared].settings alarmFireDate];
    if ( alarmDate ) {
        NSInteger diff = [[NSDate date] timeIntervalSinceDate:alarmDate];
        if ( diff > 0 ) {
            [self endAlarmClock];
        }
    }
}

- (void)cancelAlarmClock {
    [self endAlarmClock];
    
    [[AnalyticsManager shared] logEvent:@"alarmCanceled"
                         withParameters:@{ @"short" : @1 }];
}

- (void)endAlarmClock {
#ifdef USE_PUSH_FOR_ALARM
    if ( self.alarmTask ) {
        [[UIApplication sharedApplication] endBackgroundTask:self.alarmTask];
        self.alarmTask = 0;
    }
#else
    self.alarmDate = nil;
    [[UXmanager shared].settings setAlarmFireDate:nil];
    [[UXmanager shared] persist];
    [[UIApplication sharedApplication] cancelAllLocalNotifications];
#endif
}

#pragma mark - ContentProcessor

- (void)handleProcessedContent:(NSArray *)content flags:(NSDictionary *)flags {

}

@end
