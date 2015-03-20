//
//  SCPRScrubberViewController.h
//  KPCC
//
//  Created by Ben Hochberg on 2/9/15.
//  Copyright (c) 2015 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SCPRTouchableScrubberView.h"

@import AVFoundation;

@protocol Scrubbable <NSObject>

- (void)actionOfInterestWithPercentage:(CGFloat)percent;
- (void)actionOfInterestAfterScrub:(CGFloat)finalValue;
- (UILabel*)scrubbingIndicatorLabel;
- (SCPRTouchableScrubberView*)scrubbableView;

@end

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
@property (nonatomic,strong) SCPRTouchableScrubberView *viewAsTouchableScrubberView;
@property (nonatomic,weak) id<Scrubbable> scrubbingDelegate;

@property (nonatomic, strong) UIView *cloak;
@property BOOL expanded;
@property BOOL panning;
@property BOOL restoreFromSeekGate;
@property CGPoint firstTouch;
@property NSTimer *trulyFinishedTimer;


- (void)setupWithDelegate:(id<Scrubbable>)delegate;

- (void)unmask;
- (void)applyMask;

- (void)tick:(CGFloat)amount;
- (void)expand;

- (void)userTouched:(NSSet*)touches event:(UIEvent*)event;
- (void)userPanned:(NSSet*)touches event:(UIEvent*)event;
- (void)userLifted:(NSSet*)touches event:(UIEvent*)event;
- (void)trackForPoint:(CGPoint)touchPoint;



@end
