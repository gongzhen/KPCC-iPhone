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
    POPSpringAnimation *scaleAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerScaleXY];
    scaleAnimation.fromValue  = [NSValue valueWithCGSize:CGSizeMake(1.0f, 1.0f)];
    scaleAnimation.toValue  = [NSValue valueWithCGSize:CGSizeMake(0.8f, 0.8f)];
    scaleAnimation.springBounciness = 2.0f;
    scaleAnimation.springSpeed = 1.0f;
    [scaleAnimation setCompletionBlock:^(POPAnimation *p, BOOL c) {
        self.small = YES;
    }];
    [self.layer pop_addAnimation:scaleAnimation forKey:@"squeeze"];
}

- (void)expand {
    //if ( !self.small ) {
        POPSpringAnimation *scaleAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerScaleXY];
        scaleAnimation.fromValue  = [NSValue valueWithCGSize:CGSizeMake(.8f, .8f)];
        scaleAnimation.toValue  = [NSValue valueWithCGSize:CGSizeMake(1.0f, 1.0f)];
        scaleAnimation.springBounciness = 2.0f;
        scaleAnimation.springSpeed = 1.0f;
        [scaleAnimation setCompletionBlock:^(POPAnimation *p, BOOL c) {
            self.small = NO;
            [self.target performSelector:self.postPushMethod withObject:nil afterDelay:0];
        }];
        [self.layer pop_addAnimation:scaleAnimation forKey:@"expand"];
    //}
}

@end
