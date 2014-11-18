//
//  SCPRMenuButton.m
//  KPCC
//
//  Created by John Meeker on 9/4/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "SCPRMenuButton.h"
#import <POP/POP.h>

@interface SCPRMenuButton()
@property(nonatomic) CALayer *topLayer;
@property(nonatomic) CALayer *middleLayer;
@property(nonatomic) CALayer *bottomLayer;
@property(nonatomic) CALayer *backArrowTopLayer;
@property(nonatomic) CALayer *backArrowBottomLayer;

- (void)touchUpInsideHandler:(SCPRMenuButton *)sender;
- (void)animateToMenu;
- (void)animateToClose;
- (void)animateToBack;
- (void)setup;
- (void)removeAllAnimations;
@end

@implementation SCPRMenuButton

@synthesize delegate;

+ (instancetype)button {
    return [self buttonWithOrigin:CGPointZero];
}

+ (instancetype)buttonWithOrigin:(CGPoint)origin {
    return [[self alloc] initWithFrame:CGRectMake(origin.x,
                                                  origin.y,
                                                  40,
                                                  26)];
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setup];
    }
    return self;
}

#pragma mark - Instance methods

- (void)tintColorDidChange {
    CGColorRef color = [self.tintColor CGColor];
    self.topLayer.backgroundColor = color;
    self.middleLayer.backgroundColor = color;
    self.bottomLayer.backgroundColor = color;
}

#pragma mark - Private Instance methods

- (void)animateToMenu {
    [self removeAllAnimations];

    CGFloat height = CGRectGetHeight(self.topLayer.bounds);

    POPBasicAnimation *fadeAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    fadeAnimation.duration = 0.3;
    fadeAnimation.toValue = @1;

    POPBasicAnimation *positionTopAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerPosition];
    positionTopAnimation.duration = 0.3;
    positionTopAnimation.toValue = [NSValue valueWithCGPoint:CGPointMake(12,
                                                                         roundf(4+(height/2)))];

    POPBasicAnimation *positionBottomAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerPosition];
    positionTopAnimation.duration = 0.3;
    positionBottomAnimation.toValue = [NSValue valueWithCGPoint:CGPointMake(12,
                                                                            roundf(22-(height/2)))];

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

    if (self.showBackArrow) {
        POPSpringAnimation *scaleTopAnimation = [POPSpringAnimation animation];
        scaleTopAnimation.property = [POPAnimatableProperty propertyWithName:kPOPLayerBounds];
        scaleTopAnimation.toValue = [NSValue valueWithCGRect:CGRectMake(0, 0, 24, 1)];

        POPSpringAnimation *scaleBottomAnimation = [POPSpringAnimation animation];
        scaleBottomAnimation.property = [POPAnimatableProperty propertyWithName:kPOPLayerBounds];
        scaleBottomAnimation.toValue = [NSValue valueWithCGRect:CGRectMake(0, 0, 24, 1)];

        [self.topLayer pop_addAnimation:scaleTopAnimation forKey:@"scaleTopAnimation"];
        [self.bottomLayer pop_addAnimation:scaleBottomAnimation forKey:@"scaleBottomAnimation"];
        self.showBackArrow = NO;
    }

    [self.topLayer pop_addAnimation:positionTopAnimation forKey:@"positionTopAnimation"];
    [self.topLayer pop_addAnimation:transformTopAnimation forKey:@"rotateTopAnimation"];
    [self.middleLayer pop_addAnimation:fadeAnimation forKey:@"fadeAnimation"];
    [self.bottomLayer pop_addAnimation:positionBottomAnimation forKey:@"positionBottomAnimation"];
    [self.bottomLayer pop_addAnimation:transformBottomAnimation forKey:@"rotateBottomAnimation"];

    self.showMenu = YES;
}

