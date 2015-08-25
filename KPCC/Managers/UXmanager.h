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
#import <AVFoundation/AVFoundation.h>
#import <Lock/Lock.h>
#import <libextobjc/EXTScope.h>
#import <SimpleKeychain/A0SimpleKeychain.h>

@class SCPROnboardingViewController;
@class SCPRMasterViewController;

typedef NS_ENUM(NSInteger, SSOType) {
    SSOTypeNone = 0,
    SSOTypeTwitter,
    SSOTypeFacebook,
    SSOTypeKPCC
};

@interface UXmanager : NSObject<AVAudioPlayerDelegate>

@property (nonatomic,strong) Settings *settings;
@property (nonatomic,weak) SCPROnboardingViewController *onboardingCtrl;
@property (nonatomic,weak) SCPRMasterViewController *masterCtrl;
@property BOOL listeningForQueues;
@property BOOL suppressBalloon;
@property BOOL onboardingEnding;
@property BOOL paused;
@property BOOL notificationsPromptDisplaying;
@property (nonatomic,strong) NSDictionary *keyPoints;
@property (nonatomic,strong) NSTimer *observerTimer;
@property (nonatomic,strong) AVAudioPlayer *musicPlayer;
@property (nonatomic,strong) AVAudioPlayer *lisaPlayer;
@property (nonatomic,strong) NSOperationQueue *fadeQueue;
@property (nonatomic,strong) NSMutableDictionary *committedActions;
@property (nonatomic,strong) NSDate *operationBeganDate;
@property (readonly, nonatomic) A0Lock *lock;
@property (nonatomic, strong) A0SimpleKeychain *store;

+ (instancetype)shared;
- (void)load;
- (void)persist;

- (BOOL)userHasSeenOnboarding;
- (BOOL)userHasSeenScrubbingOnboarding;


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
- (void)quietlyAskForNotificationPermissions;
- (void)askSystemForNotificationPermissions;
- (void)restorePreNotificationUI:(BOOL)prompt;
- (void)closeOutOnboarding;
- (void)endOnboarding;
- (void)fadePlayer:(AVAudioPlayer*)player;
- (void)restoreInteractionButton;

- (void)hideMenuButton;
- (void)showMenuButton;

- (void)godPauseOrPlay;
- (void)killAudio;
- (void)timeBegin;
- (void)timeEnd:(NSString*)operationName;

// SSO
- (SSOType)userLoginType;
- (void)createUserWithMetadata:(NSDictionary*)metadata completion:(CompletionBlockWithValue)completion;
- (void)loginWithCredentials:(NSDictionary*)credentials completion:(CompletionBlockWithValue)completion;
- (A0UserProfile*)a0profile;

- (void)storeTokens:(NSDictionary*)tokenInfo type:(SSOType)type;

@end
