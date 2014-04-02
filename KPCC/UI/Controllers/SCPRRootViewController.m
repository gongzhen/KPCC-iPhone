//
//  SCPRRootViewController.m
//  KPCC
//
//  Created by John Meeker on 4/1/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "SCPRRootViewController.h"

@interface SCPRRootViewController () <UIScrollViewDelegate>
@property (nonatomic) UILabel *onAirLabel;
@property (nonatomic) UILabel *programTitleLabel;
@property (nonatomic) UIButton *actionButton;
@property (nonatomic) UIView *horizontalDividerView;
@property (nonatomic) UIView *audioMeter;
@property (nonatomic) UILabel *streamerStatusLabel;
@end

@implementation SCPRRootViewController

#pragma mark - Accessors

@synthesize onAirLabel = _onAirLabel;
@synthesize programTitleLabel = _programTitleLabel;
@synthesize actionButton = _actionButton;
@synthesize horizontalDividerView = _horizontalDividerView;
@synthesize audioMeter = _audioMeter;
@synthesize streamerStatusLabel = _streamerStatusLabel;

- (UILabel *)onAirLabel {
    if (!_onAirLabel) {
        _onAirLabel = [[UILabel alloc] init];
        _onAirLabel.textColor = [UIColor darkGrayColor];
        _onAirLabel.text = @"On air now:";
        //[_onAirLabel sizeToFit];
    }
    return _onAirLabel;
}

- (UILabel *)programTitleLabel {
    if (!_programTitleLabel) {
        _programTitleLabel = [[UILabel alloc] init];
        _programTitleLabel.textColor = [UIColor colorWithRed:71.0f/255.0f green:111.0f/255.0f blue:192.0f/255.0f alpha:1.0f];
        _programTitleLabel.text = @"All Things Considered";
        //[_programTitleLabel sizeToFit];
    }
    return _programTitleLabel;
}

- (UIButton *)actionButton {
    if (!_actionButton) {
        _actionButton = [[UIButton alloc] init];
        [_actionButton setBackgroundImage:[UIImage imageNamed:@"playButton"] forState:UIControlStateNormal];
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

- (UILabel *)streamerStatusLabel {
    if (!_streamerStatusLabel) {
        _streamerStatusLabel = [[UILabel alloc] init];
        _streamerStatusLabel.textColor = [UIColor lightGrayColor];
        _streamerStatusLabel.font = [_streamerStatusLabel.font fontWithSize:15.0f];
        _streamerStatusLabel.text = @"Streamer Status:";
    }
    return _streamerStatusLabel;
}


#pragma mark - UIViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.navigationItem.title = @"KPCC";
    [self.navigationController.navigationBar setTitleTextAttributes:
     [NSDictionary dictionaryWithObjectsAndKeys:
      [UIFont fontWithName:@"HelveticaNeue-Light" size:20.0f],
      NSFontAttributeName, nil]];
    
    UIScrollView *scrollview = [[UIScrollView alloc] initWithFrame:self.view.frame];

    [scrollview addSubview:self.onAirLabel];
    [scrollview addSubview:self.programTitleLabel];
    [scrollview addSubview:self.actionButton];
    [scrollview addSubview:self.horizontalDividerView];
    [scrollview addSubview:self.audioMeter];
    [scrollview addSubview:self.streamerStatusLabel];
    
    [scrollview setContentSize:CGSizeMake(self.view.frame.size.width, self.view.frame.size.height - 60)];
    [self.view addSubview:scrollview];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    CGSize size = self.view.bounds.size;
    
    self.onAirLabel.frame = CGRectMake(20.0f, 20.0f, 90.0f, 20.f);
    self.programTitleLabel.frame = CGRectMake(120.f, 20.0f, size.width - 120.0f, 20.0f);
    self.actionButton.frame = CGRectMake(size.width / 2.0f - 10.0f, size.height / 2.0f - 100.0f, 30.0f, 34.0f);
    self.horizontalDividerView.frame = CGRectMake(10.0f, size.height/ 2.0f + 80.0f, size.width - 10.0f, 1.0f);
    self.audioMeter.frame = CGRectMake(size.width - 50.0f, self.horizontalDividerView.frame.origin.y - 240.0f, 40.0f, 240.0f);
    self.streamerStatusLabel.frame = CGRectMake(40.0f, self.horizontalDividerView.frame.origin.y + 20.0f, 130.0f, 20.0f);
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
