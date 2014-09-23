//
//  SCPRNavigationController.m
//  KPCC
//
//  Created by John Meeker on 9/4/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "SCPRNavigationController.h"
#import "SCPRMasterViewController.h"
#import "SCPRMenuButton.h"
#import <POP/POP.h>

@interface SCPRNavigationController ()
@property(nonatomic) BOOL menuOpen;
@end

@implementation SCPRNavigationController

- (void)viewDidLoad {
    [super viewDidLoad];

    /**
     * Lets us keep the iOS 7-style slide-over gesture when navigating back through view controllers.
     * Problems were had when using a custom bar button item.
     */
    __weak SCPRNavigationController *weakSelf = self;
    if ([self respondsToSelector:@selector(interactivePopGestureRecognizer)]) {
        self.interactivePopGestureRecognizer.delegate = weakSelf;
        self.delegate = weakSelf;
    }

    // Menu button to be used across all pushed view controllers.
    menuButton = [SCPRMenuButton buttonWithOrigin:CGPointMake(10.f, 10.f)];
    menuButton.delegate = self;

    for (UIViewController* viewController in self.viewControllers){
        NSLog(@"adding button to vc : %@", viewController.title);
        //[self addButton:viewController.navigationItem];
    }
}

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated{
    if ([self respondsToSelector:@selector(interactivePopGestureRecognizer)]) {
        self.interactivePopGestureRecognizer.enabled = NO;
    }

    [super pushViewController:viewController animated:animated];
    if (viewController.navigationItem.leftBarButtonItem == nil){
        viewController.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:menuButton];
    }

    [menuButton animateToBack];
}

- (void)addButton:(UINavigationItem *)item{
    if (item.leftBarButtonItem == nil){
        item.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:menuButton];
    }
}


#pragma mark - UINavigationControllerDelegate

- (void)navigationController:(UINavigationController *)navigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)animate {
    // Enable the gesture again once the new controller is shown
    self.interactivePopGestureRecognizer.enabled = ([self respondsToSelector:@selector(interactivePopGestureRecognizer)] && [self.viewControllers count] > 1);
}


# pragma mark - MenuButtonDelegate

- (void)backPressed {
    [self popViewControllerAnimated:YES];

    if ([self.viewControllers count] == 1) {
        [menuButton animateToMenu];
    }
}

- (void)menuPressed {
    if (self.menuOpen) {
        [pulldownMenu closeDropDown:YES];
        [[[Utils del] masterViewController] decloakForMenu:YES];
    } else {
        [[[Utils del] masterViewController] cloakForMenu:YES];
        [pulldownMenu openDropDown:YES];
    }
    self.menuOpen = !self.menuOpen;
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
