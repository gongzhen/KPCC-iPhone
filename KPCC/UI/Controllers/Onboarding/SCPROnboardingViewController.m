//
//  SCPROnboardingViewController.m
//  KPCC
//
//  Created by Ben Hochberg on 11/19/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "SCPROnboardingViewController.h"
#import "UIColor+UICustom.h"
#import "UILabel+Additions.h"
#import "DesignManager.h"
#import "UXmanager.h"
#import "SCPRNavigationController.h"

@interface SCPROnboardingViewController ()

@end

@implementation SCPROnboardingViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (void)viewDidAppear:(BOOL)animated {

}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void)prepare {
    [self.lensVC prepare];
    
    self.lensVC.view.layer.opacity = 0.0;
    self.kpccLogoView.alpha = 0.0;
    self.dividerView.alpha = 0.0;
    self.welcomeLabel.alpha = 0.0;
    self.brandingView.alpha = 1.0;
    self.notificationsView.alpha = 0.0;
    self.orangeStripView.alpha = 0.0;
    
    [[DesignManager shared] sculptButton:self.yesToNotificationsButton
                               withStyle:SculptingStylePeriwinkle
                                 andText:@"Yes, I'm interested!"];
    [[DesignManager shared] sculptButton:self.noToNotificationsButton
                               withStyle:SculptingStyleClearWithBorder
                                 andText:@"Not right now."];
    
    [self.yesToNotificationsButton addTarget:self
                                      action:@selector(yesToNotifications)
                            forControlEvents:UIControlEventTouchUpInside];
    
    [self.noToNotificationsButton addTarget:self
                                     action:@selector(noToNotifications)
                           forControlEvents:UIControlEventTouchUpInside];
    
    [self.notificationsCaptionLabel proMediumFontize];
    [self.notificationsQuestionLabel proBookFontize];
    
    self.interactionButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.welcomeLabel proMediumFontize];
    
    if ( [Utils isThreePointFive] ) {
        [self.buttonAnchor setConstant:325.0];
    }
    
}

- (void)revealLensWithOrigin:(CGPoint)origin {
    
    CGFloat modifier = [Utils isIOS8] ? 0.0 : 20.0;
    self.lensTopConstraint.constant = origin.y+modifier;
    self.lenstLeftConstraint.constant = origin.x+modifier;
    
    POPSpringAnimation *scaleAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerScaleXY];
    scaleAnimation.fromValue  = [NSValue valueWithCGSize:CGSizeMake(0.0f, 0.0f)];
    scaleAnimation.toValue  = [NSValue valueWithCGSize:CGSizeMake(1.0f, 1.0f)];
    scaleAnimation.springBounciness = 1.0f;
    scaleAnimation.springSpeed = .5f;

    
    self.lensVC.view.layer.opacity = 1.0;
    
    [self.lensVC.view.layer pop_addAnimation:scaleAnimation forKey:@"popToVisible"];
    
}

- (void)hideLens {
    POPBasicAnimation *scaleAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerScaleXY];
    scaleAnimation.fromValue  = [NSValue valueWithCGSize:CGSizeMake(1.0f, 1.0f)];
    scaleAnimation.toValue  = [NSValue valueWithCGSize:CGSizeMake(0.0f, 0.0f)];
    scaleAnimation.duration = 0.15f;
    //scaleAnimation.springBounciness = 1.0f;
    //scaleAnimation.springSpeed = .5f;
    [self.lensVC.view.layer pop_addAnimation:scaleAnimation forKey:@"popToInvisible"];
}