- (void)animateToClose {
    [self removeAllAnimations];
    CGPoint center = CGPointMake(12, CGRectGetMidY(self.bounds));

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

    if (self.showBackArrow) {
        POPSpringAnimation *scaleTopAnimation = [POPSpringAnimation animation];
        scaleTopAnimation.property = [POPAnimatableProperty propertyWithName:kPOPLayerBounds];
        scaleTopAnimation.toValue = [NSValue valueWithCGRect:CGRectMake(0, 0, 24, 1)];

        POPSpringAnimation *scaleBottomAnimation = [POPSpringAnimation animation];
        scaleBottomAnimation.property = [POPAnimatableProperty propertyWithName:kPOPLayerBounds];
        scaleBottomAnimation.toValue = [NSValue valueWithCGRect:CGRectMake(0, 0, 24, 1)];

        [self.topLayer pop_addAnimation:scaleTopAnimation forKey:@"scaleTopAnimation"];
        [self.bottomLayer pop_addAnimation:scaleBottomAnimation forKey:@"scaleBottomAnimation"];
        self.showBackArrow = NO;
    }

    [self.topLayer pop_addAnimation:positionTopAnimation forKey:@"positionTopAnimation"];
    [self.topLayer pop_addAnimation:transformTopAnimation forKey:@"rotateTopAnimation"];
    [self.middleLayer pop_addAnimation:fadeAnimation forKey:@"fadeAnimation"];
    [self.bottomLayer pop_addAnimation:positionBottomAnimation forKey:@"positionBottomAnimation"];
    [self.bottomLayer pop_addAnimation:transformBottomAnimation forKey:@"rotateBottomAnimation"];

    self.showMenu = NO;
}

- (void)animateToBack {
    [self removeAllAnimations];
    CGPoint topLeft = CGPointMake(CGRectGetMinX(self.bounds)+4, CGRectGetMidY(self.bounds)-4);
    CGPoint bottomLeft = CGPointMake(CGRectGetMinX(self.bounds)+4, CGRectGetMidY(self.bounds)+4);

    POPBasicAnimation *fadeAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    fadeAnimation.toValue = @1;
    fadeAnimation.duration = 0.3;

    POPBasicAnimation *positionTopAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerPosition];
    positionTopAnimation.toValue = [NSValue valueWithCGPoint:topLeft];
    positionTopAnimation.duration = 0.3;

    POPSpringAnimation *scaleTopAnimation = [POPSpringAnimation animation];
    scaleTopAnimation.property = [POPAnimatableProperty propertyWithName:kPOPLayerBounds];
    scaleTopAnimation.toValue = [NSValue valueWithCGRect:CGRectMake(0, 0, 12, 1)];

    POPBasicAnimation *positionBottomAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerPosition];
    positionBottomAnimation.toValue = [NSValue valueWithCGPoint:bottomLeft];
    positionTopAnimation.duration = 0.3;

    POPSpringAnimation *scaleBottomAnimation = [POPSpringAnimation animation];
    scaleBottomAnimation.property = [POPAnimatableProperty propertyWithName:kPOPLayerBounds];
    scaleBottomAnimation.toValue = [NSValue valueWithCGRect:CGRectMake(0, 0, 12, 1)];

    POPSpringAnimation *transformTopAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerRotation];
    transformTopAnimation.toValue = @(-M_PI_4);
    transformTopAnimation.springBounciness = 20.f;
    transformTopAnimation.springSpeed = 20;
    transformTopAnimation.dynamicsTension = 1000;

    POPSpringAnimation *transformBottomAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerRotation];
    transformBottomAnimation.toValue = @(M_PI_4);
    transformBottomAnimation.springBounciness = 20.0f;
    transformBottomAnimation.springSpeed = 20;
    transformBottomAnimation.dynamicsTension = 1000;

    [self.topLayer pop_addAnimation:positionTopAnimation forKey:@"positionTopAnimation"];
    [self.topLayer pop_addAnimation:transformTopAnimation forKey:@"rotateTopAnimation"];
    [self.topLayer pop_addAnimation:scaleTopAnimation forKey:@"scaleTopAnimation"];
    [self.middleLayer pop_addAnimation:fadeAnimation forKey:@"fadeAnimation"];
    [self.bottomLayer pop_addAnimation:positionBottomAnimation forKey:@"positionBottomAnimation"];
    [self.bottomLayer pop_addAnimation:transformBottomAnimation forKey:@"rotateBottomAnimation"];
    [self.bottomLayer pop_addAnimation:scaleBottomAnimation forKey:@"scaleBottomAnimation"];

    self.showBackArrow = YES;
}

