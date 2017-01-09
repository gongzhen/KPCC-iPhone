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
#import "AnalyticsManager.h"

static NSString *kCommentsPlaceholder = @"Add your comments here…";

@interface SCPRFeedbackViewController ()

@end

@implementation SCPRFeedbackViewController

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.toolbar prep];
    self.values = @[ @"Bug", @"Suggestion", @"General Feedback"];
    self.feedbackTable.dataSource = self;
    self.feedbackTable.delegate = self;
    self.feedbackTable.tableFooterView = self.submitFooterView;
    self.feedbackTable.backgroundColor = [UIColor clearColor];
    self.feedbackTable.backgroundView.backgroundColor = [UIColor clearColor];
    self.currentReason = @"Bug";
    self.descriptionTextField.delegate = self;
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
    self.feedbackTable.separatorColor = [UIColor colorWithRed:222.f/255.f green:228.f/255.f blue:229.f/255.f alpha:0.3f];
    
    NSString *versionText = [NSString stringWithFormat:@"KPCC iPhone v%@",[Utils prettyVersion]];

//#ifndef PRODUCTION
//    NSURL *url = [NSURL URLWithString:kHLS];
//    NSString *server = [url host];
//#ifdef BETA
//    NSString *beta = [NSString stringWithFormat:@" BETA : %@",server];
//#else
//    NSString *beta = [NSString stringWithFormat:@" : %@",server];
//#endif
//    versionText = [versionText stringByAppendingString:beta];
//#endif

    self.versionLabel.text = versionText;
    self.versionLabel.textColor = [UIColor darkGrayColor];

    self.nameTextField.textColor = [UIColor whiteColor];
    self.emailTextField.textColor = [UIColor whiteColor];
    
    [self.authButton.titleLabel proSemiBoldFontize];
    [self.nameTextField setFont:[[DesignManager shared] proLight:self.nameTextField.font.pointSize]];
    [self.emailTextField setFont:[[DesignManager shared] proLight:self.emailTextField.font.pointSize]];
    
    self.emailTextField.keyboardType = UIKeyboardTypeEmailAddress;
    
    [self.versionLabel proLightFontize];
    
    NSMutableAttributedString *nph = [[NSMutableAttributedString alloc] initWithString:@"e.x. Ornette Coleman" attributes:@{ NSForegroundColorAttributeName : [[UIColor virtualWhiteColor] translucify:0.63] }];
    NSMutableAttributedString *eph = [[NSMutableAttributedString alloc] initWithString:@"you@domain.com" attributes:@{ NSForegroundColorAttributeName : [[UIColor virtualWhiteColor] translucify:0.63] }];
    NSMutableAttributedString *dph = [[NSMutableAttributedString alloc] initWithString:kCommentsPlaceholder attributes:@{ NSForegroundColorAttributeName : [[UIColor virtualWhiteColor] translucify:0.63] }];

    self.nameTextField.attributedPlaceholder = nph;
    self.emailTextField.attributedPlaceholder = eph;
    self.descriptionTextField.attributedPlaceholder = dph;
    
    self.nameTextField.returnKeyType = UIReturnKeyNext;
    self.emailTextField.returnKeyType = UIReturnKeyDone;
    self.descriptionTextField.returnKeyType = UIReturnKeyNext;
    
    self.splashBlurView.backgroundColor = [UIColor clearColor];
    self.splashView.contentMode = UIViewContentModeScaleAspectFill;
    self.splashView.clipsToBounds = YES;
    
    self.descriptionTextField.backgroundColor = [UIColor clearColor];
    self.descriptionTextField.textColor = [UIColor whiteColor];
    [self.descriptionTextField setFont:[[DesignManager shared] proLight:self.descriptionTextField.font.pointSize]];
    
    self.splashBlurView.tintColor = [UIColor clearColor];
    self.nativeSpinner.alpha = 0.0f;
    
#ifdef DEBUG
    //self.emailTextField.text = @"bhochberg@scpr.org";
    //self.descriptionTextField.text = @"This is an iPhone Desk test to see if the API is working";
    //self.nameTextField.text = @"Ben Hochberg";
