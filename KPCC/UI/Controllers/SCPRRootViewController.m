//
//  SCPRRootViewController.m
//  KPCC
//
//  Created by John Meeker on 4/1/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "SCPRRootViewController.h"
#import "SCPRUserReportViewController.h"

@interface SCPRRootViewController () <UIScrollViewDelegate, ContentProcessor>
-(void) setupTimer;
@property (nonatomic) UILabel *onAirLabel;
@property (nonatomic) UILabel *programTitleLabel;
@property (nonatomic) UIButton *actionButton;
@property (nonatomic) UIView *horizontalDividerView;
@property (nonatomic) UIView *audioMeter;
@property (nonatomic) UILabel *streamerStatusTitleLabel;
@property (nonatomic) UILabel *streamerStatusLabel;
@property (nonatomic) UIButton *userReportButton;
@end

@implementation SCPRRootViewController

#pragma mark - Accessors

@synthesize onAirLabel = _onAirLabel;
@synthesize programTitleLabel = _programTitleLabel;
@synthesize actionButton = _actionButton;
@synthesize horizontalDividerView = _horizontalDividerView;
@synthesize audioMeter = _audioMeter;
@synthesize streamerStatusTitleLabel = _streamerStatusTitleLabel;
@synthesize streamerStatusLabel = _streamerStatusLabel;
@synthesize userReportButton = _userReportButton;

- (UILabel *)onAirLabel {
    if (!_onAirLabel) {
        _onAirLabel = [[UILabel alloc] init];
        _onAirLabel.textColor = [UIColor darkGrayColor];
        _onAirLabel.text = @"On air now:";
    }
    return _onAirLabel;
}

- (UILabel *)programTitleLabel {
    if (!_programTitleLabel) {
        _programTitleLabel = [[UILabel alloc] init];
        _programTitleLabel.textColor = [UIColor colorWithRed:71.0f/255.0f green:111.0f/255.0f blue:192.0f/255.0f alpha:1.0f];
    }
    return _programTitleLabel;
}

- (UIButton *)actionButton {
    if (!_actionButton) {
        _actionButton = [[UIButton alloc] init];
        [_actionButton setImage:[UIImage imageNamed:@"playButton"] forState:UIControlStateNormal];
        [[_actionButton imageView] setContentMode:UIViewContentModeCenter];
        [_actionButton addTarget:self action:@selector(playOrPauseTapped) forControlEvents:UIControlEventTouchUpInside];
    }
    return _actionButton;
}

- (UIView *)horizontalDividerView {
    if (!_horizontalDividerView) {
        _horizontalDividerView = [[UIView alloc] init];
        _horizontalDividerView.backgroundColor = [UIColor lightGrayColor];
    }
    return _horizontalDividerView;
}

- (UIView *)audioMeter {
    if (!_audioMeter) {
        _audioMeter = [[UIView alloc] init];
        _audioMeter.backgroundColor = [UIColor colorWithRed:9.0f/255.0f green:185.0f/255.0f blue:243.0f alpha:0.8f];
    }
    return _audioMeter;
}

- (UILabel *)streamerStatusTitleLabel {
    if (!_streamerStatusTitleLabel) {
        _streamerStatusTitleLabel = [[UILabel alloc] init];
        _streamerStatusTitleLabel.textColor = [UIColor lightGrayColor];
        _streamerStatusTitleLabel.font = [_streamerStatusTitleLabel.font fontWithSize:15.0f];
        _streamerStatusTitleLabel.text = @"Streamer Status:";
    }
    return _streamerStatusTitleLabel;
}

- (UILabel *)streamerStatusLabel {
    if (!_streamerStatusLabel) {
        _streamerStatusLabel = [[UILabel alloc] init];
        _streamerStatusLabel.textColor = [UIColor lightGrayColor];
        _streamerStatusLabel.font = [_streamerStatusLabel.font fontWithSize:15.0f];
        [_streamerStatusLabel setTextAlignment:NSTextAlignmentCenter];
    }
    return _streamerStatusLabel;
}

