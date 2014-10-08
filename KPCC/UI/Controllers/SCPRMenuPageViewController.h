//
//  SCPRMenuPageViewController.h
//  KPCC
//
//  Created by John Meeker on 10/8/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SCPRMenuPageViewController : UIViewController<UIPageViewControllerDelegate,UIPageViewControllerDataSource>

@property (strong, nonatomic) UIPageViewController *pageController;

@end
