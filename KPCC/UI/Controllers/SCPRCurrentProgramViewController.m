//
//  SCPRCurrentProgramViewController.m
//  KPCC
//
//  Created by Ben Hochberg on 5/5/15.
//  Copyright (c) 2015 SCPR. All rights reserved.
//

#import "SCPRCurrentProgramViewController.h"
#import "DesignManager.h"
#import "UIColor+UICustom.h"
#import "UILabel+Additions.h"

@interface SCPRCurrentProgramViewController ()

@end

@implementation SCPRCurrentProgramViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor clearColor];
    self.avatarImageView.clipsToBounds = YES;
    self.avatarImageView.layer.cornerRadius = self.avatarImageView.frame.size.width / 2.0f;
    
    [[DesignManager shared] sculptButton:self.viewFullScheduleButton
                               withStyle:SculptingStyleClearWithBorder
                                 andText:@"View Full Schedule"];
    
    self.upNextLabel.textColor = [UIColor kpccOrangeColor];
    self.dividerViewLeft.backgroundColor = [[UIColor virtualWhiteColor] translucify:0.4f];
    self.dividerViewRight.backgroundColor = [[UIColor virtualWhiteColor] translucify:0.4f];
    
    [self.upNextLabel proMediumFontize];
    [self.programTitleLabel proLightFontize];
    
    // Do any additional setup after loading the view from its nib.
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
