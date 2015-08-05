//
//  SCPRLoginViewController.m
//  KPCC
//
//  Created by Ben Hochberg on 7/30/15.
//  Copyright (c) 2015 SCPR. All rights reserved.
//

#import "SCPRLoginViewController.h"
#import "UILabel+Additions.h"
#import "DesignManager.h"
#import "UIButton+Additions.h"
#import "SCPRSSOInputFieldCell.h"
#import "Utils.h"
#import "UXmanager.h"

#define kTallHeight 93.0f
#define kShortHeight 63.0f

@interface SCPRLoginViewController ()


- (NSArray*)cellPaths;

@end

@implementation SCPRLoginViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.passwordCell = (SCPRSSOInputFieldCell*)[Utils xib:@"SCPRSSOInputFieldCell"];
    [self.passwordCell primeWithType:SSOInputFieldTypePassword andFieldDelegate:self];
    
    self.emailCell = (SCPRSSOInputFieldCell*)[Utils xib:@"SCPRSSOInputFieldCell"];
    [self.emailCell primeWithType:SSOInputFieldTypeEmail andFieldDelegate:self];
    
    self.confirmationCell = (SCPRSSOInputFieldCell*)[Utils xib:@"SCPRSSOInputFieldCell"];
    [self.confirmationCell primeWithType:SSOInputFieldTypePasswordConfirmation andFieldDelegate:self];
    
    self.emailCell.selectionStyle = UITableViewCellSelectionStyleNone;
    self.passwordCell.selectionStyle = UITableViewCellSelectionStyleNone;
    self.confirmationCell.selectionStyle = UITableViewCellSelectionStyleNone;
    self.signUpFooterCell.selectionStyle = UITableViewCellSelectionStyleNone;
    
#ifdef DEBUG
    self.longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                                                    action:@selector(cheat)];
    self.longPressGestureRecognizer.minimumPressDuration = 4.0f;
    [self.mainTable addGestureRecognizer:self.longPressGestureRecognizer];
#endif
    
    [self.createAccountCaptionLabel proBookFontize];
    
    [self.signUpButton addTarget:self
                          action:@selector(signUpTapped)
                forControlEvents:UIControlEventTouchUpInside];
    
    [self.closeButton addTarget:self
                         action:@selector(closeTapped)
               forControlEvents:UIControlEventTouchUpInside];
    
    [self.backButton addTarget:self
                        action:@selector(backTapped)
              forControlEvents:UIControlEventTouchUpInside];
    
    [[DesignManager shared] sculptButton:self.backButton
                               withStyle:SculptingStyleNormal
                                 andText:@"< Back"];
    
    [self primeForState:SSOStateTypeIdle animated:NO];
    

    // Do any additional setup after loading the view from its nib.
}

