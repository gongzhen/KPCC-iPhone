//
//  SCPRPreRollViewController.h
//  KPCC
//
//  Created by John Meeker on 10/14/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Crashlytics/Crashlytics.h>
#import <Lock/Lock.h>
#import "AudioAd.h"
#import "SCPRAppDelegate.h"
#import "KPCC-Swift.h"

@import AVFoundation;

@protocol SCPRPreRollControllerDelegate <NSObject>

- (void)preRollStartedPlaying;
- (void)preRollCompleted;

@end

@interface SCPRPreRollViewController : UIViewController

- (void)showPreRollWithAnimation:(BOOL)animated completion:(void (^)(BOOL done))completion;
- (void)primeUI:(Block)completed;
- (void)playOrPause;

@property (nonatomic, strong) UITapGestureRecognizer *adTapper;
@property (nonatomic,weak) id<SCPRPreRollControllerDelegate> delegate;
@property (nonatomic,strong) AudioAd *audioAd;
@property (nonatomic,strong) IBOutlet UIImageView *adImageView;
@property (nonatomic,strong) IBOutlet UIView *curtainView;

@property (nonatomic,strong) AudioPlayer *prerollPlayer;
@property (nonatomic, strong) id timeObserver;

@end
