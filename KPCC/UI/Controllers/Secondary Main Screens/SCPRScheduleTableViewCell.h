//
//  SCPRScheduleTableViewCell.h
//  KPCC
//
//  Created by Ben Hochberg on 5/6/15.
//  Copyright (c) 2015 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SCPRScheduleTableViewCell : UITableViewCell

@property (nonatomic, strong) IBOutlet UILabel *timeLabel;
@property (nonatomic, strong) IBOutlet UILabel *programTitleLabel;

- (void)setupWithProgram:(NSDictionary*)program;
- (NSString*)formatOfInterestFromString:(NSString*)rawDateStr startDate:(BOOL)startDate;
+ (NSString*)rui;

@end
