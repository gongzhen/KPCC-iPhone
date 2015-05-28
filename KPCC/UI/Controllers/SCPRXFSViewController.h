//
//  SCPRXFSViewController.h
//  KPCC
//
//  Created by Ben Hochberg on 5/27/15.
//  Copyright (c) 2015 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SCPRXFSViewController : UIViewController<UITableViewDataSource,UITableViewDelegate>

@property (nonatomic, strong) IBOutlet UIImageView *chevronImage;
@property (nonatomic, strong) IBOutlet UIButton *deployButton;
@property (nonatomic, strong) IBOutlet UITableView *optionsTable;
@property (nonatomic, strong) IBOutlet UIButton *leftButton;
@property (nonatomic, strong) IBOutlet UIButton *rightButton;
@property (nonatomic, strong) NSLayoutConstraint *heightAnchor;
@property (nonatomic, strong) IBOutlet NSLayoutConstraint *chevronHorizontalAnchor;

@property BOOL deployed;

- (void)applyHeight:(CGFloat)height;
- (void)openDropdown;
- (void)closeDropdown;
- (void)controlVisibility:(BOOL)visible;

@end
