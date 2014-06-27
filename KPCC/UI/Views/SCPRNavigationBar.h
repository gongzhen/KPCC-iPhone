//
//  SCPRNavigationBar.h
//  KPCC
//
//  Created by John Meeker on 6/27/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol SCPRNavigationBarDelegate <NSObject>

- (void)navBarDidFinishSwipeDown;

@end

@interface SCPRNavigationBar : UINavigationBar

@end
