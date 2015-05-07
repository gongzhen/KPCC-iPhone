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

- (void)setupWithDelegate:(id<Scrubbable>)delegate {
    [self setupWithDelegate:delegate circular:NO];
}

- (void)setupWithDelegate:(id<Scrubbable>)delegate circular:(BOOL)circular {
    
    
#ifndef SHOW_ANGLE
    [self.radiusTerminusView removeFromSuperview];
    [self.degreesLabel removeFromSuperview];
#else
    self.radiusTerminusView.layer.cornerRadius = self.radiusTerminusView.frame.size.width / 2.0;
    self.radiusTerminusView.clipsToBounds = YES;
    self.radiusTerminusView.layer.borderColor = [UIColor blackColor].CGColor;
    self.radiusTerminusView.layer.borderWidth = 1.0f;
#endif
    
    self.scrubbingDelegate = delegate;
    self.viewAsTouchableScrubberView = [delegate scrubbableView];
    self.scrubberTimeLabel = [self.scrubbingDelegate scrubbingIndicatorLabel];
    self.scrubberTimeLabel.font = [[DesignManager shared] proLight:self.scrubberTimeLabel.font.pointSize];
    self.scrubberTimeLabel.textColor = [UIColor whiteColor];
    self.currentTintColor = [UIColor kpccOrangeColor];
    self.circular = circular;
    
    [self.view layoutIfNeeded];
    
    CGFloat width = self.viewAsTouchableScrubberView.frame.size.width;
    NSLog(@"Scrubber Thinks the Width is %1.1f",width);
    CGMutablePathRef currentLinePath = CGPathCreateMutable();
    CGFloat lineWidth = 0.0;
    if ( !circular ) {
        lineWidth = self.view.frame.size.height*2.0f;
        CGPoint lPts[2];
        lPts[0] = CGPointMake(0.0, 0.0);
        lPts[1] = CGPointMake(width, 0.0);
        CGPathAddLines(currentLinePath, nil, lPts, 2);
    } else {
        
        lineWidth = self.view.frame.size.height / 4.0f;
        self.containerTintColor = [[UIColor virtualWhiteColor] translucify:0.25];
 
        CGPoint arcCenter = CGPointMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds));
        CGFloat radius = CGRectGetMidX(self.view.bounds)-(lineWidth / 2.0f);
        CGFloat startAngle = -M_PI_2;
        CGFloat endAngle = 2*M_PI-M_PI_2;
        
        //CGFloat startAngle = [Utils degreesToRadians:-90.0f];
        //CGFloat endAngle = [Utils degreesToRadians:270.0f];
        
        UIBezierPath *circlePath = [UIBezierPath bezierPathWithArcCenter:arcCenter
                                                         radius:radius
                                                     startAngle:startAngle
                                                       endAngle:endAngle
                                                      clockwise:YES];
        currentLinePath = CGPathCreateMutableCopy(circlePath.CGPath);
        
        UIBezierPath *circleSeatPath = [UIBezierPath bezierPathWithArcCenter:arcCenter
                                                                      radius:radius
                                                                  startAngle:startAngle
                                                                    endAngle:endAngle
                                                                   clockwise:YES];
        
        CGMutablePathRef seatLinePath = CGPathCreateMutableCopy(circleSeatPath.CGPath);
        
        self.containerBarLine = [CAShapeLayer layer];
        self.containerBarLine.path = seatLinePath;
        self.containerBarLine.strokeColor = self.containerTintColor.CGColor;
        self.containerBarLine.strokeStart = 0.0;
        self.containerBarLine.strokeEnd = 1.0;
        self.containerBarLine.opacity = 1.0;
        self.containerBarLine.fillColor = [UIColor clearColor].CGColor;
        self.containerBarLine.lineWidth = lineWidth;
        self.view.backgroundColor = [UIColor clearColor];
        [self.view.layer addSublayer:self.containerBarLine];
        
    }
    
    self.currentBarLine = [CAShapeLayer layer];
    self.currentBarLine.path = currentLinePath;
    self.currentBarLine.strokeColor = self.currentTintColor.CGColor;
    self.currentBarLine.strokeStart = 0.0;
    self.currentBarLine.strokeEnd = 0.0;
    self.currentBarLine.opacity = 1.0;
    self.currentBarLine.fillColor = [UIColor clearColor].CGColor;
    self.currentBarLine.lineWidth = lineWidth;
    
    [self.view.layer addSublayer:self.currentBarLine];
    
    self.cloak = [[UIView alloc] initWithFrame:CGRectMake(0.0, self.view.frame.size.height-1.0, self.view.frame.size.width,
                                                          1.0)];
    self.cloak.backgroundColor = [UIColor blackColor];
    [self.view.layer setMask:self.cloak.layer];
    
    self.view.userInteractionEnabled = YES;
    self.viewAsTouchableScrubberView.parentScrubberController = self;
    
    self.view.backgroundColor = circular ? [UIColor clearColor] : [[UIColor virtualWhiteColor] translucify:0.2];
}

