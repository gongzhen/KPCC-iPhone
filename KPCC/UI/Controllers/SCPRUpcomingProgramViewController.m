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

@interface SCPRUpcomingProgramViewController ()

- (void)setupWithNextProgram:(Program*)program;

@end

@implementation SCPRUpcomingProgramViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor clearColor];
    self.avatarImageView.clipsToBounds = YES;
    self.avatarImageView.layer.cornerRadius = self.avatarImageView.frame.size.width / 2.0f;
    
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
                                                 name:@"program_has_changed"
                                               object:nil];
    // Do any additional setup after loading the view from its nib.
}

- (void)primeWithProgramBasedOnCurrent {
    [self primeWithProgramBasedOnCurrent:[[SessionManager shared] currentProgram]];
}

- (void)primeWithProgramBasedOnCurrent:(Program *)program {
    
    if ( !program ) {
        return;
    }
    
    NSDate *cpEndsAt = [program ends_at];
    [[SessionManager shared] fetchProgramAtDate:cpEndsAt completed:^(id returnedObject) {
        
        [self setupWithNextProgram:(Program*)returnedObject];
        
    }];
}

- (void)setupWithNextProgram:(Program *)program {
    self.nextProgram = program;
    
    self.programTitleLabel.text = [program title];
    
    NSString *pretty = [NSDate stringFromDate:[program starts_at]
                                   withFormat:@"h:mm a"];
    
    pretty = [pretty lowercaseString];
    
    self.timeLabel.attributedText = [[DesignManager shared] standardTimeFormatWithString:pretty
                                                                                           attributes:@{ @"digits" : [[DesignManager shared] proMedium:18.0f],
                                                                                                         @"period" : [[DesignManager shared] proLight:14.0f] }];
    NSString *iconNamed = [self.nextProgram program_slug];
    if (iconNamed) {
        UIImage *iconImg = [UIImage imageNamed:[NSString stringWithFormat:@"program_avatar_%@", iconNamed]];
        if ( !iconImg ) {
            [self.genericAvatar setupWithProgram:self.nextProgram];
            self.avatarImageView.alpha = 0.0f;
            self.genericAvatar.view.alpha = 1.0f;
        } else {
            self.avatarImageView.image = iconImg;
            self.genericAvatar.view.alpha = 0.0f;
        }
    } else {
        [self.genericAvatar setupWithProgram:self.nextProgram];
        self.avatarImageView.alpha = 0.0f;
        self.genericAvatar.view.alpha = 1.0f;
    }
}

- (void)alignDividerToValue:(CGFloat)yCoordinate {
    self.verticalPushAnchor.constant = yCoordinate;
    [self.view layoutIfNeeded];
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
