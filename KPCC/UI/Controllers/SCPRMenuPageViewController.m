//
//  SCPRMenuPageViewController.m
//  KPCC
//
//  Created by John Meeker on 10/8/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "SCPRMenuPageViewController.h"
#import "SCPRPullDownMenu.h"
#import "SCPRProgramsListViewController.h"
#import "SCPRMasterViewController.h"

@interface SCPRMenuPageViewController ()

@end

@implementation SCPRMenuPageViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.

    self.pageController = [[UIPageViewController alloc] initWithTransitionStyle:UIPageViewControllerTransitionStyleScroll navigationOrientation:UIPageViewControllerNavigationOrientationHorizontal options:nil];

    self.pageController.dataSource = self;
    [[self.pageController view] setFrame:[[self view] bounds]];


    SCPRProgramsListViewController *programsListVC = [[SCPRProgramsListViewController alloc] initWithBackgroundProgram:nil];
    NSArray *viewControllers = @[programsListVC,programsListVC];

    [self.pageController setViewControllers:viewControllers direction:UIPageViewControllerNavigationDirectionForward animated:NO completion:nil];

    [self addChildViewController:self.pageController];
    [[self view] addSubview:[self.pageController view]];
    [self.pageController didMoveToParentViewController:self];
}


#pragma  - UIPageViewController DataSource

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerBeforeViewController:(UIViewController *)viewController {
    
    /*NSUInteger index = [(UIViewController *)viewController indexNumber];
    
    if (index == 0) {
        return nil;
    }
    
    index--;*/
    
    return [self viewControllerAtIndex:0];
    
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerAfterViewController:(UIViewController *)viewController {
    
    /*NSUInteger index = [(UIViewController *)viewController indexNumber];
    
    
    index++;
    
    if (index == 3) {
        return nil;
    }*/
    
    return [self viewControllerAtIndex:1];
    
}

- (UIViewController *)viewControllerAtIndex:(NSUInteger)index {
    
    UIViewController *childViewController = [[UIViewController alloc] initWithNibName:nil bundle:nil];
//    childViewController.indexNumber = index;
    
    return childViewController;
    
}

- (NSInteger)presentationCountForPageViewController:(UIPageViewController *)pageViewController {
    return 2;
}

- (NSInteger)presentationIndexForPageViewController:(UIPageViewController *)pageViewController {
    return 0;
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
