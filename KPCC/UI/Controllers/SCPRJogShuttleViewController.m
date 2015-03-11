//
//  SCPRJogShuttleViewController.m
//  Experiments
//
//  Created by Ben Hochberg on 10/17/14.
//  Copyright (c) 2014 Ben Hochberg. All rights reserved.
//

#import "SCPRJogShuttleViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "AudioManager.h"

@interface SCPRJogShuttleViewController ()

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
@property SpinDirection direction;

@property (atomic) BOOL completionBit;
@property (atomic) BOOL killBit;
@property (nonatomic,strong) AVAudioPlayer *rewindTriggerPlayer;
@property BOOL muteSound;

- (void)completeWithCallback:(void (^)(void))completion;
@property (NS_NONATOMIC_IOSONLY, readonly, strong) CAShapeLayer *generateCircleLayer;
- (void)snapFrame;
- (void)animateWithSpeed:(CGFloat)duration
                 tension:(CGFloat)tension
                   color:(UIColor*)color
             strokeWidth:(CGFloat)strokeWidth
            hideableView:(UIView*)viewToHide
              completion:(void (^)(void))completion;

@end

@implementation SCPRJogShuttleViewController

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
    
    @try {
        [self.rewindTriggerPlayer prepareToPlay];
    }
    @catch (NSException *exception) {
        NSLog(@"Throws an exception for hopefully this reason : %@",[exception description]);
    }
    @finally {
        
    }
    
    self.rewindTriggerPlayer.volume = 0.35;
    
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
            hideableView:(UIView *)viewToHide
               direction:(SpinDirection)direction
               withSound:(BOOL)withSound completion:(void (^)(void))completion {
    
    self.tension = 0.75;
    self.strokeColor = [UIColor whiteColor];
    self.strokeWidth = 1.5f;
    self.muteSound = !withSound;
    self.direction = direction;
    
    [self animateWithSpeed:duration
                   tension:self.tension
                     color:self.strokeColor
               strokeWidth:self.strokeWidth
              hideableView:viewToHide
                completion:completion];
    
}

- (void)animateIndefinitelyWithViewToHide:(UIView *)hideableView completion:(void (^)(void))completion {
    
    if ( self.spinning ) {
        [self endAnimations];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.7 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self animateIndefinitelyWithViewToHide:hideableView completion:completion];
        });
        return;
    }
    
    self.tension = 0.75;
    self.strokeColor = [UIColor whiteColor];
    self.strokeWidth = 1.5f;
    self.direction = SpinDirectionForward;
    self.soundPlayedBit = YES;
    self.completionBit = NO;
    self.view.alpha = 1.0;
    self.view.layer.opacity = 1.0;
    
    [self animateWithSpeed:0.76
                   tension:self.tension
                     color:self.strokeColor
               strokeWidth:self.strokeWidth
              hideableView:hideableView
                completion:completion];
    
}

- (void)animateWithSpeed:(CGFloat)duration
                 tension:(CGFloat)tension
                   color:(UIColor *)color
             strokeWidth:(CGFloat)strokeWidth
            hideableView:(UIView*)viewToHide
              completion:(void (^)(void))completion {
    
    self.spinning = YES;
    if ( !self.soundPlayedBit ) {
        self.soundPlayedBit = YES;
        [[AudioManager shared] adjustAudioWithValue:-0.5 completion:^{
            if ( !self.muteSound ) {
                [self.rewindTriggerPlayer play];
            }
            [self animateWithSpeed:duration
                           tension:tension
                             color:color
                       strokeWidth:strokeWidth
                      hideableView:viewToHide
                        completion:completion];
        }];
        
        return;
    }
    
    self.tension = tension;

    
    if ( !self.circleLayer ) {
    
        CGPoint arcCenter = CGPointMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds));
        CGFloat radius = CGRectGetMidX(self.view.bounds);
        
        CGFloat startAngle = self.direction == SpinDirectionBackward ? 2*M_PI*1-M_PI_2 : 2*M_PI*0-M_PI_2;
        CGFloat endAngle = self.direction == SpinDirectionBackward ? 2*M_PI*0-M_PI_2 : 2*M_PI*1-M_PI_2;
        self.circlePath = [UIBezierPath bezierPathWithArcCenter:arcCenter
                                                     radius:radius-strokeWidth
                                                 startAngle:startAngle
                                                   endAngle:endAngle
                                                  clockwise:self.direction == SpinDirectionForward];
        self.strokeWidth = strokeWidth;
        self.strokeColor = color;
        self.view.backgroundColor = [UIColor clearColor];
    
        self.circleLayer = [self generateCircleLayer];
        [self.view.layer addSublayer:self.circleLayer];
        self.circleLayer.opacity = 1.0;
        
        [UIView animateWithDuration:0.15 animations:^{
            self.prehiddenFrame = viewToHide.frame;
            viewToHide.alpha = 0.0;
        }];
        
    }
    
    [CATransaction begin]; {
        [CATransaction setCompletionBlock:^{
            if ( self.completionBit ) {
                [UIView animateWithDuration:0.15 animations:^{
                    viewToHide.alpha = 1.0;
                } completion:^(BOOL finished) {
                    if ( self.killBit ) {
                        self.completionBit = NO;
                        self.killBit = NO;
                        return;
                    }
                    
                    self.completionBit = NO;
                    if ( completion )
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
        
        CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
        CGFloat halfSpeed = duration / 2.0;
        animation.duration = halfSpeed;
        animation.removedOnCompletion = NO;
        

        self.circleLayer.strokeColor = self.strokeColor.CGColor;
        NSNumber *from = @(0.0);
        NSNumber *to = @(tension);
        animation.cumulative = YES;
        animation.fromValue = from;
        animation.toValue = to;
        animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
        animation.autoreverses = YES;
        [self.circleLayer addAnimation:animation
                                forKey:@"animateCircle"];
        
        CABasicAnimation* rotationAnimation;
        rotationAnimation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
        
        CGFloat degrees = 0.0;
        CGFloat modifier = self.direction == SpinDirectionBackward ? -1.0 : 1.0;
        if ( self.forceSingleRotation ) {
            degrees = modifier * M_PI * 4.0;
        } else {
            degrees = modifier * M_PI * 4.0;
        }
        
        rotationAnimation.toValue = [NSNumber numberWithFloat:degrees];
        rotationAnimation.duration = duration;
        rotationAnimation.cumulative = YES;
        rotationAnimation.repeatCount = 1.0;
        rotationAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
        rotationAnimation.removedOnCompletion = YES;
        [self.view.layer addAnimation:rotationAnimation
         forKey:@"transform.rotation.z"];
        
        
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
    self.spinning = NO;
    self.completionBit = NO;
    self.soundPlayedBit = NO;
    [self.circleLayer removeFromSuperlayer];
    self.circleLayer = nil;
    if ( completion ) {
        dispatch_async(dispatch_get_main_queue(), completion);
    }
#endif
}

- (void)endAnimations {
    if ( self.spinning ) {
        [self setCompletionBit:YES];
    }
}

- (void)killAnimations {
    if ( self.spinning ) {
        [self setKillBit:YES];
        [self setCompletionBit:YES];
    }
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
