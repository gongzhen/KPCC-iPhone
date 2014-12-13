//
//  SCPRGenericAvatarViewController.h
//  KPCC
//
//  Created by Ben Hochberg on 12/12/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>

@class Program;

@interface SCPRGenericAvatarViewController : UIViewController

@property (nonatomic,strong) IBOutlet UIView *seatView;
@property (nonatomic,strong) IBOutlet UILabel *initialLetter;

- (UIImage*)avatarFromProgram:(Program*)program;
- (void)setupWithProgram:(Program*)program;

@end
