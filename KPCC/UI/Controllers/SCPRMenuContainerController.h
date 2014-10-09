//
//  SCPRMenuContainerController.h
//  KPCC
//
//  Created by John Meeker on 10/9/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SCPRPullDownMenu.h"
#import "SCPRProgramsListViewController.h"

@protocol SCPRMenuContainerDelegate
-(void)menuItemSelected:(NSIndexPath *)indexPath;
-(void)pullDownAnimated:(BOOL)open;
@end

@interface SCPRMenuContainerController : UIViewController<SCPRMenuDelegate>

@property (nonatomic,strong) SCPRPullDownMenu *pulldownMenu;
@property (nonatomic,strong) SCPRProgramsListViewController *programsListViewController;

@end
