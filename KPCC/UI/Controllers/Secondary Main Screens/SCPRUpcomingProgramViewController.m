//
//  SCPRUpcomingProgramViewController.m
//  KPCC
//
//  Created by Ben Hochberg on 5/5/15.
//  Copyright (c) 2015 SCPR. All rights reserved.
//

#import "SCPRUpcomingProgramViewController.h"
#import "DesignManager.h"
#import "UIColor+UICustom.h"
#import "UILabel+Additions.h"
#import "ContentManager.h"
#import "SessionManager.h"
#import "SCPRGenericAvatarViewController.h"
#import "SCPRButton.h"
#import "UIImageView+AFNetworking.h"

@interface SCPRUpcomingProgramViewController ()

- (void)setupWithNextProgram:(ScheduleOccurrence*)program;

@end

@implementation SCPRUpcomingProgramViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor clearColor];
    self.avatarImageView.clipsToBounds = YES;
//    self.avatarImageView.layer.cornerRadius = self.avatarImageView.frame.size.width / 2.0f;
	
    [[DesignManager shared] sculptButton:self.viewFullScheduleButton
                               withStyle:SculptingStyleClearWithBorder
                                 andText:@"View Full Schedule"];
    
    self.upNextLabel.textColor = [UIColor kpccOrangeColor];
    self.dividerViewLeft.backgroundColor = [[UIColor virtualWhiteColor] translucify:0.4f];
    self.dividerViewRight.backgroundColor = [[UIColor virtualWhiteColor] translucify:0.4f];
    
    [self.upNextLabel proMediumFontize];
    [self.programTitleLabel proLightFontize];
    
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(primeWithProgramBasedOnCurrent)
                                                 name:@"program-has-changed"
                                               object:nil];
    
    [self.viewFullScheduleButton addTarget:self
                                    action:@selector(moveToFullSchedule)
                          forControlEvents:UIControlEventTouchUpInside
     special:YES];
    
    // Do any additional setup after loading the view from its nib.
}

- (void)primeWithProgramBasedOnCurrent {
    [self primeWithProgramBasedOnCurrent:[[SessionManager shared] currentSchedule]];
}

- (void)primeWithProgramBasedOnCurrent:(ScheduleOccurrence *)program {
    
    if ( !program ) {
        return;
    }
    
    NSDate *cpEndsAt = [program ends_at];
    NSLog(@"Projected end for program : %@",[NSDate stringFromDate:cpEndsAt
                                                        withFormat:@"h:mm:ss a"]);
    if ( !cpEndsAt ) {
        return;
    }

    NSLog(@"primeWith fetching NEXT program for %@",cpEndsAt);
    [[SessionManager shared] fetchScheduleAtDate:cpEndsAt completed:^(id object) {
        
        [self setupWithNextProgram:(ScheduleOccurrence*)object];
        
    }];
}

- (void)setupWithNextProgram:(ScheduleOccurrence *)program {
    self.nextProgram = program;
    
    self.programTitleLabel.text = [program title];
    
    NSDate *displayDate = [[SessionManager shared] sessionHasNoProgram] ? [[[SessionManager shared] currentSchedule] ends_at] : [program starts_at];
    NSString *pretty = [NSDate stringFromDate:displayDate
                                   withFormat:@"h:mm a"];
    
    pretty = [pretty lowercaseString];
    
#ifdef DEBUG
    //pretty = @"12:34 am";
#endif
    
    self.timeLabel.attributedText = [[DesignManager shared] standardTimeFormatWithString:pretty
                                                                                           attributes:@{ @"digits" : [[DesignManager shared] proMedium:18.0f],
                                                                                                         @"period" : [[DesignManager shared] proLight:14.0f] }];
    NSString *iconNamed = [self.nextProgram program_slug];
    if (iconNamed) {
		[self.genericAvatar setupWithProgram:self.nextProgram];
		self.avatarImageView.alpha = 0.0f;
		self.genericAvatar.view.alpha = 1.0f;

		NSString *densitySuffixString = nil;
		if ([[UIScreen mainScreen] scale] >= 2.0) {
			densitySuffixString = @"@2x";
		}
		NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://media.scpr.org/iphone/avatar-images/program_avatar_%@%@.png", iconNamed, densitySuffixString]] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:60];;

		__weak SCPRUpcomingProgramViewController *weakSelf = self;

		[self.avatarImageView setImageWithURLRequest:request
									  placeholderImage:nil
											   success:^(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image) {
												   weakSelf.avatarImageView.image		= image;
												   weakSelf.avatarImageView.alpha		= 1.0f;
												   weakSelf.genericAvatar.view.alpha	= 0.0f;
											   } failure:nil];
    }
}

- (void)moveToFullSchedule {
    CGFloat offset = self.tableToScroll.frame.size.width;
    [self.tableToScroll setContentOffset:CGPointMake(self.tableToScroll.contentOffset.x+offset,
                                                     self.tableToScroll.contentOffset.y)
                                animated:YES];
}

- (void)alignDividerToValue:(CGFloat)yCoordinate {
    self.verticalPushAnchor.constant = yCoordinate;
    if ( /*[Utils isIOS8] &&*/ [Utils isThreePointFive] ) {
        self.verticalPushAnchor.constant -= 88.0f;
    }
    [self.view layoutSubviews];
    [self.view updateConstraints];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
