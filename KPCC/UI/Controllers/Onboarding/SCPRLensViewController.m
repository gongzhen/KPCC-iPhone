//
//  SCPRLensViewController.m
//  KPCC
//
//  Created by Ben Hochberg on 11/19/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "SCPRLensViewController.h"
#import "DesignManager.h"
#import "UIColor+UICustom.h"
#import <POP/POP.h>

@interface SCPRLensViewController ()

@end

@implementation SCPRLensViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)prepare {
    CGPoint arcCenter = CGPointMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds));
    CGFloat radius = CGRectGetMidX(self.view.bounds);
    
    CGFloat startAngle = 2*M_PI*0-M_PI_2;
    CGFloat endAngle = 2*M_PI*1-M_PI_2;
    
    self.circlePath = [UIBezierPath bezierPathWithArcCenter:arcCenter
                                                     radius:radius
                                                 startAngle:startAngle
                                                   endAngle:endAngle
                                                  clockwise:YES];
    self.view.backgroundColor = [UIColor clearColor];
    
    CAShapeLayer *circle = [CAShapeLayer layer];
    
    circle.path = self.circlePath.CGPath;
    circle.fillColor = [[UIColor virtualWhiteColor] translucify:0.33].CGColor;
    circle.strokeColor = [UIColor virtualWhiteColor].CGColor;
    circle.lineWidth = 3.0f;
    circle.opacity = 1.0f;
    circle.strokeStart = 0.0f;
    circle.strokeEnd = 1.0f;
    
    self.circleShape = circle;
    [self.view.layer addSublayer:self.circleShape];
    
}

- (void)squeezeWithAnchorView:(UIView*)anchorView completed:(Block)completed {
    POPSpringAnimation *scaleAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerScaleXY];
    scaleAnimation.fromValue  = [NSValue valueWithCGSize:CGSizeMake(1.0f, 1.0f)];
    scaleAnimation.toValue  = [NSValue valueWithCGSize:CGSizeMake(0.75f, 0.75f)];
    scaleAnimation.springBounciness = 1.0f;
    scaleAnimation.springSpeed = .5f;
    scaleAnimation.autoreverses = YES;
    [scaleAnimation setCompletionBlock:^(POPAnimation *a, BOOL c) {
        if ( !self.lock ) {
            self.lock = YES;
            [UIView animateWithDuration:0.33 animations:^{
                self.view.alpha = 0.0f;
            } completion:^(BOOL finished) {
                completed();
            }];
        }
    }];

    
    if ( anchorView ) {
        POPSpringAnimation *anchorScale = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerScaleXY];
        anchorScale.fromValue  = [NSValue valueWithCGSize:CGSizeMake(1.0f, 1.0f)];
        anchorScale.toValue  = [NSValue valueWithCGSize:CGSizeMake(0.94f, 0.94f)];
        anchorScale.springBounciness = 1.0f;
        anchorScale.springSpeed = .5f;
        anchorScale.autoreverses = YES;
        [anchorView.layer pop_addAnimation:anchorScale
                                    forKey:@"anchorTap"];
    }
    
    
    [self.view.layer pop_addAnimation:scaleAnimation
                               forKey:@"tap"];


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
