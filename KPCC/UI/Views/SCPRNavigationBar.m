//
//  SCPRNavigationBar.m
//  KPCC
//
//  Created by John Meeker on 6/27/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "SCPRNavigationBar.h"
#import <POP/POP.h>

@interface SCPRNavigationBar()
@property(nonatomic) CALayer *topLayer;
@property(nonatomic) CALayer *middleLayer;
@property(nonatomic) CALayer *bottomLayer;
@property(nonatomic) BOOL showMenu;

- (void)touchUpInsideHandler:(SCPRNavigationBar *)sender;
- (void)animateToMenu;
- (void)animateToClose;
- (void)setup;
- (void)removeAllAnimations;
@end

@implementation SCPRNavigationBar

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        // Initialization code
        [self setup];
    }
    
    return self;
}

- (void)didSwipeDown {
    NSLog(@"didSwipeDown");
}

- (IBAction)handleTap {
    NSLog(@"didTap");
}

- (void)animateToMenu {
    [self removeAllAnimations];
    
    CGFloat height = CGRectGetHeight(self.topLayer.bounds);
    
    POPBasicAnimation *fadeAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    fadeAnimation.duration = 0.3;
    fadeAnimation.toValue = @1;
    
    POPBasicAnimation *positionTopAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerPosition];
    positionTopAnimation.duration = 0.3;
    positionTopAnimation.toValue = [NSValue valueWithCGPoint:CGPointMake(CGRectGetMidX(self.bounds) + 62.0f,
                                                                         roundf(CGRectGetMinY(self.bounds)+(height/2)) + 13.0f )];
    
    POPBasicAnimation *positionBottomAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerPosition];
    positionBottomAnimation.duration = 0.3;
    positionBottomAnimation.toValue = [NSValue valueWithCGPoint:CGPointMake(CGRectGetMidX(self.bounds) + 62.0f,
                                                                            roundf(CGRectGetMaxY(self.bounds)-(height/2)) - 13.0f )];
    
    POPSpringAnimation *transformTopAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerRotation];
    transformTopAnimation.toValue = @(0);
    transformTopAnimation.springBounciness = 20.f;
    transformTopAnimation.springSpeed = 20;
    transformTopAnimation.dynamicsTension = 1000;
    
    POPSpringAnimation *transformBottomAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerRotation];
    transformBottomAnimation.toValue = @(0);
    transformBottomAnimation.springBounciness = 20.0f;
    transformBottomAnimation.springSpeed = 20;
    transformBottomAnimation.dynamicsTension = 1000;
    
    [self.topLayer pop_addAnimation:positionTopAnimation forKey:@"positionTopAnimation"];
    [self.topLayer pop_addAnimation:transformTopAnimation forKey:@"rotateTopAnimation"];
    [self.middleLayer pop_addAnimation:fadeAnimation forKey:@"fadeAnimation"];
    [self.bottomLayer pop_addAnimation:positionBottomAnimation forKey:@"positionBottomAnimation"];
    [self.bottomLayer pop_addAnimation:transformBottomAnimation forKey:@"rotateBottomAnimation"];
}

- (void)animateToClose {
    [self removeAllAnimations];
    CGPoint center = CGPointMake(CGRectGetMidX(self.bounds) + 60.0f, CGRectGetMidY(self.bounds));
    
    POPBasicAnimation *fadeAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    fadeAnimation.toValue = @0;
    fadeAnimation.duration = 0.3;
    
    POPBasicAnimation *positionTopAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerPosition];
    positionTopAnimation.toValue = [NSValue valueWithCGPoint:center];
    positionTopAnimation.duration = 0.3;
    
    POPBasicAnimation *positionBottomAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerPosition];
    positionBottomAnimation.toValue = [NSValue valueWithCGPoint:center];
    positionTopAnimation.duration = 0.3;
    
    POPSpringAnimation *transformTopAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerRotation];
    transformTopAnimation.toValue = @(M_PI_4);
    transformTopAnimation.springBounciness = 20.f;
    transformTopAnimation.springSpeed = 20;
    transformTopAnimation.dynamicsTension = 1000;
    
    POPSpringAnimation *transformBottomAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerRotation];
    transformBottomAnimation.toValue = @(-M_PI_4);
    transformBottomAnimation.springBounciness = 20.0f;
    transformBottomAnimation.springSpeed = 20;
    transformBottomAnimation.dynamicsTension = 1000;
    
    [self.topLayer pop_addAnimation:positionTopAnimation forKey:@"positionTopAnimation"];
    [self.topLayer pop_addAnimation:transformTopAnimation forKey:@"rotateTopAnimation"];
    [self.middleLayer pop_addAnimation:fadeAnimation forKey:@"fadeAnimation"];
    [self.bottomLayer pop_addAnimation:positionBottomAnimation forKey:@"positionBottomAnimation"];
    [self.bottomLayer pop_addAnimation:transformBottomAnimation forKey:@"rotateBottomAnimation"];
}

- (void)touchUpInsideHandler:(SCPRNavigationBar *)sender {
    if (self.showMenu) {
        [self animateToMenu];
    } else {
        [self animateToClose];
    }
    self.showMenu = !self.showMenu;
}

- (void)setup {
    CGFloat height = 2.f;
    CGFloat width = CGRectGetWidth(self.bounds);
    CGFloat cornerRadius =  0.5f;
    CGColorRef color = [self.tintColor CGColor];
    CGRect bounds = self.topItem.titleView.bounds;

    self.topLayer = [CALayer layer];
    self.topLayer.frame = CGRectMake(CGRectGetMidX(self.bounds) + 54.0f, CGRectGetMinY(self.bounds) + 13.0f, 16.0f, height);
    self.topLayer.cornerRadius = cornerRadius;
    self.topLayer.backgroundColor = color;

    self.middleLayer = [CALayer layer];
    self.middleLayer.frame = CGRectMake(CGRectGetMidX(self.bounds) + 54.0f, CGRectGetMidY(self.bounds)-(height/2), 16.0f, height);
    self.middleLayer.cornerRadius = cornerRadius;
    self.middleLayer.backgroundColor = color;

    self.bottomLayer = [CALayer layer];
    self.bottomLayer.frame = CGRectMake(CGRectGetMidX(self.bounds) + 54.0f, CGRectGetMaxY(self.bounds)-height - 13.0f, 16.0f, height);
    self.bottomLayer.cornerRadius = cornerRadius;
    self.bottomLayer.backgroundColor = color;
    
    [self.layer addSublayer:self.topLayer];
    [self.layer addSublayer:self.middleLayer];
    [self.layer addSublayer:self.bottomLayer];
    
    UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(touchUpInsideHandler:)];
    [tapRecognizer setNumberOfTapsRequired:1];
    [self addGestureRecognizer:tapRecognizer];
    
    
    UISwipeGestureRecognizer *swipeDown;
    swipeDown = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(didSwipeDown)];
    [swipeDown setDirection:UISwipeGestureRecognizerDirectionDown];
    [swipeDown setNumberOfTouchesRequired:1];
    [swipeDown setEnabled:YES];
    [self addGestureRecognizer:swipeDown];
}

- (void)removeAllAnimations {
    [self.topLayer pop_removeAllAnimations];
    [self.middleLayer pop_removeAllAnimations];
    [self.bottomLayer pop_removeAllAnimations];
}

@end
