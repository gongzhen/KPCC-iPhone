//
//  UIColor+UICustom.h
//
//  Created by Ben Hochberg on 7/25/14.
//

#import <UIKit/UIKit.h>

@interface UIColor (UICustom)

- (UIColor*)translucify:(CGFloat)alpha;
+ (UIColor*)colorWithHex:(UInt32)hex;
+ (UIColor*)kpccOrangeColor;
+ (UIColor*)virtualBlackColor;
+ (UIColor*)cloudColor;
- (UIColor*)intensify;

@end
