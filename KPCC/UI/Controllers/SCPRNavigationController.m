//
//  SCPRNavigationController.m
//  KPCC
//
//  Created by John Meeker on 9/4/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "SCPRNavigationController.h"
#import "SCPRMasterViewController.h"
#import "SCPRProgramsListViewController.h"
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

    // Add observers for pull down menu open/close to update button state.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleMenuOpened:)
                                                 name:@"pull_down_menu_opened"
                                               object:nil];

     [[NSNotificationCenter defaultCenter] addObserver:self
                                              selector:@selector(handleMenuClosed:)
                                                  name:@"pull_down_menu_closed"
                                                object:nil];

    for (UIViewController* viewController in self.viewControllers){
        [self addButton:viewController.navigationItem];
    }
}

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated{
    if ([self respondsToSelector:@selector(interactivePopGestureRecognizer)]) {
        self.interactivePopGestureRecognizer.enabled = NO;
    }

    [super pushViewController:viewController animated:animated];
    [self addButton:viewController.navigationItem];
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

- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated {
    if (viewController == [[Utils del] masterViewController]) {
        if ([[[Utils del] masterViewController] menuOpen]) {
            [menuButton animateToClose];
        } else {
            [menuButton animateToMenu];
        }
    }
}


#pragma mark - Navigation Animation Delegate

- (id<UIViewControllerAnimatedTransitioning>)navigationController:(UINavigationController *)navigationController
                                  animationControllerForOperation:(UINavigationControllerOperation)operation
                                               fromViewController:(UIViewController *)fromVC
                                                 toViewController:(UIViewController *)toVC
{

    if ([toVC class] == [SCPRProgramsListViewController class] && [fromVC class] == [SCPRMasterViewController class]) {
        SCPRSlideInTransition *slideInTransition = [SCPRSlideInTransition new];
        slideInTransition.direction = @"rightToLeft";
        return slideInTransition;
    }

    return nil;
}


# pragma mark - MenuButtonDelegate

- (void)backPressed {
    [self popViewControllerAnimated:YES];
}

- (void)menuPressed {
    if ([[[Utils del] masterViewController] menuOpen]) {
        [[[Utils del] masterViewController] decloakForMenu:YES];
        [menuButton animateToMenu];
    } else {
        [[[Utils del] masterViewController] cloakForMenu:YES];
        [menuButton animateToClose];
    }
}


# pragma mark - NSNotification

- (void)handleMenuOpened:(NSNotification *)notification {

}

- (void)handleMenuClosed:(NSNotification *)notification {
    // Handle when we close menu programatically, and update
    // menu button to proper state.
    if (![menuButton showBackArrow]) {
        if (![menuButton showMenu]) {
            [menuButton animateToMenu];
        }
    }
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
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
