//
//  SCPRShortListViewController.h
//  KPCC
//
//  Created by Ben Hochberg on 10/27/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SCPRMenuButton.h"
#import "Utils.h"

@interface SCPRShortListViewController : UIViewController<UIWebViewDelegate,MenuButtonDelegate>

@property (nonatomic,strong) UIWebView *slWebView;
@property (nonatomic,strong) UIWebView *detailWebView;
@property (nonatomic,strong) UIScrollView *mainScrollView;
@property (nonatomic,copy) NSString *cachedTitle;
@property (nonatomic,copy) NSString *cachedParentTitle;

@property BOOL initialLoad;
@property BOOL detailInitialLoad;
@property BOOL popping;



@end
