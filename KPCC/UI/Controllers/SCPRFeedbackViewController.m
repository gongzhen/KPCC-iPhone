//
//  SCPRFeedbackViewController.m
//  KPCC
//
//  Created by Ben on 7/30/13.
//  Copyright (c) 2013 scpr. All rights reserved.
//

#import "SCPRFeedbackViewController.h"
#import "global.h"
#import "SCPRTitlebarViewController.h"


@interface SCPRFeedbackViewController ()

@end

@implementation SCPRFeedbackViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
  
  self.values = @[ @"Bug", @"Suggestion", @"General Feedback", @"Other" ];
  self.feedbackTable.dataSource = self;
  self.feedbackTable.delegate = self;
  self.feedbackTable.tableFooterView = self.submitFooterView;
  self.feedbackTable.backgroundColor = [UIColor clearColor];
  self.feedbackTable.backgroundView.backgroundColor = [UIColor clearColor];
  self.currentReason = @"Bug";
  self.descriptionInputView.delegate = self;
  self.emailTextField.delegate = self;
  self.descriptionInputView.layer.cornerRadius = 4.0;
  self.descriptionInputView.layer.borderColor = [[DesignManager shared] silverliningColor].CGColor;
  self.descriptionInputView.layer.borderWidth = 1.0;
  
  self.nameTextField.font = [[DesignManager shared] latoRegular:self.nameTextField.font.pointSize];
  self.emailTextField.font = [[DesignManager shared] latoRegular:self.emailTextField.font.pointSize];
  self.descriptionInputView.font = [[DesignManager shared] latoRegular:self.descriptionInputView.font.pointSize];
  
  self.authButton.backgroundColor = [[DesignManager shared] turquoiseCrystalColor:1.0];
  self.authButton.layer.cornerRadius = 4.0;

  self.authButton.frame = CGRectMake(13.0,4.0,
                                     self.authButton.frame.size.width,
                                     self.authButton.frame.size.height);
  
  self.feedbackTable.separatorColor = [[DesignManager shared] silverliningColor];
  
  self.view.backgroundColor = [UIColor whiteColor];

  self.nativeSpinner.color = [[DesignManager shared] pumpkinColor];
  self.nativeSpinner.alpha = 0.0;
  
  NSString *idiom = [Utilities isIpad] ? @"iPad" : @"iPhone";
  NSString *versionText = [NSString stringWithFormat:@"KPCC %@ v%@",idiom,[Utilities prettyVersion]];
  self.versionLabel.textColor = [[DesignManager shared] charcoalColor];
  [self.versionLabel titleizeText:versionText
                             bold:NO
                    respectHeight:YES];
  
  
  [self.emailLabel titleizeText:self.emailLabel.text
                           bold:YES];
  [self.descriptionLabel titleizeText:self.descriptionLabel.text
                                 bold:YES];
  
  NSString *email = [[ContentManager shared].settings userEmail];
  if ( ![Utilities pureNil:email] ) {
    self.emailTextField.text = email;
  } else {
    self.emailTextField.placeholder = @"you@domain.com";
  }
  
  if ( [Utilities isIOS7] ) {
    self.feedbackTable.center = CGPointMake(self.feedbackTable.center.x,
                                            self.feedbackTable.center.y + 20.0);
  }
  
  [[DesignManager shared] globalSetTextColorTo:[UIColor whiteColor]
                                     forButton:self.authButton];
  
#ifdef DEBUG
  self.emailTextField.text = @"bhochberg@scpr.org";
  self.descriptionInputView.text = @"This is a test to see if the API is working";
  self.nameTextField.text = @"Ben Hochberg";
#endif
  
  
  [[DesignManager shared] globalSetFontTo:[[DesignManager shared] latoRegular:16.0]
                                forButton:self.authButton];
  self.authButton.titleLabel.shadowOffset = CGSizeMake(0.0, 0.0);
  
    // Do any additional setup after loading the view from its nib.
}

- (void)viewDidAppear:(BOOL)animated {
  [[[Utilities del] globalTitleBar] applyGrayBackground];
  [[[Utilities del] globalTitleBar] applyKpccLogo];
}