#endif

    [self.authButton addTarget:self action:@selector(buttonTapped:) forControlEvents:UIControlEventTouchUpInside special:YES];

    [self.authButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.authButton setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
    self.authButton.layer.borderColor = [[UIColor virtualWhiteColor] translucify:0.45].CGColor;
    self.authButton.layer.borderWidth = 1.0f;

    self.versionLabel.textColor = [UIColor whiteColor];

    [self checkForm];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didShowKeyboard:) name:UIKeyboardDidShowNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willHideKeyboard:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [[AnalyticsManager shared] screen:@"feedbackView"];
}

- (void)didShowKeyboard:(NSNotification*)notification {
	CGSize keyboardSize = [[[notification userInfo] objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
 
	UIEdgeInsets contentInsets = UIEdgeInsetsMake(0.0, 0.0, keyboardSize.height, 0.0);
	self.feedbackTable.contentInset = contentInsets;
	self.feedbackTable.scrollIndicatorInsets = contentInsets;
}

- (void)willHideKeyboard:(NSNotification*)notification {
	UIEdgeInsets contentInsets = UIEdgeInsetsZero;
	self.feedbackTable.contentInset = contentInsets;
	self.feedbackTable.scrollIndicatorInsets = contentInsets;

	ValidationResult result = [self validate];

	dispatch_async(dispatch_get_main_queue(), ^{
		CGPoint bottomOffset = CGPointZero;
		if (result == ValidationResultOK) {
			bottomOffset = CGPointMake(0, self.feedbackTable.contentSize.height - self.feedbackTable.bounds.size.height);
		}
		
		[self.feedbackTable setContentOffset:bottomOffset animated:YES];
	});
}

#pragma mark - UI and Event Handling

- (IBAction)buttonTapped:(id)sender {
    if (sender == self.doneButton) {
        [self.currentField resignFirstResponder];
    } else if (sender == self.nextButton) {
        if (self.currentField == self.descriptionTextField) {
            [self.nameTextField becomeFirstResponder];
        } else if (self.currentField == self.nameTextField) {
            [self.emailTextField becomeFirstResponder];
        } else if (self.currentField == self.emailTextField) {
            [self.descriptionTextField becomeFirstResponder];
        }
    } else if (sender == self.authButton) {
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
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"spinner_appeared" object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(feedbackSubmitted) name:@"feedback_submitted" object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(feedbackFailure) name:@"feedback_failure" object:nil];

    [[FeedbackManager shared] validateCustomer:@{ @"message" : self.descriptionTextField.text,
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

    [[[UIAlertView alloc] initWithTitle:titleOfMsg message:bodyOfMsg delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
}

- (ValidationResult)validate {
    if (!self.currentReason || [self.currentReason isEqualToString:@""]) {
        return ValidationResultNoReasonProvided;
    }

	if ([self.emailTextField.text isEqualToString:@""] || ![Utils validateEmail:self.emailTextField.text]) {
        return ValidationResultBadEmail;
    }

	if ([self.nameTextField.text isEqualToString:@""]) {
        return ValidationResultNoName;
    }

	if ([self.descriptionTextField.text isEqualToString:@""]) {
        return ValidationResultNoComments;
    }

    return ValidationResultOK;
}

- (void)feedbackSubmitted {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"feedback_submitted" object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"feedback_failure" object:nil];
    
    [UIView animateWithDuration:0.22 animations:^{
        self.authButton.alpha = 1.0f;
        self.nativeSpinner.alpha = 0.0f;
    } completion:^(BOOL finished) {
        [self.navigationController popToRootViewControllerAnimated:YES];

		[[[UIAlertView alloc] initWithTitle:@"Thank You" message:@"Thank you for your feedback." delegate:nil cancelButtonTitle:@"You're welcome" otherButtonTitles:nil] show];
    }];
}

- (void)feedbackFailure {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"feedback_submitted" object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"feedback_failure" object:nil];

    [[NSNotificationCenter defaultCenter] postNotificationName:@"feedback_submitted" object:nil];

    [UIView animateWithDuration:0.22 animations:^{
        self.authButton.alpha = 1.0f;
    } completion:^(BOOL finished) {
    }];
}

- (void)checkForm {
	ValidationResult result = [self validate];

	if (result == ValidationResultOK) {
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

#pragma mark - UITableView
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 2) {
        return 2;
    } else if (section == 0) {
        return 3;
    } else if (section == 1) {
        return 1;
    }

    return 0;
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 2) {
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"n"];
        if (indexPath.row == 0) {
            cell.textLabel.text = @"Name";
            cell.accessoryView = self.nameTextField;

			[self.nameTextField addTarget:self action:@selector(didChangeTextFieldContent:) forControlEvents:UIControlEventEditingChanged];
		} else {
            cell.textLabel.text = @"Email";
            cell.accessoryView = self.emailTextField;

			[self.emailTextField addTarget:self action:@selector(didChangeTextFieldContent:) forControlEvents:UIControlEventEditingChanged];
		}
		
		[cell.textLabel proMediumFontize];
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.backgroundColor = [UIColor clearColor];

		return cell;
	} else if (indexPath.section == 0) {
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"n"];

        NSString *reason = (self.values)[indexPath.row];
        if ([self.currentReason isEqualToString:reason]) {
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

		[self.descriptionTextField addTarget:self action:@selector(didChangeTextFieldContent:) forControlEvents:UIControlEventEditingChanged];

		return cell;
    }

	[self.descriptionCell setBackgroundColor:[UIColor clearColor]];
    self.descriptionCell.selectionStyle = UITableViewCellSelectionStyleNone;

    return self.descriptionCell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 2) {
        if (indexPath.row == 0) {
            [self.nameTextField becomeFirstResponder];
		} else if (indexPath.row == 1) {
            [self.emailTextField becomeFirstResponder];
        }

		return;
	} else if (indexPath.section == 0) {
        self.currentReason = (self.values)[indexPath.row];
        [tableView reloadData];

		return;
    }
    
    [self.descriptionTextField becomeFirstResponder];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 1) {
        return self.descriptionCell.frame.size.height;
    }
    
    return 44.0f;
}

