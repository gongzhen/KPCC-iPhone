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

@interface SCPRPledgePINViewController ()

@end

@implementation SCPRPledgePINViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.headCaptionLabel.textColor = [UIColor kpccOrangeColor];
    [self.headCaptionLabel proBookFontize];
    
    self.headDescriptionLabel.textColor = [UIColor number2pencilColor];
    [self.headDescriptionLabel proBookFontize];
    
    self.tokenField.font = self.headDescriptionLabel.font;
    
    self.tokenTable.separatorColor = [UIColor kpccDividerGrayColor];
    self.spinner.alpha = 0.0f;
    
    self.tokenTable.dataSource = self;
    self.tokenTable.delegate = self;
    [self.tokenTable reloadData];
    
    self.tokenField.delegate = self;
    self.tokenField.text = kPlaceholderPINString;
    self.pinNumber = @"";
    
    [self.tokenField becomeFirstResponder];
    
    self.submitButton.alpha = 0.4f;
    self.submitButton.userInteractionEnabled = YES;
    
    [self.submitButton addTarget:self
                          action:@selector(submitButtonTapped)
                forControlEvents:UIControlEventTouchUpInside];
    
    [self examineAndApplyStyle];
    
    // Do any additional setup after loading the view from its nib.
}

- (void)submitButtonTapped {
    if ( self.confirmed ) {

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
            [[SessionManager shared] validateXFSToken:self.pinNumber completion:^(id returnedObject) {
                if ( [returnedObject isKindOfClass:[NSNumber class]] ) {
                    NSNumber *result = (NSNumber*)returnedObject;
                    SCPRXFSViewController *svc = (SCPRXFSViewController*)self.parentXFSViewController;
                    if ( [result boolValue] ) {
                        self.confirmed = YES;
                        
                        [[UXmanager shared].settings setUserHasSelectedXFS:YES];
                        [[UXmanager shared].settings setXfsToken:self.pinNumber];
                        [[UXmanager shared] persist];
                        
                        [self.tokenTable reloadData];
                        [UIView animateWithDuration:0.25f animations:^{
                            self.spinner.alpha = 0.0f;
                            svc.cancelButton.alpha = 0.0f;
                        } completion:^(BOOL finished) {
                            
                        }];
                        
                    } else {
                        [UIView animateWithDuration:0.25f animations:^{
                            self.spinner.alpha = 0.0f;
                            svc.cancelButton.alpha = 0.0f;
                        } completion:^(BOOL finished) {
                            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Uh-oh! We can't seem to find a match"
                                                                                           message:@"The token you entered wasn't found in our system. Please try again or get in touch with our membership help desk."
                                                                                    preferredStyle:UIAlertControllerStyleAlert];
                            UIAlertAction *contactUs = [UIAlertAction actionWithTitle:@"Contact Us:"
                                                                                style:UIAlertActionStyleDefault
                                                                              handler:^(UIAlertAction *action) {
                                                                                  
                                                                              }];
                            UIAlertAction *ok = [UIAlertAction actionWithTitle:@"OK"
                                                                         style:UIAlertActionStyleDestructive
                                                                       handler:^(UIAlertAction *action) {
                                                                           
                                                                       }];
                            [alert addAction:ok];
                            [alert addAction:contactUs];
                            [self presentViewController:alert
                                               animated:YES
                                             completion:nil];
                            
                        }];
                    }
                }
            }];
        }];

    }
}

- (void)examineAndApplyStyle {
    if ( SEQ(@"",self.pinNumber) ) {
        self.tokenField.textColor = [UIColor kpccSubtleGrayColor];
        self.tokenField.text = kPlaceholderPINString;
        UITextPosition *beginning = [self.tokenField beginningOfDocument];
        [self.tokenField setSelectedTextRange:[self.tokenField textRangeFromPosition:beginning
                                                              toPosition:beginning]];
        
        [UIView animateWithDuration:0.25f animations:^{
            self.submitButton.alpha = 0.4f;
        } completion:^(BOOL finished) {
            self.submitButton.userInteractionEnabled = NO;
        }];
        
    } else {
        self.tokenField.textColor = [UIColor blackColor];
        [UIView animateWithDuration:0.25f animations:^{
            self.submitButton.alpha = 1.0f;
        } completion:^(BOOL finished) {
            self.submitButton.userInteractionEnabled = YES;
        }];
    }
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
        if ( self.confirmed ) {
            self.headSpacing.constant = kShortSpacing;
            self.headCaptionLabel.text = @"Success!";
            self.headDescriptionLabel.text = @"You've unlocked your access to the KPCC pledge-free stream. Enjoy!";
        } else {
            self.headSpacing.constant = kTallSpacing;
            self.headCaptionLabel.text = @"Are you a KPCC Member?";
            self.headDescriptionLabel.text = @"Enter your pledge drive token to gain access to the pledge-free stream";
        }
        
        [self.headerCell layoutIfNeeded];
        return self.headerCell;
    }
    if ( indexPath.row == 1 ) {
        if ( self.confirmed ) {
            [[DesignManager shared] sculptButton:self.submitButton
                                       withStyle:SculptingStylePeriwinkle
                                         andText:@"Close and start listening"];
            
            return self.submitCell;
        }
        
        [[DesignManager shared] sculptButton:self.submitButton
                                   withStyle:SculptingStylePeriwinkle
                                     andText:@"Submit"];
        

        
        return self.entryCell;
    }
    
    return self.submitCell;
    
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if ( indexPath.row == 0 ) {
        
        CGFloat variable = kTallSpacing;
        if ( self.confirmed ) {
            variable = kShortSpacing;
        }
        
        return self.headCaptionLabel.frame.origin.y+self.headCaptionLabel.frame.size.height+variable+self.headDescriptionLabel.frame.size.height+10.0f;
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
- (void)textFieldDidBeginEditing:(UITextField *)textField {
    UITextPosition *beginning = [textField beginningOfDocument];
    [textField setSelectedTextRange:[textField textRangeFromPosition:beginning
                                                          toPosition:beginning]];
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    if ( SEQ(string,@"") ) {
        if ( !SEQ(self.pinNumber,@"") ) {
            self.pinNumber = [self.pinNumber substringToIndex:self.pinNumber.length-1];
        }
    } else {
        if ( SEQ(self.pinNumber,@"") ) {
            textField.text = @"";
        }
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
