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
    NSTimeInterval duration = [self transitionDuration:transitionContext];
    UIView* inView = [transitionContext containerView];
    
    UIViewController* toViewController = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    UIViewController* fromViewController = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];

    CGPoint centerOffScreen;
    CGRect frameOffScreen;
    CGRect frameInScreen;
    CGRect destinationOffScreen;
    CGRect menuFrameOffScreen;
    CGRect menuFrameInScreen;

    // Grab reference to Menu
    UIView *menuView;
    if ([inView viewWithTag:893] != nil) {
        menuView = [inView viewWithTag:893];
    }

    // Get a UIImage screenshot with the Menu hidden
    menuView.hidden = YES;
    UIGraphicsBeginImageContextWithOptions(fromViewController.view.bounds.size, fromViewController.view.opaque, 0.0);
    [fromViewController.view.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *viewImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    menuView.hidden = NO;

    // Place the UIImage in a UIImageView
    UIImageView *newView = [[UIImageView alloc] initWithFrame:toViewController.view.bounds];
    newView.image = viewImage;

    UIImageView *reverseNewView = [[UIImageView alloc] initWithImage:viewImage];
//    UIView *reverseNewView = [[UIView alloc] initWithFrame:toViewController.view.bounds];
//    reverseNewView.backgroundColor = [UIColor greenColor];

    // Add the image to the background of the Programs view controller.
    //[toViewController.view addSubview:newView];
    //[toViewController.view sendSubviewToBack:newView];
    

    
    
    if( [self.direction isEqualToString:@"leftToRight"] ){
        [inView insertSubview:toViewController.view aboveSubview:fromViewController.view];
        
        centerOffScreen = inView.center;
        centerOffScreen.x = (-1)*inView.frame.size.width;
        
        frameOffScreen = inView.frame;
        frameOffScreen.origin.x = inView.frame.size.width;
        
        frameInScreen = inView.frame;
        
        destinationOffScreen = inView.frame;
        destinationOffScreen.origin.x = (-1)*inView.frame.size.width;
        
    } else {
        [inView insertSubview:toViewController.view aboveSubview:fromViewController.view];
        [inView insertSubview:reverseNewView belowSubview:fromViewController.view];
        //[inView insertSubview:menuView aboveSubview:fromViewController.view];

        
        centerOffScreen = inView.center;
        centerOffScreen.x = inView.frame.size.width;

        menuFrameInScreen = menuView.frame;
        menuFrameOffScreen = menuView.frame;
        menuFrameOffScreen.origin.x = (-1)*menuView.frame.size.width;

        frameOffScreen = inView.frame;
        frameOffScreen.origin.x = (-1)*inView.frame.size.width;
        
        frameInScreen = inView.frame;

//        reverseNewView.frame = CGRectMake( (-1)*inView.frame.size.width, reverseNewView.frame.origin.y, reverseNewView.frame.size.width, reverseNewView.frame.size.height);
        reverseNewView.frame = frameInScreen;
        
        destinationOffScreen = inView.frame;
        destinationOffScreen.origin.x = inView.frame.size.width;
        destinationOffScreen.size.height += 20;
    }
    
    toViewController.view.frame = destinationOffScreen;
    
    [UIView animateKeyframesWithDuration:duration delay:0.0f options:UIViewKeyframeAnimationOptionCalculationModePaced animations:^{
        
        //fromViewController.view.frame = frameOffScreen;
        menuView.frame = menuFrameOffScreen;
        toViewController.view.frame = frameInScreen;
        reverseNewView.frame = frameInScreen;
        
        
    } completion:^(BOOL finished) {
        if ([transitionContext transitionWasCancelled]) {
            fromViewController.view.frame = inView.frame;
            [transitionContext completeTransition:NO];
            return;
        }
        //reverseNewView.hidden = YES;
        menuView.frame = menuFrameInScreen;

        [transitionContext completeTransition:YES];
    }];
}

@end

