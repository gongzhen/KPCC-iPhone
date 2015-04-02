//
//  SCPRButton.m
//  KPCC
//
//  Created by Ben Hochberg on 11/25/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "SCPRButton.h"
#import <POP/POP.h>
#import "UIColor+UICustom.h"

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
        
        self.transform = CGAffineTransformMakeScale(0.93f, 0.93f);
        
    } completion:^(BOOL finished) {
        
        
    }];
    
}

- (void)expand {

    POPSpringAnimation *scaleAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerScaleXY];
    scaleAnimation.toValue  = [NSValue valueWithCGSize:CGSizeMake(1.0f, 1.0f)];
    scaleAnimation.springBounciness = 2.0f;
    scaleAnimation.springSpeed = 1.0f;
    [scaleAnimation setCompletionBlock:^(POPAnimation *p, BOOL c) {
        
    }];
    [self.layer pop_addAnimation:scaleAnimation forKey:@"expand"];
    
    if ( !self.locked ) {
        self.locked = YES;
        [self.target performSelector:self.postPushMethod withObject:self afterDelay:0];
        self.lockTimer = [NSTimer scheduledTimerWithTimeInterval:0.25
                                                          target:self
                                                        selector:@selector(unlock)
                                                        userInfo:nil
                                                         repeats:NO];
    }
    
}

- (void)unlock {
    self.locked = NO;
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

- (void)setActive:(BOOL)active {
    _active = active;
    
    if ( active ) {
        [self setTitleColor:[UIColor whiteColor]
                   forState:UIControlStateNormal];
        [self setTitleColor:[UIColor whiteColor]
                   forState:UIControlStateHighlighted];
    } else {
        [self setTitleColor:[[UIColor virtualWhiteColor] translucify:0.46]
                   forState:UIControlStateNormal];
        [self setTitleColor:[[UIColor virtualWhiteColor] translucify:0.46]
                   forState:UIControlStateHighlighted];
    }
}

- (void)scprifyWithSize:(CGFloat)pointSize {
    [self scprGenericWithFont:@"FreightSansProLight-Regular"
                      andSize:pointSize];
}

- (void)scprBookifyWithSize:(CGFloat)pointSize {
    [self scprGenericWithFont:@"FreightSansProBook-Regular"
                      andSize:pointSize];
}

- (void)scprGenericWithFont:(NSString *)font andSize:(CGFloat)pointSize {
    self.titleLabel.font = [UIFont fontWithName:font size:pointSize];
    [self setTitleColor:[UIColor whiteColor]
               forState:UIControlStateNormal];
    [self setTitleColor:[UIColor grayColor]
               forState:UIControlStateHighlighted];
}

@end
