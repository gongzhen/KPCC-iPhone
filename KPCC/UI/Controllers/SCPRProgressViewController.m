//
//  SCPRProgressViewController.m
//  KPCC
//
//  Created by Ben Hochberg on 11/6/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "SCPRProgressViewController.h"
#import "Utils.h"
#import "AudioManager.h"
#import "SessionManager.h"
#import <pop/POP.h>

@interface SCPRProgressViewController ()

- (void)finishReveal;

@end

@implementation SCPRProgressViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

+ (SCPRProgressViewController*)o {
    static SCPRProgressViewController *pv = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        pv = [[SCPRProgressViewController alloc] initWithNibName:@"SCPRProgressViewController"
                                                          bundle:nil];
    });
    return pv;
}

- (void)viewDidLayoutSubviews {
    [self.liveProgressView setNeedsDisplay];
    [self.currentProgressView setNeedsDisplay];
    [self.liveProgressView setNeedsUpdateConstraints];
    [self.currentProgressView setNeedsUpdateConstraints];
}

- (void)displayWithProgram:(Program*)program onView:(UIView *)view aboveSiblingView:(UIView *)anchorView {
    
    [self setupProgressBarsWithProgram:program];
    if ( self.liveBarLine || self.currentBarLine ) {
        return;
    }
    
    self.view.clipsToBounds = YES;
    
    self.view.backgroundColor = [UIColor clearColor];
    //self.view.backgroundColor = [UIColor redColor];

    CGFloat width = self.view.frame.size.width;
    
    self.barWidth = width;
    self.liveBarLine = [CAShapeLayer layer];
    self.currentBarLine = [CAShapeLayer layer];
    
    CGMutablePathRef liveLinePath = CGPathCreateMutable();
    
    CGPoint pts[2];
    pts[0] = CGPointMake(0.0, 0.0);
    pts[1] = CGPointMake(width, 0.0);
    CGPathAddLines(liveLinePath, nil, pts, 2);
    
    CGMutablePathRef currentLinePath = CGPathCreateMutable();
    self.liveBarLine.path = liveLinePath;
    self.liveBarLine.strokeColor = self.liveTintColor.CGColor;
    self.liveBarLine.strokeStart = 0.0;
    self.liveBarLine.strokeEnd = 0.0;
    self.liveBarLine.opacity = 1.0;
    self.liveBarLine.fillColor = self.liveTintColor.CGColor;
    self.liveBarLine.lineWidth = 6.0;
    
    CGPoint lPts[2];
    lPts[0] = CGPointMake(0.0, 0.0);
    lPts[1] = CGPointMake(width, 0.0);
    CGPathAddLines(currentLinePath, nil, lPts, 2);
    
    self.currentBarLine.path = currentLinePath;
    self.currentBarLine.strokeColor = self.currentTintColor.CGColor;
    self.currentBarLine.strokeStart = 0.0;
    self.currentBarLine.strokeEnd = 0.0;
    self.currentBarLine.opacity = 1.0;
    self.currentBarLine.fillColor = self.currentTintColor.CGColor;
    self.currentBarLine.lineWidth = 6.0;
    
    [self.liveProgressView.layer addSublayer:self.liveBarLine];
    [self.currentProgressView.layer addSublayer:self.currentBarLine];
    
    [self.liveProgressView layoutIfNeeded];
    [self.currentProgressView layoutIfNeeded];
    
    //self.currentProgressView.backgroundColor = [UIColor greenColor];
    //self.liveProgressView.backgroundColor = [UIColor blueColor];
    
    [self.view layoutIfNeeded];
    
}

- (void)setupProgressBarsWithProgram:(Program *)program {
    
    self.currentProgram = program;
    self.liveTintColor = [[UIColor virtualWhiteColor] translucify:0.33];
    self.liveProgressView.backgroundColor = [UIColor clearColor];
    self.currentTintColor = [UIColor kpccOrangeColor];
    self.currentProgressView.backgroundColor = [UIColor clearColor];
    self.lastLiveValue = 0.0;
    self.lastCurrentValue = 0.0;
    self.liveProgressView.clipsToBounds = YES;
    self.currentProgressView.clipsToBounds = YES;
    self.currentProgressView.alpha = 0.0;
    self.liveProgressView.alpha = 0.0;
    self.uiHidden = YES;
    self.view.alpha = 0.0;
    
}

