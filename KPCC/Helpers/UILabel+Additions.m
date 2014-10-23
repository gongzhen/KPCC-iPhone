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


@end
