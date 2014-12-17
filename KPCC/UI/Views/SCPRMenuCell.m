//
//  SCPRMenuCell.m
//  KPCC
//
//  Created by John Meeker on 9/12/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "SCPRMenuCell.h"

@implementation SCPRMenuCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];

    self.menuItemLabel = [[UILabel alloc] initWithFrame:CGRectMake(60, 0, self.frame.size.width - 60, 62)];
    [self.contentView addSubview:self.menuItemLabel];

    self.iconImageView = [[UIImageView alloc]initWithFrame:CGRectMake(0.0, 0.0, 44.0, 44.0)];
    [self.contentView addSubview:self.iconImageView];
    
    self.rightChevronImageView = [[UIImageView alloc]initWithFrame:CGRectMake(CGRectGetMaxX(self.frame) - 20, 24, 9, 14)];
    self.rightChevronImageView.image = [UIImage imageNamed:@"item-chevron-right"];
    [self.contentView addSubview:self.rightChevronImageView];

    return self;
}

- (void)nudge {
    self.iconImageView.frame = CGRectMake(20, CGRectGetMidY(self.frame), self.iconImageView.frame.size.width,
                                          self.iconImageView.frame.size.height);
}

- (void)awakeFromNib {
    // Initialization code
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

@end
