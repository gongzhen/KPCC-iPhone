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
    [self.startButton removeTarget:nil
                            action:nil
                  forControlEvents:UIControlEventAllEvents];
}

- (void)setupInactive {
    
    [self zero];
    
    [[DesignManager shared] sculptButton:self.startButton
                               withStyle:SculptingStyleClearWithBorder
                                 andText:@"Start Sleep Timer"];
    self.scrubbingSeatView.alpha = 1.0;
    self.indicatorTopAnchor.constant = 38.0f;
    self.remainingLabel.alpha = 0.0;
    self.indicatorLabel.attributedText = [NSDate prettyAttributedFromSeconds:300 includeSeconds:NO];
    

    
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
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            
            [[SessionManager shared] armSleepTimerWithSeconds:self.armableSeconds
                                                    completed:^{
                                                        
                                                        [UIView animateWithDuration:0.33 animations:^{
                                                            [self setupActive];
                                                            [self.view layoutIfNeeded];
                                                        }];
                                                        
                                                    }];
            
        });
    }];
}

- (void)disarmSleepTimer {
    [UIView animateWithDuration:0.25 animations:^{
        [self.spinner setAlpha:1.0];
        [self.spinner startAnimating];
        [self.startButton setAlpha:0.0];
    } completion:^(BOOL finished) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            
            [[SessionManager shared] disarmSleepTimerWithCompletion:^{
                                                        
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
