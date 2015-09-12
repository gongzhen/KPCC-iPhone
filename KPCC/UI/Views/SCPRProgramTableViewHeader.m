//
//  SCPRProgramTableViewHeader.m
//  KPCC
//
//  Created by Eric Richardson on 9/11/15.
//  Copyright © 2015 SCPR. All rights reserved.
//

#import "SCPRProgramTableViewHeader.h"
#import "UILabel+Additions.h"
#import "UIColor+UICustom.h"

@implementation SCPRProgramTableViewHeader
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

@end

