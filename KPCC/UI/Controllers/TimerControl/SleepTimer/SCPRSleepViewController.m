//
//  SCPRSleepViewController.m
//  KPCC
//
//  Created by Ben Hochberg on 3/20/15.
//  Copyright (c) 2015 SCPR. All rights reserved.
//

#import "SCPRSleepViewController.h"
#import "DesignManager.h"
#import "UILabel+Additions.h"
#import "NSDate+Helper.h"
#import "SessionManager.h"
#import "AudioManager.h"

@interface SCPRSleepViewController ()

@end

@implementation SCPRSleepViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)setup {
    [self.view layoutIfNeeded];
    
    if ( [Utils isThreePointFive] ) {
        self.globalTopAnchor.constant = 178.0f;
        self.bottomAnchor.constant = 12.0f;
    } else {
        self.globalTopAnchor.constant = 228.0f;
        self.bottomAnchor.constant = 32.0f;
    }
    
    self.spinner.alpha = 0.0;
    self.armableSeconds = 300;
    
    [self.scrubber setupWithDelegate:self];
    [self.scrubber unmask];
    
    [self stylizeBoundingLabel:self.lowerBoundLabel];
    [self stylizeBoundingLabel:self.upperBoundLabel];
    [self.scrubbingSeatView layoutIfNeeded];
    
    [self.remainingLabel setFont:[[DesignManager shared] proBook:14.0]];
    self.remainingLabel.textColor = [UIColor kpccSoftOrangeColor];
    self.scrubbingSeatView.backgroundColor = [UIColor clearColor];
    
    if ( [[SessionManager shared] sleepTimerActive] ) {
        [self setupActive];
    } else {
        [self setupInactive];
    }
}

- (void)zero {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    self.spinner.alpha = 0.0;
    self.startButton.alpha = 1.0;

    [self actionOfInterestWithPercentage:0.0];
    [self.startButton removeTarget:nil
                            action:nil
                  forControlEvents:UIControlEventAllEvents];
}

- (void)setupInactive {
    
    [self zero];
    
    [[DesignManager shared] sculptButton:self.startButton
                               withStyle:SculptingStyleClearWithBorder
                                 andText:@"Start Sleep Timer"
     iconName:@"icon-stopwatch.png"];
    
    self.scrubbingSeatView.alpha = 1.0;
    self.indicatorTopAnchor.constant = 38.0f;
    self.remainingLabel.alpha = 0.0;
    self.indicatorLabel.attributedText = [NSDate prettyAttributedFromSeconds:300 includeSeconds:NO];
    self.indicatorLabel.alpha = 1.0;
    [self.startButton addTarget:self
                         action:@selector(armSleepTimer)
               forControlEvents:UIControlEventTouchUpInside
                        special:YES];
}

- (void)setupActive {
    [self zero];
    
    self.indicatorLabel.attributedText = [NSDate prettyAttributedFromSeconds:[[SessionManager shared] remainingSleepTimerSeconds] includeSeconds:YES];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(sleepTimerTicked)
                                                 name:@"sleep-timer-ticked"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(disarmSleepTimer)
                                                 name:@"sleep-timer-disarmed"
                                               object:nil];
    
    [[DesignManager shared] sculptButton:self.startButton
                               withStyle:SculptingStyleClearWithBorder
                                 andText:@"Cancel Sleep Timer"];
    
    self.scrubbingSeatView.alpha = 0.0;
    self.indicatorTopAnchor.constant = 13.0f;
    self.remainingLabel.alpha = 1.0;
    
    [self.startButton addTarget:self
                         action:@selector(disarmSleepTimer)
               forControlEvents:UIControlEventTouchUpInside
                        special:YES];

}



- (void)stylizeBoundingLabel:(UILabel *)boundingLabel {
    NSMutableAttributedString *lowerBoundString = [[NSMutableAttributedString alloc] initWithString:boundingLabel.text
                                                                                         attributes:nil];
    NSRange digit = NSMakeRange(0, 1);
    NSString *rest = [boundingLabel.text substringFromIndex:1];
    NSRange restRange = NSMakeRange(1, rest.length);
    
    NSDictionary *digitParams = @{ NSFontAttributeName : [[DesignManager shared] proLight:18.0],
                                   NSForegroundColorAttributeName : [UIColor whiteColor] };
    NSDictionary *restParams = @{ NSFontAttributeName : [[DesignManager shared] proLight:12.0],
                                  NSForegroundColorAttributeName : [UIColor whiteColor] };
    [lowerBoundString addAttributes:digitParams
                              range:digit];
    [lowerBoundString addAttributes:restParams
                              range:restRange];
    
    boundingLabel.attributedText = lowerBoundString;
}

