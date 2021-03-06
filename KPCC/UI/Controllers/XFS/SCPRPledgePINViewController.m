//
//  SCPRPledgePINViewController.m
//  KPCC
//
//  Created by Ben Hochberg on 6/1/15.
//  Copyright (c) 2015 SCPR. All rights reserved.
//

#import "SCPRPledgePINViewController.h"
#import "UILabel+Additions.h"
#import "UIColor+UICustom.h"
#import "DesignManager.h"
#import "Utils.h"
#import "UXmanager.h"
#import "SessionManager.h"
#import "SCPRXFSViewController.h"
#import "AnalyticsManager.h"
#import <Parse/Parse.h>

#define kTallSpacing 16.0f
#define kShortSpacing 8.0f
#define kPlaceholderPINString @"Enter your token"

@interface SCPRPledgePINViewController ()

@end

@implementation SCPRPledgePINViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.headCaptionLabel.textColor = [UIColor kpccOrangeColor];
    [self.headCaptionLabel proBookFontize];
    
    self.headDescriptionLabel.textColor = [UIColor number2pencilColor];
    [self.headDescriptionLabel proBookFontize];
    
    [self setupHeadlinesForState];
    
    self.tokenField.font = self.headDescriptionLabel.font;
    
    self.tokenTable.separatorColor = [UIColor kpccDividerGrayColor];
    self.spinner.alpha = 0.0f;
    
    self.tokenTable.dataSource = self;
    self.tokenTable.delegate = self;
    [self.tokenTable reloadData];
    
    self.tokenField.delegate = self;
    self.tokenField.placeholder = kPlaceholderPINString;
    self.pinNumber = @"";
    
    self.submitButton.alpha = 0.4f;
    self.submitButton.userInteractionEnabled = YES;
    
    [self.submitButton addTarget:self
                          action:@selector(submitButtonTapped)
                forControlEvents:UIControlEventTouchUpInside];
    
    [self.headerCell layoutIfNeeded];

    [self.faqLinkButton addTarget:self
                           action:@selector(puntToFAQ)
                 forControlEvents:UIControlEventTouchUpInside];
    
    [self.faqLinkButton setTitleColor:[UIColor kpccPeriwinkleColor]
                             forState:UIControlStateNormal];
    [self.faqLinkButton setTitleColor:[[UIColor kpccPeriwinkleColor] translucify:0.55f]
                             forState:UIControlStateHighlighted];
    
    [self.faqLinkButton.titleLabel proMediumFontize];
    
    
//#ifdef DEBUG
//    self.tokenField.text = @"4c3a3hn9hti";
//    self.pinNumber = @"4c3a3hn9hti";
//#endif

    [self examineAndApplyStyle];
    

    self.tokenField.returnKeyType = UIReturnKeyDone;
    
    // Do any additional setup after loading the view from its nib.
}

- (void)puntToFAQ {
    
    /*[[AnalyticsManager shared] logEvent:@"userLeavingToViewPlusFAQ"
                         withParameters:nil];*/
    
    NSString *urlStr = @"http://www.scpr.org/pledge-free";
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlStr]];
}

