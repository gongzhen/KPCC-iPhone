//
//  SCPRFirstViewController.m
//  KPCC
//
//  Created by John Meeker on 3/6/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "SCPRFirstViewController.h"
#import "AudioManager.h"
#import <AVFoundation/AVFoundation.h>


@interface SCPRFirstViewController ()
-(void) setupTimer;
-(void) updateControls;
@end

@implementation SCPRFirstViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    //Once the view has loaded then we can register to begin recieving controls and we can become the first responder
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    [self becomeFirstResponder];
    
    [self setupTimer];
    [self updateControls];
}

- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (void)remoteControlReceivedWithEvent:(UIEvent *)event {
    // If it is a remote control event handle it correctly
    if (event.type == UIEventTypeRemoteControl) {
        if (event.subtype == UIEventSubtypeRemoteControlPlay) {
            [self playStream];
        } else if (event.subtype == UIEventSubtypeRemoteControlPause) {
            [self stopStream];
        } else if (event.subtype == UIEventSubtypeRemoteControlTogglePlayPause) {
            [self stopStream];
        }
    }
}

- (IBAction)buttonTapped:(id)sender {
    if (sender == self.playButton) {
        NSLog(@"play tapped");
        [self playStream];
    } else if (sender == self.stopButton) {
        NSLog(@"stop tapped");
        [self stopStream];
        
    }
}

-(void) setupTimer
{
	timer = [NSTimer timerWithTimeInterval:0.001 target:self selector:@selector(tick) userInfo:nil repeats:YES];
	
	[[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
}


-(void) tick
{
	
    if ([[AudioManager shared] audioPlayer].state == STKAudioPlayerStateBuffering) {
        [self.streamStatusLabel setText:@"Buffering"];
    } else {
        if ([[AudioManager shared] streamPlaying])
        {
            [self.streamStatusLabel setText:@"Playing"];
        }
        else
        {
            [self.streamStatusLabel setText:@"Not playing"];
        }
    }
	
	//CGFloat newWidth = 320 * (([[[AudioManager shared] audioPlayer] averagePowerInDecibelsForChannel:1] + 60) / 60);
	
	//meter.frame = CGRectMake(0, 460, newWidth, 20);
}





- (void)playStream
{
    [[AudioManager shared] startStream];
}

- (void)stopStream
{
    [[AudioManager shared] stopStream];
}

-(void) updateControls
{
	if ([[AudioManager shared] streamPlaying])
	{
		[self.streamStatusLabel setText:@"Playing"];
	}
	else
	{
		[self.streamStatusLabel setText:@"Not playing"];
	}
    
    [self tick];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    //End recieving events
    [[UIApplication sharedApplication] endReceivingRemoteControlEvents];
    [self resignFirstResponder];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
