//
//  UXmanager.m
//  KPCC
//
//  Created by Ben Hochberg on 11/18/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "UXmanager.h"
#import "SCPRAppDelegate.h"
#import "SCPROnboardingViewController.h"
#import "SCPRMasterViewController.h"
#import "SCPRNavigationController.h"
#import "SessionManager.h"

@implementation UXmanager
+ (instancetype)shared {
    static UXmanager *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [UXmanager new];
        [shared load];
    });
    return shared;
}

- (void)load {
    if ( self.settings ) {
        self.settings = nil;
    }
    
    NSData *data = [[NSUserDefaults standardUserDefaults] objectForKey:@"settings"];
    if ( data ) {
        self.settings = (Settings*)[NSKeyedUnarchiver unarchiveObjectWithData:data];
    } else {
        self.settings = [Settings new];
    }
}

- (void)persist {
    if ( self.settings ) {
    
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self.settings];
        [[NSUserDefaults standardUserDefaults] setObject:data forKey:@"settings"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
    }
}

- (BOOL)userHasSeenOnboarding {
    return self.settings.userHasViewedOnboarding;
}

- (void)loadOnboarding {
    SCPRAppDelegate *del = (SCPRAppDelegate*)[[UIApplication sharedApplication] delegate];
    UIWindow *mw = [del window];
    [mw addSubview:del.onboardingController.view];
 
    SCPRNavigationController *nav = [del masterNavigationController];
    nav.menuButton.alpha = 0.0;
    
    
    
    del.onboardingController.view.frame = CGRectMake(0.0,0.0,mw.frame.size.width,
                                                     mw.frame.size.height);
    [del.onboardingController prepare];
    self.onboardingCtrl = del.onboardingController;
    self.onboardingCtrl.view.alpha = 0.0;
    self.onboardingCtrl.lensVC.view.layer.opacity = 0.0;
    self.onboardingCtrl.orangeStripView.backgroundColor = [[UIColor kpccOrangeColor] translucify:0.6];
    [self.onboardingCtrl.orangeStripView removeFromSuperview];
    
    self.onboardingCtrl.textCalloutBalloonCtrl.view.alpha = 0.0;
    self.onboardingCtrl.navbarMask = [[UIView alloc] initWithFrame:CGRectMake(0.0,0.0,[[UIScreen mainScreen] bounds].size.width,4.0)];
    self.onboardingCtrl.navbarMask.backgroundColor = [UIColor blackColor];
    nav.navigationBar.layer.mask = [self.onboardingCtrl.navbarMask layer];
    
    [self.onboardingCtrl.view layoutIfNeeded];

}

- (void)beginOnboarding:(SCPRMasterViewController*)masterCtrl {
    self.masterCtrl = masterCtrl;
    self.onboardingCtrl.view.alpha = 1.0;
    [self.masterCtrl primeOnboarding];
    
    
    self.onboardingCtrl.interactionButton.frame = [self.masterCtrl.view convertRect:self.masterCtrl.initialControlsView.frame
                                                                             toView:self.onboardingCtrl.view];
    [self.onboardingCtrl.interactionButton addTarget:self.masterCtrl
                                              action:@selector(initialPlayTapped:)
                                    forControlEvents:UIControlEventTouchUpInside];
    [self.onboardingCtrl.view addSubview:self.onboardingCtrl.interactionButton];
    //self.onboardingCtrl.interactionButton.backgroundColor = [UIColor orangeColor];
    
    [self.onboardingCtrl.view layoutIfNeeded];
    
}

- (void)fadeInBranding {
    [self.onboardingCtrl revealBrandingWithCompletion:^{
        [self.masterCtrl onboarding_revealPlayerControls];
    }];
}

