//
//  SCPRProgramsListViewController.h
//  KPCC
//
//  Created by John Meeker on 9/22/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Program.h"
#import "FXBlurView.h"

@class SCPRGenericAvatarViewController;

@interface SCPRProgramsListViewController : UIViewController<UITableViewDataSource,UITableViewDelegate>

- (instancetype)initWithBackgroundProgram:(Program *)program;

@property IBOutlet UIImageView *programBgImage;
@property IBOutlet UITableView *programsTable;
@property IBOutlet FXBlurView *blurView;
@property (nonatomic,strong) SCPRGenericAvatarViewController *genAvatar;

@end
