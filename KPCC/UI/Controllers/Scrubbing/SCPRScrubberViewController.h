//
//  SCPRScrubberViewController.h
//  KPCC
//
//  Created by Ben Hochberg on 2/9/15.
//  Copyright (c) 2015 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>

@import AVFoundation;

@interface SCPRScrubberViewController : UIViewController

@property (nonatomic, strong) IBOutlet UILabel *scrubberTimeLabel;
@property (nonatomic, strong) IBOutlet UIView *scrubbingContainerView;
@property (nonatomic, strong)  UIView *currentProgressView;
@property (nonatomic, strong)  UIView *liveProgressView;
@property (nonatomic, strong) UIColor *liveTintColor;
@property (nonatomic, strong) UIColor *currentTintColor;
@property (nonatomic,strong) CAShapeLayer *liveBarLine;
@property (nonatomic,strong) CAShapeLayer *currentBarLine;
@property (nonatomic,strong) UIPanGestureRecognizer *scrubPanner;

@property (nonatomic, strong) UIView *cloak;
@property BOOL expanded;
@property BOOL panning;
@property CGPoint firstTouch;
@property NSTimer *trulyFinishedTimer;

- (void)setup;
- (void)unmask;
- (void)tick;
- (void)expand;
- (void)pointedSeek;

@end
