//
//  SCPRProgramTableViewHeader.h
//  KPCC
//
//  Created by Eric Richardson on 9/11/15.
//  Copyright © 2015 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SCPRProgramTableViewHeader : UIViewController

@property (nonatomic, strong) IBOutlet UIView *topLine;
@property (nonatomic, strong) IBOutlet UIView *bottomLine;
@property (nonatomic, strong) IBOutlet UILabel *captionLabel;

- (void)setupWithText:(NSString*)text;

@end
