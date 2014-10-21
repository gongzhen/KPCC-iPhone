//
//  SCPRPreRollViewController.m
//  KPCC
//
//  Created by John Meeker on 10/14/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "SCPRPreRollViewController.h"
#import <POP/POP.h>

#define kDefaultAdPresentationTime 10.0

@interface SCPRPreRollViewController ()
{
    float currentPresentedDuration;
}

@property IBOutlet UIProgressView *adProgressView;

@property (nonatomic) NSTimer *timer;


@end

@implementation SCPRPreRollViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.

}


# pragma mark - Presentations

- (void)showPreRollWithAnimation:(BOOL)animated completion:(void (^)(BOOL done))completion {
    if (animated) {
        [UIView animateWithDuration:0.3f animations:^{
            CGRect frame = CGRectMake(self.view.frame.origin.x, 0, self.view.frame.size.width, self.view.frame.size.height);
            self.view.frame = frame;
            
        } completion:^(BOOL finished) {

            if (self.timer == nil) {
                currentPresentedDuration = 0;
                [self.adProgressView setProgress:0 animated:YES];
                self.timer = [NSTimer scheduledTimerWithTimeInterval:0.01
                                                              target:self
                                                            selector:@selector(setAdProgress)
                                                            userInfo:nil
                                                             repeats:YES];
            }
            completion(YES);
        }];
        
        
    } else {
        completion(YES);
    }
}


# pragma mark - Actions

- (IBAction)dismissTapped:(id)sender {
    if ([self.delegate respondsToSelector:@selector(preRollCompleted)]) {
        [self.delegate preRollCompleted];
    }

    [UIView animateWithDuration:0.3f animations:^{
        CGRect frame = CGRectMake(self.view.frame.origin.x,
                                  -self.view.frame.size.height,
                                  self.view.frame.size.width,
                                  self.view.frame.size.height);
        self.view.frame = frame;

    } completion:^(BOOL finished) {

        if (self.timer != nil && [self.timer isValid]) {
            [self.timer invalidate];
            self.timer = nil;
        }

        [self.adProgressView setProgress:0.0];
    }];
}

- (void)setAdProgress {

    currentPresentedDuration = currentPresentedDuration + 0.01;

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.adProgressView setProgress:(currentPresentedDuration/kDefaultAdPresentationTime) animated:YES];
    });

    if (currentPresentedDuration >= kDefaultAdPresentationTime) {
        [self dismissTapped:nil];
    }
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
