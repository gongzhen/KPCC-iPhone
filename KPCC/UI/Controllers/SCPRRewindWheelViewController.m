//
//  SCPRRewindWheelViewController.m
//  Experiments
//
//  Created by Ben Hochberg on 10/17/14.
//  Copyright (c) 2014 Ben Hochberg. All rights reserved.
//

#import "SCPRRewindWheelViewController.h"

@interface SCPRRewindWheelViewController ()

@end

@implementation SCPRRewindWheelViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)setupWithColor:(UIColor*)color andStrokeWidth:(CGFloat)strokeWidth {
    self.strokeWidth = strokeWidth;
    self.strokeColor = color;

    CGPoint arcCenter = CGPointMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds));
    CGFloat radius = CGRectGetMidX(self.view.bounds);
    
    self.circlePath = [UIBezierPath bezierPathWithArcCenter:arcCenter
                                                     radius:radius
                                                 startAngle:2*M_PI*1-M_PI_2/*M_PI*/
                                                   endAngle:2*M_PI*0-M_PI_2/*-M_PI*/
                                                  clockwise:NO];
    self.view.backgroundColor = [UIColor clearColor];
    
    self.circleLayer = [self generateCircleLayer];
    
    [self.view.layer addSublayer:self.circleLayer];
    
}

- (CAShapeLayer*)generateCircleLayer {
    CAShapeLayer *circle = [CAShapeLayer layer];
    
    circle.path = self.circlePath.CGPath;
    circle.fillColor = [UIColor clearColor].CGColor;
    circle.strokeColor = self.strokeColor.CGColor;
    circle.lineWidth = self.strokeWidth;
    circle.opacity = 0.0;
    circle.strokeStart = 0.0;
    circle.strokeEnd = 1.0;
    return circle;
}


- (void)animateWithSpeed:(CGFloat)duration tension:(CGFloat)tension completion:(void (^)(void))completion {
    
    [CATransaction begin]; {
        [CATransaction setCompletionBlock:^{
            if ( self.completionBit ) {
                [self completeWithCallback:completion];
            } else {
                self.pingpong = !self.pingpong;
                [self animateWithSpeed:duration
                               tension:tension
                            completion:completion];
            }
        }];
        
        
        self.circleLayer.opacity = 1.0;
        
        
        CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
        animation.duration = duration / 2.0;
        animation.removedOnCompletion = YES;
        
        self.circleLayer.strokeColor = self.strokeColor.CGColor;
        NSNumber *from = @(0.0);
        NSNumber *to = @(tension);
        animation.fromValue = from;
        animation.toValue = to;
        animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
        animation.autoreverses = YES;
        
        [self.circleLayer addAnimation:animation forKey:@"animateCircle"];
        
        CABasicAnimation* rotationAnimation;
        rotationAnimation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
        rotationAnimation.toValue = [NSNumber numberWithFloat: -M_PI * 2.0];
        rotationAnimation.duration = duration;
        rotationAnimation.cumulative = YES;
        rotationAnimation.repeatCount = 1.0;
        rotationAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
        rotationAnimation.removedOnCompletion = NO;
        [self.view.layer addAnimation:rotationAnimation
                          forKey:@"transform.rotation.z"];
        
    }
    [CATransaction commit];
    
}

- (void)completeWithCallback:(void (^)(void))completion {
    [CATransaction begin]; {
        [CATransaction setCompletionBlock:^{
            self.circleLayer.strokeEnd = 1.0;
            if ( completion ) {
                dispatch_async(dispatch_get_main_queue(), completion);
            }
        }];
        
        CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
        animation.duration = 0.5;
        animation.removedOnCompletion = YES;
        
        self.circleLayer.strokeColor = self.strokeColor.CGColor;
        NSNumber *from = @(0.0);
        NSNumber *to = @(1.0);
        animation.fromValue = from;
        animation.toValue = to;
        animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
        animation.autoreverses = NO;
        
        [self.circleLayer addAnimation:animation forKey:@"completeCircle"];
        
    }
    [CATransaction commit];
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
