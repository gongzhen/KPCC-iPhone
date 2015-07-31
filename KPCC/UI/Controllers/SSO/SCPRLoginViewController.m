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
    
    [self primeForState:SSOStateTypeIdle animated:NO];
    
    // Do any additional setup after loading the view from its nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)primeForState:(SSOStateType)type animated:(BOOL)animated {
    
    self.currentState = type;
    
    if ( animated ) {
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:0.25f];
    }
    
    if ( type == SSOStateTypeIdle ) {
        self.signInButton.alpha = 0.0f;
        self.twitterButton.alpha = 1.0f;
        self.facebookButton.alpha = 1.0f;
        self.orLabel.alpha = 0.0f;
        self.signInLabel.alpha = 1.0f;
        [self.signInLabel proBookFontize];
        [self.orLabel proBookFontize];
        
    }
    if ( type == SSOStateTypeSignIn ) {
        self.signInButton.alpha = 1.0f;
        self.twitterButton.alpha = 0.0f;
        self.facebookButton.alpha = 0.0f;
        self.orLabel.alpha = 0.0f;
        self.signInLabel.alpha = 0.0f;
        self.tableTopAnchor.constant = self.kpccLogoImageView.frame.origin.y+self.kpccLogoImageView.frame.size.height+20.0f;
    }
    
    [[DesignManager shared] sculptButton:self.signUpButton
                               withStyle:SculptingStyleClearWithBorder
                                 andText:@"Sign Up"];
    
    [[DesignManager shared] sculptButton:self.signInButton
                               withStyle:SculptingStylePeriwinkle
                                 andText:@"Sign In"];
    

    // Global
    self.mainTable.backgroundColor = [UIColor clearColor];
    
    self.mainTable.delegate = self;
    self.mainTable.dataSource = self;
    
    if ( animated ) {
        [self.mainTable beginUpdates];
        [self.mainTable endUpdates];
    } else {
        [self.mainTable reloadData];
    }
    
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
    
    if ( textField == self.emailCell.emailTextField ) {
        [self.emailCell setInputting:YES];
    }
    if ( textField == self.passwordCell.emailTextField ) {
        [self.passwordCell setInputting:YES];
    }
    if ( textField == self.confirmationCell.emailTextField ) {
        [self.confirmationCell setInputting:YES];
    }
    
    [self primeForState:SSOStateTypeSignIn animated:YES];
    
}

- (BOOL)textFieldShouldEndEditing:(UITextField *)textField {
    [textField resignFirstResponder];
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
