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

@interface SCPROnboardingViewController ()

@end

@implementation SCPROnboardingViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
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
    self.interactionButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.welcomeLabel proMediumFontize];
    
    //self.view.backgroundColor = [[UIColor orangeColor] translucify:0.25];
    
    //[self.lensVC.view.layer setTransform:CATransform3DMakeScale(0.0, 0.0, 1.0)];
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
    [UIView animateWithDuration:0.33 animations:^{
        self.kpccLogoView.alpha = 1.0;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.33 animations:^{
            self.dividerView.alpha = 1.0;
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:0.33 animations:^{
                self.welcomeLabel.alpha = 1.0;
            } completion:^(BOOL finished) {
                completed();
            }];
        }];
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
