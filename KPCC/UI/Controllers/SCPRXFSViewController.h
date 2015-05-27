//
//  SCPRXFSViewController.h
//  KPCC
//
//  Created by Ben Hochberg on 5/27/15.
//  Copyright (c) 2015 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SCPRXFSViewController : UIViewController

@property (nonatomic, strong) IBOutlet UIImageView *chevronImage;
@property (nonatomic, strong) IBOutlet UIButton *deployButton;
@property (nonatomic, strong) IBOutlet UITableView *optionsTable;
@property (nonatomic, strong) IBOutlet UIButton *leftButton;
@property (nonatomic, strong) IBOutlet UIButton *rightButton;
@property (nonatomic, strong) NSLayoutConstraint *heightAnchor;

- (void)applyHeight:(CGFloat)height;

@end