- (UIButton *)userReportButton {
    if (!_userReportButton) {
        _userReportButton = [[UIButton alloc] init];
        [_userReportButton setTitle:@"Report something weird!" forState:UIControlStateNormal];
        [_userReportButton setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
        [_userReportButton setTitleColor:[UIColor darkGrayColor] forState:UIControlStateHighlighted];
        [_userReportButton addTarget:self action:@selector(userReportTapped) forControlEvents:UIControlEventTouchUpInside];
    }
    return _userReportButton;
}

#pragma mark - UIViewController

// Allows for interaction with system audio controls.
- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (void)remoteControlReceivedWithEvent:(UIEvent *)event {
    // Handle remote audio control events.
    if (event.type == UIEventTypeRemoteControl) {
        if (event.subtype == UIEventSubtypeRemoteControlPlay) {
            [self playStream];
        } else if (event.subtype == UIEventSubtypeRemoteControlPause) {
            [self stopStream];
        } else if (event.subtype == UIEventSubtypeRemoteControlTogglePlayPause) {
            [self stopStream];
        }
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.navigationItem.title = @"KPCC";

    UIScrollView *scrollview = [[UIScrollView alloc] initWithFrame:self.view.frame];
    [scrollview addSubview:self.onAirLabel];
    [scrollview addSubview:self.programTitleLabel];
    [scrollview addSubview:self.actionButton];
    [scrollview addSubview:self.horizontalDividerView];
    [scrollview addSubview:self.audioMeter];
    [scrollview addSubview:self.streamerStatusTitleLabel];
    [scrollview addSubview:self.streamerStatusLabel];
    [scrollview addSubview:self.userReportButton];

    [scrollview setContentSize:CGSizeMake(self.view.frame.size.width, self.view.frame.size.height - 60)];
    [self.view addSubview:scrollview];
    
    // Fetch program info and update audio control state.
    [self updateDataForUI];

    // Once the view has loaded then we can register to begin recieving system audio controls.
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    [self becomeFirstResponder];
    
    // Observe when the application becomes active again, and update UI if need-be.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateDataForUI) name:UIApplicationWillEnterForegroundNotification object:nil];

    [self setupTimer];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    CGSize size = self.view.bounds.size;
    
    self.onAirLabel.frame = CGRectMake(20.0f, 20.0f, 90.0f, 20.f);
    self.programTitleLabel.frame = CGRectMake(120.f, 20.0f, size.width - 120.0f, 20.0f);
    self.actionButton.frame = CGRectMake(size.width / 2.0f - 30.0f, size.height / 2.0f - 100.0f, 60.0f, 60.0f);
    self.horizontalDividerView.frame = CGRectMake(10.0f, size.height/ 2.0f + 80.0f, size.width - 10.0f, 1.0f);
    self.audioMeter.frame = CGRectMake(size.width - 50.0f, self.horizontalDividerView.frame.origin.y - 240.0f, 40.0f, 240.0f);
    self.streamerStatusTitleLabel.frame = CGRectMake(40.0f, self.horizontalDividerView.frame.origin.y + 20.0f, 130.0f, 20.0f);
    self.streamerStatusLabel.frame = CGRectMake(180.0f, self.horizontalDividerView.frame.origin.y + 20.0f, size.width - 200.0f, 20.0f);
    self.userReportButton.frame = CGRectMake(0.0f, self.horizontalDividerView.frame.origin.y + 60.0f, size.width, 20.0f);
}

- (void)updateDataForUI {
    [[NetworkManager shared] fetchProgramInformationFor:[NSDate date] display:self];
    
    if ([[AudioManager shared] isStreamPlaying]) {
        [self.actionButton setImage:[UIImage imageNamed:@"pauseButton"] forState:UIControlStateHighlighted];
        [self.actionButton setImage:[UIImage imageNamed:@"pauseButton"] forState:UIControlStateNormal];
    } else {
        [self.actionButton setImage:[UIImage imageNamed:@"playButton"] forState:UIControlStateHighlighted];
        [self.actionButton setImage:[UIImage imageNamed:@"playButton"] forState:UIControlStateNormal];
    }
}

-(void)setupTimer {
	timer = [NSTimer timerWithTimeInterval:0.025 target:self selector:@selector(tick) userInfo:nil repeats:YES];
	[[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
}

-(void)playOrPauseTapped {
    if (![[AudioManager shared] isStreamPlaying]) {
        [self playStream];
    } else {
        [self stopStream];
    }
}

- (void)playStream {
    [[AudioManager shared] startStream];
}

- (void)stopStream {
    [[AudioManager shared] stopStream];
}

-(void) tick {
    STKAudioPlayerState stkAudioPlayerState = [[AudioManager shared] audioPlayer].state;
    NSString *audioPlayerStateString;
    
    if (stkAudioPlayerState != STKAudioPlayerStatePlaying) {
        
        if (!self.isUISetForPlaying) {
            
            [self.actionButton setImage:[UIImage imageNamed:@"playButton"] forState:UIControlStateHighlighted];
            [self.actionButton setImage:[UIImage imageNamed:@"playButton"] forState:UIControlStateNormal];
            
            [UIView animateWithDuration:0.44 animations:^{
                self.audioMeter.frame = CGRectMake(self.audioMeter.frame.origin.x, self.horizontalDividerView.frame.origin.y, self.audioMeter.frame.size.width, 0);
            } completion:nil];
            
            self.isUISetForPaused = NO;
            self.isUISetForPlaying = YES;
        }
    } else {
        
        if (!self.isUISetForPaused) {
            [self.actionButton setImage:[UIImage imageNamed:@"pauseButton"] forState:UIControlStateHighlighted];
            [self.actionButton setImage:[UIImage imageNamed:@"pauseButton"] forState:UIControlStateNormal];
            
            self.isUISetForPaused = YES;
            self.isUISetForPlaying = NO;
        }
        
        [UIView animateWithDuration:0.1 animations:^{
            CGFloat newHeight = 240 * (([[[AudioManager shared] audioPlayer] averagePowerInDecibelsForChannel:0] + 60) / 60);
            self.audioMeter.frame = CGRectMake(self.audioMeter.frame.origin.x, self.horizontalDividerView.frame.origin.y - 240.0f + newHeight, self.audioMeter.frame.size.width, 240.0f - newHeight);
        } completion:nil];
    }
    
    switch (stkAudioPlayerState) {
        case STKAudioPlayerStateReady:
            audioPlayerStateString = @"ready";
            break;
            
        case STKAudioPlayerStateRunning:
            audioPlayerStateString = @"running";
            break;
            
        case STKAudioPlayerStateBuffering:
            audioPlayerStateString = @"buffering";
            [[AudioManager shared] analyzeStreamError:audioPlayerStateString];
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
            if (!self.isUISetForPaused) {
                [self.actionButton setImage:[UIImage imageNamed:@"pauseButton"] forState:UIControlStateHighlighted];
                [self.actionButton setImage:[UIImage imageNamed:@"pauseButton"] forState:UIControlStateHighlighted];
                self.isUISetForPaused = YES;
                self.isUISetForPlaying = NO;
            }
            break;
            
        case STKAudioPlayerStateStopped:
            audioPlayerStateString = @"stopped";
            break;
            
        default:
            audioPlayerStateString = @"";
            break;
    }
    
    [self.streamerStatusLabel setText:audioPlayerStateString];
}

- (void)userReportTapped {
    NSLog(@"UserReportTapped!");

    SCPRUserReportViewController *viewController = [[SCPRUserReportViewController alloc] initWithNibName:@"SCPRUserReportViewController" bundle:nil];
    [self presentViewController:viewController animated:YES completion:nil];
}


#pragma mark - ContentProcessor

- (void)handleProcessedContent:(NSArray *)content flags:(NSDictionary *)flags {
    
    if ( [content count] == 0 ) {
        return;
    }
    
    [self.programTitleLabel setText:[[content objectAtIndex:0] objectForKey:@"title"]];
    
    NSDictionary *audioMetaData = @{ MPMediaItemPropertyArtist : @"89.3 KPCC",
                                     MPMediaItemPropertyTitle : [[content objectAtIndex:0] objectForKey:@"title"] };
    
    [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:audioMetaData];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    // End recieving events
    [[UIApplication sharedApplication] endReceivingRemoteControlEvents];
    [self resignFirstResponder];
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
