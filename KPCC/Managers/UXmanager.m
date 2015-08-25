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
#import <Lock-Facebook/A0FacebookAuthenticator.h>

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

- (void)timeBegin {
    self.operationBeganDate = [NSDate date];
}

- (void)timeEnd:(NSString*)operationName {
    NSDate *now = [NSDate date];
    NSTimeInterval execution = [now timeIntervalSinceDate:self.operationBeganDate];
    NSLog(@"%@ Running Time : %f",operationName,execution);
}

- (void)load {
    if ( self.settings ) {
        self.settings = nil;
    }
    
    _lock = [A0Lock newLock];
    _store = [A0SimpleKeychain keychainWithService:@"Auth0"];
    A0FacebookAuthenticator *facebook = [A0FacebookAuthenticator newAuthenticatorWithDefaultPermissions];
    [_lock registerAuthenticators:@[facebook]];
    
    NSData *data = [[NSUserDefaults standardUserDefaults] objectForKey:@"settings"];
    if ( data ) {
        self.settings = (Settings*)[NSKeyedUnarchiver unarchiveObjectWithData:data];
    } else {
        self.settings = [Settings new];
    }
    
    NSLog(@"Device Token : %@",[self.settings pushTokenString]);
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

- (BOOL)userHasSeenScrubbingOnboarding {
    return self.settings.userHasViewedScrubbingOnboarding;
}

- (void)loadOnboarding {
    
    [self listenForQueues];
    
    self.committedActions = [NSMutableDictionary new];
    
    SCPRAppDelegate *del = (SCPRAppDelegate*)[[UIApplication sharedApplication] delegate];
    UIWindow *mw = [del window];
    [mw addSubview:del.onboardingController.view];
    
    SCPRNavigationController *nav = [del masterNavigationController];
    
    [self hideMenuButton];
    
    del.onboardingController.view.frame = CGRectMake(0.0,0.0,mw.frame.size.width,
                                                     mw.frame.size.height);
    [del.onboardingController prepare];
    self.onboardingCtrl = del.onboardingController;
    self.onboardingCtrl.view.alpha = 0.0f;
    self.onboardingCtrl.lensVC.view.layer.opacity = 0.0f;
    self.onboardingCtrl.orangeStripView.backgroundColor = [[UIColor kpccOrangeColor] translucify:0.6];
    [self.onboardingCtrl.orangeStripView removeFromSuperview];
    
    self.onboardingCtrl.textCalloutBalloonCtrl.view.alpha = 0.0f;
    self.onboardingCtrl.navbarMask = [[UIView alloc] initWithFrame:CGRectMake(0.0,0.0,[[UIScreen mainScreen] bounds].size.width,4.0)];
    self.onboardingCtrl.navbarMask.backgroundColor = [UIColor blackColor];
    nav.navigationBar.layer.mask = [self.onboardingCtrl.navbarMask layer];
    
    [self.onboardingCtrl.view layoutIfNeeded];
    
    NSString *lisaPath = [[NSBundle mainBundle] pathForResource:@"onboarding-voiceover"
                                                         ofType:@"m4a"];
    NSString *musicPath = [[NSBundle mainBundle] pathForResource:@"onboarding-music-bed"
                                                          ofType:@"m4a"];
    
    NSError *lisaError = nil;
    NSError *musicError = nil;
    self.lisaPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:lisaPath]
                                                             error:&lisaError];
    self.musicPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:musicPath]
                                                              error:&musicError];
    [self.lisaPlayer prepareToPlay];
    [self.musicPlayer prepareToPlay];
    
    //self.lisaPlayer.volume = 1.0f;
    //self.musicPlayer.volume = 0.2;
    
}

- (void)beginOnboarding:(SCPRMasterViewController*)masterCtrl {
    
    [[AudioManager shared] setCurrentAudioMode:AudioModeOnboarding];
    
    self.masterCtrl = masterCtrl;
    self.onboardingCtrl.view.alpha = 1.0f;
    [self.masterCtrl primeOnboarding];
    
    self.onboardingCtrl.interactionButton.frame = [self.masterCtrl.view convertRect:self.masterCtrl.initialControlsView.frame
                                                                             toView:self.onboardingCtrl.view];
    [self.onboardingCtrl.interactionButton addTarget:self.masterCtrl
                                              action:@selector(initialPlayTapped:)
                                    forControlEvents:UIControlEventTouchUpInside];
    
    [self.onboardingCtrl.view addSubview:self.onboardingCtrl.interactionButton];
    [self.onboardingCtrl.view layoutIfNeeded];
    
}

