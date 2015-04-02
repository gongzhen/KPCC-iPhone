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
@property BOOL locked;
@property (nonatomic,strong) NSTimer *lockTimer;
@property (nonatomic) BOOL active;

- (void)addTarget:(id)target action:(SEL)action forControlEvents:(UIControlEvents)controlEvents special:(BOOL)special;
- (void)stretch;
- (void)scprifyWithSize:(CGFloat)pointSize;
- (void)scprBookifyWithSize:(CGFloat)pointSize;
- (void)scprGenericWithFont:(NSString*)font andSize:(CGFloat)pointSize;

@end
