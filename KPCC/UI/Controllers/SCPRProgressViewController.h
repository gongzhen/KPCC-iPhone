//
//  SCPRProgressViewController.h
//  KPCC
//
//  Created by Ben Hochberg on 11/6/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Program.h"
#import "KPCC-Swift.h"

static NSInteger kThrottlingValue = 5;

@interface SCPRProgressViewController : UIViewController

+ (SCPRProgressViewController*)o;
- (void)displayWithProgram:(ScheduleOccurrence*)program onView:(UIView*)viewController aboveSiblingView:(UIView*)anchorView;
- (void)tick;
- (void)update;
- (void)hide;
- (void)show;
- (void)show:(BOOL)force;

- (void)rewind;
- (void)forward;
- (void)reset;

- (void)setupProgressBarsWithProgram:(ScheduleOccurrence*)program;

@property BOOL quitBit;
@property (nonatomic,strong) IBOutlet UIView *currentProgressView;
@property (nonatomic,strong) IBOutlet UIView *liveProgressView;
@property (nonatomic, strong) UIColor *liveTintColor;
@property (nonatomic, strong) UIColor *currentTintColor;
@property (nonatomic, weak) ScheduleOccurrence *currentProgram;
@property (nonatomic,strong) NSOperationQueue *rewindQueue;

@property (nonatomic,strong) CAShapeLayer *liveBarLine;
@property (nonatomic,strong) CAShapeLayer *currentBarLine;

@property CGFloat barWidth;
@property CGFloat lastLiveValue;
@property CGFloat lastCurrentValue;

@property NSInteger throttle;

@property BOOL shuttling;
@property BOOL expanded;
@property BOOL firstTickFinished;
@property BOOL uiHidden;
@property BOOL freezeBit;
@property NSInteger counter;

@end
