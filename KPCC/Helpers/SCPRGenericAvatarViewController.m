//
//  SCPRGenericAvatarViewController.m
//  KPCC
//
//  Created by Ben Hochberg on 12/12/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "SCPRGenericAvatarViewController.h"
#import "UIColor+UICustom.h"
#import "UILabel+Additions.h"
#import "Program.h"

@interface SCPRGenericAvatarViewController ()

@end

@implementation SCPRGenericAvatarViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (UIImage*)avatarFromProgram:(Program *)program {
    
    CGFloat scale = [[UIScreen mainScreen] scale];
    self.view.alpha = 1.0;
    UIGraphicsBeginImageContextWithOptions(self.view.frame.size, YES, scale);
    [self.view.layer.superlayer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *resultingImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    [self.view setAlpha:0.0];
    
    return resultingImage;
}

- (void)setupWithProgram:(Program *)program {
    self.view.backgroundColor = [UIColor clearColor];
    self.seatView.layer.cornerRadius = self.view.frame.size.width / 2.0;
    self.seatView.backgroundColor = [UIColor kpccSlateColor];
    [self.initialLetter proBookFontize];
    self.initialLetter.textColor = [UIColor whiteColor];
    
    NSString *name = program.title;
    NSString *actionWord;
    NSString *actionLetter = @"";
    if ( [name rangeOfString:@"The"].location == 0 ) {
        NSArray *splitty = [name componentsSeparatedByString:@" "];
        if ( [splitty count] > 1 ) {
            actionWord = splitty[1];
        } else {
            // Should never happen, but...
            actionWord = splitty[0];
        }
    } else {
        actionWord = name;
    }
    
    actionLetter = [actionWord substringWithRange:NSMakeRange(0, 1)];
    self.initialLetter.text = [actionLetter uppercaseString];
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
