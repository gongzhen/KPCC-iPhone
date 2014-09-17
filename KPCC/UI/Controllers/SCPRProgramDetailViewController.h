//
//  SCPRProgramDetailViewController.h
//  KPCC
//
//  Created by John Meeker on 9/16/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Program.h"

@interface SCPRProgramDetailViewController : UIViewController

- (id)initWithProgram:(Program *)program;
@property (nonatomic,strong) Program *program;
@property IBOutlet UIImageView *programBgImage;

@end
