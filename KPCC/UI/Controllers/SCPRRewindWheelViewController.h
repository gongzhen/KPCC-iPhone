//
//  SCPRRewindWheelViewController.h
//  Experiments
//
//  Created by Ben Hochberg on 10/17/14.
//  Copyright (c) 2014 Ben Hochberg. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SCPRRewindWheelViewController : UIViewController

@property (nonatomic,strong) UIColor *strokeColor;
@property (nonatomic,strong) CAShapeLayer *circleLayer;
@property (nonatomic,strong) CAShapeLayer *antiCircleLayer;
@property (nonatomic,strong) CAShapeLayer *palimpsestLayer;
@property (nonatomic,strong) UIBezierPath *circlePath;
@property (nonatomic) double progress;
@property (nonatomic) CGFloat strokeWidth;
@property (atomic) BOOL completionBit;
@property BOOL pingpong;

- (void)setupWithColor:(UIColor*)color andStrokeWidth:(CGFloat)strokeWidth;
- (void)animateWithSpeed:(CGFloat)duration tension:(CGFloat)tension completion:(void (^)(void))completion;
- (void)completeWithCallback:(void (^)(void))completion;


- (CAShapeLayer*)generateCircleLayer;

@end
