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
    [self.view layoutIfNeeded];
    
    // Do any additional setup after loading the view from its nib.

}


# pragma mark - Presentations
- (void)primeUI:(CompletionBlock)completed {
    [UIView animateWithDuration:0.3f animations:^{
        CGRect frame = CGRectMake(self.view.frame.origin.x, 0, self.view.frame.size.width, self.view.frame.size.height);
        self.view.frame = frame;
        self.view.alpha = 1.0;
    } completion:^(BOOL finished) {
        completed();
    }];
}

- (void)showPreRollWithAnimation:(BOOL)animated completion:(void (^)(BOOL done))completion {
    [SCPRSpinnerViewController spinInCenterOfView:self.curtainView
                                         appeared:^{
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
                                                         
                                                     } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error) {
                                                         completion(false);
                                                     }];
                                                     
                                                     
                                                     __block SCPRPreRollViewController *weakself_ = self;
                                                     self.prerollPlayer = [AVPlayer playerWithURL:[NSURL URLWithString:self.tritonAd.audioCreativeUrl]];
                                                     self.timeObserver = [self.prerollPlayer addPeriodicTimeObserverForInterval:CMTimeMake(1, 10)
                                                                                                                          queue:nil
                                                                                                                     usingBlock:^(CMTime time) {
                                                                                                                         [weakself_ setAdProgress];
                                                                                                                     }];
                                                     
                                                     [[NSNotificationCenter defaultCenter] addObserver:self
                                                                                              selector:@selector(preRollCompleted)
                                                                                                  name:AVPlayerItemDidPlayToEndTimeNotification
                                                                                                object:nil];
                                                     
                                                     
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
    self.prerollPlayer = nil;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AVPlayerItemDidPlayToEndTimeNotification
                                                  object:nil];
    
    [[AudioManager shared] setCurrentAudioMode:AudioModeNeutral];
    [[UXmanager shared] showMenuButton];
    
    [self dismissTapped:nil];
    
}


# pragma mark - Actions

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
