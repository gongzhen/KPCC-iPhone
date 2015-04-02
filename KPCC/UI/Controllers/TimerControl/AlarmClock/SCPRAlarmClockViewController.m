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
    
    /*UIUserNotificationSettings *settings = [[UIApplication sharedApplication] currentUserNotificationSettings];
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
    }*/

}

- (void)setup {
    [self.scrubberControl setupWithDelegate:self
                                   circular:YES];
    [self.scrubberControl unmask];
    [self.scrubberMainValueLabel proBookFontize];
    [self setupForState];
    
    self.willWakeLabel.text = @"WILL WAKE ON:";
    
    self.inbetweenAnchor.constant = [Utils isThreePointFive] ? 6.0f : 31.0f;
    self.bottomAnchor.constant = [Utils isThreePointFive] ? 12.0f : 32.0f;
    
    NSString *pretty = [NSDate stringFromDate:self.armDate
                                   withFormat:@"EEE h:mm a"];
    self.scrubberMainValueLabel.attributedText = [[DesignManager shared] standardTimeFormatWithString:pretty
                                                                                           attributes:@{ @"digits" : [[DesignManager shared] proLight:48.0f],
                                                                                                         @"period" : [[DesignManager shared] proLight:26.0f] }];
    
    
    [self.willWakeLabel proBookFontize];
    self.willWakeLabel.textColor = [UIColor kpccOrangeColor];
    
    
    NSString *lowerBound = [NSDate stringFromDate:self.relativeNow
                                       withFormat:@"h:mm a"];
    self.midnightLabel.attributedText = [[DesignManager shared] standardTimeFormatWithString:lowerBound
                                                                                  attributes:@{ @"digits" : [[DesignManager shared] proLight:18.0f],
                                                                                                @"period" : [[DesignManager shared] proLight:12.0f] }];
    
    NSString *upperBound = [NSDate stringFromDate:[self.relativeNow dateByAddingTimeInterval:60*60*12]
                                       withFormat:@"h:mm a"];
    self.noonLabel.attributedText = [[DesignManager shared] standardTimeFormatWithString:upperBound
                                                                                  attributes:@{ @"digits" : [[DesignManager shared] proLight:18.0f],
                                                                                                @"period" : [[DesignManager shared] proLight:12.0f] }];
    
    
    
    
}

#pragma mark - Action
- (void)setupForState {
    

    [self.scheduleButton removeTarget:nil
                               action:nil
                     forControlEvents:UIControlEventAllEvents];
    
    NSString *buttonText = @"";
    SEL action = nil;
    CGFloat scrubberAlpha = 0.0f;
    CGFloat wakeAlpha = 0.0f;
    CGFloat topPush = 0.0f;
    UIColor *textColor = nil;
    NSString *iconName = nil;
    if ( [[Utils del] alarmDate] ) {

        buttonText = @"Cancel Alarm Clock";
        action = @selector(unscheduleAlarm);
        scrubberAlpha = 0.0f;
        textColor = [UIColor whiteColor];
        topPush = 170.0f;
        wakeAlpha = 1.0f;
        self.relativeNow = [NSDate date];
        self.armDate = [[UXmanager shared].settings alarmFireDate];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(setupForState)
                                                        name:@"alarm-fired"
                                                      object:nil];
        
    } else {
        
        buttonText = @"Set Alarm Clock";
        action = @selector(scheduleAlarm);
        scrubberAlpha = 1.0f;
        textColor = [UIColor whiteColor];
        topPush = 64.0;
        wakeAlpha = 0.0f;
        iconName = @"icon-clock.png";
        self.relativeNow = [NSDate date];
        self.armDate = [self.relativeNow dateByAddingTimeInterval:60*60*8];
        [self.scrubberControl applyPercentageToScrubber:(CGFloat)((1.0f*60*60*8)/(1.0f*60*60*24))];
        
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                     name:@"alarm-fired"
                                                   object:nil];
        
    }
    
    if ( [Utils isThreePointFive] ) {
        topPush -= 10.0f;
    }
    
    [[DesignManager shared] sculptButton:self.scheduleButton
                               withStyle:SculptingStyleClearWithBorder
                                 andText:buttonText
                                iconName:iconName];
    
    [self.scheduleButton addTarget:self
                            action:action
                  forControlEvents:UIControlEventTouchUpInside
                           special:YES];
    
    [UIView animateWithDuration:0.45 animations:^{
        self.scrubberMainValueLabel.textColor = textColor;
        self.scrubberControl.view.alpha = scrubberAlpha;
        self.spinner.alpha = 0.0f;
        self.scheduleButton.alpha = 1.0f;
        self.noonLabel.alpha = scrubberAlpha;
        self.midnightLabel.alpha = scrubberAlpha;
        self.topAnchor.constant = topPush;
        self.willWakeLabel.alpha = wakeAlpha;
        [self.view layoutIfNeeded];
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
#ifndef DEBUG
            [[[UIAlertView alloc] initWithTitle:@"Your alarm has been set"
                                        message:@"Keep the KPCC app in the foreground or the alarm will be disabled"
                                       delegate:nil
                              cancelButtonTitle:@"OK"
                              otherButtonTitles:nil] show];
#endif
            [self setupForState];
            
        });
    }];

}

- (void)unscheduleAlarm {
    
    self.relativeNow = [NSDate date];
    self.armDate = self.relativeNow;
    
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
                                   withFormat:@"EEE h:mm a"];
    
    self.scrubberMainValueLabel.attributedText = [[DesignManager shared] standardTimeFormatWithString:pretty
                                                                                           attributes:@{ @"digits" : [[DesignManager shared] proLight:48.0f],
                                                                                                         @"period" : [[DesignManager shared] proLight:26.0f] }];;
    

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
