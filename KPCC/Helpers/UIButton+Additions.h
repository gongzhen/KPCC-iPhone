//
//  UIButton+Additions.h
//  KPCC
//
//  Created by Ben Hochberg on 11/6/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIButton (Additions)

- (void)fadeImage:(UIImage*)image;
- (void)fadeImage:(UIImage *)image duration:(CGFloat)duration;

@end
