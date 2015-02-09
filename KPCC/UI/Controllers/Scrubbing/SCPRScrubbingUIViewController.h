//
//  SCPRScrubbingUIViewController.h
//  KPCC
//
//  Created by Ben Hochberg on 2/9/15.
//  Copyright (c) 2015 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SCPRScrubberViewController.h"
#import "Program.h"
#import "AudioChunk.h"

@interface SCPRScrubbingUIViewController : UIViewController

@property (nonatomic,strong) IBOutlet UIButton *closeButton;
@property (nonatomic,strong) IBOutlet UILabel *captionLabel;
@property (nonatomic,strong) IBOutlet UIView *scrubberSeatView;
@property (nonatomic,strong) IBOutlet UIButton *rw30Button;
@property (nonatomic,strong) IBOutlet UIButton *playPauseButton;
@property (nonatomic,strong) IBOutlet UIButton *fw30Button;
@property (nonatomic,strong) IBOutlet UIImageView *blurredImageView;
@property (nonatomic,strong) IBOutlet UIView *darkeningView;
@property (nonatomic,strong) SCPRScrubberViewController *scrubberController;
@property (nonatomic,weak) id parentControlView;

- (void)setupWithProgram:(NSDictionary*)program blurredImage:(UIImage*)image;
- (void)cutDisplayHole;

@end
