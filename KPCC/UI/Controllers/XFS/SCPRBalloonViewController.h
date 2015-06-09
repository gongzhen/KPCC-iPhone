//
//  SCPRBalloonViewController.h
//  KPCC
//
//  Created by Ben Hochberg on 6/1/15.
//  Copyright (c) 2015 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SCPRTriangleView.h"

@interface SCPRBalloonViewController : UIViewController

@property (nonatomic, strong) IBOutlet UIView *textContainerView;
@property (nonatomic, strong) IBOutlet UILabel *textCaptionLabel;
@property (nonatomic, strong) IBOutlet UIView *dividerView;
@property (nonatomic, strong) IBOutlet UIImageView *closeButtonImage;
@property (nonatomic, strong) IBOutlet UIButton *closeButton;
@property (nonatomic, strong) IBOutlet SCPRTriangleView *triangleView;
@property (nonatomic, strong) IBOutlet NSLayoutConstraint *triangleHorizontalAnchor;

- (void)prime;
- (void)primeWithText:(NSString*)text;
- (void)closeSelf;
@end
