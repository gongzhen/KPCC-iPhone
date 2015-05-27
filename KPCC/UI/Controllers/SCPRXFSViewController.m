//
//  SCPRXFSViewController.m
//  KPCC
//
//  Created by Ben Hochberg on 5/27/15.
//  Copyright (c) 2015 SCPR. All rights reserved.
//

#import "SCPRXFSViewController.h"
#import "UIColor+UICustom.h"
#import "SCPRCornerMaskView.h"
#import "SCPRAppDelegate.h"
#import "Utils.h"
#import "SCPRNavigationController.h"

@interface SCPRXFSViewController ()

@end

@implementation SCPRXFSViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.deployButton.backgroundColor = [UIColor clearColor];
    self.view.clipsToBounds = YES;
    self.view.backgroundColor = [UIColor clearColor];
    
    [self.leftButton addTarget:self
                        action:@selector(leftButtonTapped)
              forControlEvents:UIControlEventTouchUpInside];
    
    // Do any additional setup after loading the view from its nib.
}

- (void)applyHeight:(CGFloat)height {
    [UIView animateWithDuration:0.25f animations:^{
        self.view.frame = CGRectMake(self.view.frame.origin.x,
                                     self.view.frame.origin.y,
                                     self.view.frame.size.width,
                                     height);
    }];
}

- (void)leftButtonTapped {
    [[[Utils del] masterNavigationController] leftButtonTapped];
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