- (void)hide {
    if ( self.uiHidden ) return;
    
    [UIView animateWithDuration:0.25 animations:^{
        [self.view setAlpha:0.0];
    } completion:^(BOOL finished) {
        self.uiHidden = YES;
    }];
}

- (void)show {
    
    if ( !self.uiHidden ) return;
    if ( [[AudioManager shared] status] == StreamStatusStopped ) return;
    if ( [[AudioManager shared] currentAudioMode] == AudioModeOnDemand ) return;
    
    [UIView animateWithDuration:0.25 animations:^{
        [self.view setAlpha:1.0];
    } completion:^(BOOL finished) {
        self.uiHidden = NO;
        [UIView animateWithDuration:0.5 animations:^{
            self.liveProgressView.alpha = 1.0;
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:0.5 animations:^{
                self.currentProgressView.alpha = 1.0;
            } completion:^(BOOL finished) {
                
            }];
        }];
    }];


}

- (void)rewind {

    @synchronized(self) {
        self.shuttling = YES;
    }
    
    
#ifdef DONT_USE_LATENCY_CORRECTION
    CGFloat vBeginning = 0.1;
#else
    CGFloat vBeginning = 0.0;
#endif
    
    NSLog(@"currentBarLine strokeEnd : %1.2f",self.currentBarLine.strokeEnd);
    
    [CATransaction begin]; {
        [CATransaction setCompletionBlock:^{
            self.lastCurrentValue = vBeginning;
            self.shuttling = NO;
            self.currentBarLine.strokeEnd = vBeginning;
        }];
        
        CABasicAnimation *currentAnim = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
        [currentAnim setToValue:[NSNumber numberWithFloat:vBeginning]];
        [currentAnim setDuration:4];
        [currentAnim setRemovedOnCompletion:NO];
        [currentAnim setFillMode:kCAFillModeForwards];
        [self.currentBarLine addAnimation:currentAnim forKey:@"decrementCurrent"];
    }
    [CATransaction commit];
}

- (void)forward {

    @synchronized(self) {
        self.shuttling = YES;
    }
    
    Program *program = [[SessionManager shared] currentProgram];
    
    NSTimeInterval beginning = [program.soft_starts_at timeIntervalSince1970];
    NSTimeInterval end = [program.ends_at timeIntervalSince1970];
    NSTimeInterval duration = ( end - beginning );
    NSTimeInterval live = [[AudioManager shared].maxSeekableDate timeIntervalSince1970];
    
    CGFloat vBeginning = (live - beginning)/duration;
    
    NSLog(@"currentBarLine strokeEnd : %1.2f",self.currentBarLine.strokeEnd);
    
    [CATransaction begin]; {
        [CATransaction setCompletionBlock:^{
            self.lastCurrentValue = vBeginning;
            self.shuttling = NO;
            self.currentBarLine.strokeEnd = vBeginning;
            [self.currentBarLine removeAllAnimations];
        }];
        CABasicAnimation *currentAnim = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
        [currentAnim setToValue:[NSNumber numberWithFloat:vBeginning]];
        [currentAnim setDuration:2];
        [currentAnim setRemovedOnCompletion:NO];
        [currentAnim setFillMode:kCAFillModeForwards];
        [self.currentBarLine addAnimation:currentAnim forKey:@"forwardCurrent"];
    }
    [CATransaction commit];
}


