//
//  SCPRProgressViewController.h
//  KPCC
//
//  Created by Ben Hochberg on 11/6/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Program.h"

@interface SCPRProgressViewController : UIViewController

+ (SCPRProgressViewController*)o;
- (void)displayWithProgram:(Program*)program onView:(UIView*)viewController aboveSiblingView:(UIView*)anchorView;
- (void)tick;
- (void)hide;
- (void)show;
- (void)rewind;
- (void)forward;
- (void)reset;

- (void)setupProgressBarsWithProgram:(Program*)program;

@property BOOL quitBit;
@property (nonatomic,strong) IBOutlet UIView *currentProgressView;
@property (nonatomic,strong) IBOutlet UIView *liveProgressView;
@property (nonatomic, strong) UIColor *liveTintColor;
@property (nonatomic, strong) UIColor *currentTintColor;
@property (nonatomic, weak) Program *currentProgram;
@property (nonatomic,strong) NSOperationQueue *rewindQueue;

@property (nonatomic,strong) CAShapeLayer *liveBarLine;
@property (nonatomic,strong) CAShapeLayer *currentBarLine;

@property CGFloat barWidth;
@property CGFloat lastLiveValue;
@property CGFloat lastCurrentValue;

@property BOOL shuttling;
@property BOOL expanded;
@property BOOL firstTickFinished;
@property BOOL uiHidden;
@property BOOL freezeBit;
@property BOOL mutex;
@property NSInteger counter;

@end
