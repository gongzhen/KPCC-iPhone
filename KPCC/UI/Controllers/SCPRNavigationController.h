//
//  SCPRNavigationController.h
//  KPCC
//
//  Created by John Meeker on 9/4/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Utils.h"
#import "SCPRMenuButton.h"
#import "SCPRSlideInTransition.h"

typedef NS_ENUM(NSUInteger, CustomLeftBarItem) {
    CustomLeftBarItemPop = 0
};
                
@interface SCPRNavigationController : UINavigationController<UIGestureRecognizerDelegate,UINavigationControllerDelegate,MenuButtonDelegate,
UIViewControllerTransitioningDelegate> {
    SCPRMenuButton *menuButton;
}

- (void)applyCustomLeftBarItem:(CustomLeftBarItem)leftBarItemType proxyDelegate:(id<MenuButtonDelegate>)proxyDelegate;
- (void)restoreLeftBarItem:(id<MenuButtonDelegate>)proxyDelegate;

@end