- (void)fadeInBranding {
    [self.onboardingCtrl revealBrandingWithCompletion:^{
        [self.masterCtrl onboarding_revealPlayerControls];
    }];
}

- (void)fadeOutBrandingWithCompletion:(CompletionBlock)completed {
    
    
    [UIView animateWithDuration:0.25 animations:^{
        self.onboardingCtrl.brandingView.alpha = 0.0f;
        [self.masterCtrl.blurView setNeedsDisplay];
        self.onboardingCtrl.navbarMask.frame = CGRectMake(self.onboardingCtrl.navbarMask.frame.origin.x,
                                                          0.0,
                                                          self.onboardingCtrl.navbarMask.frame.size.width,
                                                          64.0);
        [self hideMenuButton];
        
    } completion:^(BOOL finished) {
        [self.onboardingCtrl.navbarMask.layer removeFromSuperlayer];
        [self.onboardingCtrl.view layoutIfNeeded];
        [self.masterCtrl.view layoutIfNeeded];
        [self.onboardingCtrl.notificationsView layoutIfNeeded];
        
        completed();
    }];
}

- (void)beginAudio {
    
    
    [UIView animateWithDuration:0.66 animations:^{
        self.masterCtrl.blurView.alpha = 0.0f;
    } completion:^(BOOL finished) {
        
        [[UIApplication sharedApplication] setStatusBarHidden:NO
                                                withAnimation:UIStatusBarAnimationSlide];
        
        [UIView animateWithDuration:0.15 animations:^{
            [self.masterCtrl.view setNeedsUpdateConstraints];
            [self.masterCtrl.liveStreamView setNeedsUpdateConstraints];
            [self.masterCtrl.liveStreamView setNeedsLayout];
            [self.masterCtrl.view layoutIfNeeded];
            [self.masterCtrl.liveStreamView layoutIfNeeded];
            [self.masterCtrl.programImageView layoutIfNeeded];
        }];
        
        [self.masterCtrl onboarding_beginOnboardingAudio];
        

        self.onboardingCtrl.interactionButton.frame = [self.masterCtrl.view convertRect:self.masterCtrl.playerControlsView.frame
                                                       
                                                                                 toView:self.onboardingCtrl.view];
        
        [self.onboardingCtrl.interactionButton removeTarget:nil
                                                     action:nil
                                           forControlEvents:UIControlEventAllEvents];
        
        [self.onboardingCtrl.interactionButton addTarget:self
                                                  action:@selector(godPauseOrPlay)
                                        forControlEvents:UIControlEventTouchUpInside];
        
        [self.onboardingCtrl.orangeStripView removeFromSuperview];
        
        
        [self.musicPlayer play];
        [self.lisaPlayer play];
        
        self.observerTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                                              target:self
                                                            selector:@selector(fireHandler)
                                                            userInfo:nil
                                                             repeats:YES];
        
        
    }];
    
    
}

- (void)godPauseOrPlay {
    if ( self.paused ) {
        [self.lisaPlayer play];
        [self.musicPlayer play];
        [[AudioManager shared].audioPlayer play];
        self.paused = NO;
    } else {
        [self.lisaPlayer pause];
        [self.musicPlayer pause];
        [[AudioManager shared].audioPlayer pause];
        self.paused = YES;
    }
}

- (void)killAudio {
    [self.lisaPlayer stop];
    [self.musicPlayer stop];
    [[AudioManager shared] stopAudio];
}

- (void)presentLensOverRewindButton {
    self.onboardingCtrl.interactionButton.alpha = 0.0f;
    [UIView animateWithDuration:0.15 animations:^{
        self.masterCtrl.liveRewindAltButton.alpha = 1.0f;
    } completion:^(BOOL finished) {
        CGPoint origin = self.masterCtrl.liveRewindAltButton.frame.origin;
        [self.onboardingCtrl revealLensWithOrigin:[self.masterCtrl.liveStreamView convertPoint:CGPointMake(origin.x+5.0, origin.y+3.0)
                                                                                        toView:self.onboardingCtrl.view]];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            
            [self.onboardingCtrl.lensVC squeezeWithAnchorView:self.masterCtrl.liveRewindAltButton completed:^{
                
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self.masterCtrl activateRewind:RewindDistanceOnboardingBeginning];
                });
                
            }];
            
        });
    }];
    
}

