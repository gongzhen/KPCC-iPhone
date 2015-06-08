//
//  SCPRMenuCell.h
//  KPCC
//
//  Created by John Meeker on 9/12/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>

@class SCPRPullDownMenu;

@interface SCPRMenuCell : UITableViewCell

@property (nonatomic,strong) UILabel* menuItemLabel;
@property (nonatomic,strong) UIImageView* iconImageView;
@property (nonatomic,strong) UIImageView* rightChevronImageView;
@property (nonatomic,weak) SCPRPullDownMenu *parentMenuTable;

- (void)nudge;
- (void)shiftForIconWithImage:(UIImage*)image;
- (void)shiftForIconWithImage:(UIImage *)image animated:(BOOL)animated;
- (void)unshiftForIcon;
- (void)unshiftForIconWithAnimated:(BOOL)animated;

@end
