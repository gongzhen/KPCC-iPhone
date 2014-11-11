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

+ (void)finishReveal;

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

+ (void)displayWithProgram:(Program*)program onView:(UIViewController *)viewController aboveSiblingView:(UIView *)anchorView {
    
    SCPRProgressViewController *pv = [SCPRProgressViewController o];
    pv.view.frame = pv.view.frame;
    if ( [pv.view superview] )
        [pv.view removeFromSuperview];
    
    
    
    [pv setupProgressBarsWithProgram:program];

    pv.view.clipsToBounds = YES;
    
    CGFloat width = viewController.view.frame.size.width;
    pv.view.frame = CGRectMake(0.0,anchorView.frame.origin.y,
                               width,
                               6.0);
    pv.view.backgroundColor = [UIColor clearColor];
    [viewController.view insertSubview:pv.view belowSubview:anchorView];

    
    pv.barWidth = width;
    pv.liveBarLine = [CAShapeLayer layer];
    pv.currentBarLine = [CAShapeLayer layer];
    
    CGMutablePathRef liveLinePath = CGPathCreateMutable();
    
    CGPoint pts[2];
    pts[0] = CGPointMake(0.0, 0.0);
    pts[1] = CGPointMake(width, 0.0);
    CGPathAddLines(liveLinePath, nil, pts, 2);
    
    CGMutablePathRef currentLinePath = CGPathCreateMutable();
    pv.liveBarLine.path = liveLinePath;
    pv.liveBarLine.strokeColor = pv.liveTintColor.CGColor;
    pv.liveBarLine.strokeStart = 0.0;
    pv.liveBarLine.strokeEnd = 0.0;
    pv.liveBarLine.opacity = 1.0;
    pv.liveBarLine.fillColor = pv.liveTintColor.CGColor;
    pv.liveBarLine.lineWidth = 6.0;
    
    CGPoint lPts[2];
    lPts[0] = CGPointMake(0.0, 0.0);
    lPts[1] = CGPointMake(width, 0.0);
    CGPathAddLines(currentLinePath, nil, lPts, 2);
    
    pv.currentBarLine.path = currentLinePath;
    pv.currentBarLine.strokeColor = pv.currentTintColor.CGColor;
    pv.currentBarLine.strokeStart = 0.0;
    pv.currentBarLine.strokeEnd = 0.0;
    pv.currentBarLine.opacity = 1.0;
    pv.currentBarLine.fillColor = pv.currentTintColor.CGColor;
    pv.currentBarLine.lineWidth = 6.0;
    
    [pv.liveProgressView.layer addSublayer:pv.liveBarLine];
    [pv.currentProgressView.layer addSublayer:pv.currentBarLine];
    
    [pv.liveProgressView layoutIfNeeded];
    [pv.currentProgressView layoutIfNeeded];
    
    [pv.view layoutIfNeeded];
    
}

- (void)setupProgressBarsWithProgram:(Program *)program {
    
    self.currentProgram = program;
    self.liveTintColor = [[UIColor virtualWhiteColor] translucify:0.6];
    self.liveProgressView.backgroundColor = [[UIColor virtualWhiteColor] translucify:0.125];
    self.currentTintColor = [UIColor kpccOrangeColor];
    self.currentProgressView.backgroundColor = [[UIColor virtualWhiteColor] translucify:0.125];
    self.lastLiveValue = 0.0;
    self.lastCurrentValue = 0.0;
    self.liveProgressView.clipsToBounds = YES;
    self.currentProgressView.clipsToBounds = YES;
    self.view.alpha = 0.0;
    
}

+ (void)hide {
   SCPRProgressViewController *pv = [SCPRProgressViewController o];
    [UIView animateWithDuration:0.25 animations:^{
        [pv.view setAlpha:0.0];
    } completion:^(BOOL finished) {
        pv.uiHidden = YES;
    }];
}

+ (void)show {
    SCPRProgressViewController *pv = [SCPRProgressViewController o];
    
    [UIView animateWithDuration:0.25 animations:^{
        [pv.view setAlpha:1.0];
    } completion:^(BOOL finished) {
        pv.uiHidden = NO;
    }];


}

+ (void)rewind {
    SCPRProgressViewController *pv = [SCPRProgressViewController o];
    @synchronized(self) {
        pv.shuttling = YES;
    }
    
    Program *program = [[SessionManager shared] currentProgram];
    
    NSTimeInterval beginning = [program.starts_at timeIntervalSince1970];
    NSTimeInterval end = [program.ends_at timeIntervalSince1970];
    NSTimeInterval duration = ( end - beginning );
    
#ifdef DONT_USE_LATENCY_CORRECTION
    CGFloat vBeginning = 0.0;
#else
    CGFloat vBeginning = 60*6/duration;
#endif
    
    NSLog(@"currentBarLine strokeEnd : %1.2f",pv.currentBarLine.strokeEnd);
    
    [CATransaction begin]; {
        [CATransaction setCompletionBlock:^{
            pv.lastCurrentValue = vBeginning;
            pv.shuttling = NO;
            pv.currentBarLine.strokeEnd = vBeginning;
            [pv.currentBarLine removeAllAnimations];
        }];
        
        CABasicAnimation *currentAnim = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
        [currentAnim setToValue:[NSNumber numberWithFloat:vBeginning]];
        [currentAnim setDuration:4];
        [currentAnim setRemovedOnCompletion:NO];
        [currentAnim setFillMode:kCAFillModeForwards];
        [pv.currentBarLine addAnimation:currentAnim forKey:@"decrementCurrent"];
    }
    [CATransaction commit];
}

