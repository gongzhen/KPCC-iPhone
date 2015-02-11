//
//  SCPRTouchableScrubberView.m
//  KPCC
//
//  Created by Ben Hochberg on 2/11/15.
//  Copyright (c) 2015 SCPR. All rights reserved.
//

#import "SCPRTouchableScrubberView.h"
#import "SCPRScrubberViewController.h"

@implementation SCPRTouchableScrubberView

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

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