- (void)revealBrandingWithCompletion:(CompletionBlock)completed {
    self.brandingView.clipsToBounds = YES;
    
    self.dividerView.layer.transform = CATransform3DMakeScale(0.025f, 1.0f, 1.0f);
    self.dividerView.layer.opacity = 0.4;
    POPBasicAnimation *scaleAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerScaleXY];
    scaleAnimation.fromValue  = [NSValue valueWithCGSize:CGSizeMake(0.025f, 1.0f)];
    scaleAnimation.toValue  = [NSValue valueWithCGSize:CGSizeMake(1.0f, 1.0f)];
    scaleAnimation.duration = 1.0;
    [self.dividerView.layer pop_addAnimation:scaleAnimation forKey:@"scaleAnimation"];
    
    [UIView animateWithDuration:0.33f animations:^{
        self.dividerView.alpha = 1.0f;
    } completion:^(BOOL finished) {
        
        [UIView animateWithDuration:0.65f delay:0.0 options:UIViewAnimationOptionCurveEaseIn animations:^{
            self.kpccLogoView.alpha = 1.0f;
            self.welcomeLabel.alpha = 1.0f;
        } completion:^(BOOL finished) {
            
        }];
        
        [UIView animateWithDuration:0.45f delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            [self.logoTopAnchor setConstant:10.0f];
            [self.sloganTopAnchor setConstant:13.0f];
            [self.brandingView layoutIfNeeded];
        } completion:^(BOOL finished) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                completed();
            });
        }];
    }];
}

- (void)revealNotificationsPrompt {
    
    self.interactionButton.alpha = 0.0;
    
    POPSpringAnimation *scaleAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerScaleXY];
    scaleAnimation.fromValue  = [NSValue valueWithCGSize:CGSizeMake(0.0f, 0.0f)];
    scaleAnimation.toValue  = [NSValue valueWithCGSize:CGSizeMake(1.0f, 1.0f)];
    scaleAnimation.springBounciness = 1.0f;
    scaleAnimation.springSpeed = .5f;
    
    [self.radioIconImage.layer pop_addAnimation:scaleAnimation forKey:@"iconScale"];
    [self.notificationsCaptionLabel.layer pop_addAnimation:scaleAnimation forKey:@"iconScale"];
    [self.notificationsQuestionLabel.layer pop_addAnimation:scaleAnimation forKey:@"iconScale"];
    [self.yesToNotificationsButton.layer pop_addAnimation:scaleAnimation forKey:@"iconScale"];
    [self.noToNotificationsButton.layer pop_addAnimation:scaleAnimation forKey:@"iconScale"];
    
    [UIView animateWithDuration:0.33 animations:^{
        self.notificationsView.alpha = 1.0;
    }];
}

- (void)collapseNotificationsPrompt {
    
    self.interactionButton.alpha = 1.0;
    
    POPSpringAnimation *scaleAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerScaleXY];
    scaleAnimation.fromValue  = [NSValue valueWithCGSize:CGSizeMake(1.0f, 1.0f)];
    scaleAnimation.toValue  = [NSValue valueWithCGSize:CGSizeMake(0.0f, 0.0f)];
    scaleAnimation.springBounciness = 1.0f;
    scaleAnimation.springSpeed = .5f;
    
    [self.radioIconImage.layer pop_addAnimation:scaleAnimation forKey:@"iconScale"];
    [self.notificationsCaptionLabel.layer pop_addAnimation:scaleAnimation forKey:@"iconScale"];
    [self.notificationsQuestionLabel.layer pop_addAnimation:scaleAnimation forKey:@"iconScale"];
    [self.yesToNotificationsButton.layer pop_addAnimation:scaleAnimation forKey:@"iconScale"];
    [self.noToNotificationsButton.layer pop_addAnimation:scaleAnimation forKey:@"iconScale"];
    
    [UIView animateWithDuration:0.33 animations:^{
        self.notificationsView.alpha = 0.0;
    }];
}