- (void)restoreInteractionButton {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.onboardingCtrl.interactionButton.alpha = 1.0f;
    });
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    
}

- (void)listenForQueues {
    
    self.listeningForQueues = YES;
    self.keyPoints = [@{
                        @"8" : @"expandButton",
                        @"18" : @"activateDropdown",
                        @"21" : @"selectFirstMenuItem",
                        @"25" : @"selectSecondMenuItem",
                        @"29" : @"closeMenu",
                        @"34" : @"askForNotifications" } mutableCopy];
    
}


- (void)fireHandler {
    NSInteger t = self.lisaPlayer.currentTime;
    if ( self.listeningForQueues ) {
        [self handleKeypoint:t];
    }
}


- (void)handleKeypoint:(NSInteger)keypoint {
    NSString *key = [NSString stringWithFormat:@"%ld",(long)keypoint];
    NSString *value = self.keyPoints[key];
    if ( value && !self.committedActions[value] ) {
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
        if ( SEQ(value, @"askForNotifications") ) {
            [self askForPushNotifications];
        }
        if ( SEQ(value, @"expandButton") ) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self.masterCtrl.playPauseButton stretch];
            });
        }
        self.committedActions[value] = @1;
    }
}

- (void)activateDropdown {
    SCPRAppDelegate *del = (SCPRAppDelegate*)[[UIApplication sharedApplication] delegate];
    SCPRNavigationController *nav = [del masterNavigationController];
    [UIView animateWithDuration:0.2 animations:^{
        [self showMenuButton];
    } completion:^(BOOL finished) {
        [self.onboardingCtrl revealLensWithOrigin:CGPointMake(8.0, 22.0)];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.22 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            
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
            [self restoreInteractionButton];
        }];
    });
}

- (void)selectMenuItem:(NSInteger)menuitem {
    [self.onboardingCtrl revealLensWithOrigin:CGPointMake(10.0, (64*menuitem)+74.0-((menuitem-1)*3.0)-3.0)];
    [self.masterCtrl.pulldownMenu lightUpCellWithIndex:menuitem];
}

- (void)askForPushNotifications {
    
    if ( ![Utils isIOS8] ) {
        self.suppressBalloon = YES;
    }
    
    self.notificationsPromptDisplaying = YES;
    self.listeningForQueues = NO;
    if ( self.observerTimer ) {
        if ( [self.observerTimer isValid] ) {
            [self.observerTimer invalidate];
        }
        self.observerTimer = nil;
    }
    
    [UIView animateWithDuration:0.5 animations:^{
        [self.masterCtrl.blurView.layer setOpacity:1.0];
        [self.masterCtrl.darkBgView.layer setOpacity:0.75];
        [self.masterCtrl.playerControlsView setAlpha:0.0];
        [self.masterCtrl.liveProgressViewController hide];
        [self.masterCtrl.horizDividerLine setAlpha:0.0];
        [self.masterCtrl.liveStreamView setAlpha:0.0];
        [self.masterCtrl.liveProgressViewController.view setAlpha:0.0];
    } completion:^(BOOL finished) {
        [self.onboardingCtrl revealNotificationsPrompt];
        [[AudioManager shared].audioPlayer pause];
        [self.lisaPlayer pause];
    }];
}

- (void)restorePreNotificationUI:(BOOL)prompt {
    [self.onboardingCtrl collapseNotificationsPrompt];
    [UIView animateWithDuration:0.5 animations:^{
        [self.masterCtrl.darkBgView.layer setOpacity:0.0];
        self.masterCtrl.playerControlsView.alpha = 1.0f;
        [self.masterCtrl.liveStreamView setAlpha:1.0f];
        [self.masterCtrl.liveProgressViewController.view setAlpha:1.0f];
    } completion:^(BOOL finished) {
        
        self.notificationsPromptDisplaying = NO;
        if ( prompt ) {
            [self askSystemForNotificationPermissions];
        } else {
            [self closeOutOnboarding];
        }
        
    }];
}

