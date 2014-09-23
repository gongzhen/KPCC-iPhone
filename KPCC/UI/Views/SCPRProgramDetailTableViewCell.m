//
//  SCPRProgramDetailTableViewCell.m
//  KPCC
//
//  Created by John Meeker on 9/23/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "SCPRProgramDetailTableViewCell.h"
#import "Utils.h"
#import "Episode.h"
#import "Segment.h"

@implementation SCPRProgramDetailTableViewCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];

    self.episodeTitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(8.f, 18.f, self.frame.size.width - 16.f, 60.f)];
    self.episodeTitleLabel.font = [UIFont fontWithName:@"FreightSansProLight-Regular" size:18.0f];
    self.episodeTitleLabel.textColor = [UIColor whiteColor];
    self.episodeTitleLabel.backgroundColor = [UIColor clearColor];
    self.episodeTitleLabel.numberOfLines = 2;
    [self.contentView addSubview:self.episodeTitleLabel];

    self.episodeInfoLabel = [[UILabel alloc] initWithFrame:CGRectMake(8.f, 40.f, self.frame.size.width - 16.f, 40.f)];
    self.episodeInfoLabel.font = [UIFont fontWithName:@"FreightSansProLight-Regular" size:14.0f];
    self.episodeInfoLabel.textColor  = [UIColor colorWithRed:180.f/255.f green:190.f/255.f blue:192.f/255.f alpha:1.f];
    self.episodeInfoLabel.backgroundColor = [UIColor clearColor];
    [self.contentView addSubview:self.episodeInfoLabel];

    return self;
}

- (void)setEpisode:(NSObject *)episode {
    if (episode != nil) {
        [self.episodeTitleLabel setFrame:CGRectMake(8.f, 18.f, self.frame.size.width - 16.f, 60.f)];
        [self.episodeInfoLabel setFrame:CGRectMake(8.f, 40.f, self.frame.size.width - 16.f, 40.f)];

        if ([episode isKindOfClass:[Episode class]]) {
            Episode *ep = (Episode *) episode;

            self.episodeTitleLabel.text = ep.title;
            [self.episodeTitleLabel sizeToFit];

            if (ep.airDate != nil) {
                self.episodeInfoLabel.text = [Utils episodeDateStringFromRFCDate:ep.airDate];
                [self.episodeInfoLabel sizeToFit];
                [self.episodeInfoLabel setFrame:CGRectMake(self.episodeInfoLabel.frame.origin.x, self.episodeTitleLabel.frame.size.height + 23.f, self.episodeInfoLabel.frame.size.width, self.episodeInfoLabel.frame.size.height)];
            }
        } else {
            Segment *seg = (Segment *) episode;

            self.episodeTitleLabel.text = seg.title;
            [self.episodeTitleLabel sizeToFit];

            if (seg.publishedAt != nil) {
                self.episodeInfoLabel.text = [Utils episodeDateStringFromRFCDate:seg.publishedAt];
                [self.episodeInfoLabel sizeToFit];
                [self.episodeInfoLabel setFrame:CGRectMake(self.episodeInfoLabel.frame.origin.x, self.episodeTitleLabel.frame.size.height + 23.f, self.episodeInfoLabel.frame.size.width, self.episodeInfoLabel.frame.size.height)];
            }
        }
    }
}

- (void)awakeFromNib {
    // Initialization code
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

@end
