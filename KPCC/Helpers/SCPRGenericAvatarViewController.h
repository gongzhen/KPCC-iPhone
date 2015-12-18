//
//  SCPRGenericAvatarViewController.h
//  KPCC
//
//  Created by Ben Hochberg on 12/12/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GenericProgram.h"

@class Program;

@interface SCPRGenericAvatarViewController : UIViewController

@property (nonatomic,strong) IBOutlet UIView *seatView;
@property (nonatomic,strong) IBOutlet UILabel *initialLetter;

- (UIImage*)avatarFromProgram:(id<GenericProgram>)program;
- (void)setupWithProgram:(id<GenericProgram>)program;

@end