+ (void)forward {
    SCPRProgressViewController *pv = [SCPRProgressViewController o];
    @synchronized(self) {
        pv.shuttling = YES;
    }
    
    Program *program = [[SessionManager shared] currentProgram];
    
    NSTimeInterval beginning = [program.starts_at timeIntervalSince1970];
    NSTimeInterval end = [program.ends_at timeIntervalSince1970];
    NSTimeInterval duration = ( end - beginning );
    NSTimeInterval live = [[AudioManager shared].maxSeekableDate timeIntervalSince1970];
    
    CGFloat vBeginning = (live - beginning)/duration;
    
    NSLog(@"currentBarLine strokeEnd : %1.2f",pv.currentBarLine.strokeEnd);
    
    [CATransaction begin]; {
        [CATransaction setCompletionBlock:^{
            pv.lastCurrentValue = 0.0;
            pv.shuttling = NO;
            pv.currentBarLine.strokeEnd = vBeginning;
            [pv.currentBarLine removeAllAnimations];
        }];
        CABasicAnimation *currentAnim = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
        [currentAnim setToValue:[NSNumber numberWithFloat:vBeginning]];
        [currentAnim setDuration:2];
        [currentAnim setRemovedOnCompletion:NO];
        [currentAnim setFillMode:kCAFillModeForwards];
        [pv.currentBarLine addAnimation:currentAnim forKey:@"forwardCurrent"];
    }
    [CATransaction commit];
}


+ (void)tick {
    
    SCPRProgressViewController *pv = [SCPRProgressViewController o];

    if ( pv.uiHidden ) return;
    if ( pv.shuttling ) return;
    
    Program *program = [[SessionManager shared] currentProgram];
    
    NSDate *currentDate = [AudioManager shared].audioPlayer.currentItem.currentDate;
    NSTimeInterval beginning = [program.starts_at timeIntervalSince1970];
    NSTimeInterval end = [program.ends_at timeIntervalSince1970];
    NSTimeInterval duration = ( end - beginning );
    
    NSTimeInterval live = [[AudioManager shared].maxSeekableDate timeIntervalSince1970];
    NSTimeInterval current = [currentDate timeIntervalSince1970];
    
    NSTimeInterval liveDiff = ( live - beginning );
    NSTimeInterval currentDiff = ( current - beginning );
    
    pv.lastCurrentValue = currentDiff / duration;
    pv.lastLiveValue = liveDiff / duration;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        [CATransaction begin]; {
            [CATransaction setCompletionBlock:^{
                pv.liveBarLine.strokeEnd = liveDiff/duration;
                pv.currentBarLine.strokeEnd = currentDiff/duration;
                [pv.currentBarLine removeAllAnimations];
                [pv.liveBarLine removeAllAnimations];
            }];
            
            CABasicAnimation *liveAnim = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
            [liveAnim setFromValue:[NSNumber numberWithFloat:pv.lastLiveValue]];
            [liveAnim setToValue:[NSNumber numberWithFloat:liveDiff/duration]];
            [liveAnim setDuration:0.1];
            [liveAnim setRemovedOnCompletion:YES];
            [liveAnim setFillMode:kCAFillModeForwards];
            [liveAnim setCumulative:YES];
            [pv.liveBarLine addAnimation:liveAnim forKey:[NSString stringWithFormat:@"incrementLive%1.1f",liveDiff]];
            
            CABasicAnimation *currentAnim = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
            [currentAnim setFromValue:[NSNumber numberWithFloat:pv.lastCurrentValue]];
            [currentAnim setToValue:[NSNumber numberWithFloat:currentDiff/duration]];
            [currentAnim setDuration:0.1];
            [currentAnim setRemovedOnCompletion:YES];
            [currentAnim setFillMode:kCAFillModeForwards];
            [currentAnim setCumulative:YES];
            [pv.currentBarLine addAnimation:currentAnim forKey:[NSString stringWithFormat:@"incrementCurrent%1.1f",currentDiff]];
            
        }
        [CATransaction commit];

        
    });

    
}

+ (void)finishReveal {
    SCPRProgressViewController *pv = [SCPRProgressViewController o];
    
    [CATransaction begin]; {
        [CATransaction setCompletionBlock:^{
            [pv.currentBarLine removeAllAnimations];
            [pv.liveBarLine removeAllAnimations];
            pv.firstTickFinished = YES;
        }];
        
        CABasicAnimation *currentAnimO = [CABasicAnimation animationWithKeyPath:@"opacity"];
        [currentAnimO setToValue:@(1.0)];
        [currentAnimO setDuration:5];
        [currentAnimO setRemovedOnCompletion:NO];
        [currentAnimO setFillMode:kCAFillModeForwards];
        [currentAnimO setCumulative:YES];
        [pv.currentBarLine addAnimation:currentAnimO forKey:@"fadeInCurrent"];
        
        CABasicAnimation *liveAnimO = [CABasicAnimation animationWithKeyPath:@"opacity"];
        [liveAnimO setToValue:@(1.0)];
        [liveAnimO setDuration:5];
        [liveAnimO setRemovedOnCompletion:NO];
        [liveAnimO setFillMode:kCAFillModeForwards];
        [liveAnimO setCumulative:YES];
        [pv.liveBarLine addAnimation:liveAnimO forKey:@"fadeInLive"];
    }
    [CATransaction commit];
    
}

@end