- (void)cheat {
#ifdef DEBUG
    [[UXmanager shared].settings setSsoKey:nil];
    [[UXmanager shared].settings setSsoLoginType:SSOTypeNone];
    [[UXmanager shared] persist];
    
    self.emailCell.emailTextField.text = @"bhochberg@scpr.org";
    self.passwordCell.emailTextField.text = @"KPCCDev#474";
    self.confirmationCell.emailTextField.text = @"KPCCDev#474";
    
    self.signInButton.alpha = 1.0f;
    self.signInButton.userInteractionEnabled = YES;
#endif
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)primeForState:(SSOStateType)type animated:(BOOL)animated {
    
    SSOStateType previousType = self.currentState;
    self.currentState = type;
    
    [self.signInLabel proBookFontize];
    [self.orLabel proBookFontize];
    
    [self.signInButton removeTarget:nil
                             action:nil
                   forControlEvents:UIControlEventAllEvents];
    
    if ( animated ) {
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:0.25f];
        [UIView setAnimationDelegate:self];
        [UIView setAnimationDidStopSelector:@selector(finishTransition)];
    }
    
    if ( type == SSOStateTypeIdle ) {
        self.signInButton.alpha = 0.0f;
        self.twitterButton.alpha = 1.0f;
        self.facebookButton.alpha = 1.0f;
        self.orLabel.alpha = 0.0f;
        self.signInLabel.alpha = 1.0f;
        self.backButton.alpha = 0.0f;
        self.kpccLogoImageView.alpha = 1.0f;
        self.createAccountCaptionLabel.alpha = 0.0f;
        self.signUpButton.alpha = 1.0f;
        self.closeButton.alpha = 1.0f;
        [self.passwordCell setSignup:NO];
        
        self.targetedCell = nil;
        self.tableTopAnchor.constant = 168.0f;
        
    }
    if ( type == SSOStateTypeSignIn ) {
        self.signInButton.alpha = 0.45f;
        self.signInButton.userInteractionEnabled = NO;
        self.twitterButton.alpha = 0.0f;
        self.facebookButton.alpha = 0.0f;
        self.orLabel.alpha = 0.0f;
        self.signInLabel.alpha = 0.0f;
        self.backButton.alpha = 1.0f;
        self.kpccLogoImageView.alpha = 1.0f;
        self.createAccountCaptionLabel.alpha = 0.0f;
        self.signUpButton.alpha = 0.0f;
        self.closeButton.alpha = 0.0f;
        
        [self.passwordCell setSignup:NO];
        
        self.tableTopAnchor.constant = self.kpccLogoImageView.frame.origin.y+self.kpccLogoImageView.frame.size.height-12.0f;
        
        [[DesignManager shared] sculptButton:self.signInButton
                                   withStyle:SculptingStylePeriwinkle
                                     andText:@"Sign In"];
        
        [self.signInButton addTarget:self
                              action:@selector(signInTapped)
                    forControlEvents:UIControlEventTouchUpInside];
        
        self.targetedCell = self.emailCell;
        
    }
    if ( type == SSOStateTypeSignUp ) {
#ifdef DEBUG
        self.signInButton.alpha = 0.45f;
        self.signInButton.userInteractionEnabled = NO;
#else
        self.signInButton.alpha = 1.0f;
        self.signInButton.userInteractionEnabled = YES;
#endif
        self.twitterButton.alpha = 0.0f;
        self.facebookButton.alpha = 0.0f;
        self.orLabel.alpha = 0.0f;
        self.signInLabel.alpha = 0.0f;
        self.signUpButton.alpha = 0.0f;
        self.closeButton.alpha = 0.0f;
        self.kpccLogoImageView.alpha = 0.0f;
        self.createAccountCaptionLabel.alpha = 1.0f;
        self.backButton.alpha = 1.0f;
        self.tableTopAnchor.constant = self.kpccLogoImageView.frame.origin.y+self.kpccLogoImageView.frame.size.height-12.0f;
        
        [self.passwordCell setSignup:YES];
        
        [self.signInButton addTarget:self
                              action:@selector(createTapped)
                    forControlEvents:UIControlEventTouchUpInside];
        
        [[DesignManager shared] sculptButton:self.signInButton
                                   withStyle:SculptingStylePeriwinkle
                                     andText:@"Create your account"];
        
        
        self.targetedCell = self.emailCell;
        
    }
    
    [[DesignManager shared] sculptButton:self.signUpButton
                               withStyle:SculptingStyleClearWithBorder
                                 andText:@"Sign Up"];

    // Global
    self.mainTable.backgroundColor = [UIColor clearColor];
    self.mainTable.delegate = self;
    self.mainTable.dataSource = self;
    
    [self.mainTable reloadData];
    
    self.mainTable.separatorColor = [UIColor clearColor];
    
    [self.signUpFooterCell setBackgroundColor:[UIColor clearColor]];
    
    [self.view layoutIfNeeded];
    [self.view updateConstraintsIfNeeded];
    
    if ( animated ) {
        [UIView commitAnimations];
    }
    
}

- (NSArray*)cellPaths {
    NSMutableArray *paths = [NSMutableArray new];
    for ( unsigned i = 0; i < 3; i++ ) {
        NSIndexPath *ip = [NSIndexPath indexPathWithIndex:i];
        [paths addObject:ip];
    }
    return [NSArray arrayWithArray:paths];
}

- (void)dismissKeyboard {
    [self.passwordCell.emailTextField resignFirstResponder];
    [self.emailCell.emailTextField resignFirstResponder];
    [self.confirmationCell.emailTextField resignFirstResponder];
    [self.emailCell deactivate];
    [self.confirmationCell deactivate];
    [self.passwordCell deactivate];
}

- (void)finishTransition {
    if ( self.targetedCell ) {
        [self.targetedCell.emailTextField becomeFirstResponder];
        self.targetedCell = nil;
    }
}

- (SSOValidationResult)validateInput {
    return SSOValidationResultOK;
    // TODO: Make this work
}

#pragma mark - Event handling
- (void)signInTapped {
    SSOValidationResult validationResult = [self validateInput];
    
    if ( validationResult == SSOValidationResultOK ) {
        [[DesignManager shared] switchAccessoryForSpinner:WSPIN toReplace:self.signInButton callback:^{
            [[UXmanager shared] loginWithCredentials:@{ @"email" : self.emailCell.emailTextField.text,
                                                        @"password" : self.passwordCell.emailTextField.text }
                                          completion:^(id returnedObject) {
                                              
                                              if ( returnedObject ) {
                                                  // Success
                                                  NSDictionary *tokens = (NSDictionary*)returnedObject;
                                                  [[UXmanager shared] storeTokens:tokens type:SSOTypeKPCC];
                                                  
                                              } else {
                                                  // Failure
                                                  
                                              }
                                              
                                          }];
        }];
    } else {
        // TODO: Handle bad input
    }
}

- (void)facebookTapped {
    
}

- (void)twitterTapped {
    
}

- (void)signUpTapped {
    [self primeForState:SSOStateTypeSignUp animated:YES];
}

- (void)closeTapped {
    [self dismissViewControllerAnimated:YES completion:^{
        
    }];
}

