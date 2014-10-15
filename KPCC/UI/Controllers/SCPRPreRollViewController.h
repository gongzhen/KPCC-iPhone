//
//  SCPRPreRollViewController.h
//  KPCC
//
//  Created by John Meeker on 10/14/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol SCPRPreRollControllerDelegate <NSObject>

- (void)preRollCompleted;

@end

@interface SCPRPreRollViewController : UIViewController

@property (nonatomic,weak) id<SCPRPreRollControllerDelegate> delegate;

- (void)showPreRollWithAnimation:(BOOL)animated;

@end
