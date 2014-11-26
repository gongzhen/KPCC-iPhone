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

#ifdef ENABLE_TESTFLIGHT
#import "TestFlight.h"
#endif


@implementation SCPRAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    NSError* error;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&error];
    [[AVAudioSession sharedInstance] setActive:YES error:&error];
    
    NSString *path = [[NSBundle mainBundle] pathForResource:@"Config" ofType:@"plist"];
    NSDictionary *globalConfig = [[NSDictionary alloc] initWithContentsOfFile:path];
    
#ifdef ENABLE_TESTFLIGHT
    [TestFlight takeOff: globalConfig[@"TestFlight"][@"AppToken"]];
#endif
    
    [Flurry setCrashReportingEnabled:YES];
    [Flurry setDebugLogEnabled:YES];
    [Flurry startSession: globalConfig[@"Flurry"][@"DebugKey"] ];
    [Flurry setBackgroundSessionEnabled:NO];
    
#ifdef DEBUG
    [[UXmanager shared].settings setUserHasViewedOnboarding:YES];
    [[UXmanager shared].settings setUserHasViewedOnDemandOnboarding:YES];
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
    
    [[UXmanager shared] setSuppressBalloon:YES];
    [[SessionManager shared] setUseLocalNotifications:( types & UIUserNotificationTypeAlert )];
   
    if ( ![[UXmanager shared] userHasSeenOnboarding] ) {
        [[UXmanager shared] closeOutOnboarding];
    }
    
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    if ( ![[UXmanager shared] userHasSeenOnboarding] ) {
        [[UXmanager shared] closeOutOnboarding];
    }
}

- (void)applicationWillResignActive:(UIApplication *)application {
    
    [[SessionManager shared] disarmProgramUpdater];
    [[SessionManager shared] setSessionLeftDate:[NSDate date]];

    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    
    if ( [[SessionManager shared] userIsViewingHeadlines] ) {
        [[AnalyticsManager shared] trackHeadlinesDismissal];
    }
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    
    [[SessionManager shared] setSessionReturnedDate:[NSDate date]];
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    
    
    
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}


# pragma mark - Stylesheet

- (void)applyStylesheet {
    [[UINavigationBar appearance] setBarTintColor:[UIColor colorWithRed:255.0f/255.0f green:126.0f/255.0f blue:20.0f/255.0f alpha:1.0f]];
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
