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
    
    [self.tokenField becomeFirstResponder];
    
    [self.submitButton addTarget:self
                          action:@selector(submitButtonTapped)
                forControlEvents:UIControlEventTouchUpInside];
    
    // Do any additional setup after loading the view from its nib.
}

- (void)submitButtonTapped {
    
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

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
