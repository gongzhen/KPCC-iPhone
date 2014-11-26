//
//  SCPRButton.h
//  KPCC
//
//  Created by Ben Hochberg on 11/25/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SCPRButton : UIButton

@property SEL postPushMethod;
@property (nonatomic, weak) id target;
@property BOOL small;

- (void)addTarget:(id)target action:(SEL)action forControlEvents:(UIControlEvents)controlEvents special:(BOOL)special;

@end
