//
//  SCPRProgramDetailHeaderView.m
//  KPCC
//
//  Created by John Meeker on 9/23/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "SCPRProgramDetailHeaderView.h"

@implementation SCPRProgramDetailHeaderView

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {

        self.headerLabel = [[UILabel alloc] initWithFrame:CGRectMake(frame.origin.x + 9.f, frame.size.height - 36.f, frame.size.width - 16.f, 20.f)];
        self.headerLabel.font = [UIFont fontWithName:@"FreightSansProMedium-Regular" size:17.0f];
        self.headerLabel.textColor = [UIColor colorWithRed:248.f/255.f green:126.f/255.f blue:33.f/255.f alpha:1.f];
        self.headerLabel.text = @"RECENT EPISODES";
        [self.headerLabel sizeToFit];
        [self addSubview:self.headerLabel];

        self.headerDividerThin = [[UIView alloc] initWithFrame:CGRectMake(frame.origin.x + 8.f, frame.size.height - 1.f, frame.size.width - 16.f, 1.f)];
        self.headerDividerThin.backgroundColor = [UIColor colorWithRed:248.f/255.f green:126.f/255.f blue:33.f/255.f alpha:1.f];
        [self addSubview:self.headerDividerThin];

        self.headerDividerThick = [[UIView alloc] initWithFrame:CGRectMake(frame.origin.x + 8.f, frame.size.height - 4.f,
                                                                           self.headerLabel.frame.size.width + 3.f, 4.f)];
        self.headerDividerThick.backgroundColor = [UIColor colorWithRed:248.f/255.f green:126.f/255.f blue:33.f/255.f alpha:1.f];
        [self addSubview:self.headerDividerThick];
    }
    return self;
}

@end