- (void)submitButtonTapped {
    
    self.pinNumber = self.tokenField.text;
    
    if ( self.confirmed ) {

        SCPRXFSViewController *xfs = [[Utils del] xfsInterface];
        [xfs orangeInterface];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"xfs-confirmation-exit"
                                                            object:nil];
        
        
    } else {
        [self.spinner startAnimating];
        [UIView animateWithDuration:0.25f animations:^{
            [[DesignManager shared] sculptButton:self.submitButton
                                       withStyle:SculptingStylePeriwinkle
                                         andText:@""];
            self.spinner.alpha = 1.0f;
        } completion:^(BOOL finished) {
            [[SessionManager shared] validateXFSToken:self.pinNumber completion:^(id object) {
           
                NSDictionary *result = (NSDictionary*)object;
                SCPRXFSViewController *svc = (SCPRXFSViewController*)self.parentXFSViewController;
                if ( result[@"success"] ) {
                    
                    self.confirmed = YES;
                    
                    PFObject *pfsu = result[@"success"];
#ifndef DEBUG
                    NSInteger viewsLeft = [pfsu[@"viewsLeft"] intValue];
                    viewsLeft--;
                    pfsu[@"viewsLeft"] = @(viewsLeft);
#endif
                    [[SessionManager shared] setUserIsSwitchingToKPCCPlus:YES];
                    [[UXmanager shared].settings setUserHasSelectedXFS:YES];
                    [[UXmanager shared].settings setXfsToken:self.pinNumber];
                    [[UXmanager shared] persist];
                    
                    [self.tokenTable reloadData];
                    [UIView animateWithDuration:0.25f animations:^{
                        self.spinner.alpha = 0.0f;
                        svc.cancelButton.alpha = 0.0f;
                    } completion:^(BOOL finished) {
                        [pfsu saveInBackground];
                        
                        /*[[AnalyticsManager shared] logEvent:@"member-token-success"
                                             withParameters:@{ @"token" : self.pinNumber }];*/
                        
                    }];
                    
                } else {
                    
                    if ( result[@"error"] ) {
                        
                        NSString *titleKey = [NSString stringWithFormat:@"%@-title",result[@"error"]];
                        NSString *bodyKey = [NSString stringWithFormat:@"%@-body",result[@"error"]];
                        NSString *emailSubjectKey = [NSString stringWithFormat:@"%@-email-subject",result[@"error"]];
                        NSString *emailBodyKey = [NSString stringWithFormat:@"%@-email-body",result[@"error"]];
                        
                        NSDictionary *errors = [[SessionManager shared] parseErrors];
                        
                        NSString *errorTitle = errors[titleKey];
                        NSString *errorBody = errors[bodyKey];
                        NSString *errorEmailSubject = errors[emailSubjectKey];
                        NSString *errorEmailBody = errors[emailBodyKey];
                        
                        if ( !errorTitle ) {
                            errorTitle = @"Uh-Oh, something went wrong";
                        }
                        if ( !errorBody ) {
                            errorBody = @"We're very sorry, but something unknown has prevented that token from processing. Please try again in a minute or contact us.";
                        }
                        if ( !errorEmailSubject ) {
                            errorEmailSubject = @"I'm having issues with the iPhone app!";
                        }
                        if ( !errorEmailBody ) {
                            errorEmailBody = @"Hello, I ran into some trouble while using the iPhone app and would appreciate some help.";
                        }
                        
                        [UIView animateWithDuration:0.25f animations:^{
                            self.spinner.alpha = 0.0f;
                        } completion:^(BOOL finished) {
                            
                            [self.tokenTable reloadData];
                            
                            UIAlertController *alert = [UIAlertController alertControllerWithTitle:errorTitle
                                                                                           message:errorBody
                                                                                    preferredStyle:UIAlertControllerStyleAlert];
                            
                            if ( [MFMailComposeViewController canSendMail] ) {
                                UIAlertAction *contactUs = [UIAlertAction actionWithTitle:@"Contact Us"
                                                                                    style:UIAlertActionStyleDefault
                                                                                  handler:^(UIAlertAction *action) {
                                                                                      
                                                                                      [[NSNotificationCenter defaultCenter] postNotificationName:@"xfs-confirmation-exit"
                                                                                                                                          object:nil];
                                                                                      
                                                                                      [[NSNotificationCenter defaultCenter]
                                                                                       postNotificationName:@"compose-mail"
                                                                                       object:nil
                                                                                       userInfo:@{ @"subject" : errorEmailSubject,
                                                                                                   @"body" : errorEmailBody,
                                                                                                   @"email" : @"membership@kpcc.org",
                                                                                                   @"subtext" : @{ @"Pledge Token" : self.pinNumber,
                                                                                                                   @"UID" : [[[UIDevice currentDevice] identifierForVendor] UUIDString] }}];
                                                                                      
                                                                                  }];
                                [alert addAction:contactUs];
                            }
                            
                            UIAlertAction *ok = [UIAlertAction actionWithTitle:@"OK"
                                                                         style:UIAlertActionStyleCancel
                                                                       handler:^(UIAlertAction *action) {
                                                                           
                                                                       }];
                            [alert addAction:ok];
                            
                            [self presentViewController:alert
                                               animated:YES
                                             completion:nil];
                            
                            /*[[AnalyticsManager shared] logEvent:@"member-token-failure"
                                                 withParameters:@{ @"token" : self.pinNumber }];*/
                            
                        }];
                    }
                }
             
            }];
        }];

    }
}

