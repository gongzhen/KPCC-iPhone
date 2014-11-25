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
    
    self.lensTopConstraint.constant = origin.y;
    self.lenstLeftConstraint.constant = origin.x;
    
    POPSpringAnimation *scaleAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerScaleXY];
    scaleAnimation.fromValue  = [NSValue valueWithCGSize:CGSizeMake(0.0f, 0.0f)];
    scaleAnimation.toValue  = [NSValue valueWithCGSize:CGSizeMake(1.0f, 1.0f)];
    scaleAnimation.springBounciness = 1.0f;
    scaleAnimation.springSpeed = .5f;

    
    self.lensVC.view.layer.opacity = 1.0;
    
    [self.lensVC.view.layer pop_addAnimation:scaleAnimation forKey:@"popToVisible"];
    
}

- (void)hideLens {
    POPSpringAnimation *scaleAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerScaleXY];
    scaleAnimation.fromValue  = [NSValue valueWithCGSize:CGSizeMake(1.0f, 1.0f)];
    scaleAnimation.toValue  = [NSValue valueWithCGSize:CGSizeMake(0.0f, 0.0f)];
    scaleAnimation.springBounciness = 1.0f;
    scaleAnimation.springSpeed = .5f;
    [self.lensVC.view.layer pop_addAnimation:scaleAnimation forKey:@"popToInvisible"];
}

- (void)revealBrandingWithCompletion:(CompletionBlock)completed {
    self.brandingView.clipsToBounds = YES;
    [UIView animateWithDuration:0.33f animations:^{
        self.dividerView.alpha = 1.0f;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.45f delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            [self.logoTopAnchor setConstant:10.0f];
            [self.sloganTopAnchor setConstant:13.0f];
            [self.brandingView layoutIfNeeded];
            self.kpccLogoView.alpha = 1.0f;
            self.welcomeLabel.alpha = 1.0f;
        } completion:^(BOOL finished) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                completed();
            });
        }];
    }];
}

- (void)revealNotificationsPrompt {
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

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