- (void)applyPercentageToScrubber:(CGFloat)percentage {
    [UIView animateWithDuration:0.33 animations:^{
        self.currentBarLine.strokeEnd = percentage;
    }];
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
    self.previousPoint = self.firstTouch;
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
    self.nowPoint = touchPoint;
    CGFloat dX = touchPoint.x;
    CGFloat basis = self.view.frame.size.width;
    double se = 0.0f;
    if ( self.circular ) {
        
#ifdef USE_ATAN2
        CGPoint zeroDegrees = CGPointMake(self.view.frame.size.width/2.0f,
                                          0.0f);
        CGPoint xp = [self extendPoint:touchPoint toEdge:zeroDegrees];
        CGFloat xDelta = xp.x - zeroDegrees.x;
        CGFloat yDelta = xp.y - zeroDegrees.y;
        CGFloat degrees = 2*[Utils radiansToDegrees:atan2(yDelta, xDelta)];
        NSLog(@"%1.1f°",degrees);
        if ( degrees <= 0.0f ) {
            degrees = 360.0f;
        }
        se = degrees / 360.0f;
#else
        CGPoint origin = CGPointMake(self.view.frame.size.width / 2.0f,
                                     self.view.frame.size.height / 2.0f);
        CGPoint zeroDegrees = CGPointMake(self.view.frame.size.width/2.0f,
                                          0.0f);
        
        CGFloat ui = origin.x - zeroDegrees.x;
        CGFloat uj = origin.y - zeroDegrees.y;
        
        CGPoint xp = [self extendPoint:touchPoint toEdge:zeroDegrees];
        CGFloat vi = xp.x - origin.x;
        CGFloat vj = origin.y - xp.y;
        
        CGFloat dotProduct = ui*vi + uj*vj;
        
        CGFloat uLength = sqrtf((ui*ui)+(uj*uj));
        CGFloat vLength = sqrtf((vi*vi)+(vj*vj));
        
        CGFloat radians = acosf(dotProduct / ( uLength * vLength));
        CGFloat degrees = [Utils radiansToDegrees:radians];
        if ( xp.x < origin.x ) {
            // Out of position angle (0 -> π)
            degrees = 180.f + (180.f - degrees);
        }
        
        se = degrees / 360.f;
        
#endif
#ifdef SHOW_ANGLE
        self.radiusTerminusView.center = xp;
        self.degreesLabel.text = [NSString stringWithFormat:@"%1.1f°",degrees];
        [self.view setNeedsDisplay];
#endif
        
    } else {
        se = ( dX / basis )*1.0f;
        CGFloat max = [self.scrubbingDelegate maxPercentage];
        se = fminf(max, se);
    }
    
    self.currentBarLine.strokeEnd = se;
    [self.scrubbingDelegate actionOfInterestWithPercentage:(CGFloat)se];
}

- (CGPoint)extendPoint:(CGPoint)touchPoint toEdge:(CGPoint)bound {
    CGPoint origin = CGPointMake(self.view.frame.size.width / 2.0,
                                 self.view.frame.size.height / 2.0);
    CGFloat slopeNumerator = touchPoint.y - origin.y;
    CGFloat slopeDenom = touchPoint.x - origin.x;
    
    
    CGPoint extendedPoint = touchPoint;
    CGFloat currX = extendedPoint.x;
    CGFloat currY = extendedPoint.y;
    while ((currX <= self.view.frame.size.width && currX >= 0.0f) &&
           (currY >= 0.0f && currY <= self.view.frame.size.height) ) {
        currX = extendedPoint.x;
        currY = extendedPoint.y;
        currX = currX + slopeDenom;
        currY = currY + slopeNumerator;
        extendedPoint = CGPointMake(currX, currY);
    }
    
    if ( currY > self.view.frame.size.height ) {
        currY = self.view.frame.size.height;
    }
    if ( currY < 0.0f ) {
        currY = 0.0f;
    }
    if ( currX > self.view.frame.size.width ) {
        currX = self.view.frame.size.width;
    }
    if ( currX < 0.0f ) {
        currX = 0.0f;
    }
    
    extendedPoint = CGPointMake(currX, currY);
    
    NSLog(@"Old Point {%1.1fx, %1.1fy}, New Point {%1.1fx, %1.1fy}",touchPoint.x,touchPoint.y,
     extendedPoint.x,extendedPoint.y);
    
    return extendedPoint;
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
