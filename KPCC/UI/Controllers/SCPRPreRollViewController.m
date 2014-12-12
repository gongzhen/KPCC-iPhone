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
    // Do any additional setup after loading the view from its nib.

}


# pragma mark - Presentations

- (void)showPreRollWithAnimation:(BOOL)animated completion:(void (^)(BOOL done))completion {
    if (self.tritonAd) {

        // Set image for ad
        NSURL *imageUrl = [NSURL URLWithString:self.tritonAd.imageCreativeUrl];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:imageUrl];
        UIImageView *iv = self.adImageView;
        [iv setImageWithURLRequest:request placeholderImage:nil success:^(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image) {
            self.adImageView.image = image;
        } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error) {
            completion(false);
        }];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(preRollCompleted)
                                                     name:AVPlayerItemDidPlayToEndTimeNotification
                                                   object:nil];
        
        // Play audio for ad
        [[AudioManager shared] playAudioWithURL:self.tritonAd.audioCreativeUrl];
        
        impressionSent = NO;
    }
    
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

- (void)preRollCompleted {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AVPlayerItemDidPlayToEndTimeNotification
                                                  object:nil];
    [self.delegate preRollCompleted];
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
    if (self.tritonAd && [[AudioManager shared] isStreamPlaying]) {
        currentPresentedDuration = currentPresentedDuration + 0.01;
        
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
