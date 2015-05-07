//
//  SCPRScheduleTableViewCell.m
//  KPCC
//
//  Created by Ben Hochberg on 5/6/15.
//  Copyright (c) 2015 SCPR. All rights reserved.
//

#import "SCPRScheduleTableViewCell.h"
#import "UILabel+Additions.h"
#import "Utils.h"
#import "DesignManager.h"

@implementation SCPRScheduleTableViewCell

- (void)awakeFromNib {
    // Initialization code
}

+ (NSString*)rui {
    return @"schedule-cell";
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (void)setupWithProgram:(NSDictionary *)program {
    [self.programTitleLabel proLightFontize];
    self.programTitleLabel.text = program[@"title"];
    
    NSString *startsStr = program[@"starts_at"];
    
    NSDate *startsDate = [Utils dateFromRFCString:startsStr];
    NSString *startFmt = [self formatOfInterestFromDate:startsDate
                                                startDate:YES];
    NSString *formattedStartStr = [NSDate stringFromDate:startsDate
                                              withFormat:startFmt];
    
    NSString *endsStr = program[@"ends_at"];
    
    NSDate *endsDate = [Utils dateFromRFCString:endsStr];
    NSString *endsFmt = [self formatOfInterestFromDate:endsDate
                                               startDate:NO];
    NSString *formattedEndStr = [NSDate stringFromDate:endsDate
                                            withFormat:endsFmt];
    
    NSString *combined = [NSString stringWithFormat:@"%@-%@",formattedStartStr,formattedEndStr];
    self.timeLabel.attributedText = [[DesignManager shared] standardTimeFormatWithString:[combined lowercaseString]
                                                                              attributes:@{ @"digits" : [[DesignManager shared] proMedium:18.0f],
                                                                                            @"period" : [[DesignManager shared] proLight:14.0f] }];
    self.programTitleLabel.textColor = [UIColor whiteColor];
    self.backgroundColor = [UIColor clearColor];
}

- (NSString*)formatOfInterestFromDate:rawDate startDate:(BOOL)startDate {

    return [Utils formatOfInterestFromDate:rawDate
                                 startDate:startDate];
    
}

- (NSString*)reuseIdentifier {
    return [SCPRScheduleTableViewCell rui];
}

@end
