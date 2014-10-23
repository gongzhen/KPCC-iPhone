//
//  UILabel+Additions.h
//  KPCC
//
//  Created by Ben Hochberg on 10/22/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UILabel (Additions)

- (void)fadeText:(NSString*)text;
- (void)fadeText:(NSString *)text duration:(CGFloat)duration;

@end
