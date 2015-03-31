//
//  SCPRAlarmClockViewController.h
//  KPCC
//
//  Created by Ben Hochberg on 3/23/15.
//  Copyright (c) 2015 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SCPRScrubberViewController.h"
#import "SCPRTouchableScrubberView.h"
#import "SCPRButton.h"

@interface SCPRAlarmClockViewController : UIViewController<Scrubbable>

@property (nonatomic, strong) IBOutlet SCPRScrubberViewController *scrubberControl;
@property (nonatomic, strong) IBOutlet SCPRTouchableScrubberView *scrubbingSurface;
@property (nonatomic, strong) IBOutlet UILabel *scrubberMainValueLabel;
@property (nonatomic, strong) NSDate *relativeNow;
@property (nonatomic, strong) NSDate *armDate;
@property (nonatomic, strong) IBOutlet SCPRButton *scheduleButton;
@property (nonatomic, strong) IBOutlet UIActivityIndicatorView *spinner;
@property (nonatomic, strong) IBOutlet UILabel *midnightLabel;
@property (nonatomic, strong) IBOutlet UILabel *noonLabel;
@property (nonatomic, strong) IBOutlet UILabel *willWakeLabel;

@property BOOL throwRequirement;

- (void)setup;
- (void)setupForState;

@end
