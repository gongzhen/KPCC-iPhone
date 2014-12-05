//
//  SCPRKeyboardToolbar.h
//  KPCC
//
//  Created by Ben Hochberg on 12/4/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>

static NSString *kToolbarOptionNext = @"NEXT";

@interface SCPRKeyboardToolbar : UIToolbar

- (void)presentOnController:(UIViewController*)controller withOptions:(NSDictionary*)options;
- (void)dismiss;
- (void)prep;

@property (nonatomic,strong) IBOutlet NSLayoutConstraint *topMargin;

@end
