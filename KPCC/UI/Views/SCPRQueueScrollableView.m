//
//  SCPRQueueScrollableView.m
//  KPCC
//
//  Created by John Meeker on 10/30/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "SCPRQueueScrollableView.h"
#import "Utils.h"

@interface SCPRQueueScrollableView ()

@property (nonatomic,strong) AudioChunk *audioChunk;


@end

@implementation SCPRQueueScrollableView

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {

        self.audioTitleLabel = [[UILabel alloc]initWithFrame:CGRectMake(15, 40, frame.size.width - 30, 100)];
        self.audioTitleLabel.font = [UIFont fontWithName:@"FreightSansProLight-Regular" size:27.0f];
        self.audioTitleLabel.minimumScaleFactor = 20.f / 27.f;
        self.audioTitleLabel.numberOfLines = 2;
        self.audioTitleLabel.textColor = [UIColor whiteColor];
        self.audioTitleLabel.adjustsFontSizeToFitWidth = YES;
        [self addSubview:self.audioTitleLabel];

        self.audioDateLabel = [[UILabel alloc]initWithFrame:CGRectMake(15, 60, frame.size.width - 30, 50)];
        self.audioDateLabel.font = [UIFont fontWithName:@"FreightSansProLight-Regular" size:14.0f];
        self.audioDateLabel.textColor = [UIColor colorWithRed:180.f/255.f green:190.f/255.f blue:192.f/255.f alpha:1.f];
        [self addSubview:self.audioDateLabel];
    }
    return self;
}

- (void)setAudioChunk:(AudioChunk *)audioChunk {
    [self setAudioTitle:audioChunk.audioTitle];
    [self setAudioDate:audioChunk.audioTimeStamp];
}

- (void)setAudioTitle:(NSString *)audioTitle {
    NSString *trimmedTitle = [audioTitle stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [self.audioTitleLabel setText:trimmedTitle];
    [self.audioTitleLabel sizeToFit];
}

- (void)setAudioDate:(NSDate *)audioDate {
    self.audioDateLabel.text = [Utils episodeDateStringFromRFCDate:audioDate];
    [self.audioDateLabel sizeToFit];

    CGRect frame = self.audioDateLabel.frame;
    frame.origin.y = self.audioTitleLabel.frame.origin.y + self.audioTitleLabel.frame.size.height;// + 10.f;
    [self.audioDateLabel setFrame:frame];
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

@end
