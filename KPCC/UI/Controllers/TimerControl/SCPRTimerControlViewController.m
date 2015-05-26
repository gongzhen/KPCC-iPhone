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
#import "SCPRSleepViewController.h"
#import "SCPRAlarmClockViewController.h"
#import "Utils.h"

@interface SCPRTimerControlViewController ()

@end

@implementation SCPRTimerControlViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.view layoutIfNeeded];
    
    // Do any additional setup after loading the view from its nib.
}

- (void)viewWillAppear:(BOOL)animated {
    
    [self.navigationController.interactivePopGestureRecognizer setDelegate:self];
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    return false;
}

- (void)setup {
    
    [self.view layoutIfNeeded];
    [self.view printDimensionsWithIdentifier:@"Timer Container View"];
    [self.toggleScroller printDimensionsWithIdentifier:@"Timer Scroller View"];
    
    self.navigationItem.title = @"Wake / Sleep";
    
    self.toggleScroller.translatesAutoresizingMaskIntoConstraints = NO;
    
    self.buttonSeatView.backgroundColor = [UIColor clearColor];
    
    [self.sleepTimerButton scprBookifyWithSize:21.0f];
    [self.alarmClockButton scprBookifyWithSize:21.0f];
    
    [self.sleepTimerButton addTarget:self
                              action:@selector(toggleTimerFunction:)
                    forControlEvents:UIControlEventTouchUpInside
                             special:YES];
    
    [self.alarmClockButton addTarget:self
                              action:@selector(toggleTimerFunction:)
                    forControlEvents:UIControlEventTouchUpInside
                             special:YES];
    
    self.selectedButton = self.sleepTimerButton;
    [self.sleepTimerButton setActive:YES];
    
    self.toggleScroller.contentSize = CGSizeMake(self.toggleScroller.frame.size.width*2,
                                                 self.toggleScroller.frame.size.height);
    
    self.sleepTimerController = [[SCPRSleepViewController alloc] initWithNibName:@"SCPRSleepViewController"
                                                                          bundle:nil];
    self.sleepTimerController.view.frame = self.sleepTimerController.view.frame;
    
    NSString *xib = @"SCPRAlarmClockViewController";
    if ( [Utils isThreePointFive] && ![Utils isIOS8] ) {
        xib = @"SCPRAlarmClockViewController7";
    }
    
    self.alarmClockController = [[SCPRAlarmClockViewController alloc] initWithNibName:xib
                                                                               bundle:nil];
    
    self.alarmClockController.view.frame = self.alarmClockController.view.frame;
    
    
    UIView *st = self.sleepTimerController.view;
    UIView *ac = self.alarmClockController.view;
    
    st.backgroundColor = [UIColor clearColor];
    ac.backgroundColor = [UIColor clearColor];
    
    st.translatesAutoresizingMaskIntoConstraints = NO;
    ac.translatesAutoresizingMaskIntoConstraints = NO;
    
    self.blurredImageView.image = [[DesignManager shared] currentBlurredLiveImage];
    
    [self.toggleScroller addSubview:st];
    [self.toggleScroller addSubview:ac];
    self.toggleScroller.scrollEnabled = NO;
    
    NSString *hFormat = [NSString stringWithFormat:@"H:|[v1(%1.1f)][v2(%1.1f)]|",self.toggleScroller.frame.size.width,self.toggleScroller.frame.size.width];
    
    
    NSArray *v1c = [NSLayoutConstraint constraintsWithVisualFormat:hFormat
                                                           options:0
                                                           metrics:nil
                                                             views:@{ @"v1" : st,
                                                                      @"v2" : ac }];
    
    NSArray *v1vc = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[v1]|"
                                                            options:0
                                                            metrics:nil
                                                              views:@{ @"v1" : st }];
    
    NSArray *v2vc = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[v2]|"
                                                            options:0
                                                            metrics:nil
                                                              views:@{ @"v2" : ac }];
    
    [self.toggleScroller addConstraints:v1c];
    [self.toggleScroller addConstraints:v1vc];
    [self.toggleScroller addConstraints:v2vc];
    
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
    
    if ( ![Utils isIOS8] ) {
        self.alarmClockController.view.alpha = 0.0f;
    }
    
    [self.view layoutIfNeeded];
    
    [self.chromaKeyView setBackgroundColor:[[UIColor virtualBlackColor] translucify:0.5f]];
    [self.sleepTimerController setup];
    [self.alarmClockController setup];
}

- (void)toggleTimerFunction:(SCPRButton*)sender {
    
    if ( self.selectedButton ) {
        [self.selectedButton setActive:NO];
    }
    
    self.selectedButton = sender;
    [self.selectedButton setActive:YES];
    
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

    self.alarmClockController.view.alpha = 1.0f;
    
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
