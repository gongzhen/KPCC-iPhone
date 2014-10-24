//
//  UILabel+Additions.m
//  KPCC
//
//  Created by Ben Hochberg on 10/22/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "UILabel+Additions.h"

@implementation UILabel (Additions)

- (void)fadeText:(NSString *)text {
    [self stopPulsating];
    [self fadeText:text
          duration:0.33f];
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
                    const CGFloat *cdata = CGColorGetComponents(self.textColor.CGColor);
                    CGFloat max = 0.0;
                    NSInteger index = 0;
                    for ( unsigned i = 0; i < 3; i++ ) {
                        CGFloat val = cdata[i];
                        if ( val > max ) {
                            max = val;
                            index = i;
                        }
                    }
                    
                    CGFloat brighterValue = fminf(max + (max * 0.33),
                                                  1.0);
                    
                    CGFloat *newValues = (CGFloat*)malloc(4*sizeof(CGFloat));
                    for ( unsigned i = 0; i < 4; i++ ) {
                        if ( i == index ) {
                            newValues[i] = brighterValue;
                            continue;
                        }
                        
                        if ( i == 3 ) {
                            newValues[i] = 1.0;
                        }
                        
                        newValues[i] = cdata[i]*0.55;
                    }
                    
                    pulseTo = [UIColor colorWithRed:newValues[0]
                                              green:newValues[1]
                                               blue:newValues[2]
                                              alpha:1.0];
                    free(newValues);
                    
                }
                
                self.textColor = pulseTo;
                CATransition *pulse = [CATransition animation];
                pulse.duration = 0.33f;
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
