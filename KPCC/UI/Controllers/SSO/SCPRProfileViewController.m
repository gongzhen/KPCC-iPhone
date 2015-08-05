//
//  SCPRProfileViewController.m
//  KPCC
//
//  Created by Ben Hochberg on 8/4/15.
//  Copyright (c) 2015 SCPR. All rights reserved.
//

#import "SCPRProfileViewController.h"
#import <Lock/Lock.h>
#import "UXmanager.h"
#import "UIImageView+AFNetworking.h"

@interface SCPRProfileViewController ()

@end

@implementation SCPRProfileViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (void)setup {
    
    A0UserProfile *profile = [[UXmanager shared] a0profile];
    self.userNameLabel.text = [profile name];
    [self.avatarImage setImageWithURL:[profile picture]];
    
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
