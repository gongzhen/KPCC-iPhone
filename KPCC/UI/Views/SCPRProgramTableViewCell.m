//
//  SCPRProgramTableViewCell.m
//  KPCC
//
//  Created by John Meeker on 9/22/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "SCPRProgramTableViewCell.h"

@implementation SCPRProgramTableViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    
    self.programLabel = [[UILabel alloc] initWithFrame:CGRectMake(60, 0, self.frame.size.width - 60, 62)];
    [self.programLabel setFont:[UIFont fontWithName:@"FreightSansProLight-Regular" size:18.0f]];
    [self.programLabel setTextColor:[UIColor whiteColor]];
    [self.contentView addSubview:self.programLabel];
    
    self.iconImageView = [[UIImageView alloc]initWithFrame:CGRectMake(15, CGRectGetMidY(self.frame), 0, 0)];
    [self.contentView addSubview:self.iconImageView];
    
    self.rightChevronImageView = [[UIImageView alloc]initWithFrame:CGRectMake(CGRectGetMaxX(self.frame) - 20, 24, 9, 14)];
    self.rightChevronImageView.image = [UIImage imageNamed:@"item-chevron-right"];
    [self.contentView addSubview:self.rightChevronImageView];
    
    return self;
}

- (void)prepareForReuse {
    UIView *v = [self.contentView viewWithTag:11111];
    if ( v ) {
        [v removeFromSuperview];
    }
    self.gav = nil;
    self.iconImageView.alpha = 0.0;
}

- (void)awakeFromNib {
    // Initialization code
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

@end