- (void)createTapped {
    SSOValidationResult validationResult = [self validateInput];
    if ( validationResult == SSOValidationResultOK ) {
        [[DesignManager shared] switchAccessoryForSpinner:WSPIN toReplace:self.signInButton callback:^{
            [[UXmanager shared] createUserWithMetadata:@{ @"email" : self.emailCell.emailTextField.text,
                                                          @"password" : self.passwordCell.emailTextField.text } completion:^(id returnedObject) {
                                                              
                                                              [[DesignManager shared] restoreControlFromSpinner];
                                                              
                                                              if ( returnedObject ) {
                                                                  
                                                                  NSDictionary *profile = (NSDictionary*)returnedObject;
                                                                  NSString *email = profile[@"email"];
                                                                  NSString *password = self.passwordCell.emailTextField.text;
                                                                  [[UXmanager shared] loginWithCredentials:@{ @"email" : email,
                                                                                                              @"password" : password }
                                                                                                completion:^(id returnedObject) {
                                                                                                    
                                                                                                    if ( returnedObject ) {
                                                                                                        // Success
                                                                                                        NSDictionary *tokens = (NSDictionary*)returnedObject;
                                                                                                        [[UXmanager shared] storeTokens:tokens type:SSOTypeKPCC];
                                                                                                        
                                                                                                    } else {
                                                                                                        // Failure
                                                                                                        
                                                                                                    }
                                                                                                    
                                                                                                }];
                                                                  
                                                              } else {
                                                                  
                                                              }
                                                          }];
            
        }];
    }
}

- (void)backTapped {
    [self primeForState:SSOStateTypeIdle animated:YES];
}

#pragma mark - UITableView
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    if ( self.currentState == SSOStateTypeSignUp ) {
        return 4;
    }
    
    return 3;
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if ( indexPath.row == 0 ) {
        return self.emailCell;
    }
    if ( indexPath.row == 1 ) {
        return self.passwordCell;
    }
    if ( indexPath.row == 2 ) {
        if ( self.currentState == SSOStateTypeSignUp ) {
            return self.confirmationCell;
        } else {
            return self.signUpFooterCell;
        }
    }
 
    
    return self.signUpFooterCell;
    
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if ( indexPath.row == 0 || indexPath.row == 1 ) {
        if ( self.currentState == SSOStateTypeIdle ) {
            return kShortHeight;
        }
        
        return kTallHeight;
    }
    if ( indexPath.row == 2 ) {
        if ( self.currentState == SSOStateTypeSignUp ) {
            return kTallHeight;
        }
        
        return self.signUpFooterCell.frame.size.height;
    }
    
    return self.signUpFooterCell.frame.size.height;
}

#pragma mark - UITextField
- (void)textFieldDidBeginEditing:(UITextField *)textField {
    
    if ( !self.dismissalTapper ) {
        self.dismissalTapper = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                       action:@selector(dismissKeyboard)];
        [self.mainTable addGestureRecognizer:self.dismissalTapper];
    }
    
    if ( textField == self.emailCell.emailTextField ) {
        [self.emailCell setInputting:YES];
    }
    if ( textField == self.passwordCell.emailTextField ) {
        [self.passwordCell setInputting:YES];
    }
    if ( textField == self.confirmationCell.emailTextField ) {
        [self.confirmationCell setInputting:YES];
    }
    
    if ( self.currentState == SSOStateTypeIdle ) {
        [self primeForState:SSOStateTypeSignIn animated:YES];
    }
    
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if ( self.dismissalTapper ) {
        [self.mainTable removeGestureRecognizer:self.dismissalTapper];
        self.dismissalTapper = nil;
    }
    [textField resignFirstResponder];
    
    [self.emailCell deactivate];
    [self.passwordCell deactivate];
    [self.confirmationCell deactivate];
    
    return YES;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    NSString *email = self.emailCell.emailTextField.text;
    NSString *password = self.passwordCell.emailTextField.text;
    NSString *confirm = self.confirmationCell.emailTextField.text;
    
    NSString *s2u = @"";
    NSString *other = @"";
    NSString *third = @"";
    
    if ( textField == self.emailCell.emailTextField ) {
        s2u = email;
        other = password;
    }
    if ( textField == self.passwordCell.emailTextField ) {
        s2u = password;
        other = email;
    }
    if ( textField == self.confirmationCell.emailTextField ) {
        s2u = confirm;
        other = email;
        third = password;
    }
    
    if ( SEQ(string,@"") ) {
        if ( [s2u length] > 0 ) {
            s2u = [s2u substringToIndex:[s2u length]-1];
        }
    } else {
        s2u = [s2u stringByAppendingString:string];
    }
    
    BOOL notOk = SEQ(s2u,@"") || SEQ(other,@"") ;
    if ( self.currentState == SSOStateTypeSignUp ) {
        if ( SEQ(@"",third) ) {
            notOk = YES;
        }
    }
    
    if ( notOk ) {
        [UIView animateWithDuration:0.25f animations:^{
            self.signInButton.alpha = 0.45f;
            self.signInButton.userInteractionEnabled = NO;
        }];
    } else {
        [UIView animateWithDuration:0.25f animations:^{
            self.signInButton.alpha = 1.0f;
            self.signInButton.userInteractionEnabled = YES;
        }];
    }
    
    return YES;
}
/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
