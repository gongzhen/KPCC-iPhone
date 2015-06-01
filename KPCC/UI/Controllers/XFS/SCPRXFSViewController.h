//
//  SCPRXFSViewController.h
//  KPCC
//
//  Created by Ben Hochberg on 5/27/15.
//  Copyright (c) 2015 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SCPRBalloonViewController.h"

@interface SCPRXFSViewController : UIViewController

@property (nonatomic, strong) IBOutlet UIImageView *chevronImage;
@property (nonatomic, strong) IBOutlet UIButton *deployButton;
@property (nonatomic, strong) IBOutlet UITableView *optionsTable;
@property (nonatomic, strong) IBOutlet UIButton *leftButton;
@property (nonatomic, strong) IBOutlet UIButton *rightButton;
@property (nonatomic, strong) IBOutlet UIButton *cancelButton;
@property (nonatomic, strong) NSLayoutConstraint *heightAnchor;
@property (nonatomic, strong) IBOutlet UIView *dividerView;

@property (nonatomic, strong) IBOutlet NSLayoutConstraint *chevronHorizontalAnchor;
@property (nonatomic, strong) SCPRBalloonViewController *xfsBalloon;

@property BOOL deployed;
@property BOOL isGrayInterface;

- (void)applyHeight:(CGFloat)height;
- (void)openDropdown;
- (void)closeDropdown;
- (void)controlVisibility:(BOOL)visible;
- (void)showCoachingBalloon;
- (void)orangeInterface;
- (void)grayInterface;
- (void)adjustInterface;

@end
