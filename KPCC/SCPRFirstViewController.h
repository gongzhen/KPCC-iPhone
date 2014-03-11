//
//  SCPRFirstViewController.h
//  KPCC
//
//  Created by John Meeker on 3/6/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SCPRFirstViewController : UIViewController

@property (nonatomic,strong) IBOutlet UIButton *playButton;
@property (nonatomic,strong) IBOutlet UIButton *stopButton;

- (IBAction)buttonTapped:(id)sender;


@end
