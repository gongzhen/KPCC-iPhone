//
//  SCPRAlarmClockViewController.m
//  KPCC
//
//  Created by Ben Hochberg on 3/23/15.
//  Copyright (c) 2015 SCPR. All rights reserved.
//

#import "SCPRAlarmClockViewController.h"
#import "UILabel+Additions.h"

@interface SCPRAlarmClockViewController ()

@end

@implementation SCPRAlarmClockViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.view layoutIfNeeded];
    
    self.view.backgroundColor = [UIColor clearColor];
    self.scrubberControl.scrubbingDelegate = self;
    // Do any additional setup after loading the view from its nib.
}

- (void)setup {
    [self.scrubberControl setupWithDelegate:self
                                   circular:YES];
    [self.scrubberControl unmask];
    
    [self.scrubberMainValueLabel proBookFontize];
    self.scrubberMainValueLabel.textColor = [UIColor whiteColor];
}

#pragma mark - Scrubbable
- (void)actionOfInterestAfterScrub:(CGFloat)finalValue {
    
}

- (void)actionOfInterestWithPercentage:(CGFloat)percent {
    // Range is 5 to 480
    NSInteger dayInSeconds = 60*60*24;
    
}

- (UILabel*)scrubbingIndicatorLabel {
    return self.scrubberMainValueLabel;
}

- (SCPRTouchableScrubberView*)scrubbableView {
    return self.scrubbingSurface;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
