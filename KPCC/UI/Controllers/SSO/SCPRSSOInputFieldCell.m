//
//  SCPRSSOInputFieldCellTableViewCell.m
//  KPCC
//
//  Created by Ben Hochberg on 7/30/15.
//  Copyright (c) 2015 SCPR. All rights reserved.
//

#import "SCPRSSOInputFieldCell.h"
#import "DesignManager.h"
#import "UIColor+UICustom.h"
#import "UILabel+Additions.h"

@implementation SCPRSSOInputFieldCell

- (void)awakeFromNib {
    // Initialization code
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (void)primeWithType:(SSOInputFieldType)type andFieldDelegate:(id<UITextFieldDelegate>)delegate {
    if ( type == SSOInputFieldTypeEmail ) {
        self.emailTextField.secureTextEntry = NO;
        self.captionLabel.text = @"Enter your email address:";
        self.iconImageView.image = [UIImage imageNamed:@"icon-mail.png"];
    }
    if ( type == SSOInputFieldTypePassword ) {
        self.emailTextField.secureTextEntry = YES;
        self.captionLabel.text = @"Enter your password:";
        self.iconImageView.image = [UIImage imageNamed:@"icon-lock.png"];
    }
    if ( type == SSOInputFieldTypePasswordConfirmation ) {
        self.emailTextField.secureTextEntry = YES;
        self.captionLabel.text = @"Confirm your password:";
        self.iconImageView.alpha = 0.0f;
        self.fieldLeftAnchor.constant = 12.0f;
    }
    
    self.backgroundColor = [UIColor clearColor];
    
    self.emailTextField.delegate = delegate;
    self.captionLabel.textColor = [UIColor whiteColor];
    
    self.clipsToBounds = YES;
    self.contentView.clipsToBounds = YES;
    
    self.emailTextField.backgroundColor = [UIColor clearColor];
    self.inputSeatView.backgroundColor = [[UIColor virtualWhiteColor] translucify:0.45f];
    [self.captionLabel proBookFontize];
    
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(fieldActivated:)
                                                 name:@"field-input-active"
                                               object:nil];
    [self layoutIfNeeded];
    
}

- (void)fieldActivated:(NSNotification*)note {
    NSDictionary *ui = note.userInfo;
    SCPRSSOInputFieldCell *cell = ui[@"cell"];
    if ( cell == self ) {
        [self activate];
    } else {
        [self deactivate];
    }
}

- (void)setInputting:(BOOL)inputting {
    _inputting = inputting;
    if ( inputting ) {
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"field-input-active"
                                                            object:nil
                                                          userInfo:@{ @"cell" : self }];
        
    }
}

- (void)activate {
    [UIView animateWithDuration:0.25f animations:^{
        self.inputSeatView.layer.borderWidth = 1.0f;
        self.inputSeatView.layer.borderColor = [UIColor whiteColor].CGColor;
        self.inputSeatView.alpha = 1.0f;
        self.fieldLeftAnchor.constant = 10.0f;
        self.iconImageView.alpha = 0.0f;
        [self layoutIfNeeded];
    }];
}

- (void)deactivate {
    [self setInputting:NO];
    [UIView animateWithDuration:0.25f animations:^{
        self.inputSeatView.layer.borderWidth = 0.0f;
        self.inputSeatView.alpha = 0.65f;
        self.fieldLeftAnchor.constant = 55.0f;
        self.iconImageView.alpha = 1.0f;
        [self layoutIfNeeded];
    }];
}
@end
