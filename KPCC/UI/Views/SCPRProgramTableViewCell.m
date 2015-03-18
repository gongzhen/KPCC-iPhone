//
//  SCPRProgramTableViewCell.m
//  KPCC
//
//  Created by John Meeker on 9/22/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "SCPRProgramTableViewCell.h"
#import "SCPRGenericAvatarViewController.h"

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

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    [self.programLabel setFont:[UIFont fontWithName:@"FreightSansProLight-Regular" size:18.0f]];
    [self.programLabel setTextColor:[UIColor whiteColor]];
    self.rightChevronImageView.image = [UIImage imageNamed:@"item-chevron-right"];
    return self;
}


- (void)prepareForReuse {
    self.iconImageView.alpha = 0.0;
    self.gav.view.alpha = 0.0;
}

- (void)awakeFromNib {
    [self.programLabel setFont:[UIFont fontWithName:@"FreightSansProLight-Regular" size:18.0f]];
    [self.programLabel setTextColor:[UIColor whiteColor]];
    self.rightChevronImageView.image = [UIImage imageNamed:@"item-chevron-right"];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (NSString*)reuseIdentifier {
    return @"programTableCell";
}

@end
