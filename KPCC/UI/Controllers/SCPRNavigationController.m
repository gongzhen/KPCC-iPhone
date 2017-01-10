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
#import "SessionManager.h"

@interface SCPRNavigationController ()
@property(nonatomic) BOOL menuOpen;
@property (nonatomic, weak) id<MenuButtonDelegate> proxyDelegate;
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
    self.menuButton = [SCPRMenuButton buttonWithOrigin:CGPointMake(10.f, 10.f)];
    self.menuButton.delegate = self;

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

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    NSLog(@">>>> TITLE HAS CHANGED : %@",self.navigationItem.title);
}

- (void)applyCustomLeftBarItem:(CustomLeftBarItem)leftBarItemType proxyDelegate:(id<MenuButtonDelegate>)proxyDelegate {
    self.proxyDelegate = proxyDelegate;
    if ( leftBarItemType == CustomLeftBarItemPop ) {
        [self.menuButton animateToPop:proxyDelegate];
    }
}

- (void)restoreLeftBarItem:(id<MenuButtonDelegate>)proxyDelegate {
    if (proxyDelegate == self.proxyDelegate) {
        [self.menuButton animateToBack];
        [self.menuButton setProxyDelegate:nil];
        self.proxyDelegate = nil;
    }
}

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated{
//    if ([self respondsToSelector:@selector(interactivePopGestureRecognizer)]) {
//        self.interactivePopGestureRecognizer.enabled = NO;
//    }

    [super pushViewController:viewController animated:animated];

	[self addButton:viewController.navigationItem];
    [self.menuButton animateToBack];
}

- (void)addButton:(UINavigationItem *)item{
    if (item.leftBarButtonItem == nil){
        item.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:self.menuButton];
    }
}

- (void)leftButtonTapped {
    [self.menuButton touchUpInsideHandler:self.menuButton];
}

#pragma mark - UINavigationControllerDelegate

//- (void)navigationController:(UINavigationController *)navigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)animate {
//    // Enable the gesture again once the new controller is shown
//    self.interactivePopGestureRecognizer.enabled = ([self respondsToSelector:@selector(interactivePopGestureRecognizer)] && [self.viewControllers count] > 1);
//}

- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated {
	[[self transitionCoordinator] notifyWhenInteractionEndsUsingBlock:^(id<UIViewControllerTransitionCoordinatorContext> context) {
		if ([context isCancelled]) {
			UIViewController *fromViewController = [context viewControllerForKey:UITransitionContextFromViewControllerKey];
			[self navigationController:navigationController willShowViewController:fromViewController animated:animated];

			if ([self respondsToSelector:@selector(navigationController:didShowViewController:animated:)]) {
				NSTimeInterval animationCompletion = [context transitionDuration] * [context percentComplete];

				dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (uint64_t)animationCompletion * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
					[self navigationController:navigationController didShowViewController:fromViewController animated:animated];
				});
			}
		}
	}];

	if (viewController == [[Utils del] masterViewController]) {
		if ([[Utils del] masterViewController].menuOpen == YES) {
			[self.menuButton animateToClose];
		} else {
			[self.menuButton animateToMenu];
		}
	}
}

- (void) navigationController:(UINavigationController *)navigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)animated {
	self.interactivePopGestureRecognizer.enabled = YES;

	// Used to prevent freeze when left-edge gesture popping when there is only one VC in the navigation stack... - JAC
	// See: http://stackoverflow.com/questions/36503224/ios-app-freezes-on-pushviewcontroller/36637556#36637556

	if ([self respondsToSelector:@selector(interactivePopGestureRecognizer)]) {
		if (viewController == [[Utils del] masterViewController]) {
			if (self.viewControllers.count == 1) {
				self.interactivePopGestureRecognizer.enabled = NO;
			}
		}
	}

	if (viewController == [[Utils del] masterViewController]) {
		if ([[Utils del] masterViewController].menuOpen == YES) {
			[self.menuButton animateToClose];
		} else {
			[self.menuButton animateToMenu];
		}
	} else {
		if (self.menuButton.showPopArrow == YES) {
			[self.menuButton animateToPop:self.menuButton.proxyDelegate];
		} else {
			[self.menuButton animateToBack];
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

    // TODO: The back transition needs some work
//    if ([toVC class] == [SCPRMasterViewController class] && [fromVC class] == [SCPRProgramsListViewController class]) {
//        SCPRSlideInTransition *slideInTransition = [SCPRSlideInTransition new];
//        slideInTransition.direction = @"leftToRight";
//        return slideInTransition;
//    }

    return nil;
}


# pragma mark - MenuButtonDelegate

- (void)backPressed {
    [[[Utils del] masterViewController] setHomeIsNotRootViewController:NO];
    [[Utils del] controlXFSAvailability:[[SessionManager shared] virtualLiveAudioMode]];
    [self popViewControllerAnimated:YES];
}

- (void)menuPressed {
    if ([[[Utils del] masterViewController] menuOpen]) {
		[[[Utils del] masterViewController] decloakForMenu:YES];
        [self.menuButton animateToMenu];
    } else {
		[[[Utils del] masterViewController] cloakForMenu:YES];
        [self.menuButton animateToClose];
    }
}

- (void)popPressed {
    
}

# pragma mark - NSNotification

- (void)handleMenuOpened:(NSNotification *)notification {

}

- (void)handleMenuClosed:(NSNotification *)notification {
    // Handle when we close menu programatically, and update
    // menu button to proper state.

	if (![self.menuButton showBackArrow]) {
        if (![self.menuButton showMenu]) {
            [self.menuButton animateToMenu];
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
