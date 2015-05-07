//
//  SCPRScheduleHeaderViewController.m
//  KPCC
//
//  Created by Ben Hochberg on 5/6/15.
//  Copyright (c) 2015 SCPR. All rights reserved.
//

#import "SCPRScheduleHeaderViewController.h"
#import "UILabel+Additions.h"
#import "UIColor+UICustom.h"

@interface SCPRScheduleHeaderViewController ()

@end

@implementation SCPRScheduleHeaderViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)setupWithText:(NSString *)text {
    [self.captionLabel proMediumFontize];
    self.captionLabel.textColor = [UIColor kpccOrangeColor];
    
    self.topLine.backgroundColor = [UIColor kpccSubtleGrayColor];
    self.bottomLine.backgroundColor = [UIColor kpccSubtleGrayColor];
    
    self.captionLabel.text = text;
    self.view.backgroundColor = [[UIColor virtualBlackColor] translucify:0.5f];
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