- (void)quietlyAskForNotificationPermissions {
    if ( [[UIApplication sharedApplication] respondsToSelector:@selector(registerUserNotificationSettings:)] ) {
        [[UIApplication sharedApplication] registerUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeAlert|UIRemoteNotificationTypeSound|UIRemoteNotificationTypeBadge
                                                                                                              categories:nil]];
    } else {
        [[UIApplication sharedApplication] registerForRemoteNotificationTypes:UIRemoteNotificationTypeAlert|UIRemoteNotificationTypeBadge|UIRemoteNotificationTypeSound];
    }
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
            [self.masterCtrl.liveProgressViewController hide];
            [self.masterCtrl.playerControlsView setAlpha:0.0];
            [self.onboardingCtrl showCalloutWithText:@"Tap \"OK\" to allow us to send you occasional push notifications."
                                     pointerPosition:180.0
                                            position:CGPointMake(self.onboardingCtrl.view.frame.size.width/2.0,
                                                                 self.onboardingCtrl.view.frame.size.height/2.0+(self.onboardingCtrl.view.frame.size.height/4.0))];
        }
    });
    
}

- (void)closeOutOnboarding {
    
    [self.onboardingCtrl hideCallout];
    
    [UIView animateWithDuration:0.33 animations:^{
        
        [self.masterCtrl.horizDividerLine setAlpha:0.4];
        [self.masterCtrl.blurView.layer setOpacity:0.0];
        [self.masterCtrl.playerControlsView setAlpha:1.0];
        
    } completion:^(BOOL finished) {
        
        [[AudioManager shared].audioPlayer play];
        [self.lisaPlayer play];
        [self.musicPlayer play];
        
    }];
    
}

- (void)endOnboarding {
    
    self.onboardingEnding = YES;
    self.fadeQueue = [[NSOperationQueue alloc] init];
    [self.onboardingCtrl.view removeFromSuperview];
    [self fadePlayer:self.musicPlayer];
    
    [UIView animateWithDuration:0.25 animations:^{
        self.masterCtrl.liveProgressViewController.view.alpha = 0.0f;
        [self showMenuButton];
    } completion:^(BOOL finished) {
        [self.onboardingCtrl.interactionButton removeFromSuperview];
        [self.masterCtrl onboarding_fin];
    }];
    
}

- (void)fadePlayer:(AVAudioPlayer *)player {
    [self fadeThread:player];
}

- (void)fadeThread:(AVAudioPlayer*)player {
    
    if ( player.volume <= 0.0 ) {
        [player stop];
        return;
    }
    
    NSBlockOperation *block = [NSBlockOperation blockOperationWithBlock:^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [player setVolume:(player.volume-0.05)];
            [self fadeThread:player];
        });
    }];
    [self.fadeQueue addOperation:block];
}

- (void)hideMenuButton {
    SCPRAppDelegate *del = [Utils del];
    SCPRNavigationController *nav = [del masterNavigationController];
    nav.menuButton.alpha = 0.0f;
}

- (void)showMenuButton {
    SCPRAppDelegate *del = [Utils del];
    SCPRNavigationController *nav = [del masterNavigationController];
    nav.menuButton.alpha = 1.0f;
}

#pragma mark - SSO
- (SSOType)userLoginType {
    return self.settings.ssoLoginType;
}

- (void)loginWithCredentials:(NSDictionary *)credentials completion:(CompletionBlockWithValue)completion {
    NSString *email = credentials[@"email"];
    NSString *password = credentials[@"password"];
    
    A0Lock *lock = [self lock];
    A0APIClient *client = [lock apiClient];
    A0APIClientAuthenticationSuccess success = ^(A0UserProfile *profile, A0Token *token) {
        NSLog(@"We did it!. Logged in with Auth0.");
        if ( completion ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(@{ @"profile" : profile, @"token" : token });
            });
        }
    };
    
    A0AuthParameters *params = [A0AuthParameters newDefaultParams];
    params[A0ParameterConnection] = @"Username-Password-Authentication"; // Or your configured DB connection
   
    [client loginWithUsername:email
                     password:password
                   parameters:params
                      success:success
                      failure:^(NSError *error) {
                          
                          if ( completion ) {
                              dispatch_async(dispatch_get_main_queue(), ^{
                                  completion(nil);
                              });
                          }
                          
                          NSLog(@"Error : %@",[error localizedDescription]);
                          
                      }];
    
}

