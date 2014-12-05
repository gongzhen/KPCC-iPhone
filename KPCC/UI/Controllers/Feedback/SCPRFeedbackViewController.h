//
//  SCPRFeedbackViewController.h
//  KPCC
//
//  Created by Ben on 7/30/13.
//  Copyright (c) 2013 scpr. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SCPRSpinnerViewController.h"
#import "FeedbackManager.h"
#import "FXBlurView.h"
#import "SCPRButton.h"
#import "SCPRKeyboardToolbar.h"

typedef NS_ENUM(NSInteger, ValidationResult) {
  ValidationResultUnknown = 0,
  ValidationResultNoName,
  ValidationResultBadEmail,
  ValidationResultNoComments,
  ValidationResultOK
} ;

@interface SCPRFeedbackViewController : UIViewController<UITextFieldDelegate,UITextViewDelegate,UITableViewDataSource,UITableViewDelegate>

@property (nonatomic,strong) IBOutlet UITableView *feedbackTable;
@property (nonatomic,strong) IBOutlet SCPRButton *authButton;
@property (nonatomic,strong) IBOutlet SCPRSpinnerViewController *spinner;
@property (nonatomic,strong) IBOutlet UILabel *emailLabel;
@property (nonatomic,strong) IBOutlet UITextField *emailTextField;
@property (nonatomic,strong) IBOutlet UITextField *nameTextField;
@property (nonatomic,strong) IBOutlet UILabel *descriptionLabel;
@property (nonatomic,strong) IBOutlet UITextView *descriptionInputView;
@property (nonatomic,strong) IBOutlet SCPRKeyboardToolbar *toolbar;
@property (nonatomic,strong) IBOutlet UIBarButtonItem *doneButton;
@property (nonatomic,strong) IBOutlet UIBarButtonItem *nextButton;
@property (nonatomic,strong) IBOutlet UIActivityIndicatorView *nativeSpinner;
@property (nonatomic,strong) IBOutlet UILabel *versionLabel;
@property (nonatomic,strong) IBOutlet UIImageView *splashView;
@property (nonatomic,strong) IBOutlet FXBlurView *splashBlurView;

@property BOOL barShowing;
@property (nonatomic,weak) UIResponder *currentField;
@property (nonatomic,strong) IBOutlet UIView *submitFooterView;
@property (nonatomic,strong) IBOutlet UITableViewCell *descriptionCell;

@property (nonatomic,strong) NSArray *values;
@property (nonatomic,strong) NSString *currentReason;

- (IBAction)buttonTapped:(id)sender;

@property (NS_NONATOMIC_IOSONLY, readonly) ValidationResult validate;
- (void)failWithValidationResult:(ValidationResult)reason;

- (void)showBar;
- (void)hideBar;

@end
