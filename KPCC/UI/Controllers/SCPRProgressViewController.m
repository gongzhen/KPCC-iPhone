//
//  SCPRProgressViewController.m
//  KPCC
//
//  Created by Ben Hochberg on 11/6/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "SCPRProgressViewController.h"
#import "Utils.h"
#import "AudioManager.h"

@interface SCPRProgressViewController ()



@end

@implementation SCPRProgressViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

+ (SCPRProgressViewController*)o {
    static SCPRProgressViewController *pv = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        pv = [[SCPRProgressViewController alloc] initWithNibName:@"SCPRProgressViewController"
                                                          bundle:nil];
    });
    return pv;
}

- (void)viewDidLayoutSubviews {
    [self.liveProgressView setNeedsDisplay];
    [self.currentProgressView setNeedsDisplay];
    [self.liveProgressView setNeedsUpdateConstraints];
    [self.currentProgressView setNeedsUpdateConstraints];
}

+ (void)displayWithProgram:(Program*)program onView:(UIViewController *)viewController aboveSiblingView:(UIView *)anchorView {
    
    SCPRProgressViewController *pv = [SCPRProgressViewController o];
    pv.view.frame = pv.view.frame;
    if ( [pv.view superview] )
        [pv.view removeFromSuperview];
    
    
    
    [pv setupProgressBarsWithProgram:program];

    pv.view.clipsToBounds = YES;
    
    CGFloat width = viewController.view.frame.size.width-20.0;
    pv.view.frame = CGRectMake(10.0,anchorView.frame.origin.y-5.0,
                               width,
                               8.0);
    pv.view.backgroundColor = [UIColor clearColor];
    [viewController.view addSubview:pv.view];
    [pv.view layoutIfNeeded];
}

- (void)setupProgressBarsWithProgram:(Program *)program {
    
    self.currentProgram = program;
    self.liveProgressView.progressTintColor = [UIColor lightGrayColor];
    self.liveProgressView.tintColor = [UIColor kpccOrangeColor];
    self.liveProgressView.trackTintColor = [[UIColor cloudColor] translucify:0.22];
    self.currentProgressView.progressTintColor = [UIColor kpccOrangeColor];
    self.currentProgressView.trackTintColor = [[UIColor cloudColor] translucify:0.22];
    
    NSTimeInterval end = [program.ends_at timeIntervalSince1970];
    NSTimeInterval live = [[AudioManager shared].maxSeekableDate timeIntervalSince1970];
    NSTimeInterval current = [[AudioManager shared].currentDate timeIntervalSince1970];
    
    self.liveProgressView.progress = (float) live / end;
    self.currentProgressView.progress = (float) current / end;
    
}

+ (void)rewind {
    SCPRProgressViewController *pv = [SCPRProgressViewController o];
    pv.rewindQueue = [[NSOperationQueue alloc] init];
    [SCPRProgressViewController threadedRewind];
}

+ (void)threadedRewind {

    SCPRProgressViewController *pv = [SCPRProgressViewController o];
    NSLog(@"Progress : %1.2f",pv.currentProgressView.progress);
    
    if ( pv.currentProgressView.progress <= 0.05 ) {
        return;
    }
    NSBlockOperation *block = [NSBlockOperation blockOperationWithBlock:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            float interval = pv.currentProgressView.progress / 50;
            [pv.currentProgressView setProgress:pv.currentProgressView.progress-interval animated:YES];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [SCPRProgressViewController threadedRewind];
            });
        });
    }];
    [pv.rewindQueue addOperation:block];
}

+ (void)tick {
    
    SCPRProgressViewController *pv = [SCPRProgressViewController o];
    Program *program = pv.currentProgram;
    
    NSTimeInterval beginning = [program.starts_at timeIntervalSince1970];
    NSTimeInterval end = [program.ends_at timeIntervalSince1970];
    NSTimeInterval duration = ( end - beginning ) / 60;
    
    NSTimeInterval live = [[AudioManager shared].maxSeekableDate timeIntervalSince1970];
    NSTimeInterval current = [[AudioManager shared].currentDate timeIntervalSince1970];
    
    NSTimeInterval liveDiff = ( live - beginning ) / 60;
    NSTimeInterval currentDiff = ( current - beginning ) / 60;
    
    double currentPtr = (double) ( currentDiff * 1.0f ) / ( duration * 1.0f );
    double livePtr = (double) ( liveDiff * 1.0f ) / ( duration * 1.0f );
    
    NSInteger currentPct = currentPtr * 100;
    NSInteger livePct = livePtr * 100;
    
    double finalLiveProgress = livePct / 100.0f;
    double finalCurrentProgress = currentPct / 100.0f;
    
    if ( finalCurrentProgress == 0.0 || finalLiveProgress == 0.0 ) {
        int x = 1;
        x++;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [pv.liveProgressView setProgress:finalLiveProgress animated:YES];
        [pv.currentProgressView setProgress:finalCurrentProgress animated:YES];
    });

    
}

@end
