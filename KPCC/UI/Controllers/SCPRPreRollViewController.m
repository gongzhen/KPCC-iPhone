//
//  SCPRPreRollViewController.m
//  KPCC
//
//  Created by John Meeker on 10/14/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "SCPRPreRollViewController.h"
#import <POP/POP.h>
#import "UIImageView+AFNetworking.h"
#import "AudioManager.h"
#import "NetworkManager.h"
#import "SCPRSpinnerViewController.h"
#import "UXmanager.h"
#import "SessionManager.h"

#define kDefaultAdPresentationTime 10.0

@interface SCPRPreRollViewController ()
{
    float currentPresentedDuration;
    BOOL impressionSent;
}

@property IBOutlet UIProgressView *adProgressView;

@property (nonatomic) NSTimer *timer;


@end

@implementation SCPRPreRollViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.curtainView.backgroundColor = [UIColor kpccAsphaltColor];
    self.adImageView.backgroundColor = [UIColor clearColor];
    self.adImageView.userInteractionEnabled = YES;
    self.adTapper = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                            action:@selector(openClickThroughUrl)];
    [self.view layoutIfNeeded];
    
    // Do any additional setup after loading the view from its nib.

}


# pragma mark - Presentations
- (void)primeUI:(CompletionBlock)completed {
    [UIView animateWithDuration:0.3f animations:^{
        CGRect frame = CGRectMake(self.view.frame.origin.x, 0, self.view.frame.size.width, self.view.frame.size.height);
        self.view.frame = frame;
        self.view.alpha = 1.0f;
    } completion:^(BOOL finished) {
        completed();
    }];
}

- (void)showPreRollWithAnimation:(BOOL)animated completion:(void (^)(BOOL done))completion {
    [SCPRSpinnerViewController spinInCenterOfView:self.curtainView appeared:^{
        if (self.tritonAd) {

            [[AudioManager shared] setCurrentAudioMode:AudioModePreroll];

            if (animated) {
                // Set image for ad
                NSURL *imageUrl = [NSURL URLWithString:self.tritonAd.imageCreativeUrl];
                NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:imageUrl];
                UIImageView *iv = self.adImageView;
                [iv setImageWithURLRequest:request placeholderImage:nil success:^(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image) {
                    self.adImageView.image = image;
                    CATransition *transition = [CATransition animation];
                    transition.duration = 0.25;
                    transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
                    transition.type = kCATransitionFade;

                    [self.adImageView.layer addAnimation:transition
                                                   forKey:nil];

                    dispatch_async(dispatch_get_main_queue(), ^{
                        if ( self.tritonAd.clickthroughUrl ) {
                            [self.adImageView addGestureRecognizer:self.adTapper];
                        }

                    });
                } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error) {
                    completion(false);
                }];

                // Build preroll audio player
                self.prerollPlayer = [AVPlayer playerWithURL:[NSURL URLWithString:self.tritonAd.audioCreativeUrl]];

                __block SCPRPreRollViewController *weakself_ = self;
                self.timeObserver = [self.prerollPlayer addPeriodicTimeObserverForInterval:CMTimeMake(1, 10)
                                                                                     queue:nil
                                                                                usingBlock:^(CMTime time) {
                                                                                    [weakself_ setAdProgress];
                                                                                }];

                self.observer = [[AVObserver alloc] initWithPlayer:self.prerollPlayer callback:^(enum Statuses status, NSString* msg, id obj) {
                    switch (status) {
                        case StatusesPlaying:
                            [[[AudioManager shared] status] setStatus:AudioStatusPlaying];
                            break;
                        case StatusesPaused:
                            [[[AudioManager shared] status] setStatus:AudioStatusPaused];
                            break;
                        case StatusesItemEnded:
                            [self preRollCompleted];
                            break;

                        case StatusesPlayerFailed:
                        case StatusesItemFailed:
                            // FIXME: Need to account for potential failure here
                            break;
                        default:

                            break;
                    }
                }];

                [SCPRSpinnerViewController finishSpinning];

                impressionSent = NO;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate preRollStartedPlaying];
                    completion(YES);
                });
            } else {
                 completion(YES);
            }
        }
    }];
}

- (void)preRollCompleted {

    [self.prerollPlayer removeTimeObserver:self.timeObserver];
    self.timeObserver = nil;
    [self.prerollPlayer cancelPendingPrerolls];
    
    [[SessionManager shared] resetCache];

    [self.observer stop];

    self.observer = nil;
    self.prerollPlayer = nil;

    [[AudioManager shared] setCurrentAudioMode:AudioModeNeutral];
    [[UXmanager shared] showMenuButton];
    
    [self dismissTapped:nil];
    
}


# pragma mark - Actions
- (void)openClickThroughUrl {
    NSString *url = self.tritonAd.clickthroughUrl;
    if ( url && !SEQ(@"",url) ) {
        [[SessionManager shared] setUserLeavingForClickthrough:YES];
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
    }
}

- (IBAction)dismissTapped:(id)sender {
    if (self.tritonAd && !impressionSent) {
        impressionSent = YES;
        [[NetworkManager shared] sendImpressionToTriton:self.tritonAd.impressionUrl completion:^(BOOL success) {
            if (success) NSLog(@"impression sent successfully");
        }];
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
        if ([self.delegate respondsToSelector:@selector(preRollCompleted)]) {
            [self.delegate preRollCompleted];
        }
        
    }];
}

- (void)setAdProgress {
    if (self.tritonAd && self.prerollPlayer.rate > 0.0 ) {
        currentPresentedDuration = CMTimeGetSeconds(self.prerollPlayer.currentItem.currentTime);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.adProgressView setProgress:(currentPresentedDuration/[self.tritonAd.audioCreativeDuration floatValue]) animated:YES];
        });
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
