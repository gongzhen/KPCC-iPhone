//
//  SCPRButton.m
//  KPCC
//
//  Created by Ben Hochberg on 11/25/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "SCPRButton.h"
#import <POP/POP.h>

@implementation SCPRButton

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

- (void)addTarget:(id)target action:(SEL)action forControlEvents:(UIControlEvents)controlEvents special:(BOOL)special {
    self.target = target;
    self.postPushMethod = action;
    [self addTarget:self
             action:@selector(squeeze) forControlEvents:UIControlEventTouchDown];
    [self addTarget:self
             action:@selector(expand) forControlEvents:UIControlEventTouchUpInside];
}

- (void)squeeze {
    
    [UIView animateWithDuration:0.11 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        
        self.transform = CGAffineTransformMakeScale(0.80f, 0.80f);
        
    } completion:^(BOOL finished) {
        
        
    }];
    
}

- (void)expand {

    POPSpringAnimation *scaleAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerScaleXY];
    scaleAnimation.toValue  = [NSValue valueWithCGSize:CGSizeMake(1.0f, 1.0f)];
    scaleAnimation.springBounciness = 2.0f;
    scaleAnimation.springSpeed = 1.0f;
    [scaleAnimation setCompletionBlock:^(POPAnimation *p, BOOL c) {
        self.small = NO;
    }];
    [self.layer pop_addAnimation:scaleAnimation forKey:@"expand"];
    [self.target performSelector:self.postPushMethod withObject:self afterDelay:0];
    
}

- (void)stretch {
    
    [UIView animateWithDuration:0.31 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        
        self.transform = CGAffineTransformMakeScale(1.2f, 1.2f);
        
    } completion:^(BOOL finished) {
        
        [UIView animateWithDuration:0.31 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            
            self.transform = CGAffineTransformMakeScale(1.0f, 1.0f);
            
        } completion:^(BOOL finished) {
            
            
        }];
    }];
}

@end
