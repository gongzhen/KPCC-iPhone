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
@end

@implementation SCPRRootViewController

#pragma mark - Accessors

@synthesize onAirLabel = _onAirLabel;
@synthesize programTitleLabel = _programTitleLabel;

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


#pragma mark - UIViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.navigationItem.title = @"KPCC";
    
    UIScrollView *scrollview = [[UIScrollView alloc] initWithFrame:self.view.frame];

    [scrollview addSubview:self.onAirLabel];
    [scrollview addSubview:self.programTitleLabel];
    
    [scrollview setContentSize:CGSizeMake(self.view.frame.size.width, self.view.frame.size.height - 60)];
    [self.view addSubview:scrollview];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    CGSize size = self.view.bounds.size;
    
    self.onAirLabel.frame = CGRectMake(20.0f, 20.0f, 90.0f, 20.f);
    self.programTitleLabel.frame = CGRectMake(120.f, 20.0f, size.width - 120.0f, 20.0f);
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
