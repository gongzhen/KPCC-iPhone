//
//  SCPRRewindWheelViewController.m
//  Experiments
//
//  Created by Ben Hochberg on 10/17/14.
//  Copyright (c) 2014 Ben Hochberg. All rights reserved.
//

#import "SCPRRewindWheelViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "AudioManager.h"

@interface SCPRRewindWheelViewController ()

@property (nonatomic,strong) UIColor *strokeColor;
@property (nonatomic,strong) CAShapeLayer *circleLayer;
@property (nonatomic,strong) CAShapeLayer *antiCircleLayer;
@property (nonatomic,strong) CAShapeLayer *palimpsestLayer;
@property (nonatomic,strong) UIBezierPath *circlePath;
@property (nonatomic) double progress;
@property BOOL soundPlayedBit;
@property BOOL firstHalfBit;
@property (nonatomic) CGFloat tension;
@property (nonatomic) CGFloat strokeWidth;
@property (nonatomic) CGRect prehiddenFrame;
@property (atomic) BOOL completionBit;
@property (nonatomic,strong) AVAudioPlayer *rewindTriggerPlayer;

- (void)completeWithCallback:(void (^)(void))completion;
- (CAShapeLayer*)generateCircleLayer;
- (void)snapFrame;

@end

@implementation SCPRRewindWheelViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    

    // Do any additional setup after loading the view.
}

- (void)prepare {
    NSString *path = [[NSBundle mainBundle] pathForResource:@"rewind_beat"
                                                     ofType:@"mp3"];
    NSURL *fileUrl = [NSURL fileURLWithPath:path];
    NSError *fileError = nil;
    self.rewindTriggerPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:fileUrl
                                                                      error:&fileError];
    [self.rewindTriggerPlayer prepareToPlay];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)snapFrame {
    
}

- (CAShapeLayer*)generateCircleLayer {
    CAShapeLayer *circle = [CAShapeLayer layer];
    
    circle.path = self.circlePath.CGPath;
    circle.fillColor = [UIColor clearColor].CGColor;
    circle.strokeColor = self.strokeColor.CGColor;
    circle.lineWidth = self.strokeWidth;
    circle.opacity = 0.0;
    circle.strokeStart = 0.0;
    circle.strokeEnd = 0.0;
    return circle;
}


- (void)animateWithSpeed:(CGFloat)duration
                 tension:(CGFloat)tension
                   color:(UIColor *)color
             strokeWidth:(CGFloat)strokeWidth
            hideableView:(UIView*)viewToHide
              completion:(void (^)(void))completion {
    

    if ( !self.soundPlayedBit ) {
        self.soundPlayedBit = YES;
        if ( [[AudioManager shared] isStreamPlaying] ) {
            [[AudioManager shared] adjustAudioWithValue:-0.1 completion:^{
                [self.rewindTriggerPlayer play];
                [self animateWithSpeed:duration
                               tension:tension
                                 color:color
                           strokeWidth:strokeWidth
                          hideableView:viewToHide
                            completion:completion];
            }];
            
            return;
        } else {
            [self.rewindTriggerPlayer play];
        }
    }
    
    if ( !self.circleLayer ) {
    
        CGPoint arcCenter = CGPointMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds));
        CGFloat radius = CGRectGetMidX(self.view.bounds);
        
        self.circlePath = [UIBezierPath bezierPathWithArcCenter:arcCenter
                                                     radius:radius-1.0
                                                 startAngle:2*M_PI*1-M_PI_2/*M_PI*/
                                                   endAngle:2*M_PI*0-M_PI_2/*-M_PI*/
                                                  clockwise:NO];
        self.strokeWidth = strokeWidth;
        self.strokeColor = color;
        self.view.backgroundColor = [UIColor clearColor];
    
        self.circleLayer = [self generateCircleLayer];
        [self.view.layer addSublayer:self.circleLayer];
        self.circleLayer.opacity = 1.0;
        
        [UIView animateWithDuration:0.15 animations:^{
            self.prehiddenFrame = viewToHide.frame;
            CGAffineTransform tForm = CGAffineTransformMakeScale(0.1, 0.1);
            viewToHide.transform = tForm;
            viewToHide.alpha = 0.0;
        }];
    }
    
    self.tension = tension;
    
    [CATransaction begin]; {
        [CATransaction setCompletionBlock:^{
            [CATransaction begin]; {
                [CATransaction setCompletionBlock:^{
                    if ( self.completionBit ) {
                        [UIView animateWithDuration:0.15 animations:^{
                            CGAffineTransform tForm = CGAffineTransformMakeScale(1.0, 1.0);
                            viewToHide.transform = tForm;
                        } completion:^(BOOL finished) {
                            [self completeWithCallback:completion];
                        }];
                    } else {
                        [self animateWithSpeed:duration
                                       tension:tension
                                         color:color
                                   strokeWidth:strokeWidth
                                  hideableView:viewToHide
                                    completion:completion];
                    }
                }];

                CABasicAnimation* rotationAnimation;
                rotationAnimation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
                rotationAnimation.toValue = [NSNumber numberWithFloat: -M_PI * 4.0];
                rotationAnimation.duration = duration / 2.0;
                rotationAnimation.cumulative = YES;
                rotationAnimation.repeatCount = 1.0;
                rotationAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
                rotationAnimation.removedOnCompletion = NO;
                [self.view.layer addAnimation:rotationAnimation
                                       forKey:@"transform.rotation.z"];
                
                CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
                CGFloat halfSpeed = duration / 2.0;
                animation.duration = halfSpeed;
                animation.removedOnCompletion = NO;
                
                self.circleLayer.strokeColor = self.strokeColor.CGColor;
                NSNumber *from = @(tension);
                NSNumber *to = @(0.25);
                animation.fromValue = from;
                animation.toValue = to;
                animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
                
                [self.circleLayer addAnimation:animation
                                        forKey:@"animateCircle"];
            }
            [CATransaction commit];
        }];
        
        CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
        CGFloat halfSpeed = duration / 2.0;
        animation.duration = halfSpeed;
        animation.removedOnCompletion = NO;
        
        self.circleLayer.strokeColor = self.strokeColor.CGColor;
        NSNumber *from = @(0.0);
        NSNumber *to = @(tension);
        animation.fromValue = from;
        animation.toValue = to;
        animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
        
        [self.circleLayer addAnimation:animation
                                forKey:@"animateCircle"];
        
    }
    [CATransaction commit];
    
}

- (void)completeWithCallback:(void (^)(void))completion {
#ifdef USE_REWIND_UNCOILING
    [CATransaction begin]; {
        [CATransaction setCompletionBlock:^{
            self.circleLayer.strokeEnd = 1.0;
            if ( completion ) {
                dispatch_async(dispatch_get_main_queue(), completion);
            }
        }];
        
        CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
        animation.duration = 0.5;
        animation.removedOnCompletion = NO;
        
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
#else
    if ( completion ) {
        self.completionBit = NO;
        self.soundPlayedBit = NO;
        [self.circleLayer removeFromSuperlayer];
        self.circleLayer = nil;
        dispatch_async(dispatch_get_main_queue(), completion);
    }
#endif
}

- (void)endAnimations {
    [self setCompletionBit:YES];
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
