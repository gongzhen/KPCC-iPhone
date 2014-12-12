//
//  SCPRProgramDetailTableViewCell.h
//  KPCC
//
//  Created by John Meeker on 9/23/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Episode.h"

@interface SCPRProgramDetailTableViewCell : UITableViewCell

- (void)setEpisode:(Episode*)episode;
- (NSString*)episodeTitle;

@property (nonatomic,strong) UILabel* episodeTitleLabel;
@property (nonatomic,strong) UILabel* episodeInfoLabel;
@property (nonatomic,strong) Episode *episode;

@end