- (void)examineAndApplyStyle {
    self.tokenField.textColor = [UIColor blackColor];
    if ( SEQ(@"",self.pinNumber) ) {
        [UIView animateWithDuration:0.25f animations:^{
            self.submitButton.alpha = 0.4f;
        } completion:^(BOOL finished) {
            self.submitButton.userInteractionEnabled = NO;
        }];
        
    } else {
        [UIView animateWithDuration:0.25f animations:^{
            self.submitButton.alpha = 1.0f;
        } completion:^(BOOL finished) {
            self.submitButton.userInteractionEnabled = YES;
        }];
    }
}

- (void)setupHeadlinesForState {
    if ( self.confirmed ) {
        self.headSpacing.constant = kShortSpacing;
        self.headCaptionLabel.text = @"Success!";
        self.headDescriptionLabel.text = @"You've unlocked your access to KPCC Plus. Enjoy!";
        self.faqLinkButton.alpha = 0.0f;
    } else {
        self.headSpacing.constant = kTallSpacing;
        self.headCaptionLabel.text = @"Are you a KPCC Member?";
        self.headDescriptionLabel.text = @"We'll e-mail all qualifying members a unique code to gain access to KPCC Plus, a stream without fundraising interruptions.\n\nIf you need more information on how to get an access code please visit the link below:";
        self.faqLinkButton.alpha = 1.0f;
    }
    
    self.headerCell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    [self.headerCell layoutIfNeeded];
}

#pragma mark - UITableView
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    if ( self.confirmed ) {
        return 2;
    }
    
    return 3;
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if ( indexPath.row == 0 ) {

        [self setupHeadlinesForState];
        
        return self.headerCell;
    }
    if ( indexPath.row == 1 ) {
        if ( self.confirmed ) {
            [[DesignManager shared] sculptButton:self.submitButton
                                       withStyle:SculptingStylePeriwinkle
                                         andText:@"Close and start listening"];
            
            self.submitCell.selectionStyle = UITableViewCellSelectionStyleNone;
            return self.submitCell;
        }
        
        [[DesignManager shared] sculptButton:self.submitButton
                                   withStyle:SculptingStylePeriwinkle
                                     andText:@"Submit"];
        

        self.entryCell.selectionStyle = UITableViewCellSelectionStyleNone;
        return self.entryCell;
    }
    
    self.submitCell.selectionStyle = UITableViewCellSelectionStyleNone;
    return self.submitCell;
    
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if ( indexPath.row == 0 ) {
        
        [self setupHeadlinesForState];
        
        return self.headerCell.frame.size.height;
        
    }
    if ( indexPath.row == 1 ) {
        if ( self.confirmed ) {
            return self.submitCell.frame.size.height;
        } else {
            return self.entryCell.frame.size.height;
        }
    }
    
    return self.submitCell.frame.size.height;
}

- (UIView*)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    return [[UIView alloc] initWithFrame:CGRectMake(0.0,0.0,self.view.frame.size.width,1.0f)];
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return 1.0f;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - UITextField
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    [UIView animateWithDuration:0.33f animations:^{
        self.tokenTable.contentOffset = CGPointMake(0.0,200.0f);
    }];
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    [UIView animateWithDuration:0.33f animations:^{
        self.tokenTable.contentOffset = CGPointMake(0.0,-64.0f);
    }];
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    
    self.pinNumber = textField.text;
    if ( SEQ(string,@"") ) {
        self.pinNumber = [self.pinNumber substringToIndex:[self.pinNumber length]-1];
    } else {
        self.pinNumber = [self.pinNumber stringByAppendingString:string];
    }
    [self examineAndApplyStyle];
    
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
