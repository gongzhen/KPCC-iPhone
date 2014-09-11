//
//  SCPRNavigationController.m
//  KPCC
//
//  Created by John Meeker on 9/4/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "SCPRNavigationController.h"
#import "SCPRMenuButton.h"
#import <POP/POP.h>

@interface SCPRNavigationController ()

@end

@implementation SCPRNavigationController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.

    pulldownMenu = [[PulldownMenu alloc] initWithNavigationController:self];
    [self.view insertSubview:pulldownMenu belowSubview:self.navigationBar];

    [pulldownMenu insertButton:@"Menu Item 1"];
    [pulldownMenu insertButton:@"Menu Item 2"];
    [pulldownMenu insertButton:@"Menu Item 3"];

    pulldownMenu.delegate = self;
    [pulldownMenu loadMenu];

    // "Global" menu button to be used across all pushed view controllers.
    menuButton = [SCPRMenuButton buttonWithOrigin:CGPointMake(10.f, 10.f)];
    menuButton.delegate = self;
//    [menuButton addTarget:self action:@selector(menuPressed:) forControlEvents:UIControlEventTouchUpInside];

    for (UIViewController* viewController in self.viewControllers){
        // You need to do this because the push is not called if you created this controller as part of the storyboard
        NSLog(@"adding button to vc : %@", viewController.title);
        [self addButton:viewController.navigationItem];
    }
}

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated{
    [super pushViewController:viewController animated:animated];
    if (viewController.navigationItem.leftBarButtonItem == nil){
        viewController.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:menuButton];
    }

    //[pulldownMenu animateDropDown];
    [menuButton animateToBack];
}

- (void)addButton:(UINavigationItem *)item{
    if (item.leftBarButtonItem == nil){
        item.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:menuButton];
    }
}

- (void)menuPressed:(id)sender {
    [pulldownMenu animateDropDown];
}


# pragma mark - PulldownMenuDelegate

- (void)menuItemSelected:(NSIndexPath *)indexPath {
    NSLog(@"%ld",(long)indexPath.item);

    // Push test vc.
    UIViewController *vc = [[UIViewController alloc] init];
    vc.view.backgroundColor = [UIColor blackColor];
    vc.view.alpha = 0.7;
    [self pushViewController:vc animated:YES];
}

- (void)pullDownAnimated:(BOOL)open {
    if (open) {
        NSLog(@"Pull down menu open!");
        [[NSNotificationCenter defaultCenter] postNotificationName:@"pull_down_menu_opened"
                                                            object:nil];
    } else {
        NSLog(@"Pull down menu closed!");
        [[NSNotificationCenter defaultCenter] postNotificationName:@"pull_down_menu_closed"
                                                            object:nil];
    }
}


# pragma mark - MenuButtonDelegate
- (void)backPressed {
    [self popViewControllerAnimated:YES];
    [menuButton animateToClose];
}

- (void)menuPressed {
    [pulldownMenu animateDropDown];
}

- (void)closePressed {
    [pulldownMenu animateDropDown];
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
