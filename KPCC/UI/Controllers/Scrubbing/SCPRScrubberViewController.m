//
//  SCPRScrubberViewController.m
//  KPCC
//
//  Created by Ben Hochberg on 2/9/15.
//  Copyright (c) 2015 SCPR. All rights reserved.
//

#import "SCPRScrubberViewController.h"
#import "SCPRScrubbingUIViewController.h"
#import "DesignManager.h"
#import "AudioManager.h"
#import "Utils.h"
#import "POP.h"
#import "QueueManager.h"

@interface SCPRScrubberViewController ()

@end

@implementation SCPRScrubberViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)setup {
    
    self.scrubberTimeLabel = [self.scrubbingDelegate scrubbingIndicatorLabel];
    self.scrubberTimeLabel.font = [[DesignManager shared] proLight:36.0];
    self.scrubberTimeLabel.textColor = [UIColor whiteColor];
    //self.scrubberTimeLabel.alpha = 0.0;
    self.currentTintColor = [UIColor kpccOrangeColor];
    
    CGFloat width = self.view.frame.size.width;
    CGMutablePathRef currentLinePath = CGPathCreateMutable();
    CGPoint lPts[2];
    lPts[0] = CGPointMake(0.0, 0.0);
    lPts[1] = CGPointMake(width, 0.0);
    CGPathAddLines(currentLinePath, nil, lPts, 2);
    
    self.currentBarLine = [CAShapeLayer layer];
    self.currentBarLine.path = currentLinePath;
    self.currentBarLine.strokeColor = self.currentTintColor.CGColor;
    self.currentBarLine.strokeStart = 0.0;
    self.currentBarLine.strokeEnd = 0.0;
    self.currentBarLine.opacity = 1.0;
    self.currentBarLine.fillColor = self.currentTintColor.CGColor;
    self.currentBarLine.lineWidth = self.view.frame.size.height*2;
    
    [self.view.layer addSublayer:self.currentBarLine];
    
    self.cloak = [[UIView alloc] initWithFrame:CGRectMake(0.0, self.view.frame.size.height-1.0, self.view.frame.size.width,
                                                          1.0)];
    self.cloak.backgroundColor = [UIColor blackColor];
    [self.view.layer setMask:self.cloak.layer];
    
    self.view.userInteractionEnabled = YES;
    self.viewAsTouchableScrubberView.parentScrubberController = self;
    
}

- (void)unmask {

    self.cloak.frame = CGRectMake(0.0, 0.0, self.view.frame.size.width,
                                      self.view.frame.size.height);
    
}

- (void)applyMask {
    
    self.cloak.frame = CGRectMake(0.0, self.view.frame.size.height-1.0, self.view.frame.size.width,
                                  1.0);
}

- (void)userTouched:(NSSet *)touches event:(UIEvent *)event {
    self.firstTouch = [(UITouch*)[touches anyObject] locationInView:self.view];
    [self trackForPoint:self.firstTouch];
    self.panning = YES;
}

- (void)userPanned:(NSSet *)touches event:(UIEvent *)event {
    
    CGPoint deltaPoint = [(UITouch*)[touches anyObject] locationInView:self.view];
    [self trackForPoint:deltaPoint];
    
}

- (void)userLifted:(NSSet *)touches event:(UIEvent *)event {
    self.firstTouch = CGPointZero;
    self.trulyFinishedTimer = [NSTimer scheduledTimerWithTimeInterval:0.15
                                                               target:self
                                                             selector:@selector(userFinishedScrubbing)
                                                             userInfo:nil
                                                              repeats:NO];
}

- (void)trackForPoint:(CGPoint)touchPoint {
    CGFloat dX = touchPoint.x;
    double se = ( dX / self.view.frame.size.width )*1.0f;
    self.currentBarLine.strokeEnd = se;
    [self.scrubbingDelegate actionOfInterestWithPercentage:(CGFloat)se];
}

- (void)userFinishedScrubbing {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.scrubbingDelegate actionOfInterestAfterScrub:self.currentBarLine.strokeEnd];
        self.panning = NO;
    });
}


- (void)tick:(CGFloat)amount {
    
    if ( self.panning ) return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.currentBarLine.strokeEnd = amount;
    });
}


- (void)expand {
    POPSpringAnimation *scaleAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerScaleXY];
    scaleAnimation.fromValue  = [NSValue valueWithCGSize:CGSizeMake(0.0f, 0.0f)];
    scaleAnimation.toValue  = [NSValue valueWithCGSize:CGSizeMake(1.0f, 1.0f)];
    scaleAnimation.springBounciness = 1.0f;
    scaleAnimation.springSpeed = .5f;
    [scaleAnimation setCompletionBlock:^(POPAnimation *a, BOOL f) {
        
    }];
    
    
    [self.scrubberTimeLabel pop_addAnimation:scaleAnimation forKey:@"expanding"];
    self.expanded = YES;
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
