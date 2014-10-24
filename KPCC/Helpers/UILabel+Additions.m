//
//  UILabel+Additions.m
//  KPCC
//
//  Created by Ben Hochberg on 10/22/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "UILabel+Additions.h"
#import "DesignManager.h"

@implementation UILabel (Additions)

- (void)fadeText:(NSString *)text {
    [self stopPulsating];
    [self fadeText:text
          duration:0.5f];
}

- (void)fadeText:(NSString *)text duration:(CGFloat)duration {
    self.text = text;
    CATransition *transition = [CATransition animation];
    transition.duration = duration;
    transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    transition.type = kCATransitionFade;
    
    [self.layer addAnimation:transition
                      forKey:nil];
}

- (void)pulsate:(NSString*)text color:(UIColor *)color {
    
    UIColor *original = self.textColor;
    [CATransaction begin]; {
        [CATransaction setCompletionBlock:^{
            [CATransaction begin]; {
                [CATransaction setCompletionBlock:^{
                    self.textColor = original;
                }];
                UIColor *pulseTo = color;
                if ( !color ) {
                    
                    pulseTo = [[DesignManager shared] intensifyColor:original];
                    
                }
                
                self.textColor = pulseTo;
                CATransition *pulse = [CATransition animation];
                pulse.duration = 0.66f;
                pulse.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
                pulse.autoreverses = YES;
                pulse.type = kCATransitionFade;
                pulse.repeatCount = HUGE_VALF;
                pulse.removedOnCompletion = YES;
                [self.layer addAnimation:pulse
                                  forKey:nil];
            }
            [CATransaction commit];

        }];
        
        self.text = text;
        CATransition *transition = [CATransition animation];
        transition.duration = 0.33f;
        transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
        transition.type = kCATransitionFade;
        
        [self.layer addAnimation:transition
                          forKey:nil];
    }
    [CATransaction commit];
}

- (void)stopPulsating {
    [self.layer removeAllAnimations];
}

@end