- (void)createUserWithMetadata:(NSDictionary *)metadata completion:(CompletionBlockWithValue)completion {
    
    if ( !metadata[@"connection"] ) {
        NSMutableDictionary *revised = [metadata mutableCopy];
        revised[@"connection"] = @"Username-Password-Authentication";
        metadata = [NSDictionary dictionaryWithDictionary:revised];
    }
    
    NSError *jsonError = nil;
    NSData *json = [NSJSONSerialization dataWithJSONObject:metadata
                                                   options:NSJSONWritingPrettyPrinted
                                                     error:&jsonError];
    NSString *jsonString = [[NSString alloc] initWithData:json
                                                 encoding:NSUTF8StringEncoding];
    NSLog(@"JSON Body : %@",jsonString);
    
    NSString *a0apiStr = [NSString stringWithFormat:@"https://kpcc.auth0.com/api/v2/users"];
    
    NSDictionary *globalConfig = [Utils globalConfig];
    NSString *token = globalConfig[@"Auth0"][@"POST"];
    NSMutableURLRequest *mru = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:a0apiStr]];
    [mru setHTTPMethod:@"POST"];
    [mru setHTTPBody:json];
    [mru setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [mru setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [mru setValue:[NSString stringWithFormat:@"%ld", (long)[json length]] forHTTPHeaderField:@"Content-Length"];
    [mru setValue:[NSString stringWithFormat:@"Bearer %@", token] forHTTPHeaderField:@"Authorization"];
    [NSURLConnection sendAsynchronousRequest:mru queue:[NSOperationQueue new]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                               
                               if ( connectionError ) {
                                   NSLog(@"Problems : %@",[connectionError userInfo]);
                               }
                               
                               if ( [(NSHTTPURLResponse*)response statusCode] == 201 ) {
                                   if ( data ) {
                                       NSString *userData = [[NSString alloc] initWithData:data
                                                                                  encoding:NSUTF8StringEncoding];
                                       NSLog(@"User data : %@",userData);
                                       

                                       dispatch_async(dispatch_get_main_queue(), ^{
                                           if ( completion ) {
                                               NSError *jsonError = nil;
                                               NSMutableDictionary *profile = [NSJSONSerialization JSONObjectWithData:data
                                                                                                              options:NSJSONReadingMutableLeaves
                                                                                                                error:&jsonError];
                                               completion(profile);
                                           }
                                       });

                                       
                                   }
                               } else {
                                   if ( data ) {
                                       NSString *userData = [[NSString alloc] initWithData:data
                                                                                  encoding:NSUTF8StringEncoding];
                                       NSLog(@"Response fails with %ld : %@",(long)[(NSHTTPURLResponse*)response statusCode],
                                             userData);
                                       
                                       if ( completion ) {
                                           completion(nil);
                                       }
                                   }
                               }
                               
                               
                           }];
}

- (void)storeTokens:(NSDictionary *)tokenInfo type:(SSOType)type {
    A0Token *token = tokenInfo[@"token"];
    A0UserProfile *profile = tokenInfo[@"profile"];
    
    A0SimpleKeychain *keychain = [A0SimpleKeychain keychainWithService:@"Auth0"];
    [keychain setString:token.idToken forKey:@"id_token"];
    [keychain setString:token.refreshToken forKey:@"refresh_token"];
    [keychain setData:[NSKeyedArchiver archivedDataWithRootObject:profile]
               forKey:@"profile"];
    [self.settings setSsoKey:token.idToken];
    [self.settings setSsoLoginType:type];
    [[UXmanager shared] persist];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"tokens-stored"
                                                        object:nil];
    
}

- (A0UserProfile*)a0profile {
    A0SimpleKeychain *keychain = [A0SimpleKeychain keychainWithService:@"Auth0"];
    return (A0UserProfile*)[NSKeyedUnarchiver unarchiveObjectWithData:[keychain dataForKey:@"profile"]];
}

@end
