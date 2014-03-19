//
//  SCPRFirstViewController.h
//  KPCC
//
//  Created by John Meeker on 3/6/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AudioManager.h"
#import "NetworkManager.h"

@interface SCPRFirstViewController : UIViewController <ContentProcessor>
{
@private
    NSTimer *timer;
}

@property (nonatomic,strong) IBOutlet UIButton *playButton;
@property (nonatomic,strong) IBOutlet UIButton *stopButton;
@property (nonatomic,strong) IBOutlet UILabel *streamStatusLabel;
@property (nonatomic,strong) IBOutlet UIView *meter;

- (IBAction)buttonTapped:(id)sender;


@end
