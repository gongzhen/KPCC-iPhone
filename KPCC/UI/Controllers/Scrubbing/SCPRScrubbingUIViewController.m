//
//  SCPRScrubbingUIViewController.m
//  KPCC
//
//  Created by Ben Hochberg on 2/9/15.
//  Copyright (c) 2015 SCPR. All rights reserved.
//

#import "SCPRScrubbingUIViewController.h"
#import "DesignManager.h"
#import "SCPRMasterViewController.h"

@interface SCPRScrubbingUIViewController ()

@end

@implementation SCPRScrubbingUIViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.darkeningView.backgroundColor = [[UIColor virtualBlackColor] translucify:0.35];
    // Do any additional setup after loading the view from its nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidLayoutSubviews {
    //[self cutDisplayHole];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.25 animations:^{
            self.view.alpha = 1.0;
        }];
    });

}

- (void)setupWithProgram:(NSDictionary *)program blurredImage:(UIImage *)image parent:(id)parent {
    self.parentControlView = parent;
    self.blurredImageView.image = image;
    AudioChunk *ac = program[@"chunk"];
    
    self.captionLabel.text = ac.audioTitle;
    self.blurredImageView.alpha = 0.0;
    

    self.captionLabel.font = [[DesignManager shared] proLight:self.captionLabel.font.pointSize];
    
    [self.closeButton addTarget:self
                         action:@selector(closeScrubber)
               forControlEvents:UIControlEventTouchUpInside];
    
}

- (void)closeScrubber {
    SCPRMasterViewController *mvc = (SCPRMasterViewController*)self.parentControlView;
    [UIView animateWithDuration:0.25 animations:^{
        [mvc decloakForScrubber];
        [[DesignManager shared] fauxRevealNavigationBar];
        self.view.alpha = 0.0;
    } completion:^(BOOL finished) {
        [self.view removeFromSuperview];
    }];
    
    
}

- (void)cutDisplayHole {
    
    self.darkeningView.backgroundColor = [[UIColor virtualBlackColor] translucify:0.45];
    
    CAShapeLayer *box = [CAShapeLayer layer];
    box.path = CGPathCreateWithRect(self.darkeningView.frame, nil);
    box.fillRule = kCAFillRuleEvenOdd;
    box.fillColor = [UIColor blackColor].CGColor;
    box.opacity = 1.0;
    

    CAShapeLayer *fillLayer = [CAShapeLayer layer];
    fillLayer.path = CGPathCreateWithRect(self.scrubberSeatView.frame, nil);;
    fillLayer.fillRule = kCAFillRuleEvenOdd;
    fillLayer.opacity = 1.0;
    fillLayer.frame = self.scrubberSeatView.frame;
    
    [box addSublayer:fillLayer];
    [self.darkeningView.layer setMask:box];
    
    self.scrubberSeatView.alpha = 0.0;
    
}

#pragma mark - AudioManager
- (void)onRateChange {
    if ([[AudioManager shared] isStreamPlaying] || [[AudioManager shared] isStreamBuffering]) {
        [self.playPauseButton fadeImage:[UIImage imageNamed:@"btn_pause.png"] duration:0.2];
    } else {
        [self.playPauseButton fadeImage:[UIImage imageNamed:@"btn_play.png"] duration:0.2];
    }
}

- (void)onTimeChange {
    
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
