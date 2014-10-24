//
//  SCPRPreRollViewController.h
//  KPCC
//
//  Created by John Meeker on 10/14/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TritonAd.h"

@protocol SCPRPreRollControllerDelegate <NSObject>

- (void)preRollCompleted;

@end

@interface SCPRPreRollViewController : UIViewController

- (void)showPreRollWithAnimation:(BOOL)animated completion:(void (^)(BOOL done))completion;

@property (nonatomic,weak) id<SCPRPreRollControllerDelegate> delegate;
@property (nonatomic,strong) TritonAd *tritonAd;
@property BOOL hasAdBeenShown;

@property (nonatomic,strong) IBOutlet UIImageView *adImageView;

@end
