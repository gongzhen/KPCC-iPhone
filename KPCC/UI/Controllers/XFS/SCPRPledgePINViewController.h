//
//  SCPRPledgePINViewController.h
//  KPCC
//
//  Created by Ben Hochberg on 6/1/15.
//  Copyright (c) 2015 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>

@import MessageUI;



@interface SCPRPledgePINViewController : UIViewController<UITableViewDataSource,UITableViewDelegate,UITextFieldDelegate>

@property (nonatomic, strong) IBOutlet UITableViewCell *headerCell;
@property (nonatomic, strong) IBOutlet UILabel *headCaptionLabel;
@property (nonatomic, strong) IBOutlet UILabel *headDescriptionLabel;
@property (nonatomic, strong) IBOutlet NSLayoutConstraint *headSpacing;
@property (nonatomic, strong) IBOutlet UITableViewCell *entryCell;
@property (nonatomic, strong) IBOutlet UIImageView *lockImageView;
@property (nonatomic, strong) IBOutlet UITextField *tokenField;
@property (nonatomic, strong) IBOutlet UITableViewCell *submitCell;
@property (nonatomic, strong) IBOutlet UIButton *submitButton;
@property (nonatomic, strong) IBOutlet UIActivityIndicatorView *spinner;
@property (nonatomic, strong) IBOutlet UITableView *tokenTable;
@property (nonatomic, strong) IBOutlet UIButton *faqLinkButton;

@property (nonatomic, weak) id parentXFSViewController;

@property NSString *pinNumber;

- (void)examineAndApplyStyle;
- (void)setupHeadlinesForState;

@property BOOL confirmed;

@end
