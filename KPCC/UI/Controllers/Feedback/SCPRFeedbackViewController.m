//
//  SCPRFeedbackViewController.m
//  KPCC
//
//  Created by Ben on 7/30/13.
//  Copyright (c) 2013 scpr. All rights reserved.
//

#import "SCPRFeedbackViewController.h"
#import "DesignManager.h"
#import "AudioManager.h"

static NSString *kCommentsPlaceholder = @"... Add your comments here";

@interface SCPRFeedbackViewController ()

@end

@implementation SCPRFeedbackViewController

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
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
    
    [self.toolbar prep];
    self.values = @[ @"Bug", @"Suggestion", @"General Feedback"];
    self.feedbackTable.dataSource = self;
    self.feedbackTable.delegate = self;
    self.feedbackTable.tableFooterView = self.submitFooterView;
    self.feedbackTable.backgroundColor = [UIColor clearColor];
    self.feedbackTable.backgroundView.backgroundColor = [UIColor clearColor];
    self.currentReason = @"Bug";
    self.descriptionInputView.delegate = self;
    self.emailTextField.delegate = self;
    self.splashBlurView.blurRadius = 7.0f;
    
    UIImage *img = [[DesignManager shared] currentBlurredLiveImage];
    if ( [[AudioManager shared] currentAudioMode] == AudioModeOnDemand ) {
        UIImage *odImg = [[DesignManager shared] currentBlurredImage];
        if ( odImg ) {
            img = odImg;
        }
    }
    
    self.splashView.image = img;
    
    self.navigationItem.title = @"Feedback";
    self.splashView.alpha = 1.0f;
    
    self.feedbackTable.separatorColor = [UIColor lightGrayColor];
    
    self.view.backgroundColor = [UIColor blackColor];
    self.feedbackTable.separatorColor = [UIColor colorWithRed:222.f/255.f
                                                        green:228.f/255.f
                                                         blue:229.f/255.f alpha:0.3f];
    
    NSString *versionText = [NSString stringWithFormat:@"KPCC iPhone v%@",[Utils prettyVersion]];
    
#ifndef PRODUCTION
    NSURL *url = [NSURL URLWithString:kHLS];
    NSString *server = [url host];
#ifdef BETA
    NSString *beta = [NSString stringWithFormat:@" BETA : %@",server];
#else
    NSString *beta = [NSString stringWithFormat:@" : %@",server];
#endif
    versionText = [versionText stringByAppendingString:beta];
#endif
    
    self.versionLabel.text = versionText;
    self.versionLabel.textColor = [UIColor darkGrayColor];

    self.nameTextField.textColor = [UIColor whiteColor];
    self.emailTextField.textColor = [UIColor whiteColor];
    
    [self.authButton.titleLabel proSemiBoldFontize];
    [self.nameTextField setFont:[[DesignManager shared] proLight:self.nameTextField.font.pointSize]];
    [self.emailTextField setFont:[[DesignManager shared] proLight:self.emailTextField.font.pointSize]];
    
    self.emailTextField.keyboardType = UIKeyboardTypeEmailAddress;
    
    [self.versionLabel proLightFontize];
    
    NSMutableAttributedString *nph = [[NSMutableAttributedString alloc] initWithString:@"e.x. Ornette Coleman"
                                                                            attributes:@{ NSForegroundColorAttributeName : [[UIColor virtualWhiteColor] translucify:0.63] }];
    NSMutableAttributedString *eph = [[NSMutableAttributedString alloc] initWithString:@"you@domain.com"
                                                                            attributes:@{ NSForegroundColorAttributeName : [[UIColor virtualWhiteColor] translucify:0.63] }];
    NSMutableAttributedString *dph = [[NSMutableAttributedString alloc] initWithString:kCommentsPlaceholder
                                                                            attributes:@{ NSForegroundColorAttributeName : [[UIColor virtualWhiteColor] translucify:0.63] }];
    self.nameTextField.attributedPlaceholder = nph;
    self.emailTextField.attributedPlaceholder = eph;
    self.descriptionInputView.attributedPlaceholder = dph;
    
    self.nameTextField.returnKeyType = UIReturnKeyNext;
    self.emailTextField.returnKeyType = UIReturnKeyDone;
    self.descriptionInputView.returnKeyType = UIReturnKeyNext;
    
    self.splashBlurView.backgroundColor = [UIColor clearColor];
    self.splashView.contentMode = UIViewContentModeScaleAspectFill;
    self.splashView.clipsToBounds = YES;
    
    self.descriptionInputView.backgroundColor = [UIColor clearColor];
    self.descriptionInputView.textColor = [UIColor whiteColor];
    [self.descriptionInputView setFont:[[DesignManager shared] proLight:self.descriptionInputView.font.pointSize]];
    
    self.splashBlurView.tintColor = [UIColor clearColor];
    self.nativeSpinner.alpha = 0.0f;
    
