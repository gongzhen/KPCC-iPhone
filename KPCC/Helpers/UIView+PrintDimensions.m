//
//  UIView+PrintHeight.m
//  KPCC
//
//  Created by Ben Hochberg on 12/16/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "UIView+PrintDimensions.h"

@implementation UIView (PrintDimensions)

- (void)printDimensions {
    [self printDimensionsWithIdentifier:@"GenericView"];
}

- (void)printDimensionsWithIdentifier:(NSString *)identifier {
    NSLog(@"%@ {%@} : oX: %1.1f, oY: %1.1f, W: %1.1f, H: %1.1f",identifier,[[self class] description],self.frame.origin.x,
          self.frame.origin.y,
          self.frame.size.width,
          self.frame.size.height);
}

- (void)cutAHole:(CGRect)holeDimensions {
    CGRect r = self.bounds;
    CGRect r2 = holeDimensions; // adjust this as desired!
    UIGraphicsBeginImageContextWithOptions(r.size, NO, 0);
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGContextAddRect(c, r2);
    CGContextAddRect(c, r);
    CGContextEOClip(c);
    CGContextSetFillColorWithColor(c, [UIColor blackColor].CGColor);
    CGContextFillRect(c, r);
    UIImage* maskim = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    CALayer* mask = [CALayer layer];
    mask.frame = r;
    mask.contents = (id)maskim.CGImage;
    self.layer.mask = mask;
}

- (void)fillHole {
    self.layer.mask = nil;
}

@end
