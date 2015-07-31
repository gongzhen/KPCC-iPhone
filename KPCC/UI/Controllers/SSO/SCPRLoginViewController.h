//
//  SCPRLoginViewController.h
//  KPCC
//
//  Created by Ben Hochberg on 7/30/15.
//  Copyright (c) 2015 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSUInteger, SSOStateType) {
    SSOStateTypeIdle = 0,
    SSOStateTypeSignIn,
    SSOStateTypeSignUp
};

@class SCPRSSOInputFieldCell;

@interface SCPRLoginViewController : UIViewController<UITableViewDataSource,UITableViewDelegate,UITextFieldDelegate>

@property (nonatomic, strong) IBOutlet UITableView *mainTable;
@property (nonatomic, strong) IBOutlet UITableViewCell *signUpFooterCell;
@property (nonatomic, strong) IBOutlet UIButton *facebookButton;
@property (nonatomic, strong) IBOutlet UIButton *twitterButton;
@property (nonatomic, strong) IBOutlet UILabel *orLabel;
@property (nonatomic, strong) IBOutlet UIButton *signInButton;
@property (nonatomic, strong) IBOutlet UIButton *signUpButton;
@property (nonatomic, strong) IBOutlet UIButton *closeButton;
@property (nonatomic, strong) IBOutlet UIImageView *kpccLogoImageView;
@property (nonatomic, strong) IBOutlet UILabel *signInLabel;
@property (nonatomic, strong) IBOutlet NSLayoutConstraint *tableTopAnchor;


@property (nonatomic, strong) SCPRSSOInputFieldCell *emailCell;
@property (nonatomic, strong) SCPRSSOInputFieldCell *passwordCell;
@property (nonatomic, strong) SCPRSSOInputFieldCell *confirmationCell;

@property SSOStateType currentState;

- (void)primeForState:(SSOStateType)type animated:(BOOL)animated;

@end
