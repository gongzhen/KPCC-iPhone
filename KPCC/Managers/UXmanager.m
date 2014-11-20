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
    del.onboardingController.view.frame = CGRectMake(0.0,0.0,mw.frame.size.width,
                                                     mw.frame.size.height);
    [del.onboardingController prepare];
    self.onboardingCtrl = del.onboardingController;
    self.onboardingCtrl.view.alpha = 0.0;
    self.onboardingCtrl.lensVC.view.layer.opacity = 0.0;
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

}

- (void)fadeInBranding {
    [self.onboardingCtrl revealBrandingWithCompletion:^{
        [self.masterCtrl onboarding_revealPlayerControls];
    }];
}

- (void)beginAudio {
    [self.masterCtrl onboarding_beginOnboardingAudio];
}

- (void)presentLensOverRewindButton {
    CGPoint origin = self.masterCtrl.liveRewindAltButton.frame.origin;
    [self.onboardingCtrl revealLensWithOrigin:[self.masterCtrl.view convertPoint:CGPointMake(origin.x+5.0, origin.y)
                                                                          toView:self.onboardingCtrl.view]];
  
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        [self.onboardingCtrl.lensVC squeeze:^{
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self.masterCtrl activateRewind:RewindDistanceOnboardingBeginning];
            });
            
        }];
        
    });
}

@end