#ifdef DEBUG
    //self.emailTextField.text = @"bhochberg@scpr.org";
    //self.descriptionInputView.text = @"This is an iPhone Desk test to see if the API is working";
    //self.nameTextField.text = @"Ben Hochberg";
#endif
    
    [self.authButton addTarget:self
                        action:@selector(buttonTapped:)
              forControlEvents:UIControlEventTouchUpInside
                       special:YES];
    
    [self.authButton setTitleColor:[UIColor whiteColor]
                          forState:UIControlStateNormal];
    [self.authButton setTitleColor:[UIColor whiteColor]
                          forState:UIControlStateHighlighted];
    self.authButton.layer.borderColor = [[UIColor virtualWhiteColor] translucify:0.45].CGColor;
    self.authButton.layer.borderWidth = 1.0f;
    
    self.versionLabel.textColor = [UIColor whiteColor];
    
    [self checkForm];
    // Do any additional setup after loading the view from its nib.
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
        
        [UIView animateWithDuration:0.25 animations:^{
            self.authButton.alpha = 0.0f;
            self.nativeSpinner.alpha = 1.0f;
            [self.nativeSpinner startAnimating];
        } completion:^(BOOL finished) {
            [self continueSubmission];
        }];
        
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
                                                  @"email" : self.emailTextField.text,
                                                  @"date" : [NSDate date],
                                                  @"name" : self.nameTextField.text,
                                                  @"type" : self.currentReason }];
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
    
    if ( !self.currentReason || SEQ(self.currentReason,@"") ) {
        return ValidationResultNoReasonProvided;
    }
    if ( SEQ(self.emailTextField.text,@"") || ![Utils validateEmail:self.emailTextField.text] ) {
        return ValidationResultBadEmail;
    }
    if ( SEQ(self.nameTextField.text,@"") ) {
        return ValidationResultNoName;
    }
    if ( SEQ(self.descriptionInputView.text,@"") ) {
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
        self.authButton.alpha = 1.0f;
        self.nativeSpinner.alpha = 0.0f;

    } completion:^(BOOL finished) {
        
        [self.navigationController popToRootViewControllerAnimated:YES];
        
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
        self.authButton.alpha = 1.0f;
    } completion:^(BOOL finished) {
        
    }];
}

- (void)checkForm {
    ValidationResult result = [self validate];
    if ( result == ValidationResultOK ) {
        [UIView animateWithDuration:0.22
                         animations:^{
                             self.authButton.alpha = 1.0f;
                             self.authButton.userInteractionEnabled = YES;
                         }];
    } else {
        [UIView animateWithDuration:0.22
                         animations:^{
                             self.authButton.alpha = 0.35;
                             self.authButton.userInteractionEnabled = NO;
                         }];
    }
}

- (void)showBar {
   // [self.toolbar presentOnController:self withOptions:@{}];
}

- (void)hideBar {
  //  [self.toolbar dismiss];
}

#pragma mark - UITableView
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if ( section == 2 ) {
        return 2;
    }
    
    if ( section == 0 ) {
        return 3;
    }
    
    if ( section == 1 ) {
        return 1;
    }
    
    return 0;
    
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if ( indexPath.section == 2 ) {
        
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                                       reuseIdentifier:@"n"];
        if ( indexPath.row == 0 ) {
            cell.textLabel.text = @"Name";
            cell.accessoryView = self.nameTextField;

        } else {
            cell.textLabel.text = @"Email";
            cell.accessoryView = self.emailTextField;
        }
        
        
        [cell.textLabel proMediumFontize];
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.backgroundColor = [UIColor clearColor];
        return cell;
    }
    if ( indexPath.section == 0 ) {
        
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                                       reuseIdentifier:@"n"];
        
        NSString *reason = (self.values)[indexPath.row];
        if ( [self.currentReason isEqualToString:reason] ) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        } else {
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
        
        cell.tintColor = [UIColor kpccOrangeColor];
        
        cell.textLabel.text = reason;
        [cell.textLabel proMediumFontize];
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.backgroundColor = [UIColor clearColor];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        return cell;
        
    }
    
    [self.descriptionCell setBackgroundColor:[UIColor clearColor]];
    self.descriptionCell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    return self.descriptionCell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if ( indexPath.section != 2 ) {

    } else {

    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ( indexPath.section == 2 ) {
        if ( indexPath.row == 0 ) {
            [self.nameTextField becomeFirstResponder];
        }
        if ( indexPath.row == 1 ) {
            [self.emailTextField becomeFirstResponder];
        }
        return;
    }
    if ( indexPath.section == 0 ) {
        self.currentReason = (self.values)[indexPath.row];
        [tableView reloadData];
        return;
    }
    
    [self.descriptionInputView becomeFirstResponder];
    
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if ( indexPath.section == 1 ) {
        return self.descriptionCell.frame.size.height;
    }
    
    return 44.0f;
}