#pragma mark - UI and Event Handling
- (IBAction)buttonTapped:(id)sender {
  
  if ( sender == self.doneButton ) {
    [self hideBar];
    [self.currentField resignFirstResponder];
  }
  
  if ( sender == self.nextButton ) {
    if ( self.currentField == self.descriptionInputView ) {
      [self.nameTextField becomeFirstResponder];
    } else if ( self.currentField == self.nameTextField ) {
      [self.emailTextField becomeFirstResponder];
    } else if ( self.currentField == self.emailTextField ) {
      [self.descriptionInputView becomeFirstResponder];
    }
  }
  
  if ( sender == self.authButton ) {
    
    ValidationResult result = [self validate];
    if ( result == ValidationResultOK ) {

    
      [UIView animateWithDuration:0.22
                     animations:^{
                       self.nativeSpinner.alpha = 1.0;
                       [self.nativeSpinner startAnimating];
                       self.authButton.alpha = 0.0;
                     } completion:^(BOOL finished) {
                       [self continueSubmission];
                     }];
    } else {
      [self failWithValidationResult:result];
    }

  }
  
}

- (void)continueSubmission {
  
  [[NSNotificationCenter defaultCenter]
   removeObserver:self
   name:@"spinner_appeared"
   object:nil];
  
  [[NSNotificationCenter defaultCenter]
   addObserver:self
   selector:@selector(feedbackSubmitted)
   name:@"feedback_submitted"
   object:nil];
  
  [[NSNotificationCenter defaultCenter]
   addObserver:self
   selector:@selector(feedbackFailure)
   name:@"feedback_failure"
   object:nil];
  
  [[FeedbackManager shared] validateCustomer:@{ @"message" : self.descriptionInputView.text,
   @"email" : self.emailTextField.text, @"date" : [NSDate date], @"name" : self.nameTextField.text, @"type" : self.currentReason }];
}

- (void)failWithValidationResult:(ValidationResult)reason {
  
  NSString *titleOfMsg = @"";
  NSString *bodyOfMsg = @"";
  switch (reason) {
    case ValidationResultBadEmail:
      titleOfMsg = @"Email Invalid";
      bodyOfMsg = @"The email address provided is not valid. Please provide a valid email";
      break;
    case ValidationResultNoName:
      titleOfMsg = @"Enter Name";
      bodyOfMsg = @"Please enter your name";
      break;
    case ValidationResultNoComments:
      titleOfMsg = @"Enter a comment";
      bodyOfMsg = @"Please enter a comment";
      break;
    case ValidationResultUnknown:
      titleOfMsg = @"Unknown Failure";
      bodyOfMsg = @"The form could not be submitted for an unknown reason";
      break;
    default:
      break;
  }
  
  [[[UIAlertView alloc] initWithTitle:titleOfMsg
                              message:bodyOfMsg
                             delegate:nil
                    cancelButtonTitle:@"OK"
                    otherButtonTitles:nil] show];
  
}

- (ValidationResult)validate {
  
  if ( [Utilities pureNil:self.nameTextField.text] ) {
    return ValidationResultNoName;
  }
  if ( [Utilities pureNil:self.emailTextField.text] ||
      ![Utilities validateEmail:self.emailTextField.text] ) {
    return ValidationResultBadEmail;
  }
  if ( [Utilities pureNil:self.descriptionInputView.text] ) {
    return ValidationResultNoComments;
  }
  
  return ValidationResultOK;
  
}

- (void)feedbackSubmitted {
  
  [[NSNotificationCenter defaultCenter] removeObserver:self
                                                  name:@"feedback_submitted"
                                                object:nil];
  
  [[NSNotificationCenter defaultCenter] removeObserver:self
                                                  name:@"feedback_failure"
                                                object:nil];
  
  [UIView animateWithDuration:0.22 animations:^{
    self.authButton.alpha = 1.0;
    self.nativeSpinner.alpha = 0.0;
  } completion:^(BOOL finished) {
    [[[UIAlertView alloc] initWithTitle:@"Thank You"
                                message:@"Thank you for your feedback."
                               delegate:nil
                      cancelButtonTitle:@"You're welcome"
                      otherButtonTitles:nil] show];
  }];
}

- (void)feedbackFailure {
  
  [[NSNotificationCenter defaultCenter] removeObserver:self
                                                  name:@"feedback_submitted"
                                                object:nil];
  
  [[NSNotificationCenter defaultCenter] removeObserver:self
                                                  name:@"feedback_failure"
                                                object:nil];
  
  [[NSNotificationCenter defaultCenter] postNotificationName:@"feedback_submitted"
                                                      object:nil];
  
  [UIView animateWithDuration:0.22 animations:^{
    self.authButton.alpha = 1.0;
  } completion:^(BOOL finished) {

  }];
}

