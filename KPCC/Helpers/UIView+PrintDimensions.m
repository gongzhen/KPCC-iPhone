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

@end
