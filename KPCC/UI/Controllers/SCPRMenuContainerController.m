//
//  SCPRMenuContainerController.m
//  KPCC
//
//  Created by John Meeker on 10/9/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "SCPRMenuContainerController.h"

@interface SCPRMenuContainerController ()

@end

@implementation SCPRMenuContainerController

@synthesize pulldownMenu;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    pulldownMenu = [[SCPRPullDownMenu alloc] initWithView:self.view];
    [self.view addSubview:pulldownMenu];
    
    pulldownMenu.delegate = self;
    [pulldownMenu loadMenu];
    
    [self addProgramsListTableView];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)addProgramsListTableView {
    self.programsListViewController = [[SCPRProgramsListViewController alloc] initWithBackgroundProgram:nil];
    self.programsListViewController.view.backgroundColor = [UIColor clearColor];
    [self.view addSubview:self.programsListViewController.view];
    
    
    //    details.delegate = self;
    
    [self addChildViewController:self.programsListViewController];
    CGRect frame = self.view.bounds;
    frame.origin.x = self.view.bounds.size.width;
    self.programsListViewController.view.frame = frame;
    [self.view addSubview:self.programsListViewController.view];
    [self.programsListViewController didMoveToParentViewController:self];
}


# pragma mark - SCPRMenuDelegate

- (void)pullDownAnimated:(BOOL)open {
    // Notifications used in SCPRNavigationController.
    if (open) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"pull_down_menu_opened"
                                                            object:nil];
    } else {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"pull_down_menu_closed"
                                                            object:nil];
    }
}

- (void)menuItemSelected:(NSIndexPath *)indexPath {
    
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
