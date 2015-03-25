//
//  SCPRSleepViewController.h
//  KPCC
//
//  Created by Ben Hochberg on 3/20/15.
//  Copyright (c) 2015 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SCPRScrubberViewController.h"
#import "SCPRButton.h"

@interface SCPRSleepViewController : UIViewController<Scrubbable,UIAlertViewDelegate>

@property (nonatomic, strong) IBOutlet SCPRScrubberViewController *scrubber;
@property (nonatomic, strong) IBOutlet SCPRTouchableScrubberView *scrubbingTouchView;
@property (nonatomic, strong) IBOutlet UILabel *indicatorLabel;
@property (nonatomic, strong) IBOutlet UILabel *lowerBoundLabel;
@property (nonatomic, strong) IBOutlet UILabel *upperBoundLabel;
@property (nonatomic, strong) IBOutlet SCPRButton *startButton;
@property (nonatomic, strong) IBOutlet UILabel *remainingLabel;
@property (nonatomic, strong) IBOutlet NSLayoutConstraint *indicatorTopAnchor;
@property (nonatomic, strong) IBOutlet UIView *scrubbingSeatView;
@property (nonatomic, strong) IBOutlet UIActivityIndicatorView *spinner;
@property NSInteger armableSeconds;

- (void)setup;
- (void)setupInactive;
- (void)setupActive;
- (void)stylizeBoundingLabel:(UILabel*)boundingLabel;
- (void)armSleepTimer;
- (void)disarmSleepTimer;
- (void)zero;
- (void)kickoff;


@end