- (void)fadeOutBrandingWithCompletion:(CompletionBlock)completed {
    
    SCPRAppDelegate *del = (SCPRAppDelegate*)[[UIApplication sharedApplication] delegate];
    SCPRNavigationController *nav = del.masterNavigationController;

    [UIView animateWithDuration:0.25 animations:^{
        self.onboardingCtrl.brandingView.alpha = 0.0;
        [self.masterCtrl.blurView setNeedsDisplay];
        
        nav.menuButton.alpha = 0.0;
        
    } completion:^(BOOL finished) {
        [self.onboardingCtrl.view layoutIfNeeded];
        [self.masterCtrl.view layoutIfNeeded];
        [self.onboardingCtrl.notificationsView layoutIfNeeded];
        
        completed();
    }];
}

- (void)beginAudio {
    

    [UIView animateWithDuration:0.66 animations:^{
        self.masterCtrl.blurView.layer.opacity = 0.0;

        self.onboardingCtrl.navbarMask.frame = CGRectMake(self.onboardingCtrl.navbarMask.frame.origin.x,
                                                          0.0,
                                                          self.onboardingCtrl.navbarMask.frame.size.width,
                                                          64.0);
    } completion:^(BOOL finished) {
        [self.onboardingCtrl.navbarMask.layer removeFromSuperlayer];
        self.onboardingCtrl.interactionButton.alpha = 0.0;
        [self.onboardingCtrl.orangeStripView removeFromSuperview];
        [self.masterCtrl onboarding_beginOnboardingAudio];
        [[UIApplication sharedApplication] setStatusBarHidden:NO
                                                withAnimation:UIStatusBarAnimationSlide];
    }];


}

- (void)presentLensOverRewindButton {
    [self.masterCtrl.liveProgressViewController tick];
    [self.masterCtrl primeManualControlButton];
    CGPoint origin = self.masterCtrl.liveRewindAltButton.frame.origin;
    [self.onboardingCtrl revealLensWithOrigin:[self.masterCtrl.liveStreamView convertPoint:CGPointMake(origin.x, origin.y)
                                                                          toView:self.onboardingCtrl.view]];
  
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        [self.onboardingCtrl.lensVC squeezeWithAnchorView:self.masterCtrl.liveRewindAltButton completed:^{
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self.masterCtrl activateRewind:RewindDistanceOnboardingBeginning];
            });
            
        }];
        
    });
}

- (void)listenForQueues {
    self.listeningForQueues = YES;
    self.keyPoints = [@{ @"8" : @"activateDropdown",
                         @"13" : @"selectFirstMenuItem",
                         @"18" : @"selectSecondMenuItem",
                         @"23" : @"closeMenu" } mutableCopy];
}

- (void)handleKeypoint:(NSInteger)keypoint {
    NSString *key = [NSString stringWithFormat:@"%ld",(long)keypoint];
    NSString *value = self.keyPoints[key];
    if ( value ) {
        if ( SEQ(value, @"activateDropdown") ) {
            [self activateDropdown];
        }
        if ( SEQ(value, @"selectFirstMenuItem") ) {
            [self selectMenuItem:1];
        }
        if ( SEQ(value, @"selectSecondMenuItem") ) {
            [self selectMenuItem:2];
        }
        if ( SEQ(value, @"closeMenu") ) {
            [self closeMenu];
        }
    }
}

- (void)activateDropdown {
    SCPRAppDelegate *del = (SCPRAppDelegate*)[[UIApplication sharedApplication] delegate];
    SCPRNavigationController *nav = [del masterNavigationController];
    [UIView animateWithDuration:0.2 animations:^{
        nav.menuButton.alpha = 1.0;
    } completion:^(BOOL finished) {
        [self.onboardingCtrl revealLensWithOrigin:CGPointMake(8.0, 22.0)];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            
            self.onboardingCtrl.lensVC.lock = NO;
            [self.onboardingCtrl.lensVC squeezeWithAnchorView:nil completed:^{
                [self.masterCtrl cloakForMenu:YES];
                [nav.menuButton animateToClose];
            }];
            
        });
    }];

}

- (void)closeMenu {
    [self.masterCtrl.pulldownMenu clearMenu];
    [self.masterCtrl decloakForMenu:YES];
    
    SCPRAppDelegate *del = (SCPRAppDelegate*)[[UIApplication sharedApplication] delegate];
    SCPRNavigationController *nav = [del masterNavigationController];
    [self.onboardingCtrl hideLens];
    [nav.menuButton animateToMenu];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.15 animations:^{
            [nav.menuButton setAlpha:0.0];
        }];
    });
}

