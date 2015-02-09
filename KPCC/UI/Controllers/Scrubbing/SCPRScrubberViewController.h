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

- (void)setup;

@end