- (UIView*)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if ( section == 2 ) {
        return [[DesignManager shared] textHeaderWithText:@"YOUR DETAILS"
                                                textColor:[UIColor kpccOrangeColor]
                                          backgroundColor:[[UIColor virtualBlackColor] translucify:0.25]
                                                  divider:NO];
    }
    if ( section == 0 ) {
        return [[DesignManager shared] textHeaderWithText:@"REASON FOR INQUIRY"
                                                textColor:[UIColor kpccOrangeColor]
                                          backgroundColor:[[UIColor virtualBlackColor] translucify:0.25]
                                                  divider:NO];
    }
    
    return [[DesignManager shared] textHeaderWithText:@"COMMENTS"
                                            textColor:[UIColor kpccOrangeColor]
                                      backgroundColor:[[UIColor virtualBlackColor] translucify:0.25]
                                              divider:NO];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 34.0f;
}

#pragma mark - UITextView
/*
- (void)textViewDidBeginEditing:(UITextView *)textView {
    
    textView.userInteractionEnabled = NO;
    
    if ( SEQ(textView.attributedText.string,kCommentsPlaceholder) ) {
        textView.attributedText = [[NSMutableAttributedString alloc] initWithString:@""
                                                                         attributes:@{}];
    }
    
    [self.feedbackTable setContentOffset:CGPointMake(0.0,240.0)
                                animated:YES];
    
    self.currentField = textView;
    [self showBar];
    
    if ( !self.tapper ) {
        self.tapper = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                              action:@selector(dk)];
        [self.view addGestureRecognizer:self.tapper];
    }
}

- (void)textViewDidEndEditing:(UITextView *)textView {
    [self hideBar];
    if ( SEQ(textView.attributedText.string,kCommentsPlaceholder) ) {
        textView.attributedText = [[NSMutableAttributedString alloc] initWithString:kCommentsPlaceholder
                                                                         attributes:@{ NSForegroundColorAttributeName : [[UIColor virtualWhiteColor] translucify:0.63] }];
    }
    

}

- (BOOL)textViewShouldEndEditing:(UITextView *)textView {
    [self.nameTextField becomeFirstResponder];
 
    return YES;
}
*/

#pragma mark - UITextField
- (void)textFieldDidBeginEditing:(UITextField *)textField {
    self.currentField = textField;
    NSLog(@"Current offset : %1.1f",self.feedbackTable.contentOffset.y);
    
    if ( textField == self.descriptionInputView ) {
        [self.feedbackTable setContentOffset:CGPointMake(0.0,140.0)
                                    animated:YES];
    } else {
        [self.feedbackTable setContentOffset:CGPointMake(0.0,160.0)
                                animated:YES];
    }
    
    [self showBar];
    if ( !self.tapper ) {
        self.tapper = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                              action:@selector(dk)];
        [self.view addGestureRecognizer:self.tapper];
    }
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    [self hideBar];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if ( textField == self.nameTextField ) {
        [self.emailTextField becomeFirstResponder];
    }
    if ( textField == self.emailTextField ) {
        [self.feedbackTable setContentOffset:CGPointMake(0.0, 0.0) animated:YES];
        [self.emailTextField resignFirstResponder];
    }
    if ( textField == self.descriptionInputView ) {
        [self.nameTextField becomeFirstResponder];
    }
    
    return YES;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    [self checkForm];
    
    return YES;
}

- (void)dk {
    [self.view removeGestureRecognizer:self.tapper];
    self.tapper = nil;
    
    [self.nameTextField resignFirstResponder];
    [self.emailTextField resignFirstResponder];
    [self.descriptionInputView resignFirstResponder];
    
    self.nameTextField.userInteractionEnabled = YES;
    self.emailTextField.userInteractionEnabled = YES;
    self.descriptionInputView.userInteractionEnabled = YES;
    
    [self.feedbackTable setContentOffset:CGPointMake(0.0, 0.0) animated:YES];
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