- (void)animateToPop:(id<MenuButtonDelegate>)proxyDelegate {
    [self removeAllAnimations];
    CGPoint topLeft = CGPointMake(CGRectGetMinX(self.bounds)+4, CGRectGetMidY(self.bounds)-4);
    CGPoint bottomLeft = CGPointMake(CGRectGetMinX(self.bounds)+4, CGRectGetMidY(self.bounds)+4);
    
    POPBasicAnimation *fadeAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    fadeAnimation.toValue = @0;
    fadeAnimation.duration = 0.3;
    
    POPBasicAnimation *positionTopAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerPosition];
    positionTopAnimation.toValue = [NSValue valueWithCGPoint:topLeft];
    positionTopAnimation.duration = 0.3;
    
    POPSpringAnimation *scaleTopAnimation = [POPSpringAnimation animation];
    scaleTopAnimation.property = [POPAnimatableProperty propertyWithName:kPOPLayerBounds];
    scaleTopAnimation.toValue = [NSValue valueWithCGRect:CGRectMake(0, 0, 12, 1)];
    
    POPBasicAnimation *positionBottomAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerPosition];
    positionBottomAnimation.toValue = [NSValue valueWithCGPoint:bottomLeft];
    positionTopAnimation.duration = 0.3;
    
    POPSpringAnimation *scaleBottomAnimation = [POPSpringAnimation animation];
    scaleBottomAnimation.property = [POPAnimatableProperty propertyWithName:kPOPLayerBounds];
    scaleBottomAnimation.toValue = [NSValue valueWithCGRect:CGRectMake(0, 0, 12, 1)];
    
    POPSpringAnimation *transformTopAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerRotation];
    transformTopAnimation.toValue = @(-M_PI_4);
    transformTopAnimation.springBounciness = 20.f;
    transformTopAnimation.springSpeed = 20;
    transformTopAnimation.dynamicsTension = 1000;
    
    POPSpringAnimation *transformBottomAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerRotation];
    transformBottomAnimation.toValue = @(M_PI_4);
    transformBottomAnimation.springBounciness = 20.0f;
    transformBottomAnimation.springSpeed = 20;
    transformBottomAnimation.dynamicsTension = 1000;
    
    [self.topLayer pop_addAnimation:positionTopAnimation forKey:@"positionTopAnimation"];
    [self.topLayer pop_addAnimation:transformTopAnimation forKey:@"rotateTopAnimation"];
    [self.topLayer pop_addAnimation:scaleTopAnimation forKey:@"scaleTopAnimation"];
    [self.middleLayer pop_addAnimation:fadeAnimation forKey:@"fadeAnimation"];
    [self.bottomLayer pop_addAnimation:positionBottomAnimation forKey:@"positionBottomAnimation"];
    [self.bottomLayer pop_addAnimation:transformBottomAnimation forKey:@"rotateBottomAnimation"];
    [self.bottomLayer pop_addAnimation:scaleBottomAnimation forKey:@"scaleBottomAnimation"];
    
    self.showBackArrow = NO;
    self.showPopArrow = YES;
    self.proxyDelegate = proxyDelegate;
}

- (void)touchUpInsideHandler:(SCPRMenuButton *)sender {
    if (self.showBackArrow) {
        [delegate backPressed];
    } else if ( self.showPopArrow && self.proxyDelegate ) {
        [self.proxyDelegate popPressed];
        self.showPopArrow = NO;
        self.proxyDelegate = nil;
    } else {
        [delegate menuPressed];
    }
}

- (void)setup {
    CGFloat height = 1.f;
    CGFloat width = 24.f;
    CGFloat cornerRadius =  1.f;
    CGColorRef color = [self.tintColor CGColor];

    self.topLayer = [CALayer layer];
    self.topLayer.frame = CGRectMake(0, CGRectGetMinY(self.bounds) + 4, width, height);
    self.topLayer.cornerRadius = cornerRadius;
    self.topLayer.backgroundColor = color;

    self.middleLayer = [CALayer layer];
    self.middleLayer.frame = CGRectMake(0, CGRectGetMidY(self.bounds)-(height/2), width, height);
    self.middleLayer.cornerRadius = cornerRadius;
    self.middleLayer.backgroundColor = color;

    self.bottomLayer = [CALayer layer];
    self.bottomLayer.frame = CGRectMake(0, CGRectGetMaxY(self.bounds)-height - 4, width, height);
    self.bottomLayer.cornerRadius = cornerRadius;
    self.bottomLayer.backgroundColor = color;

    [self.layer addSublayer:self.topLayer];
    [self.layer addSublayer:self.middleLayer];
    [self.layer addSublayer:self.bottomLayer];

    [self addTarget:self
             action:@selector(touchUpInsideHandler:)
   forControlEvents:UIControlEventTouchUpInside];

    self.showMenu = YES;
}

- (void)removeAllAnimations {
    [self.topLayer pop_removeAllAnimations];
    [self.middleLayer pop_removeAllAnimations];
    [self.bottomLayer pop_removeAllAnimations];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
