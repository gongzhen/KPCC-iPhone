//
//  SCPRSpinnerViewController.m
//  KPCC
//
//  Created by Ben Hochberg on 10/29/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "SCPRSpinnerViewController.h"
#import "DesignManager.h"
#import "UIView+PrintDimensions.h"

@interface SCPRSpinnerViewController ()

@property (nonatomic,strong) CAShapeLayer *circleLayer;
@property (nonatomic,strong) UIBezierPath *circlePath;
@property (nonatomic,strong) UIColor *strokeColor;
@property BOOL isSpinning;
@property BOOL completionBit;

- (void)generateCircle;

@end


@implementation SCPRSpinnerViewController
+ (SCPRSpinnerViewController*)o {
    static SCPRSpinnerViewController *spinner = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        spinner = [[SCPRSpinnerViewController alloc] init];
    });
    return spinner;
}

+ (void)spinInCenterOfView:(UIView *)view offset:(CGFloat)yOffset delay:(CGFloat)delay appeared:(CompletionBlock)appeared {
    SCPRSpinnerViewController *spinner = [SCPRSpinnerViewController o];
    
    if ( spinner && spinner.isSpinning ) {
        [spinner.view removeFromSuperview];
    }
    
    spinner.strokeColor = [UIColor kpccOrangeColor];
    spinner.view.frame = CGRectMake(0.0,
                                    0.0,
                                    26.0,
                                    26.0);
    
    spinner.view.alpha = 0.0;
    [view addSubview:spinner.view];
    [spinner.view setNeedsLayout];
    
    [view layoutIfNeeded];
    
    spinner.view.backgroundColor = [UIColor clearColor];
    [spinner generateCircle];
    
    [view printDimensionsWithIdentifier:@"SpinnerContainer"];
    
    spinner.view.center = CGPointMake(view.frame.size.width/2.0,
                                      view.frame.size.height/2.0+yOffset);
    
    [spinner.view printDimensionsWithIdentifier:@"Spinner"];
    
    [UIView animateWithDuration:0.13 animations:^{
        [spinner.view setAlpha:1.0];
    } completion:^(BOOL finished) {
        [spinner spin];
        if ( appeared ) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                appeared();
            });
        }
    }];
}

+ (void)spinInCenterOfView:(UIView *)view offset:(CGFloat)yOffset appeared:(CompletionBlock)appeared {
    [SCPRSpinnerViewController spinInCenterOfView:view
                                           offset:yOffset
                                            delay:1.0
                                         appeared:appeared];
}

+ (void)spinInCenterOfView:(UIView *)view appeared:(CompletionBlock)appeared {
    [SCPRSpinnerViewController spinInCenterOfView:view offset:0.0 appeared:appeared];
}

+ (void)spinInCenterOfViewController:(UIViewController *)viewController appeared:(CompletionBlock)appeared {
    
    [SCPRSpinnerViewController spinInCenterOfView:viewController.view appeared:appeared];
    
}

+ (void)finishSpinning {
    
    NSAssert([NSThread isMainThread], @"*** Ensure this is called on the main thread ***");
    SCPRSpinnerViewController *sp = [SCPRSpinnerViewController o];
    [UIView animateWithDuration:0.33 animations:^{
        [sp.view setAlpha:0.0];
    } completion:^(BOOL finished) {
        [sp.view.layer removeAllAnimations];
        [sp.circleLayer removeAllAnimations];
        [sp.view removeFromSuperview];
        @synchronized(self) {
            sp.isSpinning = NO;
        }
    }];
}

- (void)spin {
    
    @synchronized(self) {
        self.isSpinning = YES;
    }
    
    [CATransaction begin]; {
        [CATransaction setCompletionBlock:^{
         
        }];
        
        CABasicAnimation* opacityAnimation;
        opacityAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
        opacityAnimation.fromValue = @0.0;
        opacityAnimation.toValue = @1.0;
        opacityAnimation.duration = 0.15;
        opacityAnimation.cumulative = YES;
        opacityAnimation.repeatCount = 1;
        opacityAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
        opacityAnimation.removedOnCompletion = NO;
        opacityAnimation.fillMode = kCAFillModeForwards;
        [self.circleLayer addAnimation:opacityAnimation
                               forKey:@"fadeUp"];
        
        
        CABasicAnimation *drawAnimation;
        drawAnimation = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
        drawAnimation.fromValue = @0.0;
        drawAnimation.toValue = @0.65;
        drawAnimation.cumulative = YES;
        drawAnimation.duration = 0.75;
        drawAnimation.removedOnCompletion = NO;
        drawAnimation.fillMode = kCAFillModeForwards;
        [self.circleLayer addAnimation:drawAnimation
                                forKey:@"draw"];
        
    }
    [CATransaction commit];
    
    CABasicAnimation* rotationAnimation;
    rotationAnimation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
    
    rotationAnimation.toValue = [NSNumber numberWithFloat: M_PI];
    rotationAnimation.duration = 0.25;
    rotationAnimation.cumulative = YES;
    rotationAnimation.repeatCount = HUGE_VALF;
    rotationAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    rotationAnimation.removedOnCompletion = YES;
    [self.view.layer addAnimation:rotationAnimation
                           forKey:@"transform.rotation.z"];
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)generateCircle {
    
    if ( self.circleLayer ) return;
    
    CGPoint arcCenter = CGPointMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds));
    CGFloat radius = CGRectGetMidX(self.view.bounds);
    CGFloat startAngle = 2*M_PI*0-M_PI_2;
    CGFloat endAngle = 2*M_PI*1-M_PI_2;
    
    self.circlePath = [UIBezierPath bezierPathWithArcCenter:arcCenter
                                                     radius:radius
                                                 startAngle:startAngle
                                                   endAngle:endAngle
                                                  clockwise:YES];
    
    CAShapeLayer *circle = [CAShapeLayer layer];
    
    circle.path = self.circlePath.CGPath;
    circle.fillColor = [UIColor clearColor].CGColor;
    circle.strokeColor = self.strokeColor.CGColor;
    circle.lineWidth = 1.0;
    circle.opacity = 0.0;
    circle.strokeStart = 0.0;
    circle.strokeEnd = 0.0;
    
    self.circleLayer = circle;
    [self.view.layer addSublayer:self.circleLayer];
    
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
