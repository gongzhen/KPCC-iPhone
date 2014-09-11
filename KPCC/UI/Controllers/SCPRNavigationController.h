//
//  SCPRNavigationController.h
//  KPCC
//
//  Created by John Meeker on 9/4/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SCPRMenuButton.h"
#import "PulldownMenu.h"

@interface SCPRNavigationController : UINavigationController<PulldownMenuDelegate> {
    PulldownMenu *pulldownMenu;
    SCPRMenuButton *menuButton;
}

//@property (nonatomic, retain) PulldownMenu *_pulldownMenu;

@end