- (void)selectMenuItem:(NSInteger)menuitem {
    [self.onboardingCtrl revealLensWithOrigin:CGPointMake(4.0+((menuitem-1)*5.0), (64*menuitem)+90.0)];
    [self.masterCtrl.pulldownMenu lightUpCellWithIndex:menuitem];
}

- (void)askForPushNotifications {
    self.listeningForQueues = NO;
    [UIView animateWithDuration:0.5 animations:^{
        [self.masterCtrl.blurView.layer setOpacity:1.0];
        [self.masterCtrl.darkBgView.layer setOpacity:0.75];
        self.masterCtrl.playerControlsView.alpha = 0.0;
        [self.masterCtrl.liveProgressViewController hide];
        [self.masterCtrl.horizDividerLine setAlpha:0.0];
        [self.masterCtrl.liveStreamView setAlpha:0.0];
        [self.masterCtrl.liveProgressViewController hide];
    } completion:^(BOOL finished) {
        [self.onboardingCtrl revealNotificationsPrompt];
    }];
}

- (void)restorePreNotificationUI:(BOOL)prompt {
    [self.onboardingCtrl collapseNotificationsPrompt];
    [UIView animateWithDuration:0.5 animations:^{
        //[self.masterCtrl.blurView.layer setOpacity:0.0];
        [self.masterCtrl.darkBgView.layer setOpacity:0.35];
        self.masterCtrl.playerControlsView.alpha = 1.0;
        
        [self.masterCtrl.liveStreamView setAlpha:1.0];
    } completion:^(BOOL finished) {
        if ( prompt ) {
            [self askSystemForNotificationPermissions];
        } else {
            [self closeOutOnboarding];
        }
    }];
}

- (void)askSystemForNotificationPermissions {
    if ( [[UIApplication sharedApplication] respondsToSelector:@selector(registerUserNotificationSettings:)] ) {
        [[UIApplication sharedApplication] registerUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeAlert|UIRemoteNotificationTypeSound|UIRemoteNotificationTypeBadge
                                                                                                              categories:nil]];
    } else {
        [[UIApplication sharedApplication] registerForRemoteNotificationTypes:UIRemoteNotificationTypeAlert|UIRemoteNotificationTypeBadge|UIRemoteNotificationTypeSound];
    }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ( !self.suppressBalloon ) {
            [self.onboardingCtrl showCalloutWithText:@"Tap \"OK\" to allow us to send you occasional push notifications."
                                     pointerPosition:180.0
                                            position:CGPointMake(self.onboardingCtrl.view.frame.size.width/2.0,
                                                                 self.onboardingCtrl.view.frame.size.height/2.0+(self.onboardingCtrl.view.frame.size.height/4.0))];
        }
    });
    
}

- (void)closeOutOnboarding {
   /* [UIView animateWithDuration:0.25 animations:^{
        [self.masterCtrl.blurView.layer setOpacity:0.0];
        [self.masterCtrl.darkBgView.layer setOpacity:0.35];
    } completion:^(BOOL finished) {*/
    [self.onboardingCtrl hideCallout];
    [UIView animateWithDuration:0.33 animations:^{
        [self.masterCtrl.horizDividerLine setAlpha:0.4];
        [self.masterCtrl.blurView.layer setOpacity:0.0];
    } completion:^(BOOL finished) {
        /*[[SessionManager shared] fetchOnboardingProgramWithSegment:3 completed:^(id returnedObject) {
            
            [[AudioManager shared] setTemporaryMutex:NO];
            [self.masterCtrl onboarding_beginOutro];
            [self.masterCtrl.liveProgressViewController show];
            
        }];*/
        [self endOnboarding];
    }];

   // }];
}

- (void)endOnboarding {
    [[AudioManager shared] setRelativeFauxDate:nil];
    [self.onboardingCtrl.view removeFromSuperview];
    [self.masterCtrl onboarding_fin];
}

@end
