//
//  SCPRBalloonViewController.m
//  KPCC
//
//  Created by Ben Hochberg on 6/1/15.
//  Copyright (c) 2015 SCPR. All rights reserved.
//

#import "SCPRBalloonViewController.h"
#import "DesignManager.h"
#import "UILabel+Additions.h"
#import "UIColor+UICustom.h"

@interface SCPRBalloonViewController ()

@end

@implementation SCPRBalloonViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)primeWithText:(NSString *)text {
    [self.textCaptionLabel setText:text];
    [self prime];
}

- (void)prime {
    [self.textCaptionLabel proLightFontize];
    [self.triangleView setShadeColor:[UIColor kpccBalloonBlueColor]];
    self.view.backgroundColor = [UIColor clearColor];
    self.textContainerView.backgroundColor = [UIColor kpccBalloonBlueColor];
    
    [self.closeButton addTarget:self
                         action:@selector(closeSelf)
               forControlEvents:UIControlEventTouchUpInside];
}

- (void)closeSelf {
    [UIView animateWithDuration:0.15f animations:^{
        self.view.alpha = 0.0f;
    } completion:^(BOOL finished) {
        //[self.view removeFromSuperview];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"balloon-dismissed"
                                                            object:nil
                                                          userInfo:@{ @"balloon" : self }];
    }];
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
