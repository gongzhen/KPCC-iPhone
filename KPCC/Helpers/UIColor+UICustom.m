//
//  UIColor+UICustom.m
//
//  Created by Ben Hochberg on 7/25/14.
//

#import "UIColor+UICustom.h"

@implementation UIColor (UICustom)


- (UIColor*)translucify:(CGFloat)alpha {
   CGFloat *colorValues = (CGFloat*) CGColorGetComponents(self.CGColor);
    return [UIColor colorWithRed:colorValues[0]
                           green:colorValues[1]
                            blue:colorValues[2]
                           alpha:alpha];
}

- (UIColor*)intensify {
    const CGFloat *cdata = CGColorGetComponents(self.CGColor);
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
    
    CGFloat *newValues = (CGFloat*)malloc(3*sizeof(CGFloat));
    for ( unsigned i = 0; i < 3; i++ ) {
        if ( i == index ) {
            newValues[i] = brighterValue;
            continue;
        }
        newValues[i] = cdata[i]*0.65;
    }
    
    UIColor *moreIntense = [UIColor colorWithRed:newValues[0]
                                           green:newValues[1]
                                            blue:newValues[2]
                                           alpha:1.0];
    free(newValues);
    return moreIntense;
}

+ (UIColor *)colorWithHex:(UInt32)hex {
    return [UIColor colorWithRed:((CGFloat)((hex & 0xFF0000) >> 16))/255.0f green:((CGFloat)((hex & 0xFF00) >> 8))/255.0f blue:((CGFloat)(hex & 0xFF))/255.0f alpha:1.0f];
}

#pragma mark - Hard colors
+ (UIColor*)virtualBlackColor {
    return [UIColor colorWithRed:1.0/255.0
                           green:1.0/255.0
                            blue:1.0/255.0
                           alpha:1.0];
}

+ (UIColor*)virtualWhiteColor {
    return [UIColor colorWithRed:254.0/255.0
                           green:254.0/255.0
                            blue:254.0/255.0
                           alpha:1.0];
}

+ (UIColor*)cloudColor {
    return [UIColor colorWithRed:204.0/255.0
                           green:204.0/255.0
                            blue:204.0/255.0
                           alpha:1.0];
}

+ (UIColor*)kpccOrangeColor {
    return [UIColor colorWithHex:0xFF8C26];
}



@end