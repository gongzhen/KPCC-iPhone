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
#import "SCPRPullDownMenu.h"

@interface SCPRNavigationController : UINavigationController<UIGestureRecognizerDelegate, UINavigationControllerDelegate, PulldownMenuDelegate,MenuButtonDelegate> {
    SCPRPullDownMenu *pulldownMenu;
    SCPRMenuButton *menuButton;
}

//@property (nonatomic, retain) PulldownMenu *_pulldownMenu;

@end
