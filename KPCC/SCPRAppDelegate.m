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
    //[[UXmanager shared].settings setUserHasViewedOnboarding:YES];
    //[[UXmanager shared].settings setUserHasViewedOnDemandOnboarding:YES];
    //[[UXmanager shared] persist];
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

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
    [self storeNote:userInfo];
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    if ( completionHandler ) {
        [self storeNote:userInfo];
        completionHandler(UIBackgroundFetchResultNoData);
    } else {
        [self storeNote:userInfo];
    }
}

- (void)storeNote:(NSDictionary *)userInfo {
    
    //if ( [[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground ) {
        /*NSError *jsonError = nil;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:userInfo
                                                           options:NSJSONWritingPrettyPrinted
                                                             error:&jsonError];
        NSString *jsonStr = [[NSString alloc] initWithData:jsonData
                                                  encoding:NSUTF8StringEncoding];
        NSLog(@"Push Received : %@",jsonStr);
        
        [[UXmanager shared].settings setLatestPushJson:jsonStr];
        [[UXmanager shared] persist];*/
    NSLog(@" ******* ••••••• Handling remote notification •••••• ****** ");
    [self.masterViewController handleResponseForNotification];
    //}


    
    if ( [[UIApplication sharedApplication] applicationState] == UIApplicationStateActive ) {
        // Do something if the app is in the foreground
    }
}

- (void)applicationWillResignActive:(UIApplication *)application {
    
    if ( [[AudioManager shared] currentAudioMode] == AudioModeOnboarding ) {
        if ( ![[UXmanager shared] paused] ) {
            [[UXmanager shared] godPauseOrPlay];
        }
    }
    
    [[UIApplication sharedApplication] endReceivingRemoteControlEvents];
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
    
    [[AnalyticsManager shared] kTrackSession:@"began"];
    [[SessionManager shared] setUserLeavingForClickthrough:NO];

    
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    
    
    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
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

- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification {
    if ( [[UIApplication sharedApplication] applicationState] == UIApplicationStateActive ) {
        [[SessionManager shared] processNotification:notification];
    }
}

#pragma mark - ContentProcessor

- (void)handleProcessedContent:(NSArray *)content flags:(NSDictionary *)flags {

}

@end