- (UIView*)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if (section == 2) {
        return [[DesignManager shared] textHeaderWithText:@"YOUR DETAILS" textColor:[UIColor kpccOrangeColor] backgroundColor:[[UIColor virtualBlackColor] translucify:0.25] divider:NO];
	} else if ( section == 0 ) {
        return [[DesignManager shared] textHeaderWithText:@"REASON FOR INQUIRY" textColor:[UIColor kpccOrangeColor] backgroundColor:[[UIColor virtualBlackColor] translucify:0.25] divider:NO];
    }

    return [[DesignManager shared] textHeaderWithText:@"COMMENTS" textColor:[UIColor kpccOrangeColor] backgroundColor:[[UIColor virtualBlackColor] translucify:0.25] divider:NO];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 34.0f;
}

#pragma mark - UITextField
- (void)textFieldDidBeginEditing:(UITextField *)textField {
    self.currentField = textField;

    if (!self.tapper) {
        self.tapper = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTapBackground)];

		[self.view addGestureRecognizer:self.tapper];
    }
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
	[self.view removeGestureRecognizer:self.tapper];
	self.tapper = nil;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == self.nameTextField) {
        [self.emailTextField becomeFirstResponder];
    } else if (textField == self.emailTextField) {
        [self.feedbackTable setContentOffset:CGPointMake(0.0, 0.0) animated:YES];
        [self.emailTextField resignFirstResponder];
    } else if (textField == self.descriptionTextField) {
        [self.nameTextField becomeFirstResponder];
    }

    return YES;
}

- (void)didChangeTextFieldContent:(id) sender {
	[self checkForm];
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
	if (textField == self.emailTextField && [string containsString:@" "]) {
		if (range.location == 0) {
			// No spaces at the start of an email address! - JAC
			return NO;
		}

		NSRange rangeOfAtSign	= [textField.text rangeOfString:@"@"];
		if (rangeOfAtSign.location != NSNotFound && range.location > rangeOfAtSign.location) {
			// No spaces in the middle of an email if they are not in the local part (before the '@' character)! - JAC
			return NO;
		}
	}
	return YES;
}

- (void)didTapBackground {
    [self.nameTextField resignFirstResponder];
    [self.emailTextField resignFirstResponder];
    [self.descriptionTextField resignFirstResponder];

    self.nameTextField.userInteractionEnabled = YES;
    self.emailTextField.userInteractionEnabled = YES;
    self.descriptionTextField.userInteractionEnabled = YES;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
