//
//  SCPRSlideInTransition.m
//  KPCC
//
//  Created by John Meeker on 10/6/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "SCPRSlideInTransition.h"

@implementation SCPRSlideInTransition

- (NSTimeInterval)transitionDuration:(id <UIViewControllerContextTransitioning>)transitionContext
{
    return 0.25;
}

- (void)animateTransition:(id<UIViewControllerContextTransitioning>)transitionContext
{
    UIViewController* toViewController = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    UIViewController* fromViewController = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    [[transitionContext containerView] addSubview:toViewController.view];
    toViewController.view.alpha = 0;
    
    [UIView animateWithDuration:[self transitionDuration:transitionContext] animations:^{
        fromViewController.view.transform = CGAffineTransformMakeScale(0.1, 0.1);
        toViewController.view.alpha = 1;
    } completion:^(BOOL finished) {
        fromViewController.view.transform = CGAffineTransformIdentity;
        [transitionContext completeTransition:![transitionContext transitionWasCancelled]];
        
    }];
    
}

//- (void)animateFromView:(UIView *)fromView
//                 toView:(UIView *)toView
//        inContainerView:(UIView *)containerView
//    executeOnCompletion:(void (^)(BOOL))onCompletion {
//    toView.alpha = 0.0f;
//    
//    CGFloat offsetX = CGRectGetWidth(containerView.bounds) / 2.5f;
//  
////    toView.layer.transform = !self.isReversed ? [self rotatedRightToX:offsetX] : [self rotatedLeftToX:offsetX];
//    
//    [containerView addSubview:toView];
//    
//    [UIView animateWithDuration:self.transitionDuration
//                     animations:
//     ^{
//         fromView.alpha = 0.0f;
//         toView.alpha = 1.0f;
//         
////         fromView.layer.transform = !self.isReversed ? [self rotatedLeftToX:offsetX] : [self rotatedRightToX:offsetX];
//         toView.layer.transform = CATransform3DIdentity;
//     }
//                     completion:
//     ^(BOOL finished) {
//         onCompletion(finished);
//         
//         fromView.alpha = 1.0f;
//         toView.alpha = 1.0f;
//         
//         fromView.layer.transform = CATransform3DIdentity;
//         toView.layer.transform = CATransform3DIdentity;
//     }];
//}

- (CATransform3D)rotatedLeftToX:(CGFloat)offsetX {
    CATransform3D rotateNegatively = CATransform3DMakeRotation(-M_PI_2, 0, 1, 0);
    CATransform3D moveLeft = CATransform3DMakeTranslation(-offsetX, 0, 0);
    return CATransform3DConcat(rotateNegatively, moveLeft);
}

- (CATransform3D)rotatedRightToX:(CGFloat)offsetX {
    CATransform3D rotatePositively = CATransform3DMakeRotation(M_PI_2, 0, 1, 0);
    CATransform3D moveRight = CATransform3DMakeTranslation(offsetX, 0, 0);
    return CATransform3DConcat(rotatePositively, moveRight);
}

@end

