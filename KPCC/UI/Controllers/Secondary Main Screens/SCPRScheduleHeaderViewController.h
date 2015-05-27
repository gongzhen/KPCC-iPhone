//
//  SCPRScheduleHeaderViewController.h
//  KPCC
//
//  Created by Ben Hochberg on 5/6/15.
//  Copyright (c) 2015 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SCPRScheduleHeaderViewController : UIViewController

@property (nonatomic, strong) IBOutlet UIView *topLine;
@property (nonatomic, strong) IBOutlet UIView *bottomLine;
@property (nonatomic, strong) IBOutlet UILabel *captionLabel;

- (void)setupWithText:(NSString*)text;

@end
