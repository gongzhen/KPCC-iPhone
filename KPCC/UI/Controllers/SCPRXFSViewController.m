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
#import "pop.h"
#import "SCPRMenuCell.h"

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
    
    [self.deployButton addTarget:self
                          action:@selector(toggleDropdown)
                forControlEvents:UIControlEventTouchUpInside];
    
    
    // Do any additional setup after loading the view from its nib.
}

- (void)toggleDropdown {
    [self controlVisibility:!self.deployed];
}

- (void)applyHeight:(CGFloat)height {
    [UIView animateWithDuration:0.35f animations:^{
        self.view.frame = CGRectMake(self.view.frame.origin.x,
                                     self.view.frame.origin.y,
                                     self.view.frame.size.width,
                                     height);
    }];
}

- (void)openDropdown {
    
    [self controlVisibility:YES];
    
}

- (void)closeDropdown {
    
    [self controlVisibility:NO];
    
}

- (void)controlVisibility:(BOOL)visible {
    if ( self.deployed == visible ) return;
    
    NSNumber *x = visible ? @([Utils degreesToRadians:180.0f]) : @(0.0f);
    POPSpringAnimation *rotation = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerRotation];
    [rotation setToValue:x];
    [rotation setSpringBounciness:1.65f];
    [rotation setSpringSpeed:.64f];
    
    [self.chevronImage.layer pop_addAnimation:rotation forKey:@"rotate"];
    self.deployed = visible;
    
    NSString *message = visible ? @"xfs-shown" : @"xfs-hidden";
    
    [[NSNotificationCenter defaultCenter] postNotificationName:message
                                                        object:nil];
    
#ifdef OVERLAY_XFS_INTERFACE
    CGFloat h = !visible ? [[[Utils del] masterNavigationController] navigationBar].frame.size.height+20.0f : [[Utils del] window].frame.size.height;
    [self applyHeight:h];
#endif
    
}

- (void)leftButtonTapped {
    [[[Utils del] masterNavigationController] leftButtonTapped];
}

#pragma mark - UITableVIew
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 3;
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