- (void)showCalloutWithText:(NSString *)text pointerPosition:(CGFloat)pointer /*ignore position for now*/ position:(CGPoint)position {
    self.textCalloutBalloonCtrl.view.alpha = 0.0;
    
    CGFloat magicNumber = [Utils isThreePointFive] ? 20.0 : 70.0;
    [self.calloutAnchor setConstant:magicNumber];
    
    
    [self.textCalloutBalloonCtrl slidePointer:170.0];

    [self.view layoutIfNeeded];
    [self.textCalloutBalloonCtrl.view layoutIfNeeded];
    self.textCalloutBalloonCtrl.bodyTextLabel.text = text;
    
    [UIView animateWithDuration:0.4 animations:^{
        self.textCalloutBalloonCtrl.view.alpha = 1.0;
    }];
}

- (void)hideCallout {
    [UIView animateWithDuration:0.4 animations:^{
        self.textCalloutBalloonCtrl.view.alpha = 0.0;
    } completion:^(BOOL finished) {
        [self.textCalloutBalloonCtrl.view removeFromSuperview];
    }];
}

- (void)yesToNotifications {
    [[UXmanager shared] restorePreNotificationUI:YES];
}

- (void)noToNotifications {
    [[UXmanager shared] restorePreNotificationUI:NO];
}

- (void)ondemandMode {
    self.view.alpha = 0.0;
    self.onDemandContainerView.alpha = 1.0;
    self.notificationsView.alpha = 0.0;
    self.brandingView.alpha = 0.0;
    self.textCalloutBalloonCtrl.view.alpha = 0.0;
    self.lensVC.view.alpha = 0.0;
    self.view.backgroundColor = [[UIColor virtualBlackColor] translucify:0.75];
    
    if ( [[UXmanager shared] userHasSeenScrubbingOnboarding] ) {
        self.swiper = [[UISwipeGestureRecognizer alloc] initWithTarget:self
                                                            action:@selector(dismissOnDemand)];
    } else {
        self.swiper = [[UISwipeGestureRecognizer alloc] initWithTarget:self
                                                                action:@selector(finishOnDemandAndGoToScrubbing)];
    }
    
    self.swiper.direction = UISwipeGestureRecognizerDirectionLeft|UISwipeGestureRecognizerDirectionRight;
    [self.view addGestureRecognizer:self.swiper];
    
    [self.swipeToSkipLabel proBookFontize];
    [self.gotItButton.titleLabel proSemiBoldFontize];
    [self.gotItButton setTitleColor:[UIColor kpccPeriwinkleColor]
                           forState:UIControlStateNormal];
    [self.gotItButton setTitleColor:[UIColor kpccPeriwinkleColor]
                           forState:UIControlStateHighlighted];
    
    if ( !self.view.superview ) {
        SCPRAppDelegate *del = [Utils del];
        self.view.frame = CGRectMake(0.0,0.0,del.window.frame.size.width,
                                     del.window.frame.size.height);
        [del.window addSubview:self.view];
    }
    
    if ( [[UXmanager shared] userHasSeenScrubbingOnboarding] ) {
        [self.gotItButton addTarget:self
                             action:@selector(dismissOnDemand)
                   forControlEvents:UIControlEventTouchUpInside
                            special:YES];
    } else {
        [self.gotItButton addTarget:self
                             action:@selector(finishOnDemandAndGoToScrubbing)
                   forControlEvents:UIControlEventTouchUpInside];
    }
    

    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.25 animations:^{
            self.view.alpha = 1.0;
        }];
    });
}

- (void)finishOnDemandAndGoToScrubbing {
    [[UXmanager shared].settings setUserHasViewedOnDemandOnboarding:YES];
    [[UXmanager shared] persist];
    self.dontFade = YES;
    [self scrubbingMode];
}

