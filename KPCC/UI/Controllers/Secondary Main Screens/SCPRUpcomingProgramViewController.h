//
//  SCPRUpcomingProgramViewController.h
//  KPCC
//
//  Created by Ben Hochberg on 5/5/15.
//  Copyright (c) 2015 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Program.h"

@class SCPRGenericAvatarViewController;
@class SCPRButton;

@interface SCPRUpcomingProgramViewController : UIViewController

@property IBOutlet UILabel *upNextLabel;
@property IBOutlet UILabel *programTitleLabel;
@property IBOutlet UIImageView *avatarImageView;
@property IBOutlet UIImageView *clockImageView;
@property IBOutlet UILabel *timeLabel;
@property IBOutlet UIView *dividerViewLeft;
@property IBOutlet UIView *dividerViewRight;
@property IBOutlet SCPRButton *viewFullScheduleButton;
@property IBOutlet SCPRGenericAvatarViewController *genericAvatar;
@property (nonatomic, weak) UIScrollView *tableToScroll;
@property (nonatomic, strong) IBOutlet NSLayoutConstraint *verticalPushAnchor;
@property (nonatomic, strong) Program *nextProgram;

- (void)primeWithProgramBasedOnCurrent:(Program*)program;
- (void)alignDividerToValue:(CGFloat)yCoordinate;

@end
