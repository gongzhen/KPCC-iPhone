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
    
    

    for (UIViewController* viewController in self.viewControllers){
        // You need to do this because the push is not called if you created this controller as part of the storyboard
        [self addButton:viewController.navigationItem];
    }
}

-(void) pushViewController:(UIViewController *)viewController animated:(BOOL)animated{
    [self addButton:viewController.navigationItem];
    [super pushViewController:viewController animated:animated];
}

-(void) addButton:(UINavigationItem *)item{
    if (item.leftBarButtonItem == nil){
        SCPRMenuButton *button = [SCPRMenuButton button];
        //[button addTarget:self action:@selector(animateTitleLabel:) forControlEvents:UIControlEventTouchUpInside];
        //button.tintColor = [UIColor blueColor];
        item.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:button];
    }
}


# pragma mark - PulldownMenuDelegate

-(void)menuItemSelected:(NSIndexPath *)indexPath {
    NSLog(@"%ld",(long)indexPath.item);
}

-(void)pullDownAnimated:(BOOL)open {
    if (open) {
        NSLog(@"Pull down menu open!");
        //self.navigationItem.leftBarButtonItem
    } else {
        NSLog(@"Pull down menu closed!");
    }
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