- (void)scrubbingMode {
    
    if ( !self.dontFade ) {
        self.view.alpha = 0.0;
    }
    
    [UIView animateWithDuration:0.25 animations:^{
        self.onDemandContainerView.alpha = 0.0;
    } completion:^(BOOL finished) {
        
        self.scrubbingContainerView.alpha = 0.0;
        [self.view addSubview:self.scrubbingContainerView];
        
        self.scrubbingContainerView.translatesAutoresizingMaskIntoConstraints = NO;
        

        
        self.notificationsView.alpha = 0.0;
        self.brandingView.alpha = 0.0;
        self.textCalloutBalloonCtrl.view.alpha = 0.0;
        self.lensVC.view.alpha = 0.0;
        self.view.backgroundColor = [[UIColor virtualBlackColor] translucify:0.75];
        
        self.scrubbingSwiper = [[UISwipeGestureRecognizer alloc] initWithTarget:self
                                                                action:@selector(dismissOnDemand)];
        self.scrubbingSwiper.direction = UISwipeGestureRecognizerDirectionLeft|UISwipeGestureRecognizerDirectionRight;
        
        if ( self.swiper ) {
            [self.view removeGestureRecognizer:self.swiper];
            self.swiper = nil;
        }
        
        [self.view addGestureRecognizer:self.scrubbingSwiper];
        
        [self.scrubbingSwipeToSkipLabel proBookFontize];
        
        [self.scrubbingGotItButton.titleLabel proSemiBoldFontize];
        [self.scrubbingGotItButton setTitleColor:[UIColor kpccPeriwinkleColor]
                               forState:UIControlStateNormal];
        [self.scrubbingGotItButton setTitleColor:[UIColor kpccPeriwinkleColor]
                               forState:UIControlStateHighlighted];
        
        BOOL fadeUpScrubbingView = NO;
        if ( !self.view.superview ) {
            
            self.view.alpha = 0.0;
            SCPRAppDelegate *del = [Utils del];
            self.view.frame = CGRectMake(0.0,0.0,del.window.frame.size.width,
                                         del.window.frame.size.height);
            [del.window addSubview:self.view];
            self.scrubbingContainerView.alpha = 1.0;
        } else {
            self.scrubbingContainerView.alpha = 0.0;
            fadeUpScrubbingView = YES;
        }
        
        self.scrubbingContainerView.backgroundColor = [UIColor clearColor];
        
        NSLayoutConstraint *hCenter = [NSLayoutConstraint constraintWithItem:self.scrubbingContainerView
                                                                   attribute:NSLayoutAttributeCenterX
                                                                   relatedBy:NSLayoutRelationEqual
                                                                      toItem:self.view
                                                                   attribute:NSLayoutAttributeCenterX
                                                                  multiplier:1.0
                                                                    constant:0.0];
        
        NSLayoutConstraint *yCenter = [NSLayoutConstraint constraintWithItem:self.scrubbingContainerView
                                                                   attribute:NSLayoutAttributeCenterY
                                                                   relatedBy:NSLayoutRelationEqual
                                                                      toItem:self.view
                                                                   attribute:NSLayoutAttributeCenterY
                                                                  multiplier:1.0
                                                                    constant:100.0];
        
        [self.view addConstraints:@[hCenter,yCenter]];
        
        
        [self.scrubbingGotItButton addTarget:self
                             action:@selector(dismissOnDemand)
                   forControlEvents:UIControlEventTouchUpInside
                            special:YES];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [UIView animateWithDuration:0.25 animations:^{
                self.view.alpha = 1.0;
                if ( fadeUpScrubbingView ) {
                    self.scrubbingContainerView.alpha = 1.0;
                }
            }];
        });
    }];
    


}

- (void)dismissOnDemand {
    [UIView animateWithDuration:0.25 animations:^{
        self.onDemandContainerView.alpha = 0.0;
        self.view.alpha = 0.0;
    } completion:^(BOOL finished) {
        [UXmanager shared].settings.userHasViewedOnDemandOnboarding = YES;
        [UXmanager shared].settings.userHasViewedScrubbingOnboarding = YES;
#ifndef TESTING_SCRUBBER
        [[UXmanager shared] persist];
#endif
    }];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
