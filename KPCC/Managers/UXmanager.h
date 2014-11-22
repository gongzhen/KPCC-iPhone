//
//  UXmanager.h
//  KPCC
//
//  Created by Ben Hochberg on 11/18/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Settings.h"
#import "SCPRAppDelegate.h"

@class SCPROnboardingViewController;
@class SCPRMasterViewController;

@interface UXmanager : NSObject

@property (nonatomic,strong) Settings *settings;
@property (nonatomic,weak) SCPROnboardingViewController *onboardingCtrl;
@property (nonatomic,weak) SCPRMasterViewController *masterCtrl;
@property BOOL listeningForQueues;
@property (nonatomic,strong) NSDictionary *keyPoints;

+ (instancetype)shared;
- (void)load;
- (void)persist;

- (BOOL)userHasSeenOnboarding;
- (void)loadOnboarding;
- (void)beginOnboarding:(SCPRMasterViewController*)masterCtrl;
- (void)fadeInBranding;
- (void)fadeOutBrandingWithCompletion:(CompletionBlock)completed;
- (void)beginAudio;
- (void)presentLensOverRewindButton;
- (void)listenForQueues;
- (void)activateDropdown;
- (void)handleKeypoint:(NSInteger)keypoint;
- (void)selectMenuItem:(NSInteger)menuitem;
- (void)closeMenu;
- (void)askForPushNotifications;
- (void)askSystemForNotificationPermissions;
- (void)restorePreNotificationUI:(BOOL)prompt;
- (void)closeOutOnboarding;
- (void)endOnboarding;

@end