- (void)tick {
    

    if ( self.shuttling ) return;
    
    Program *program = [[SessionManager shared] currentProgram];
    
    NSDate *currentDate = [AudioManager shared].audioPlayer.currentItem.currentDate;
    if ( !currentDate ) {
        if ( [[AudioManager shared] relativeFauxDate] ) {
            currentDate = [[AudioManager shared] relativeFauxDate];
        }
    }
    NSTimeInterval beginning = [program.soft_starts_at timeIntervalSince1970];
    if ( [[AudioManager shared] currentAudioMode] == AudioModeOnboarding ) {
        NSDate *fauxDate = [[AudioManager shared] relativeFauxDate];
        beginning = [fauxDate timeIntervalSince1970];
    }
    NSTimeInterval end = [program.ends_at timeIntervalSince1970];
    NSTimeInterval duration = ( end - beginning );
    
    NSTimeInterval live = [[AudioManager shared].maxSeekableDate timeIntervalSince1970];
    if ( [[AudioManager shared] currentAudioMode] == AudioModeOnboarding ) {
        live = [[NSDate date] timeIntervalSince1970];
    }
    NSTimeInterval current = [currentDate timeIntervalSince1970];
    if ( [[AudioManager shared] currentAudioMode] == AudioModeOnboarding ) {
        current = live;
    }
    NSTimeInterval liveDiff = ( live - beginning );
    NSTimeInterval currentDiff = ( current - beginning );
    

    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        [CATransaction begin]; {
            [CATransaction setCompletionBlock:^{
                self.currentBarLine.strokeEnd = currentDiff / duration;
                self.liveBarLine.strokeEnd = liveDiff / duration;
                [self.liveBarLine removeAllAnimations];
                [self.currentBarLine removeAllAnimations];
                self.lastCurrentValue = currentDiff / duration;
                self.lastLiveValue = liveDiff / duration;
            }];
            
            CABasicAnimation *liveAnim = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
            [liveAnim setFromValue:[NSNumber numberWithFloat:self.lastLiveValue]];
            [liveAnim setToValue:@(fminf(liveDiff/duration,0.98f))];
            [liveAnim setDuration:0.95];
            [liveAnim setRemovedOnCompletion:NO];
            [liveAnim setFillMode:kCAFillModeForwards];

            [self.liveBarLine addAnimation:liveAnim forKey:[NSString stringWithFormat:@"incrementLive"]];
            
            CABasicAnimation *currentAnim = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
            [currentAnim setFromValue:[NSNumber numberWithFloat:self.lastCurrentValue]];
            [currentAnim setToValue:@(fminf(currentDiff/duration,0.98f))];
            [currentAnim setDuration:0.95];
            [currentAnim setRemovedOnCompletion:NO];
            [currentAnim setFillMode:kCAFillModeForwards];
   
            [self.currentBarLine addAnimation:currentAnim forKey:[NSString stringWithFormat:@"incrementCurrent"]];
            
        }
        [CATransaction commit];

        
    });

    
}

- (void)finishReveal {
    
    [CATransaction begin]; {
        [CATransaction setCompletionBlock:^{
            [self.currentBarLine removeAllAnimations];
            [self.liveBarLine removeAllAnimations];
            self.firstTickFinished = YES;
        }];
        
        CABasicAnimation *currentAnimO = [CABasicAnimation animationWithKeyPath:@"opacity"];
        [currentAnimO setToValue:@(1.0)];
        [currentAnimO setDuration:5];
        [currentAnimO setRemovedOnCompletion:NO];
        [currentAnimO setFillMode:kCAFillModeForwards];
        [currentAnimO setCumulative:YES];
        [self.currentBarLine addAnimation:currentAnimO forKey:@"fadeInCurrent"];
        
        CABasicAnimation *liveAnimO = [CABasicAnimation animationWithKeyPath:@"opacity"];
        [liveAnimO setToValue:@(1.0)];
        [liveAnimO setDuration:5];
        [liveAnimO setRemovedOnCompletion:NO];
        [liveAnimO setFillMode:kCAFillModeForwards];
        [liveAnimO setCumulative:YES];
        [self.liveBarLine addAnimation:liveAnimO forKey:@"fadeInLive"];
    }
    [CATransaction commit];
    
}

@end
