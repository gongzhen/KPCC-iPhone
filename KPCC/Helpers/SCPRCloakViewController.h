//
//  SCPRCloakViewController.h
//  KPCC
//
//  Created by Ben Hochberg on 11/4/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Utils.h"

@interface SCPRCloakViewController : UIViewController

+ (SCPRCloakViewController*)o;
+ (void)cloakWithCustomCenteredView:(UIView*)customView cloakAppeared:(Block)cloakAppeared;
+ (void)cloakWithCustomCenteredView:(UIView *)customView useSpinner:(BOOL)useSpinner cloakAppeared:(Block)cloakAppeared;
+ (void)cloakWithCustomCenteredView:(UIView *)customView useSpinner:(BOOL)useSpinner blackout:(BOOL)blackout cloakAppeared:(Block)cloakAppeared;
+ (void)uncloak;
+ (BOOL)cloakInUse;

@property BOOL cloaked;

@end
