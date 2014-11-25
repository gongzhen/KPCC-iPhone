//
//  SCPRTriangleView.m
//  KPCC
//
//  Created by Ben Hochberg on 11/24/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "SCPRTriangleView.h"

@implementation SCPRTriangleView


// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
    
    NSLog(@"My frame : %1.1f x, %1.1f y",self.frame.origin.x,self.frame.origin.y);
    self.backgroundColor = [UIColor clearColor];
    
    CGContextRef cx = UIGraphicsGetCurrentContext();

    CGPoint p[3];
    p[0] = CGPointMake(0.0, rect.size.height);
    p[1] = CGPointMake(rect.size.width / 2.0, 0.0);
    p[2] = CGPointMake(rect.size.width, rect.size.height);
    
    CGContextAddLines(cx, p, 3);
    
    CGContextSetFillColor(cx, CGColorGetComponents(self.shadeColor.CGColor));
    
    CGContextClosePath(cx);
    CGContextFillPath(cx);
    CGContextStrokePath(cx);
    
}


@end
