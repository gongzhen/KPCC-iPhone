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
    CGFloat max = 0.0f;
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

+ (UIColor*)angryCloudColor {
    return [UIColor colorWithRed:186.0/255.0
                           green:186.0/255.0
                            blue:186.0/255.0
                           alpha:1.0];
}

+ (UIColor*)paleHorseColor {
    return [UIColor colorWithRed:248.0/255.0
                           green:248.0/255.0
                            blue:248.0/255.0
                           alpha:1.0];
}

+ (UIColor*)kpccSlateColor {
    return [UIColor colorWithRed:108.0/255.0
                           green:117.0/255.0
                            blue:121.0/255.0
                           alpha:1.0];
}

+ (UIColor*)kpccAsphaltColor {
    return [UIColor colorWithRed:34.0/255.0
                           green:38.0/255.0
                            blue:40.0/255.0
                           alpha:1.0];
}

+ (UIColor*)kpccSubtleGrayColor {
    return [UIColor colorWithRed:151.0/255.0
                           green:151.0/255.0
                            blue:151.0/255.0
                           alpha:1.0];
}

+ (UIColor*)kpccSoftOrangeColor {
    return [UIColor colorWithHex:0xF87E21];
}

+ (UIColor*)kpccOrangeColor {
    return [UIColor colorWithHex:0xFF8C26];
}

+ (UIColor*)kpccPeriwinkleColor {
    return [UIColor colorWithHex:0x32ACD5];
}

+ (UIColor*)kpccBalloonBlueColor {
    return [UIColor colorWithHex:0x33AAD5];
}

+ (UIColor*)number2pencilColor {
    return [UIColor colorWithHex:0x6C7579];
}

+ (UIColor*)kpccDividerGrayColor {
    return [UIColor colorWithHex:0xE3E3E3];
}

@end