#pragma mark - Timer Functions
- (void)kickoff {

    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        [[SessionManager shared] armSleepTimerWithSeconds:self.armableSeconds
                                                completed:^{
                                                    
                                                    [UIView animateWithDuration:0.33 animations:^{
                                                        [self setupActive];
                                                        [self.view layoutIfNeeded];
                                                    } completion:^(BOOL finished) {
                                                        
                                                        
                                                        
                                                    }];
                                                    
                                                }];
        
    });

}

- (void)sleepTimerTicked {
    self.indicatorLabel.attributedText = [NSDate prettyAttributedFromSeconds:[[SessionManager shared] remainingSleepTimerSeconds] includeSeconds:YES];
    if ( [[SessionManager shared] remainingSleepTimerSeconds] <= 0 ) {
        [UIView animateWithDuration:0.33 animations:^{
            [self setupInactive];
            [self.view layoutIfNeeded];
        }];
    }
}

- (void)armSleepTimer {
    [UIView animateWithDuration:0.25 animations:^{
        [self.spinner setAlpha:1.0];
        [self.spinner startAnimating];
        [self.startButton setAlpha:0.0];
    } completion:^(BOOL finished) {
#ifdef USE_ONDEMAND_SAFEGUARD
        if ( [[AudioManager shared] isPlayingAudio] && [[AudioManager shared] currentAudioMode] != AudioModeLive ) {
            
            [[[UIAlertView alloc] initWithTitle:@"Switch to Live"
                                        message:@"Using a sleep timer will change your listening to the KPCC live stream. Is this OK?"
                                       delegate:self
                              cancelButtonTitle:@"No thanks"
                              otherButtonTitles:@"Yes",nil] show];
            
        } else {
#endif
            [self kickoff];
#ifdef USE_ONDEMAND_SAFEGUARD
        }
#endif
    }];
}

- (void)disarmSleepTimer {
    [UIView animateWithDuration:0.25 animations:^{
        [self.spinner setAlpha:1.0];
        [self.spinner startAnimating];
        [self.startButton setAlpha:0.0];
        [self.indicatorLabel setAlpha:0.0f];
        [self.remainingLabel setAlpha:0.0f];
    } completion:^(BOOL finished) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            
            [[SessionManager shared] cancelSleepTimerWithCompletion:^{
                                                        
                                                        [UIView animateWithDuration:0.33 animations:^{
                                                            [self setupInactive];
                                                            [self.view layoutIfNeeded];
                                                        }];
                                                        
                                                    }];
            
        });
    }];
}

#pragma mark - Scrubbable
- (void)actionOfInterestAfterScrub:(CGFloat)finalValue {

}

- (void)actionOfInterestWithPercentage:(CGFloat)percent {
    // Range is 5 to 480
    NSInteger minutes = ceilf(percent * 475.0);
    if ( minutes < 0 ) {
        minutes = 0;
    } else if ( minutes > 475 ) {
        minutes = 475;
    }
    
    NSInteger seconds = minutes * 60;
    seconds += 300;
    seconds = seconds - ( seconds % 300 );
    NSLog(@"Seconds : %ld",(long)seconds);
    self.armableSeconds = seconds;
    self.indicatorLabel.attributedText = [NSDate prettyAttributedFromSeconds:seconds includeSeconds:NO];
}

- (UILabel*)scrubbingIndicatorLabel {
    return self.indicatorLabel;
}

- (SCPRTouchableScrubberView*)scrubbableView {
    return self.scrubbingTouchView;
}

#pragma mark - UIAlertView
- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if ( buttonIndex == 0 ) {
        [UIView animateWithDuration:0.33 animations:^{
            [self setupInactive];
            [self.view layoutIfNeeded];
        }];
    } else {
        [self kickoff];
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
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
