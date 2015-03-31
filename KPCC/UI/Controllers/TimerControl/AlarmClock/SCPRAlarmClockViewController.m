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
#import "SCPRMasterViewController.h"
#import "AnalyticsManager.h"
#import "UXmanager.h"

@interface SCPRAlarmClockViewController ()

@end

@implementation SCPRAlarmClockViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.view layoutIfNeeded];
    
    self.view.backgroundColor = [UIColor clearColor];
    self.scrubberControl.scrubbingDelegate = self;
    self.spinner.alpha = 0.0;

    // Do any additional setup after loading the view from its nib.
}

- (void)viewDidAppear:(BOOL)animated {
    
    UIUserNotificationSettings *settings = [[UIApplication sharedApplication] currentUserNotificationSettings];
    if ( settings.types == UIUserNotificationTypeNone ) {
        [[[UIAlertView alloc] initWithTitle:@"Push Notifications Required"
                                    message:@"To use this feature, please enable push notifications for KPCC in your settings"
                                   delegate:nil
                          cancelButtonTitle:@"OK"
                          otherButtonTitles:nil] show];
        self.scheduleButton.alpha = 0.45;
        self.scheduleButton.enabled = NO;
    } else {
        self.scheduleButton.alpha = 1.0;
        self.scheduleButton.enabled = YES;
    }

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
    
    [self setupForState];
    
    [self.scrubberControl applyPercentageToScrubber:(CGFloat)((1.0f*60*60*8)/(1.0f*60*60*24))];
}

#pragma mark - Action
- (void)setupForState {
    
    [[UIApplication sharedApplication] cancelAllLocalNotifications];
    [self.scheduleButton removeTarget:nil
                               action:nil
                     forControlEvents:UIControlEventAllEvents];
    
    NSString *buttonText = @"";
    SEL action = nil;
    CGFloat scrubberAlpha = 0.0f;
    UIColor *textColor = nil;
    if ( [[Utils del] alarmDate] ) {

        buttonText = @"Cancel Alarm Clock";
        action = @selector(unscheduleAlarm);
        scrubberAlpha = 0.0f;
        textColor = [UIColor kpccOrangeColor];
        
    } else {
        
        buttonText = @"Set Alarm Clock";
        action = @selector(scheduleAlarm);
        scrubberAlpha = 1.0f;
        textColor = [UIColor whiteColor];
        
    }
    
    [[DesignManager shared] sculptButton:self.scheduleButton
                               withStyle:SculptingStyleClearWithBorder
                                 andText:buttonText];
    
    [self.scheduleButton addTarget:self
                            action:action
                  forControlEvents:UIControlEventTouchUpInside
                           special:YES];
    
    [UIView animateWithDuration:0.45 animations:^{
        self.scrubberMainValueLabel.textColor = textColor;
        self.scrubberControl.view.alpha = scrubberAlpha;
        self.spinner.alpha = 0.0f;
        self.scheduleButton.alpha = 1.0f;
    } completion:^(BOOL finished) {
        
    }];
    
}
- (void)scheduleAlarm {
    [UIView animateWithDuration:0.22 animations:^{
        self.scheduleButton.alpha = 0.0;
        self.spinner.alpha = 1.0;
        [self.spinner startAnimating];
    } completion:^(BOOL finished) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.75 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [[Utils del] armAlarmClockWithDate:self.armDate];
        });
    }];

}

- (void)unscheduleAlarm {
    [UIView animateWithDuration:0.22 animations:^{
        self.scheduleButton.alpha = 0.0;
        self.spinner.alpha = 1.0;
        [self.spinner startAnimating];
    } completion:^(BOOL finished) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.75 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [[Utils del] endAlarmClock];
            [self setupForState];
        });
    }];

}

#pragma mark - Scrubbable
- (void)actionOfInterestAfterScrub:(CGFloat)finalValue {
    
}

- (void)actionOfInterestWithPercentage:(CGFloat)percent {
    NSInteger twentyFour = 60*60*24;
    twentyFour = ceilf((twentyFour * 1.0) * percent);
    NSDate *then = [self.relativeNow dateByAddingTimeInterval:twentyFour];
    then = [then minuteRoundedUpByThreshold:5];
    
    self.armDate = then;
    NSString *pretty = [NSDate stringFromDate:then
                                   withFormat:@"EEE MM/dd, hh:mm a"];
    
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
