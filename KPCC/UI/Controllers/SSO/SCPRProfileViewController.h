//
//  SCPRProfileViewController.h
//  KPCC
//
//  Created by Ben Hochberg on 8/4/15.
//  Copyright (c) 2015 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SCPRProfileViewController : UIViewController

@property (nonatomic, strong) IBOutlet UIImageView *avatarImage;
@property (nonatomic, strong) IBOutlet UILabel *userNameLabel;

- (void)setup;

@end
