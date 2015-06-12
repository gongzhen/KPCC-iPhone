//
//  SCPRTouchableScrubberView.m
//  KPCC
//
//  Created by Ben Hochberg on 2/11/15.
//  Copyright (c) 2015 SCPR. All rights reserved.
//

#import "SCPRTouchableScrubberView.h"
#import "SCPRScrubberViewController.h"
#import "UIColor+UICustom.h"

@implementation SCPRTouchableScrubberView


// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
    
#ifdef SHOW_ANGLE
    if ( ![(SCPRScrubberViewController*)self.parentScrubberController circular] ) return;
    
    UIView *v = [(SCPRScrubberViewController*)self.parentScrubberController radiusTerminusView];
    CGContextRef cx = UIGraphicsGetCurrentContext();
    CGContextMoveToPoint(cx, self.frame.size.width / 2.0f,
                         self.frame.size.height / 2.0f);
    CGContextAddLineToPoint(cx, v.center.x,
                            v.center.y);
    
    CGContextMoveToPoint(cx, self.frame.size.width / 2.0f,
                         self.frame.size.height / 2.0f);
    
    CGContextAddLineToPoint(cx, self.frame.size.width / 2.0f, 0.0f);
    
    CGContextSetStrokeColor(cx, CGColorGetComponents([UIColor virtualWhiteColor].CGColor));
    CGContextSetLineWidth(cx, 2.0f);
    CGContextStrokePath(cx);
#endif
    
}


- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [(SCPRScrubberViewController*)self.parentScrubberController userTouched:touches
                                                                      event:event];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    [(SCPRScrubberViewController*)self.parentScrubberController userPanned:touches
                                                                      event:event];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    [(SCPRScrubberViewController*)self.parentScrubberController userLifted:touches
                                                                     event:event];
}

@end
