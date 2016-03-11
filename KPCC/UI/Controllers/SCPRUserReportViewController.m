//
//  SCPRUserReportViewController.m
//  KPCC
//
//  Created by John Meeker on 4/4/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "SCPRUserReportViewController.h"
//#import "SCPRRootViewController.h"
#import "AnalyticsManager.h"
#import "AudioManager.h"
#import "NetworkManager.h"

@interface SCPRUserReportViewController () <UITextViewDelegate>

@end

@implementation SCPRUserReportViewController

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil{
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

    /*[self.cancelButton setTitleTextAttributes:
     @{NSForegroundColorAttributeName:[UIColor whiteColor],
       NSFontAttributeName:[UIFont fontWithName:@"HelveticaNeue-Light" size:16.0f]}
                                     forState:UIControlStateNormal];*/

    self.versionNumberLabel.text = [NSString stringWithFormat:@"%@",[[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"]];

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
        
//        long currentTimeSeconds = [[NSDate date] timeIntervalSince1970];

        // TODO: more descriptive logging on state of AVPlayer
//        NSString *audioPlayerStateString = [[AudioManager shared] isStreamPlaying] ? @"playing" : @"not playing";

        /*[[AnalyticsManager shared] logEvent:@"userReportedIssue" withParameters:@{ @"UserReport" :  reportToSend,
                                                                                   @"StreamPlaying?" : [NSString stringWithFormat:@"%@", [[AudioManager shared] isStreamPlaying] == 1 ? @"YES" : @"NO"],
                                                                                   @"StreamState" : audioPlayerStateString,
                                                                                   @"NetworkInfo" : [[NetworkManager shared] networkInformation],
                                                                                   @"LastPrerollPlayedSecondsAgo" : [NSString stringWithFormat:@"%ld", currentTimeSeconds - [[AudioManager shared] lastPreRoll]]}];*/
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
