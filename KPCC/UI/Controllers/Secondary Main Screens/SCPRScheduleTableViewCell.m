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
    NSString *startFmt = [self formatOfInterestFromString:startsStr
                                                startDate:YES];
    NSString *formattedStartStr = [NSDate stringFromDate:[Utils dateFromRFCString:startsStr]
                                              withFormat:startFmt];
    
    NSString *endsStr = program[@"ends_at"];
    NSString *endsFmt = [self formatOfInterestFromString:endsStr
                                               startDate:NO];
    NSString *formattedEndStr = [NSDate stringFromDate:[Utils dateFromRFCString:endsStr]
                                            withFormat:endsFmt];
    
    NSString *combined = [NSString stringWithFormat:@"%@-%@",formattedStartStr,formattedEndStr];
    self.timeLabel.attributedText = [[DesignManager shared] standardTimeFormatWithString:[combined lowercaseString]
                                                                              attributes:@{ @"digits" : [[DesignManager shared] proMedium:18.0f],
                                                                                            @"period" : [[DesignManager shared] proLight:14.0f] }];
    self.programTitleLabel.textColor = [UIColor whiteColor];
    self.backgroundColor = [UIColor clearColor];
}

- (NSString*)formatOfInterestFromString:(NSString *)rawDateStr startDate:(BOOL)startDate {
    NSDate *startsDate = [Utils dateFromRFCString:rawDateStr];
    NSDateComponents *startComps = [[NSCalendar currentCalendar] components:NSCalendarUnitMinute
                                                                   fromDate:startsDate];
    NSString *dFmt = @"";
    if ( [startComps minute] == 0 ) {
        dFmt = @"h";
    } else {
        dFmt = @"h:mm";
    }
    
    if ( !startDate ) {
        dFmt = [dFmt stringByAppendingString:@" a"];
    }
    
    return dFmt;
}

- (NSString*)reuseIdentifier {
    return [SCPRScheduleTableViewCell rui];
}

@end
