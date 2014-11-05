//
//  SCPRCloakViewController.m
//  KPCC
//
//  Created by Ben Hochberg on 11/4/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "SCPRCloakViewController.h"
#import "Utils.h"
#import "SCPRSpinnerViewController.h"
#import "SCPRAppDelegate.h"

@interface SCPRCloakViewController ()

@end

@implementation SCPRCloakViewController

+ (SCPRCloakViewController*)o {
    static SCPRCloakViewController *cloak = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cloak = [[SCPRCloakViewController alloc] init];
    });
    return cloak;
}

+ (void)cloakWithCustomCenteredView:(UIView *)customView useSpinner:(BOOL)useSpinner cloakAppeared:(CompletionBlock)cloakAppeared  {
    
    SCPRCloakViewController *cloak = [SCPRCloakViewController o];
    if ( [cloak cloaked] ) {
        return;
    }
    cloak.view.backgroundColor = [[UIColor virtualBlackColor] translucify:0.75];
    
    SCPRAppDelegate *del = (SCPRAppDelegate*)[[UIApplication sharedApplication] delegate];
    UIWindow *window = [del window];
    
    cloak.view.frame = CGRectMake(0.0,0.0,
                                  window.frame.size.width,
                                  window.frame.size.height);
    cloak.view.alpha = 0.0;
    
    BOOL spinner = useSpinner;
    if ( customView ) {
        spinner = NO;
        customView.center = CGPointMake(cloak.view.frame.size.width/2.0,
                                        cloak.view.frame.size.height/2.0);
        [cloak.view addSubview:customView];
    }
    
    [window addSubview:cloak.view];
    [UIView animateWithDuration:0.33 animations:^{
        [cloak.view setAlpha:1.0];
        if ( useSpinner ) {
            [SCPRSpinnerViewController spinInCenterOfViewController:cloak appeared:^{
                
            }];
        }
    } completion:^(BOOL finished) {
        cloak.cloaked = YES;
        if ( cloakAppeared ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                cloakAppeared();
            });
        }
    }];
    
}

+ (void)cloakWithCustomCenteredView:(UIView *)customView cloakAppeared:(CompletionBlock)cloakAppeared {
    [SCPRCloakViewController cloakWithCustomCenteredView:customView
                                              useSpinner:NO
                                           cloakAppeared:cloakAppeared];
}

+ (void)uncloak {
    SCPRCloakViewController *cloak = [SCPRCloakViewController o];
    if ( ![cloak cloaked] ) {
        return;
    }
    
    [UIView animateWithDuration:0.33 animations:^{
        [cloak.view setAlpha:0.0];
        [SCPRSpinnerViewController finishSpinning];
    } completion:^(BOOL finished) {
        [cloak.view removeFromSuperview];
        cloak.cloaked = NO;
    }];
}

+ (BOOL)cloakInUse {
    SCPRCloakViewController *cloak = [SCPRCloakViewController o];
    return [cloak cloaked];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
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
