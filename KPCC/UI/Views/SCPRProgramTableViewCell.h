//
//  SCPRProgramTableViewCell.h
//  KPCC
//
//  Created by John Meeker on 9/22/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>

@class SCPRGenericAvatarViewController;

@interface SCPRProgramTableViewCell : UITableViewCell

@property (nonatomic,strong) IBOutlet UILabel* programLabel;
@property (nonatomic,strong) IBOutlet UIImageView* iconImageView;
@property (nonatomic,strong) IBOutlet UIImageView* rightChevronImageView;
@property (nonatomic,strong) IBOutlet SCPRGenericAvatarViewController *gav;

@end
