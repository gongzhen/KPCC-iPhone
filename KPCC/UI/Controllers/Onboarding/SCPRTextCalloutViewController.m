//
//  SCPRTextCalloutViewController.m
//  KPCC
//
//  Created by Ben Hochberg on 11/19/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "SCPRTextCalloutViewController.h"
#import "UILabel+Additions.h"
#import "UIColor+UICustom.h"

@interface SCPRTextCalloutViewController ()

@end

@implementation SCPRTextCalloutViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.bodyTextLabel proBookFontize];
    self.bodyContainerView.backgroundColor = [UIColor kpccPeriwinkleColor];
    self.trianglePointerView.shadeColor = [UIColor kpccPeriwinkleColor];
    [self.trianglePointerView setNeedsDisplay];
    self.trianglePointerView.backgroundColor = [UIColor clearColor];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)slidePointer:(CGFloat)xCoordinate {
    [self.pointerXPosition setConstant:xCoordinate];
    
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
