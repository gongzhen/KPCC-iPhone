//
//  SCPRUserReportViewController.m
//  KPCC
//
//  Created by John Meeker on 4/4/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "SCPRUserReportViewController.h"
#import "SCPRRootViewController.h"
#import "AnalyticsManager.h"
#import "AudioManager.h"
#import "NetworkManager.h"

@interface SCPRUserReportViewController () <UITextViewDelegate>

@end

@implementation SCPRUserReportViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.

    [self.cancelButton setAction:@selector(hideUserReportView)];
    [self.sendReportButton addTarget:self action:@selector(sendUserReportAction) forControlEvents:UIControlEventTouchUpInside];
    
    //self.userReportDetails.delegate = self;
}

/*- (void)textViewDidBeginEditing:(UITextView *)textView {
    self.userReportDetails.text = @"";
}*/

- (void)hideUserReportView {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)sendUserReportAction {
    NSString *reportToSend = self.userReportDetails.text;
    if (![reportToSend isEqualToString:@"What's happening..."]) {
        
        long currentTimeSeconds = [[NSDate date] timeIntervalSince1970];
        
        NSString *audioPlayerStateString;
        switch ([[AudioManager shared].audioPlayer state]) {
            case STKAudioPlayerStateReady:
                audioPlayerStateString = @"ready";
                break;
                
            case STKAudioPlayerStateRunning:
                audioPlayerStateString = @"running";
                break;
                
            case STKAudioPlayerStateBuffering:
                audioPlayerStateString = @"buffering";
                break;
                
            case STKAudioPlayerStateDisposed:
                audioPlayerStateString = @"disposed";
                break;
                
            case STKAudioPlayerStateError:
                audioPlayerStateString = @"error";
                break;
                
            case STKAudioPlayerStatePaused:
                audioPlayerStateString = @"paused";
                break;
                
            case STKAudioPlayerStatePlaying:
                audioPlayerStateString = @"playing";
                break;
                
            case STKAudioPlayerStateStopped:
                audioPlayerStateString = @"stopped";
                break;
                
            default:
                audioPlayerStateString = @"";
                break;
        }
        
        
        [[AnalyticsManager shared] logEvent:@"userReportedIssue" withParameters:@{ @"UserReport" :  reportToSend,
                                                                                   @"StreamPlaying?" : [NSString stringWithFormat:@"%@", [[AudioManager shared] isStreamPlaying] == 1 ? @"YES" : @"NO"],
                                                                                   @"StreamState" : audioPlayerStateString,
                                                                                   @"NetworkInfo" : [[NetworkManager shared] networkInformation],
                                                                                   @"LastPrerollPlayerSecondsAgo" : [NSString stringWithFormat:@"%ld", currentTimeSeconds - [[AudioManager shared] lastPreRoll]]}];
        /*UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Thank you" message:@"This really helps!" delegate:self cancelButtonTitle:nil otherButtonTitles: @"OK",nil, nil];
        [alert show];*/
        [self hideUserReportView];
    } else {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Access Denied" message:@"Come on, be original!" delegate:self cancelButtonTitle:nil otherButtonTitles: @"OK",nil, nil];
        [alert show];
    }
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
