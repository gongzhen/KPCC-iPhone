//
//  SCPRProgressViewController.h
//  KPCC
//
//  Created by Ben Hochberg on 11/6/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Program.h"

@interface SCPRProgressViewController : UIViewController

+ (SCPRProgressViewController*)o;
+ (void)displayWithProgram:(Program*)program onView:(UIViewController*)viewController aboveSiblingView:(UIView*)anchorView;
+ (void)tick;
- (void)setupProgressBarsWithProgram:(Program*)program;
+ (void)rewind;
+ (void)threadedRewind;

@property BOOL quitBit;
@property (nonatomic,strong) IBOutlet UIProgressView *currentProgressView;
@property (nonatomic,strong) IBOutlet UIProgressView *liveProgressView;
@property (nonatomic, weak) Program *currentProgram;
@property (nonatomic,strong) NSOperationQueue *rewindQueue;

@end
