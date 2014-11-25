//
//  SCPRTextCalloutViewController.h
//  KPCC
//
//  Created by Ben Hochberg on 11/19/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SCPRTriangleView.h"

@interface SCPRTextCalloutViewController : UIViewController

@property (nonatomic,strong) IBOutlet SCPRTriangleView *trianglePointerView;
@property (nonatomic,strong) IBOutlet UIView *bodyContainerView;
@property (nonatomic,strong) IBOutlet UILabel *bodyTextLabel;
@property (nonatomic,strong) IBOutlet NSLayoutConstraint *pointerXPosition;

- (void)slidePointer:(CGFloat)xCoordinate;

@end
