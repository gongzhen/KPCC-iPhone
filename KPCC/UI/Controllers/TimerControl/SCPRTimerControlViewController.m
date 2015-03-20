//
//  SCPRTimerControlViewController.m
//  KPCC
//
//  Created by Ben Hochberg on 3/19/15.
//  Copyright (c) 2015 SCPR. All rights reserved.
//

#import "SCPRTimerControlViewController.h"
#import "DesignManager.h"
#import "UIView+PrintDimensions.h"
#import "UIColor+UICustom.h"

@interface SCPRTimerControlViewController ()

@end

@implementation SCPRTimerControlViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.view layoutIfNeeded];
    
    // Do any additional setup after loading the view from its nib.
}

- (void)setup {
    
    [self.view layoutIfNeeded];
    [self.view printDimensionsWithIdentifier:@"Timer Container View"];
    [self.toggleScroller printDimensionsWithIdentifier:@"Timer Scroller View"];
    
    self.toggleScroller.translatesAutoresizingMaskIntoConstraints = NO;
    
    self.buttonSeatView.backgroundColor = [UIColor clearColor];
    
    [self.sleepTimerButton scprifyWithSize:21.0f];
    [self.alarmClockButton scprifyWithSize:21.0f];
    
    [self.sleepTimerButton addTarget:self
                              action:@selector(toggleTimerFunction:)
                    forControlEvents:UIControlEventTouchUpInside
                             special:YES];
    
    [self.alarmClockButton addTarget:self
                              action:@selector(toggleTimerFunction:)
                    forControlEvents:UIControlEventTouchUpInside
                             special:YES];
    
    self.selectedButton = self.sleepTimerButton;
    
    self.toggleScroller.contentSize = CGSizeMake(self.toggleScroller.frame.size.width*2,
                                                 self.toggleScroller.frame.size.height);
    
    UIView *st = [[UIView alloc] init];
    UIView *ac = [[UIView alloc] init];
    st.backgroundColor = [[UIColor purpleColor] translucify:0.15];
    ac.backgroundColor = [[UIColor greenColor] translucify:0.15];
    st.translatesAutoresizingMaskIntoConstraints = NO;
    ac.translatesAutoresizingMaskIntoConstraints = NO;
    
    self.blurredImageView.image = [[DesignManager shared] currentBlurredLiveImage];
    
    [self.toggleScroller addSubview:st];
    [self.toggleScroller addSubview:ac];
    
    NSString *hFormat = [NSString stringWithFormat:@"H:|[v1(%1.1f)][v2(%1.1f)]|",self.toggleScroller.frame.size.width,self.toggleScroller.frame.size.width];
    
    
    NSArray *v1c = [NSLayoutConstraint constraintsWithVisualFormat:hFormat
                                                           options:0
                                                           metrics:nil
                                                             views:@{ @"v1" : st,
                                                                      @"v2" : ac }];
    
    
    [self.toggleScroller addConstraints:v1c];
    
    NSLayoutConstraint *heightV1 = [NSLayoutConstraint constraintWithItem:st
                                                                attribute:NSLayoutAttributeHeight
                                                                relatedBy:NSLayoutRelationEqual
                                                                   toItem:nil
                                                                attribute:NSLayoutAttributeNotAnAttribute
                                                               multiplier:1.0
                                                                 constant:self.toggleScroller.frame.size.height];
    
    NSLayoutConstraint *heightV2 = [NSLayoutConstraint constraintWithItem:ac
                                                                attribute:NSLayoutAttributeHeight
                                                                relatedBy:NSLayoutRelationEqual
                                                                   toItem:nil
                                                                attribute:NSLayoutAttributeNotAnAttribute
                                                               multiplier:1.0
                                                                 constant:self.toggleScroller.frame.size.height];
    
    [st addConstraint:heightV1];
    [ac addConstraint:heightV2];
    
    [self.view layoutIfNeeded];
    

    
}

- (void)toggleTimerFunction:(SCPRButton*)sender {
    
    self.selectedButton = sender;
    CGFloat offset = 0.0f;
    if ( self.selectedButton == self.alarmClockButton ) {
        offset = self.toggleScroller.frame.size.width;
    } else {
        offset = 0.0f;
    }
    
    [self.buttonSeatView removeConstraint:self.ddgCenterXAnchor];
    
    self.ddgCenterXAnchor = [NSLayoutConstraint constraintWithItem:self.duckDuckGooseView
                                                         attribute:NSLayoutAttributeCenterX
                                                         relatedBy:NSLayoutRelationEqual
                                                            toItem:self.selectedButton
                                                         attribute:NSLayoutAttributeCenterX
                                                        multiplier:1.0
                                                          constant:0.0];
    [self.buttonSeatView addConstraint:self.ddgCenterXAnchor];

    [UIView animateWithDuration:0.33 animations:^{
        self.toggleScroller.contentOffset = CGPointMake(offset,0.0f);
        [self.buttonSeatView layoutIfNeeded];
    } completion:^(BOOL finished) {
        // Do something eventually
    }];
    
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
