//
//  SCPRMenuButton.h
//  KPCC
//
//  Created by John Meeker on 9/4/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol MenuButtonDelegate
    -(void)backPressed;
    -(void)menuPressed;
-(void)popPressed;
@end

@interface SCPRMenuButton : UIControl

@property (nonatomic, assign) id<MenuButtonDelegate> delegate;
@property (nonatomic, weak) id<MenuButtonDelegate> proxyDelegate;

+ (instancetype)button;
+ (instancetype)buttonWithOrigin:(CGPoint)origin;

@property(nonatomic) BOOL showMenu;
@property(nonatomic) BOOL showBackArrow;
@property (nonatomic) BOOL showPopArrow;

- (void)animateToBack;
- (void)animateToMenu;
- (void)animateToClose;
- (void)animateToPop:(id<MenuButtonDelegate>)proxyDelegate;

@end
