//
//  SCPRAlarmClockViewController.m
//  KPCC
//
//  Created by Ben Hochberg on 3/23/15.
//  Copyright (c) 2015 SCPR. All rights reserved.
//

#import "SCPRAlarmClockViewController.h"
#import "UILabel+Additions.h"
#import "NSDate+Helper.h"
#import "UIColor+UICustom.h"
#import "DesignManager.h"
#import "Utils.h"

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
    
    self.relativeNow = [NSDate date];
    self.armDate = [self.relativeNow dateByAddingTimeInterval:60*60*8];
    
    NSString *pretty = [NSDate stringFromDate:self.armDate
                                   withFormat:@"EEE MM/dd, hh:mm a"];
    self.scrubberMainValueLabel.text = pretty;
    
    [[DesignManager shared] sculptButton:self.scheduleButton
                               withStyle:SculptingStyleClearWithBorder
                                 andText:@"Set Alarm Clock"];
    
    [self.scheduleButton addTarget:self
                            action:@selector(scheduleAlarm)
                  forControlEvents:UIControlEventTouchUpInside
                           special:YES];
    
    self.scrubberMainValueLabel.textColor = [UIColor whiteColor];
    
    [self.scrubberControl applyPercentageToScrubber:(CGFloat)((1.0f*60*60*8)/(1.0f*60*60*24))];
}

#pragma mark - Action
- (void)scheduleAlarm {
    
    [UIView animateWithDuration:0.45 animations:^{
        self.scrubberMainValueLabel.textColor = [UIColor kpccOrangeColor];
        self.scrubberControl.view.alpha = 0.0;
    } completion:^(BOOL finished) {
        
        [[Utils del] armAlarmClockWithDate:self.armDate];
        
    }];
}

#pragma mark - Scrubbable
- (void)actionOfInterestAfterScrub:(CGFloat)finalValue {
    
}

- (void)actionOfInterestWithPercentage:(CGFloat)percent {
    NSInteger twentyFour = 60*60*24;
    twentyFour = ceilf((twentyFour * 1.0) * percent);
    NSDate *then = [self.relativeNow dateByAddingTimeInterval:twentyFour];
    self.armDate = then;
    NSString *pretty = [NSDate stringFromDate:then
                                   withFormat:@"EEE MM/dd, hh:mm a"];
    
#ifdef DEBUG
    self.armDate = [[NSDate date] dateByAddingTimeInterval:210.0];
#endif
    
    self.scrubberMainValueLabel.text = pretty;
    

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