- (void)showBar {
  
  if ( self.barShowing ) {
    return;
  }
  
  self.barShowing = YES;
  
  CGFloat yDelta = [Utilities isLandscape] ? 352.0 : 696.0;
  if ( ![Utilities isIOS7] ) {
    yDelta -= 20.0;
  }
  
  if ( ![Utilities isIpad] ) {
    yDelta = 289.0;
  }
  
  self.toolbar.frame = CGRectMake(0.0,yDelta,self.view.bounds.size.width,
                                  self.toolbar.frame.size.height);
  [self.view addSubview:self.toolbar];
  
}

- (void)hideBar {
  
  if ( !self.barShowing ) {
    return;
  }
  
  self.barShowing = NO;
  [self.toolbar removeFromSuperview];
}

#pragma mark - UITableView
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  if ( section == 0 ) {
    return 2;
  }
  
  if ( section == 1 ) {
    return 4;
  }
  
  if ( section == 2 ) {
    return 1;
  }
  
  return 0;
  
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  if ( indexPath.section == 0 ) {
    
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                                   reuseIdentifier:@"n"];
    if ( indexPath.row == 0 ) {
      [cell.textLabel titleizeText:@"Name" bold:YES];
      cell.accessoryView = self.nameTextField;
    } else {
      [cell.textLabel titleizeText:@"Email" bold:YES];
      cell.accessoryView = self.emailTextField;
    }
    
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
  }
  if ( indexPath.section == 1 ) {
    
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                                   reuseIdentifier:@"n"];
    
    NSString *reason = [self.values objectAtIndex:indexPath.row];
    if ( [self.currentReason isEqualToString:reason] ) {
      cell.accessoryType = UITableViewCellAccessoryCheckmark;
    } else {
      cell.accessoryType = UITableViewCellAccessoryNone;
    }
    
    [cell.textLabel titleizeText:reason bold:YES];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
  }
  
  self.descriptionCell.selectionStyle = UITableViewCellSelectionStyleNone;

  return self.descriptionCell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
  if ( indexPath.section != 2 ) {
    [cell.textLabel titleizeText:cell.textLabel.text bold:YES];
  } else {
    if ( [Utilities isIOS7] ) {
      self.descriptionInputView.frame = CGRectMake(self.descriptionInputView.frame.origin.x,
                                                   self.descriptionInputView.frame.origin.y,
                                                   742.0,
                                                   self.descriptionInputView.frame.size.height);
    }
  }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  if ( indexPath.section == 0 ) {
    if ( indexPath.row == 0 ) {
      [self.nameTextField becomeFirstResponder];
    }
    if ( indexPath.row == 1 ) {
      [self.emailTextField becomeFirstResponder];
    }
    return;
  }
  if ( indexPath.section == 1 ) {
    self.currentReason = [self.values objectAtIndex:indexPath.row];
    [tableView reloadData];
    return;
  }
  
  [self.descriptionInputView becomeFirstResponder];
  
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
  if ( indexPath.section == 2 ) {
    return self.descriptionCell.frame.size.height;
  }
  
  return 44.0;
}

- (UIView*)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
  if ( section == 0 ) {
    return [[DesignManager shared] textHeaderWithText:@"YOUR DETAILS"
                                            textColor:[[DesignManager shared] periwinkleColor]
                                      backgroundColor:[UIColor whiteColor]
            divider:NO];
  }
  if ( section == 1 ) {
    return [[DesignManager shared] textHeaderWithText:@"REASON FOR INQUIRY"
                                            textColor:[[DesignManager shared] periwinkleColor]
                                      backgroundColor:[UIColor whiteColor]
            divider:NO];
  }
  
  return [[DesignManager shared] textHeaderWithText:@"COMMENTS"
                                          textColor:[[DesignManager shared] periwinkleColor]
                                    backgroundColor:[UIColor whiteColor]
          divider:NO];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
  return [[[DesignManager shared] orangeTextHeaderWithText:@""] frame].size.height;
}

#pragma mark - UITextView
- (void)textViewDidBeginEditing:(UITextView *)textView {
  
  if ( [Utilities isLandscape] ) {
    [self.feedbackTable setContentOffset:CGPointMake(0.0,240.0)
                                animated:YES];
  }
  self.currentField = textView;
  [self showBar];
}

- (void)textViewDidEndEditing:(UITextView *)textView {
  if ( [Utilities isLandscape] ) {
    [self.feedbackTable setContentOffset:CGPointMake(0.0,0.0)
                                animated:YES];
  }
  [self hideBar];
}

#pragma mark - UITextField
- (void)textFieldDidBeginEditing:(UITextField *)textField {
  self.currentField = textField;

  [self.feedbackTable setContentOffset:CGPointMake(0.0,0.0)
                                animated:YES];
  
  [self showBar];
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
  [self hideBar];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
