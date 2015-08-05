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
#import "Utils.h"

@implementation SCPRSSOInputFieldCell

- (void)awakeFromNib {
    // Initialization code
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (void)primeWithType:(SSOInputFieldType)type andFieldDelegate:(id<UITextFieldDelegate>)delegate {
    
    self.type = type;
    if ( type == SSOInputFieldTypeEmail ) {
        self.emailTextField.secureTextEntry = NO;
        self.captionLabel.text = @"Enter your email address:";
        self.iconImageView.image = [UIImage imageNamed:@"icon-mail.png"];
        
        NSMutableAttributedString *aPlaceholder = [[NSMutableAttributedString alloc] initWithString:@"Email Address"
                                                                                         attributes:@{ NSForegroundColorAttributeName : [[UIColor virtualWhiteColor] translucify:1.0f],
                                                                                                       NSFontAttributeName : [[DesignManager shared] proBook:17.0f] }];
        
        self.emailTextField.attributedPlaceholder = aPlaceholder;
    }
    if ( type == SSOInputFieldTypePassword ) {
        self.emailTextField.secureTextEntry = YES;
        self.captionLabel.text = @"Enter your password:";
        self.iconImageView.image = [UIImage imageNamed:@"icon-lock-white.png"];
        NSMutableAttributedString *aPlaceholder = [[NSMutableAttributedString alloc] initWithString:@"Password"
                                                                                         attributes:@{ NSForegroundColorAttributeName : [[UIColor virtualWhiteColor] translucify:1.0f],
                                                                                                       NSFontAttributeName : [[DesignManager shared] proBook:17.0f] }];
        self.emailTextField.attributedPlaceholder = aPlaceholder;
        
    }
    if ( type == SSOInputFieldTypePasswordConfirmation ) {
        self.emailTextField.secureTextEntry = YES;
        self.captionLabel.text = @"Confirm your password:";
        self.iconImageView.image = [UIImage imageNamed:@"icon-lock-white.png"];
        self.fieldLeftAnchor.constant = 12.0f;
        
        NSMutableAttributedString *aPlaceholder = [[NSMutableAttributedString alloc] initWithString:@"Confirm Password"
                                                                                         attributes:@{ NSForegroundColorAttributeName : [[UIColor virtualWhiteColor] translucify:1.0f],
                                                                                                       NSFontAttributeName : [[DesignManager shared] proBook:17.0f] }];
        self.emailTextField.attributedPlaceholder = aPlaceholder;
    }
    
    self.backgroundColor = [UIColor clearColor];
    
    self.emailTextField.textColor = [UIColor whiteColor];
    self.emailTextField.returnKeyType = UIReturnKeyDone;
    self.emailTextField.enablesReturnKeyAutomatically = YES;
    self.emailTextField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.emailTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.emailTextField.font = [[DesignManager shared] proBook:self.emailTextField.font.pointSize];
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

- (void)setSignup:(BOOL)signup {
    _signup = signup;
    if ( signup ) {
        
        if ( self.type == SSOInputFieldTypePassword ) {
            self.captionLabel.text = @"";
            NSMutableAttributedString *aString = [[NSMutableAttributedString alloc] initWithString:@"Enter your password:           at least 8 characters"
                                                                                        attributes:@{}];
            NSRange italicRange = [aString.string rangeOfString:@"at least 8 characters"];
            
            [aString addAttributes:@{ NSFontAttributeName : [[DesignManager shared] proBookItalic:10.0f] }
                             range:italicRange];
            self.captionLabel.attributedText = aString;
        } else {
            self.captionLabel.attributedText = nil;
            self.captionLabel.text = @"Enter your password:";
        }
        
    }
}

- (void)activate {
    [UIView animateWithDuration:0.25f animations:^{
        self.inputSeatView.layer.borderWidth = 1.0f;
        self.inputSeatView.layer.borderColor = [UIColor whiteColor].CGColor;
        self.inputSeatView.alpha = 1.0f;
        self.fieldLeftAnchor.constant = 10.0f;
        self.iconImageView.alpha = 0.0f;
        self.captionLabel.alpha = 1.0f;
        [self layoutIfNeeded];
    }];
}

- (void)deactivate {
    [self setInputting:NO];
    [UIView animateWithDuration:0.25f animations:^{
        self.inputSeatView.layer.borderWidth = 0.0f;
        if ( SEQ(self.emailTextField.text,@"") || !self.emailTextField.text ) {
            self.inputSeatView.alpha = 0.65f;
        } else {
            self.inputSeatView.alpha = 1.0f;
        }
        self.fieldLeftAnchor.constant = 55.0f;
        self.iconImageView.alpha = 1.0f;
        self.captionLabel.alpha = 0.0f;
        [self layoutIfNeeded];
    }];
}
@end
